package com.example.handlazy

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import android.content.Context

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.handlazy/gestures"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    // Robust check using system service list
                    var enabled = false
                    val prefString = Settings.Secure.getString(
                        contentResolver,
                        Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                    )
                    if (prefString != null) {
                        enabled = prefString.contains("$packageName/${GestureAccessibilityService::class.java.canonicalName}")
                    }
                    // Fallback to static instance check if string check fails but instance exists
                    if (!enabled && GestureAccessibilityService.isServiceEnabled()) {
                        enabled = true
                    }
                    result.success(enabled)
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(true)
                }
                "showToast" -> {
                    val message = call.argument<String>("message")
                    if (message != null) {
                        android.widget.Toast.makeText(context, message, android.widget.Toast.LENGTH_SHORT).show()
                    }
                    result.success(true)
                }
                "swipeUp" -> {
                    val service = GestureAccessibilityService.getInstance()
                    if (service != null) {
                        service.swipeUp()
                        result.success(true)
                    } else {
                        result.error("SERVICE_NOT_ENABLED", "Accessibility service not enabled", null)
                    }
                }
                "swipeDown" -> {
                    val service = GestureAccessibilityService.getInstance()
                    if (service != null) {
                        service.swipeDown()
                        result.success(true)
                    } else {
                        result.error("SERVICE_NOT_ENABLED", "Accessibility service not enabled", null)
                    }
                }
                "setVolume" -> {
                    val volume = call.argument<Int>("volume") ?: 50
                    val service = GestureAccessibilityService.getInstance()
                    if (service != null) {
                        service.setVolume(volume)
                        result.success(true)
                    } else {
                        result.error("SERVICE_NOT_ENABLED", "Accessibility service not enabled", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
