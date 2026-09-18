# ==============================================================================
# R8 Core Optimization & Aggressive Shrinking Configuration
# ==============================================================================
-optimizationpasses 5
-allowaccessmodification
-repackageclasses ''
-dontusemixedcaseclassnames

# Retain required metadata attributes
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable

# ==============================================================================
# Flutter Core & Embedding
# ==============================================================================
-keep class io.flutter.app.FlutterApplication { *; }
-keep class io.flutter.embedding.android.** { *; }
-keep class io.flutter.embedding.engine.FlutterJNI { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# ==============================================================================
# AndroidX & Support Libraries
# ==============================================================================
-dontwarn androidx.**
-keep class androidx.annotation.Keep
-keep @androidx.annotation.Keep class * { *; }
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <methods>;
}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <fields>;
}

# Biometric Authentication (Keep only native AIDL & biometric prompts)
-keep class androidx.biometric.BiometricPrompt$** { *; }
-dontwarn androidx.biometric.**

# ==============================================================================
# Firebase & Google Play Services
# Note: Firebase & Play Services libraries package their own consumer rules.
# We retain only entry points and suppress benign warnings.
# ==============================================================================
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.core.**
-dontwarn com.google.firebase.**

# Retain keep-annotated classes for Firebase
-keepattributes *Annotation*
-keep class com.google.firebase.provider.FirebaseInitProvider

# ==============================================================================
# Flutter Local Notifications
# ==============================================================================
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# ==============================================================================
# Gson / JSON Serialization
# ==============================================================================
-keepclassmembers enum * { *; }
-dontwarn sun.misc.**
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ==============================================================================
# Networking & Desugaring
# ==============================================================================
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn java.lang.invoke.**

