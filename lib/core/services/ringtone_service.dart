import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ringtone_set_plus/ringtone_set_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../models/ringtone_model.dart';
import '../database/song_cache_service.dart';

class RingtoneService {
  static final RingtoneService _instance = RingtoneService._internal();
  factory RingtoneService() => _instance;
  RingtoneService._internal();

  final SongCacheService _cacheService = SongCacheService();

  /// Sets the trimmed audio file as phone ringtone, notification tone, or alarm tone
  Future<bool> setSystemRingtone({
    required String filePath,
    required RingtoneTarget target,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Ringtone file does not exist: $filePath');
    }

    if (Platform.isAndroid) {
      try {
        switch (target) {
          case RingtoneTarget.phone:
            final success = await RingtoneSet.setRingtoneFromFile(file);
            return success;
          case RingtoneTarget.notification:
            final success = await RingtoneSet.setNotificationFromFile(file);
            return success;
          case RingtoneTarget.alarm:
            final success = await RingtoneSet.setAlarmFromFile(file);
            return success;
        }
      } catch (e) {
        debugPrint('SONIQ: Ringtone set error on Android: $e');
        rethrow;
      }
    } else if (Platform.isIOS) {
      // iOS does not allow arbitrary third-party apps to directly set ringtones.
      // We share the file to Files or GarageBand.
      await shareRingtone(filePath, title: 'Export Ringtone');
      return true;
    }
    return false;
  }

  /// Shares ringtone via system share sheet
  Future<void> shareRingtone(String filePath, {String title = 'Share Ringtone'}) async {
    final file = File(filePath);
    if (await file.exists()) {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: title,
        text: 'Created with SONIQ Ringtone Studio',
      );
    }
  }

  /// Records saved ringtone in database
  Future<void> recordSavedRingtone(RingtoneModel ringtone) async {
    await _cacheService.saveRingtone(ringtone);
  }
}
