package com.example.hanja_magic

import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.hanja_magic/apps"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                if (call.method == "getInstalledApps") {
                    val apps = getInstalledApps()
                    result.success(apps)
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val pm: PackageManager = packageManager
        val intent = Intent(Intent.ACTION_MAIN, null)
        intent.addCategory(Intent.CATEGORY_LAUNCHER)

        val apps: List<ResolveInfo> = pm.queryIntentActivities(intent, 0)
        val installedApps = mutableListOf<Map<String, String>>()

        for (app in apps) {
            val appName = app.loadLabel(pm).toString()
            val packageName = app.activityInfo.packageName
            installedApps.add(
                mapOf(
                    "name" to appName,
                    "package" to packageName
                )
            )
        }

        return installedApps
    }
}
