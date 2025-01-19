package com.example.hanja_magic

import android.content.pm.PackageManager
import android.os.Bundle
import android.graphics.drawable.BitmapDrawable
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import android.graphics.Bitmap
import android.graphics.Canvas
import android.util.Log


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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInstalledApps") {
                result.success(getInstalledApps())
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
            val icon = packageInfo.loadIcon(pm)

            // Convert icon to Base64
            val iconBase64 = try {
                val drawable = packageInfo.loadIcon(pm)
                val bitmap = if (drawable is BitmapDrawable) {
                    drawable.bitmap
                } else {
                    // 다른 Drawable 타입의 경우 비트맵으로 변환
                    val bitmap = Bitmap.createBitmap(drawable.intrinsicWidth, drawable.intrinsicHeight, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bitmap)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                    bitmap
                }

                // 비트맵을 Base64로 변환
                val outputStream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
                Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
            } catch (e: Exception) {
                Log.e("AppIconError", "Failed to process icon for ${packageInfo.packageName}: ${e.message}")
                null
            }

            Log.d("Base64Debug", "Base64 Icon Data: ${iconBase64?.take(100)}")

            if (launchIntent != null) {
                val appName = pm.getApplicationLabel(packageInfo).toString()
                apps.add(
                    mapOf(
                        "name" to appName,
                        "package" to packageName,
                        "icon" to (iconBase64 ?: "")
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
