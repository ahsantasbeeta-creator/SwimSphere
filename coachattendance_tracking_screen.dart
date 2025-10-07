import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CoachAttendanceScreen extends StatefulWidget {
  final String? swimmerId;
  final String? userId;
  final String? role;

  const CoachAttendanceScreen({
    super.key,
    required this.swimmerId,
    required this.userId,
    required this.role,
  });

  @override
  State<CoachAttendanceScreen> createState() => _CoachAttendanceScreenState();
}

class _CoachAttendanceScreenState extends State<CoachAttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String> attendanceStatus = {};
  String searchQuery = "";
  DateTime selectedDate = DateTime.now();
  bool isSubmitting = false;

  String get _selectedDateString => DateFormat('yyyy-MM-dd').format(selectedDate);

  @override
  void initState() {
    super.initState();
    _loadExistingAttendance();
    _debugSwimmerData(); // Add debug function
  }

  // Debug function to check swimmer data
  Future<void> _debugSwimmerData() async {
    try {
      final swimmersSnapshot = await _firestore.collection('swimmers').get();
      print('=== DEBUG: Swimmers Collection ===');
      print('Total swimmers found: ${swimmersSnapshot.docs.length}');
      
      for (var doc in swimmersSnapshot.docs) {
        final data = doc.data();
        print('Swimmer ID: ${doc.id}');
        print('Name: ${data['name']}');
        print('Member ID: ${data['memberId']}');
        print('Role: ${data['role']}');
        print('---');
      }
    } catch (e) {
      print('Error debugging swimmer data: $e');
    }
  }

  // Test function to create sample attendance data
  Future<void> _createSampleAttendanceData() async {
    try {
      final swimmersSnapshot = await _firestore.collection('swimmers').get();
      if (swimmersSnapshot.docs.isEmpty) {
        print('No swimmers found to create sample data');
        return;
      }

      final firstSwimmer = swimmersSnapshot.docs.first;
      final swimmerId = firstSwimmer.id;
      final swimmerName = firstSwimmer.data()['name'] ?? 'Unknown';

      print('=== DEBUG: Creating Sample Attendance Data ===');
      print('Swimmer ID: $swimmerId');
      print('Swimmer Name: $swimmerName');

      // Create sample attendance for today
      final today = DateTime.now();
      final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final docRef = _firestore
          .collection('attendance')
          .doc(swimmerId)
          .collection('records')
          .doc(dateString);

      final sampleData = {
        'date': dateString,
        'status': 'Present',
        'timestamp': FieldValue.serverTimestamp(),
        'markedBy': 'test_coach',
        'markedAt': DateTime.now().toIso8601String(),
        'swimmerId': swimmerId,
      };

      await docRef.set(sampleData);
      print('Sample attendance data created successfully');
      print('Data: $sampleData');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sample attendance data created for $swimmerName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error creating sample data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating sample data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadExistingAttendance() async {
    try {
      final snapshot = await _firestore
          .collection('attendance')
          .get();

      for (var doc in snapshot.docs) {
        final recordDoc = await _firestore
            .collection('attendance')
            .doc(doc.id)
            .collection('records')
            .doc(_selectedDateString)
            .get();

        if (recordDoc.exists) {
          final data = recordDoc.data() as Map<String, dynamic>;
          setState(() {
            attendanceStatus[doc.id] = data['status'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading existing attendance: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.lightBlueAccent,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        attendanceStatus.clear();
      });
      _loadExistingAttendance();
    }
  }

  void _setStatus(String swimmerId, String status) {
    setState(() {
      attendanceStatus[swimmerId] = status;
    });
  }

  void _clearStatus(String swimmerId) {
    setState(() {
      attendanceStatus.remove(swimmerId);
    });
  }

  Future<void> _submitAttendance() async {
    if (attendanceStatus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No attendance marked to submit.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      WriteBatch batch = _firestore.batch();

      // Debug: Print what we're about to submit
      print('=== DEBUG: Submitting Attendance ===');
      print('Date: $_selectedDateString');
      print('Attendance Status: $attendanceStatus');

      attendanceStatus.forEach((swimmerId, status) {
        // Use the swimmer's UID (document ID) to store attendance records
        final docRef = _firestore
            .collection('attendance')
            .doc(swimmerId) // This is the swimmer's UID from the swimmers collection
            .collection('records')
            .doc(_selectedDateString);

        final attendanceData = {
          'date': _selectedDateString,
          'status': status,
          'timestamp': FieldValue.serverTimestamp(),
          'markedBy': widget.userId ?? 'coach',
          'markedAt': DateTime.now().toIso8601String(),
          'swimmerId': swimmerId, // Store the swimmer ID for reference
        };

        // Debug: Print the data being stored
        print('Storing for swimmer $swimmerId: $attendanceData');

        batch.set(docRef, attendanceData);
      });

      await batch.commit();

      // Debug: Print success message
      print('=== DEBUG: Attendance Submitted Successfully ===');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance submitted successfully for ${_selectedDateString}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Debug: Print error details
      print('=== DEBUG: Attendance Submission Error ===');
      print('Error: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting attendance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mark Attendance',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.lightBlueAccent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.lightBlueAccent),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM dd, yyyy').format(selectedDate),
                      style: TextStyle(
                        color: Colors.lightBlueAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _selectDate(context),
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Change Date'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            searchQuery = val.trim().toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search swimmers...',
          prefixIcon: const Icon(Icons.search, color: Colors.lightBlueAccent),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchQuery = "");
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildSwimmerTile(DocumentSnapshot swimmerDoc) {
    final swimmerId = swimmerDoc.id;
    final swimmerData = swimmerDoc.data() as Map<String, dynamic>? ?? {};
    final swimmerName = swimmerData['name'] ?? 'Unnamed';
    final swimmerAge = swimmerData['age'] ?? '';
    final currentStatus = attendanceStatus[swimmerId];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.lightBlueAccent.withOpacity(0.1),
          child: Text(
            swimmerName.isNotEmpty ? swimmerName[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.lightBlueAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          swimmerName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: $swimmerId',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            if (swimmerAge.isNotEmpty)
              Text(
                'Age: $swimmerAge',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        trailing: Container(
          width: 200,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _setStatus(swimmerId, 'Present'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentStatus == 'Present' 
                        ? Colors.green 
                        : Colors.green.withOpacity(0.1),
                    foregroundColor: currentStatus == 'Present' 
                        ? Colors.white 
                        : Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: currentStatus == 'Present' ? 2 : 0,
                  ),
                  child: const Text(
                    'Present',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _setStatus(swimmerId, 'Absent'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentStatus == 'Absent' 
                        ? Colors.red 
                        : Colors.red.withOpacity(0.1),
                    foregroundColor: currentStatus == 'Absent' 
                        ? Colors.white 
                        : Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: currentStatus == 'Absent' ? 2 : 0,
                  ),
                  child: const Text(
                    'Absent',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
        onLongPress: () {
          _clearStatus(swimmerId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cleared attendance for $swimmerName'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard() {
    final presentCount = attendanceStatus.values.where((s) => s == 'Present').length;
    final absentCount = attendanceStatus.values.where((s) => s == 'Absent').length;
    final totalMarked = attendanceStatus.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total Marked',
                  totalMarked.toString(),
                  Colors.blue,
                  Icons.checklist,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Present',
                  presentCount.toString(),
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Absent',
                  absentCount.toString(),
                  Colors.red,
                  Icons.cancel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSubmitting || attendanceStatus.isEmpty ? null : _submitAttendance,
              icon: isSubmitting 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(isSubmitting ? 'Submitting...' : 'Submit Attendance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot> swimmerStream = _firestore
        .collection('swimmers')
        .orderBy('name')
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Attendance Management',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.lightBlueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _createSampleAttendanceData,
            tooltip: 'Create Sample Data',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('How to use'),
                  content: const Text(
                    '• Tap Present/Absent to mark attendance\n'
                    '• Long press to clear a mark\n'
                    '• Use search to find specific swimmers\n'
                    '• Change date to mark attendance for different days\n'
                    '• Submit when done marking all swimmers\n'
                    '• Use the bug icon to create sample data for testing',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: swimmerStream,
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];

                final filtered = docs.where((doc) {
                  final name = ((doc.data() as Map<String, dynamic>?)?['name'] ?? '')
                      .toString()
                      .toLowerCase();
                  if (searchQuery.isEmpty) return true;
                  return name.contains(searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.lightBlueAccent),
                          SizedBox(height: 16),
                          Text(
                            'Loading swimmers...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isEmpty 
                              ? 'No swimmers registered yet'
                              : 'No matching swimmers found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    return _buildSwimmerTile(doc);
                  },
                );
              },
            ),
          ),
          _buildSummaryCard(),
        ],
      ),
    );
  }
}




