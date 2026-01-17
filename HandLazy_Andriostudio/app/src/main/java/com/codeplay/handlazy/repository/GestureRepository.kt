package com.codeplay.handlazy.repository

import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow

data class HandGestureState(
    val type: GestureType,
    val x: Float = 0f, 
    val y: Float = 0f,
    val landmarks: List<NormalizedLandmark> = emptyList(),
    val handedness: String = "Unknown",
    val timestamp: Long = 0L
)

data class NormalizedLandmark(
    val x: Float,
    val y: Float,
    val z: Float
)

enum class GestureType {
    IDLE, OPEN_HAND, FIST, POINTING, PINCH_START, PINCH_HOLD, PINCH_RELEASE, SCROLL
}

object GestureRepository {
    // Replay = 0, ExtraBuffer = 1, Drop Oldest
    private val _gestures = MutableSharedFlow<HandGestureState>(
        replay = 0,
        extraBufferCapacity = 1,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val gestures = _gestures.asSharedFlow()

    fun emit(state: HandGestureState) {
        _gestures.tryEmit(state)
    }
}
