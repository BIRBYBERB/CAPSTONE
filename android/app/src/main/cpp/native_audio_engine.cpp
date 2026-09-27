#include <oboe/Oboe.h>
#include <android/log.h>
#include <math.h>
#include <vector>
#include <memory>
#include <mutex>
#include <random>

#define LOG_TAG "SasandoAudioEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

constexpr int MAX_VOICES = 32;
constexpr float SAMPLE_RATE = 48000.0f;

// Karplus-Strong Plucked String Voice for Sasando
class SasandoVoice {
public:
    SasandoVoice() : active(false), readIndex(0), writeIndex(0), prevSample(0.0f), decay(0.992f) {}

    void pluck(float frequency, float velocity) {
        if (frequency <= 20.0f) return;
        
        int bufferSize = static_cast<int>(SAMPLE_RATE / frequency);
        if (bufferSize < 2) bufferSize = 2;
        
        buffer.resize(bufferSize);
        
        // Excitation: noise burst with slight low-pass filtering for organic lontar/bamboo tone
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_real_distribution<float> dis(-1.0f, 1.0f);

        float lastNoise = 0.0f;
        for (int i = 0; i < bufferSize; ++i) {
            float noise = dis(gen);
            // Gentle filter on noise burst
            buffer[i] = (noise + lastNoise) * 0.5f * velocity;
            lastNoise = noise;
        }

        readIndex = 0;
        writeIndex = 0;
        prevSample = 0.0f;
        
        // Frequency-dependent decay (higher notes decay faster)
        decay = 0.985f + (0.012f * (1.0f - (frequency / 2000.0f)));
        if (decay > 0.998f) decay = 0.998f;
        if (decay < 0.960f) decay = 0.960f;

        active = true;
    }

    float render() {
        if (!active || buffer.empty()) return 0.0f;

        float currentSample = buffer[readIndex];
        
        // Karplus-Strong low-pass averaging filter (averages current and previous sample)
        float newSample = (currentSample + prevSample) * 0.5f * decay;
        prevSample = currentSample;

        buffer[writeIndex] = newSample;

        readIndex = (readIndex + 1) % buffer.size();
        writeIndex = (writeIndex + 1) % buffer.size();

        // Check for silence to deactivate voice
        if (fabs(newSample) < 0.00005f) {
            active = false;
        }

        return currentSample;
    }

    bool isActive() const { return active; }

private:
    std::vector<float> buffer;
    bool active;
    size_t readIndex;
    size_t writeIndex;
    float prevSample;
    float decay;
};

class SasandoEngine : public oboe::AudioStreamCallback {
public:
    SasandoEngine() {
        voices.resize(MAX_VOICES);
    }

    void pluckString(float frequency, float velocity) {
        std::lock_guard<std::mutex> lock(engineMutex);
        
        // Find an inactive voice or steal the oldest
        for (auto& voice : voices) {
            if (!voice.isActive()) {
                voice.pluck(frequency, velocity);
                return;
            }
        }
        // If all are active, reuse voice 0
        voices[0].pluck(frequency, velocity);
    }

    oboe::DataCallbackResult onAudioReady(oboe::AudioStream *audioStream, void *audioData, int32_t numFrames) override {
        float *outputBuffer = static_cast<float *>(audioData);

        std::lock_guard<std::mutex> lock(engineMutex);

        for (int i = 0; i < numFrames; ++i) {
            float mixedSample = 0.0f;

            for (auto& voice : voices) {
                if (voice.isActive()) {
                    mixedSample += voice.render();
                }
            }

            // Soft clipping / limiter to prevent distortion during heavy chords/glissando
            if (mixedSample > 1.0f) mixedSample = 1.0f;
            else if (mixedSample < -1.0f) mixedSample = -1.0f;

            outputBuffer[i] = mixedSample;
        }

        return oboe::DataCallbackResult::Continue;
    }

    bool start() {
        oboe::AudioStreamBuilder builder;
        builder.setDirection(oboe::Direction::Output)
               ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
               ->setSharingMode(oboe::SharingMode::Exclusive)
               ->setFormat(oboe::AudioFormat::Float)
               ->setChannelCount(oboe::ChannelCount::Mono)
               ->setSampleRate(static_cast<int32_t>(SAMPLE_RATE))
               ->setCallback(this);

        oboe::Result result = builder.openStream(&stream);
        if (result != oboe::Result::OK) {
            LOGE("Failed to open stream. Error: %s", oboe::convertToText(result));
            return false;
        }

        result = stream->requestStart();
        if (result != oboe::Result::OK) {
            LOGE("Failed to start stream. Error: %s", oboe::convertToText(result));
            return false;
        }

        LOGI("Oboe Sasando audio stream started successfully.");
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
    std::vector<SasandoVoice> voices;
    std::mutex engineMutex;
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
    gSasandoEngine.pluckString(frequency, velocity);
}

}