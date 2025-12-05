# ============================================================================
# ProGuard Rules - Google Mobile Services & Firebase Obfuscation Configuration
# ============================================================================

# ⭐ GMS Phenotype API obfuscation kuralları (Phenotype API hatası çözmek için)
-keep class com.google.android.gms.phenotype.** { *; }
-keep class bbvl { *; }
-keep class bcsx { *; }
-keep class bbxh { *; }
-keep class bbxe { *; }
-dontwarn com.google.android.gms.phenotype.**

# GMS Base Services
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-keep interface com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.common.**

# GMS Auth
-keep class com.google.android.gms.auth.** { *; }
-dontwarn com.google.android.gms.auth.**

# GMS Maps
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
-dontwarn com.google.android.gms.maps.**

# GMS Location
-keep class com.google.android.gms.location.** { *; }
-dontwarn com.google.android.gms.location.**

# Firebase obfuscation
-keep class com.google.firebase.** { *; }
-keep class com.google.firebase.analytics.** { *; }
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.storage.** { *; }
-keep class com.google.firebase.functions.** { *; }
-dontwarn com.google.firebase.**

# Flogger obfuscation
-keep class com.google.flogger.** { *; }
-dontwarn com.google.flogger.**

# Kotlin coroutines
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Remove logging statements
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Keep Flutter-related classes
-keep class io.flutter.** { *; }
-keep interface io.flutter.** { *; }
-dontwarn io.flutter.**

# Keep annotation classes
-keepattributes *Annotation*,SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# General configuration
-verbose
-dontskipnonpubliclibraryclasses
-dontpreverify
