package com.example.handlazy

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.res.Resources
import android.graphics.Color
import android.graphics.Path
import android.graphics.PixelFormat
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.FrameLayout
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import java.util.concurrent.Executors
import java.util.concurrent.ExecutorService
import kotlin.math.sqrt
import kotlin.math.pow
import com.example.handlazy.math.CoordinateMapper
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import com.google.mediapipe.framework.image.BitmapImageBuilder

class GestureAccessibilityService : AccessibilityService(), LifecycleOwner {

    companion object {
        private const val TAG = "HandLazy"
        @Volatile private var instance: GestureAccessibilityService? = null
        fun getInstance(): GestureAccessibilityService? = instance
        fun isServiceEnabled(): Boolean = instance != null
    }

    private val lifecycleRegistry = LifecycleRegistry(this)
    override val lifecycle: Lifecycle get() = lifecycleRegistry

    private lateinit var windowManager: WindowManager
    private var floatingView: View? = null
    private var previewView: PreviewView? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var cameraExecutor: ExecutorService? = null
    
    // ML Vars
    private var handLandmarker: HandLandmarker? = null
    private var lastActionTime = 0L
    private var lastVolumeChangeTime = 0L
    private var wasPinching = false
    private var isVolumeIncreasing = true
    private var prevIndexY: Float? = null
    private var volume = 50

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        cameraExecutor = Executors.newSingleThreadExecutor()
        lifecycleRegistry.currentState = Lifecycle.State.STARTED
        Log.d(TAG, "Accessibility Connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}
    override fun onDestroy() {
        stopNativeTracking()
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        cameraExecutor?.shutdown()
        super.onDestroy()
    }

    fun startNativeTracking() {
        mainHandler.post {
            if (floatingView == null) {
                createFloatingWindow()
                setupMediaPipe()
                startCamera()
                Log.d(TAG, "Native Tracking Started")
            }
        }
    }

    fun stopNativeTracking() {
        mainHandler.post {
            floatingView?.let { windowManager.removeView(it) }
            floatingView = null
            previewView = null
            
            // Clean up ML
            handLandmarker?.close()
            handLandmarker = null
        }
    }

    private fun createFloatingWindow() {
        val frame = FrameLayout(this)
        frame.setBackgroundColor(Color.BLACK)
        
        previewView = PreviewView(this)
        previewView?.scaleType = PreviewView.ScaleType.FILL_CENTER
        frame.addView(previewView)
        
        // Add border for feedback
        val border = View(this).apply {
             background = android.graphics.drawable.GradientDrawable().apply {
                 setStroke(8, Color.GREEN)
                 setColor(Color.TRANSPARENT)
             }
             tag = "border"
        }
        frame.addView(border)

        val params = WindowManager.LayoutParams(
            300, 400,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.END
        params.x = 20
        params.y = 100
        
        // Simple drag
        frame.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> true
                // Implement drag if needed, skipped for brevity in this final fix
                else -> false
            }
        }
        
        floatingView = frame
        windowManager.addView(frame, params)
    }
    
