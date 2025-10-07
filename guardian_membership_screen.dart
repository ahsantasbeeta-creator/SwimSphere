import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class GuardianMembershipScreen extends StatefulWidget {
  final String guardianId;
  final String? guardianName;
  final String? guardianEmail;
  final List<Map<String, String>>? childrenData;

  const GuardianMembershipScreen({
    Key? key,
    required this.guardianId,
    this.guardianName,
    this.guardianEmail,
    this.childrenData,
  }) : super(key: key);

  @override
  State<GuardianMembershipScreen> createState() => _GuardianMembershipScreenState();
}

class _GuardianMembershipScreenState extends State<GuardianMembershipScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  String guardianName = '';
  String guardianEmail = '';
  List<Map<String, String>> childrenData = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Immediately display passed data
    if (widget.guardianName != null &&
        widget.guardianEmail != null &&
        widget.childrenData != null) {
      guardianName = widget.guardianName!;
      guardianEmail = widget.guardianEmail!;
      childrenData = widget.childrenData!;
      setState(() => isLoading = false);
      _storeGuardianData(); // Store in backend
    } else {
      _fetchGuardianData(); // Fetch from backend
    }
  }

  Future<void> _storeGuardianData() async {
    try {
      final docRef = FirebaseFirestore.instance.collection('guardians').doc(widget.guardianId);
      final existingDoc = await docRef.get();

      if (!existingDoc.exists) {
        await docRef.set({
          'name': guardianName,
          'email': guardianEmail,
          'children': childrenData,
        });
        print('Guardian data stored successfully.');
      } else {
        print('Guardian already exists, skipping store.');
      }
    } catch (e) {
      print('Error storing guardian data: $e');
    }
  }

  Future<void> _fetchGuardianData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('guardians')
          .doc(widget.guardianId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          guardianName = data['name'] ?? '';
          guardianEmail = data['email'] ?? '';
          childrenData = List<Map<String, String>>.from(
            (data['children'] ?? []).map((child) => Map<String, String>.from(child)),
          );
          isLoading = false;
        });
      } else {
        print('Guardian not found in database.');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching guardian data: $e');
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Widget _buildMemberCard(String title, String subtitle) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.lightBlueAccent,
        title: Text('Membership Details', style: TextStyle(color: Colors.blue.shade900)),
        iconTheme: IconThemeData(color: Colors.blue.shade900),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: MultiWavePainter(_waveController.value),
                  );
                },
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Guardian Info',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
                const SizedBox(height: 10),
                _buildMemberCard(
                  guardianName,
                  'Role: Guardian | Contact: $guardianEmail',
                ),
                const SizedBox(height: 30),
                const Text(
                  'Children',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
                const SizedBox(height: 10),
                ...childrenData.map((child) {
                  return _buildMemberCard(
                    child['name'] ?? '',
                    'Role: Swimmer | Age: ${child['age']} | ID: ${child['id']}',
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MultiWavePainter extends CustomPainter {
  final double value;
  MultiWavePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = Colors.blue.shade300.withOpacity(0.4);
    final paint2 = Paint()..color = Colors.blue.shade400.withOpacity(0.5);
    final paint3 = Paint()..color = Colors.blue.shade600.withOpacity(0.6);

    final path1 = Path();
    final path2 = Path();
    final path3 = Path();

    path1.moveTo(0, size.height);
    for (double i = 0; i <= size.width; i++) {
      path1.lineTo(i, sin((i / size.width * 2 * pi) + value * 2 * pi) * 10 + 50);
    }
    path1.lineTo(size.width, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    path2.moveTo(0, size.height);
    for (double i = 0; i <= size.width; i++) {
      path2.lineTo(i, cos((i / size.width * 2 * pi) + value * 2 * pi) * 12 + 60);
    }
    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);

    path3.moveTo(0, size.height);
    for (double i = 0; i <= size.width; i++) {
      path3.lineTo(i, sin((i / size.width * 2 * pi) + value * 2 * pi + pi / 2) * 15 + 70);
    }
    path3.lineTo(size.width, size.height);
    path3.close();
    canvas.drawPath(path3, paint3);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}







