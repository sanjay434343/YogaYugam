import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/notification_service.dart' as service;

class NotificationDetailPage extends StatelessWidget {
  final service.NotificationItem notification;

  const NotificationDetailPage({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'notification-${notification.id}',
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Notification'),
          backgroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTimestamp(notification.timestamp),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                MarkdownBody(
                  data: notification.content,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute}';
  }
}
