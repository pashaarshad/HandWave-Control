import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'dart:math';

class BackgroundGestureService {
  static final BackgroundGestureService _instance =
      BackgroundGestureService._internal();
  factory BackgroundGestureService() => _instance;
  BackgroundGestureService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Initialize the background service
  Future<void> initialize() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'handlazy_channel',
        initialNotificationTitle: 'HandLazy Active',
        initialNotificationContent: 'Gesture control is running',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.camera],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Start the background service
  Future<void> start() async {
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
      _isRunning = true;
    }
  }

  /// Stop the background service
  Future<void> stop() async {
    _service.invoke('stopService');
    _isRunning = false;
  }

  /// Check if running
  Future<bool> checkRunning() async {
    _isRunning = await _service.isRunning();
    return _isRunning;
  }
}

// iOS background handler
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

// Main background entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  CameraController? controller;
  HandLandmarkerPlugin? handLandmarker;
  bool isProcessing = false;

  // Gesture state
  String lastGesture = "None";
  double? prevIndexY;
  double lastActionTime = 0;
  int volume = 50;
  bool volumeIncreasing = true;
  bool wasPinching = false;
  double lastVolumeChange = 0;

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    service.on('stopService').listen((event) async {
      controller?.dispose();
      handLandmarker?.dispose();
      await service.stopSelf();
    });
  }

  // Initialize ML model
  try {
    handLandmarker = await HandLandmarkerPlugin.create(numHands: 1);
  } catch (e) {
    service.invoke('update', {'status': 'ML Error: $e'});
    return;
  }

  // Initialize camera
  try {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    controller = CameraController(
      front,
      ResolutionPreset.low, // Lower res for background to save battery
      enableAudio: false,
    );
    await controller.initialize();
  } catch (e) {
    service.invoke('update', {'status': 'Camera Error: $e'});
    return;
  }

  // Process frames
  controller.startImageStream((image) async {
    if (isProcessing || handLandmarker == null) return;
    isProcessing = true;

    try {
      final result = handLandmarker.detect(image, 0);

      if (result.isNotEmpty) {
        final landmarks = result.first.landmarks;
        final now = DateTime.now().millisecondsSinceEpoch / 1000.0;

        // Get key points
        final thumbTip = landmarks[4];
        final indexTip = landmarks[8];
        final pinkyTip = landmarks[20];
        final wrist = landmarks[0];

        // Calculate distances
        double thumbToIndex = _dist(thumbTip, indexTip);
        double indexToWrist = _dist(indexTip, wrist);
        double pinkyToWrist = _dist(pinkyTip, wrist);

        bool isPinching = thumbToIndex < 0.08;
        bool isOpen = indexToWrist > 0.20 && pinkyToWrist > 0.15;

        // Gesture detection
        if (isPinching) {
          lastGesture = "PINCH";

          if (!wasPinching) {
            volumeIncreasing = !volumeIncreasing;
            if (volume == 0) volumeIncreasing = true;
            if (volume == 100) volumeIncreasing = false;
          }

          if (now - lastVolumeChange > 0.2) {
            if (volumeIncreasing && volume < 100) {
              volume += 10;
              if (volume > 100) volume = 100;
            } else if (!volumeIncreasing && volume > 0) {
              volume -= 10;
              if (volume < 0) volume = 0;
            }
            lastVolumeChange = now;

            // Send volume update
            service.invoke('gesture', {'type': 'VOLUME', 'value': volume});
          }
        } else if (isOpen) {
          lastGesture = "OPEN";
          if (now - lastActionTime > 0.8) {
            lastActionTime = now;
            service.invoke('gesture', {'type': 'PREV_REEL'});
          }
        } else {
          lastGesture = "POINTING";

          // Swipe detection
          if (prevIndexY != null && (now - lastActionTime) > 0.6) {
            double dy = indexTip.y - prevIndexY!;
            if (dy < -0.06) {
              lastActionTime = now;
              service.invoke('gesture', {'type': 'NEXT_REEL'});
            }
          }
        }

        wasPinching = isPinching;
        prevIndexY = indexTip.y;

        // Update notification
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'HandLazy - $lastGesture',
            content: 'Volume: $volume%',
          );
        }
      }
    } catch (e) {
      // Ignore frame errors
    }

    isProcessing = false;
  });

  // Keep service alive
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.invoke('update', {
          'current_gesture': lastGesture,
          'volume': volume,
        });
      }
    }
  });
}

double _dist(dynamic a, dynamic b) {
  return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
}
