import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For MethodChannel
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

// Native Bridge for Gestures (Duplicate of GestureController to function in Overlay Isolate)
class OverlayGestureController {
  static const MethodChannel _channel = MethodChannel('com.handlazy/gestures');

  Future<void> swipeUp() async {
    try {
      await _channel.invokeMethod('swipeUp');
    } catch (_) {}
  }

  Future<void> swipeDown() async {
    try {
      await _channel.invokeMethod('swipeDown');
    } catch (_) {}
  }

  Future<void> setVolume(int volume) async {
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } catch (_) {}
  }
}

class FloatingIndicator extends StatefulWidget {
  const FloatingIndicator({super.key});

  @override
  State<FloatingIndicator> createState() => _FloatingIndicatorState();
}

class _FloatingIndicatorState extends State<FloatingIndicator> {
  // UI State
  // bool _isExpanded = true; // Default to expanded to show camera
  String _statusMessage = "Initializing...";
  Color _statusColor = Colors.orange;

  // Camera & ML State
  CameraController? _cameraController;
  HandLandmarkerPlugin? _handLandmarker;
  bool _isProcessing = false;
  bool _isCameraReady = false;

  // Gesture Logic State
  final OverlayGestureController _gestureController =
      OverlayGestureController();
  double? _prevIndexY;
  double _lastActionTime = 0;
  int _volume = 50;
  bool _volumeIncreasing = true;
  bool _wasPinching = false;
  double _lastVolumeChange = 0;

  @override
  void initState() {
    super.initState();
    _initializeCameraAndML();

    // Resize overlay to fit camera preview initially
    // FlutterOverlayWindow.resizeOverlay(200, 260, true);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _handLandmarker?.dispose();
    super.dispose();
  }

  Future<void> _initializeCameraAndML() async {
    try {
      // 1. Initialize ML
      _handLandmarker = await HandLandmarkerPlugin.create(numHands: 1);

      // 2. Initialize Camera
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        front,
        ResolutionPreset.low, // 240p is enough for gestures and saves battery
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _statusMessage = "Ready";
          _statusColor = Colors.green;
        });
        _startProcessing();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Error: $e";
          _statusColor = Colors.red;
        });
      }
    }
  }

  void _startProcessing() {
    if (_cameraController == null) return;

    _cameraController!.startImageStream((image) async {
      if (_isProcessing || _handLandmarker == null) return;
      _isProcessing = true;

      try {
        final result = _handLandmarker!.detect(image, 0);

        if (result.isNotEmpty) {
          final landmarks = result.first.landmarks;
          _processLandmarks(landmarks);

          if (mounted) {
            setState(() {
              _statusColor = Colors.greenAccent;
            });
          }
        } else {
          if (mounted && _statusColor == Colors.greenAccent) {
            setState(() {
              _statusColor = Colors.green;
            });
          }
        }
      } catch (e) {
        // Ignore frame errors
      } finally {
        _isProcessing = false;
      }
    });
  }

  void _processLandmarks(List<dynamic> landmarks) {
    if (landmarks.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;

    // Key Points
    final thumbTip = landmarks[4];
    final indexTip = landmarks[8];
    final pinkyTip = landmarks[20];
    final wrist = landmarks[0];

    // Calculations
    double thumbToIndex = _dist(thumbTip, indexTip);
    double indexToWrist = _dist(indexTip, wrist);
    double pinkyToWrist = _dist(pinkyTip, wrist);

    // Logic
    bool isPinching = thumbToIndex < 0.08;
    bool isOpen = indexToWrist > 0.20 && pinkyToWrist > 0.15;

    // Detect Gestures
    if (isPinching) {
      _handlePinch(now);
    } else if (isOpen) {
      _handleOpenHand(now);
    } else {
      _handlePointing(now, indexTip);
    }

    _wasPinching = isPinching;
    _prevIndexY = indexTip.y;
  }

  void _handlePinch(double now) {
    if (!_wasPinching) {
      _volumeIncreasing = !_volumeIncreasing; // Toggle direction
    }

    if (now - _lastVolumeChange > 0.2) {
      if (_volumeIncreasing && _volume < 100) _volume += 10;
      if (!_volumeIncreasing && _volume > 0) _volume -= 10;

      _gestureController.setVolume(_volume);
      _lastVolumeChange = now;

      setState(() {
        _statusMessage = "Vol: $_volume%";
        _statusColor = Colors.cyan;
      });
    }
  }

  void _handleOpenHand(double now) {
    if (now - _lastActionTime > 0.8) {
      _gestureController.swipeDown(); // Prev Reel
      _lastActionTime = now;
      setState(() {
        _statusMessage = "Prev Reel";
        _statusColor = Colors.pinkAccent;
      });
    }
  }

  void _handlePointing(double now, dynamic indexTip) {
    if (_prevIndexY != null && (now - _lastActionTime) > 0.6) {
      double dy = indexTip.y - _prevIndexY!;
      if (dy < -0.06) {
        _gestureController.swipeUp(); // Next Reel
        _lastActionTime = now;
        setState(() {
          _statusMessage = "Next Reel";
          _statusColor = Colors.lightGreenAccent;
        });
      }
    }
  }

  double _dist(dynamic a, dynamic b) {
    return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(200),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _statusColor, width: 3),
          boxShadow: [
            BoxShadow(
              color: _statusColor.withAlpha(100),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              // 1. Camera Preview Layer
              if (_isCameraReady && _cameraController != null)
                Positioned.fill(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(pi), // Mirror effect
                    child: CameraPreview(_cameraController!),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              // 2. Overlay Info Layer
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  color: Colors.black54,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildDot(_statusColor == Colors.greenAccent),
                          const SizedBox(width: 4),
                          Text(
                            "HandLazy",
                            style: TextStyle(
                              color: Colors.white.withAlpha(150),
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Close/Minimize Button
              Positioned(
                top: 5,
                right: 5,
                child: GestureDetector(
                  onTap: () {
                    // Close Overlay and Open App
                    FlutterOverlayWindow.shareData("OPEN_APP");
                    FlutterOverlayWindow.closeOverlay();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(bool active) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Entry point for the overlay window
@pragma("vm:entry-point")
void overlayMain() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FloatingIndicator(), // Removed Scaffold for transparent background
    ),
  );
}
