import 'package:flutter/services.dart';

class GestureController {
  static const MethodChannel _channel = MethodChannel('com.handlazy/gestures');
  static final GestureController _instance = GestureController._internal();

  factory GestureController() => _instance;
  GestureController._internal();

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
}
