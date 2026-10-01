import 'dart:ffi';
import 'dart:io';

typedef StartAudioEngineC = Bool Function();
typedef StartAudioEngineDart = bool Function();

typedef StopAudioEngineC = Void Function();
typedef StopAudioEngineDart = void Function();

typedef PluckStringC = Void Function(Float frequency, Float velocity);
typedef PluckStringDart = void Function(double frequency, double velocity);

class OboeEngine {
  static DynamicLibrary? _nativeLib;

  static StartAudioEngineDart? _startAudioEngine;
  static StopAudioEngineDart? _stopAudioEngine;
  static PluckStringDart? _pluckString;

  static bool _isInitialized = false;
  static bool get isAvailable => _isInitialized && _nativeLib != null;

  static void init() {
    if (!Platform.isAndroid) return;
    if (_isInitialized) return;

    try {
      _nativeLib = DynamicLibrary.open('libnative_audio_engine.so');

      _startAudioEngine = _nativeLib!
          .lookup<NativeFunction<StartAudioEngineC>>('startAudioEngine')
          .asFunction<StartAudioEngineDart>();

      _stopAudioEngine = _nativeLib!
          .lookup<NativeFunction<StopAudioEngineC>>('stopAudioEngine')
          .asFunction<StopAudioEngineDart>();

      _pluckString = _nativeLib!
          .lookup<NativeFunction<PluckStringC>>('pluckSasandoString')
          .asFunction<PluckStringDart>();

      final started = _startAudioEngine!();
      if (started) {
        _isInitialized = true;
      }
    } catch (e) {
      _isInitialized = false;
    }
  }

  static void pluck(double frequency, {double velocity = 1.0}) {
    if (_isInitialized && _pluckString != null) {
      _pluckString!(frequency, velocity);
    }
  }

  static void dispose() {
    if (_isInitialized && _stopAudioEngine != null) {
      _stopAudioEngine!();
      _isInitialized = false;
    }
  }
}