package com.codeplay.handlazy.service

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.content.res.Resources
import com.codeplay.handlazy.math.CoordinateMapper
import com.codeplay.handlazy.ui.OverlayManager
import com.codeplay.handlazy.repository.GestureRepository
import com.codeplay.handlazy.repository.GestureType
import com.codeplay.handlazy.repository.HandGestureState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

class GlobalTouchService : AccessibilityService() {

    private val serviceScope = CoroutineScope(Dispatchers.Main + Job())
    private lateinit var coordinateMapper: CoordinateMapper
    private lateinit var overlayManager: OverlayManager
    private var isMapperInitialized = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        initializeMapper()
        initializeOverlay()
        observeGestures()
    }
    
    private fun initializeOverlay() {
        overlayManager = OverlayManager(this)
        overlayManager.show()
    }

    private fun initializeMapper() {
        val metrics = Resources.getSystem().displayMetrics
        coordinateMapper = CoordinateMapper(metrics.widthPixels, metrics.heightPixels)
        isMapperInitialized = true
        Log.d("HandLazy", "GlobalTouchService: Mapper initialized with ${metrics.widthPixels}x${metrics.heightPixels}")
    }

    private fun observeGestures() {
        serviceScope.launch {
            GestureRepository.gestures.collectLatest { state ->
               if (isMapperInitialized) {
                   performAction(state)
               }
            }
        }
    }

    private fun performAction(state: HandGestureState) {
        val (screenX, screenY) = coordinateMapper.map(state.x, state.y, state.timestamp)
        
        // Update Overlay
        overlayManager.updatePosition(screenX, screenY)
        overlayManager.updateState(state.type)
        
        when (state.type) {
             GestureType.PINCH_RELEASE -> { // Treat Release as Click
                Log.d("HandLazy", "Clicking at $screenX, $screenY")
                click(screenX, screenY)
             }
             GestureType.PINCH_HOLD -> {
                 // Drag logic (To Be Implemented)
             }
             else -> {
                 // Just moving cursor
             }
        }
    }

    private fun click(x: Float, y: Float) {
        val path = Path().apply { moveTo(x, y) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
            .build()
        dispatchGesture(gesture, null, null)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}
    
    override fun onDestroy() {
        super.onDestroy()
        overlayManager.hide()
    }
}
