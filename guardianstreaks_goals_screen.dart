import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class GuardianStreaksGoalsScreen extends StatefulWidget {
  final String childId;
  final String childName;

  const GuardianStreaksGoalsScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<GuardianStreaksGoalsScreen> createState() =>
      _GuardianStreaksGoalsScreenState();
}

class _GuardianStreaksGoalsScreenState extends State<GuardianStreaksGoalsScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final AnimationController _waveController;
  late final AnimationController _pulseController;
  late final AnimationController _fadeController;
  String childId = '';
  String childName = '';

  int currentStreak = 0;
  int longestStreak = 0;
  int totalWorkouts = 0;
  int gems = 0;
  int level = 1;
  int experience = 0;
  int experienceToNextLevel = 100;

  List<Goal> childGoals = [];
  List<Workout> recentWorkouts = [];
  List<Achievement> achievements = [];
  List<WeeklyProgress> weeklyProgress = [];
  List<MonthlyStats> monthlyStats = [];

  // Achievements claimed locally to avoid duplicate writes
  final Set<String> claimedAchievementIds = {};

  // Toggle whether to use mock data if Firestore returns empty
  final bool _useMockDataIfEmpty = true;

  // Defensive: keep track whether initial fetch was attempted
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    childId = widget.childId;
    childName = widget.childName;
    _initializeControllers();
    // NOTE: we intentionally do NOT show a blocking loading screen. We
    // immediately render and fetch data in the background; fallbacks and
    // mock data ensure UI is populated.
    _initializeData();
  }

  void _initializeControllers() {
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  Future<void> _initializeData() async {
    // fetch data but do not block UI
    try {
      _initialized = true;

      // 1) Fetch primary stats doc
      final streaksRef = _firestore.collection('swimmer_streaks').doc(childId);
      final streaksDoc = await streaksRef.get();

      if (streaksDoc.exists) {
        final data = streaksDoc.data()!;
        currentStreak = (data['currentStreak'] ?? 0) as int;
        longestStreak = (data['longestStreak'] ?? 0) as int;
        totalWorkouts = (data['totalWorkouts'] ?? 0) as int;
        gems = (data['gems'] ?? 0) as int;
        level = (data['level'] ?? 1) as int;
        experience = (data['experience'] ?? 0) as int;
        experienceToNextLevel = (data['experienceToNextLevel'] ?? 100) as int;
      }

      // 2) Goals
      try {
        final goalsSnapshot = await streaksRef.collection('goals').get();
        childGoals = goalsSnapshot.docs
            .map((d) => Goal.fromMap(d.id, d.data()))
            .toList();
      } catch (e) {
        // if goals collection missing or not accessible, leave empty
        childGoals = [];
      }

      // 3) Workouts
      try {
        final workoutsSnapshot = await streaksRef
            .collection('workouts')
            .orderBy('date', descending: true)
            .limit(50)
            .get();

        recentWorkouts = workoutsSnapshot.docs
            .map((d) => Workout.fromMap(d.id, d.data()))
            .toList();
      } catch (e) {
        recentWorkouts = [];
      }

      // 4) Apply mock data if empty
      if (_useMockDataIfEmpty) {
        _applyMockDataIfEmpty();
      }

      // 5) Achievements (computed locally)
      _initializeAchievements();

      // 6) Aggregations
      _generateWeeklyProgress();
      _generateMonthlyStats();

      // ensure UI updates
      if (mounted) setState(() {});
    } catch (e, st) {
      debugPrint('Error loading data: $e\n$st');
      // If there's a read error, fallback to mock
      if (_useMockDataIfEmpty) {
        _applyMockDataFallback();
        _initializeAchievements();
        _generateWeeklyProgress();
        _generateMonthlyStats();
        if (mounted) setState(() {});
      }
    }
  }

  void _applyMockDataIfEmpty() {
    if (recentWorkouts.isEmpty) {
      recentWorkouts = List.generate(10, (i) {
        final daysAgo = i * 2;
        final date = DateTime.now().subtract(Duration(days: daysAgo));
        return Workout(
          id: 'mock_w_$i',
          distance: (150 + i * 100).toDouble(),
          duration: (12 + i * 3).toDouble(),
          notes: i % 2 == 0 ? 'Focus on kicks' : 'Drills: breathing',
          date: date,
          gemsEarned: 5 + i,
        );
      });
      totalWorkouts = recentWorkouts.length;
    }

    if (childGoals.isEmpty) {
      childGoals = [
        Goal(
          id: 'g1',
          name: 'Swim 2 km this month',
          type: GoalType.distance,
          target: 2000,
          current: 600,
          unit: 'm',
        ),
        Goal(
          id: 'g2',
          name: '5 workouts this week',
          type: GoalType.frequency,
          target: 5,
          current: 2,
          unit: 'sessions',
        ),
      ];
    }
  }

  void _applyMockDataFallback() {
    currentStreak = 0;
    longestStreak = 0;
    totalWorkouts = 0;
    gems = 0;
    level = 1;
    experience = 0;
    experienceToNextLevel = 100;

    childGoals = [
      Goal(
        id: 'fallback_g1',
        name: 'Start swimming',
        type: GoalType.frequency,
        target: 3,
        current: 0,
        unit: 'sessions',
      ),
    ];

    recentWorkouts = [];
  }

  void _initializeAchievements() {
    final double totalDistance = _calculateTotalDistance();
    achievements = [
      Achievement(
        id: 'first_workout',
        title: 'First Splash',
        description: 'Completed first workout',
        icon: Icons.water_drop,
        gemsReward: 50,
        isUnlocked: totalWorkouts > 0,
        color: Colors.blue,
      ),
      Achievement(
        id: 'streak_3',
        title: 'Getting Started',
        description: '3-day streak achieved',
        icon: Icons.local_fire_department,
        gemsReward: 100,
        isUnlocked: currentStreak >= 3,
        color: Colors.orange,
      ),
      Achievement(
        id: 'streak_7',
        title: 'Week Warrior',
        description: '7-day streak achieved',
        icon: Icons.whatshot,
        gemsReward: 200,
        isUnlocked: currentStreak >= 7,
        color: Colors.red,
      ),
      Achievement(
        id: 'streak_14',
        title: 'Dedicated Swimmer',
        description: '14-day streak achieved',
        icon: Icons.emoji_events,
        gemsReward: 500,
        isUnlocked: currentStreak >= 14,
        color: Colors.purple,
      ),
      Achievement(
        id: 'level_5',
        title: 'Rising Star',
        description: 'Reached level 5',
        icon: Icons.star,
        gemsReward: 300,
        isUnlocked: level >= 5,
        color: Colors.amber,
      ),
      Achievement(
        id: 'distance_10k',
        title: 'Distance Champion',
        description: 'Swam 10km total',
        icon: Icons.track_changes,
        gemsReward: 400,
        isUnlocked: totalDistance >= 10000,
        color: Colors.green,
      ),
    ];
  }

  double _calculateTotalDistance() {
    return recentWorkouts.fold(0.0, (sum, w) => sum + w.distance);
  }

  void _generateWeeklyProgress() {
    final now = DateTime.now();
    weeklyProgress = List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      final dayWorkouts = recentWorkouts.where((w) =>
      w.date.year == date.year &&
          w.date.month == date.month &&
          w.date.day == date.day);
      final workouts = dayWorkouts.length;
      final distance = dayWorkouts.fold(0.0, (s, w) => s + w.distance);
      return WeeklyProgress(date: date, workouts: workouts, distance: distance);
    });
  }

  void _generateMonthlyStats() {
    final now = DateTime.now();
    monthlyStats = List.generate(6, (index) {
      final month = DateTime(now.year, now.month - (5 - index), 1);
      final monthWorkouts = recentWorkouts.where(
              (w) => w.date.year == month.year && w.date.month == month.month);
      final totalWorkouts = monthWorkouts.length;
      final totalDistance = monthWorkouts.fold(0.0, (s, w) => s + w.distance);
      final totalDuration = monthWorkouts.fold(0.0, (s, w) => s + w.duration);
      return MonthlyStats(
        month: month,
        totalWorkouts: totalWorkouts,
        totalDistance: totalDistance,
        totalDuration: totalDuration,
      );
    });
  }

  Future<void> _claimAchievement(Achievement ach) async {
    if (!ach.isUnlocked) return;
    if (claimedAchievementIds.contains(ach.id)) return;

    setState(() {
      claimedAchievementIds.add(ach.id);
    });

    // Optimistic UI: add gems locally
    setState(() {
      gems += ach.gemsReward;
    });

    // Attempt to write claim to Firestore (optional)
    try {
      final docRef = _firestore
          .collection('swimmer_streaks')
          .doc(childId)
          .collection('claimed_achievements')
          .doc(ach.id);

      await docRef.set({
        'claimedAt': FieldValue.serverTimestamp(),
        'gemsReward': ach.gemsReward,
      });

      final streakDocRef = _firestore.collection('swimmer_streaks').doc(childId);
      await streakDocRef.set({'gems': gems}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to claim achievement: $e');
      // Rollback optimistic if write failed
      setState(() {
        claimedAchievementIds.remove(ach.id);
        gems = (gems - ach.gemsReward).clamp(0, 999999);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to claim achievement. Try again later.'),
        ));
      }
    }
  }

  Future<void> _refresh() async {
    await _initializeData();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlueAccent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: WaterWavePainter(
                  animation: _waveController,
                  waveColor: Colors.blue.withOpacity(0.20),
                  waveHeight: 18,
                  baseHeight: 0.78,
                ),
              ),
            ),
            RefreshIndicator(
              onRefresh: _refresh,
              color: Colors.white,
              backgroundColor: Colors.lightBlueAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    FadeTransition(
                      opacity: _fadeController,
                      child: Column(
                        children: [
                          _buildChildInfo(),
                          const SizedBox(height: 16),
                          _buildStatsCards(),
                          const SizedBox(height: 16),
                          _buildProgressChartSafe(),
                          const SizedBox(height: 16),
                          _buildGoalsSection(),
                          const SizedBox(height: 16),
                          _buildRecentWorkouts(),
                          const SizedBox(height: 16),
                          _buildAchievementsSection(),
                          const SizedBox(height: 16),
                          _buildMonthlyStats(),
                          const SizedBox(height: 24),
                        ],
                      ),
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

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Child\'s Progress',
                  style: GoogleFonts.poppins(
                      fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Monitoring $childName\'s swimming journey',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ),
        _buildGemsBadge(),
      ],
    );
  }

  Widget _buildGemsBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.diamond, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            '$gems',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue[100],
            child: Icon(Icons.person, size: 32, color: Colors.blue[800]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(childName,
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
                const SizedBox(height: 6),
                Text('Level $level Swimmer',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700])),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: experienceToNextLevel > 0
                      ? (experience / experienceToNextLevel).clamp(0.0, 1.0)
                      : 0.0,
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 6),
                Text('$experience / $experienceToNextLevel XP',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
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
            title: 'Current Streak',
            value: '$currentStreak days',
            icon: Icons.local_fire_department,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            title: 'Longest Streak',
            value: '$longestStreak days',
            icon: Icons.whatshot,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            title: 'Total Workouts',
            value: '$totalWorkouts',
            icon: Icons.fitness_center,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 6),
          Text(title, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildProgressChartSafe() {
    final safeWeekly = weeklyProgress;
    final maxDistance = safeWeekly.isEmpty
        ? 200.0
        : (safeWeekly.map((p) => p.distance).fold<double>(0.0, (a, b) => a > b ? a : b) + 50.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Week\'s Activity',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxDistance,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}m',
                            style: GoogleFonts.poppins(fontSize: 10));
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          final idx = value.toInt();
                          final label = (idx >= 0 && idx < days.length) ? days[idx] : '';
                          return Text(label, style: GoogleFonts.poppins(fontSize: 12));
                        }),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barGroups: List.generate(7, (i) {
                  final p = safeWeekly.length > i ? safeWeekly[i] : WeeklyProgress(date: DateTime.now(), workouts: 0, distance: 0.0);
                  final barColor = p.workouts > 0 ? Colors.blue : Colors.grey.shade300;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: p.distance,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        color: barColor,
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Goals',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (childGoals.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.flag, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('No goals set yet', style: GoogleFonts.poppins(color: Colors.grey[700])),
                ],
              ),
            )
          else
            Column(
              children: childGoals.map((g) => _buildGoalCard(g)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(Goal g) {
    final progress = g.target == 0 ? 0.0 : (g.current / g.target).clamp(0.0, 1.0);
    final isComplete = progress >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isComplete ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isComplete ? Colors.green : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(g.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
              if (isComplete) const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
          const SizedBox(height: 8),
          Text('${g.current.toStringAsFixed(1)} / ${g.target.toStringAsFixed(1)} ${g.unit}',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700])),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor:
            AlwaysStoppedAnimation<Color>(isComplete ? Colors.green : Colors.blue),
          ),
          const SizedBox(height: 6),
          Text('${(progress * 100).toInt()}% Complete', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildRecentWorkouts() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Workouts',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (recentWorkouts.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.fitness_center, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('No workouts yet', style: GoogleFonts.poppins(color: Colors.grey[700])),
                ],
              ),
            )
          else
            Column(
              children: recentWorkouts.take(6).map((w) => _buildWorkoutCard(w)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(Workout w) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.water_drop, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${w.distance.toStringAsFixed(0)}m in ${w.duration.toStringAsFixed(0)}min',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${w.date.day}/${w.date.month}/${w.date.year}',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                if (w.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(w.notes, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.diamond, color: Colors.amber),
              const SizedBox(height: 4),
              Text('+${w.gemsEarned}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Achievements', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: achievements.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              final a = achievements[index];
              return _buildAchievementCard(a);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(Achievement a) {
    final isClaimed = claimedAchievementIds.contains(a.id);
    final unlocked = a.isUnlocked;
    final borderColor = unlocked ? a.color : Colors.grey.shade300;
    final bgColor = unlocked ? a.color.withOpacity(0.08) : Colors.grey.shade100;

    return GestureDetector(
      onTap: unlocked && !isClaimed ? () => _onAchievementTap(a) : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(a.icon, size: 36, color: unlocked ? a.color : Colors.grey[400]),
            const SizedBox(height: 8),
            Text(a.title,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700, color: unlocked ? Colors.black87 : Colors.grey[700]),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('+${a.gemsReward}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.amber[700])),
            const SizedBox(height: 6),
            if (!unlocked) Text('Locked', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
            if (unlocked && isClaimed) Text('Claimed', style: GoogleFonts.poppins(fontSize: 12, color: Colors.green)),
          ],
        ),
      ),
    );
  }

  void _onAchievementTap(Achievement a) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Claim Achievement', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text('Claim "${a.title}" for +${a.gemsReward} gems?', style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _claimAchievement(a);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Claimed ${a.title}!')));
                }
              },
              child: Text('Claim', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthlyStats() {
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Progress', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (monthlyStats.isEmpty)
            Center(child: Text('No monthly data', style: GoogleFonts.poppins(color: Colors.grey[700])))
          else
            Column(
              children: monthlyStats.map((m) => _buildMonthlyStatCard(m, monthNames)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStatCard(MonthlyStats stat, List<String> monthNames) {
    final index = stat.month.month - 1;
    final monthLabel = (index >= 0 && index < 12) ? monthNames[index] : '${stat.month.month}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.calendar_today, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$monthLabel ${stat.month.year}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${stat.totalWorkouts} workouts • ${stat.totalDistance.toStringAsFixed(0)}m • ${stat.totalDuration.toStringAsFixed(0)}min',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- MODELS --------------------

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

  factory Goal.fromMap(String id, Map<String, dynamic> map) {
    GoalType t = GoalType.distance;
    try {
      t = GoalType.values.firstWhere((e) => e.name == (map['type'] ?? 'distance'));
    } catch (_) {}
    return Goal(
      id: id,
      name: map['name'] ?? '',
      type: t,
      target: (map['target'] as num?)?.toDouble() ?? 0.0,
      current: (map['current'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
    );
  }
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

  factory Workout.fromMap(String id, Map<String, dynamic> map) {
    DateTime date;
    final d = map['date'];
    if (d is Timestamp) {
      date = d.toDate();
    } else if (d is DateTime) {
      date = d;
    } else if (d is String) {
      try {
        date = DateTime.parse(d);
      } catch (_) {
        date = DateTime.now();
      }
    } else {
      date = DateTime.now();
    }

    return Workout(
      id: id,
      distance: (map['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (map['duration'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] ?? '',
      date: date,
      gemsEarned: (map['gemsEarned'] as int?) ?? (map['gems'] as int?) ?? 0,
    );
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int gemsReward;
  final bool isUnlocked;
  final Color color;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.gemsReward,
    required this.isUnlocked,
    required this.color,
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

class MonthlyStats {
  final DateTime month;
  final int totalWorkouts;
  final double totalDistance;
  final double totalDuration;

  MonthlyStats({
    required this.month,
    required this.totalWorkouts,
    required this.totalDistance,
    required this.totalDuration,
  });
}

// -------------------- PAINTERS --------------------

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

    final int steps = size.width.toInt();
    for (int i = 0; i <= steps; i++) {
      final double x = i.toDouble();
      final double progress = x / size.width;
      final double phase = (animation.value * 2 * math.pi);
      final double y = baseY +
          math.sin((progress * 2 * math.pi * 1.2) + phase) * waveHeight;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaterWavePainter oldDelegate) => animation != oldDelegate.animation;
}

