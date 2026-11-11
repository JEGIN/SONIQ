import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/models/smart_playlist_model.dart';
import '../../../core/models/song_model.dart';
import '../../home/controllers/home_controller.dart';
import '../../library/controllers/library_controller.dart';
import '../../player/controllers/player_controller.dart';
import '../controllers/smart_playlist_controller.dart';

class SmartPlaylistGeneratorDialog extends StatefulWidget {
  final SmartPlaylistModel? existingPlaylist;

  const SmartPlaylistGeneratorDialog({super.key, this.existingPlaylist});

  static void show(BuildContext context, {SmartPlaylistModel? existingPlaylist}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmartPlaylistGeneratorDialog(existingPlaylist: existingPlaylist),
    );
  }

  @override
  State<SmartPlaylistGeneratorDialog> createState() => _SmartPlaylistGeneratorDialogState();
}

class _SmartPlaylistGeneratorDialogState extends State<SmartPlaylistGeneratorDialog> {
  final smartCtrl = Get.find<SmartPlaylistController>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late List<String> _selectedMoods;
  String? _selectedEnergy;
  String? _selectedLanguage;
  bool _favoritesOnly = false;
  int _targetSize = 30;

  final List<String> _allMoods = [
    'Love & Romance',
    'Fast Beat',
    'Sad & Emotional',
    'Chill & Relax',
    'Workout',
    'Party',
    'Motivation',
    'Focus',
    'Sleep',
    'Road Trip',
    'Melody',
    'Instrumental',
    'Devotional',
    'Tamil Melody',
    'Tamil Kuthu',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existingPlaylist;
    _nameController = TextEditingController(text: p?.name ?? 'My Smart Mix');
    _descController = TextEditingController(text: p?.description ?? '');
    _selectedMoods = p?.rules.selectedMoods.toList() ?? ['Love & Romance'];
    _selectedEnergy = p?.rules.energyLevel;
    _selectedLanguage = p?.rules.language;
    _favoritesOnly = p?.rules.favoritesOnly ?? false;
    _targetSize = p?.targetSize ?? 30;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  List<SongModel> _getLibrary() {
    if (Get.isRegistered<LibraryController>()) {
      final lib = Get.find<LibraryController>();
      if (lib.allSongs.isNotEmpty) return lib.allSongs.toList();
    }
    final cached = smartCtrl.cacheService.getCachedSongs();
    if (cached.isNotEmpty) return cached;
    if (Get.isRegistered<HomeController>()) {
      final home = Get.find<HomeController>();
      if (home.recentlyAdded.isNotEmpty) return home.recentlyAdded.toList();
    }
    if (Get.isRegistered<AudioPlayerController>()) {
      final player = Get.find<AudioPlayerController>();
      if (player.queue.isNotEmpty) return player.queue.toList();
    }
    // Auto-trigger cache load if library is empty
    if (Get.isRegistered<LibraryController>()) {
      final lib = Get.find<LibraryController>();
      if (!lib.isScanning.value && lib.allSongs.isEmpty) {
        Future.microtask(() => lib.loadCachedSongs());
      }
    }
    return [];
  }

  int _calculatePreviewCountWithLibrary(List<SongModel> library) {
    if (library.isEmpty) return 0;
    final tempRules = SmartPlaylistRules(
      selectedMoods: _selectedMoods,
      energyLevel: _selectedEnergy,
      language: _selectedLanguage,
      favoritesOnly: _favoritesOnly,
    );

    final tempPl = SmartPlaylistModel(
      id: 'temp',
      name: 'temp',
      category: _selectedMoods.isNotEmpty ? _selectedMoods.first : 'General',
      rules: tempRules,
      targetSize: -1,
      createdAt: 0,
    );

    final matches = smartCtrl.evaluatePlaylist(tempPl, library);
    return matches.length;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingPlaylist != null;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Color(0xFF141120),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.gold, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'Edit Smart Playlist Rules' : 'Create Dynamic Smart Playlist',
                    style: AppTypography.headlineMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            // Scrollable Form
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  // 1. Playlist Name
                  const Text('Playlist Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1A2B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter playlist title...',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 2. Target Moods (multi-select)
                  const Text('Target Moods & Categories (multi-select)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allMoods.map((m) {
                      final isSelected = _selectedMoods.contains(m);
                      return FilterChip(
                        label: Text(m),
                        selected: isSelected,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                        selectedColor: AppColors.gold,
                        backgroundColor: const Color(0xFF221C30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isSelected ? AppColors.gold : AppColors.border),
                        ),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedMoods.add(m);
                            } else {
                              if (_selectedMoods.length > 1) {
                                _selectedMoods.remove(m);
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 3. Energy Level
                  const Text('Energy Level', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildRadioChip('Any', null, _selectedEnergy, (val) => setState(() => _selectedEnergy = val)),
                      const SizedBox(width: 8),
                      _buildRadioChip('Low', 'low', _selectedEnergy, (val) => setState(() => _selectedEnergy = val)),
                      const SizedBox(width: 8),
                      _buildRadioChip('Medium', 'medium', _selectedEnergy, (val) => setState(() => _selectedEnergy = val)),
                      const SizedBox(width: 8),
                      _buildRadioChip('High', 'high', _selectedEnergy, (val) => setState(() => _selectedEnergy = val)),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 4. Language Filter
                  const Text('Language Filter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildRadioChip('Any', null, _selectedLanguage, (val) => setState(() => _selectedLanguage = val)),
                      const SizedBox(width: 8),
                      _buildRadioChip('Tamil', 'tamil', _selectedLanguage, (val) => setState(() => _selectedLanguage = val)),
                      const SizedBox(width: 8),
                      _buildRadioChip('Hindi', 'hindi', _selectedLanguage, (val) => setState(() => _selectedLanguage = val)),
                      const SizedBox(width: 8),
                      _buildRadioChip('English', 'english', _selectedLanguage, (val) => setState(() => _selectedLanguage = val)),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 5. Target Playlist Size
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Target Playlist Size', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('$_targetSize tracks', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                  Slider(
                    value: _targetSize.toDouble(),
                    min: 10,
                    max: 100,
                    divisions: 9,
                    activeColor: AppColors.gold,
                    inactiveColor: AppColors.surfaceHighlight,
                    onChanged: (val) {
                      setState(() => _targetSize = val.round());
                    },
                  ),

                  // 6. Favorites Only Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: AppColors.gold,
                    title: const Text('Favorites Only', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: const Text('Limit playlist to songs in your Favorites', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    value: _favoritesOnly,
                    onChanged: (val) => setState(() => _favoritesOnly = val),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Live Preview & Save Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF0E0B16),
                border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
              ),
              child: Obx(() {
                final lib = Get.isRegistered<LibraryController>()
                    ? Get.find<LibraryController>()
                    : null;
                final isScanning = lib?.isScanning.value ?? false;
                final currentLibrary = _getLibrary();
                final previewCount = _calculatePreviewCountWithLibrary(currentLibrary);

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isScanning) ...[
                            Row(
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.gold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Scanning (${lib!.scanCurrent.value}/${lib.scanTotal.value})...',
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Discovering offline tracks',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ] else if (currentLibrary.isEmpty) ...[
                            Row(
                              children: [
                                const Text(
                                  '0 tracks found',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    if (lib != null) {
                                      lib.scanLibrary();
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                                    ),
                                    child: const Text(
                                      'Scan Music',
                                      style: TextStyle(
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Tap Scan to load audio files',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ] else ...[
                            Text(
                              '$previewCount matching tracks',
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'From ${currentLibrary.length} songs in library',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isScanning ? null : _savePlaylist,
                      child: Text(
                        isEditing ? 'Save Rules' : 'Create Smart Playlist',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioChip(String label, String? value, String? current, Function(String?) onSelected) {
    final isSelected = current == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : const Color(0xFF221C30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.gold : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _savePlaylist() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final rules = SmartPlaylistRules(
      selectedMoods: _selectedMoods,
      energyLevel: _selectedEnergy,
      language: _selectedLanguage,
      favoritesOnly: _favoritesOnly,
    );

    if (widget.existingPlaylist != null) {
      final p = widget.existingPlaylist!;
      p.name = name;
      p.category = _selectedMoods.isNotEmpty ? _selectedMoods.first : p.category;
      p.rules = rules;
      p.targetSize = _targetSize;
      p.updatedAt = DateTime.now().millisecondsSinceEpoch;
      Navigator.pop(context);
      await smartCtrl.saveSmartPlaylist(p);
      Get.snackbar('Rules Updated', 'Smart Playlist "${p.name}" rules updated.');
    } else {
      final newPl = SmartPlaylistModel(
        id: 'smart_pl_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        category: _selectedMoods.isNotEmpty ? _selectedMoods.first : 'General',
        rules: rules,
        targetSize: _targetSize,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      Navigator.pop(context);
      await smartCtrl.saveSmartPlaylist(newPl);
      Get.snackbar('Smart Playlist Created', 'Dynamic playlist "$name" is ready.');
    }
  }
}
