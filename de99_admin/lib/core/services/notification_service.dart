import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:de99_admin/core/utils/notification_log.dart';

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in background
  await Firebase.initializeApp();
  
  final notification = message.notification;
  final title = notification?.title ?? 'Admin Notification';
  final body = notification?.body ?? '';
  final data = message.data;

  // Log in background console
  developer.log('Background FCM received: $title - $body');
  
  // Note: background memory context is isolated in Flutter, so we log to logs when the app returns,
  // but if the app is alive we store it.
  NotificationLog.addLog(title, body, data);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _initialized = false;
  String? fcmToken;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      // 1. Initialise Firebase Core
      await Firebase.initializeApp();
      
      // 2. Request permission (iOS & Android 13+)
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // 3. Retrieve FCM token
      try {
        fcmToken = await messaging.getToken();
        developer.log('FCM Token successfully retrieved: $fcmToken');
      } catch (tokenError) {
        developer.log('Warning: Failed to retrieve FCM Token: $tokenError');
      }

      // 4. Set background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 4. Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final title = notification?.title ?? 'Admin Notification';
        final body = notification?.body ?? '';
        final data = message.data;

        developer.log('Foreground FCM received: $title - $body');
        NotificationLog.addLog(title, body, data);
      });

      // 5. Handle user clicking notification when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final notification = message.notification;
        final title = notification?.title ?? 'Admin Notification';
        final body = notification?.body ?? '';
        final data = message.data;

        NotificationLog.addLog(title, body, data);
      });

      _initialized = true;
      developer.log('Firebase Cloud Messaging successfully initialized.');
    } catch (e) {
      developer.log('Firebase initialization skipped/failed: $e');
      developer.log('Push notifications will run in mock/local mode.');
    }
  }

  Future<void> subscribeToAdminTopic() async {
    if (!_initialized) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic('admin_notifications');
      developer.log('Successfully subscribed to topic: admin_notifications');
    } catch (e) {
      developer.log('Failed to subscribe to topic: $e');
    }
  }

  Future<void> unsubscribeFromAdminTopic() async {
    if (!_initialized) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('admin_notifications');
      developer.log('Successfully unsubscribed from topic: admin_notifications');
    } catch (e) {
      developer.log('Failed to unsubscribe from topic: $e');
    }
  }
}
