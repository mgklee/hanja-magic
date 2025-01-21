package com.example.hanja_magic

import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.os.Bundle
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import android.content.Intent
import android.net.Uri

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.hanja_magic/apps"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledAppNames" -> {
                    val names = getInstalledAppNames()
                    result.success(names)
                }
                "getSingleAppInfoByName" -> {
                    val name = call.argument<String>("appName")
                    if (name != null) {
                        val info = getSingleAppInfoByName(name)
                        if (info != null) {
                            result.success(info)
                        } else {
                            result.error("NOT_FOUND", "No matching app found for $name", null)
                        }
                    } else {
                        result.error("INVALID_NAME", "App name is null or invalid.", null)
                    }
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    val additiveData = call.argument<String>("additivedata")
                    if (packageName != null) {
                        val success = launchApp(packageName, additiveData)
                        result.success(success)
                    } else {
                        result.error("INVALID_PACKAGE", "Package name is null or invalid.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getInstalledAppNames(): List<String> {
        val pm = packageManager
        val list = mutableListOf<String>()
        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        for (pkg in packages) {
            val launchIntent = pm.getLaunchIntentForPackage(pkg.packageName)
            if (launchIntent != null) {
                val appName = pm.getApplicationLabel(pkg).toString()
                list.add(appName)
            }
        }
        return list
    }

    private fun getSingleAppInfoByName(appName: String): Map<String, String>? {
        val pm = packageManager
        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        for (pkg in packages) {
            val launchIntent = pm.getLaunchIntentForPackage(pkg.packageName)
            if (launchIntent != null) {
                val name = pm.getApplicationLabel(pkg).toString()
                if (name.equals(appName, ignoreCase = true)) {
                    val iconDrawable = pm.getApplicationIcon(pkg.packageName)
                    val bitmap = if (iconDrawable is BitmapDrawable) {
                        iconDrawable.bitmap
                    } else {
                        val b = Bitmap.createBitmap(iconDrawable.intrinsicWidth, iconDrawable.intrinsicHeight, Bitmap.Config.ARGB_8888)
                        val c = Canvas(b)
                        iconDrawable.setBounds(0, 0, c.width, c.height)
                        iconDrawable.draw(c)
                        b
                    }
                    val outputStream = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
                    val iconBase64 = Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
                    return mapOf(
                        "name" to name,
                        "package" to pkg.packageName,
                        "icon" to iconBase64
                    )
                }
            }
        }
        return null
    }

    private fun launchApp(packageName: String, additiveData: String?): Boolean {
        return when (packageName) {
            "com.samsung.android.dialer" -> {
                if (!additiveData.isNullOrEmpty()) {
                    val sanitizedNumber = additiveData.replace("\\s".toRegex(), "")
                    val intent = Intent(Intent.ACTION_DIAL).apply {
                        data = Uri.parse("tel:$sanitizedNumber")
                        //addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    true
                } else {
                    false
                }
            }
            "com.sec.android.app.sbrowser" -> {
                if (!additiveData.isNullOrEmpty()) {
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        data = Uri.parse(additiveData)
                    }
                    startActivity(intent)
                    true
                } else {
                    false
                }
            }
            else -> {
                val intent = packageManager.getLaunchIntentForPackage(packageName)
                if (intent != null) {
                    startActivity(intent)
                    true
                } else {
                    false
                }
            }
        }
    }
}
