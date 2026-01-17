package com.codeplay.handlazy.math

import android.util.Log

class CoordinateMapper(
    private val screenWidth: Int,
    private val screenHeight: Int
) {
    private val filterX = OneEuroFilter(minCutoff = 1.0f, beta = 0.007f, dCutoff = 1.0f)
    private val filterY = OneEuroFilter(minCutoff = 1.0f, beta = 0.007f, dCutoff = 1.0f)

    // Safety box: Map only the center portion of camera to full screen
    // This allows reaching corners easily without stretching arm too much
    private val marginX = 0.1f // 10% margin
    private val marginY = 0.1f // 10% margin

    fun map(normX: Float, normY: Float, timestamp: Long): Pair<Float, Float> {
        // 1. Mirror X (Front camera is mirrored)
        // MediaPipe X: 0 (Left) -> 1 (Right)
        // Screen X: 0 (Left) -> Width (Right)
        // But Front Cam acts like mirror: Moving hand RIGHT in air moves it LEFT in image if not mirrored.
        // MediaPipe results are usually normalized image coordinates.
        // Let's assume standard mirror behavior: Input X needs to be inverted.
        val mirroredX = 1.0f - normX

        // 2. Apply Safety Box / Sensitivity
        // Map [margin, 1-margin] to [0, 1]
        val roiW = 1.0f - 2 * marginX
        val roiH = 1.0f - 2 * marginY
        
        val scaledX = ((mirroredX - marginX) / roiW).coerceIn(0f, 1f)
        val scaledY = ((normY - marginY) / roiH).coerceIn(0f, 1f)

        // 3. Map to Screen Pixels
        val pixelX = scaledX * screenWidth
        val pixelY = scaledY * screenHeight

        // 4. Apply Smoothing
        val smoothX = filterX.filter(pixelX, timestamp)
        val smoothY = filterY.filter(pixelY, timestamp)

        return Pair(smoothX, smoothY)
    }
}
