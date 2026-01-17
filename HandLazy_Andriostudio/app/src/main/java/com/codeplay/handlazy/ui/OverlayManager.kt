package com.codeplay.handlazy.ui

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import com.codeplay.handlazy.R
import com.codeplay.handlazy.repository.GestureType

class OverlayManager(private val context: Context) {

    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var cursorView: View? = null
    private var cursorImageView: ImageView? = null
    
    // Layout Params for the Cursor (Always on top, not touchable)
    private val cursorParams = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
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

    fun show() {
        if (cursorView == null) {
            val inflater = LayoutInflater.from(context)
            cursorView = inflater.inflate(R.layout.layout_cursor, null)
            cursorImageView = cursorView?.findViewById(R.id.iv_cursor)
            
            try {
                windowManager.addView(cursorView, cursorParams)
            } catch (e: Exception) {
                // Permission might be missing or other error
                e.printStackTrace()
            }
        }
    }

    fun updatePosition(x: Float, y: Float) {
        if (cursorView != null) {
            cursorParams.x = x.toInt() - (cursorView!!.width / 2)
            cursorParams.y = y.toInt() - (cursorView!!.height / 2)
            try {
                windowManager.updateViewLayout(cursorView, cursorParams)
            } catch (e: Exception) {
                // Window might be gone
            }
        }
    }

    fun updateState(type: GestureType) {
        // Visual feedback based on state
        // e.g., Green for Hold, Yellow for Point
        cursorImageView?.let { iv ->
            when (type) {
                GestureType.PINCH_HOLD -> iv.setColorFilter(0xFF00FF00.toInt()) // Green
                GestureType.PINCH_START -> iv.setColorFilter(0xFFFF0000.toInt()) // Red
                else -> iv.clearColorFilter()
            }
        }
    }
    
    fun hide() {
        if (cursorView != null) {
            try {
                windowManager.removeView(cursorView)
            } catch (e: Exception) {}
            cursorView = null
        }
    }
}
