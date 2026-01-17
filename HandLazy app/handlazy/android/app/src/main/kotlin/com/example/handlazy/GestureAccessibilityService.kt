package com.example.handlazy

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.res.Resources
import android.graphics.Color
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import com.example.handlazy.math.CoordinateMapper

/**
 * Accessibility Service for HandLazy that:
 * 1. Displays a persistent yellow dot cursor overlay
 * 2. Dispatches system gestures (scroll, click) for reel navigation
 */
class GestureAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "HandLazy"
        
        @Volatile
        private var instance: GestureAccessibilityService? = null
        
        fun getInstance(): GestureAccessibilityService? = instance
        
        fun isServiceEnabled(): Boolean = instance != null
    }

    private lateinit var windowManager: WindowManager
    private lateinit var coordinateMapper: CoordinateMapper
    private var cursorView: View? = null
    private var cursorParams: WindowManager.LayoutParams? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    
    // Cursor size
    private val cursorSize = 40 // dp
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        
        // Initialize coordinate mapper with screen dimensions
        val metrics = Resources.getSystem().displayMetrics
        coordinateMapper = CoordinateMapper(metrics.widthPixels, metrics.heightPixels)
        
        Log.d(TAG, "Accessibility Service Connected. Screen: ${metrics.widthPixels}x${metrics.heightPixels}")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not needed for gesture control
    }

    override fun onInterrupt() {
        Log.d(TAG, "Service Interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        hideCursor()
        instance = null
        Log.d(TAG, "Accessibility Service Destroyed")
    }

    // ==================== CURSOR OVERLAY ====================
    
    private fun createCursorView(): View {
        val view = View(this)
        val drawable = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.YELLOW)
            setStroke(3, Color.RED)
        }
        view.background = drawable
        return view
    }


    fun showCursor() {
        mainHandler.post {
            if (cursorView == null) {
                cursorView = createCursorView()
                
                val size = (cursorSize * Resources.getSystem().displayMetrics.density).toInt()
                
                cursorParams = WindowManager.LayoutParams(
                    size,
                    size,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                    else
                        WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.TOP or Gravity.START
                    x = 0
                    y = 0
                }

                try {
                    windowManager.addView(cursorView, cursorParams)
                    Log.d(TAG, "Cursor overlay shown")
                } catch (e: Exception) {
                    Log.e(TAG, "Error showing cursor: ${e.message}")
                }
            }
        }
    }

    fun hideCursor() {
        mainHandler.post {
            cursorView?.let { view ->
                try {
                    windowManager.removeView(view)
                    Log.d(TAG, "Cursor overlay hidden")
                } catch (e: Exception) {
                    Log.e(TAG, "Error hiding cursor: ${e.message}")
                }
                cursorView = null
                cursorParams = null
            }
        }
    }

    /**
     * Update cursor position.
     * @param normX Normalized X (0.0 to 1.0) - raw from MediaPipe
     * @param normY Normalized Y (0.0 to 1.0) - raw from MediaPipe  
     */
    fun updateCursorPosition(normX: Float, normY: Float) {
        // First show cursor if not visible
        if (cursorView == null) {
            showCursor()
        }
        
        mainHandler.post {
            cursorView?.let { view ->
                cursorParams?.let { params ->
                    try {
                        // Use CoordinateMapper for proper transformation + smoothing
                        val timestamp = System.currentTimeMillis()
                        val (screenX, screenY) = coordinateMapper.map(normX, normY, timestamp)
                        
                        // Center the cursor on the point
                        params.x = (screenX - view.width / 2).toInt()
                        params.y = (screenY - view.height / 2).toInt()
                        
                        windowManager.updateViewLayout(view, params)
                    } catch (e: Exception) {
                        // Window might be gone
                    }
                }
            }
        }
    }
    
    /**
     * Flash the cursor a specific color for visual feedback.
     */
    fun flashCursor(color: Int) {
        mainHandler.post {
            cursorView?.let { view ->
                val bg = view.background as? GradientDrawable
                bg?.setColor(color)
                view.invalidate()
                
                // Revert to yellow after 300ms
                mainHandler.postDelayed({
                    bg?.setColor(Color.YELLOW)
                    view.invalidate()
                }, 300)
            }
        }
    }

    // ==================== GESTURE ACTIONS ====================
    
    /**
     * Perform swipe up gesture (Next Reel).
     */
    fun swipeUp() {
        flashCursor(Color.GREEN)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val metrics = Resources.getSystem().displayMetrics
            val screenHeight = metrics.heightPixels
            val screenWidth = metrics.widthPixels

            val path = Path().apply {
                moveTo(screenWidth / 2f, screenHeight * 0.7f)
                lineTo(screenWidth / 2f, screenHeight * 0.3f)
            }

            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
                .build()

            dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    Log.d(TAG, "Swipe UP completed - Next Reel")
                }
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    Log.w(TAG, "Swipe UP cancelled")
                }
            }, null)
        }
    }

    /**
     * Perform swipe down gesture (Previous Reel).
     */
    fun swipeDown() {
        flashCursor(Color.MAGENTA)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val metrics = Resources.getSystem().displayMetrics
            val screenHeight = metrics.heightPixels
            val screenWidth = metrics.widthPixels

            val path = Path().apply {
                moveTo(screenWidth / 2f, screenHeight * 0.3f)
                lineTo(screenWidth / 2f, screenHeight * 0.7f)
            }

            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
                .build()

            dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    Log.d(TAG, "Swipe DOWN completed - Prev Reel")
                }
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    Log.w(TAG, "Swipe DOWN cancelled")
                }
            }, null)
        }
    }

    /**
     * Set system media volume (0-100).
     */
    fun setVolume(volumePercent: Int) {
        flashCursor(Color.CYAN)
        
        val audioManager = getSystemService(AUDIO_SERVICE) as? AudioManager
        audioManager?.let { am ->
            val maxVolume = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val volume = (maxVolume * volumePercent / 100.0).toInt()
            am.setStreamVolume(AudioManager.STREAM_MUSIC, volume, 0)
            Log.d(TAG, "Volume set to: $volumePercent%")
        }
    }
}
