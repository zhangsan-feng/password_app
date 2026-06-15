package com.example.password_app

import android.content.Context
import android.os.Build
import android.provider.Settings
import android.net.wifi.WifiManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "password_app/lan_sync"
    private val logTag = "LanSync"
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireMulticastLock" -> {
                    acquireMulticastLock()
                    result.success(null)
                }

                "releaseMulticastLock" -> {
                    releaseMulticastLock()
                    result.success(null)
                }

                "getDeviceName" -> {
                    result.success(getDeviceName())
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        releaseMulticastLock()
        super.onDestroy()
    }

    private fun acquireMulticastLock() {
        val wifiManager =
            applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                ?: return

        if (multicastLock?.isHeld == true) {
            return
        }

        multicastLock = wifiManager.createMulticastLock("password_app_lan_sync").apply {
            setReferenceCounted(true)
            acquire()
        }
    }

    private fun releaseMulticastLock() {
        multicastLock?.let { lock ->
            if (lock.isHeld) {
                lock.release()
            }
        }
        multicastLock = null
    }

    private fun getDeviceName(): String {
        val nameCandidates =
            listOf(
                readSystemProperty("ro.product.marketname"),
                readSystemProperty("ro.product.odm.marketname"),
                formatBrandModel(Build.BRAND, Build.MODEL),
                formatBrandModel(Build.MANUFACTURER, Build.MODEL),
                Build.MODEL,
                Build.DEVICE,
                Build.PRODUCT,
                readSystemProperty("persist.sys.device_name"),
                readGlobalSetting("device_name"),
                readSystemSetting("device_name"),
            )

        for (candidate in nameCandidates) {
            val normalizedCandidate = candidate?.trim().orEmpty()
            if (isUsableDeviceName(normalizedCandidate)) {
                Log.d(logTag, "Resolved Android device name: $normalizedCandidate")
                return normalizedCandidate
            }
        }

        if (isProbablyEmulatorName(Build.MODEL) ||
            isProbablyEmulatorName(Build.DEVICE) ||
            isProbablyEmulatorName(Build.PRODUCT)
        ) {
            Log.d(logTag, "Resolved Android device name: Android Emulator")
            return "Android Emulator"
        }

        Log.d(
            logTag,
            "Falling back to Android Device. brand=${Build.BRAND}, manufacturer=${Build.MANUFACTURER}, " +
                "model=${Build.MODEL}, device=${Build.DEVICE}, product=${Build.PRODUCT}",
        )
        return "Android Device"
    }

    private fun readSystemProperty(key: String): String? {
        return try {
            val systemProperties = Class.forName("android.os.SystemProperties")
            val getMethod = systemProperties.getMethod("get", String::class.java)
            (getMethod.invoke(null, key) as? String)?.trim()?.takeIf { it.isNotEmpty() }
        } catch (_: Exception) {
            null
        }
    }

    private fun readGlobalSetting(key: String): String? {
        return try {
            Settings.Global.getString(contentResolver, key)?.trim()?.takeIf {
                it.isNotEmpty()
            }
        } catch (error: SecurityException) {
            Log.w(logTag, "Failed to read global setting $key", error)
            null
        }
    }

    private fun readSystemSetting(key: String): String? {
        return try {
            Settings.System.getString(contentResolver, key)?.trim()?.takeIf {
                it.isNotEmpty()
            }
        } catch (error: SecurityException) {
            Log.w(logTag, "Failed to read system setting $key", error)
            null
        }
    }

    private fun formatBrandModel(brand: String?, model: String?): String {
        val normalizedBrand = brand?.trim().orEmpty()
        val normalizedModel = model?.trim().orEmpty()
        if (normalizedBrand.isEmpty()) {
            return normalizedModel
        }
        if (normalizedModel.isEmpty()) {
            return normalizedBrand
        }
        if (normalizedModel.startsWith(normalizedBrand, ignoreCase = true)) {
            return normalizedModel
        }
        return "$normalizedBrand $normalizedModel"
    }

    private fun isUsableDeviceName(value: String): Boolean {
        if (value.isBlank()) {
            return false
        }

        val normalized = value.trim().lowercase()
        return normalized != "localhost" &&
            normalized != "127.0.0.1" &&
            normalized != "android" &&
            normalized != "unknown" &&
            !isProbablyEmulatorName(normalized)
    }

    private fun isProbablyEmulatorName(value: String?): Boolean {
        val normalized = value?.trim()?.lowercase().orEmpty()
        if (normalized.isEmpty()) {
            return false
        }

        return normalized.startsWith("sdk_gphone") ||
            normalized.contains("emulator") ||
            normalized.contains("generic") ||
            normalized == "android sdk built for x86" ||
            normalized == "android sdk built for x86_64"
    }
}
