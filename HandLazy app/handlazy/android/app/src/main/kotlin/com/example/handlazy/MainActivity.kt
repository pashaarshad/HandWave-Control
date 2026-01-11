package com.example.handlazy

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import android.content.Context
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.handlazy/gestures"
    private val TAG = "HandLazy"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    val enabled = isMyAccessibilityEnabled()
                    Log.d(TAG, "isAccessibilityEnabled called, result: $enabled")
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
                        Log.e(TAG, "swipeUp failed: service instance is null")
                        result.error("SERVICE_NOT_RUNNING", "Accessibility service not running", null)
                    }
                }
                "swipeDown" -> {
                    val service = GestureAccessibilityService.getInstance()
                    if (service != null) {
                        service.swipeDown()
                        result.success(true)
                    } else {
                        Log.e(TAG, "swipeDown failed: service instance is null")
                        result.error("SERVICE_NOT_RUNNING", "Accessibility service not running", null)
                    }
                }
                "setVolume" -> {
                    val volume = call.argument<Int>("volume") ?: 50
                    val service = GestureAccessibilityService.getInstance()
                    if (service != null) {
                        service.setVolume(volume)
                        result.success(true)
                    } else {
                        result.error("SERVICE_NOT_RUNNING", "Accessibility service not running", null)
                    }
                }
                "updateCursor" -> {
                    val x = call.argument<Double>("x")?.toFloat()
                    val y = call.argument<Double>("y")?.toFloat()
                    val service = GestureAccessibilityService.getInstance()
                    if (service != null && x != null && y != null) {
                        service.updateCursorPosition(x, y)
                        result.success(true)
                    } else {
                        result.success(false) 
                    }
                }
                "hideCursor" -> {
                    val service = GestureAccessibilityService.getInstance()
                    if (service != null) {
                        service.hideCursor()
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "showCursor" -> {
                    val service = GestureAccessibilityService.getInstance()
                    if (service != null) {
                        service.showCursor()
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ✅ CORRECT Accessibility Check - checks YOUR specific service
    private fun isMyAccessibilityEnabled(): Boolean {
        // Build the expected service component name
        val expectedService = "$packageName/${GestureAccessibilityService::class.java.name}"
        
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        
        Log.d(TAG, "Expected service: $expectedService")
        Log.d(TAG, "Enabled services: $enabledServices")
        
        if (enabledServices.isNullOrEmpty()) {
            Log.d(TAG, "No accessibility services enabled")
            return false
        }
        
        // Check if our service is in the list
        val isEnabled = enabledServices.contains(expectedService)
        
        // Also check if instance is alive (service could be enabled but not yet started)
        val instanceAlive = GestureAccessibilityService.isServiceEnabled()
        
        Log.d(TAG, "Service in settings: $isEnabled, Instance alive: $instanceAlive")
        
        return isEnabled || instanceAlive
    }

    // ✅ Re-check accessibility when user returns from Settings
    override fun onResume() {
        super.onResume()
        
        // Notify Flutter about current accessibility state
        val enabled = isMyAccessibilityEnabled()
        Log.d(TAG, "onResume: Accessibility enabled = $enabled")
        
        // Send update to Flutter
        methodChannel?.invokeMethod("accessibilityStatusChanged", enabled)
    }
}
