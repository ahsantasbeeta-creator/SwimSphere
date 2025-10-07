import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'guardianhome_screen.dart';

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
      home: GuardianSignupScreen(),
    );
  }
}

class GuardianSignupScreen extends StatefulWidget {
  const GuardianSignupScreen({super.key});

  @override
  State<GuardianSignupScreen> createState() => _GuardianSignupScreenState();
}

class _GuardianSignupScreenState extends State<GuardianSignupScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _childIdCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  late AnimationController _waveController;
  late AnimationController _bubbleController;
  bool _isLoading = false;

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
    _childIdCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  String _generateGuardianId() {
    final random = Random();
    return 'GU${100 + random.nextInt(900)}';
  }

  bool _isAlphabetOnly(String text) => RegExp(r'^[a-zA-Z\s]+$').hasMatch(text);
  bool _isValidGmail(String email) => RegExp(r'^[a-zA-Z0-9]+@gmail\.com$').hasMatch(email);
  bool _isValidPassword(String pass) => RegExp(r'^\d{8}$').hasMatch(pass);

  Future<void> _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // First, find the swimmer by member ID
        final swimmerQuery = await FirebaseFirestore.instance
            .collection('swimmers')
            .where('memberId', isEqualTo: _childIdCtrl.text.trim())
            .get();

        if (swimmerQuery.docs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Swimmer not found. Please check the Member ID.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        final swimmerDoc = swimmerQuery.docs.first;
        final swimmerData = swimmerDoc.data();
        final swimmerUid = swimmerDoc.id; // This is the Firebase UID of the swimmer

        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );

        final guardianId = _generateGuardianId();

        await FirebaseFirestore.instance.collection('guardians').doc(credential.user!.uid).set({
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'childAge': _ageCtrl.text.trim(),
          'childId': swimmerUid, // Store the swimmer's Firebase UID
          'childMemberId': _childIdCtrl.text.trim(), // Store the member ID for reference
          'childName': swimmerData['name'] ?? 'Unknown', // Store the swimmer's name
          'memberId': guardianId,
          'status': 'Active',
          'role': 'guardian',
          'linkedSwimmerUid': swimmerUid, // Additional field for clarity
        });

        if (!mounted) return;

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Registration Successful'),
            content: Text('Your Guardian Member ID is: $guardianId\nLinked to swimmer: ${swimmerData['name']}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continue'),
              ),
            ],
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GuardianHomeScreen(
              name: _nameCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              childage: _ageCtrl.text.trim(),
              childId: swimmerUid, // Pass the swimmer's Firebase UID
              memberId: guardianId,
              status: 'Active',
              profilePicUrl: '',
              age: '',
            ),
          ),
        );
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Signup failed')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFa3e0ff),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Guardian Sign Up', style: TextStyle(color: Colors.blue)),
        leading: const BackButton(color: Colors.blue),
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _waveController,
            builder: (_, __) => CustomPaint(
              painter: WavePainter(animation: _waveController.value),
              size: Size.infinite,
            ),
          ),
          AnimatedBuilder(
            animation: _bubbleController,
            builder: (_, __) => CustomPaint(
              painter: BubblePainter(animation: _bubbleController.value),
              size: Size.infinite,
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              margin: const EdgeInsets.only(bottom: 100),
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
                      decoration: _inputDecoration('Guardian Name', Icons.person),
                      validator: (val) => val == null || !_isAlphabetOnly(val) ? 'Use alphabets only' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: _inputDecoration('Email (e.g. user123@gmail.com)', Icons.email),
                      validator: (val) => val == null || !_isValidGmail(val) ? 'Only alphanumeric @gmail.com allowed' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: _inputDecoration('Password (8 digits)', Icons.lock),
                      validator: (val) => val == null || !_isValidPassword(val) ? '8 digit numeric password' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: true,
                      decoration: _inputDecoration('Confirm Password', Icons.lock_outline),
                      validator: (val) => val != _passCtrl.text ? 'Passwords do not match' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Child Age (under 18)', Icons.cake),
                      validator: (val) {
                        final age = int.tryParse(val ?? '');
                        if (age == null || age < 1) return 'Enter valid age';
                        if (age >= 18) return 'Child must be under 18';
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _childIdCtrl,
                      decoration: _inputDecoration('Child (Swimmer) Member ID', Icons.child_care),
                      validator: (val) => val == null || val.isEmpty ? 'Enter valid swimmer member ID' : null,
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

// ------------------ Custom Painters ------------------

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
  bool shouldRepaint(covariant WavePainter oldDelegate) => true;
}

class BubblePainter extends CustomPainter {
  final double animation;
  BubblePainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.3);
    const bubbleCount = 7;

    for (int i = 0; i < bubbleCount; i++) {
      double x = (i + 1) * size.width / (bubbleCount + 1);
      double y = size.height - (animation * size.height * (0.5 + i * 0.05)) % size.height;
      canvas.drawCircle(Offset(x, y), 6 + (i % 3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant BubblePainter oldDelegate) => true;
}



