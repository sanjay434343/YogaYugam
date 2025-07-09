  import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Stream<Map<String, dynamic>?> getUserData(String uid) {
    return _database
        .child('users')
        .child(uid)
        .onValue
        .map((event) {
          final data = event.snapshot.value;
          if (data == null) return null;
          if (data is Map) {
            return Map<String, dynamic>.from(data);
          }
          return {'name': data.toString()};
        });
  }

  Future<void> updateUserLoginData(User user) async {
    try {
      final userRef = _database.child('users').child(user.uid);
      
      // Only update lastLogin timestamp
      await userRef.update({
        'lastLogin': ServerValue.timestamp,
      });
      debugPrint('Updated lastLogin timestamp for ${user.uid}');
    } catch (e) {
      debugPrint('Error updating user login data: $e');
    }
  }

  Future<void> initializeUserIfNeeded(User user) async {
    try {
      final userRef = _database.child('users').child(user.uid);
      final snapshot = await userRef.get();
      
      if (!snapshot.exists) {
        // Only create data if it doesn't exist
        final username = user.email?.split('@')[0] ?? 'User';
        await userRef.set({
          'email': user.email,
          'name': username.substring(0, 1).toUpperCase() + username.substring(1),
          'createdAt': ServerValue.timestamp,
          'lastLogin': ServerValue.timestamp,
          'streak': 0,
          'totalSessions': 0,
        });
        debugPrint('Created new user data for ${user.uid}');
      }
    } catch (e) {
      debugPrint('Error initializing user data: $e');
    }
  }
}
