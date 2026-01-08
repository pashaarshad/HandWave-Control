import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:get/get.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  CameraController? _controller;
  HandLandmarkerPlugin? _handLandmarker;
  bool _isDetecting = false;
  bool _isProcessing = false;
  String _debugStatus = "Initializing...";

  // Gesture State
  String _gestureMode = "No Hand";
  Color _modeColor = Colors.grey;
  String _lastAction = "";
  int _volume = 0;

  // Yellow cursor position
  double _cursorX = 0.5;
  double _cursorY = 0.5;
  bool _showCursor = false;

  // Landmarks for skeleton
  List<Offset>? _landmarks;

  // Swipe detection
  double? _prevIndexY;
  double _lastActionTime = 0;

  // Volume toggle logic
  bool _volumeIncreasing = true; // true = increase, false = decrease
  bool _wasPinching = false; // was pinching in previous frame
  double _lastVolumeChange = 0; // debounce volume changes

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initSystem();
  }

  Future<void> _initSystem() async {
    setState(() => _debugStatus = "Loading ML Model...");

    try {
      _handLandmarker = await HandLandmarkerPlugin.create(numHands: 1);
      setState(() => _debugStatus = "Model Loaded. Init Camera...");
    } catch (e) {
      setState(() => _debugStatus = "ML Error: $e");
      return;
    }

    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _controller!.initialize();

      setState(() => _debugStatus = "Ready! Tap START");
    } catch (e) {
      setState(() => _debugStatus = "Camera Error: $e");
    }
  }

  void _toggleDetection() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _isDetecting = !_isDetecting;
      if (_isDetecting) {
        _controller!.startImageStream(_processFrame);
        _debugStatus = "Detecting...";
      } else {
        _controller!.stopImageStream();
        _gestureMode = "Paused";
        _modeColor = Colors.grey;
        _showCursor = false;
        _landmarks = null;
        _debugStatus = "Paused";
      }
    });
  }

  void _processFrame(CameraImage image) async {
    if (!_isDetecting || _handLandmarker == null || _isProcessing) return;
    _isProcessing = true;

    try {
      final result = _handLandmarker!.detect(image, 0);

      if (result.isNotEmpty) {
        final hand = result.first;
        final landmarks = hand.landmarks;

        _landmarks = landmarks.map((lm) => Offset(1.0 - lm.x, lm.y)).toList();

        final indexTip = landmarks[8];
        _cursorX = 1.0 - indexTip.x;
        _cursorY = indexTip.y;
        _showCursor = true;

        _detectGesture(landmarks);
        _detectSwipe(indexTip.y);
      } else {
        _gestureMode = "No Hand 👋";
        _modeColor = Colors.grey;
        _showCursor = false;
        _landmarks = null;
      }

      if (mounted) setState(() {});
    } catch (e) {
      // Ignore frame errors
    }

    _isProcessing = false;
  }

  void _detectGesture(List<dynamic> landmarks) {
    final thumbTip = landmarks[4];
    final indexTip = landmarks[8];
    final pinkyTip = landmarks[20];
    final wrist = landmarks[0];

    double thumbToIndex = _dist(thumbTip, indexTip);
    double indexToWrist = _dist(indexTip, wrist);
    double pinkyToWrist = _dist(pinkyTip, wrist);

    bool isPinching = thumbToIndex < 0.08;
    bool isOpen = indexToWrist > 0.20 && pinkyToWrist > 0.15;

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;

    if (isPinching) {
      _gestureMode = "✊ PINCH";
      _modeColor = Colors.green;

      // When pinch starts (transition from not pinching to pinching)
      if (!_wasPinching) {
        // Toggle direction on new pinch session
        _volumeIncreasing = !_volumeIncreasing;
        // If starting fresh at 0, always increase first
        if (_volume == 0) _volumeIncreasing = true;
        // If at 100, always decrease
        if (_volume == 100) _volumeIncreasing = false;
      }

      // Gradual volume change while pinching (every 200ms)
      if (now - _lastVolumeChange > 0.2) {
        if (_volumeIncreasing && _volume < 100) {
          _volume += 10;
          if (_volume > 100) _volume = 100;
        } else if (!_volumeIncreasing && _volume > 0) {
          _volume -= 10;
          if (_volume < 0) _volume = 0;
        }
        _lastVolumeChange = now;
      }
    } else if (isOpen) {
      _gestureMode = "🖐️ OPEN";
      _modeColor = Colors.red;

      // Trigger Previous Reel on open hand (with cooldown)
      if (now - _lastActionTime > 0.8) {
        _lastAction = "⬇️ PREV REEL";
        _lastActionTime = now;
      }
    } else {
      _gestureMode = "☝️ POINTING";
      _modeColor = Colors.orange;
    }

    _wasPinching = isPinching;
  }

  void _detectSwipe(double currentY) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;

    if (_prevIndexY != null && (now - _lastActionTime) > 0.6) {
      double dy = currentY - _prevIndexY!;

      // Swipe UP = Next Reel (index finger moves upward)
      if (dy < -0.06) {
        _lastAction = "⬆️ NEXT REEL";
        _lastActionTime = now;
      }
    }
    _prevIndexY = currentY;
  }

  double _dist(dynamic a, dynamic b) {
    return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller?.dispose();
    _handLandmarker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller == null || !_controller!.value.isInitialized
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.deepPurple),
                  const SizedBox(height: 20),
                  Text(
                    _debugStatus,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // Camera Preview
                Positioned.fill(
                  child: Transform.scale(
                    scaleX: -1,
                    child: CameraPreview(_controller!),
                  ),
                ),

                // Hand Skeleton
                if (_landmarks != null)
                  CustomPaint(
                    size: size,
                    painter: HandSkeletonPainter(_landmarks!, _modeColor),
                  ),

                // Yellow Cursor
                if (_showCursor)
                  Positioned(
                    left: _cursorX * size.width - 20,
                    top: _cursorY * size.height - 20,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.yellow,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.orange, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.yellow.withAlpha(150),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Top Bar
                SafeArea(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Get.back(),
                        ),
                        Expanded(
                          child: Text(
                            _debugStatus,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDetecting
                                ? Colors.red
                                : Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          onPressed: _toggleDetection,
                          icon: Icon(
                            _isDetecting ? Icons.stop : Icons.play_arrow,
                            size: 20,
                          ),
                          label: Text(_isDetecting ? "STOP" : "START"),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Panel
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha(230),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mode Indicator
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _modeColor.withAlpha(60),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _modeColor, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              _gestureMode,
                              style: TextStyle(
                                color: _modeColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Volume Bar
                        Row(
                          children: [
                            const Icon(
                              Icons.volume_down,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: _volume / 100,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation(
                                    Colors.blueAccent,
                                  ),
                                  minHeight: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "$_volume%",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Last Action
                        if (_lastAction.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _lastAction,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class HandSkeletonPainter extends CustomPainter {
  final List<Offset> landmarks;
  final Color color;

  HandSkeletonPainter(this.landmarks, this.color);

  static const connections = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [0, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [0, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [0, 17],
    [17, 18],
    [18, 19],
    [19, 20],
    [5, 9],
    [9, 13],
    [13, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color.withAlpha(200)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (var conn in connections) {
      if (conn[0] < landmarks.length && conn[1] < landmarks.length) {
        final p1 = Offset(
          landmarks[conn[0]].dx * size.width,
          landmarks[conn[0]].dy * size.height,
        );
        final p2 = Offset(
          landmarks[conn[1]].dx * size.width,
          landmarks[conn[1]].dy * size.height,
        );
        canvas.drawLine(p1, p2, linePaint);
      }
    }

    for (int i = 0; i < landmarks.length; i++) {
      final p = Offset(
        landmarks[i].dx * size.width,
        landmarks[i].dy * size.height,
      );
      double r = [4, 8, 12, 16, 20].contains(i) ? 8 : 5;
      canvas.drawCircle(p, r, dotPaint);
      canvas.drawCircle(p, r, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
