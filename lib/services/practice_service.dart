import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/practice.dart' as practice_model;  // Add alias to avoid ambiguity

class PracticeService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final _db = FirebaseDatabase.instance.ref();  // Updated to use ref() instead of reference()

  Future<List<practice_model.Practice>> getPractices() async {
    try {
      final snapshot = await _database.child('practice').get();
      if (!snapshot.exists) return [];

      final values = snapshot.value as Map<dynamic, dynamic>;
      final practices = <practice_model.Practice>[];
      
      values.forEach((key, value) {
        practices.add(practice_model.Practice.fromRTDB(Map<String, dynamic>.from(value)));
      });

      return practices;
    } catch (e) {
      debugPrint('Error fetching practices: $e');
      return [];
    }
  }

  Future<List<practice_model.Practice>> getFeaturedPractices() async {
    final snapshot = await _db.child('practice').get();
    if (!snapshot.exists) return [];

    List<practice_model.Practice> practices = [];
    Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
    
    data.forEach((key, value) {
      if (value is Map) {
        practices.add(practice_model.Practice.fromRTDB(Map<String, dynamic>.from(value)));
      }
    });

    return practices;
  }
}
