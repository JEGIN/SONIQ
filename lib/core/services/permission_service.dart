import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();

  static Future<void> ensureNotificationPermission() async {
    try {
      if (Platform.isAndroid) {
        final notifStatus = await Permission.notification.status;
        if (!notifStatus.isGranted) {
          await Permission.notification.request();
        }
      }
    } catch (e) {
      debugPrint('Error ensuring notification permission: $e');
    }
  }

  static Future<bool> requestMediaPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Request notification permission on Android 13+ first if needed
        try {
          final notifStatus = await Permission.notification.status;
          if (!notifStatus.isGranted) {
            await Permission.notification.request();
          }
        } catch (_) {}

        // For Android 13 (API 33) and above:
        final audioStatus = await Permission.audio.status;
        if (audioStatus.isGranted) return true;

        final storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) return true;

        // Try Permission.audio first (standard for Android 13+)
        final audioReq = await Permission.audio.request();
        if (audioReq.isGranted) return true;

        // Fallback for Android 12 and below (API <= 32)
        final storageReq = await Permission.storage.request();
        if (storageReq.isGranted) return true;

        return false;
      } else if (Platform.isIOS) {
        final mediaLibrary = await Permission.mediaLibrary.request();
        return mediaLibrary.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting media permissions: $e');
      return false;
    }
  }

  static Future<bool> hasMediaPermission() async {
    try {
      if (Platform.isAndroid) {
        final audio = await Permission.audio.isGranted;
        final storage = await Permission.storage.isGranted;
        return audio || storage;
      } else if (Platform.isIOS) {
        return await Permission.mediaLibrary.isGranted;
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
