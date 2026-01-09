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
    private Handler mainHandler;

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        mainHandler = new Handler(Looper.getMainLooper());
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

    @Override
    public void onDestroy() {
        super.onDestroy();
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
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
            int screenHeight = getResources().getDisplayMetrics().heightPixels;
            int screenWidth = getResources().getDisplayMetrics().widthPixels;

            Path swipePath = new Path();
            swipePath.moveTo(screenWidth / 2f, screenHeight * 0.7f);
            swipePath.lineTo(screenWidth / 2f, screenHeight * 0.3f);

            GestureDescription.Builder gestureBuilder = new GestureDescription.Builder();
            gestureBuilder.addStroke(new GestureDescription.StrokeDescription(swipePath, 0, 300));

            dispatchGesture(gestureBuilder.build(), new GestureResultCallback() {
                @Override
                public void onCompleted(GestureDescription gestureDescription) {
                    Log.d(TAG, "Swipe Up completed - Next Reel");
                }
            }, null);
        }
    }

    // Perform swipe down gesture (Previous Reel)
    public void swipeDown() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
            int screenHeight = getResources().getDisplayMetrics().heightPixels;
            int screenWidth = getResources().getDisplayMetrics().widthPixels;

            Path swipePath = new Path();
            swipePath.moveTo(screenWidth / 2f, screenHeight * 0.3f);
            swipePath.lineTo(screenWidth / 2f, screenHeight * 0.7f);

            GestureDescription.Builder gestureBuilder = new GestureDescription.Builder();
            gestureBuilder.addStroke(new GestureDescription.StrokeDescription(swipePath, 0, 300));

            dispatchGesture(gestureBuilder.build(), new GestureResultCallback() {
                @Override
                public void onCompleted(GestureDescription gestureDescription) {
                    Log.d(TAG, "Swipe Down completed - Prev Reel");
                }
            }, null);
        }
    }

    // Set volume (0-100)
    public void setVolume(int volumePercent) {
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
