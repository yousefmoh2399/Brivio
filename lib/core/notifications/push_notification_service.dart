import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../apps/student/screens/student_group_details_screen.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/study_workspace/domain/models/study_workspace_models.dart';
import '../../features/study_workspace/presentation/screens/study_workspace_screen.dart';
import '../../firebase_options.dart';
import '../../main.dart';
import '../config/app_config.dart';
import '../logging/app_logger.dart';
import '../network/supabase_client_wrapper.dart';
import 'package:get_it/get_it.dart';
import '../localization/app_locale_controller.dart';
import '../localization/notification_localizer.dart';
import '../services/settings_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      if (AppConfig.hasFirebaseConfig) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp();
      }
    }

    // If message is data-only (no system tray notification attached), display via local notifications
    if (message.notification == null && message.data.isNotEmpty) {
      final rawTitle = message.data['title']?.toString();
      final rawBody = message.data['body']?.toString();
      if (rawTitle != null || rawBody != null) {
        final localNotifications = FlutterLocalNotificationsPlugin();
        const initSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        );
        await localNotifications.initialize(settings: initSettings);

        final title = NotificationLocalizer.localizeTitle(rawTitle, isArabic: true);
        final body = NotificationLocalizer.localizeMessage(rawBody, isArabic: true);

        await localNotifications.show(
          id: message.hashCode,
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'academy_notifications',
              'إشعارات الأكاديمية والسنتر',
              channelDescription:
                  'تنبيهات الحصص والواجبات والامتحانات والمدفوعات والحضور.',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: jsonEncode(message.data),
        );
      }
    }
  } catch (error, stackTrace) {
    AppLogger.error('Firebase background message handling failed', error, stackTrace);
  }
}

class PushNotificationService {
  bool get _isArabic {
    if (GetIt.instance.isRegistered<SettingsService>()) {
      return GetIt.instance<SettingsService>().language == AppLanguage.arabic;
    }
    return true;
  }

  AndroidNotificationChannel _getAndroidChannel() {
    final isAr = _isArabic;
    return AndroidNotificationChannel(
      'academy_notifications',
      isAr ? 'إشعارات الأكاديمية والسنتر' : 'Academy & Center Notifications',
      description: isAr
          ? 'تنبيهات الحصص والواجبات والامتحانات والمدفوعات والحضور.'
          : 'Operational, payment, attendance, and learning alerts.',
      importance: Importance.high,
    );
  }

