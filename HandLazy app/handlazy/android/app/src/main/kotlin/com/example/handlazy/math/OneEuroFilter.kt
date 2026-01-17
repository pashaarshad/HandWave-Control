package com.example.handlazy.math

import kotlin.math.PI
import kotlin.math.abs

/**
 * One Euro Filter for smooth cursor movement.
 * This filter reduces jitter while maintaining responsiveness.
 */
class OneEuroFilter(
    private val minCutoff: Float = 1.0f, // Min cutoff frequency (Hz)
    private val beta: Float = 0.0f,      // Speed coefficient
    private val dCutoff: Float = 1.0f    // Derivative cutoff frequency (Hz)
) {
    private var xPrev: Float? = null
    private var dxPrev: Float? = null
    private var tPrev: Long? = null

    fun filter(x: Float, timestamp: Long): Float {
        // If first sample, return it as is
        if (tPrev == null || xPrev == null) {
             xPrev = x
             dxPrev = 0f
             tPrev = timestamp
             return x
        }

        val t = timestamp
        val dt = (t - tPrev!!) / 1000.0f // Convert millis to seconds
        
        // Avoid division by zero
        if (dt <= 0f) return xPrev!!

        // Compute derivative
        val dx = (x - xPrev!!) / dt
        val edx = lowPassFilter(dx, dxPrev!!, dt, dCutoff)
        
        // Compute cutoff based on speed
        val cutoff = minCutoff + beta * abs(edx)
        val result = lowPassFilter(x, xPrev!!, dt, cutoff)

        xPrev = result
        dxPrev = edx
        tPrev = t

        return result
    }

    private fun lowPassFilter(x: Float, xPrev: Float, dt: Float, cutoff: Float): Float {
        val rc = 1.0f / (2.0f * PI.toFloat() * cutoff)
        val alpha = dt / (dt + rc)
        return xPrev + alpha * (x - xPrev)
    }
    
    fun reset() {
        xPrev = null
        dxPrev = null
        tPrev = null
    }
}
