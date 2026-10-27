# Flutter ProGuard / R8 Configuration for Brivio Production
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Preserve Annotations and Generic Signatures for Serialization
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Firebase Cloud Messaging & Core
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }

# Desugaring & Java 8+ APIs
-dontwarn java.lang.invoke.**

# Mobile Scanner & Camera
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# Local Auth & Biometrics
-dontwarn androidx.biometric.**
-keep class androidx.biometric.** { *; }

# Google Play Core & Deferred Components
-dontwarn com.google.android.play.core.**
