# SONIQ Phase 9: Global UX, Accessibility & Localization

## Implemented

- Added a shared Flutter localization delegate and catalogs for English, Tamil, Hindi, Arabic, Spanish, French, German, Japanese, and Simplified Chinese. Untranslated keys visibly fall back to English.
- Added a language picker with system-language selection and local persistence. Startup resolves the saved or device locale before the first app frame so Flutter can establish RTL directionality.
- Localized the app navigation, library and track-action menu, home, playback controls, Now Playing actions, queue controls, Favorites and playlist details, primary playlist flows, equalizer and spatial-audio controls, discovery, settings descriptions, analytics dashboard, and analytics privacy/data-management screens.
- Preserved original song titles, artist names, album names, and other imported metadata.
- Added Noto script font fallbacks for Tamil, Devanagari, Arabic, and CJK. Fonts remain platform supplied; no binaries were added.
- Added directional positioning for the floating playback controls and library fast scroller, and made queue swipe actions respect reading direction.
- Added shared radius, spacing, and touch-target tokens; improved muted-text contrast; and removed tight tracking from shared text styles for complex scripts.
- Added offline Unicode case and canonical normalization for search while preserving Tamil, Arabic marks, and source metadata.
- Applied locale-aware number formatting to durations, file sizes, selected analytics values, and queue playlist dates. Stored timestamps remain unchanged.
- Added screen-reader descriptions for artwork and playback state, adjustable keyboard-operable equalizer faders, and queue reorder descriptions.
- Added responsive behavior for large text and smaller layouts in the library, settings statistics, Now Playing artwork, and floating playback controls.
- Reduced motion for vinyl rotation, spectrum visualization, and floating playback-bar transitions when the platform requests reduced animation.

## Language coverage and limits

All nine languages have translated strings for the primary screens listed above. The complete interface is not fully translated yet: many secondary dialogs, replay/story screens, preset-management and studio/ringtone flows, feature-specific error messages, and controller-generated snackbars still fall back to English. Translation quality has not had native-speaker review.

Tamil metadata is never translated or transliterated. Search preserves Tamil and mixed Tamil/English text. Script fallback and shaping still need validation on devices containing real Tamil metadata.

Arabic uses Flutter's locale directionality, and the layouts use directional padding in key navigation and playback surfaces. Mixed RTL/LTR text, all screen flows, and icon ordering still need device-level review.

## Platform behavior

- Android notifications and Android Auto use the audio service media session and original track metadata. The notification channel label is selected at startup; Android may retain a channel label after the user changes app language.
- iOS lock-screen and Control Center presentation is provided by iOS and uses audio-service metadata. Android notification-channel behavior does not apply there.
- Android Auto uses Android's native automotive media presentation. The app retains the same playback state and original metadata but does not reproduce the Android Auto UI in Flutter.
- Android and iOS may expose different system media actions.

## Validation

- `flutter analyze`: passed with no issues.
- `flutter test`: passed, including localization fallback/catalog checks, Unicode search normalization, queue reordering, playback, analytics, DSP, favorites, and Android Auto model tests.
- `git diff --check`: clean.

The requested device matrix remains unverified: TalkBack/VoiceOver, native notification and Android Auto behavior, Tamil shaping, Arabic mixed-direction interactions, maximum text scaling, small phones, tablets, landscape/split-screen, and low-end visualizer performance need physical-device checks. The tests do not establish formal accessibility or contrast conformance.
