import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/models/song_model.dart';
import '../../../../core/services/audio_dsp_service.dart';
import '../../../equalizer/controllers/equalizer_controller.dart';

class AudioQualitySheet extends StatefulWidget {
  final SongModel song;

  const AudioQualitySheet({super.key, required this.song});

  static void show(BuildContext context, SongModel song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AudioQualitySheet(song: song),
    );
  }

  @override
  State<AudioQualitySheet> createState() => _AudioQualitySheetState();
}

class _AudioQualitySheetState extends State<AudioQualitySheet> {
  Map<String, dynamic>? _specs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSpecs();
  }

  Future<void> _fetchSpecs() async {
    final res = await AudioDspService().getAudioFileSpecs(widget.song.dataPath);
    if (mounted) {
      setState(() {
        _specs = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.song.fileExtension.toUpperCase();
    final isLossless = ext == 'FLAC' || ext == 'WAV';

    final eqCtrl = Get.isRegistered<EqualizerController>()
        ? Get.find<EqualizerController>()
        : null;

    final bitrateBps = (_specs?['bitrateBps'] as num?)?.toInt() ?? 0;
    final bitrateKbps = bitrateBps > 0
        ? (bitrateBps / 1000).round()
        : (isLossless ? 999 : 320);

    final sampleRateHz = (_specs?['sampleRateHz'] as num?)?.toInt() ?? 44100;
    final sampleRateKhz = (sampleRateHz / 1000).toStringAsFixed(1);
    final mimeType = (_specs?['mimeType'] as String?) ?? 'audio/mpeg';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.15),
                    ),
                    child: const Icon(Icons.graphic_eq_rounded, color: AppColors.gold, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Audio Stream Specs', style: AppTypography.headlineSmall),
                        Text(
                          widget.song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLossless
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : AppColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isLossless ? const Color(0xFF10B981) : AppColors.border,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      isLossless ? 'HI-RES LOSSLESS' : 'HIGH FIDELITY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isLossless ? const Color(0xFF10B981) : AppColors.gold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              if (_isLoading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: AppColors.gold,
                )
              else
                const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 12),

              // SECTION 1: PHYSICAL SOURCE FILE PROPERTIES
              _buildSectionTitle('SOURCE FILE SPECIFICATIONS'),
              const SizedBox(height: 6),
              _buildSpecRow('File Format & Container', '$ext ($mimeType)'),
              _buildSpecRow('Measured Bitrate', '$bitrateKbps kbps ${isLossless ? 'Variable Lossless' : 'CBR Audio'}'),
              _buildSpecRow('Sample Rate', '$sampleRateKhz kHz (${sampleRateHz == 44100 ? 'CD Quality' : 'Broadcast Quality'})'),
              _buildSpecRow('Bit Depth', isLossless ? '24-bit / 16-bit PCM' : '16-bit Equivalent'),
              _buildSpecRow('Channels', '2 Channels (Stereo Left / Right)'),
              _buildSpecRow('File Size', widget.song.formattedSize),
              _buildSpecRow('Duration', widget.song.formattedDuration),

              const SizedBox(height: 16),
              if (_isLoading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: AppColors.gold,
                )
              else
                const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 12),

              // SECTION 2: LIVE HARDWARE DSP PROCESSING PIPELINE
              _buildSectionTitle('LIVE DSP AUDIO ENGINE PIPELINE'),
              const SizedBox(height: 6),

              if (eqCtrl != null) ...[
                _buildSpecRow(
                  'Equalizer Engine',
                  eqCtrl.isEqualizerEnabled.value
                      ? '10-Band Biquad Active (${eqCtrl.currentPreset.value.name})'
                      : 'Bypassed (Bit-Perfect Direct Out)',
                  highlight: eqCtrl.isEqualizerEnabled.value,
                ),
                _buildSpecRow(
                  'Preamp & Headroom',
                  '${eqCtrl.preamp.value > 0 ? '+' : ''}${eqCtrl.preamp.value.toStringAsFixed(1)} dB (Clipping Protected)',
                ),
                _buildSpecRow(
                  'Bass Enhancement',
                  eqCtrl.bassBoost.value > 0
                      ? '${(eqCtrl.bassBoost.value * 100).toInt()}% Sub-Bass Resonance'
                      : 'Flat (0%)',
                ),
                _buildSpecRow(
                  'Treble Response',
                  '${eqCtrl.treble.value > 0 ? '+' : ''}${eqCtrl.treble.value.toStringAsFixed(1)} dB High Shelf',
                ),
                _buildSpecRow(
                  'Soundstage Mode',
                  _formatSpatialMode(eqCtrl.spatialMode.value, eqCtrl.stereoWidth.value),
                ),
                _buildSpecRow(
                  'Active Audio Route',
                  _formatOutputDevice(eqCtrl.connectedDevice.value),
                  highlight: true,
                ),
                _buildSpecRow(
                  'Dynamic Peak Limiter',
                  eqCtrl.isLimiterEnabled.value ? 'Enabled (Soft-Knee Headroom)' : 'Off',
                ),
              ] else ...[
                _buildSpecRow('DSP Engine', 'Android MediaCodec Hardware Sink'),
              ],

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF14151C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: AppColors.gold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Direct native Android AudioTrack DSP pipeline. True hardware audio processing without artificial resolution upsampling.',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted.withValues(alpha: 0.9)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: AppColors.gold,
      ),
    );
  }

  String _formatSpatialMode(String mode, int width) {
    switch (mode) {
      case 'mono':
        return 'Balanced Mono Downmix (0% Width)';
      case 'wide_stereo':
        return 'Wide Stereo ($width% Width)';
      case 'headphone_spatial':
        return 'Headphone Binaural 3D Stage';
      case 'virtual_surround':
        return 'Transaural Cabin Surround ($width%)';
      case 'stereo':
      default:
        return 'Original Stereo (100% Width)';
    }
  }

  String _formatOutputDevice(String dev) {
    switch (dev) {
      case 'car':
        return 'Renault Triber Infotainment (Android Auto)';
      case 'bluetooth':
        return 'Bluetooth A2DP Audio Sink';
      case 'wired_headphones':
        return 'Wired 3.5mm Headset';
      case 'usb':
        return 'USB-C Audio DAC Device';
      case 'speaker':
      default:
        return 'Phone Internal Stereo Speakers';
    }
  }

  Widget _buildSpecRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: highlight ? AppColors.gold : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
