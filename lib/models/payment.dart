
class Payment {
  final String paymentId;
  final double amount;
  final int courseId;
  final String courseName;
  final String email;
  final String paymentMethod;
  final String status;
  final int timestamp;
  final String transactionDate;
  final String userEmail;
  final String userId;

  Payment({
    required this.paymentId,
    required this.amount,
    required this.courseId,
    required this.courseName,
    required this.email,
    required this.paymentMethod,
    required this.status,
    required this.timestamp,
    required this.transactionDate,
    required this.userEmail,
    required this.userId,
  });

  factory Payment.fromMap(String id, Map<String, dynamic> map) {
    return Payment(
      paymentId: id,
      amount: (map['amount'] as num).toDouble(),
      courseId: map['courseId'] as int,
      courseName: map['courseName'] as String,
      email: map['email'] as String,
      paymentMethod: map['paymentMethod'] as String,
      status: map['status'] as String,
      timestamp: map['timestamp'] as int,
      transactionDate: map['transactionDate'] as String,
      userEmail: map['userEmail'] as String,
      userId: map['userId'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'courseId': courseId,
      'courseName': courseName,
      'email': email,
      'paymentMethod': paymentMethod,
      'status': status,
      'timestamp': timestamp,
      'transactionDate': transactionDate,
      'userEmail': userEmail,
      'userId': userId,
    };
  }
}