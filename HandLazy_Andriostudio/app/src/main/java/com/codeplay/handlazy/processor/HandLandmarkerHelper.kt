package com.codeplay.handlazy.processor

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.SystemClock
import android.util.Log
import androidx.camera.core.ImageProxy
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult

class HandLandmarkerHelper(
    val context: Context,
    val gestureListener: (HandLandmarkerResult) -> Unit,
    val errorListener: (String) -> Unit
) {
    private var handLandmarker: HandLandmarker? = null

    init {
        setupHandLandmarker()
    }

    private fun setupHandLandmarker() {
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("hand_landmarker.task") // We need to download this asset!
            .setDelegate(Delegate.GPU) // Use GPU for performance
            .build()

        val options = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setMinHandDetectionConfidence(0.5f)
            .setMinHandTrackingConfidence(0.5f)
            .setMinHandPresenceConfidence(0.5f)
            .setNumHands(1)
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setResultListener(this::returnLivestreamResult)
            .setErrorListener(this::returnLivestreamError)
            .build()

        try {
            handLandmarker = HandLandmarker.createFromOptions(context, options)
        } catch (e: IllegalStateException) {
            errorListener("HandLandmarker failed to initialize: ${e.message}")
        } catch (e: RuntimeException) {
            errorListener("HandLandmarker failed to initialize: ${e.message}")
        }
    }

    fun detectLiveStream(imageProxy: ImageProxy) {
        if (handLandmarker == null) {
            setupHandLandmarker()
        }

        val frameTime = SystemClock.uptimeMillis()
        
        // Convert ImageProxy to MPImage
        // Note: For optimal efficiency we should use ByteBuffer but Bitmap is safer for rotation handling initially
        val bitmapBuffer = Bitmap.createBitmap(
            imageProxy.width, 
            imageProxy.height, 
            Bitmap.Config.ARGB_8888
        )
        
        // This copy is heavy; in production, use YUV directly if possible or imageProxy.image
        // However, CameraX ImageAnalysis -> MPImage conversion is tricky with rotation.
        // Let's rely on tasks-vision utils if available, or manual conversion.
        // For Phase 2 verification, we will use a dedicated converter helper or simplified flow.
        // The safest robust way without external utils:
        
        imageProxy.use { 
            // We need to handle rotation. 
            // If we just pass the buffer, MP might not handle rotation correctly unless specified in image properties.
            // Simplified approach: Bitmap conversion (Expensive but works)
            
            val bitmap = it.toBitmap() // Requires androidx.camera:camera-core:1.3.1+
            val matrix = Matrix().apply {
                postRotate(it.imageInfo.rotationDegrees.toFloat())
            }
            val rotatedBitmap = Bitmap.createBitmap(
                bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true
            )
            
            val mpImage = BitmapImageBuilder(rotatedBitmap).build()
            handLandmarker?.detectAsync(mpImage, frameTime)
        }
    }

    private fun returnLivestreamResult(result: HandLandmarkerResult, input: MPImage) {
        gestureListener(result)
    }

    private fun returnLivestreamError(error: RuntimeException) {
        errorListener(error.message ?: "Unknown error")
    }
    
    fun clear() {
        handLandmarker?.close()
        handLandmarker = null
    }
}
