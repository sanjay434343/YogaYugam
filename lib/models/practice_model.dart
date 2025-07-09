class StepModel {
  final String duration;
  final String pose;
  final String model;

  const StepModel({
    required this.duration,
    required this.pose,
    required this.model,
  });

  factory StepModel.fromJson(Map<String, dynamic> json) {
    return StepModel(
      duration: json['duration'] ?? '',
      pose: json['pose1'] ?? '',
      model: json['model'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepModel &&
          runtimeType == other.runtimeType &&
          duration == other.duration &&
          pose == other.pose &&
          model == other.model;

  @override
  int get hashCode => duration.hashCode ^ pose.hashCode ^ model.hashCode;
}

class PracticeModel {
  final String yoga;
  final String asscor;
  final String? image;
  final Map<String, StepModel> steps;

  const PracticeModel({
    required this.yoga,
    required this.asscor,
    this.image,
    required this.steps,
  });

  factory PracticeModel.fromJson(Map<String, dynamic> json) {
    Map<String, StepModel> steps = {};
    
    json.forEach((key, value) {
      if (key.startsWith('step')) {
        steps[key] = StepModel.fromJson(value);
      }
    });

    return PracticeModel(
      yoga: json['yoga'] ?? '',
      asscor: json['asscor']?.toString() ?? '0',
      image: json['image'],
      steps: steps,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PracticeModel &&
          runtimeType == other.runtimeType &&
          yoga == other.yoga &&
          asscor == other.asscor &&
          image == other.image &&
          steps == other.steps;

  @override
  int get hashCode => yoga.hashCode ^ asscor.hashCode ^ image.hashCode ^ steps.hashCode;
}
