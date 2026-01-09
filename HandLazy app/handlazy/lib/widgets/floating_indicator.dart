import 'package:flutter/material.dart';

/// Floating overlay widget that shows when background mode is active
class FloatingIndicator extends StatelessWidget {
  const FloatingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade700, Colors.purple.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withAlpha(150),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.pan_tool_alt, color: Colors.white, size: 28),
        ),
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
      home: FloatingIndicator(),
    ),
  );
}
