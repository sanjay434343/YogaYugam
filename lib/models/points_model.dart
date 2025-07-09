import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class YogaPoints {
  final int points;
  final String activity;
  final DateTime timestamp;
  final String type;

  YogaPoints({
    required this.points,
    required this.activity,
    required this.timestamp,
    this.type = 'practice_completion',
  });

  Map<String, dynamic> toJson() {
    return {
      'points': points,
      'activity': activity,
      'exactTime': timestamp.toIso8601String(),
      'timestamp': DateTime(timestamp.year, timestamp.month, timestamp.day).toIso8601String(),
      'type': type,
    };
  }

  static Future<Map<String, dynamic>> getTodayProgress(String userId) async {
    final db = FirebaseDatabase.instance;
    final today = DateTime.now();
    final todayString = DateTime(today.year, today.month, today.day).toIso8601String();
    
    try {
      final snapshot = await db
          .ref()
          .child('users/$userId/points_history')
          .orderByChild('timestamp')
          .equalTo(todayString)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final todayPoints = data.values
            .fold(0, (sum, item) => sum + (item['points'] as int? ?? 0));
            
        return {
          'todayPoints': todayPoints,
          'targetPoints': 10,
          'progress': todayPoints / 10,
        };
      }
      
      return {
        'todayPoints': 0,
        'targetPoints': 10,
        'progress': 0.0,
      };
    } catch (e) {
      debugPrint('Error getting today\'s progress: $e');
      return {
        'todayPoints': 0,
        'targetPoints': 10,
        'progress': 0.0,
      };
    }
  }
}
