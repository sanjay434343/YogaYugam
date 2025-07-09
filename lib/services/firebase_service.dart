import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_options.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  bool _isInitialized = false;
  
  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  late final FirebaseAuth _auth;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isInitialized = true;
    } catch (e) {
      if (!e.toString().contains('duplicate-app')) {
        rethrow;
      }
    }
  }

  FirebaseAuth get auth => _auth;

  Future<void> signOut() async {
    await _auth.signOut();
  }

  bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      // Trim whitespace from email and password
      final trimmedEmail = email.trim();
      final trimmedPassword = password.trim();
      
      if (trimmedEmail.isEmpty || trimmedPassword.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-input',
          message: 'Email and password cannot be empty',
        );
      }

      return await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: trimmedPassword,
      );
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      if (e.code == 'invalid-credential') {
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Invalid email or password. Please check your credentials and try again.',
        );
      }
      rethrow;
    } catch (e) {
      print('Unknown error during sign in: $e');
      rethrow;
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword(
      String email, String password) async {
    try {
      final trimmedEmail = email.trim();
      final trimmedPassword = password.trim();

      if (trimmedPassword.length < 6) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: 'Password should be at least 6 characters',
        );
      }

      return await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: trimmedPassword,
      );
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  // Add method to verify current user's email
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } catch (e) {
      print('Error sending email verification: $e');
      rethrow;
    }
  }
}
