import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class CourseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Stream<List<Map<String, dynamic>>> getCourses() {
    return _database
        .child('courses')
        .onValue
        .map((event) {
          debugPrint('Attempting to load courses...');
          debugPrint('Database URL: ${_database.child('courses')}');
          
          final data = event.snapshot.value;
          if (data == null) return [];

          try {
            if (data is Map) {
              return data.entries
                  .map((e) => {
                        'id': e.key,
                        ...(e.value as Map<dynamic, dynamic>)
                            .map((key, value) => MapEntry(key.toString(), value))
                      })
                  .toList();
            }
            return [];
          } catch (e) {
            debugPrint('Exception caught: $e');
            return [];
          }
        });
  }

  Future<void> initializeDefaultCourses() async {
    try {
      final snapshot = await _database.child('courses').get();
      
      if (!snapshot.exists) {
        await _database.child('courses').set({
          'beginner': {
            'title': 'Beginner Yoga',
            'description': 'Perfect for those just starting their yoga journey',
            'level': 1,
            'duration': '30 mins',
            'imageUrl': 'https://example.com/beginner.jpg',
          },
          'intermediate': {
            'title': 'Intermediate Flow',
            'description': 'Advance your practice with flowing sequences',
            'level': 2,
            'duration': '45 mins',
            'imageUrl': 'https://example.com/intermediate.jpg',
          },
          'advanced': {
            'title': 'Advanced Poses',
            'description': 'Challenge yourself with complex poses',
            'level': 3,
            'duration': '60 mins',
            'imageUrl': 'https://example.com/advanced.jpg',
          }
        });
        debugPrint('Initialized default courses');
      }
    } catch (e) {
      debugPrint('Error initializing default courses: $e');
    }
  }
}
