import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/models/song_model.dart';
import '../../../core/services/audio_scanner_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/artwork_cache_service.dart';
import '../../../core/database/song_cache_service.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/search_normalizer.dart';
import '../../playlists/controllers/favorites_controller.dart';

enum LibraryFilterTab { songs, artists, albums, folders }

enum SongSortOption {
  titleAsc,
  titleDesc,
  artistAsc,
  artistDesc,
  dateAddedDesc,
  dateAddedAsc,
  durationAsc,
  durationDesc,
}

extension SongSortOptionExtension on SongSortOption {
  String get label {
    switch (this) {
      case SongSortOption.titleAsc:
        return 'Title: A to Z';
      case SongSortOption.titleDesc:
        return 'Title: Z to A';
      case SongSortOption.artistAsc:
        return 'Artist: A to Z';
      case SongSortOption.artistDesc:
        return 'Artist: Z to A';
      case SongSortOption.dateAddedDesc:
        return 'Recently Added';
      case SongSortOption.dateAddedAsc:
        return 'Oldest Added';
      case SongSortOption.durationAsc:
        return 'Duration: Shortest First';
      case SongSortOption.durationDesc:
        return 'Duration: Longest First';
    }
  }

  String get subtitle {
    switch (this) {
      case SongSortOption.titleAsc:
        return 'Alphabetical from A to Z';
      case SongSortOption.titleDesc:
        return 'Reverse alphabetical from Z to A';
      case SongSortOption.artistAsc:
        return 'Artist name from A to Z';
      case SongSortOption.artistDesc:
        return 'Artist name from Z to A';
      case SongSortOption.dateAddedDesc:
        return 'Newest downloaded tracks first';
      case SongSortOption.dateAddedAsc:
        return 'Earliest added tracks first';
      case SongSortOption.durationAsc:
        return 'Quick tracks to long tracks';
      case SongSortOption.durationDesc:
        return 'Longest tracks first';
    }
  }
}

class LibraryController extends GetxController {
  final AudioScannerService scannerService = AudioScannerService();
  final SongCacheService cacheService = SongCacheService();

  final RxList<SongModel> allSongs = <SongModel>[].obs;
  final RxList<SongModel> filteredSongs = <SongModel>[].obs;

  final Rx<LibraryFilterTab> activeTab = LibraryFilterTab.songs.obs;
  final Rx<SongSortOption> sortOption = SongSortOption.titleAsc.obs;

  final RxString searchQuery = ''.obs;
  final RxBool isScanning = false.obs;
  final RxInt scanCurrent = 0.obs;
  final RxInt scanTotal = 0.obs;

  // Grouped maps
  final RxMap<String, List<SongModel>> artistsMap =
      <String, List<SongModel>>{}.obs;
  final RxMap<String, List<SongModel>> albumsMap =
      <String, List<SongModel>>{}.obs;
  final RxMap<String, List<SongModel>> foldersMap =
      <String, List<SongModel>>{}.obs;

  @override
  void onInit() {
    super.onInit();
    PermissionService.ensureNotificationPermission();
    _loadSavedSortOption();
    loadCachedSongs();
    debounce(
      searchQuery,
      (_) => applyFiltersAndSorting(),
      time: const Duration(milliseconds: 200),
    );
  }

  void _loadSavedSortOption() {
    final saved = cacheService.getSetting(
      'library_sort_option',
      defaultValue: 'titleAsc',
    );
    final match = SongSortOption.values.firstWhere(
      (opt) => opt.name == saved,
      orElse: () => SongSortOption.titleAsc,
    );
    sortOption.value = match;
  }

  void loadCachedSongs() {
    final cached = cacheService.getCachedSongs();
    final favIds = cacheService.getFavoriteSongIds().toSet();
    for (final s in cached) {
      if (favIds.contains(s.id)) {
        s.isFavorite = true;
      }
    }

    if (cached.isNotEmpty) {
      // Auto-cleanse recordings from existing cache if filter is active
      final skipRecordings = cacheService.isSkipRecordingsEnabled();
      final sanitized = cached.where((s) {
        if (cacheService.isPathExcluded(s.dataPath)) return false;
        if (!skipRecordings) return true;
        return !AudioScannerService.isIgnoredRecordingOrSystemAudio(
          filePath: s.dataPath,
          title: s.title,
          artist: s.artist,
          album: s.album,
          durationMs: s.durationMs,
        );
      }).toList();

      if (sanitized.length != cached.length) {
        cacheService.saveSongs(sanitized);
        debugPrint(
          'SONIQ: Cleansed ${cached.length - sanitized.length} recording files from library cache.',
        );
      }

      allSongs.assignAll(sanitized);
      _rebuildGroupings();
      applyFiltersAndSorting();
      ArtworkCacheService().prewarmArtworkCache(allSongs);
    } else {
      scanLibrary();
    }
  }

