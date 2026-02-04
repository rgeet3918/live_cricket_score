package com.aryatech.cricketlivescore

import android.content.Context
import android.net.ConnectivityManager
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.aryatech.speedtest/network_type"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            android.util.Log.d("NetworkType", "📡 Method channel called: ${call.method}")
            when (call.method) {
                "getNetworkType" -> {
                    val networkType = getNetworkType()
                    android.util.Log.d("NetworkType", "📡 Returning network type: $networkType")
                    result.success(networkType)
                }
                else -> {
                    android.util.Log.d("NetworkType", "📡 Method not implemented: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    private fun getNetworkType(): String {
        return try {
            android.util.Log.d("NetworkType", "📡 Getting network type...")

            val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

            @Suppress("DEPRECATION")
            val networkInfo = connectivityManager.activeNetworkInfo

            if (networkInfo == null || !networkInfo.isConnected) {
                android.util.Log.d("NetworkType", "📡 No active network connection")
                return "Mobile"
            }

            android.util.Log.d("NetworkType", "📡 Network type: ${networkInfo.type}")
            android.util.Log.d("NetworkType", "📡 Network subtype: ${networkInfo.subtype}")
            android.util.Log.d("NetworkType", "📡 Network subtype name: ${networkInfo.subtypeName}")

            val subtype = networkInfo.subtype

            when (subtype) {
                TelephonyManager.NETWORK_TYPE_GPRS,
                TelephonyManager.NETWORK_TYPE_EDGE,
                TelephonyManager.NETWORK_TYPE_CDMA,
                TelephonyManager.NETWORK_TYPE_1xRTT,
                TelephonyManager.NETWORK_TYPE_IDEN -> {
                    android.util.Log.d("NetworkType", "📡 ✅ Detected: 2G")
                    "2G"
                }
                TelephonyManager.NETWORK_TYPE_UMTS,
                TelephonyManager.NETWORK_TYPE_EVDO_0,
                TelephonyManager.NETWORK_TYPE_EVDO_A,
                TelephonyManager.NETWORK_TYPE_HSDPA,
                TelephonyManager.NETWORK_TYPE_HSUPA,
                TelephonyManager.NETWORK_TYPE_HSPA,
                TelephonyManager.NETWORK_TYPE_EVDO_B,
                TelephonyManager.NETWORK_TYPE_EHRPD,
                TelephonyManager.NETWORK_TYPE_HSPAP -> {
                    android.util.Log.d("NetworkType", "📡 ✅ Detected: 3G")
                    "3G"
                }
                TelephonyManager.NETWORK_TYPE_LTE -> {
                    android.util.Log.d("NetworkType", "📡 ✅ Detected: 4G (LTE)")
                    "4G"
                }
                20 -> {
                    android.util.Log.d("NetworkType", "📡 ✅ Detected: 5G (NR)")
                    "5G"
                }
                else -> {
                    android.util.Log.d("NetworkType", "📡 ⚠️ Unknown subtype: $subtype (${networkInfo.subtypeName})")
                    "Mobile"
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("NetworkType", "📡 ❌ Exception: ${e.message}", e)
            e.printStackTrace()
            "Mobile"
        }
    }
}
