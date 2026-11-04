package com.example.healthdeviceapp

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.healthdeviceapp/wifi_scan"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getScanResults") {
                try {
                    // Check and request runtime location permissions if missing
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val hasFine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                        val hasCoarse = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                        if (!hasFine && !hasCoarse) {
                            requestPermissions(
                                arrayOf(
                                    Manifest.permission.ACCESS_FINE_LOCATION,
                                    Manifest.permission.ACCESS_COARSE_LOCATION
                                ),
                                101
                            )
                        }
                    }

                    val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                    if (wifiManager == null) {
                        result.success(emptyList<Map<String, Any>>())
                        return@setMethodCallHandler
                    }

                    // Trigger hardware scan
                    try {
                        wifiManager.startScan()
                    } catch (_: Exception) {}

                    val scanResults = wifiManager.scanResults
                    val list = mutableListOf<Map<String, Any>>()
                    val seenSsids = mutableSetOf<String>()

                    if (scanResults != null) {
                        for (sr in scanResults) {
                            val ssid = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                sr.wifiSsid?.toString()?.replace("^\"|\"$".toRegex(), "") ?: sr.SSID ?: ""
                            } else {
                                sr.SSID?.replace("^\"|\"$".toRegex(), "") ?: ""
                            }
                            if (ssid.isNotEmpty() && !seenSsids.contains(ssid.lowercase())) {
                                seenSsids.add(ssid.lowercase())
                                val map = mapOf(
                                    "ssid" to ssid,
                                    "bssid" to (sr.BSSID ?: ""),
                                    "capabilities" to (sr.capabilities ?: ""),
                                    "frequency" to sr.frequency,
                                    "level" to sr.level
                                )
                                list.add(map)
                            }
                        }
                    }

                    // Also include current connected Wi-Fi info if missing
                    try {
                        val connectionInfo = wifiManager.connectionInfo
                        if (connectionInfo != null) {
                            val curSsid = connectionInfo.ssid?.replace("^\"|\"$".toRegex(), "")?.trim()
                            if (!curSsid.isNullOrEmpty() &&
                                curSsid != "<unknown ssid>" &&
                                !seenSsids.contains(curSsid.lowercase())) {
                                seenSsids.add(curSsid.lowercase())
                                val freq = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                    connectionInfo.frequency
                                } else 2412
                                list.add(
                                    mapOf(
                                        "ssid" to curSsid,
                                        "bssid" to (connectionInfo.bssid ?: ""),
                                        "capabilities" to "[WPA2-PSK-CCMP][ESS]",
                                        "frequency" to freq,
                                        "level" to connectionInfo.rssi
                                    )
                                )
                            }
                        }
                    } catch (_: Exception) {}

                    result.success(list)
                } catch (e: Exception) {
                    result.error("SCAN_ERROR", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