    private fun setupMediaPipe() {
        try {
            val baseOptions = BaseOptions.builder()
                .setModelAssetPath("hand_landmarker.task")
                .build()
            
            val options = HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setNumHands(1)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setResultListener { result, _ -> 
                    processLandmarks(result) 
                }
                .build()
                
            handLandmarker = HandLandmarker.createFromOptions(this, options)
            Log.d(TAG, "MediaPipe Initialized")
        } catch (e: Exception) {
            Log.e(TAG, "MediaPipe Init Failed", e)
        }
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()
                val preview = Preview.Builder().build()
                preview.setSurfaceProvider(previewView!!.surfaceProvider)
                
                val imageAnalyzer = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .build()
                    
                imageAnalyzer.setAnalyzer(cameraExecutor!!) { imageProxy ->
                    analyzeImage(imageProxy)
                }

                val cameraSelector = CameraSelector.DEFAULT_FRONT_CAMERA
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(this, cameraSelector, preview, imageAnalyzer)
                Log.d(TAG, "Camera Started")
            } catch (e: Exception) {
                Log.e(TAG, "Camera Start Failed", e)
            }
        }, ContextCompat.getMainExecutor(this))
    }
    
    private fun analyzeImage(imageProxy: ImageProxy) {
        if (handLandmarker == null) {
            imageProxy.close()
            return
        }
        
        // Convert ImageProxy to MPImage
        val bitmap = imageProxy.toBitmap()
        val mpImage = BitmapImageBuilder(bitmap).build()
        handLandmarker?.detectAsync(mpImage, System.currentTimeMillis())
        imageProxy.close()
    }
    
    private fun processLandmarks(result: HandLandmarkerResult) {
        if (result.landmarks().isEmpty()) {
            updateBorder(Color.RED)
            return
        }
        
        updateBorder(Color.GREEN)
        val landmarks = result.landmarks()[0]
        val now = System.currentTimeMillis()

        // Key Points (normalized)
        val thumb = landmarks[4]
        val index = landmarks[8]
        val pinky = landmarks[20]
        val wrist = landmarks[0]

        // Distances
        val thumbIndex = dist(thumb.x(), thumb.y(), index.x(), index.y())
        val indexWrist = dist(index.x(), index.y(), wrist.x(), wrist.y())
        val pinkyWrist = dist(pinky.x(), pinky.y(), wrist.x(), wrist.y())
        
        // Simple logic from before
        val isPinching = thumbIndex < 0.08
        val isOpen = indexWrist > 0.2 && pinkyWrist > 0.15

        if (isPinching) {
            updateBorder(Color.CYAN)
            handlePinch(now)
        } else if (isOpen) {
             updateBorder(Color.MAGENTA)
            if (now - lastActionTime > 800) {
                swipeDown() // Prev Reel
                lastActionTime = now
            }
        } else {
             updateBorder(Color.YELLOW)
            // Pointing / Scroll
            if (prevIndexY != null && (now - lastActionTime > 600)) {
                val dy = index.y() - prevIndexY!!
                // Note: Y increases downwards in image coordinates. dy < 0 means moving UP.
                // To scroll "Next" (scroll down), user typically moves finger UP? 
                // Wait, "Swipe Up" gesture means touching screen and moving UP? 
                // Gestures: swipeUp() performs a drag from down to up.
                if (dy < -0.05) { 
                    swipeUp() // Next Reel
                    lastActionTime = now
                }
            }
        }
        
        wasPinching = isPinching
        prevIndexY = index.y()
    }
    
    private fun handlePinch(now: Long) {
        if (!wasPinching) {
            isVolumeIncreasing = !isVolumeIncreasing
        }
        
        if (now - lastVolumeChangeTime > 200) {
            if (isVolumeIncreasing && volume < 100) volume += 10
            if (!isVolumeIncreasing && volume > 0) volume -= 10
            setVolume(volume)
            lastVolumeChangeTime = now
        }
    }

    private fun updateBorder(color: Int) {
        mainHandler.post {
            floatingView?.findViewWithTag<View>("border")?.let {
                val bg = it.background as? android.graphics.drawable.GradientDrawable
                bg?.setStroke(8, color)
            }
        }
    }
    
    private fun dist(x1: Float, y1: Float, x2: Float, y2: Float): Float {
        return sqrt((x1 - x2).pow(2) + (y1 - y2).pow(2))
    }

    fun setVolume(percent: Int) {
        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val vol = (max * percent / 100.0).toInt()
        am.setStreamVolume(AudioManager.STREAM_MUSIC, vol, 0)
    }
    
    // Gesture Helpers
    fun swipeUp() { performSwipe(0.7f, 0.3f) }
    fun swipeDown() { performSwipe(0.3f, 0.7f) }
    
    private fun performSwipe(startYRatio: Float, endYRatio: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
             val metrics = Resources.getSystem().displayMetrics
             val w = metrics.widthPixels
             val h = metrics.heightPixels
             val path = Path().apply {
                 moveTo(w / 2f, h * startYRatio)
                 lineTo(w / 2f, h * endYRatio)
             }
             val gesture = GestureDescription.Builder()
                 .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
                 .build()
             dispatchGesture(gesture, null, null)
        }
    }
    
    // Stubs
    fun showCursor() {}
    fun hideCursor() {}
    fun updateCursorPosition(x: Float, y: Float) {}
}
