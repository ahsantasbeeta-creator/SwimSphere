import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class CoachMembershipManagementScreen extends StatefulWidget {
  const CoachMembershipManagementScreen({Key? key}) : super(key: key);

  @override
  State<CoachMembershipManagementScreen> createState() =>
      _CoachMembershipManagementScreenState();
}

class _CoachMembershipManagementScreenState
    extends State<CoachMembershipManagementScreen> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _contactController = TextEditingController();

  String _editingType = '';
  String? _editingDocId;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _nameController.dispose();
    _roleController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _showMemberDialog(String type, {Map<String, dynamic>? data, String? docId}) {
    _editingType = type;
    _isEditing = data != null;
    _editingDocId = docId;

    _nameController.text = data?['name'] ?? '';
    _roleController.text = data?['role'] ?? (type == 'swimmer' ? 'Swimmer' : 'Guardian');
    _contactController.text = data?['contact'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isEditing ? 'Edit Member' : 'Add Member'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (val) => val == null || val.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: _roleController,
                decoration: const InputDecoration(labelText: 'Role'),
                validator: (val) => val == null || val.isEmpty ? 'Enter role' : null,
              ),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'Contact'),
                validator: (val) => val == null || val.isEmpty ? 'Enter contact' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final member = {
                  'name': _nameController.text,
                  'role': _roleController.text,
                  'contact': _contactController.text,
                };
                final collection = FirebaseFirestore.instance
                    .collection(_editingType == 'swimmer' ? 'swimmers' : 'guardians');

                if (_isEditing && _editingDocId != null) {
                  await collection.doc(_editingDocId).update(member);
                } else {
                  await collection.add(member);
                }

                Navigator.pop(context);
              }
            },
            child: Text(_isEditing ? 'Save' : 'Add'),
          )
        ],
      ),
    );
  }

  Widget _buildList(String title, String collectionName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collectionName).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text("Something went wrong");
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showMemberDialog(collectionName),
                  icon: const Icon(Icons.add),
                  label: const Text("Add"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              final name = data['name'] ?? '';
              final role = data['role'] ?? '';
              final contact = data['contact'] ?? '';

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Role: $role | Contact: $contact'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val == 'edit') {
                        _showMemberDialog(collectionName, data: data, docId: doc.id);
                      } else if (val == 'delete') {
                        await FirebaseFirestore.instance
                            .collection(collectionName)
                            .doc(doc.id)
                            .delete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.lightBlueAccent,
        title: Text('Membership Management', style: TextStyle(color: Colors.blue.shade900)),
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
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildList('Swimmers', 'swimmers'),
                const SizedBox(height: 30),
                _buildList('Guardians', 'guardians'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for Animated Waves
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


