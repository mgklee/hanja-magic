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
import android.content.Context
import android.media.AudioManager
import android.hardware.camera2.CameraManager
import android.app.NotificationManager
import android.provider.Settings
import android.app.UiModeManager
import android.os.Build
import android.content.ContentResolver


class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.hanja_magic/apps"
    private var isFlashlightOn = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
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
                    val extraData = call.argument<String>("extraData")
                    if (packageName != null) {
                        val success = launchApp(packageName, extraData)
                        result.success(success)
                    } else {
                        result.error("INVALID_PACKAGE", "Package name is null or invalid.", null)
                    }
                }
                "turnOnFlashlight" -> {
                    try {
                        val cameraId = cameraManager.cameraIdList[0] // 기본 카메라
                        cameraManager.setTorchMode(cameraId, true)
                        isFlashlightOn = true
                        result.success("Flashlight turned on")
                    } catch (e: Exception) {
                        result.error("FLASHLIGHT_ERROR", "Failed to turn on flashlight", e.message)
                    }
                }
                "turnOffFlashlight" -> {
                    try {
                        val cameraId = cameraManager.cameraIdList[0]
                        cameraManager.setTorchMode(cameraId, false)
                        isFlashlightOn = false
                        result.success("Flashlight turned off")
                    } catch (e: Exception) {
                        result.error("FLASHLIGHT_ERROR", "Failed to turn off flashlight", e.message)
                    }
                }
                "setVibrationMode" -> {
                    audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
                    result.success("Vibration mode activated")
                }
                "setSoundMode" -> {
                    audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
                    result.success("Sound mode activated")
                }
                "setSilentMode" -> {
                    if (notificationManager.isNotificationPolicyAccessGranted) {
                        audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                        result.success("Silent mode activated")
                    } else {
                        requestDoNotDisturbPermission()
                        result.error("PERMISSION_DENIED", "Do Not Disturb permission is required", null)
                    }
                }
                "enableDarkMode" -> {
                    if (checkWriteSettingsPermission()) {
                        adjustScreenBrightness(-30) // 밝기 30 감소
                        result.success("Brightness decreased for Dark Mode")
                    } else {
                        requestWriteSettingsPermission()
                        result.error("PERMISSION_DENIED", "Write settings permission is required", null)
                    }
                }
                "enableLightMode" -> {
                    if (checkWriteSettingsPermission()) {
                        adjustScreenBrightness(30) // 밝기 30 증가
                        result.success("Brightness increased for Light Mode")
                    } else {
                        requestWriteSettingsPermission()
                        result.error("PERMISSION_DENIED", "Write settings permission is required", null)
                    }
                }
                "getOutApp" -> {
                    finishAffinity() // 현재 앱의 모든 액티비티 종료
                    result.success("App closed successfully")
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

    private fun launchApp(packageName: String, extraData: String?): Boolean {
        print("packageName is $packageName and extraData is $extraData")
        return when (packageName) {
            "com.samsung.android.dialer" -> {
                print("packageName is $packageName and extraData is $extraData")
                if (!extraData.isNullOrEmpty()) {
                    val sanitizedNumber = extraData.replace("\\s".toRegex(), "")
                    val intent = Intent(Intent.ACTION_DIAL).apply {
                        data = Uri.parse("tel:$sanitizedNumber")
                    }
                    startActivity(intent)
                    true
                } else {
                    false
                }
            }
            "com.sec.android.app.sbrowser" -> {
                print("packageName is $packageName and extraData is $extraData")
                if (!extraData.isNullOrEmpty()) {
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        data = Uri.parse(extraData)
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
    private fun requestDoNotDisturbPermission() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
        startActivity(intent)
    }

    private fun checkWriteSettingsPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.System.canWrite(applicationContext)
        } else {
            true
        }
    }

    private fun requestWriteSettingsPermission() {
        val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun adjustScreenBrightness(adjustment: Int) {
        try {
            val resolver: ContentResolver = contentResolver
            val currentBrightness = Settings.System.getInt(resolver, Settings.System.SCREEN_BRIGHTNESS)
            val newBrightness = (currentBrightness + adjustment).coerceIn(0, 255) // 0~255 범위로 제한
            Settings.System.putInt(resolver, Settings.System.SCREEN_BRIGHTNESS, newBrightness)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

}
