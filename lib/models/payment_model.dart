class PaymentModel {
  final String paymentId;
  final int courseId;
  final String courseName;
  final String status;
  final String userId;
  final double amount;
  final String? email;
  final String? paymentMethod;
  final int? timestamp;
  final String? transactionDate;

  PaymentModel({
    required this.paymentId,
    required this.courseId,
    required this.courseName,
    required this.status,
    required this.userId,
    required this.amount,
    this.email,
    this.paymentMethod,
    this.timestamp,
    this.transactionDate,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      paymentId: json['paymentId'] ?? '',
      courseId: json['courseId'] ?? 0,
      courseName: json['courseName'] ?? '',
      status: json['status'] ?? '',
      userId: json['userId'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      email: json['email'],
      paymentMethod: json['paymentMethod'],
      timestamp: json['timestamp'],
      transactionDate: json['transactionDate'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paymentId': paymentId,
      'courseId': courseId,
      'courseName': courseName,
      'status': status,
      'userId': userId,
      'amount': amount,
      'email': email,
      'paymentMethod': paymentMethod,
      'timestamp': timestamp,
      'transactionDate': transactionDate,
    };
  }
}
