import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

// ENUMS
enum NotificationType { event, membership, schedule, announcement, system }
enum NotificationPriority { normal, high, urgent }

// MODEL
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final NotificationPriority priority;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    required this.priority,
  });

  factory NotificationItem.fromMap(String id, Map<String, dynamic> data) {
    return NotificationItem(
      id: id,
      title: data['title'] ?? 'Untitled',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: NotificationType.values.firstWhere(
            (e) => e.toString() == data['type'],
        orElse: () => NotificationType.announcement,
      ),
      priority: NotificationPriority.values.firstWhere(
            (e) => e.toString() == data['priority'],
        orElse: () => NotificationPriority.normal,
      ),
    );
  }
}

// MAIN NOTIFICATION SCREEN
class NotificationScreen extends StatefulWidget {
  final String role; // Swimmer, Guardian, Coach
  const NotificationScreen({super.key, required this.role});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  NotificationType _selectedType = NotificationType.announcement;
  NotificationPriority _selectedPriority = NotificationPriority.normal;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('notifications').add({
      'title': _titleController.text,
      'message': _messageController.text,
      'timestamp': DateTime.now(),
      'type': _selectedType.toString(),
      'priority': _selectedPriority.toString(),
    });

    _titleController.clear();
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      body: Stack(
        children: [
          // Water Wave Background
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return CustomPaint(
                painter: WavePainter(animation: _waveController, color: Colors.lightBlue.shade100),
                size: Size.infinite,
              );
            },
          ),

          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Notifications (${widget.role})",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 16),

                  // Only Coach Can Send
                  if (widget.role == 'Coach') ...[
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButton<NotificationType>(
                      value: _selectedType,
                      onChanged: (val) => setState(() => _selectedType = val!),
                      items: NotificationType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.name),
                        );
                      }).toList(),
                    ),
                    DropdownButton<NotificationPriority>(
                      value: _selectedPriority,
                      onChanged: (val) => setState(() => _selectedPriority = val!),
                      items: NotificationPriority.values.map((priority) {
                        return DropdownMenuItem(
                          value: priority,
                          child: Text(priority.name),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _sendNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text("Send Notification"),
                    ),
                    const Divider(height: 30),
                  ],

                  // Notification List
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('notifications')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return const Center(child: Text('No notifications found'));
                        }

                        final items = docs.map((e) {
                          try {
                            return NotificationItem.fromMap(e.id, e.data() as Map<String, dynamic>);
                          } catch (e) {
                            return null;
                          }
                        }).whereType<NotificationItem>().toList();

                        return ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) => _buildNotificationCard(items[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.notifications, color: Colors.blue),
        title: Text(notification.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 4),
            Text(
              'Type: ${notification.type.name}, Priority: ${notification.priority.name}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Text(DateFormat('MMM d, h:mm a').format(notification.timestamp)),
      ),
    );
  }
}

// WAVE PAINTER
class WavePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  WavePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    _drawWave(canvas, size, paint, 0.8, 0.04, animation.value);
    _drawWave(canvas, size, paint, 0.85, 0.06, animation.value + 1);
    _drawWave(canvas, size, paint, 0.9, 0.05, animation.value + 2);
  }

  void _drawWave(Canvas canvas, Size size, Paint paint, double yFactor, double amplitude, double phase) {
    final path = Path();
    final yBase = size.height * yFactor;
    path.moveTo(0, yBase);

    for (double x = 0; x <= size.width; x++) {
      double y = yBase + math.sin((x / size.width * 2 * math.pi) + phase * 2 * math.pi) * size.height * amplitude;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

