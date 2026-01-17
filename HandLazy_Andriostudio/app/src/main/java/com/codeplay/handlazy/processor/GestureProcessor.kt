package com.codeplay.handlazy.processor

import com.codeplay.handlazy.repository.GestureType
import com.codeplay.handlazy.repository.HandGestureState
import com.codeplay.handlazy.repository.NormalizedLandmark
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult

object GestureProcessor {

    private val stateMachine = GestureStateMachine()

    fun processResult(result: HandLandmarkerResult): HandGestureState {
        val timestamp = System.currentTimeMillis()
        
        if (result.landmarks().isEmpty()) {
            val stateType = stateMachine.process(GestureType.IDLE, timestamp)
            return HandGestureState(type = stateType, timestamp = timestamp)
        }

        val landmarks = result.landmarks()[0] // Get first hand
        val normalizedLandmarks = landmarks.map { 
            NormalizedLandmark(it.x(), it.y(), it.z()) 
        }
        
        // 1. Detect Raw Physical Pose
        val isFist = isFist(normalizedLandmarks)
        val isOpen = isOpenHand(normalizedLandmarks)
        
        val rawType = when {
            isFist -> GestureType.FIST
            isOpen -> GestureType.OPEN_HAND
            else -> GestureType.POINTING // Default assumption for now
        }
        
        // 2. Feed to State Machine to get Stable High-Level State
        val processedType = stateMachine.process(rawType, timestamp)
        
        // Index Finger Tip is index 8
        val tooltip = normalizedLandmarks[8]

        return HandGestureState(
            type = processedType,
            x = tooltip.x,
            y = tooltip.y,
            landmarks = normalizedLandmarks,
            handedness = result.handedness().firstOrNull()?.first()?.categoryName() ?: "Unknown",
            timestamp = timestamp
        )
    }

    private fun isFist(landmarks: List<NormalizedLandmark>): Boolean {
        // Simple logic: Tips are below PIP joints (y coordinate is higher in screen space = lower physically)
        // Wait, normalized Y: 0 is top, 1 is bottom.
        // Finger curled: Tip Y > PIP Y (for upright hand)
        val indexTipY = landmarks[8].y
        val indexPipY = landmarks[6].y
        return indexTipY > indexPipY
    }
    
    private fun isOpenHand(landmarks: List<NormalizedLandmark>): Boolean {
        val indexTipY = landmarks[8].y
        val indexPipY = landmarks[6].y
        return indexTipY < indexPipY
    }
}
