import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yoga/models/notification_model.dart';
import 'package:intl/intl.dart';  // Add this import

class NotificationDetailPage extends StatefulWidget {
  final NotificationModel notification;

  const NotificationDetailPage({super.key, required this.notification});

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  String _formatTimestamp(DateTime dateTime) {
    return DateFormat('MMM d, y').format(dateTime);
  }

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    if (!widget.notification.isRead!) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance
            .ref()
            .child('users/${user.uid}/notifications/${widget.notification.id}')
            .update({'isRead': true});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Convert timestamp to DateTime with proper type conversion
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      widget.notification.timestamp.toInt()
    );
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.notification.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.notification.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.notification.body ?? 'No content', // Add null check with default value
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              _formatTimestamp(dateTime), // Pass the converted DateTime
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}