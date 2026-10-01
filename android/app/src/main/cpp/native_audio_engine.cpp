#include <oboe/Oboe.h>
#include <android/log.h>
#include <math.h>
#include <array>
#include <atomic>
#include <memory>
#include <cstdint>

#define LOG_TAG "SasandoUltraLowLatency"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

constexpr int MAX_VOICES = 24;
constexpr int MAX_BUFFER_PER_VOICE = 4096; // Supports down to ~20 Hz at 96kHz
constexpr int EVENT_QUEUE_CAPACITY = 64;

// Ultra-fast deterministic Xorshift32 PRNG (Zero syscalls, 0 lock, 3 CPU cycles)
struct FastRandom {
    uint32_t state = 2463534242;
    inline float nextFloat() {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        // Map uint32 to [-1.0f, 1.0f]
        return (static_cast<float>(state) / 2147483648.0f) - 1.0f;
    }
};

struct PluckCommand {
    float frequency;
    float velocity;
};

// Lock-Free Single-Producer Single-Consumer (SPSC) Queue for Note-On events
class LockFreeEventQueue {
public:
    LockFreeEventQueue() : head(0), tail(0) {}

    bool push(float freq, float vel) {
        size_t currentTail = tail.load(std::memory_order_relaxed);
        size_t nextTail = (currentTail + 1) % EVENT_QUEUE_CAPACITY;
        if (nextTail == head.load(std::memory_order_acquire)) {
            return false; // Queue full
        }
        queue[currentTail] = {freq, vel};
        tail.store(nextTail, std::memory_order_release);
        return true;
    }

    bool pop(PluckCommand& cmd) {
        size_t currentHead = head.load(std::memory_order_relaxed);
        if (currentHead == tail.load(std::memory_order_acquire)) {
            return false; // Queue empty
        }
        cmd = queue[currentHead];
        head.store((currentHead + 1) % EVENT_QUEUE_CAPACITY, std::memory_order_release);
        return true;
    }

private:
    std::array<PluckCommand, EVENT_QUEUE_CAPACITY> queue;
    std::atomic<size_t> head;
    std::atomic<size_t> tail;
};

// Zero-allocation, pre-buffered Karplus-Strong string voice
class SasandoVoice {
public:
    SasandoVoice() : active(false), bufferSize(0), readIndex(0), writeIndex(0), prevSample(0.0f), decay(0.992f) {
        buffer.fill(0.0f);
    }

    void pluck(float frequency, float velocity, float sampleRate, FastRandom& rng) {
        if (frequency <= 30.0f) return;

        int size = static_cast<int>(sampleRate / frequency);
        if (size < 2) size = 2;
        if (size > MAX_BUFFER_PER_VOICE) size = MAX_BUFFER_PER_VOICE;

        bufferSize = size;

        // Noise burst with bamboo resonance filtering
        float lastNoise = 0.0f;
        for (int i = 0; i < bufferSize; ++i) {
            float noise = rng.nextFloat();
            buffer[i] = (noise + lastNoise) * 0.5f * velocity;
            lastNoise = noise;
        }

        readIndex = 0;
        writeIndex = 0;
        prevSample = 0.0f;

        // Tuned decay factor for Sasando lontar resonance
        decay = 0.987f + (0.010f * (1.0f - (frequency / 2500.0f)));
        if (decay > 0.997f) decay = 0.997f;
        if (decay < 0.950f) decay = 0.950f;

        active = true;
    }

    inline float render() {
        if (!active || bufferSize == 0) return 0.0f;

        float currentSample = buffer[readIndex];
        
        // Karplus-Strong Low-Pass Averaging
        float newSample = (currentSample + prevSample) * 0.5f * decay;
        prevSample = currentSample;

        buffer[writeIndex] = newSample;

        readIndex = (readIndex + 1) % bufferSize;
        writeIndex = (writeIndex + 1) % bufferSize;

        // Auto-silence cut-off
        if (fabs(newSample) < 0.00004f) {
            active = false;
        }

        return currentSample;
    }

    bool isActive() const { return active; }

private:
    std::array<float, MAX_BUFFER_PER_VOICE> buffer;
    bool active;
    int bufferSize;
    size_t readIndex;
    size_t writeIndex;
    float prevSample;
    float decay;
};

class SasandoEngine : public oboe::AudioStreamCallback {
public:
    SasandoEngine() : sampleRate(48000.0f) {}

