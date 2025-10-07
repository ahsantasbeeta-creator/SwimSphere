import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'dart:async';
import 'welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // ✅ Firebase Initialization
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Bubble> bubbles = List.generate(20, (index) => Bubble());

  @override
  void initState() {
    super.initState();
    _testFirebaseWrite();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    Future.delayed(const Duration(seconds: 6), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    });
  }

  // ✅ Write data to Firebase Firestore
  Future<void> _testFirebaseWrite() async {
    try {
      await FirebaseFirestore.instance.collection('test_connection').add({
        'status': 'connected',
        'timestamp': Timestamp.now(),
        'message': 'SwimSphere app successfully connected!',
      });
      debugPrint("✅ Firebase write successful!");
    } catch (e) {
      debugPrint("❌ Firebase write failed: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF64B5F6),
                  Color(0xFF2196F3),
                  Color(0xFF1976D2),
                ],
              ),
            ),
          ),

          // Animated Waves
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: WavePainter(animation: _controller),
                size: Size.infinite,
              );
            },
          ),

          // Animated Bubbles
          ...bubbles.map((bubble) => AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              bubble.update();
              return Positioned(
                left: bubble.x,
                bottom: bubble.y,
                child: Container(
                  width: bubble.size,
                  height: bubble.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              );
            },
          )),

          // Logo Animation
          Center(
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 2),
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: 0.8 + (value * 0.2),
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: AssetImage('assets/images/Applogo.png'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Animated Wave Painter
class WavePainter extends CustomPainter {
  final Animation<double> animation;

  WavePainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path();
    final path2 = Path();
    final path3 = Path();

    path.moveTo(0, size.height * 0.5);
    path2.moveTo(0, size.height * 0.6);
    path3.moveTo(0, size.height * 0.7);

    for (double x = 0; x < size.width; x++) {
      path.lineTo(
        x,
        size.height * 0.5 +
            math.sin((x / size.width * 2 * math.pi) + (animation.value * 2 * math.pi)) * 20,
      );
      path2.lineTo(
        x,
        size.height * 0.6 +
            math.sin((x / size.width * 2 * math.pi) + (animation.value * 2 * math.pi) + 1) * 15,
      );
      path3.lineTo(
        x,
        size.height * 0.7 +
            math.sin((x / size.width * 2 * math.pi) + (animation.value * 2 * math.pi) + 2) * 10,
      );
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    path3.lineTo(size.width, size.height);
    path3.lineTo(0, size.height);
    path3.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path2, paint);
    canvas.drawPath(path3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Bubble Class for Animation
class Bubble {
  double x = math.Random().nextDouble() * 400;
  double y = math.Random().nextDouble() * 800;
  double size = math.Random().nextDouble() * 20 + 5;
  double speed = math.Random().nextDouble() * 2 + 1;

  void update() {
    y -= speed;
    if (y < -size) {
      y = 800;
      x = math.Random().nextDouble() * 400;
    }
  }
}
