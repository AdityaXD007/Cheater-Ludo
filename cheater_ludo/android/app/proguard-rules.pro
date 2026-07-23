# Flutter Wrapper & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }

# Ignore warnings for optional Play Core deferred components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Google Play Core & Services
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.gms.** { *; }

# Generated Plugin Registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Preserve native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve enum values
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
