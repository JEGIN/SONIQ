# Flutter Wrapper & Play Core deferred components
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn com.google.android.play.core.**

# audio_service rules
-keep class com.ryanheise.audioservice.** { *; }
-keepclassmembers class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**

# just_audio & ExoPlayer / Media3
-keep class com.ryanheise.just_audio.** { *; }
-keepclassmembers class com.ryanheise.just_audio.** { *; }
-dontwarn com.ryanheise.just_audio.**

# audio_session rules
-keep class com.ryanheise.audio_session.** { *; }
-keepclassmembers class com.ryanheise.audio_session.** { *; }
-dontwarn com.ryanheise.audio_session.**

# AndroidX Media and Media3
-keep class androidx.media.** { *; }
-keep class androidx.media3.** { *; }
-keep interface androidx.media3.** { *; }
-keep class android.support.v4.media.** { *; }
-dontwarn androidx.media.**
-dontwarn androidx.media3.**
-dontwarn android.support.v4.media.**

# Notification and Media controls
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class androidx.media.app.NotificationCompat** { *; }

# Native Audio DSP Engine & App classes
-keep class com.soniq.soniq.** { *; }
-keepclassmembers class com.soniq.soniq.dsp.NativeAudioDspEngine { *; }

# R classes and resources accessed by dynamic reflection
-keepclassmembers class **.R$* {
    public static <fields>;
}

# AudioTrack reflection
-keep class android.media.AudioTrack { *; }
-keep class kotlin.Metadata { *; }
