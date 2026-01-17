package com.codeplay.handlazy.processor

import com.codeplay.handlazy.repository.GestureType

class GestureStateMachine {
    
    // Config
    private val pinchThreshold = 200L // ms to confirm hold
    private val clickDebounce = 300L

    private var stateStartTime = 0L
    private var lastState = GestureType.IDLE

    fun process(rawType: GestureType, timestamp: Long): GestureType {
        // Simple state machine for now
        // rawType comes from simple Geometry (isPinching?)
        
        // Transitions:
        // POINTING -> PINCH_START
        // PINCH_START -> (wait) -> PINCH_HOLD
        // PINCH_HOLD -> PINCH_RELEASE (when rawType becomes OPEN/POINTING)
        
        return when (lastState) {
            GestureType.IDLE, GestureType.OPEN_HAND, GestureType.POINTING -> {
                if (rawType == GestureType.FIST) { // Assuming Fist or Pinch is valid trigger
                    transition(GestureType.PINCH_START, timestamp)
                } else {
                    // Keep updating movement
                    rawType
                }
            }
            GestureType.PINCH_START -> {
                if (rawType == GestureType.FIST) {
                     if (timestamp - stateStartTime > pinchThreshold) {
                         transition(GestureType.PINCH_HOLD, timestamp)
                     } else {
                         GestureType.PINCH_START
                     }
                } else {
                    // Quick release? It's a CLICK
                    transition(GestureType.PINCH_RELEASE, timestamp) // Which maps to CLICK
                }
            }
            GestureType.PINCH_HOLD -> {
                if (rawType != GestureType.FIST) {
                    transition(GestureType.PINCH_RELEASE, timestamp)
                } else {
                    GestureType.PINCH_HOLD
                }
            }
            GestureType.PINCH_RELEASE -> {
                // One frame state, then reset
                transition(rawType, timestamp)
            }
            else -> rawType
        }
    }

    private fun transition(newState: GestureType, time: Long): GestureType {
        lastState = newState
        stateStartTime = time
        return newState
    }
}
