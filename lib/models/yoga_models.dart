import 'package:flutter/foundation.dart';
export 'practice.dart';

class Practice {
  final int id;  // Changed to int type
  final String yoga;
  final double price;
  final Map<String, YogaStep> steps;

  // Add a getter for practiceId to maintain compatibility
  String get practiceId => id.toString();

  Practice({
    required this.id,
    required this.yoga,
    required this.price,
    required this.steps,
  });

  factory Practice.fromRTDB(Map<String, dynamic> data) {
    debugPrint('Parsing practice data: $data');
    
    // Extract and sort steps properly
    Map<String, YogaStep> steps = {};
    List<MapEntry<String, dynamic>> stepEntries = data.entries
        .where((e) => e.key.startsWith('step'))
        .toList();
    
    // Sort by step number
    stepEntries.sort((a, b) {
      final aNum = int.tryParse(a.key.replaceAll('step', '')) ?? 0;
      final bNum = int.tryParse(b.key.replaceAll('step', '')) ?? 0;
      return aNum.compareTo(bNum);
    });

    // Create sorted steps map
    for (var entry in stepEntries) {
      if (entry.value is Map) {
        final stepNumber = int.tryParse(entry.key.replaceAll('step', '')) ?? 0;
        steps[entry.key] = YogaStep.fromRTDB(
          Map<String, dynamic>.from(entry.value),
          stepNumber: stepNumber,
        );
      }
    }

    debugPrint('Found ${steps.length} sorted steps');

    return Practice(
      id: (data['id'] is String) ? int.parse(data['id'].toString().trim()) : (data['id'] ?? 0),
      yoga: data['yoga'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      steps: steps,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'yoga': yoga,
      'price': price,
      ...steps.map((key, value) => MapEntry(key, value.toMap())),
    };
  }
}

class YogaStep {
  final String pose1;
  final String duration;
  final String model;
  final int stepNumber;  // Changed from 'step' to 'stepNumber' for clarity

  YogaStep({
    required this.pose1,
    required this.duration,
    required this.model,
    required this.stepNumber,  // Changed parameter name
  });

  factory YogaStep.fromMap(Map<String, dynamic> map) {
    return YogaStep(
      duration: map['duration'] ?? '',
      model: map['model'] ?? '',
      pose1: map['pose1'] ?? '',
      stepNumber: map['step'] ?? 0, // Parse step from map
    );
  }

  factory YogaStep.fromRTDB(Map<dynamic, dynamic> map, {required int stepNumber}) {
    debugPrint('Parsing step $stepNumber data: $map');
    final step = YogaStep(
      duration: map['duration']?.toString() ?? '60s',
      model: map['model']?.toString() ?? '',
      pose1: map['pose1']?.toString() ?? '',
      stepNumber: stepNumber,  // Use the provided step number
    );
    debugPrint('Created step $stepNumber with duration: ${step.duration}, model: ${step.model}');
    return step;
  }

  YogaStep toPracticeStep() => this;

  int getDurationInSeconds() {
    try {
      final cleanDur = duration.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      final numberMatch = RegExp(r'(\d+)').firstMatch(cleanDur);
      if (numberMatch == null) return 60;
      
      final number = int.parse(numberMatch.group(1)!);
      
      if (cleanDur.endsWith('m') || cleanDur.contains('min')) {
        return number * 60;
      }
      return number;
    } catch (e) {
      debugPrint('Error parsing duration "$duration": $e');
      return 60;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'model': model,
      'pose1': pose1,
      'duration': duration,
      'step': stepNumber, // Add step to map
    };
  }
}
