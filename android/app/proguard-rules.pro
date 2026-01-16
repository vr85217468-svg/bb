# ============================================================================
# ProGuard/R8 Rules - Force ignore Firebase completely
# ============================================================================

# Keep all classes to prevent issues (optional, can be more specific)
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ============================================================================
# FIREBASE - COMPLETE EXCLUSION
# ============================================================================

# Remove all Firebase dependencies and references
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-dontnote com.google.firebase.**
-dontnote com.google.android.gms.**

# Ignore Firebase classes completely
-dontwarn firebase.**
-dontnote firebase.**

# Remove Firebase Cloud Messaging
-dontwarn com.google.firebase.messaging.**
-dontnote com.google.firebase.messaging.**

# Remove Firebase Analytics
-dontwarn com.google.firebase.analytics.**
-dontnote com.google.firebase.analytics.**

# Remove Firebase Crashlytics
-dontwarn com.google.firebase.crashlytics.**
-dontnote com.google.firebase.crashlytics.**

# Remove Firebase Auth
-dontwarn com.google.firebase.auth.**
-dontnote com.google.firebase.auth.**

# Remove Firebase Database
-dontwarn com.google.firebase.database.**
-dontnote com.google.firebase.database.**

# Remove Firebase Storage
-dontwarn com.google.firebase.storage.**
-dontnote com.google.firebase.storage.**

# Remove all Google Play Services
-dontwarn com.google.android.gms.**
-dontnote com.google.android.gms.**

# ============================================================================
# PUSHY - KEEP ALL (Our notification service)
# ============================================================================
-keep class me.pushy.sdk.** { *; }
-dontwarn me.pushy.sdk.**

# ============================================================================
# SUPABASE - KEEP ALL (Our backend)
# ============================================================================
-keep class io.supabase.** { *; }

# ============================================================================
# FLUTTER - KEEP ALL
# ============================================================================
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }

# Keep all native Flutter methods
-keepclassmembers class * {
    @io.flutter.embedding.engine.dart.DartEntrypoint *;
}

# ============================================================================
# KOTLIN - KEEP ALL
# ============================================================================
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# ============================================================================
# BACKGROUND SERVICE - KEEP ALL
# ============================================================================
-keep class id.flutter.flutter_background_service.** { *; }

# ============================================================================
# JITSI MEET - KEEP ALL
# ============================================================================
-keep class org.jitsi.** { *; }
-keep class com.facebook.react.** { *; }
-keep class com.facebook.soloader.** { *; }
-keep class org.jitsi.meet.** { *; }
-keep class org.jitsi.meet.sdk.** { *; }
-keep class org.jitsi.meet.sdk.JitsiMeetPlugin { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# ============================================================================
# CAMERA & PERMISSIONS - KEEP ALL
# ============================================================================
-keep class com.mrousavy.camera.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }

# ============================================================================
# AGORA RTC ENGINE - OPTIMIZED (Keep only essentials)
# ============================================================================
# Keep main Agora classes
-keep class io.agora.** { *; }
-keep class io.agora.rtc.** { *; }
-keep class io.agora.rtc2.** { *; }

# Keep native methods (required for SDK to work)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Optimize unused features (يمكن تعديلها حسب الميزات المستخدمة)
# إذا كنت لا تستخدم Video، يمكنك إضافة:
# -dontwarn io.agora.rtc.video.**

# ============================================================================
# GENERAL - REMOVE WARNINGS
# ============================================================================
-ignorewarnings
