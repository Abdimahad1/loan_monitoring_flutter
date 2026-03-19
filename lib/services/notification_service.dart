// lib/services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  final ApiService _apiService = ApiService();

  Future<void> init() async {
    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await _initLocalNotifications();

    // Get FCM token
    await _getToken();

    // Setup message handlers
    _setupMessageHandlers();
  }

  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('🔔 User declined permission');
    }
  }

  Future<void> _initLocalNotifications() async {
    // Android settings
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'loan_notifications',
      'Loan Notifications',
      description: 'Notifications about loans and payments',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _getToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        print('🔔 FCM Token: $token');
        await _sendTokenToServer(token);
      }

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        print('🔔 FCM Token refreshed: $newToken');
        _sendTokenToServer(newToken);
      });
    } catch (e) {
      print('❌ Error getting FCM token: $e');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/notifications/register-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _apiService.getToken()}',
        },
        body: json.encode({
          'token': token,
          'platform': 'flutter',
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Device token registered with server');
      }
    } catch (e) {
      print('❌ Error registering token: $e');
    }
  }

  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Background message opened
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Terminated app opened
    FirebaseMessaging.instance.getInitialMessage().then(_handleNotificationTap);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;

    if (notification != null) {
      const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        'loan_notifications',
        'Loan Notifications',
        channelDescription: 'Notifications about loans and payments',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
      );

      const DarwinNotificationDetails iosDetails =
      DarwinNotificationDetails();

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        details,
        payload: json.encode(message.data),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage? message) {
    if (message != null) {
      print('🔔 Notification tapped: ${message.data}');
      // TODO: Navigate based on notification type
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    try {
      final data = json.decode(response.payload ?? '{}');
      print('🔔 Local notification tapped: $data');
      // TODO: Navigate based on notification type
    } catch (e) {
      print('Error parsing payload: $e');
    }
  }
}