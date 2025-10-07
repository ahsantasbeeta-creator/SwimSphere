import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

// Comment this if firebase_options.dart does not exist yet
import 'firebase_options.dart';

void main(dynamic DefaultFirebaseOptions) async {
  WidgetsFlutterBinding.ensureInitialized();

  // If firebase_options.dart doesn't exist yet, comment the line below and initialize without options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  final List<String> _backgroundImages = [
    'assets/images/welcomepageimage.jpg',
    'assets/images/welcomepageimage1.jpg',
    'assets/images/welcomepageimage2.jpg',
  ];
  int _currentImageIndex = 0;
  late Timer _timer;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation1;
  late Animation<double> _fadeAnimation2;
  late Animation<Offset> _slideAnimation1;
  late Animation<Offset> _slideAnimation2;
  late Animation<double> _scaleAnimation1;
  late Animation<double> _scaleAnimation2;
  late Animation<double> _rotateAnimation1;
  late Animation<double> _rotateAnimation2;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    _fadeAnimation1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeInOut)),
    );

    _fadeAnimation2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeInOut)),
    );

    _slideAnimation1 = Tween<Offset>(begin: const Offset(-1.0, -0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );

    _slideAnimation2 = Tween<Offset>(begin: const Offset(1.0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeOutBack)),
    );

    _scaleAnimation1 = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );

    _scaleAnimation2 = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.elasticOut)),
    );

    _rotateAnimation1 = Tween<double>(begin: -0.05, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeInOut)),
    );

    _rotateAnimation2 = Tween<double>(begin: 0.05, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeInOut)),
    );

    _controller.forward();

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _backgroundImages.length;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(seconds: 1),
            child: SizedBox.expand(
              key: ValueKey<String>(_backgroundImages[_currentImageIndex]),
              child: FittedBox(
                fit: BoxFit.cover,
                child: Image.asset(_backgroundImages[_currentImageIndex], fit: BoxFit.cover),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.3),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset('assets/images/Applogo.png', height: 120, width: 120),
                ),
                const SizedBox(height: 40),
                RotationTransition(
                  turns: _rotateAnimation1,
                  child: ScaleTransition(
                    scale: _scaleAnimation1,
                    child: SlideTransition(
                      position: _slideAnimation1,
                      child: FadeTransition(
                        opacity: _fadeAnimation1,
                        child: _buildAnimatedText("Make ", "Waves", " & Break ", "Records"),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                RotationTransition(
                  turns: _rotateAnimation2,
                  child: ScaleTransition(
                    scale: _scaleAnimation2,
                    child: SlideTransition(
                      position: _slideAnimation2,
                      child: FadeTransition(
                        opacity: _fadeAnimation2,
                        child: _buildAnimatedText("Achieve Your ", "Goals", "", ""),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
                  child: Column(
                    children: [
                      _buildGradientButton('Sign Up', () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                      }),
                      const SizedBox(height: 20),
                      _buildGradientButton('Login', () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedText(String text1, String highlight1, String text2, String highlight2) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              _textSpan(text1, Colors.white),
              _textSpan(highlight1, Colors.lightBlueAccent),
              _textSpan(text2, Colors.white),
              _textSpan(highlight2, Colors.lightBlueAccent),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _textSpan(String text, Color color) {
    return TextSpan(
      text: text,
      style: GoogleFonts.poppins(fontSize: 35, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildGradientButton(String label, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF64B5F6), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }
}
