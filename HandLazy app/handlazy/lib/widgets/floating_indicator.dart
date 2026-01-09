import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Interactive floating overlay widget with ON/OFF controls
class FloatingIndicator extends StatefulWidget {
  const FloatingIndicator({super.key});

  @override
  State<FloatingIndicator> createState() => _FloatingIndicatorState();
}

class _FloatingIndicatorState extends State<FloatingIndicator> {
  bool _expanded = false;
  bool _isActive = true;
  String _lastGesture = "Ready";

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          setState(() => _expanded = !_expanded);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _expanded ? 180 : 65,
          height: _expanded ? 150 : 65,
          decoration: BoxDecoration(
            // GREEN for active, RED for stopped
            gradient: LinearGradient(
              colors: _isActive
                  ? [Colors.green.shade700, Colors.green.shade500]
                  : [Colors.red.shade700, Colors.red.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(_expanded ? 16 : 32),
            border: Border.all(
              color: _isActive ? Colors.greenAccent : Colors.redAccent,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: _isActive
                    ? Colors.green.withAlpha(180)
                    : Colors.red.withAlpha(180),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: _expanded ? _buildExpandedView() : _buildCollapsedView(),
        ),
      ),
    );
  }

  Widget _buildCollapsedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pan_tool_alt, color: Colors.white, size: 28),
          const SizedBox(height: 2),
          Text(
            _isActive ? "ON" : "OFF",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedView() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.pan_tool_alt, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    "HandLazy",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _expanded = false),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Status with big indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isActive ? Colors.greenAccent : Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isActive ? Colors.green : Colors.red,
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isActive ? "ACTIVE" : "STOPPED",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Control Buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isActive = !_isActive);
                    FlutterOverlayWindow.shareData(
                      _isActive ? "START" : "STOP",
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isActive
                          ? Colors.red.shade600
                          : Colors.green.shade600,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isActive
                            ? Colors.redAccent
                            : Colors.greenAccent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _isActive ? "⏹ STOP" : "▶ START",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  FlutterOverlayWindow.shareData("OPEN_APP");
                  FlutterOverlayWindow.closeOverlay();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white38, width: 1),
                  ),
                  child: const Icon(
                    Icons.open_in_new,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
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
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: FloatingIndicator()),
      ),
    ),
  );
}
