import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

class CoachStreaksGoalsScreen extends StatefulWidget {
  const CoachStreaksGoalsScreen({super.key});

  @override
  State<CoachStreaksGoalsScreen> createState() => _CoachStreaksGoalsScreenState();
}

class _CoachStreaksGoalsScreenState extends State<CoachStreaksGoalsScreen> 
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late AnimationController _waveController;
  late AnimationController _pulseController;

  String coachId = '';
  String coachName = '';
  List<Swimmer> swimmers = [];
  List<AssignedGoal> assignedGoals = [];
  List<SwimmerProgress> swimmerProgress = [];
  List<GoalTemplate> goalTemplates = [];

  final TextEditingController _swimmerNameController = TextEditingController();
  final TextEditingController _goalNameController = TextEditingController();
  final TextEditingController _goalTargetController = TextEditingController();
  final TextEditingController _goalDescriptionController = TextEditingController();

  GoalType? selectedGoalType;
  Swimmer? selectedSwimmer;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeData();
  }

  void _initializeControllers() {
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  Future<void> _initializeData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    coachId = user.uid;
    
    // Fetch coach profile
    final profileDoc = await _firestore.collection('coaches').doc(coachId).get();
    if (profileDoc.exists) {
      final profileData = profileDoc.data()!;
      coachName = profileData['name'] ?? 'Coach';
    }

    // Fetch swimmers assigned to this coach
    final swimmersSnapshot = await _firestore
        .collection('coach_swimmers')
        .where('coachId', isEqualTo: coachId)
        .get();
    
    final swimmerIds = swimmersSnapshot.docs.map((doc) => doc.data()['swimmerId'] as String).toList();
    
    // Fetch swimmer details
    final swimmerDocs = await Future.wait(
      swimmerIds.map((id) => _firestore.collection('swimmers').doc(id).get())
    );
    
    setState(() {
      swimmers = swimmerDocs
          .where((doc) => doc.exists)
          .map((doc) => Swimmer.fromMap(doc.id, doc.data()!))
          .toList();
    });

    // Fetch assigned goals
    final goalsSnapshot = await _firestore
        .collection('coach_goals')
        .where('coachId', isEqualTo: coachId)
        .get();
    
    setState(() {
      assignedGoals = goalsSnapshot.docs.map((doc) => AssignedGoal.fromMap(doc.id, doc.data())).toList();
    });

    // Initialize goal templates
    _initializeGoalTemplates();
    
    // Generate swimmer progress
    _generateSwimmerProgress();
    
    // Screen loads instantly
  }

  void _initializeGoalTemplates() {
    goalTemplates = [
      GoalTemplate(
        name: 'Distance Challenge',
        type: GoalType.distance,
        description: 'Swim a specific distance',
        icon: Icons.track_changes,
        color: Colors.blue,
      ),
      GoalTemplate(
        name: 'Time Challenge',
        type: GoalType.time,
        description: 'Swim for a specific duration',
        icon: Icons.timer,
        color: Colors.green,
      ),
      GoalTemplate(
        name: 'Frequency Challenge',
        type: GoalType.frequency,
        description: 'Complete workouts regularly',
        icon: Icons.repeat,
        color: Colors.orange,
      ),
      GoalTemplate(
        name: 'Calorie Burn',
        type: GoalType.calories,
        description: 'Burn specific calories',
        icon: Icons.local_fire_department,
        color: Colors.red,
      ),
    ];
  }

  void _generateSwimmerProgress() {
    swimmerProgress = swimmers.map((swimmer) {
      final swimmerGoals = assignedGoals.where((g) => g.swimmerId == swimmer.id).toList();
      final completedGoals = swimmerGoals.where((g) => g.isCompleted).length;
      final totalGoals = swimmerGoals.length;
      
      return SwimmerProgress(
        swimmer: swimmer,
        totalGoals: totalGoals,
        completedGoals: completedGoals,
        completionRate: totalGoals > 0 ? completedGoals / totalGoals : 0.0,
      );
    }).toList();
  }

  Future<void> _assignGoal() async {
    if (selectedSwimmer == null || 
        selectedGoalType == null || 
        _goalNameController.text.isEmpty || 
        _goalTargetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields'), backgroundColor: Colors.red),
      );
      return;
    }

    final target = double.tryParse(_goalTargetController.text);
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid target'), backgroundColor: Colors.red),
      );
      return;
    }

    final newGoal = AssignedGoal(
      id: '',
      coachId: coachId,
      swimmerId: selectedSwimmer!.id,
      swimmerName: selectedSwimmer!.name,
      name: _goalNameController.text,
      description: _goalDescriptionController.text,
      type: selectedGoalType!,
      target: target,
      current: 0,
      unit: _getUnitForGoalType(selectedGoalType!),
      isCompleted: false,
      assignedDate: DateTime.now(),
    );

    final docRef = await _firestore.collection('coach_goals').add(newGoal.toMap());

    setState(() {
      assignedGoals.add(newGoal.copyWith(id: docRef.id));
      _generateSwimmerProgress();
    });

    // Clear form
    _goalNameController.clear();
    _goalTargetController.clear();
    _goalDescriptionController.clear();
    selectedSwimmer = null;
    selectedGoalType = null;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Goal assigned successfully!'), backgroundColor: Colors.green),
    );
  }

  String _getUnitForGoalType(GoalType type) {
    switch (type) {
      case GoalType.distance:
        return 'meters';
      case GoalType.time:
        return 'minutes';
      case GoalType.frequency:
        return 'workouts';
      case GoalType.calories:
        return 'calories';
    }
  }

  Future<void> _updateGoalProgress(AssignedGoal goal, double newProgress) async {
    final updatedGoal = goal.copyWith(current: newProgress, isCompleted: newProgress >= goal.target);
    
    await _firestore
        .collection('coach_goals')
        .doc(goal.id)
        .update(updatedGoal.toMap());

    setState(() {
      final index = assignedGoals.indexWhere((g) => g.id == goal.id);
      if (index != -1) {
        assignedGoals[index] = updatedGoal;
      }
      _generateSwimmerProgress();
    });

    if (updatedGoal.isCompleted && !goal.isCompleted) {
      _showGoalCompletedDialog(updatedGoal);
    }
  }

  void _showGoalCompletedDialog(AssignedGoal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.green, Colors.lightGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, size: 60, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                'Goal Completed!',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${goal.swimmerName} completed: ${goal.name}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green,
                ),
                child: const Text('Great!'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    _swimmerNameController.dispose();
    _goalNameController.dispose();
    _goalTargetController.dispose();
    _goalDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.lightBlueAccent,
      body: Stack(
        children: [
          // Animated background
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: WaterWavePainter(
              animation: _waveController,
              waveColor: Colors.blue.withOpacity(0.3),
              waveHeight: 15,
              baseHeight: 0.8,
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCoachInfo(),
                        const SizedBox(height: 20),
                        _buildSwimmerProgress(),
                        const SizedBox(height: 20),
                        _buildGoalTemplates(),
                        const SizedBox(height: 20),
                        _buildAssignedGoals(),
                        const SizedBox(height: 20),
                        _buildAddGoalSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Goals Management',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Set and track swimmer goals',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${swimmers.length} Swimmers',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.sports,
              size: 30,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coachName,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Swimming Coach',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Managing ${swimmers.length} swimmers',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwimmerProgress() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Swimmer Progress',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (swimmers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: DropdownButton<Swimmer>(
                    value: selectedSwimmer,
                    hint: Text(
                      'Select Swimmer',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue[700]),
                    ),
                    underline: Container(),
                    items: swimmers.map((swimmer) {
                      return DropdownMenuItem<Swimmer>(
                        value: swimmer,
                        child: Text(
                          swimmer.name,
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue[700]),
                        ),
                      );
                    }).toList(),
                    onChanged: (Swimmer? value) {
                      setState(() {
                        selectedSwimmer = value;
                      });
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (swimmers.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.people, size: 50, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    'No swimmers assigned yet',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _showAddSwimmerDialog,
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Add Swimmer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            )
          else if (selectedSwimmer != null)
            _buildSelectedSwimmerProgress(selectedSwimmer!)
          else
            ...swimmerProgress.map((progress) => _buildSwimmerProgressCard(progress)),
        ],
      ),
    );
  }

  Widget _buildSwimmerProgressCard(SwimmerProgress progress) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              Icons.person,
              color: Colors.blue[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress.swimmer.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${progress.completedGoals}/${progress.totalGoals} goals completed',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress.completionRate,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  minHeight: 6,
                ),
                Text(
                  '${(progress.completionRate * 100).toInt()}% completion rate',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                selectedSwimmer = progress.swimmer;
              });
            },
            icon: Icon(Icons.visibility, color: Colors.blue[600], size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedSwimmerProgress(Swimmer swimmer) {
    final swimmerGoals = assignedGoals.where((goal) => goal.swimmerId == swimmer.id).toList();
    final completedGoals = swimmerGoals.where((goal) => goal.isCompleted).length;
    final totalGoals = swimmerGoals.length;
    final completionRate = totalGoals > 0 ? completedGoals / totalGoals : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.blue[700],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      swimmer.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${completedGoals}/${totalGoals} goals completed',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedSwimmer = null;
                  });
                },
                icon: Icon(Icons.close, color: Colors.grey[600], size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: completionRate,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            '${(completionRate * 100).toInt()}% completion rate',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.blue[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          if (swimmerGoals.isNotEmpty) ...[
            Text(
              'Assigned Goals:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...swimmerGoals.map((goal) => _buildGoalItem(goal)),
          ] else ...[
            Text(
              'No goals assigned yet',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalItem(AssignedGoal goal) {
    final progress = goal.current / goal.target;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  goal.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: goal.isCompleted ? Colors.green[100] : Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  goal.isCompleted ? 'Completed' : 'In Progress',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: goal.isCompleted ? Colors.green[700] : Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${goal.current.toStringAsFixed(1)} / ${goal.target.toStringAsFixed(1)} ${goal.unit}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              goal.isCompleted ? Colors.green : Colors.orange,
            ),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  void _showAddSwimmerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Swimmer',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _swimmerNameController,
              decoration: const InputDecoration(
                labelText: 'Swimmer Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_swimmerNameController.text.isNotEmpty) {
                await _addSwimmer();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSwimmer() async {
    final swimmerData = {
      'name': _swimmerNameController.text,
      'coachId': coachId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore.collection('swimmers').add(swimmerData);
    
    // Add to coach_swimmers collection
    await _firestore.collection('coach_swimmers').add({
      'coachId': coachId,
      'swimmerId': docRef.id,
      'assignedAt': FieldValue.serverTimestamp(),
    });

    // Add to swimmers list
    final newSwimmer = Swimmer(
      id: docRef.id,
      name: _swimmerNameController.text,
      email: '${_swimmerNameController.text.toLowerCase().replaceAll(' ', '')}@swimsphere.com',
      age: 12,
      level: 'Beginner',
    );

    setState(() {
      swimmers.add(newSwimmer);
      _swimmerNameController.clear();
    });

    final swimmerName = _swimmerNameController.text;
    _swimmerNameController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Swimmer $swimmerName added successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildGoalTemplates() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Goal Templates',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.4,
            ),
            itemCount: goalTemplates.length,
            itemBuilder: (context, index) {
              final template = goalTemplates[index];
              return _buildGoalTemplateCard(template);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGoalTemplateCard(GoalTemplate template) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: template.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: template.color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            template.icon,
            size: 32,
            color: template.color,
          ),
          const SizedBox(height: 6),
          Text(
            template.name,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              template.description,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedGoals() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assigned Goals',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (assignedGoals.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.flag, size: 50, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    'No goals assigned yet',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          else
            ...assignedGoals.map((goal) => _buildAssignedGoalCard(goal)),
        ],
      ),
    );
  }

  Widget _buildAssignedGoalCard(AssignedGoal goal) {
    final progress = goal.target == 0 ? 0.0 : goal.current / goal.target;
    final isCompleted = goal.isCompleted;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.green : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Assigned to: ${goal.swimmerName}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
            ],
          ),
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              goal.description,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${goal.current.toStringAsFixed(1)} / ${goal.target.toStringAsFixed(1)} ${goal.unit}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              isCompleted ? Colors.green : Colors.blue,
            ),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% Complete',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              if (!isCompleted)
                ElevatedButton(
                  onPressed: () => _showUpdateProgressDialog(goal),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('Update'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUpdateProgressDialog(AssignedGoal goal) {
    final progressController = TextEditingController(text: goal.current.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Update Progress',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${goal.swimmerName} - ${goal.name}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: progressController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Current Progress (${goal.unit})',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newProgress = double.tryParse(progressController.text) ?? goal.current;
              _updateGoalProgress(goal, newProgress);
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddGoalSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assign New Goal',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (swimmers.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No swimmers available. Add swimmers first.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<Swimmer>(
              value: selectedSwimmer,
              decoration: const InputDecoration(
                labelText: 'Select Swimmer',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              items: swimmers.map((swimmer) {
                return DropdownMenuItem(
                  value: swimmer,
                  child: Text(swimmer.name),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedSwimmer = value),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _goalNameController,
            decoration: const InputDecoration(
              labelText: 'Goal Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<GoalType>(
            value: selectedGoalType,
            decoration: const InputDecoration(
              labelText: 'Goal Type',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.flag),
            ),
            items: GoalType.values.map((type) {
              String label;
              switch (type) {
                case GoalType.distance:
                  label = 'Distance (meters)';
                  break;
                case GoalType.time:
                  label = 'Time (minutes)';
                  break;
                case GoalType.frequency:
                  label = 'Frequency (workouts)';
                  break;
                case GoalType.calories:
                  label = 'Calories';
                  break;
              }
              return DropdownMenuItem(
                value: type,
                child: Text(label),
              );
            }).toList(),
            onChanged: (value) => setState(() => selectedGoalType = value),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _goalTargetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Target Value ${selectedGoalType != null ? "(${_getUnitForGoalType(selectedGoalType!)})" : ""}',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.track_changes),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _goalDescriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _assignGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Assign Goal',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Models
enum GoalType { distance, time, frequency, calories }

class Swimmer {
  final String id;
  final String name;
  final String email;
  final int age;
  final String level;

  Swimmer({
    required this.id,
    required this.name,
    required this.email,
    required this.age,
    required this.level,
  });

  factory Swimmer.fromMap(String id, Map<String, dynamic> map) => Swimmer(
    id: id,
    name: map['name'] ?? '',
    email: map['email'] ?? '',
    age: map['age'] ?? 0,
    level: map['level'] ?? 'Beginner',
  );
}

class AssignedGoal {
  final String id;
  final String coachId;
  final String swimmerId;
  final String swimmerName;
  final String name;
  final String description;
  final GoalType type;
  final double target;
  final double current;
  final String unit;
  final bool isCompleted;
  final DateTime assignedDate;

  AssignedGoal({
    required this.id,
    required this.coachId,
    required this.swimmerId,
    required this.swimmerName,
    required this.name,
    required this.description,
    required this.type,
    required this.target,
    required this.current,
    required this.unit,
    required this.isCompleted,
    required this.assignedDate,
  });

  Map<String, dynamic> toMap() => {
    'coachId': coachId,
    'swimmerId': swimmerId,
    'swimmerName': swimmerName,
    'name': name,
    'description': description,
    'type': type.name,
    'target': target,
    'current': current,
    'unit': unit,
    'isCompleted': isCompleted,
    'assignedDate': assignedDate,
  };

  factory AssignedGoal.fromMap(String id, Map<String, dynamic> map) => AssignedGoal(
    id: id,
    coachId: map['coachId'] ?? '',
    swimmerId: map['swimmerId'] ?? '',
    swimmerName: map['swimmerName'] ?? '',
    name: map['name'] ?? '',
    description: map['description'] ?? '',
    type: GoalType.values.firstWhere((e) => e.name == map['type']),
    target: (map['target'] as num).toDouble(),
    current: (map['current'] as num).toDouble(),
    unit: map['unit'] ?? '',
    isCompleted: map['isCompleted'] ?? false,
    assignedDate: (map['assignedDate'] as Timestamp).toDate(),
  );

  AssignedGoal copyWith({
    String? id,
    String? coachId,
    String? swimmerId,
    String? swimmerName,
    String? name,
    String? description,
    GoalType? type,
    double? target,
    double? current,
    String? unit,
    bool? isCompleted,
    DateTime? assignedDate,
  }) => AssignedGoal(
    id: id ?? this.id,
    coachId: coachId ?? this.coachId,
    swimmerId: swimmerId ?? this.swimmerId,
    swimmerName: swimmerName ?? this.swimmerName,
    name: name ?? this.name,
    description: description ?? this.description,
    type: type ?? this.type,
    target: target ?? this.target,
    current: current ?? this.current,
    unit: unit ?? this.unit,
    isCompleted: isCompleted ?? this.isCompleted,
    assignedDate: assignedDate ?? this.assignedDate,
  );
}

class SwimmerProgress {
  final Swimmer swimmer;
  final int totalGoals;
  final int completedGoals;
  final double completionRate;

  SwimmerProgress({
    required this.swimmer,
    required this.totalGoals,
    required this.completedGoals,
    required this.completionRate,
  });
}

class GoalTemplate {
  final String name;
  final GoalType type;
  final String description;
  final IconData icon;
  final Color color;

  GoalTemplate({
    required this.name,
    required this.type,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class WaterWavePainter extends CustomPainter {
  final Animation<double> animation;
  final Color waveColor;
  final double waveHeight;
  final double baseHeight;

  WaterWavePainter({
    required this.animation,
    required this.waveColor,
    required this.waveHeight,
    required this.baseHeight,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = waveColor;
    final path = Path();
    final baseY = size.height * baseHeight;
    
    path.moveTo(0, baseY);
    for (double x = 0; x <= size.width; x++) {
      double y = baseY + 
          math.sin((x / size.width * 2 * math.pi) + (animation.value * 2 * math.pi)) * waveHeight;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
