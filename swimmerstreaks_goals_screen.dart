import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

class SwimmerStreaksGoalsScreen extends StatefulWidget {
  const SwimmerStreaksGoalsScreen({super.key});

  @override
  State<SwimmerStreaksGoalsScreen> createState() => _SwimmerStreaksGoalsScreenState();
}

class _SwimmerStreaksGoalsScreenState extends State<SwimmerStreaksGoalsScreen> 
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _celebrateController;

  String swimmerId = '';
  String swimmerName = '';
  int currentStreak = 0;
  int longestStreak = 0;
  int totalWorkouts = 0;
  int gems = 0;
  int totalGemsEarned = 0;
  int level = 1;
  int experience = 0;
  int experienceToNextLevel = 100;

  List<Goal> goals = [];
  List<Workout> recentWorkouts = [];
  List<Achievement> achievements = [];
  List<WeeklyProgress> weeklyProgress = [];

  final TextEditingController _goalNameController = TextEditingController();
  final TextEditingController _goalTargetController = TextEditingController();
  final TextEditingController _workoutDistanceController = TextEditingController();
  final TextEditingController _workoutDurationController = TextEditingController();
  final TextEditingController _workoutNotesController = TextEditingController();

  GoalType? selectedGoalType;
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
    _celebrateController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  }

  Future<void> _initializeData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    swimmerId = user.uid;
    

    final profileDoc = await _firestore.collection('swimmers').doc(swimmerId).get();
    if (profileDoc.exists) {
      final profileData = profileDoc.data()!;
      swimmerName = profileData['name'] ?? 'Swimmer';
    }


    final streaksDoc = await _firestore.collection('swimmer_streaks').doc(swimmerId).get();
    if (streaksDoc.exists) {
      final data = streaksDoc.data()!;
      setState(() {
        currentStreak = data['currentStreak'] ?? 0;
        longestStreak = data['longestStreak'] ?? 0;
        totalWorkouts = data['totalWorkouts'] ?? 0;
        gems = data['gems'] ?? 0;
        totalGemsEarned = data['totalGemsEarned'] ?? 0;
        level = data['level'] ?? 1;
        experience = data['experience'] ?? 0;
        experienceToNextLevel = data['experienceToNextLevel'] ?? 100;
      });
    }


    final goalsSnapshot = await _firestore
        .collection('swimmer_streaks')
        .doc(swimmerId)// Generate weekly progress
        .collection('goals')
        .get();
    
    setState(() {
      goals = goalsSnapshot.docs.map((doc) => Goal.fromMap(doc.id, doc.data())).toList();
    });


    final workoutsSnapshot = await _firestore
        .collection('swimmer_streaks')
        .doc(swimmerId)
        .collection('workouts')
        .orderBy('date', descending: true)
        .limit(5)
        .get();
    
    setState(() {
      recentWorkouts = workoutsSnapshot.docs.map((doc) => Workout.fromMap(doc.id, doc.data())).toList();
    });


    _initializeAchievements();
    

    _generateWeeklyProgress();
    
    setState(() {
      isLoading = false;
    });
  }

  void _initializeAchievements() {
    achievements = [
      Achievement(
        id: 'first_workout',
        title: 'First Splash',
        description: 'Complete your first workout',
        icon: Icons.water_drop,
        gemsReward: 50,
        isUnlocked: totalWorkouts > 0,
        color: Colors.blue,
      ),
      Achievement(
        id: 'streak_3',
        title: 'Getting Started',
        description: 'Maintain a 3-day streak',
        icon: Icons.local_fire_department,
        gemsReward: 100,
        isUnlocked: currentStreak >= 3,
        color: Colors.orange,
      ),
      Achievement(
        id: 'streak_7',
        title: 'Week Warrior',
        description: 'Maintain a 7-day streak',
        icon: Icons.whatshot,
        gemsReward: 200,
        isUnlocked: currentStreak >= 7,
        color: Colors.red,
      ),
      Achievement(
        id: 'streak_14',
        title: 'Dedicated Swimmer',
        description: 'Maintain a 14-day streak',
        icon: Icons.emoji_events,
        gemsReward: 500,
        isUnlocked: currentStreak >= 14,
        color: Colors.purple,
      ),
      Achievement(
        id: 'level_5',
        title: 'Rising Star',
        description: 'Reach level 5',
        icon: Icons.star,
        gemsReward: 300,
        isUnlocked: level >= 5,
        color: Colors.amber,
      ),
    ];
  }

  void _generateWeeklyProgress() {
    final now = DateTime.now();
    weeklyProgress = List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      return WeeklyProgress(
        date: date,
        workouts: index % 3 == 0 ? 1 : 0, // Mock data - replace with real data
        distance: index % 2 == 0 ? 500.0 : 0.0,
      );
    });
  }

  Future<void> _saveData() async {
    await _firestore.collection('swimmer_streaks').doc(swimmerId).set({
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalWorkouts': totalWorkouts,
      'gems': gems,
      'totalGemsEarned': totalGemsEarned,
      'level': level,
      'experience': experience,
      'experienceToNextLevel': experienceToNextLevel,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _addWorkout() async {
    if (_workoutDistanceController.text.isEmpty || _workoutDurationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all workout details'), backgroundColor: Colors.red),
      );
      return;
    }

    final distance = double.tryParse(_workoutDistanceController.text) ?? 0;
    final duration = double.tryParse(_workoutDurationController.text) ?? 0;

    if (distance <= 0 || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid workout values'), backgroundColor: Colors.red),
      );
      return;
    }

    // Add workout to Firestore
    final workoutData = {
      'distance': distance,
      'duration': duration,
      'notes': _workoutNotesController.text,
      'date': FieldValue.serverTimestamp(),
      'gemsEarned': 10,
    };

    await _firestore
        .collection('swimmer_streaks')
        .doc(swimmerId)
        .collection('workouts')
        .add(workoutData);

    // Update streaks and progress
    setState(() {
      currentStreak++;
      totalWorkouts++;
      gems += 10;
      totalGemsEarned += 10;
      experience += 20;
      
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }

      // Check for level up
      if (experience >= experienceToNextLevel) {
        level++;
        experience -= experienceToNextLevel;
        experienceToNextLevel = (level * 100).toInt();
        _showLevelUpDialog();
      }

      // Add to recent workouts
      recentWorkouts.insert(0, Workout(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        distance: distance,
        duration: duration,
        notes: _workoutNotesController.text,
        date: DateTime.now(),
        gemsEarned: 10,
      ));

      if (recentWorkouts.length > 5) {
        recentWorkouts.removeLast();
      }
    });

    // Check for achievements
    _checkAchievements();

    // Clear form
    _workoutDistanceController.clear();
    _workoutDurationController.clear();
    _workoutNotesController.clear();

    await _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Workout added! +10 gems earned'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _checkAchievements() {
    _initializeAchievements();
    for (var achievement in achievements) {
      if (achievement.isUnlocked && !achievement.isClaimed) {
        _showAchievementDialog(achievement);
        break;
      }
    }
  }

  void _showLevelUpDialog() {
    _celebrateController.forward().then((_) => _celebrateController.reset());
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.amber, Colors.orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 60, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                'LEVEL UP!',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Congratulations! You reached level $level',
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
                  foregroundColor: Colors.orange,
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAchievementDialog(Achievement achievement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [achievement.color, achievement.color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(achievement.icon, size: 60, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                achievement.title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                achievement.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                '+${achievement.gemsReward} gems',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    gems += achievement.gemsReward;
                    totalGemsEarned += achievement.gemsReward;
                    achievement.isClaimed = true;
                  });
                  _saveData();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: achievement.color,
                ),
                child: const Text('Claim Reward'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addGoal() async {
    if (selectedGoalType == null || 
        _goalNameController.text.isEmpty || 
        _goalTargetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all goal details'), backgroundColor: Colors.red),
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

    final newGoal = Goal(
      id: '',
      name: _goalNameController.text,
      type: selectedGoalType!,
      target: target,
      current: 0,
      unit: _getUnitForGoalType(selectedGoalType!),
    );

    final docRef = await _firestore
        .collection('swimmer_streaks')
        .doc(swimmerId)
        .collection('goals')
        .add(newGoal.toMap());

    setState(() {
      goals.add(newGoal.copyWith(id: docRef.id));
    });

    // Clear form
    _goalNameController.clear();
    _goalTargetController.clear();
    selectedGoalType = null;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Goal added successfully!'), backgroundColor: Colors.green),
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

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    _celebrateController.dispose();
    _goalNameController.dispose();
    _goalTargetController.dispose();
    _workoutDistanceController.dispose();
    _workoutDurationController.dispose();
    _workoutNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E3A8A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text(
                'Loading your progress...',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                        _buildStatsCards(),
                        const SizedBox(height: 20),
                        _buildProgressChart(),
                        const SizedBox(height: 20),
                        _buildGoalsSection(),
                        const SizedBox(height: 20),
                        _buildRecentWorkouts(),
                        const SizedBox(height: 20),
                        _buildAchievements(),
                        const SizedBox(height: 20),
                        _buildAddWorkoutSection(),
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
                  'My Progress',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Welcome back, $swimmerName!',
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.diamond, color: Colors.white, size: 20),
                const SizedBox(width: 4),
                Text(
                  '$gems',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Current Streak',
            '$currentStreak days',
            Icons.local_fire_department,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Longest Streak',
            '$longestStreak days',
            Icons.whatshot,
            Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Total Workouts',
            '$totalWorkouts',
            Icons.fitness_center,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressChart() {
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
            'Weekly Progress',
            style: GoogleFonts.poppins(
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
                maxY: 1000,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        return Text(
                          days[value.toInt()],
                          style: GoogleFonts.poppins(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}m',
                          style: GoogleFonts.poppins(fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: weeklyProgress.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.distance,
                        color: Colors.blue,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsSection() {
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
                'My Goals',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                onPressed: _showAddGoalDialog,
                icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (goals.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.flag, size: 50, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    'No goals set yet',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _showAddGoalDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Add Your First Goal'),
                  ),
                ],
              ),
            )
          else
            ...goals.map((goal) => _buildGoalCard(goal)),
        ],
      ),
    );
  }

  Widget _buildGoalCard(Goal goal) {
    final progress = goal.target == 0 ? 0.0 : goal.current / goal.target;
    final isCompleted = progress >= 1.0;
    
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
                child: Text(
                  goal.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (isCompleted)
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
            ],
          ),
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
          Text(
            '${(progress * 100).toInt()}% Complete',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentWorkouts() {
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
            'Recent Workouts',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (recentWorkouts.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.fitness_center, size: 50, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    'No workouts yet',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          else
            ...recentWorkouts.map((workout) => _buildWorkoutCard(workout)),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(Workout workout) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.water_drop, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${workout.distance}m in ${workout.duration}min',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${workout.date.day}/${workout.date.month}/${workout.date.year}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (workout.notes.isNotEmpty)
                  Text(
                    workout.notes,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.diamond, color: Colors.amber, size: 20),
              Text(
                '+${workout.gemsEarned}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievements() {
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
            'Achievements',
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
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              final achievement = achievements[index];
              return _buildAchievementCard(achievement);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: achievement.isUnlocked ? achievement.color.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: achievement.isUnlocked ? achievement.color : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            achievement.icon,
            size: 40,
            color: achievement.isUnlocked ? achievement.color : Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            achievement.title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: achievement.isUnlocked ? Colors.black87 : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '+${achievement.gemsReward}',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.amber[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddWorkoutSection() {
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
            'Add Workout',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _workoutDistanceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Distance (m)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _workoutDurationController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Duration (min)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _workoutNotesController,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addWorkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Add Workout',
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

  void _showAddGoalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add New Goal',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              ),
              items: GoalType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedGoalType = value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _goalTargetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target Value',
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
              await _addGoal();
              Navigator.pop(context);
            },
            child: const Text('Add Goal'),
          ),
        ],
      ),
    );
  }
}

// Models
enum GoalType { distance, time, frequency, calories }

class Goal {
  final String id;
  final String name;
  final GoalType type;
  final double target;
  final double current;
  final String unit;

  Goal({
    required this.id,
    required this.name,
    required this.type,
    required this.target,
    required this.current,
    required this.unit,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type.name,
    'target': target,
    'current': current,
    'unit': unit,
  };

  factory Goal.fromMap(String id, Map<String, dynamic> map) => Goal(
    id: id,
    name: map['name'] ?? '',
    type: GoalType.values.firstWhere((e) => e.name == map['type']),
    target: (map['target'] as num).toDouble(),
    current: (map['current'] as num).toDouble(),
    unit: map['unit'] ?? '',
  );

  Goal copyWith({
    String? id,
    String? name,
    GoalType? type,
    double? target,
    double? current,
    String? unit,
  }) => Goal(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    target: target ?? this.target,
    current: current ?? this.current,
    unit: unit ?? this.unit,
  );
}

class Workout {
  final String id;
  final double distance;
  final double duration;
  final String notes;
  final DateTime date;
  final int gemsEarned;

  Workout({
    required this.id,
    required this.distance,
    required this.duration,
    required this.notes,
    required this.date,
    required this.gemsEarned,
  });

  Map<String, dynamic> toMap() => {
    'distance': distance,
    'duration': duration,
    'notes': notes,
    'date': date,
    'gemsEarned': gemsEarned,
  };

  factory Workout.fromMap(String id, Map<String, dynamic> map) => Workout(
    id: id,
    distance: (map['distance'] as num).toDouble(),
    duration: (map['duration'] as num).toDouble(),
    notes: map['notes'] ?? '',
    date: (map['date'] as Timestamp).toDate(),
    gemsEarned: map['gemsEarned'] ?? 0,
  );
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int gemsReward;
  final bool isUnlocked;
  final Color color;
  bool isClaimed;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.gemsReward,
    required this.isUnlocked,
    required this.color,
    this.isClaimed = false,
  });
}

class WeeklyProgress {
  final DateTime date;
  final int workouts;
  final double distance;

  WeeklyProgress({
    required this.date,
    required this.workouts,
    required this.distance,
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





