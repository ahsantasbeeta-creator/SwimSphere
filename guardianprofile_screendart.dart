import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swimsphere/screenss/welcome_screen.dart';

class GuardianProfileScreen extends StatefulWidget {
  final String guardianName;
  final String guardianEmail;
  final String childId;
  final String childage;

  const GuardianProfileScreen({
    super.key,
    required this.guardianName,
    required this.guardianEmail,
    required this.childId,
    required this.childage,
  });

  @override
  State<GuardianProfileScreen> createState() => _GuardianProfileScreenState();
}

class _GuardianProfileScreenState extends State<GuardianProfileScreen> {
  File? _imageFile;
  bool _isEditing = false;

  late TextEditingController _nameController;
  late TextEditingController _emailController;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.guardianName);
    _emailController = TextEditingController(text: widget.guardianEmail);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('guardians').doc(uid).set({
        'name': _nameController.text,
        'email': _emailController.text,
        'childId': widget.childId,
        'childAge': widget.childage,
        'profileImageUrl': '', // You can integrate Firebase Storage to add image uploading later.
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });

    if (!_isEditing) {
      _updateProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool enabled = false}) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return TextFormField(
      initialValue: value,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Logout")),
        ],
      ),
    );

    if (confirmed == true) {
      _logLogout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (route) => false,
      );
    }
  }

  Future<void> _logLogout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('logout_logs').add({
        'userId': uid,
        'role': 'guardian',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00838F),
        title: const Text("Guardian Profile"),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _toggleEdit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _isEditing ? _pickImage : null,
              child: CircleAvatar(
                radius: 55,
                backgroundColor: const Color(0xFF4DD0E1),
                backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                child: _imageFile == null
                    ? const Icon(Icons.person, size: 60, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField('Guardian Name', _nameController, enabled: _isEditing),
            const SizedBox(height: 15),
            _buildTextField('Guardian Email', _emailController, enabled: _isEditing),
            const SizedBox(height: 15),
            _buildReadOnlyField('Child Id', widget.childId),
            const SizedBox(height: 15),
            _buildReadOnlyField('Child Age', widget.childage),
            const SizedBox(height: 15),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: const [
                Icon(Icons.verified, color: Colors.green),
                SizedBox(width: 10),
                Text("Status: Active", style: TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: const [
                Icon(Icons.family_restroom, color: Colors.deepPurple),
                SizedBox(width: 10),
                Text("Role: Guardian", style: TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