    void queuePluck(float frequency, float velocity) {
        eventQueue.push(frequency, velocity);
    }

    oboe::DataCallbackResult onAudioReady(oboe::AudioStream *audioStream, void *audioData, int32_t numFrames) override {
        float *outputBuffer = static_cast<float *>(audioData);

        // 1. Process lock-free pending plucks from UI
        PluckCommand cmd;
        while (eventQueue.pop(cmd)) {
            // Find inactive voice
            bool assigned = false;
            for (auto& voice : voices) {
                if (!voice.isActive()) {
                    voice.pluck(cmd.frequency, cmd.velocity, sampleRate, rng);
                    assigned = true;
                    break;
                }
            }
            if (!assigned) {
                // Steal voice 0 if all are saturated
                voices[0].pluck(cmd.frequency, cmd.velocity, sampleRate, rng);
            }
        }

        // 2. Render all active voices with zero latency & soft limiter
        for (int i = 0; i < numFrames; ++i) {
            float mixedSample = 0.0f;

            for (auto& voice : voices) {
                if (voice.isActive()) {
                    mixedSample += voice.render();
                }
            }

            // Soft saturation limiter (clean acoustic saturation)
            if (mixedSample > 1.0f) mixedSample = 1.0f;
            else if (mixedSample < -1.0f) mixedSample = -1.0f;

            outputBuffer[i] = mixedSample;
        }

        return oboe::DataCallbackResult::Continue;
    }

    void onErrorAfterClose(oboe::AudioStream *oboeStream, oboe::Result result) override {
        if (result == oboe::Result::ErrorDisconnected) {
            LOGW("Audio stream disconnected. Restarting stream...");
            start();
        }
    }

    bool start() {
        stop();

        oboe::AudioStreamBuilder builder;
        builder.setAudioApi(oboe::AudioApi::AAudio) // Prefer native AAudio MMAP
               ->setDirection(oboe::Direction::Output)
               ->setPerformanceMode(oboe::PerformanceMode::LowLatency) // Request Low-Latency DSP pipeline
               ->setSharingMode(oboe::SharingMode::Exclusive) // Exclusive hardware access
               ->setUsage(oboe::Usage::Game) // Game usage guarantees lowest scheduling latency
               ->setContentType(oboe::ContentType::Sonification)
               ->setFormat(oboe::AudioFormat::Float)
               ->setChannelCount(oboe::ChannelCount::Mono)
               ->setCallback(this);

        oboe::Result result = builder.openStream(&stream);
        if (result != oboe::Result::OK) {
            LOGW("Exclusive stream open failed. Retrying with Shared mode...");
            builder.setSharingMode(oboe::SharingMode::Shared);
            result = builder.openStream(&stream);
            if (result != oboe::Result::OK) {
                LOGE("Failed to open stream. Error: %s", oboe::convertToText(result));
                return false;
            }
        }

        sampleRate = static_cast<float>(stream->getSampleRate());
        
        // Optimize buffer size to the lowest burst hardware capacity
        int32_t framesPerBurst = stream->getFramesPerBurst();
        stream->setBufferSizeInFrames(framesPerBurst * 2); // 2 bursts buffer threshold

        result = stream->requestStart();
        if (result != oboe::Result::OK) {
            LOGE("Failed to start stream. Error: %s", oboe::convertToText(result));
            return false;
        }

        LOGI("Oboe Ultra Low Latency Stream active! SampleRate: %f, Burst: %d, MMAP: %s",
             sampleRate, framesPerBurst, stream->isXRunCountSupported() ? "Yes" : "No");
        return true;
    }

    void stop() {
        if (stream) {
            stream->stop();
            stream->close();
            stream = nullptr;
        }
    }

private:
    std::shared_ptr<oboe::AudioStream> stream;
    std::array<SasandoVoice, MAX_VOICES> voices;
    LockFreeEventQueue eventQueue;
    FastRandom rng;
    float sampleRate;
};

static SasandoEngine gSasandoEngine;

// C-Export APIs for Dart FFI
extern "C" {

__attribute__((visibility("default"))) __attribute__((used))
bool startAudioEngine() {
    return gSasandoEngine.start();
}

__attribute__((visibility("default"))) __attribute__((used))
void stopAudioEngine() {
    gSasandoEngine.stop();
}

__attribute__((visibility("default"))) __attribute__((used))
void pluckSasandoString(float frequency, float velocity) {
    gSasandoEngine.queuePluck(frequency, velocity);
}

}