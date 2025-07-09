class Comment {
  final String id;
  final String text;
  final String userId;
  final String username;
  final int timestamp;

  Comment({
    required this.id,
    required this.text,
    required this.userId,
    required this.username,
    required this.timestamp,
  });

  factory Comment.fromMap(String id, Map<dynamic, dynamic> map) {
    return Comment(
      id: id,
      text: map['text'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? 'Anonymous', // Use provided username from map
      timestamp: map['timestamp'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'userId': userId,
      'timestamp': timestamp,
      // Don't store username in comments, it will be fetched from users node
    };
  }
}
