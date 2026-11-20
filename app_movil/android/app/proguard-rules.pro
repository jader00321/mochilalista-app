# =========================================================================
# MochilaLista Proguard Rules - Protección de Release y Plugins Nativos
# =========================================================================

# Flutter Core
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# SQLCipher / SQLite
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-keep class com.tekartik.sqflite.** { *; }
-dontwarn net.sqlcipher.**

# Flutter Secure Storage y Criptografía Android Keystore
-keep class androidx.security.crypto.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn androidx.security.crypto.**

# Workmanager & Tareas en Segundo Plano
-keep class dev.fluttercommunity.workmanager.** { *; }

# Autenticación Biométrica
-keep class io.flutter.plugins.localauth.** { *; }

# Google Sign In & Google Play Services Auth
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class io.flutter.plugins.googlesignin.** { *; }
-dontwarn com.google.android.gms.auth.**
-dontwarn com.google.android.gms.common.**

# Supresión de advertencias para dependencias nativas
-dontwarn io.flutter.**
-dontwarn com.google.android.**
