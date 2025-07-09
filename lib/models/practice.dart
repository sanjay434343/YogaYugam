class PracticeStep {
  final String duration;
  final String model;
  final String pose1;

  PracticeStep({
    required this.duration,
    required this.model,
    required this.pose1,
  });

  factory PracticeStep.fromMap(Map<String, dynamic> map) {
    return PracticeStep(
      duration: map['duration'] ?? '',
      model: map['model'] ?? '',
      pose1: map['pose1'] ?? '',
    );
  }
}

class Practice {
  final String yoga;
  final double price;
  final String practiceId;
  final Map<String, PracticeStep> steps;

  Practice({
    required this.yoga,
    required this.steps,
    this.price = 0.0,
    this.practiceId = '',
  });

  factory Practice.fromRTDB(Map<String, dynamic> map) {
    Map<String, PracticeStep> stepsMap = {};
    map.forEach((key, value) {
      if (key.startsWith('step') && value is Map) {
        stepsMap[key] = PracticeStep.fromMap(Map<String, dynamic>.from(value));
      }
    });

    return Practice(
      yoga: map['yoga'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      practiceId: map['id']?.toString() ?? '',
      steps: stepsMap,
    );
  }
}
