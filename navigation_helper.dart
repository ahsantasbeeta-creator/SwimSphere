import 'package:flutter/material.dart';
import 'swimmerstreaks_goals_screen.dart';
import 'guardianstreaks_goals_screen.dart';
import 'coachstreaks_goals_screen.dart';

class NavigationHelper {
  // Navigate to Swimmer Streaks & Goals Screen
  static void navigateToSwimmerStreaksGoals(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SwimmerStreaksGoalsScreen(),
      ),
    );
  }

  // Navigate to Guardian Streaks & Goals Screen
  static void navigateToGuardianStreaksGoals(BuildContext context, String childId, String childName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GuardianStreaksGoalsScreen(
          childId: childId,
          childName: childName,
        ),
      ),
    );
  }

  // Navigate to Coach Streaks & Goals Screen
  static void navigateToCoachStreaksGoals(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CoachStreaksGoalsScreen(),
      ),
    );
  }

  // Show role selection dialog
  static void showRoleSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Your Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: Colors.blue),
              title: const Text('Swimmer'),
              subtitle: const Text('Track your own progress'),
              onTap: () {
                Navigator.pop(context);
                navigateToSwimmerStreaksGoals(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.family_restroom, color: Colors.green),
              title: const Text('Guardian'),
              subtitle: const Text('Monitor child\'s progress'),
              onTap: () {
                Navigator.pop(context);
                // For demo purposes, using mock data
                navigateToGuardianStreaksGoals(context, 'child123', 'Alex Johnson');
              },
            ),
            ListTile(
              leading: const Icon(Icons.sports, color: Colors.orange),
              title: const Text('Coach'),
              subtitle: const Text('Manage swimmer goals'),
              onTap: () {
                Navigator.pop(context);
                navigateToCoachStreaksGoals(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
