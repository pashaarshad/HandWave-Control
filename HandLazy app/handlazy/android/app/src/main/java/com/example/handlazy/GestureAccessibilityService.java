package com.example.handlazy;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.graphics.Path;
import android.os.Handler;
import android.os.Looper;
import android.view.accessibility.AccessibilityEvent;
import android.util.Log;

public class GestureAccessibilityService extends AccessibilityService {
    private static final String TAG = "HandLazyGesture";
    private static GestureAccessibilityService instance;
    private android.view.WindowManager windowManager;
    private android.view.View cursorView;
    private android.view.WindowManager.LayoutParams cursorParams;
    private Handler mainHandler;

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        mainHandler = new Handler(Looper.getMainLooper());
        windowManager = (android.view.WindowManager) getSystemService(WINDOW_SERVICE);
        createCursorView();
        Log.d(TAG, "Accessibility Service Created");
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        // Not needed for gesture performance
    }

    @Override
    public void onInterrupt() {
        Log.d(TAG, "Service Interrupted");
    }

    private void createCursorView() {
        cursorView = new android.view.View(this);
        android.graphics.drawable.GradientDrawable drawable = new android.graphics.drawable.GradientDrawable();
        drawable.setShape(android.graphics.drawable.GradientDrawable.OVAL);
        drawable.setColor(android.graphics.Color.YELLOW);
        drawable.setStroke(3, android.graphics.Color.RED);
        cursorView.setBackground(drawable);

        cursorParams = new android.view.WindowManager.LayoutParams(
            40, // Width
            40, // Height
            android.view.WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE |
            android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE |
            android.view.WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN |
            android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            android.graphics.PixelFormat.TRANSLUCENT
        );
        cursorParams.gravity = android.view.Gravity.TOP | android.view.Gravity.START;
        cursorParams.x = 0;
        cursorParams.y = 0;
    }

    public void showCursor() {
        if (cursorView.getParent() == null) {
            mainHandler.post(() -> {
                try {
                    windowManager.addView(cursorView, cursorParams);
                } catch (Exception e) {
                    Log.e(TAG, "Error showing cursor: " + e.getMessage());
                }
            });
        }
    }

    public void hideCursor() {
        if (cursorView.getParent() != null) {
            mainHandler.post(() -> {
                try {
                    windowManager.removeView(cursorView);
                } catch (Exception e) {
                    Log.e(TAG, "Error hiding cursor: " + e.getMessage());
                }
            });
        }
    }

    public void updateCursorPosition(float x, float y) {
        if (cursorView.getParent() == null) {
             showCursor();
        }
        
        mainHandler.post(() -> {
            try {
                int screenWidth = getResources().getDisplayMetrics().widthPixels;
                int screenHeight = getResources().getDisplayMetrics().heightPixels;

                // X is mirrored (1.0 - x) because front camera matches mirror logic usually,
                // but depends on how flutter sends it. Let's assume Flutter sends raw landmark.
                // Raw MediaPipe landmarks: x is 0 on left, 1 on right of IMAGE.
                // Front camera image is usually mirrored relative to user?
                // Let's stick to standard mapping first.
                
                cursorParams.x = (int) (x * screenWidth);
                cursorParams.y = (int) (y * screenHeight);
                windowManager.updateViewLayout(cursorView, cursorParams);
            } catch (Exception e) {
                // Ignore transient update errors
            }
        });
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        hideCursor();
        instance = null;
        Log.d(TAG, "Accessibility Service Destroyed");
    }

    public static GestureAccessibilityService getInstance() {
        return instance;
    }

    public static boolean isServiceEnabled() {
        return instance != null;
    }

    // Perform swipe up gesture (Next Reel)
    public void swipeUp() {
        showOneTimeFeedback(android.graphics.Color.GREEN); // Feedback flash
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
             int screenHeight = getResources().getDisplayMetrics().heightPixels;
             int screenWidth = getResources().getDisplayMetrics().widthPixels;

             Path swipePath = new Path();
             swipePath.moveTo(screenWidth / 2f, screenHeight * 0.7f);
             swipePath.lineTo(screenWidth / 2f, screenHeight * 0.3f);

             GestureDescription.Builder gestureBuilder = new GestureDescription.Builder();
             gestureBuilder.addStroke(new GestureDescription.StrokeDescription(swipePath, 0, 300));

             dispatchGesture(gestureBuilder.build(), null, null);
        }
    }

    // Perform swipe down gesture (Previous Reel)
    public void swipeDown() {
        showOneTimeFeedback(android.graphics.Color.MAGENTA); // Feedback flash
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
            int screenHeight = getResources().getDisplayMetrics().heightPixels;
            int screenWidth = getResources().getDisplayMetrics().widthPixels;

            Path swipePath = new Path();
            swipePath.moveTo(screenWidth / 2f, screenHeight * 0.3f);
            swipePath.lineTo(screenWidth / 2f, screenHeight * 0.7f);

            GestureDescription.Builder gestureBuilder = new GestureDescription.Builder();
            gestureBuilder.addStroke(new GestureDescription.StrokeDescription(swipePath, 0, 300));

            dispatchGesture(gestureBuilder.build(), null, null);
        }
    }
    
    // Quick visual flash for action feedback
    private void showOneTimeFeedback(int color) {
        if (cursorView.getParent() != null) {
            mainHandler.post(() -> {
                 android.graphics.drawable.GradientDrawable bg = (android.graphics.drawable.GradientDrawable) cursorView.getBackground();
                 bg.setColor(color);
                 cursorView.invalidate();
                 
                 // Revert to yellow after 500ms
                 mainHandler.postDelayed(() -> {
                     bg.setColor(android.graphics.Color.YELLOW);
                     cursorView.invalidate();
                 }, 500);
            });
        }
    }

    // Set volume (0-100)
    public void setVolume(int volumePercent) {
        showOneTimeFeedback(android.graphics.Color.CYAN); // Feedback flash
        android.media.AudioManager audioManager = 
            (android.media.AudioManager) getSystemService(AUDIO_SERVICE);
        if (audioManager != null) {
            int maxVolume = audioManager.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC);
            int volume = (int) (maxVolume * volumePercent / 100.0);
            audioManager.setStreamVolume(
                android.media.AudioManager.STREAM_MUSIC, 
                volume, 
                0
            );
            Log.d(TAG, "Volume set to: " + volumePercent + "%");
        }
    }
}