  final SupabaseClientWrapper _clientWrapper;
  FirebaseMessaging? messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  bool _initialized = false;
  bool _started = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  PushNotificationService(
    this._clientWrapper, {
    this.messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  bool get isConfigured => _initialized;

  bool get _supportsFirebaseMessaging {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> initialize() async {
    if (_initialized || !_supportsFirebaseMessaging) {
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        if (AppConfig.hasFirebaseConfig) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } else {
          await Firebase.initializeApp();
        }
      }
      messaging ??= FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final decoded = jsonDecode(payload);
            if (decoded is Map<String, dynamic>) {
              handleNotificationTap(decoded);
            } else if (decoded is Map) {
              handleNotificationTap(Map<String, dynamic>.from(decoded));
            }
          } catch (error, stackTrace) {
            AppLogger.error(
              'Failed to decode local notification payload',
              error,
              stackTrace,
            );
          }
        },
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_getAndroidChannel());
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      await messaging!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _initialized = true;
      AppLogger.info('Firebase Cloud Messaging initialized.');
    } catch (error, stackTrace) {
      AppLogger.error('Firebase initialization failed', error, stackTrace);
    }
  }

  Future<void> start() async {
    if (_started) return;
    await initialize();
    if (!_initialized) return;
    _started = true;

    await syncCurrentToken();
    _tokenRefreshSub = messaging?.onTokenRefresh.listen(registerToken);
    _foregroundMessageSub = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
    _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      handleNotificationTap(message.data);
    });

    final initialMessage = await messaging?.getInitialMessage();
    if (initialMessage != null) {
      handleNotificationTap(initialMessage.data);
    }
  }

  void handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final referenceId =
        data['reference_id']?.toString() ?? data['referenceId']?.toString();

    final navigatorState = globalNavigatorKey.currentState;
    if (navigatorState == null) {
      AppLogger.warning(
        'globalNavigatorKey.currentState is null; cannot navigate from notification tap.',
      );
      return;
    }

    AppLogger.info('Notification tapped: type=$type, referenceId=$referenceId');

    final normalizedType = type?.toLowerCase() ?? '';

    if (normalizedType.contains('study') ||
        normalizedType.contains('lesson') ||
        normalizedType.contains('workspace')) {
      if (referenceId != null && referenceId.isNotEmpty) {
        navigatorState.push(
          MaterialPageRoute(
            builder: (_) => StudyWorkspaceScreen(
              lesson: StudyLessonSummary(
                id: referenceId,
                title: data['title']?.toString() ?? 'Study Workspace',
                pathName: '',
                unitName: '',
                progressPercentage: 0,
                estimatedMinutes: 0,
                lastPage: 1,
                totalPages: 1,
                xp: 0,
                hasPdf: false,
                hasCodePlayground: false,
              ),
            ),
          ),
        );
      }
    } else if (normalizedType.contains('group') ||
        normalizedType.contains('academic') ||
        normalizedType.contains('class')) {
      if (referenceId != null && referenceId.isNotEmpty) {
        navigatorState.push(
          MaterialPageRoute(
            builder: (_) => StudentGroupDetailsScreen(
              group: GroupEntity(
                id: referenceId,
                name: data['title']?.toString() ?? 'Group Details',
                code: '',
                subjectId: '',
                branchId: '',
                status: 'active',
              ),
            ),
          ),
        );
      }
    } else {
      AppLogger.info(
        'Notification type has no direct push route; keeping current screen. type=$type',
      );
    }
  }

  Future<void> syncCurrentToken() async {
    if (!_initialized) return;
    final user = _clientWrapper.client.auth.currentUser;
    if (user == null) return;

    final messagingClient = messaging;
    if (messagingClient == null) return;

    final settings = await messagingClient.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      AppLogger.info('Push notification permission denied.');
      return;
    }

    final token = await messagingClient.getToken();
    if (token == null || token.isEmpty) return;
    await registerToken(token);
  }

  Future<void> registerToken(String token) async {
    final user = _clientWrapper.client.auth.currentUser;
    if (user == null || token.trim().isEmpty) return;

    try {
      await _clientWrapper.client.rpc(
        'register_device_push_token',
        params: {'p_token': token, 'p_platform': defaultTargetPlatform.name},
      );
      AppLogger.info('FCM token registered for ${defaultTargetPlatform.name}.');
    } on PostgrestException catch (error, stackTrace) {
      AppLogger.error('Failed to register FCM token', error, stackTrace);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Unexpected FCM token registration failure',
        error,
        stackTrace,
      );
    }
  }

  Future<void> unregisterCurrentToken() async {
    if (!_initialized) return;
    final messagingClient = messaging;
    if (messagingClient == null) return;
    final token = await messagingClient.getToken();
    if (token == null || token.isEmpty) return;
    await _clientWrapper.client.rpc(
      'unregister_device_push_token',
      params: {'p_token': token},
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final rawTitle = notification?.title ?? message.data['title']?.toString();
    final rawBody = notification?.body ?? message.data['body']?.toString();
    if (rawTitle == null && rawBody == null) return;

    final isAr = _isArabic;
    final title = NotificationLocalizer.localizeTitle(rawTitle, isArabic: isAr);
    final body = NotificationLocalizer.localizeMessage(rawBody, isArabic: isAr);
    final channel = _getAndroidChannel();

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> showTestNotification({
    String? title,
    String? body,
  }) async {
    try {
      await initialize();
      final isAr = _isArabic;
      final defaultTitle = isAr
          ? 'تنبيه تجريبي من منصة بريفيو 🔔'
          : 'Test Alert from Brivio Platform 🔔';
      final defaultBody = isAr
          ? 'نظام الإشعارات الفورية يعمل بكفاءة على جهازك ومستعد لاستقبال التنبيهات.'
          : 'The push notification system is working properly on your device and ready to receive alerts.';

      final finalTitle = NotificationLocalizer.localizeTitle(title ?? defaultTitle, isArabic: isAr);
      final finalBody = NotificationLocalizer.localizeMessage(body ?? defaultBody, isArabic: isAr);
      final channel = _getAndroidChannel();

      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: finalTitle,
        body: finalBody,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (e, st) {
      AppLogger.error('Failed to show test notification', e, st);
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundMessageSub?.cancel();
    await _messageOpenedSub?.cancel();
    _started = false;
  }
}
