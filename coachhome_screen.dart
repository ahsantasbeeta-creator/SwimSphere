import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:swimsphere/screenss/coachattendance_tracking_screen.dart';
import 'package:swimsphere/screenss/coachbooking_screen.dart';
import 'package:swimsphere/screenss/help_support_screen.dart';
import 'package:swimsphere/screenss/coach_membership_screen.dart';
import 'package:swimsphere/screenss/coachstreaks_goals_screen.dart';
import 'package:swimsphere/screenss/coachprofile_screen.dart';
import 'package:swimsphere/screenss/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  final String name;
  final String email;
  final String age;
  final String qualification;
  final String memberId;
  final String status;
  final String profilePicUrl;

  const HomeScreen({
    super.key,
    required this.name,
    required this.email,
    required this.age,
    required this.qualification,
    required this.memberId,
    required this.status,
    required this.profilePicUrl,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
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
            _buildAnimatedWave(_wave1Controller, const Color(0xFF4DD0E1), 20, 0),
            _buildAnimatedWave(_wave2Controller, const Color(0xFF00BCD4), 30, 20),
            _buildAnimatedWave(_wave3Controller, const Color(0xFF00838F), 40, 40),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildTopBar(context),
                    const SizedBox(height: 30),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildModuleCard('Notifications & Announcements', Icons.notifications_active, const Color(0xFF4DD0E1)),
                        _buildModuleCard('Help & Support', Icons.help_outline, const Color(0xFF26C6DA)),
                        _buildModuleCard('Membership Management', Icons.card_membership, const Color(0xFF00BCD4)),
                        _buildModuleCard('Attendance Tracking', Icons.person_pin, const Color(0xFF00ACC1)),
                        _buildModuleCard('Scheduling & Booking', Icons.calendar_today, const Color(0xFF0097A7)),
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

  Widget _buildAnimatedWave(AnimationController controller, Color color, double height, double offset) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
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

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CoachProfileScreen(
                  name: widget.name,
                  email: widget.email,
                  age: widget.age,
                  qualification: widget.qualification, profilePicUrl: '', role: '', coachId: '', status: '',
                ),
              ),
            );
          },
          child: CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFF4DD0E1),
            child: widget.profilePicUrl.isNotEmpty
                ? ClipOval(
              child: Image.network(widget.profilePicUrl, fit: BoxFit.cover, width: 50, height: 50),
            )
                : const Icon(Icons.person, color: Colors.white),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome,',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w400, color: Color(0xFF006064)),
            ),
            Text(
              '${widget.name} 👋',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF006064)),
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
                MaterialPageRoute(builder: (_) => const NotificationScreen(role: 'Coach')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard(String title, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          if (title == 'Membership Management') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CoachMembershipManagementScreen()));
          } else if (title == 'Attendance Tracking') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CoachAttendanceScreen(
                  role: 'coach',
                  userId: widget.memberId,
                  swimmerId: '',
                ),
              ),
            );
          } else if (title == 'Help & Support') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
          } else if (title == 'Notifications & Announcements') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen(role: 'Coach')));
          } else if (title == 'Scheduling & Booking') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CoachBookingScreen()));
          } else if (title == 'Streaks & Goals') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CoachStreaksGoalsScreen()));
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.7), color],
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
    final height = size.height;
    final width = size.width;
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


