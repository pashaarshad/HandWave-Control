import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'test_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HandLazyApp());
}

class HandLazyApp extends StatelessWidget {
  const HandLazyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'HandLazy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: const Color(0xFF238636),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF238636),
          secondary: Color(0xFF1F6FEB),
        ),
      ),
      home: const HomeScreen(),
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

  @override
  void initState() {
    super.initState();
    _checkPermissions();
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
        backgroundColor: Colors.green.withOpacity(0.8),
      );
    }
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
              const SizedBox(height: 40),

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
                    backgroundColor: const Color(0xFF1F6FEB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Get.snackbar(
                      "🚀 Coming Soon",
                      "Background mode will be enabled after testing!",
                      backgroundColor: Colors.blue.withOpacity(0.8),
                    );
                  },
                  icon: const Icon(Icons.play_circle_fill, color: Colors.white),
                  label: const Text(
                    "🚀 ACTIVATE BACKGROUND",
                    style: TextStyle(fontSize: 16, color: Colors.white),
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
