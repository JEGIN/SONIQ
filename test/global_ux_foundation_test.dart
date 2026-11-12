import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soniq/app/localization/soniq_localizations.dart';
import 'package:soniq/core/utils/search_normalizer.dart';

void main() {
  group('SONIQ localization foundation', () {
    test('declares all requested interface locales', () {
      expect(
        SoniqLocalizations.supportedLocales
            .map((locale) => locale.languageCode)
            .toSet(),
        {'en', 'ta', 'hi', 'ar', 'es', 'fr', 'de', 'ja', 'zh'},
      );
    });

    test('uses translated strings and falls back to English', () {
      expect(
        const SoniqLocalizations(Locale('ta')).text('library'),
        'இசைத் தொகுப்பு',
      );
      expect(
        const SoniqLocalizations(Locale('ar')).text('nowPlaying'),
        'قيد التشغيل',
      );
      expect(
        const SoniqLocalizations(Locale('fr')).text('unknownKey'),
        'unknownKey',
      );
    });

    test('primary screen labels exist in each supported locale', () {
      for (final locale in SoniqLocalizations.supportedLocales) {
        final strings = SoniqLocalizations(locale);
        expect(strings.text('dailyMixes'), isNotEmpty);
        expect(strings.text('queueEnding'), isNot('queueEnding'));
        expect(
          strings.text('libraryAudioIndexing'),
          isNot('libraryAudioIndexing'),
        );
        expect(strings.text('analyticsPrivacy'), isNot('analyticsPrivacy'));
        expect(strings.text('spatialAudioOutput'), isNot('spatialAudioOutput'));
        expect(
          strings.text('rescanMusicLibraryHelp'),
          isNot('rescanMusicLibraryHelp'),
        );
        expect(strings.text('fileInformation'), isNot('fileInformation'));
        expect(
          strings.text('favoritesCollection'),
          isNot('favoritesCollection'),
        );
        expect(strings.text('emptyPlaylist'), isNot('emptyPlaylist'));
        if (locale.languageCode != 'en') {
          expect(strings.text('dailyMixes'), isNot('Daily mixes'));
          expect(strings.text('queueEnding'), isNot('Queue ending'));
        }
      }
    });

    test('resolves Arabic and system language choices predictably', () {
      expect(
        SoniqLocalizations.resolve(const Locale('ar')),
        const Locale('ar'),
      );
      expect(SoniqLocalizations.localeForCode('system'), isNull);
      expect(
        SoniqLocalizations.resolve(const Locale('pt')),
        const Locale('en'),
      );
    });
  });

  group('offline Unicode search normalization', () {
    test('matches common precomposed and decomposed Latin accents', () {
      expect(
        SearchNormalizer.normalize('CAFÉ'),
        SearchNormalizer.normalize('cafe\u0301'),
      );
    });

    test('preserves meaningful language marks and non-Latin scripts', () {
      expect(
        SearchNormalizer.normalize('ñ'),
        isNot(SearchNormalizer.normalize('n')),
      );
      expect(SearchNormalizer.normalize('தமிழ்'), 'தமிழ்');
      expect(SearchNormalizer.normalize('العَرَبِيَّة'), 'العَرَبِيَّة');
    });
  });
}