  Future<void> scanLibrary() async {
    isScanning.value = true;
    scanCurrent.value = 0;
    scanTotal.value = 0;

    try {
      final songs = await scannerService.scanAudioFiles(
        onProgress: (current, total) {
          scanCurrent.value = current;
          scanTotal.value = total;
        },
      );
      allSongs.assignAll(songs);
      _rebuildGroupings();
      applyFiltersAndSorting();
      ArtworkCacheService().prewarmArtworkCache(allSongs);

      if (Get.isRegistered<FavoritesController>()) {
        Get.find<FavoritesController>().loadFavorites();
      }
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> importFolder() async {
    try {
      final selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select your SONGS or Music folder',
      );
      if (selectedDirectory == null || selectedDirectory.isEmpty) return;

      isScanning.value = true;
      final sourceDir = Directory(selectedDirectory);
      if (!await sourceDir.exists()) {
        isScanning.value = false;
        return;
      }

      // Copy into app Documents folder so files are permanently accessible in iOS sandbox
      final appDocDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${appDocDir.path}/Songs');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      int count = 0;
      await for (final entity in sourceDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && FileUtils.isSupportedAudioFile(entity.path)) {
          final relPath = entity.path.substring(sourceDir.path.length);
          final destFile = File('${targetDir.path}$relPath');
          await destFile.parent.create(recursive: true);
          await entity.copy(destFile.path);
          count++;
        }
      }

      // Also remember this directory in customDirectories
      await cacheService.addCustomDirectory(selectedDirectory);

      await scanLibrary();

      Get.snackbar(
        'Import Complete',
        'Successfully imported $count songs to your library.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E202B),
        colorText: Colors.white,
      );
    } catch (e) {
      debugPrint('Error importing folder: $e');
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> importAudioFiles() async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.audio,
      );
      if (pickedFiles.isEmpty) return;

      isScanning.value = true;
      final appDocDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${appDocDir.path}/Imported');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      int count = 0;
      for (final file in pickedFiles) {
        if (file.path != null) {
          final srcFile = File(file.path!);
          final destPath = '${targetDir.path}/${file.name}';
          await srcFile.copy(destPath);
          count++;
        }
      }

      await scanLibrary();

      Get.snackbar(
        'Import Complete',
        'Successfully imported $count songs to your library.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E202B),
        colorText: Colors.white,
      );
    } catch (e) {
      debugPrint('Error importing audio files: $e');
    } finally {
      isScanning.value = false;
    }
  }

  void setFilterTab(LibraryFilterTab tab) {
    activeTab.value = tab;
  }

  void setSortOption(SongSortOption option) {
    sortOption.value = option;
    cacheService.setSetting('library_sort_option', option.name);
    applyFiltersAndSorting();
  }

  void updateSearch(String query) {
    searchQuery.value = query;
  }

  void applyFiltersAndSorting() {
    List<SongModel> list = List.from(allSongs);

    // Apply search query
    final query = SearchNormalizer.normalize(searchQuery.value.trim());
    if (query.isNotEmpty) {
      list = list.where((song) {
        return SearchNormalizer.normalize(song.title).contains(query) ||
            SearchNormalizer.normalize(song.artist).contains(query) ||
            SearchNormalizer.normalize(song.album).contains(query);
      }).toList();
    }

    // Apply case-insensitive sorting
    switch (sortOption.value) {
      case SongSortOption.titleAsc:
        list.sort(
          (a, b) => a.title.trim().toLowerCase().compareTo(
            b.title.trim().toLowerCase(),
          ),
        );
        break;
      case SongSortOption.titleDesc:
        list.sort(
          (a, b) => b.title.trim().toLowerCase().compareTo(
            a.title.trim().toLowerCase(),
          ),
        );
        break;
      case SongSortOption.artistAsc:
        list.sort((a, b) {
          final aUnknown =
              a.artist.isEmpty || a.artist.toLowerCase().contains('unknown');
          final bUnknown =
              b.artist.isEmpty || b.artist.toLowerCase().contains('unknown');
          final aArtist = aUnknown ? 'zzz' : a.artist.trim().toLowerCase();
          final bArtist = bUnknown ? 'zzz' : b.artist.trim().toLowerCase();
          final cmp = aArtist.compareTo(bArtist);
          return cmp != 0
              ? cmp
              : a.title.trim().toLowerCase().compareTo(
                  b.title.trim().toLowerCase(),
                );
        });
        break;
      case SongSortOption.artistDesc:
        list.sort((a, b) {
          final aUnknown =
              a.artist.isEmpty || a.artist.toLowerCase().contains('unknown');
          final bUnknown =
              b.artist.isEmpty || b.artist.toLowerCase().contains('unknown');
          final aArtist = aUnknown ? '' : a.artist.trim().toLowerCase();
          final bArtist = bUnknown ? '' : b.artist.trim().toLowerCase();
          final cmp = bArtist.compareTo(aArtist);
          return cmp != 0
              ? cmp
              : a.title.trim().toLowerCase().compareTo(
                  b.title.trim().toLowerCase(),
                );
        });
        break;
      case SongSortOption.dateAddedDesc:
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case SongSortOption.dateAddedAsc:
        list.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
        break;
      case SongSortOption.durationAsc:
        list.sort((a, b) => a.durationMs.compareTo(b.durationMs));
        break;
      case SongSortOption.durationDesc:
        list.sort((a, b) => b.durationMs.compareTo(a.durationMs));
        break;
    }

    filteredSongs.assignAll(list);
  }

  void _rebuildGroupings() {
    final Map<String, List<SongModel>> artists = {};
    final Map<String, List<SongModel>> albums = {};

    for (final song in allSongs) {
      final artistName = song.artist.trim().isNotEmpty
          ? song.artist.trim()
          : 'Unknown Artist';
      artists.putIfAbsent(artistName, () => []).add(song);

      final albumName = song.album.trim().isNotEmpty
          ? song.album.trim()
          : 'Unknown Album';
      albums.putIfAbsent(albumName, () => []).add(song);
    }

    artistsMap.assignAll(artists);
    albumsMap.assignAll(albums);
    foldersMap.assignAll(AudioScannerService.groupSongsByFolder(allSongs));
  }

  Future<void> toggleFavorite(SongModel song) async {
    if (Get.isRegistered<FavoritesController>()) {
      await Get.find<FavoritesController>().toggleFavorite(song);
    } else {
      await cacheService.toggleFavorite(song.id);
      song.isFavorite = !song.isFavorite;
      allSongs.refresh();
      filteredSongs.refresh();
    }
  }
}
