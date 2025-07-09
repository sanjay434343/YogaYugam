
class Notification {
  final String id;
  final String title;
  final String message;
  final String type;
  final int timestamp;
  final bool? isRead;  // Make nullable with default value

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = true,  // Default to true if not specified
  });

  factory Notification.fromMap(String id, Map<dynamic, dynamic> map) {
    return Notification(
      id: id,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? '',
      timestamp: map['timestamp'] ?? 0,
      isRead: map['isRead'] ?? true,  // Default to true if not in map
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'timestamp': timestamp,
      'isRead': isRead,  // Include isRead in the map
    };
  }
}