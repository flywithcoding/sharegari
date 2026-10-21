# =============================================================================
# ShareGari — ProGuard / R8 keep rules
# =============================================================================
# These rules apply when isMinifyEnabled = true.
# Currently minification is DISABLED (see build.gradle.kts) because R8
# breaks Flutter plugin reflection at runtime.
#
# If minification is re-enabled in future, these rules protect the most
# common plugin surface areas.
# =============================================================================

# ── Flutter plugin registrar / embedding ────────────────────────────────────

# Keep all Flutter plugin classes (io.flutter.plugins.**)
-keep class io.flutter.plugins.** { *; }

# Keep Flutter embedding classes (used by GeneratedPluginRegistrant)
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# ── shared_preferences_android ───────────────────────────────────────────────
# SharedPreferencesApiRegistrar and related classes use reflection-style
# method dispatch that R8 strips by default.
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ── Supabase / Realtime (OkHttp, Ktor) ───────────────────────────────────────
-keep class io.github.jan.supabase.** { *; }
-dontwarn io.github.jan.supabase.**

# OkHttp (used by Supabase Realtime / HTTP)
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# ── flutter_map / latlong2 ────────────────────────────────────────────────────
-keep class com.onurturhan.fluttermap.** { *; }

# ── Google Fonts ──────────────────────────────────────────────────────────────
# Google Fonts loads font metadata via reflection in some versions
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ── General: keep annotation-driven classes ──────────────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod
