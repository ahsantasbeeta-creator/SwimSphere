import 'package:flutter/material.dart';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'coachhome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CoachSignupScreen(),
    );
  }
}

class CoachSignupScreen extends StatefulWidget {
  const CoachSignupScreen({super.key});
  @override
  State<CoachSignupScreen> createState() => _CoachSignupScreenState();
}

class _CoachSignupScreenState extends State<CoachSignupScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  bool _isLoading = false;
  String _selectedQualification = 'Certified Coach';

  final List<String> _qualifications = [
    'Certified Coach',
    'Assistant Coach',
    'Head Coach',
    'Swimming Instructor',
    'Fitness Trainer'
  ];

  late AnimationController _waveController;
  late AnimationController _bubbleController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _bubbleController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _bubbleController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  String _generateMemberId() {
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String uniqueSuffix = timestamp.substring(timestamp.length - 6);
    return 'CO$uniqueSuffix';
  }

  bool _isValidName(String name) {
    return RegExp(r'^[a-zA-Z\s]+$').hasMatch(name);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-z0-9]+@gmail\.com$').hasMatch(email);
  }

  bool _isValidPassword(String password) {
    return RegExp(r'^\d{8}$').hasMatch(password);
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Future<void> _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      String memberId = _generateMemberId();
      String name = _nameCtrl.text.trim();
      String email = _emailCtrl.text.trim();
      String age = _ageCtrl.text.trim();
      String qualification = _selectedQualification;

      try {
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: _passCtrl.text.trim(),
        );

        final uid = userCredential.user!.uid;

        // Show dialog with Member ID and Continue button
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Signup Successful"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, color: Colors.green, size: 48),
                const SizedBox(height: 12),
                Text("Your Member ID:", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                Text(memberId, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomeScreen(
                          name: name,
                          email: email,
                          age: age,
                          qualification: qualification,
                          memberId: memberId,
                          status: 'Active',
                          profilePicUrl: '',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text("Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );

        // Firestore + Email in background
        FirebaseFirestore.instance.collection('coaches').doc(uid).set({
          'name': name,
          'email': email,
          'age': age,
          'qualification': qualification,
          'memberId': memberId,
          'status': 'Active',
          'role': 'Coach',
          'createdAt': FieldValue.serverTimestamp(),
        });

        FirebaseFunctions.instance.httpsCallable('sendCoachWelcomeEmail').call({
          'email': email,
          'name': name,
          'memberId': memberId,
        });

      } on FirebaseAuthException catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Signup failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFa3e0ff),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Coach Sign Up', style: TextStyle(color: Colors.blue)),
        leading: BackButton(color: Colors.blue),
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return CustomPaint(
                painter: WavePainter(animation: _waveController.value),
                size: Size.infinite,
              );
            },
          ),
          AnimatedBuilder(
            animation: _bubbleController,
            builder: (context, child) {
              return CustomPaint(
                painter: BubblePainter(animation: _bubbleController.value),
                size: Size.infinite,
              );
            },
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              margin: const EdgeInsets.only(bottom: 80),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: _inputDecoration('Full Name', Icons.person),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Enter name'
                          : !_isValidName(val)
                          ? 'Only letters allowed'
                          : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: _inputDecoration('Email (e.g. abc123@gmail.com)', Icons.email),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Enter email'
                          : !_isValidEmail(val)
                          ? 'Use lowercase letters/numbers + @gmail.com'
                          : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: _inputDecoration('Password (8 digits)', Icons.lock),
                      validator: (val) =>
                      _isValidPassword(val ?? '') ? null : 'Password must be 8 digits',
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: true,
                      decoration: _inputDecoration('Confirm Password', Icons.lock),
                      validator: (val) =>
                      val != _passCtrl.text ? 'Passwords do not match' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Age', Icons.cake),
                      validator: (val) => int.tryParse(val ?? '') != null ? null : 'Enter valid age',
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _selectedQualification,
                      decoration: InputDecoration(
                        labelText: 'Qualification',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _qualifications
                          .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedQualification = val!),
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Sign Up',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------- Custom Painters -------------------

class WavePainter extends CustomPainter {
  final double animation;
  WavePainter({required this.animation});
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final paint = Paint()..color = Colors.blue.withOpacity(0.3);
    double waveHeight = 20;
    double yOffset = size.height - 100;
    path.moveTo(0, yOffset);
    for (double x = 0; x < size.width; x++) {
      double y = waveHeight * sin((x / size.width * 2 * pi) + (animation * 2 * pi));
      path.lineTo(x, yOffset + y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BubblePainter extends CustomPainter {
  final double animation;
  BubblePainter({required this.animation});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.3);
    for (int i = 0; i < 7; i++) {
      double x = (i + 1) * size.width / 8;
      double y =
          size.height - (animation * size.height * (0.5 + i * 0.05)) % size.height;
      canvas.drawCircle(Offset(x, y), 6 + (i % 3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}




