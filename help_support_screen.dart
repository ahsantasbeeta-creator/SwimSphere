import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  final List<FAQItem> faqItems = [
    FAQItem(
      question: "How do I book a swimming session?",
      answer: "Use 'Book Session' in the main menu and confirm your time slot.",
    ),
    FAQItem(
      question: "What are the membership benefits?",
      answer: "Access to all facilities, discounts, and exclusive events.",
    ),
    FAQItem(
      question: "How can I cancel my booking?",
      answer: "Cancel through 'My Bookings' at least 24 hours before.",
    ),
    FAQItem(
      question: "What are the pool opening hours?",
      answer: "Mon–Fri: 6 AM–10 PM, Sat–Sun: 7 AM–8 PM.",
    ),
  ];

  late List<Bubble> bubbles;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    bubbles = List.generate(30, (index) => Bubble.random());

    _searchController.addListener(() {
      _storeSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _storeSearchQuery(String query) async {
    if (query.trim().isEmpty) return;
    await FirebaseFirestore.instance.collection('faq_search_queries').add({
      'query': query.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _submitSupportRequest() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      await FirebaseFirestore.instance.collection('support_requests').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'message': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      await Future.delayed(const Duration(seconds: 2));
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Support request submitted. We will respond soon.'),
          backgroundColor: Colors.green,
        ),
      );

      _nameController.clear();
      _emailController.clear();
      _messageController.clear();
    }
  }

  void _updateBubbles() {
    final size = MediaQuery.of(context).size;
    for (var bubble in bubbles) {
      bubble.updatePosition(size);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFBBDEFB),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return CustomPaint(
                painter: WavePainter(animation: _waveController),
                child: Container(),
              );
            },
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                _updateBubbles();
                return CustomPaint(painter: BubblePainter(bubbles));
              },
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.blue.shade900),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Help & Support',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search FAQs...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.95),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...faqItems
                      .where((faq) => faq.question
                      .toLowerCase()
                      .contains(_searchController.text.toLowerCase()))
                      .map((faq) => FAQExpansionTile(faq: faq)),
                  const SizedBox(height: 20),
                  Card(
                    color: const Color(0xFFE3F2FD),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contact Support',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                labelText: 'Message',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 4,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your message';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : _submitSupportRequest,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: _isSubmitting
                                    ? const CircularProgressIndicator(
                                    color: Colors.white)
                                    : const Text('Submit Request'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// FAQ
class FAQItem {
  final String question;
  final String answer;

  FAQItem({required this.question, required this.answer});
}

class FAQExpansionTile extends StatelessWidget {
  final FAQItem faq;

  const FAQExpansionTile({Key? key, required this.faq}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFE3F2FD),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        title: Text(
          faq.question,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(faq.answer),
          ),
        ],
      ),
    );
  }
}

// Wave animation painter
class WavePainter extends CustomPainter {
  final Animation<double> animation;

  WavePainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final double waveHeight = size.height * 0.15;
    final double baseHeight = size.height * 0.8;

    final Paint paint1 = Paint()
      ..shader = LinearGradient(
        colors: [Colors.blue.shade400.withOpacity(0.6), Colors.blue.shade200.withOpacity(0.3)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, baseHeight - waveHeight, size.width, waveHeight))
      ..style = PaintingStyle.fill;

    final Paint paint2 = Paint()
      ..shader = LinearGradient(
        colors: [Colors.blue.shade700.withOpacity(0.5), Colors.blue.shade400.withOpacity(0.2)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, baseHeight - waveHeight * 1.5, size.width, waveHeight * 1.5))
      ..style = PaintingStyle.fill;

    final Paint paint3 = Paint()
      ..shader = LinearGradient(
        colors: [Colors.blue.shade900.withOpacity(0.4), Colors.blue.shade600.withOpacity(0.1)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, baseHeight - waveHeight * 2, size.width, waveHeight * 2))
      ..style = PaintingStyle.fill;

    Path createWavePath(double waveHeight, double waveLength, double phase, double yOffset) {
      Path path = Path()..moveTo(0, yOffset);
      int waveCount = (size.width / waveLength).ceil() + 1;
      for (int i = 0; i < waveCount; i++) {
        double startX = i * waveLength - phase;
        path.cubicTo(
          startX + waveLength * 0.25,
          yOffset + waveHeight,
          startX + waveLength * 0.75,
          yOffset - waveHeight,
          startX + waveLength,
          yOffset,
        );
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
      return path;
    }

    double phase1 = animation.value * 300;
    double phase2 = animation.value * 200;
    double phase3 = animation.value * 150;

    canvas.drawPath(createWavePath(waveHeight * 1.2, 300, phase1, baseHeight), paint1);
    canvas.drawPath(createWavePath(waveHeight, 250, phase2, baseHeight + 15), paint2);
    canvas.drawPath(createWavePath(waveHeight * 0.7, 200, phase3, baseHeight + 30), paint3);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) => true;
}

// Bubbles
class Bubble {
  double x, y, radius, speedY, driftX;
  final Color color;
  final math.Random random = math.Random();

  Bubble({
    required this.x,
    required this.y,
    required this.radius,
    required this.speedY,
    required this.driftX,
    required this.color,
  });

  factory Bubble.random() {
    final random = math.Random();
    return Bubble(
      x: random.nextDouble(),
      y: random.nextDouble(),
      radius: 4 + random.nextDouble() * 6,
      speedY: 0.002 + random.nextDouble() * 0.004,
      driftX: (random.nextDouble() - 0.5) * 0.002,
      color: Colors.white.withOpacity(0.3 + random.nextDouble() * 0.4),
    );
  }

  void updatePosition(Size size) {
    y += speedY;
    x += driftX;
    if (y > 1.1) y = -0.1;
    if (x > 1.1) x = -0.1;
    if (x < -0.1) x = 1.1;
  }

  Offset getOffset(Size size) => Offset(x * size.width, y * size.height);
}

class BubblePainter extends CustomPainter {
  final List<Bubble> bubbles;

  BubblePainter(this.bubbles);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    for (var bubble in bubbles) {
      paint.color = bubble.color;
      canvas.drawCircle(bubble.getOffset(size), bubble.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BubblePainter oldDelegate) => true;
}
