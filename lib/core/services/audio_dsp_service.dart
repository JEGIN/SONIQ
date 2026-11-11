import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioDspService {
  static final AudioDspService _instance = AudioDspService._internal();
  factory AudioDspService() => _instance;
  AudioDspService._internal();

  static const MethodChannel _channel = MethodChannel('com.soniq.soniq/dsp');
  static const EventChannel _vizChannel = EventChannel(
    'com.soniq.soniq/visualizer',
  );
  static const EventChannel _deviceChannel = EventChannel(
    'com.soniq.soniq/device_route',
  );

  Stream<List<double>>? _visualizerStream;
  Stream<String>? _deviceStream;

  int _lastSessionId = 0;

  Stream<List<double>> get visualizerStream {
    _visualizerStream ??= _vizChannel
        .receiveBroadcastStream()
        .map(
          (event) => (event as List<dynamic>)
              .map((e) => (e as num).toDouble())
              .toList(),
        )
        .handleError((e) {
          debugPrint('SONIQ_DSP: Visualizer stream error: $e');
        });
    return _visualizerStream!;
  }

  Stream<String> get deviceStream {
    _deviceStream ??= _deviceChannel
        .receiveBroadcastStream()
        .map((event) => event.toString())
        .handleError((e) {
          debugPrint('SONIQ_DSP: Device stream error: $e');
        });
    return _deviceStream!;
  }

  Future<Map<String, dynamic>?> attachAudioSession(int sessionId) async {
    if (sessionId <= 0 || sessionId == _lastSessionId) return null;
    _lastSessionId = sessionId;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'attachSession',
        {'sessionId': sessionId},
      );
      return res;
    } catch (e) {
      debugPrint('SONIQ_DSP: attachSession error: $e');
      return null;
    }
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setEqualizerEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('SONIQ_DSP: setEqualizerEnabled error: $e');
    }
  }

  Future<void> set10BandGains(List<double> gains) async {
    try {
      await _channel.invokeMethod('set10BandGains', {'gains': gains});
    } catch (e) {
      debugPrint('SONIQ_DSP: set10BandGains error: $e');
    }
  }

  Future<void> setBandGain(int band, double gainDb) async {
    try {
      await _channel.invokeMethod('setBandGain', {
        'band': band,
        'gain': gainDb,
      });
    } catch (e) {
      debugPrint('SONIQ_DSP: setBandGain error: $e');
    }
  }

  Future<void> setPreamp(double gainDb) async {
    try {
      await _channel.invokeMethod('setPreamp', {'gainDb': gainDb});
    } catch (e) {
      debugPrint('SONIQ_DSP: setPreamp error: $e');
    }
  }

  Future<void> setBassBoost(int strength) async {
    try {
      await _channel.invokeMethod('setBassBoost', {'strength': strength});
    } catch (e) {
      debugPrint('SONIQ_DSP: setBassBoost error: $e');
    }
  }

  Future<void> setTrebleBoost(double gainDb) async {
    try {
      await _channel.invokeMethod('setTrebleBoost', {'gainDb': gainDb});
    } catch (e) {
      debugPrint('SONIQ_DSP: setTrebleBoost error: $e');
    }
  }

  Future<void> setVirtualizerStrength(int strength) async {
    try {
      await _channel.invokeMethod('setVirtualizerStrength', {
        'strength': strength,
      });
    } catch (e) {
      debugPrint('SONIQ_DSP: setVirtualizerStrength error: $e');
    }
  }

  Future<void> setVirtualizerMode(String mode) async {
    try {
      await _channel.invokeMethod('setVirtualizerMode', {'mode': mode});
    } catch (e) {
      debugPrint('SONIQ_DSP: setVirtualizerMode error: $e');
    }
  }

  Future<void> setStereoWidth(int widthPercent) async {
    try {
      await _channel.invokeMethod('setStereoWidth', {'width': widthPercent});
    } catch (e) {
      debugPrint('SONIQ_DSP: setStereoWidth error: $e');
    }
  }

  Future<Map<String, double>?> setChannelBalance(double balance) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'setChannelBalance',
        {'balance': balance},
      );
      if (res != null) {
        return {
          'left': (res['left'] as num).toDouble(),
          'right': (res['right'] as num).toDouble(),
        };
      }
    } catch (e) {
      debugPrint('SONIQ_DSP: setChannelBalance error: $e');
    }
    return null;
  }

  Future<void> setLimiterEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setLimiterEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('SONIQ_DSP: setLimiterEnabled error: $e');
    }
  }

  Future<void> setVisualizerEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setVisualizerEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('SONIQ_DSP: setVisualizerEnabled error: $e');
    }
  }

  Future<String> getConnectedOutputDevice() async {
    try {
      final res = await _channel.invokeMethod<String>(
        'getConnectedOutputDevice',
      );
      return res ?? 'speaker';
    } catch (e) {
      return 'speaker';
    }
  }

  Future<bool> isCarConnected() async {
    try {
      final res = await _channel.invokeMethod<bool>('isCarConnected');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getDeviceCapabilities() async {
    try {
      return await _channel.invokeMapMethod<String, dynamic>(
        'getDeviceCapabilities',
      );
    } catch (e) {
      debugPrint('SONIQ_DSP: getDeviceCapabilities error: $e');
      return null;
    }
  }

  Future<bool> setHighRefreshRate(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<bool>('setHighRefreshRate', {
        'enabled': enabled,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('SONIQ_DSP: setHighRefreshRate error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getAudioFileSpecs(String filePath) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'getAudioFileSpecs',
        {'path': filePath},
      );
      return res;
    } catch (e) {
      debugPrint('SONIQ_DSP: getAudioFileSpecs error: $e');
      return null;
    }
  }
}
