import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class GuardianAttendanceScreen extends StatefulWidget {
  final String childId;
  final String swimmerId;
  final String childName;

  const GuardianAttendanceScreen({
    super.key,
    required this.childId,
    required this.swimmerId,
    required this.childName,
  });

  @override
  State<GuardianAttendanceScreen> createState() => _GuardianAttendanceScreenState();
}

class _GuardianAttendanceScreenState extends State<GuardianAttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String selectedPeriod = 'Last 30 Days';
  final List<String> periods = ['Last 7 Days', 'Last 30 Days', 'Last 3 Months', 'All Time'];

  @override
  void initState() {
    super.initState();
    _debugGuardianData(); // Add debug function
  }

  // Debug function to check guardian and swimmer data
  Future<void> _debugGuardianData() async {
    try {
      print('=== DEBUG: Guardian Attendance Debug ===');
      print('Child ID: ${widget.childId}');
      print('Swimmer ID: ${widget.swimmerId}');
      print('Child Name: ${widget.childName}');

      // Check if the swimmer exists
      final swimmerDoc = await _firestore.collection('swimmers').doc(widget.swimmerId).get();
      if (swimmerDoc.exists) {
        final swimmerData = swimmerDoc.data() as Map<String, dynamic>;
        print('Swimmer found: ${swimmerData['name']}');
        print('Swimmer Member ID: ${swimmerData['memberId']}');
      } else {
        print('Swimmer not found with ID: ${widget.swimmerId}');
      }

      // Check if attendance collection exists
      final attendanceDoc = await _firestore.collection('attendance').doc(widget.swimmerId).get();
      if (attendanceDoc.exists) {
        print('Attendance collection exists for swimmer');
        
        // Check attendance records
        final recordsQuery = await _firestore
            .collection('attendance')
            .doc(widget.swimmerId)
            .collection('records')
            .get();
        
        print('Number of attendance records: ${recordsQuery.docs.length}');
        for (var doc in recordsQuery.docs) {
          final data = doc.data();
          print('Record: ${data}');
        }
      } else {
        print('Attendance collection does not exist for swimmer');
      }
    } catch (e) {
      print('Error debugging guardian data: $e');
    }
  }

  double _calculatePercentage(List<QueryDocumentSnapshot> records) {
    if (records.isEmpty) return 0;
    final presentCount = records.where((doc) => doc['status'] == 'Present').length;
    return (presentCount / records.length) * 100;
  }

  List<BarChartGroupData> _buildBarChartData(List<QueryDocumentSnapshot> records) {
    final presentCount = records.where((doc) => doc['status'] == 'Present').length;
    final absentCount = records.where((doc) => doc['status'] == 'Absent').length;

    return [
      BarChartGroupData(
        x: 0,
        barRods: [
          BarChartRodData(
            toY: presentCount.toDouble(),
            color: Colors.green,
            width: 30,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      ),
      BarChartGroupData(
        x: 1,
        barRods: [
          BarChartRodData(
            toY: absentCount.toDouble(),
            color: Colors.red,
            width: 30,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.lightBlueAccent,
            Colors.lightBlueAccent.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: const Icon(
                  Icons.family_restroom,
                  size: 35,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.childName}\'s Attendance',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Guardian View',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButton<String>(
              value: selectedPeriod,
              dropdownColor: Colors.lightBlueAccent,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              underline: Container(),
              items: periods.map((String period) {
                return DropdownMenuItem<String>(
                  value: period,
                  child: Text(period),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedPeriod = newValue;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(List<QueryDocumentSnapshot> records) {
    final percentage = _calculatePercentage(records);
    final presentCount = records.where((doc) => doc['status'] == 'Present').length;
    final absentCount = records.where((doc) => doc['status'] == 'Absent').length;
    final totalSessions = records.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Attendance Rate',
                  '${percentage.toStringAsFixed(1)}%',
                  Colors.lightBlueAccent,
                  Icons.trending_up,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Total Sessions',
                  totalSessions.toString(),
                  Colors.blue,
                  Icons.calendar_today,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Present',
                  presentCount.toString(),
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Absent',
                  absentCount.toString(),
                  Colors.red,
                  Icons.cancel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard(List<QueryDocumentSnapshot> records) {
    if (records.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No attendance data available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: records.length.toDouble(),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.lightBlueAccent,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String label = group.x == 0 ? 'Present' : 'Absent';
                      final count = rod.toY.toInt();
                      final total = records.length;
                      final percent = ((count / total) * 100).toStringAsFixed(1);
                      return BarTooltipItem(
                        '$label: $count ($percent%)',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        switch (value.toInt()) {
                          case 0:
                            return const Text(
                              'Present',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            );
                          case 1:
                            return const Text(
                              'Absent',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            );
                          default:
                            return const Text('');
                        }
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _buildBarChartData(records),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 1,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList(List<QueryDocumentSnapshot> records) {
    if (records.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No attendance records found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final sortedRecords = records.toList()
      ..sort((a, b) {
        final tsA = a['timestamp'] as Timestamp?;
        final tsB = b['timestamp'] as Timestamp?;
        return tsB?.compareTo(tsA ?? Timestamp.now()) ?? 0;
      });

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Recent Attendance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedRecords.length,
            itemBuilder: (context, index) {
              final data = sortedRecords[index].data() as Map<String, dynamic>? ?? {};
              final timestamp = data['timestamp'] as Timestamp?;
              final date = timestamp?.toDate() ?? DateTime.now();
              final status = data['status'] ?? 'Unknown';
              final isPresent = status == 'Present';

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isPresent ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPresent ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isPresent ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPresent ? Icons.check : Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    DateFormat('EEEE, MMMM dd, yyyy').format(date),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat('hh:mm a').format(date),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPresent ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceStream = _firestore
        .collection('attendance')
        .doc(widget.swimmerId)
        .collection('records')
        .orderBy('timestamp', descending: true)
        .snapshots();

    // Debug: Print the swimmer ID being used
    print('=== DEBUG: Guardian Attendance Screen ===');
    print('Child ID: ${widget.childId}');
    print('Swimmer ID: ${widget.swimmerId}');
    print('Child Name: ${widget.childName}');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Child Attendance',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.lightBlueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: attendanceStream,
        builder: (context, snapshot) {
          // Debug: Print snapshot information
          print('=== DEBUG: Guardian StreamBuilder ===');
          print('Connection State: ${snapshot.connectionState}');
          print('Has Error: ${snapshot.hasError}');
          print('Error: ${snapshot.error}');
          print('Data: ${snapshot.data?.docs.length ?? 0} documents');
          
          if (snapshot.hasError) {
            print('Guardian Stream Error: ${snapshot.error}');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.lightBlueAccent),
                  SizedBox(height: 16),
                  Text(
                    'Loading attendance data...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading attendance data: ${snapshot.error}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          
          // Debug: Print each document
          print('=== DEBUG: Guardian Attendance Documents ===');
          for (int i = 0; i < docs.length; i++) {
            final data = docs[i].data() as Map<String, dynamic>? ?? {};
            print('Document $i: ${data}');
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(),
                _buildStatsCard(docs),
                _buildChartCard(docs),
                _buildAttendanceList(docs),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}