import 'dart:convert';

class EqualizerPreset {
  final String name;
  final List<double> gains; // 10 bands (-12.0 to +12.0 dB)
  final double preamp; // in dB (-6.0 to +6.0)
  final double bass; // 0.0 to 1.0
  final double treble; // in dB (-12.0 to +12.0)
  final bool isCustom;

  const EqualizerPreset({
    required this.name,
    required this.gains,
    this.preamp = 0.0,
    this.bass = 0.0,
    this.treble = 0.0,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'gains': gains,
      'preamp': preamp,
      'bass': bass,
      'treble': treble,
      'isCustom': isCustom,
    };
  }

  factory EqualizerPreset.fromMap(Map<String, dynamic> map) {
    return EqualizerPreset(
      name: map['name'] as String,
      gains: (map['gains'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
      preamp: (map['preamp'] as num?)?.toDouble() ?? 0.0,
      bass: (map['bass'] as num?)?.toDouble() ?? 0.0,
      treble: (map['treble'] as num?)?.toDouble() ?? 0.0,
      isCustom: map['isCustom'] as bool? ?? true,
    );
  }

  String toJson() => json.encode(toMap());
  factory EqualizerPreset.fromJson(String source) => EqualizerPreset.fromMap(json.decode(source));

  static const List<EqualizerPreset> builtInPresets = [
    EqualizerPreset(
      name: 'Flat',
      gains: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      preamp: 0.0,
      bass: 0.0,
      treble: 0.0,
    ),
    EqualizerPreset(
      name: 'Pop',
      gains: [-1.0, 1.0, 2.0, 3.0, 1.5, -0.5, 1.0, 2.5, 3.5, 4.0],
      preamp: 0.0,
      bass: 0.25,
      treble: 2.0,
    ),
    EqualizerPreset(
      name: 'Rock',
      gains: [4.5, 3.0, 1.5, 0.0, -1.0, 0.0, 1.5, 3.0, 4.5, 5.0],
      preamp: 0.5,
      bass: 0.4,
      treble: 3.5,
    ),
    EqualizerPreset(
      name: 'Classical',
      gains: [3.5, 2.5, 1.5, 0.5, -0.5, -0.5, 0.5, 1.5, 2.5, 3.0],
      preamp: 0.0,
      bass: 0.2,
      treble: 1.5,
    ),
    EqualizerPreset(
      name: 'Jazz',
      gains: [2.5, 1.5, 0.0, 1.5, 2.0, 1.5, 0.5, 1.5, 2.5, 3.0],
      preamp: 0.0,
      bass: 0.25,
      treble: 2.0,
    ),
    EqualizerPreset(
      name: 'Hip-Hop',
      gains: [5.5, 4.5, 2.0, 0.5, -0.5, 0.5, 1.5, 2.0, 3.5, 4.0],
      preamp: 1.0,
      bass: 0.6,
      treble: 2.5,
    ),
    EqualizerPreset(
      name: 'Electronic',
      gains: [4.5, 3.5, 1.5, 0.0, -1.5, 1.5, 0.5, 1.5, 4.0, 4.5],
      preamp: 0.5,
      bass: 0.5,
      treble: 3.0,
    ),
    EqualizerPreset(
      name: 'Acoustic',
      gains: [3.0, 2.0, 1.0, 0.5, 1.0, 1.0, 1.5, 2.0, 2.5, 2.0],
      preamp: 0.0,
      bass: 0.15,
      treble: 1.5,
    ),
    EqualizerPreset(
      name: 'Vocal Clarity',
      gains: [-2.0, -1.5, -0.5, 1.5, 3.5, 4.0, 3.0, 1.5, 0.0, -1.0],
      preamp: 0.0,
      bass: 0.0,
      treble: 0.0,
    ),
    EqualizerPreset(
      name: 'Bass Boost',
      gains: [6.0, 5.0, 3.5, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      preamp: 1.0,
      bass: 0.75,
      treble: 0.0,
    ),
    EqualizerPreset(
      name: 'Deep Bass',
      gains: [7.0, 6.0, 4.0, 1.0, -1.0, -1.0, 0.0, 0.0, 0.0, 0.0],
      preamp: 1.5,
      bass: 0.9,
      treble: -1.0,
    ),
    EqualizerPreset(
      name: 'Treble Boost',
      gains: [0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.5, 4.0, 5.5, 6.5],
      preamp: 0.0,
      bass: 0.0,
      treble: 5.0,
    ),
    EqualizerPreset(
      name: 'Podcast',
      gains: [-3.0, -2.0, 0.0, 2.0, 3.5, 3.0, 1.5, 0.0, -1.0, -2.0],
      preamp: 0.0,
      bass: 0.0,
      treble: 0.0,
    ),
  ];

  static const List<EqualizerPreset> renaultTriberPresets = [
    EqualizerPreset(
      name: 'Renault Triber Balanced',
      gains: [4.0, 5.0, 3.0, 1.0, -0.5, 1.0, 2.5, 3.0, 3.5, 2.0],
      preamp: 0.5,
      bass: 0.55,
      treble: 2.5,
    ),
    EqualizerPreset(
      name: 'Deep Bass (Road Boost)',
      gains: [6.5, 6.0, 4.0, 1.5, 0.0, 0.0, 1.0, 1.5, 2.0, 1.0],
      preamp: 1.0,
      bass: 0.85,
      treble: 0.0,
    ),
    EqualizerPreset(
      name: 'Vocal Clarity',
      gains: [-1.0, 0.0, 1.0, 2.0, 3.0, 4.0, 4.5, 3.5, 1.5, 0.0],
      preamp: 0.0,
      bass: 0.1,
      treble: 1.5,
    ),
    EqualizerPreset(
      name: 'Pop',
      gains: [2.0, 3.5, 4.0, 2.0, 0.0, 1.5, 3.0, 4.0, 4.5, 3.5],
      preamp: 0.5,
      bass: 0.45,
      treble: 3.0,
    ),
    EqualizerPreset(
      name: 'Rock',
      gains: [4.5, 4.0, 2.5, 0.5, -0.5, 1.5, 2.5, 4.0, 4.5, 5.0],
      preamp: 0.5,
      bass: 0.5,
      treble: 3.5,
    ),
    EqualizerPreset(
      name: 'Classical',
      gains: [3.0, 2.5, 1.5, 0.5, 0.0, 0.5, 1.5, 2.5, 3.0, 3.0],
      preamp: 0.0,
      bass: 0.25,
      treble: 2.0,
    ),
    EqualizerPreset(
      name: 'Acoustic',
      gains: [2.5, 2.5, 2.0, 1.5, 1.0, 1.5, 2.0, 2.5, 2.5, 2.0],
      preamp: 0.0,
      bass: 0.2,
      treble: 1.5,
    ),
    EqualizerPreset(
      name: 'Custom',
      gains: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      preamp: 0.0,
      bass: 0.0,
      treble: 0.0,
      isCustom: true,
    ),
  ];
}
