package com.codeplay.handlazy.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.lifecycle.LifecycleService
import androidx.lifecycle.lifecycleScope
import com.codeplay.handlazy.R
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import java.util.concurrent.Executors
import android.util.Log
import com.codeplay.handlazy.processor.HandLandmarkerHelper
import com.codeplay.handlazy.processor.GestureProcessor
import com.codeplay.handlazy.repository.HandGestureState

class HandTrackingService : LifecycleService() {

    private var wakeLock: PowerManager.WakeLock? = null

    private lateinit var handLandmarkerHelper: HandLandmarkerHelper

    override fun onCreate() {
        super.onCreate()
        startForegroundService()
        acquireWakeLock() // Keep the CPU running
        
        // Initialize MediaPipe Helper
        handLandmarkerHelper = HandLandmarkerHelper(
            context = this,
            gestureListener = { result ->
                // This runs on a background thread from MediaPipe
                val state = GestureProcessor.processResult(result)
                GestureRepository.emit(state)
            },
            errorListener = { error ->
                Log.e("HandLazy", "MediaPipe Error: $error")
            }
        )
        
        // Start Camera
        startCamera()
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()
                bindCameraUseCases(cameraProvider)
            } catch (e: Exception) {
                Log.e("HandLazy", "Camera Initialization Failed", e)
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun bindCameraUseCases(cameraProvider: ProcessCameraProvider) {
        // CameraSelector
        val cameraSelector = CameraSelector.Builder()
            .requireLensFacing(CameraSelector.LENS_FACING_FRONT)
            .build()
            
        // ImageAnalysis
        val imageAnalysis = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888) // Easier for Bitmap conversion
            .build()
            
        imageAnalysis.setAnalyzer(Executors.newSingleThreadExecutor()) { imageProxy ->
            handLandmarkerHelper.detectLiveStream(imageProxy)
        }

        try {
            cameraProvider.unbindAll()
            cameraProvider.bindToLifecycle(
                this, // LifecycleService is a LifecycleOwner!
                cameraSelector,
                imageAnalysis
            )
        } catch (e: Exception) {
            Log.e("HandLazy", "Use case binding failed", e)
        }
    }

    private fun startForegroundService() {
        val channelId = "hand_tracking_channel"
        val channelName = getString(R.string.notification_channel_name)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(getString(R.string.notification_title))
            .setContentText(getString(R.string.notification_content))
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setOngoing(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
            
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA)
        } else {
            startForeground(1, notification)
        }
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "HandLazy::TrackingWakeLock"
        ).apply {
            acquire()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        handLandmarkerHelper.clear()
        wakeLock?.release()
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // Auto-restart logic
        val restartServiceIntent = Intent(applicationContext, this.javaClass)
        restartServiceIntent.setPackage(packageName)
        startService(restartServiceIntent)
    }
}
