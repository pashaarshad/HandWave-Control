import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Hide system UI for splash
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();

    // Navigate after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                widget.nextScreen,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF1a1a2e), Color(0xFF0D1117)],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo with animation
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withAlpha(50),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withAlpha(100),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.pan_tool_alt,
                          size: 80,
                          color: Colors.deepPurpleAccent,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // App Name
                  Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Text(
                      "HandLazy",
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Tagline
                  Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Text(
                      "Touchless Gesture Control",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white54,
                        letterSpacing: 1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Creator credit
                  Opacity(
                    opacity: _fadeAnimation.value,
                    child: Column(
                      children: [
                        const Text(
                          "Created by",
                          style: TextStyle(fontSize: 14, color: Colors.white38),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Arshad Pasha",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple.shade200,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
