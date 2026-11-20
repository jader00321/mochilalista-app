package com.mochilalista.app

import android.annotation.SuppressLint
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.mochilalista.app/device_security"

    // Huella SHA-256 del certificado oficial de Release de Julio Angello Vasquez Navarro
    // Si está vacía o en modo DEBUG, no se bloquea la ejecución para permitir desarrollo fluido.
    private val OFFICIAL_RELEASE_SIGNATURE_SHA256 = ""

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSecureHardwareId" -> {
                    @SuppressLint("HardwareIds")
                    val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    result.success(androidId ?: "generic_android_fallback")
                }
                "verifyAppSignature" -> {
                    val isValid = verifyCertificateSignature()
                    result.success(isValid)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun verifyCertificateSignature(): Boolean {
        // En compilaciones de depuración (DEBUG), omitir verificación para no auto-bloquearse
        val isDebuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (isDebuggable) {
            return true
        }

        // Si aún no se ha inyectado la huella oficial de producción, permitir ejecución
        if (OFFICIAL_RELEASE_SIGNATURE_SHA256.isEmpty()) {
            return true
        }

        return try {
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val packageInfo = packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
                packageInfo.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                val packageInfo = packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNATURES
                )
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }

            if (signatures == null || signatures.isEmpty()) {
                return false
            }

            val md = MessageDigest.getInstance("SHA-256")
            val currentSignatureHash = md.digest(signatures[0].toByteArray())
                .joinToString("") { "%02X".format(it) }

            currentSignatureHash.equals(OFFICIAL_RELEASE_SIGNATURE_SHA256, ignoreCase = true)
        } catch (e: Exception) {
            // En caso de fallo de lectura inesperado, no bloquear catastróficamente al usuario legítimo
            true
        }
    }
}
