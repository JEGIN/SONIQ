import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'app/bindings/initial_binding.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';
import 'app/localization/soniq_localizations.dart';
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
  final savedLanguage = cacheService.getSetting(
    'language_code',
    defaultValue: 'system',
  ) as String;
  final initialLocale = SoniqLocalizations.localeForCode(savedLanguage);
  final resolvedInitialLocale = SoniqLocalizations.resolve(
    initialLocale ?? WidgetsBinding.instance.platformDispatcher.locale,
  );
  // GetMaterialApp uses Get.locale for both Flutter localization and directionality.
  // Set the resolved system locale before first build so RTL system locales work.
  Get.locale = resolvedInitialLocale;
  Intl.defaultLocale = SoniqLocalizations.resolve(
    initialLocale ?? WidgetsBinding.instance.platformDispatcher.locale,
  ).toString();

  // Initialize Background Audio Service (audio_service + just_audio)
  final audioHandler = await initAudioHandler(
    initialLocale: resolvedInitialLocale,
  );

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
      supportedLocales: SoniqLocalizations.supportedLocales,
      localizationsDelegates: const [
        SoniqLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (deviceLocale != null) {
          for (final supported in supportedLocales) {
            if (supported.languageCode == deviceLocale.languageCode) {
              return supported;
            }
          }
        }
        return const Locale('en');
      },
      theme: AppTheme.darkTheme,
      initialBinding: InitialBinding(audioHandler: audioHandler),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      defaultTransition: Transition.fadeIn,
    );
  }
}
