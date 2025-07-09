class Poll {
  final String id;
  final String question;
  final Map<String, String> options;
  final Map<String, int> results;

  Poll({
    required this.id,
    required this.question,
    required this.options,
    this.results = const {},
  });

  factory Poll.fromMap(Map<String, dynamic> map, String documentId) {
    print('Converting map: $map'); // Debug print
    
    // Handle options correctly based on your structure
    Map<String, String> processedOptions = {};
    if (map['options'] != null) {
      (map['options'] as Map<String, dynamic>).forEach((key, value) {
        processedOptions[key] = value.toString();
      });
    }

    return Poll(
      id: documentId,
      question: (map['question '] ?? map['question'] ?? '').toString().trim(),
      options: processedOptions,
      results: Map<String, int>.from(map['results'] ?? {}),
    );
  }

  List<String> get optionsList => options.values.where((value) => value.isNotEmpty).toList();
}
