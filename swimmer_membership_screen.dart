import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class SwimmerMembershipScreen extends StatefulWidget {
  final String name;
  final String email;
  final String memberId;
  final String status;
  final String role;

  const SwimmerMembershipScreen({
    Key? key,
    required this.name,
    required this.email,
    required this.memberId,
    required this.status,
    required this.role,
  }) : super(key: key);

  @override
  State<SwimmerMembershipScreen> createState() => _SwimmerMembershipScreenState();
}

class _SwimmerMembershipScreenState extends State<SwimmerMembershipScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _storeSwimmerDataToFirestore();
  }

  Future<void> _storeSwimmerDataToFirestore() async {
    final docRef = FirebaseFirestore.instance.collection('memberships').doc(widget.memberId);

    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      await docRef.set({
        'name': widget.name,
        'email': widget.email,
        'memberId': widget.memberId,
        'status': widget.status,
        'role': widget.role,
        'joinedDate': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, String> swimmerInfo = {
      'Name': widget.name,
      'Email': widget.email,
      'Role': widget.role,
      'Status': widget.status,
      'Membership ID': widget.memberId,
      'Joined': 'June 2025',
    };

    return Scaffold(
      backgroundColor: Colors.lightBlue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.lightBlueAccent,
        title: Text(
          'My Membership',
          style: TextStyle(color: Colors.blue.shade900),
        ),
        iconTheme: IconThemeData(color: Colors.blue.shade900),
      ),
      body: Stack(
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildSwimmerInfoCard(swimmerInfo),
          ),
        ],
      ),
    );
  }

  Widget _buildSwimmerInfoCard(Map<String, String> swimmerInfo) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: swimmerInfo.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${entry.key}:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
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

    // Wave 1
    path1.moveTo(0, size.height);
    for (double i = 0; i <= size.width; i++) {
      path1.lineTo(i, sin((i / size.width * 2 * pi) + value * 2 * pi) * 10 + 50);
    }
    path1.lineTo(size.width, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Wave 2
    path2.moveTo(0, size.height);
    for (double i = 0; i <= size.width; i++) {
      path2.lineTo(i, cos((i / size.width * 2 * pi) + value * 2 * pi) * 12 + 60);
    }
    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);

    // Wave 3
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




