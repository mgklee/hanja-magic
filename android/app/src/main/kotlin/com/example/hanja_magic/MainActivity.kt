package com.example.hanja_magic

import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.hanja_magic/apps"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

            // Null 가능성 확인 후 안전하게 처리
            val binaryMessenger = flutterEngine?.dartExecutor?.binaryMessenger
                if (binaryMessenger != null) {
                    MethodChannel(binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                        when (call.method) {
                            "getInstalledApps" -> {
                                val apps = getInstalledApps()
                                result.success(apps)
                            }
                            "launchApp" -> {
                                val packageName = call.argument<String>("packageName")
                                if (packageName != null) {
                                    val success = launchApp(packageName)
                                    result.success(success)
                                } else {
                                    result.error("INVALID_PACKAGE", "Invalid package name.", null)
                                }
                            }
                            else -> result.notImplemented()
                        }
                    }
                }
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val pm: PackageManager = packageManager
        val apps = mutableListOf<Map<String, String>>()

        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        for (packageInfo in packages) {
            val packageName = packageInfo.packageName
            val launchIntent = pm.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                val appName = pm.getApplicationLabel(packageInfo).toString()
                apps.add(
                    mapOf(
                        "name" to appName,
                        "package" to packageName
                    )
                )
            }
        }

        return apps
    }

    private fun launchApp(packageName: String): Boolean {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        return if (launchIntent != null) {
            startActivity(launchIntent)
            true
        } else {
            false
        }
    }
}
