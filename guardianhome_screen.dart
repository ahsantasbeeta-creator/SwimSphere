import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swimsphere/screenss/guardianprofile_screendart.dart';
import 'package:swimsphere/screenss/notifications_screen.dart';
import 'package:swimsphere/screenss/help_support_screen.dart';
import 'package:swimsphere/screenss/guardianattendance_tracking_screen.dart';
import 'package:swimsphere/screenss/booking_screen.dart';
import 'package:swimsphere/screenss/guardian_membership_screen.dart';
import 'package:swimsphere/screenss/guardianstreaks_goals_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GuardianHomeScreen extends StatefulWidget {
  final String name;
  final String email;
  final String childage;
  final String childId;
  final String memberId;
  final String status;

  const GuardianHomeScreen({
    Key? key,
    required this.name,
    required this.email,
    required this.childage,
    required this.childId,
    required this.memberId,
    required this.status,
    required String profilePicUrl,
    required String age,
  }) : super(key: key);

  @override
  State<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends State<GuardianHomeScreen> with TickerProviderStateMixin {
  late final AnimationController _wave1Controller;
  late final AnimationController _wave2Controller;
  late final AnimationController _wave3Controller;

  @override
  void initState() {
    super.initState();
    _wave1Controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _wave2Controller = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _wave3Controller = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
  }

  @override
  void dispose() {
    _wave1Controller.dispose();
    _wave2Controller.dispose();
    _wave3Controller.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    return (await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (Platform.isAndroid) {
                SystemNavigator.pop();
              } else if (Platform.isIOS) {
                exit(0);
              }
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFE0F7FA),
        body: Stack(
          children: [
            _buildWave(_wave1Controller, const Color(0xFF4DD0E1), 20, 0),
            _buildWave(_wave2Controller, const Color(0xFF00BCD4), 30, 20),
            _buildWave(_wave3Controller, const Color(0xFF00838F), 40, 40),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GuardianProfileScreen(
                                  guardianName: widget.name,
                                  guardianEmail: widget.email,
                                  childId: widget.childId,
                                  childage: widget.childage,
                                ),
                              ),
                            );
                          },
                          child: const CircleAvatar(
                            radius: 25,
                            backgroundColor: Color(0xFF4DD0E1),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: Color(0xFF00796B)),
                            ),
                            Text(
                              widget.name,
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF006064)),
                            ),
                          ],
                        ),
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFF4DD0E1),
                          child: IconButton(
                            icon: const Icon(Icons.notifications, color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationScreen(role: 'Guardian'),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildModuleCard('Notifications', Icons.notifications, const Color(0xFF4DD0E1)),
                        _buildModuleCard('Help & Support', Icons.help_outline, const Color(0xFF26C6DA)),
                        _buildModuleCard('Attendance', Icons.check_circle_outline, const Color(0xFF00ACC1)),
                        _buildModuleCard('Booking', Icons.calendar_today, const Color(0xFF0097A7)),
                        _buildModuleCard('Membership', Icons.group, const Color(0xFF00796B)),
                        _buildModuleCard('Streaks & Goals', Icons.emoji_events, const Color(0xFF00838F)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AnimatedBuilder _buildWave(AnimationController controller, Color color, double height, double offset) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          painter: WavePainter(
            animationValue: controller.value,
            color: color.withOpacity(0.3),
            waveHeight: height,
            waveOffset: offset,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildModuleCard(String title, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () async {
          if (title == 'Notifications') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen(role: 'Guardian')));
          } else if (title == 'Help & Support') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
          } else if (title == 'Attendance') {
            // Get the current guardian's data to find the child name
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null) {
              final guardianDoc = await FirebaseFirestore.instance
                  .collection('guardians')
                  .doc(currentUser.uid)
                  .get();
              
              if (guardianDoc.exists) {
                final guardianData = guardianDoc.data() as Map<String, dynamic>;
                final childName = guardianData['childName'] ?? '${widget.name} Jr.';
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GuardianAttendanceScreen(
                      childId: widget.childId,
                      swimmerId: widget.childId, // This should be the swimmer's Firebase UID
                      childName: childName, // Use the actual child name from database
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error: Guardian data not found'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error: User not authenticated'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } else if (title == 'Booking') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingScreen()));
          } else if (title == 'Membership') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GuardianMembershipScreen(
                  guardianName: widget.name,
                  guardianEmail: widget.email,
                  childrenData: [
                    {
                      'name': '${widget.name} Jr.',
                      'age': widget.childage,
                      'id': widget.childId,
                    },
                  ],
                  guardianId: widget.memberId,
                ),
              ),
            );
          } else if (title == 'Streaks & Goals') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GuardianStreaksGoalsScreen(childId: widget.childId, childName: '',),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final double waveHeight;
  final double waveOffset;

  WavePainter({
    required this.animationValue,
    required this.color,
    required this.waveHeight,
    required this.waveOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    final width = size.width;
    final height = size.height;
    final double speed = animationValue * 2 * math.pi;

    path.moveTo(0, height * 0.8 + waveOffset);
    for (double i = 0; i <= width; i++) {
      path.lineTo(i, height * 0.8 + waveOffset + waveHeight * math.sin((i / width * 2 * math.pi) + speed));
    }
    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) => true;
}







