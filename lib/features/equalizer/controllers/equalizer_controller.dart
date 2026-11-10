import 'dart:async';
import 'package:get/get.dart';
import '../../../core/database/song_cache_service.dart';
import '../../../core/models/equalizer_preset_model.dart';
import '../../../core/services/audio_dsp_service.dart';

class EqualizerController extends GetxController {
  final AudioDspService dspService = AudioDspService();
  final SongCacheService cacheService = SongCacheService();

  // 10 Band Frequencies in Hz
  static const List<int> bandFrequencies = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000
  ];

  static const List<String> bandLabels = [
    '31', '62', '125', '250', '500', '1K', '2K', '4K', '8K', '16K'
  ];

  final RxBool isEqualizerEnabled = true.obs;
  final RxList<double> gains = <double>[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0].obs;
  final RxDouble preamp = 0.0.obs; // -6.0 to +6.0 dB
  final RxDouble bassBoost = 0.0.obs; // 0.0 to 1.0
  final RxDouble treble = 0.0.obs; // -12.0 to +12.0 dB
  final RxDouble virtualizer = 0.0.obs; // 0.0 to 1.0
  final RxInt stereoWidth = 100.obs; // 0 to 150%
  final RxDouble balance = 0.0.obs; // -1.0 to +1.0
  final RxString spatialMode = 'stereo'.obs; // mono, stereo, wide_stereo, virtual_surround, headphone_spatial
  final RxBool isLimiterEnabled = true.obs;

  final Rx<EqualizerPreset> currentPreset = EqualizerPreset.builtInPresets.first.obs;
  final RxList<EqualizerPreset> customPresets = <EqualizerPreset>[].obs;

  final RxList<double> spectrumMagnitudes = List.generate(16, (_) => 0.0).obs;
  final RxString connectedDevice = 'speaker'.obs;
  final RxString activeProfile = 'speaker'.obs; // speaker, headphones, bluetooth, renault_triber
  final RxBool isCarMode = false.obs;
  final RxBool isRoadNoiseCompensationEnabled = true.obs;

  List<EqualizerPreset> get availablePresets {
    if (activeProfile.value == 'renault_triber') {
      return [...EqualizerPreset.renaultTriberPresets, ...customPresets];
    }
    return [...EqualizerPreset.builtInPresets, ...customPresets];
  }

  StreamSubscription? _visualizerSub;
  StreamSubscription? _deviceSub;

  @override
  void onInit() {
    super.onInit();
    _loadSavedSettings();
    _initStreams();
  }

  void _initStreams() {
    // 60fps Visualizer Stream
    _visualizerSub = dspService.visualizerStream.listen((mags) {
      if (mags.isNotEmpty && isEqualizerEnabled.value) {
        spectrumMagnitudes.assignAll(mags);
      }
    });

    // Hardware Audio Device Route Stream
    _deviceSub = dspService.deviceStream.listen((device) {
      connectedDevice.value = device;
      _adaptDspForDevice(device);
    });

    dspService.getConnectedOutputDevice().then((dev) {
      connectedDevice.value = dev;
      _adaptDspForDevice(dev);
    });
  }

  void _adaptDspForDevice(String device) {
    if (device == 'car') {
      isCarMode.value = true;
      switchAudioProfile('renault_triber');
      dspService.setVirtualizerMode('transaural');
    } else if (device == 'wired_headphones') {
      isCarMode.value = false;
      if (activeProfile.value == 'renault_triber') switchAudioProfile('headphones');
      dspService.setVirtualizerMode('binaural');
    } else if (device == 'bluetooth') {
      isCarMode.value = false;
      if (activeProfile.value == 'renault_triber') switchAudioProfile('bluetooth');
      dspService.setVirtualizerMode('binaural');
    } else {
      isCarMode.value = false;
      if (activeProfile.value == 'renault_triber') switchAudioProfile('speaker');
      dspService.setVirtualizerMode('transaural');
    }
  }

  void switchAudioProfile(String profileId) {
    if (activeProfile.value == profileId) return;

    // 1. Save current profile state
    _saveProfileSettings(activeProfile.value);

    // 2. Set new profile
    activeProfile.value = profileId;
    cacheService.setSetting('active_audio_profile', profileId);

    // 3. Load target profile state
    _loadProfileSettings(profileId);
  }

  void _saveProfileSettings(String profile) {
    cacheService.setSetting('profile_${profile}_preset', currentPreset.value.name);
    cacheService.setSetting('profile_${profile}_gains', gains.toList());
    cacheService.setSetting('profile_${profile}_preamp', preamp.value);
    cacheService.setSetting('profile_${profile}_bass', bassBoost.value);
    cacheService.setSetting('profile_${profile}_treble', treble.value);
    cacheService.setSetting('profile_${profile}_spatial', spatialMode.value);
  }

  void _loadProfileSettings(String profile) {
    if (profile == 'renault_triber') {
      final savedPresetName = cacheService.getSetting(
        'profile_renault_triber_preset',
        defaultValue: 'Renault Triber Balanced',
      );
      final match = [...EqualizerPreset.renaultTriberPresets, ...customPresets].firstWhere(
        (p) => p.name == savedPresetName,
        orElse: () => EqualizerPreset.renaultTriberPresets.first,
      );
      applyPreset(match);
      setSpatialMode('virtual_surround');
      if (isRoadNoiseCompensationEnabled.value) {
        setBassBoost((bassBoost.value + 0.1).clamp(0.0, 1.0));
      }
    } else {
      final savedPresetName = cacheService.getSetting(
        'profile_${profile}_preset',
        defaultValue: 'Flat',
      );
      final match = [...EqualizerPreset.builtInPresets, ...customPresets].firstWhere(
        (p) => p.name == savedPresetName,
        orElse: () => EqualizerPreset.builtInPresets.first,
      );
      applyPreset(match);
      if (profile == 'headphones') {
        setSpatialMode('headphone_spatial');
      } else {
        setSpatialMode('stereo');
      }
    }
  }

  void toggleRoadNoiseCompensation([bool? state]) {
    isRoadNoiseCompensationEnabled.value = state ?? !isRoadNoiseCompensationEnabled.value;
    cacheService.setSetting('road_noise_comp', isRoadNoiseCompensationEnabled.value);
    if (activeProfile.value == 'renault_triber') {
      if (isRoadNoiseCompensationEnabled.value) {
        setBassBoost((bassBoost.value + 0.15).clamp(0.0, 1.0));
        dspService.setLimiterEnabled(true);
      } else {
        setBassBoost((bassBoost.value - 0.15).clamp(0.0, 1.0));
      }
    }
  }

  void _loadSavedSettings() {
    try {
      final enabled = cacheService.getSetting('eq_enabled', defaultValue: true);
      isEqualizerEnabled.value = enabled;

      final savedGains = cacheService.getSetting('eq_gains');
      if (savedGains is List) {
        final loaded = savedGains.map((e) => (e as num).toDouble()).toList();
        if (loaded.length == 10) gains.assignAll(loaded);
      }

      preamp.value = (cacheService.getSetting('eq_preamp', defaultValue: 0.0) as num).toDouble();
      bassBoost.value = (cacheService.getSetting('eq_bass', defaultValue: 0.0) as num).toDouble();
      treble.value = (cacheService.getSetting('eq_treble', defaultValue: 0.0) as num).toDouble();
      virtualizer.value = (cacheService.getSetting('eq_virtualizer', defaultValue: 0.0) as num).toDouble();
      stereoWidth.value = (cacheService.getSetting('eq_stereo_width', defaultValue: 100) as num).toInt();
      balance.value = (cacheService.getSetting('eq_balance', defaultValue: 0.0) as num).toDouble();
      spatialMode.value = cacheService.getSetting('eq_spatial_mode', defaultValue: 'stereo') as String;
      isLimiterEnabled.value = cacheService.getSetting('eq_limiter', defaultValue: true);

      // Load custom presets
      final savedPresets = cacheService.getSetting('eq_custom_presets');
      if (savedPresets is List) {
        customPresets.assignAll(
          savedPresets.map((p) => EqualizerPreset.fromJson(p.toString())).toList(),
        );
      }

      final presetName = cacheService.getSetting('eq_preset_name', defaultValue: 'Flat');
      final match = [...EqualizerPreset.builtInPresets, ...customPresets].firstWhere(
        (p) => p.name == presetName,
        orElse: () => EqualizerPreset.builtInPresets.first,
      );
      currentPreset.value = match;

      _syncAllToDsp();
    } catch (_) {}
  }

  void _syncAllToDsp() {
    dspService.setEqualizerEnabled(isEqualizerEnabled.value);
    dspService.set10BandGains(gains);
    dspService.setPreamp(preamp.value);
    dspService.setBassBoost((bassBoost.value * 1000).toInt());
    dspService.setTrebleBoost(treble.value);
    dspService.setVirtualizerStrength((virtualizer.value * 1000).toInt());
    dspService.setStereoWidth(stereoWidth.value);
    dspService.setChannelBalance(balance.value);
    dspService.setLimiterEnabled(isLimiterEnabled.value);
  }

  void toggleEqualizer([bool? state]) {
    isEqualizerEnabled.value = state ?? !isEqualizerEnabled.value;
    dspService.setEqualizerEnabled(isEqualizerEnabled.value);
    cacheService.setSetting('eq_enabled', isEqualizerEnabled.value);
    if (!isEqualizerEnabled.value) {
      spectrumMagnitudes.assignAll(List.generate(16, (_) => 0.0));
    }
  }

  void setBandGain(int bandIndex, double gainDb) {
    if (bandIndex >= 0 && bandIndex < 10) {
      gains[bandIndex] = gainDb.clamp(-12.0, 12.0);
      dspService.setBandGain(bandIndex, gains[bandIndex]);
      _markPresetCustom();
      _saveGains();
    }
  }

  void setPreamp(double gainDb) {
    preamp.value = gainDb.clamp(-6.0, 6.0);
    dspService.setPreamp(preamp.value);
    cacheService.setSetting('eq_preamp', preamp.value);
    _markPresetCustom();
  }

  void setBassBoost(double val) {
    bassBoost.value = val.clamp(0.0, 1.0);
    dspService.setBassBoost((bassBoost.value * 1000).toInt());
    cacheService.setSetting('eq_bass', bassBoost.value);
    _markPresetCustom();
  }

  void setTreble(double gainDb) {
    treble.value = gainDb.clamp(-12.0, 12.0);
    dspService.setTrebleBoost(treble.value);
    cacheService.setSetting('eq_treble', treble.value);
    _markPresetCustom();
  }

  void setVirtualizer(double val) {
    virtualizer.value = val.clamp(0.0, 1.0);
    dspService.setVirtualizerStrength((virtualizer.value * 1000).toInt());
    cacheService.setSetting('eq_virtualizer', virtualizer.value);
  }

  void setStereoWidth(int width) {
    stereoWidth.value = width.clamp(0, 150);
    dspService.setStereoWidth(stereoWidth.value);
    cacheService.setSetting('eq_stereo_width', stereoWidth.value);
  }

  void setBalance(double val) {
    balance.value = val.clamp(-1.0, 1.0);
    dspService.setChannelBalance(balance.value);
    cacheService.setSetting('eq_balance', balance.value);
  }

  void setSpatialMode(String mode) {
    spatialMode.value = mode;
    cacheService.setSetting('eq_spatial_mode', mode);

    switch (mode) {
      case 'mono':
        setStereoWidth(0);
        setVirtualizer(0.0);
        break;
      case 'stereo':
        setStereoWidth(100);
        setVirtualizer(0.0);
        break;
      case 'wide_stereo':
        setStereoWidth(135);
        setVirtualizer(0.35);
        break;
      case 'virtual_surround':
        setStereoWidth(140);
        setVirtualizer(0.75);
        dspService.setVirtualizerMode('transaural');
        break;
      case 'headphone_spatial':
        setStereoWidth(125);
        setVirtualizer(0.65);
        dspService.setVirtualizerMode('binaural');
        break;
    }
  }

  void toggleLimiter([bool? state]) {
    isLimiterEnabled.value = state ?? !isLimiterEnabled.value;
    dspService.setLimiterEnabled(isLimiterEnabled.value);
    cacheService.setSetting('eq_limiter', isLimiterEnabled.value);
  }

  void applyPreset(EqualizerPreset preset) {
    currentPreset.value = preset;
    gains.assignAll(preset.gains);
    preamp.value = preset.preamp;
    bassBoost.value = preset.bass;
    treble.value = preset.treble;

    dspService.set10BandGains(gains);
    dspService.setPreamp(preamp.value);
    dspService.setBassBoost((bassBoost.value * 1000).toInt());
    dspService.setTrebleBoost(treble.value);

    cacheService.setSetting('eq_preset_name', preset.name);
    _saveGains();
  }

  void saveCustomPreset(String name) {
    final newPreset = EqualizerPreset(
      name: name.trim(),
      gains: List.from(gains),
      preamp: preamp.value,
      bass: bassBoost.value,
      treble: treble.value,
      isCustom: true,
    );

    customPresets.removeWhere((p) => p.name.toLowerCase() == name.trim().toLowerCase());
    customPresets.add(newPreset);
    currentPreset.value = newPreset;

    _persistCustomPresets();
    cacheService.setSetting('eq_preset_name', name.trim());
  }

  void deleteCustomPreset(String name) {
    customPresets.removeWhere((p) => p.name == name);
    _persistCustomPresets();
    if (currentPreset.value.name == name) {
      applyPreset(EqualizerPreset.builtInPresets.first);
    }
  }

  void renameCustomPreset(String oldName, String newName) {
    final cleanNewName = newName.trim();
    if (cleanNewName.isEmpty || oldName == cleanNewName) return;

    final index = customPresets.indexWhere((p) => p.name == oldName);
    if (index >= 0) {
      final oldPreset = customPresets[index];
      final updated = EqualizerPreset(
        name: cleanNewName,
        gains: List.from(oldPreset.gains),
        preamp: oldPreset.preamp,
        bass: oldPreset.bass,
        treble: oldPreset.treble,
        isCustom: true,
      );
      customPresets[index] = updated;
      if (currentPreset.value.name == oldName) {
        currentPreset.value = updated;
        cacheService.setSetting('eq_preset_name', cleanNewName);
      }
      _persistCustomPresets();
    }
  }

  void resetToFlat() {
    applyPreset(EqualizerPreset.builtInPresets.first);
  }

  void _markPresetCustom() {
    if (!currentPreset.value.isCustom && currentPreset.value.name != 'Custom') {
      currentPreset.value = const EqualizerPreset(
        name: 'Custom',
        gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        isCustom: true,
      );
      cacheService.setSetting('eq_preset_name', 'Custom');
    }
  }

  void _saveGains() {
    cacheService.setSetting('eq_gains', gains.toList());
  }

  void _persistCustomPresets() {
    final list = customPresets.map((p) => p.toJson()).toList();
    cacheService.setSetting('eq_custom_presets', list);
  }

  @override
  void onClose() {
    _visualizerSub?.cancel();
    _deviceSub?.cancel();
    super.onClose();
  }
}
