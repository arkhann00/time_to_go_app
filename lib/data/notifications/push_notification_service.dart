import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../firebase_options.dart';
import '../remote/backend_api.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;

  static const _channel = AndroidNotificationChannel(
    'general',
    'General notifications',
    description: 'Time To Go reminders',
    importance: Importance.high,
    playSound: true,
  );
  final _local = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _token;
  VoidCallback? _openBelievers;
  bool _pendingBelieversOpen = false;

  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() async {
    if (!isSupported) return;
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (_) =>
          _handleData({'screen': 'believers'}),
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen((message) async {
      _handleData(message.data);
      await _showForeground(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleData(message.data),
    );
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleData(initial.data);
  }

  void setOpenBelieversCallback(VoidCallback callback) {
    _openBelievers = callback;
    if (_pendingBelieversOpen) {
      _pendingBelieversOpen = false;
      callback();
    }
  }

  Future<void> activate(BackendApi api) async {
    if (!isSupported) return;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    _token = await FirebaseMessaging.instance.getToken();
    await _register(api, _token);
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
        .listen((token) {
          _token = token;
          unawaited(_register(api, token));
        });
  }

  Future<void> deactivate(BackendApi api) async {
    final token = _token;
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _token = null;
    if (isSupported && token != null) {
      try {
        await api.unregisterPushDevice(token);
      } catch (_) {}
    }
  }

  Future<void> _register(BackendApi api, String? token) async {
    if (token == null || token.isEmpty) return;
    final timezone = (await FlutterTimezone.getLocalTimezone()).identifier;
    await api.registerPushDevice(
      token: token,
      platform: Platform.isIOS ? 'ios' : 'android',
      timezone: timezone,
    );
  }

  Future<void> _showForeground(RemoteMessage message) async {
    if (message.data['type'] != 'believers_friday_reminder') return;
    await _local.show(
      1001,
      message.notification?.title ?? 'Time To Go',
      message.notification?.body ?? 'Проверьте Believers',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'general',
          'General notifications',
          channelDescription: 'Time To Go reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  void _handleData(Map<String, dynamic> data) {
    if (data['screen'] != 'believers') return;
    final callback = _openBelievers;
    if (callback == null) {
      _pendingBelieversOpen = true;
    } else {
      callback();
    }
  }
}
