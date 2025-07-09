import 'package:flutter/material.dart';
import '../models/practice.dart';
import '../services/practice_service.dart';

class HomeController extends ChangeNotifier {
  final PracticeService _practiceService = PracticeService();
  List<Practice> practices = [];
  bool isLoading = false;
  String? error;

  Future<void> loadPractices() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      // Cast the result to List<Practice>
      final fetchedPractices = await _practiceService.getFeaturedPractices();
      practices = List<Practice>.from(fetchedPractices);
      
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      error = 'Failed to load practices';
      debugPrint('Error loading practices: $e');
      notifyListeners();
    }
  }
}
