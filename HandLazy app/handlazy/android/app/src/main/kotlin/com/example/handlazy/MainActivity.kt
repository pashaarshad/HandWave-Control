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
                    result.success(GestureAccessibilityService.isServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
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
