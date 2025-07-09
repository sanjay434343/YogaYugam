import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';  // Add this import

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String UID_KEY = 'uid';
  final NotificationService _notificationService = NotificationService();

  // Add this getter
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<String?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = result.user;
      if (user != null) {
        // Store UID in SharedPreferences
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(UID_KEY, user.uid);
        await _notificationService.init(); // Initialize notifications after sign in
        return user.uid;
      }
      return null;
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }

  // Check if user is already logged in
  Future<String?> getCurrentUID() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(UID_KEY);
  }

  // Sign out
  Future<void> signOut() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(UID_KEY);
    await _notificationService.removeFCMToken(); // Remove FCM token before signing out
    await _auth.signOut();
  }
}
