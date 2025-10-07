import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'swimmerhome_screen.dart';

class SwimmerSignupScreen extends StatefulWidget {
  const SwimmerSignupScreen({super.key});

  @override
  State<SwimmerSignupScreen> createState() => _SwimmerSignupScreenState();
}

class _SwimmerSignupScreenState extends State<SwimmerSignupScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();

  String _selectedLevel = 'Beginner';
  final List<String> _levels = ['Beginner', 'Intermediate', 'Advanced', 'Professional'];
  bool _isLoading = false;

  late AnimationController _waveController;
  late AnimationController _bubbleController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
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

  bool _isValidName(String name) {
    return RegExp(r"^[A-Za-z ]+$").hasMatch(name);
  }

  bool _isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9]+@gmail\.com$").hasMatch(email);
  }

  bool _isValidPassword(String password) {
    return RegExp(r"^\d{8}$").hasMatch(password);
  }

  String _generateMemberId() {
    final random = Random();
    final int randomNumber = random.nextInt(900000) + 100000;
    return 'SW$randomNumber';
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

      try {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );

        final String memberId = _generateMemberId();

        await _firestore.collection('swimmers').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'age': _ageCtrl.text.trim(),
          'skillLevel': _selectedLevel,
          'memberId': memberId,
          'status': 'Active',
          'role': 'swimmer',
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Initialize attendance collection for this swimmer
        await _firestore.collection('attendance').doc(userCredential.user!.uid).set({
          'swimmerId': userCredential.user!.uid,
          'swimmerName': _nameCtrl.text.trim(),
          'memberId': memberId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        /// ✅ Email Notification Placeholder (Needs Firebase Functions or Backend SMTP)
        print("📧 Email to ${_emailCtrl.text.trim()} with Member ID: $memberId");

        if (mounted) {
          setState(() => _isLoading = false);
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Signup Successful'),
              content: Text('Your Member ID: $memberId'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SwimmerHomeScreen(
                          name: _nameCtrl.text,
                          email: _emailCtrl.text,
                          age: _ageCtrl.text,
                          skillLevel: _selectedLevel,
                          memberId: memberId,
                          status: 'Active',
                          profilePicUrl: ' ',
                        ),
                      ),
                    );
                  },
                  child: const Text('Continue'),
                ),
              ],
            ),
          );
        }
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
        title: const Text('Swimmer Sign Up', style: TextStyle(color: Colors.blue)),
        leading: const BackButton(color: Colors.blue),
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, _) => CustomPaint(painter: WavePainter(animation: _waveController.value)),
          ),
          AnimatedBuilder(
            animation: _bubbleController,
            builder: (context, _) => CustomPaint(painter: BubblePainter(animation: _bubbleController.value)),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              margin: const EdgeInsets.only(bottom: 80),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.93),
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
                          ? 'Only alphabets allowed'
                          : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: _inputDecoration('Email (e.g. name123@gmail.com)', Icons.email),
                      validator: (val) => _isValidEmail(val!.trim()) ? null : 'Enter valid email: name123@gmail.com',
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: _inputDecoration('Password (8 digits)', Icons.lock),
                      validator: (val) => _isValidPassword(val!) ? null : 'Must be exactly 8 digits',
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: true,
                      decoration: _inputDecoration('Confirm Password', Icons.lock),
                      validator: (val) => val == _passCtrl.text ? null : 'Passwords do not match',
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Age', Icons.cake),
                      validator: (val) => int.tryParse(val!) != null ? null : 'Enter valid age',
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _selectedLevel,
                      decoration: InputDecoration(
                        labelText: 'Skill Level',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _levels.map((level) => DropdownMenuItem(value: level, child: Text(level))).toList(),
                      onChanged: (val) => setState(() => _selectedLevel = val!),
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Sign Up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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


// -------------------- Custom Painters --------------------

class WavePainter extends CustomPainter {
  final double animation;
  WavePainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blue.withOpacity(0.3);
    final path = Path();
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
    const bubbleCount = 8;

    for (int i = 0; i < bubbleCount; i++) {
      double x = (i + 1) * size.width / (bubbleCount + 1);
      double y = size.height - (animation * size.height * (0.4 + i * 0.04)) % size.height;
      canvas.drawCircle(Offset(x, y), 5 + (i % 3).toDouble(), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}



