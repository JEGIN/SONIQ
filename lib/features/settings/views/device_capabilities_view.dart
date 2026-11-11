import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/services/audio_dsp_service.dart';
import '../../../core/utils/file_utils.dart';
import '../../library/controllers/library_controller.dart';

class DeviceCapabilitiesView extends StatefulWidget {
  const DeviceCapabilitiesView({super.key});

  @override
  State<DeviceCapabilitiesView> createState() => _DeviceCapabilitiesViewState();
}

class _DeviceCapabilitiesViewState extends State<DeviceCapabilitiesView> {
  final AudioDspService _dspService = AudioDspService();
  late Future<Map<String, dynamic>?> _deviceFuture;

  @override
  void initState() {
    super.initState();
    _deviceFuture = _dspService.getDeviceCapabilities();
  }

  @override
  Widget build(BuildContext context) {
    final library = Get.find<LibraryController>();
    final songs = library.allSongs;
    final totalBytes = songs.fold<int>(0, (sum, song) => sum + song.sizeBytes);
    final localFormats =
        songs
            .map((song) => song.fileExtension.toLowerCase())
            .where((format) => format.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Device Capabilities',
          style: AppTypography.headlineMedium,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh device details',
            onPressed: () => setState(
              () => _deviceFuture = _dspService.getDeviceCapabilities(),
            ),
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _deviceFuture,
        builder: (context, snapshot) {
          final details = snapshot.data ?? const <String, dynamic>{};
          final codecs =
              (details['decoderMimeTypes'] as List?)
                  ?.map((e) => e.toString().toLowerCase())
                  .toSet() ??
              <String>{};
          final outputs =
              (details['outputs'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              <String>[];
          final decoderNames =
              (details['decoderNames'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              <String>[];
          final currentOutput = (details['currentOutput'] ?? 'speaker')
              .toString();
          final displayRate = (details['refreshRate'] as num?)?.toDouble();
          final maxDisplayRate = (details['maxRefreshRate'] as num?)
              ?.toDouble();

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _readinessCard(songs.length, localFormats),
              const SizedBox(height: 14),
              _sectionTitle('LOCAL MUSIC STORAGE'),
              _infoCard([
                _infoRow(
                  Icons.library_music_rounded,
                  'Indexed songs',
                  '${songs.length}',
                ),
                _infoRow(
                  Icons.storage_rounded,
                  'Library size',
                  FileUtils.formatBytes(totalBytes),
                ),
                _infoRow(
                  Icons.offline_pin_rounded,
                  'Offline ready',
                  songs.isEmpty
                      ? 'No local tracks indexed'
                      : 'Available without a network connection',
                ),
              ]),
              const SizedBox(height: 14),
              _sectionTitle('PLAYBACK PATH'),
              _infoCard([
                _infoRow(
                  Icons.route_rounded,
                  'Audio path',
                  'Local file → system audio output',
                ),
                _infoRow(
                  Icons.speaker_group_rounded,
                  'Current output',
                  _formatOutput(currentOutput),
                ),
                _infoRow(
                  Icons.surround_sound_rounded,
                  'Detected outputs',
                  outputs.isEmpty
                      ? _formatOutput(currentOutput)
                      : outputs.map(_formatOutput).toSet().join(' • '),
                ),
              ]),
              const SizedBox(height: 14),
              _sectionTitle('OFFLINE-READY FORMATS'),
              _infoCard([
                if (localFormats.isEmpty)
                  _infoRow(
                    Icons.info_outline_rounded,
                    'Formats',
                    'Scan local music to see available formats',
                  )
                else
                  _infoRow(
                    Icons.music_note_rounded,
                    'On this device',
                    localFormats
                        .map((format) => format.toUpperCase())
                        .join(' • '),
                  ),
                _infoRow(
                  Icons.check_circle_rounded,
                  'Player formats',
                  FileUtils.supportedAudioExtensions
                      .map((format) => format.toUpperCase())
                      .join(' • '),
                ),
              ]),
              const SizedBox(height: 14),
              _sectionTitle('DEVICE FORMAT CAPABILITIES'),
              _formatCard(codecs),
              const SizedBox(height: 14),
              _sectionTitle('HARDWARE DECODERS'),
              _infoCard([
                if (snapshot.connectionState == ConnectionState.waiting)
                  _infoRow(
                    Icons.hourglass_top_rounded,
                    'Status',
                    'Checking device decoders…',
                  )
                else if (decoderNames.isEmpty)
                  _infoRow(
                    Icons.info_outline_rounded,
                    'Status',
                    'Decoder details are unavailable on this platform',
                  )
                else
                  _infoRow(
                    Icons.memory_rounded,
                    'Detected',
                    '${decoderNames.length} audio decoder${decoderNames.length == 1 ? '' : 's'}',
                  ),
                if (decoderNames.isNotEmpty)
                  _infoRow(
                    Icons.graphic_eq_rounded,
                    'Examples',
                    decoderNames.take(4).join(' • '),
                  ),
              ]),
              const SizedBox(height: 14),
              _sectionTitle('DEVICE INFO'),
              _infoCard([
                _infoRow(
                  Icons.phone_android_rounded,
                  'Device',
                  _deviceName(details),
                ),
                _infoRow(
                  Icons.devices_rounded,
                  'Platform',
                  (details['platform'] ?? defaultTargetPlatform.name)
                      .toString(),
                ),
                _infoRow(
                  Icons.monitor_rounded,
                  'Display refresh',
                  _refreshRateLabel(displayRate, maxDisplayRate),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  _infoRow(
                    Icons.sync_rounded,
                    'Status',
                    'Reading device details…',
                  ),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _readinessCard(int songCount, List<String> formats) {
    final ready = songCount > 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF172D28), Color(0xFF171A22)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (ready ? AppColors.cyan : AppColors.gold).withValues(
            alpha: 0.45,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ready ? Icons.check_circle_rounded : Icons.music_off_rounded,
            color: ready ? AppColors.cyan : AppColors.gold,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready ? 'Ready for playback' : 'Ready to scan',
                  style: AppTypography.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  ready
                      ? '$songCount local songs · ${formats.map((e) => e.toUpperCase()).toSet().join(', ')}'
                      : 'Scan your local library to check tracks and formats',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatCard(Set<String> codecs) {
    const formats = <String, List<String>>{
      'MP3': ['audio/mpeg', 'audio/mpeg-l2'],
      'M4A': ['audio/mp4a-latm', 'audio/mp4'],
      'AAC': ['audio/aac', 'audio/mp4a-latm'],
      'WAV': ['audio/raw', 'audio/wav', 'audio/x-wav'],
      'FLAC': ['audio/flac'],
      'OGG': ['audio/vorbis', 'audio/opus', 'audio/ogg'],
    };
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: formats.entries.map((entry) {
          final supported = codecs.isEmpty
              ? null
              : entry.value.any(codecs.contains);
          return Column(
            children: [
              ListTile(
                dense: true,
                leading: Icon(
                  supported == null
                      ? Icons.help_outline_rounded
                      : supported
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: supported == null
                      ? AppColors.textMuted
                      : supported
                      ? Colors.greenAccent
                      : Colors.redAccent,
                  size: 21,
                ),
                title: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: Text(
                  supported == null
                      ? 'Not reported'
                      : supported
                      ? 'Supported'
                      : 'No decoder found',
                  style: TextStyle(
                    fontSize: 11,
                    color: supported == null
                        ? AppColors.textMuted
                        : supported
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                ),
              ),
              if (entry.key != formats.keys.last)
                const Divider(color: AppColors.border, height: 1, indent: 56),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );

  Widget _infoCard(List<Widget> rows) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: rows),
  );

  Widget _infoRow(IconData icon, String label, String value) => ListTile(
    dense: true,
    leading: Icon(icon, color: AppColors.primary, size: 20),
    title: Text(
      label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      value,
      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
    ),
  );

  String _deviceName(Map<String, dynamic> details) {
    final manufacturer = (details['manufacturer'] ?? '').toString().trim();
    final model = (details['model'] ?? '').toString().trim();
    final name = '$manufacturer $model'.trim();
    return name.isEmpty ? 'Device details unavailable' : name;
  }

  String _refreshRateLabel(double? current, double? maximum) {
    if (current == null) return 'Unavailable';
    final currentText = '${current.toStringAsFixed(0)} Hz';
    if (maximum == null || maximum <= current) return currentText;
    return '$currentText · up to ${maximum.toStringAsFixed(0)} Hz';
  }

  String _formatOutput(String type) {
    switch (type) {
      case 'wired_headphones':
        return 'Wired headphones';
      case 'bluetooth':
        return 'Bluetooth';
      case 'usb':
        return 'USB audio';
      case 'cast':
        return 'Cast / HDMI';
      case 'car':
        return 'Car audio';
      default:
        return 'Device speaker';
    }
  }
}
