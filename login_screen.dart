import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import 'swimmerhome_screen.dart';
import 'coachhome_screen.dart';
import 'guardianhome_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _memberIdController = TextEditingController();
  final _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _memberIdController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _showErrorDialog(String message) async {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white.withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Login Error', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final enteredMemberId = _memberIdController.text.trim().toUpperCase();
    final password = _passwordController.text.trim();

    String? collection;
    if (enteredMemberId.startsWith('SW')) {
      collection = 'swimmers';
    } else if (enteredMemberId.startsWith('CO')) {
      collection = 'coaches';
    } else if (enteredMemberId.startsWith('GU')) {
      collection = 'guardians';
    } else {
      await _showErrorDialog('Invalid Member ID prefix');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await _firestore
          .collection(collection)
          .where('memberId', isEqualTo: enteredMemberId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found with this Member ID',
        );
      }

      final userData = snapshot.docs.first.data();
      final email = userData['email'] ?? '';
      final name = userData['name'] ?? '';
      final age = userData['age']?.toString() ?? '0';
      final fetchedMemberId = userData['memberId'] ?? '';
      final status = userData['status'] ?? 'Inactive';
      final profilePicUrl = userData['profilePicUrl'] ?? userData['imageURL'] ?? '';

      await _auth.signInWithEmailAndPassword(email: email, password: password);

      if (collection == 'swimmers') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SwimmerHomeScreen(
              name: name,
              email: email,
              age: age,
              skillLevel: userData['skillLevel'] ?? 'Beginner',
              memberId: fetchedMemberId,
              status: status,
              profilePicUrl: profilePicUrl,
            ),
          ),
        );
      } else if (collection == 'coaches') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              name: name,
              email: email,
              age: age,
              qualification: userData['qualification'] ?? '',
              memberId: fetchedMemberId,
              status: status,
              profilePicUrl: profilePicUrl,
            ),
          ),
        );
      } else if (collection == 'guardians') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GuardianHomeScreen(
              name: name,
              email: email,
              memberId: fetchedMemberId,
              status: status,
              childId: userData['childId'] ?? '',
              childage: userData['childage']?.toString() ?? '0',
              profilePicUrl: profilePicUrl,
              age: '', // ✅ fixed: pass empty string instead of null
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      await _showErrorDialog(e.message ?? 'Login failed');
    } catch (e) {
      await _showErrorDialog('An error occurred during login.');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            height: screenHeight,
            width: screenWidth,
            child: Image.asset(
              'assets/images/loginpagepic.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Container(
            height: screenHeight,
            width: screenWidth,
            color: Colors.black.withOpacity(0.25),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.07),
                child: Column(
                  children: [
                    SizedBox(height: screenHeight * 0.05),
                    Image.asset(
                      'assets/images/Applogo.png',
                      height: screenHeight * 0.18,
                    ),
                    SizedBox(height: screenHeight * 0.06),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _memberIdController,
                                  decoration: InputDecoration(
                                    labelText: 'Member ID',
                                    prefixIcon: const Icon(Icons.person),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your Member ID';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: 'Password (8 characters)',
                                    prefixIcon: const Icon(Icons.lock),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (value.length != 8) {
                                      return 'Password must be exactly 8 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 25),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                        : const Text('Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                                  },
                                  child: const Text('Forgot Password?', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Don’t have an account?'),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                                      },
                                      child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.04),
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










