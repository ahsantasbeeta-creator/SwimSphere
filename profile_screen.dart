import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String name;
  final String email;
  final String age;
  final String skillLevel;

  const ProfileScreen({
    super.key,
    required this.name,
    required this.email,
    required this.age,
    required this.skillLevel, required String profilePicUrl, required String role, required String memberId, required String status,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TextEditingController _nameController;
  late TextEditingController _ageController;

  bool _isEditing = false;
  File? _imageFile;
  String? _imageURL;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _ageController = TextEditingController(text: widget.age);
    _fetchImageURL();
  }

  Future<void> _fetchImageURL() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (snapshot.exists && snapshot.data()?['imageURL'] != null) {
      setState(() {
        _imageURL = snapshot['imageURL'];
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final uid = _auth.currentUser?.uid;
      final ref = FirebaseStorage.instance.ref().child("profilePics/$uid.jpg");
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Upload Error: $e");
      return null;
    }
  }

  Future<void> _saveProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    String? newImageURL = _imageURL;
    if (_imageFile != null) {
      newImageURL = await _uploadImage(_imageFile!);
    }

    await _firestore.collection('users').doc(uid).set({
      'name': _nameController.text.trim(),
      'email': widget.email,
      'age': _ageController.text.trim(),
      'skillLevel': widget.skillLevel,
      'imageURL': newImageURL,
      'role': 'Swimmer',
      'status': 'Active',
    }, SetOptions(merge: true));

    setState(() {
      _imageURL = newImageURL;
      _isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile saved successfully.")),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Logout")),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _auth.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (_) => false,
      );
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool enabled = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileImage = _imageFile != null
        ? FileImage(_imageFile!)
        : (_imageURL != null ? NetworkImage(_imageURL!) : null);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00838F),
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
          )
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
                backgroundColor: Colors.teal.shade200,
                backgroundImage: profileImage as ImageProvider?,
                child: profileImage == null
                    ? const Icon(Icons.person, size: 60, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(label: "Name", controller: _nameController, enabled: _isEditing),
            const SizedBox(height: 15),
            _buildTextField(label: "Email", controller: TextEditingController(text: widget.email), enabled: false),
            const SizedBox(height: 15),
            _buildTextField(label: "Age", controller: _ageController, enabled: _isEditing),
            const SizedBox(height: 15),
            TextFormField(
              initialValue: widget.skillLevel,
              enabled: false,
              decoration: const InputDecoration(
                labelText: "Skill Level",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),
            const Divider(thickness: 1),
            const SizedBox(height: 10),
            Row(
              children: const [
                Icon(Icons.verified_user, color: Colors.green),
                SizedBox(width: 8),
                Text("Status: Active", style: TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: const [
                Icon(Icons.person_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text("Role: Swimmer", style: TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _confirmLogout,
            ),
          ],
        ),
      ),
    );
  }
}
