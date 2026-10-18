import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/localization/app_locale_controller.dart';
import '../../../../core/localization/notification_localizer.dart';
import '../../../../core/services/settings_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request permission (prevent crash if denied or failed)
    try {
      await _fcm.requestPermission();
    } catch (e) {
      debugPrint('FCM requestPermission failed: $e');
    }

    // Init local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showLocalNotification(
          message.notification!.title,
          message.notification!.body,
        );
      }
    });
  }

  Future<void> _showLocalNotification(String? title, String? body) async {
    final isAr = GetIt.instance.isRegistered<SettingsService>()
        ? GetIt.instance<SettingsService>().language == AppLanguage.arabic
        : true;
    final finalTitle = NotificationLocalizer.localizeTitle(title, isArabic: isAr);
    final finalBody = NotificationLocalizer.localizeMessage(body, isArabic: isAr);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'parent_portal_channel',
          isAr ? 'إشعارات أولياء الأمور' : 'Parent Portal Notifications',
          importance: Importance.max,
          priority: Priority.high,
        );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _localNotificationsPlugin.show(
      id: 0,
      title: finalTitle,
      body: finalBody,
      notificationDetails: platformDetails,
    );
  }
}
