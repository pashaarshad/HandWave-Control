import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gesture_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GestureController _gestureController = GestureController();

  // Settings state
  bool _autoStartOnBoot = false;
  bool _showFloatingIndicator = true;
  bool _enableSwipeUp = true;
  bool _enableOpenHand = true;
  bool _enablePinchVolume = true;
  double _gestureSensitivity = 0.5;
  bool _accessibilityEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoStartOnBoot = prefs.getBool('autoStartOnBoot') ?? false;
      _showFloatingIndicator = prefs.getBool('showFloatingIndicator') ?? true;
      _enableSwipeUp = prefs.getBool('enableSwipeUp') ?? true;
      _enableOpenHand = prefs.getBool('enableOpenHand') ?? true;
      _enablePinchVolume = prefs.getBool('enablePinchVolume') ?? true;
      _gestureSensitivity = prefs.getDouble('gestureSensitivity') ?? 0.5;
    });
    _accessibilityEnabled = await _gestureController.isAccessibilityEnabled();
    if (mounted) setState(() {});
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoStartOnBoot', _autoStartOnBoot);
    await prefs.setBool('showFloatingIndicator', _showFloatingIndicator);
    await prefs.setBool('enableSwipeUp', _enableSwipeUp);
    await prefs.setBool('enableOpenHand', _enableOpenHand);
    await prefs.setBool('enablePinchVolume', _enablePinchVolume);
    await prefs.setDouble('gestureSensitivity', _gestureSensitivity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('⚙️ Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Accessibility Status Card
          _buildStatusCard(),
          const SizedBox(height: 24),

          // Gesture Settings Section
          _buildSectionHeader('🎮 Gesture Controls'),
          _buildSwitchTile(
            'Swipe Up → Next Reel',
            'Move index finger up to scroll to next',
            _enableSwipeUp,
            (value) => setState(() {
              _enableSwipeUp = value;
              _saveSettings();
            }),
          ),
          _buildSwitchTile(
            'Open Hand → Previous Reel',
            'Fully open hand to go back',
            _enableOpenHand,
            (value) => setState(() {
              _enableOpenHand = value;
              _saveSettings();
            }),
          ),
          _buildSwitchTile(
            'Pinch → Volume Control',
            'Pinch to adjust volume (toggle direction)',
            _enablePinchVolume,
            (value) => setState(() {
              _enablePinchVolume = value;
              _saveSettings();
            }),
          ),

          const SizedBox(height: 24),

          // Sensitivity Slider
          _buildSectionHeader('🎚️ Sensitivity'),
          _buildSliderTile(),

          const SizedBox(height: 24),

          // App Behavior Section
          _buildSectionHeader('📱 App Behavior'),
          _buildSwitchTile(
            'Show Floating Indicator',
            'Display small icon when active',
            _showFloatingIndicator,
            (value) => setState(() {
              _showFloatingIndicator = value;
              _saveSettings();
            }),
          ),
          _buildSwitchTile(
            'Auto-Start on Boot',
            'Start gesture control when phone turns on',
            _autoStartOnBoot,
            (value) => setState(() {
              _autoStartOnBoot = value;
              _saveSettings();
            }),
          ),

          const SizedBox(height: 32),

          // About Section
          _buildSectionHeader('ℹ️ About'),
          _buildInfoTile('Version', '1.0.0'),
          _buildInfoTile('Developer', 'Arshad Pasha'),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _accessibilityEnabled
              ? [Colors.green.shade800, Colors.green.shade600]
              : [Colors.orange.shade800, Colors.orange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            _accessibilityEnabled ? Icons.check_circle : Icons.warning,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _accessibilityEnabled
                      ? 'Accessibility Enabled'
                      : 'Accessibility Required',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _accessibilityEnabled
                      ? 'HandLazy can control other apps'
                      : 'Enable to control Instagram, YouTube, etc.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!_accessibilityEnabled)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange.shade800,
              ),
              onPressed: () => _gestureController.openAccessibilitySettings(),
              child: const Text('Enable'),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.deepPurple,
      ),
    );
  }

  Widget _buildSliderTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gesture Sensitivity',
                style: TextStyle(color: Colors.white),
              ),
              Text(
                _gestureSensitivity < 0.33
                    ? 'Low'
                    : _gestureSensitivity < 0.66
                    ? 'Medium'
                    : 'High',
                style: TextStyle(
                  color: Colors.deepPurple.shade300,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: _gestureSensitivity,
            onChanged: (value) => setState(() => _gestureSensitivity = value),
            onChangeEnd: (value) => _saveSettings(),
            activeColor: Colors.deepPurple,
            inactiveColor: Colors.white24,
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Less Sensitive',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Text(
                'More Sensitive',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
