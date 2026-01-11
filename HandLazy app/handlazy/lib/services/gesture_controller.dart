import 'package:flutter/services.dart';

/// Callback type for accessibility status changes
typedef AccessibilityStatusCallback = void Function(bool enabled);

class GestureController {
  static const MethodChannel _channel = MethodChannel('com.handlazy/gestures');
  static final GestureController _instance = GestureController._internal();

  factory GestureController() => _instance;

  AccessibilityStatusCallback? _onAccessibilityStatusChanged;
  bool _initialized = false;

  GestureController._internal();

  /// Initialize the controller and set up method call handler
  void initialize({AccessibilityStatusCallback? onAccessibilityStatusChanged}) {
    if (_initialized) return;
    _initialized = true;
    _onAccessibilityStatusChanged = onAccessibilityStatusChanged;

    // Listen for calls FROM native (e.g., onResume accessibility check)
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'accessibilityStatusChanged') {
        final enabled = call.arguments as bool? ?? false;
        _onAccessibilityStatusChanged?.call(enabled);
      }
      return null;
    });
  }

  /// Check if accessibility service is enabled
  Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _channel.invokeMethod('isAccessibilityEnabled');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Open accessibility settings for user to enable service
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      // Ignore errors
    }
  }

  /// Perform swipe up gesture (Next Reel)
  Future<bool> swipeUp() async {
    try {
      await _channel.invokeMethod('swipeUp');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Perform swipe down gesture (Previous Reel)
  Future<bool> swipeDown() async {
    try {
      await _channel.invokeMethod('swipeDown');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Set system volume (0-100)
  Future<bool> setVolume(int volume) async {
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Show toast message (useful for background feedback)
  Future<void> showToast(String message) async {
    try {
      await _channel.invokeMethod('showToast', {'message': message});
    } catch (e) {
      // Ignore
    }
  }

  /// Update cursor position (x, y are 0.0 to 1.0)
  Future<void> updateCursor(double x, double y) async {
    try {
      // Optimistic fire-and-forget to avoid awaiting platform channel overhead for every frame
      _channel.invokeMethod('updateCursor', {'x': x, 'y': y});
    } catch (e) {
      // Ignore
    }
  }

  /// Show the cursor
  Future<void> showCursor() async {
    try {
      await _channel.invokeMethod('showCursor');
    } catch (e) {
      // Ignore
    }
  }

  /// Hide the cursor
  Future<void> hideCursor() async {
    try {
      await _channel.invokeMethod('hideCursor');
    } catch (e) {
      // Ignore
    }
  }
}
