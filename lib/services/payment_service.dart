import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Add this import
import '../models/payment_model.dart';

class PaymentService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Future<int> getPurchasedCoursesCount() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return 0;

      final snapshot = await _dbRef.child('payments')
          .orderByChild('userId')
          .equalTo(userId)
          .once();

      if (snapshot.snapshot.value == null) return 0;

      final payments = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
      
      // Count only successful payments
      return payments.values
          .where((payment) => payment['status'] == 'success')
          .length;
    } catch (e) {
      print('Error getting purchased courses count: $e');
      return 0;
    }
  }

  Future<List<PaymentModel>> getUserPurchases(String userId) async {
    try {
      DatabaseEvent event = await _dbRef.once();
      
      if (event.snapshot.value == null) return [];

      Map<dynamic, dynamic> data = event.snapshot.value as Map;
      List<PaymentModel> payments = [];
      
      data.forEach((key, value) {
        if (value['userId'] == userId && value['status'] == 'success') {
          payments.add(PaymentModel.fromJson(Map<String, dynamic>.from(value)));
        }
      });

      return payments;
    } catch (e) {
      print('Error fetching user purchases: $e');
      return [];
    }
  }

  Future<int> getPurchasedPracticesCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('practice_payments')
          .orderByChild('userId')
          .equalTo(user.uid)
          .once();

      if (!snapshot.snapshot.exists) return 0;

      final payments = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
      
      // Count only successful payments
      return payments.values
          .where((payment) => payment['status'] == 'success')
          .length;
    } catch (e) {
      debugPrint('Error getting purchased practices count: $e');
      return 0;
    }
  }
}
