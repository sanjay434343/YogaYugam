class NotificationModel {
  final String id;
  final String title;
  final String content;
  final int timestamp;

  NotificationModel({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      timestamp: (map['timestamp'] as num).toInt(),
    );
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(
    (timestamp * 1000),
  );

  get isRead => null;

  String? get body => null;
}
