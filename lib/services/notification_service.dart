import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart'; // Add logger package
import '../firebase_options.dart';  // Add this import
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // Add this import

class NotificationItem {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });

  factory NotificationItem.fromMap(String id, Map<String, dynamic> map) {
    return NotificationItem(
      id: id,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] * 1000).toInt(),
      ),
      isRead: map['read'] ?? false,
    );
  }
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static const String notificationEnabledKey = 'notification_enabled'; // Change to lowerCamelCase
  final DatabaseReference _notificationsRef = FirebaseDatabase.instance.ref().child('notification');
  final Logger _logger = Logger(); // Initialize logger
  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  // Add this stream controller
  final StreamController<List<NotificationItem>> _notificationsController = 
      StreamController<List<NotificationItem>>.broadcast();

  Future<void> init() async {
    // Request permission and get token
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Get FCM token and save it
    await _updateFCMToken();

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveFCMToken);

    // Initialize local notifications
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: (int id, String? title, String? body, String? payload) async {
        // Handle iOS foreground notification
      }
    );

    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification response
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create notification channel
    await _createNotificationChannel();

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'default_channel',
      'Default Channel',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<bool> getNotificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(notificationEnabledKey) ?? true;
  }

  Future<void> toggleNotifications(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationEnabledKey, enable);

    if (enable) {
      await _fcm.requestPermission();
      await _fcm.subscribeToTopic('all_users');
    } else {
      await _fcm.unsubscribeFromTopic('all_users');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) async {
    if (!await getNotificationStatus()) return;

    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      channelDescription: 'Default notification channel',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    // Save to Realtime Database with read status
    await _notificationsRef.push().set({
      'title': message.notification?.title,
      'content': message.notification?.body,
      'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
      'read': false,
    });
  }

  Stream<List<NotificationItem>> getNotifications() {
    return _database
        .child('notification')
        .onValue
        .map((event) {
          final data = event.snapshot.value;
          if (data == null) return [];

          final notificationsMap = Map<String, dynamic>.from(data as Map);
          final List<NotificationItem> notifications = [];

          notificationsMap.forEach((key, value) {
            if (value is Map) {
              try {
                notifications.add(
                  NotificationItem.fromMap(key, Map<String, dynamic>.from(value)),
                );
              } catch (e) {
                debugPrint('Error parsing notification: $e');
              }
            }
          });

          // Sort notifications by timestamp, newest first
          notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          
          return notifications;
        });
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _database
          .child('notification')
          .child(notificationId)
          .child('read')
          .set(true);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> initializeFCM() async {
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission();
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    await NotificationService.ensureFirebaseInitialized();  // Update the call
    // Save to Realtime Database
    await FirebaseDatabase.instance.ref().child('notifications').push().set({
      'title': message.notification?.title,
      'content': message.notification?.body,
      'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
    });
  }

  Future<void> testDatabaseConnection() async {
    try {
      _logger.d("Testing database connection..."); // Replace print with logger
      
      // Test main notification node
      final mainSnapshot = await _notificationsRef.get();
      _logger.d("Main node data: ${mainSnapshot.value}"); // Replace print with logger
      
      // Test specific n1 node
      final n1Snapshot = await _notificationsRef.child('n1').get();
      _logger.d("N1 node data: ${n1Snapshot.value}"); // Replace print with logger
      
      // Try to list all children
      final allData = mainSnapshot.value;
      if (allData is Map) {
        _logger.d("All notification keys: ${allData.keys.toList()}"); // Replace print with logger
        allData.forEach((key, value) {
          _logger.d("Key: $key, Value: $value"); // Replace print with logger
        });
      } else {
        _logger.d("Data is not a map: $allData"); // Replace print with logger
      }
    } catch (e, stackTrace) {
      _logger.e("Database connection error: $e", e, stackTrace); // Replace print with logger
    }
  }

  // Add helper method to check Firebase initialization
  static Future<bool> ensureFirebaseInitialized() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return true;
    }
    return false;
  }

  Future<void> removeNotification(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _database
            .child('users/${user.uid}/notifications/$notificationId')
            .remove();
        
        // Get current notifications from database instead of stream
        final snapshot = await _database
            .child('users/${user.uid}/notifications')
            .get();
        
        final notifications = <NotificationItem>[];
        if (snapshot.value != null) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          data.forEach((key, value) {
            if (value is Map) {
              notifications.add(NotificationItem.fromMap(key, Map<String, dynamic>.from(value)));
            }
          });
        }
        
        _notificationsController.add(notifications);
      }
    } catch (e) {
      debugPrint('Error removing notification: $e');
    }
  }

  Future<void> _updateFCMToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final token = await _fcm.getToken();
        if (token != null) {
          await _saveFCMToken(token);
        }
      }
    } catch (e, stack) {
      _logger.e('Error updating FCM token', e, stack);
    }
  }

  Future<void> _saveFCMToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _database
            .child('users')
            .child(user.uid)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': ServerValue.timestamp,
          'platform': defaultTargetPlatform.toString(),
        });
        _logger.i('FCM token saved successfully');
      }
    } catch (e, stack) {
      _logger.e('Error saving FCM token', e, stack);
    }
  }

  // Add this method to handle user sign out
  Future<void> removeFCMToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _database
            .child('users')
            .child(user.uid)
            .child('fcmToken')
            .remove();
        _logger.i('FCM token removed successfully');
      }
    } catch (e, stack) {
      _logger.e('Error removing FCM token', e, stack);
    }
  }

  @override
  void dispose() {
    _notificationsController.close();
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Handle notification tap when app is in background
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.ensureFirebaseInitialized();  // Update the call
  // Handle background message
  await FirebaseDatabase.instance.ref().child('notifications').push().set({
    'title': message.notification?.title,
    'content': message.notification?.body,
    'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
  });
}
