import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'app/bindings/initial_binding.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';
import 'core/database/song_cache_service.dart';
import 'core/services/audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Premium OLED edge-to-edge system overlays
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF12131A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Hive Cache Service
  final cacheService = SongCacheService();
  await cacheService.init();

  // Initialize Background Audio Service (audio_service + just_audio)
  final audioHandler = await initAudioHandler();

  runApp(SoniqApp(audioHandler: audioHandler));
}

class SoniqApp extends StatelessWidget {
  final SoniqAudioHandler audioHandler;

  const SoniqApp({super.key, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'SONIQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialBinding: InitialBinding(audioHandler: audioHandler),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      defaultTransition: Transition.fadeIn,
    );
  }
}
