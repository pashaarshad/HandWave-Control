import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'test_screen.dart';
import 'splash_screen.dart';
import 'services/background_service.dart';
import 'services/gesture_controller.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HandLazyApp());
}

class HandLazyApp extends StatelessWidget {
  const HandLazyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'HandLazy - by Arshad Pasha',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: const Color(0xFF238636),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF238636),
          secondary: Color(0xFF1F6FEB),
        ),
      ),
      home: const SplashScreen(nextScreen: HomeScreen()),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _cameraGranted = false;
  bool _backgroundRunning = false;
  bool _accessibilityEnabled = false;
  bool _overlayGranted = false;
  final BackgroundGestureService _bgService = BackgroundGestureService();
  final GestureController _gestureController = GestureController();

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    await _checkPermissions();
    await _bgService.initialize();
    _backgroundRunning = await _bgService.checkRunning();
    _accessibilityEnabled = await _gestureController.isAccessibilityEnabled();
    _overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
    _listenToBackgroundService();
    _listenToOverlayData();
    if (mounted) setState(() {});
  }

  void _listenToBackgroundService() {
    FlutterBackgroundService().on('gesture').listen((event) {
      if (event == null) return;
      final type = event['type'] as String?;
      final message = event['message'] as String?;

      if (message != null) {
        _gestureController.showToast(message);
      }

      switch (type) {
        case 'NEXT_REEL':
          _gestureController.swipeUp();
          break;
        case 'PREV_REEL':
          _gestureController.swipeDown();
          break;
        case 'VOLUME':
          final volume = event['value'] as int? ?? 50;
          _gestureController.setVolume(volume);
          break;
      }
    });
  }

  void _listenToOverlayData() {
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data == null) return;

      switch (data) {
        case "START":
          _bgService.start();
          break;
        case "STOP":
          _bgService.stop();
          break;
        case "OPEN_APP":
          // App is already open, just bring to front
          break;
      }
    });
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.camera.status;
    setState(() => _cameraGranted = status.isGranted);
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    setState(() => _cameraGranted = status.isGranted);
    if (status.isGranted) {
      Get.snackbar(
        "✅ Success",
        "Camera permission granted!",
        backgroundColor: Colors.green.withAlpha(200),
      );
    }
  }

  Future<void> _toggleBackgroundService() async {
    if (!_cameraGranted) {
      Get.snackbar(
        "⚠️ Permission Required",
        "Please grant camera permission first",
        backgroundColor: Colors.orange.withAlpha(200),
      );
      return;
    }

    // Check accessibility service
    _accessibilityEnabled = await _gestureController.isAccessibilityEnabled();
    if (!_accessibilityEnabled) {
      Get.dialog(
        AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text("🔐 Enable Accessibility"),
          content: const Text(
            "To control other apps (Instagram, YouTube, etc.), you need to enable HandLazy in Accessibility Settings.\n\n"
            "1. Tap 'Open Settings'\n"
            "2. Find 'HandLazy Gesture Control'\n"
            "3. Enable the toggle\n"
            "4. Come back and try again",
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                _gestureController.openAccessibilitySettings();
              },
              child: const Text("Open Settings"),
            ),
          ],
        ),
      );
      return;
    }

    // Check for battery optimizations (Critical for background stability on POCO/Xiaomi)
    final ignoreBattery = await Permission.ignoreBatteryOptimizations.isGranted;
    if (!ignoreBattery) {
      Get.dialog(
        AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text("🔋 Battery Optimization"),
          content: const Text(
            "To keep HandLazy running in the background, please allow it to ignore battery optimizations.\n\n"
            "This prevents the system from killing the app while you're scrolling.",
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text("Skip (Not Recommended)"),
            ),
            ElevatedButton(
              onPressed: () async {
                Get.back();
                await Permission.ignoreBatteryOptimizations.request();
              },
              child: const Text("Allow"),
            ),
          ],
        ),
      );
      // We don't return here, we proceed after the dialog is shown/dismissed (user choice)
      // Ideally we would wait, but for UX flow we just prompt once.
    }

    // Check overlay permission
    _overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!_overlayGranted) {
      await FlutterOverlayWindow.requestPermission();
      _overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
      if (!_overlayGranted) {
        Get.snackbar(
          "⚠️ Overlay Permission",
          "Please allow overlay permission for floating indicator",
          backgroundColor: Colors.orange.withAlpha(200),
        );
      }
    }

    if (_backgroundRunning) {
      // Stop service and hide overlay
      await _bgService.stop();
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
      Get.snackbar(
        "🛑 Stopped",
        "Background gesture control stopped",
        backgroundColor: Colors.red.withAlpha(200),
      );
    } else {
      // Start service and show overlay
      await _bgService.start();
      if (_overlayGranted && !(await FlutterOverlayWindow.isActive())) {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: "HandLazy",
          overlayContent: "Gesture Control Active",
          flag: OverlayFlag.defaultFlag,
          visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.auto,
          height: 150,
          width: 180,
        );
      }
      Get.snackbar(
        "🚀 Activated!",
        "Gesture control running in background",
        backgroundColor: Colors.green.withAlpha(200),
      );
    }

    _backgroundRunning = await _bgService.checkRunning();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Settings Button Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => Get.to(() => const SettingsScreen()),
                    icon: const Icon(Icons.settings, color: Colors.white54),
                    tooltip: 'Settings',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Logo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pan_tool_alt,
                  size: 60,
                  color: Colors.deepPurpleAccent,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                "HandLazy",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                "Touchless Gesture Control",
                style: TextStyle(fontSize: 16, color: Colors.white54),
              ),
              const SizedBox(height: 4),
              Text(
                "by Arshad Pasha",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.deepPurple.shade200,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "v10.2",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.deepPurpleAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // How It Works Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          "How It Works",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildGestureRow(
                      Icons.pan_tool,
                      Colors.red,
                      "Open Hand",
                      "Go PREV",
                    ),
                    _buildGestureRow(
                      Icons.front_hand,
                      Colors.green,
                      "Closed/Single",
                      "Go NEXT",
                    ),
                    _buildGestureRow(
                      Icons.pinch,
                      Colors.blue,
                      "Pinch Gesture",
                      "Volume Control",
                    ),
                    _buildGestureRow(
                      Icons.circle,
                      Colors.yellow,
                      "Yellow Dot",
                      "Cursor Tracking",
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Permission Status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cameraGranted
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _cameraGranted ? Colors.green : Colors.orange,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _cameraGranted ? Icons.check_circle : Icons.warning,
                      color: _cameraGranted ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _cameraGranted
                            ? "Camera permission granted"
                            : "Camera permission required",
                        style: TextStyle(
                          color: _cameraGranted ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                    if (!_cameraGranted)
                      TextButton(
                        onPressed: _requestPermissions,
                        child: const Text("GRANT"),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Test Mode Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _cameraGranted
                      ? () => Get.to(() => const TestScreen())
                      : null,
                  icon: const Icon(Icons.science, color: Colors.white),
                  label: const Text(
                    "🧪 TEST MODE",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Activate Background Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _backgroundRunning
                        ? Colors.red
                        : const Color(0xFF1F6FEB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _cameraGranted ? _toggleBackgroundService : null,
                  icon: Icon(
                    _backgroundRunning
                        ? Icons.stop_circle
                        : Icons.play_circle_fill,
                    color: Colors.white,
                  ),
                  label: Text(
                    _backgroundRunning
                        ? "🛑 STOP BACKGROUND"
                        : "🚀 ACTIVATE BACKGROUND",
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGestureRow(
    IconData icon,
    Color color,
    String gesture,
    String action,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(gesture, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(
            "→ $action",
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
