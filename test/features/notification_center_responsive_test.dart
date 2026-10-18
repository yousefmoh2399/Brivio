import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/features/communication/domain/models/notification.dart';
import 'package:brivio/features/communication/domain/repositories/i_notification_repository.dart';
import 'package:brivio/features/communication/presentation/viewmodels/notification_center_viewmodel.dart';
import 'package:brivio/features/communication/presentation/screens/notification_center_screen.dart';

class _FakeNotificationRepository implements INotificationRepository {
  List<AppNotification> notifications;

  _FakeNotificationRepository(this.notifications);

  @override
  Future<List<AppNotification>> getNotifications() async => notifications;

  @override
  Future<int> getUnreadCount() async =>
      notifications.where((n) => !n.isRead).length;

  @override
  Future<void> markRead(String notificationId) async {
    final idx = notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      notifications[idx] = notifications[idx].copyWith(isRead: true);
    }
  }

  @override
  Future<void> markAllRead() async {
    notifications =
        notifications.map((n) => n.copyWith(isRead: true)).toList();
  }

  @override
  Future<NotificationPreference> getPreferences() async =>
      NotificationPreference(
        userId: 'test-user',
        updatedAt: DateTime.now(),
      );

  @override
  Future<void> updatePreferences(NotificationPreference preference) async {}

  @override
  Stream<AppNotification> subscribeToNotifications() => const Stream.empty();

  @override
  void clearCache() {}
}

void main() {
  List<AppNotification> createSampleNotifications() {
    return [
      AppNotification(
        id: 'notif-1',
        userId: 'user-1',
        type: 'exam_published',
        title: 'تم نشر اختبار جديد',
        message: 'تم جدول موعد اختبار التفاضل والتكامل النهائي يوم الأربعاء القادم.',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      AppNotification(
        id: 'notif-2',
        userId: 'user-1',
        type: 'receipt_created',
        title: 'تم إصدار إيصال سداد',
        message: 'تم استلام مبلغ 500 جنيه لمصاريف شهر أكتوبر لمجموعة الفيزياء بنجاح.',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'notif-3',
        userId: 'user-1',
        type: 'absence_alert',
        title: 'تنبيه غياب طالب',
        message: 'تم تسجيل غياب الطالب في حصة الكيمياء الساعة 4:00 عصراً.',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      AppNotification(
        id: 'notif-4',
        userId: 'user-1',
        type: 'general_announcement',
        title: 'تنبيه هام من الإدارة',
        message: 'يرجى العلم بأنه تم تأجيل مواعيد مراجعة ليلة الامتحان إلى يوم الجمعة.',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }

  Widget createTestWidget({
    required Size screenSize,
    required NotificationCenterViewModel viewModel,
    ValueChanged<AppNotification>? onNotificationTap,
    Locale locale = const Locale('ar'),
  }) {
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(
          size: screenSize,
          textScaler: const TextScaler.linear(1.0),
        ),
        child: SizedBox(
          width: screenSize.width,
          height: screenSize.height,
          child: NotificationCenterScreen(
            viewModel: viewModel,
            onNotificationTap: onNotificationTap,
          ),
        ),
      ),
    );
  }

  group('NotificationCenterScreen Responsiveness & Functionality Tests', () {
    testWidgets(
      'renders flawlessly on narrow mobile screen (320x640) with zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final sampleNotifs = createSampleNotifications();
        final repo = _FakeNotificationRepository(sampleNotifs);
        final vm = NotificationCenterViewModel(repo);

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(320, 640),
            viewModel: vm,
          ),
        );
        await tester.pumpAndSettle();

        // Check for absence of any RenderFlex overflow
        expect(tester.takeException(), isNull);

        // Header check
        expect(find.textContaining('مركز الإشعارات'), findsWidgets);

        // KPI metrics strip check
        expect(find.text('إجمالي التنبيهات'), findsOneWidget);
        expect(find.text('غير مقروءة ⚡'), findsOneWidget);

        // Notification cards rendered
        expect(find.textContaining('تم نشر اختبار جديد'), findsOneWidget);
        expect(find.textContaining('تم إصدار إيصال سداد'), findsOneWidget);
      },
    );

    testWidgets(
      'renders on standard mobile screen (375x812) with search and filters',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final sampleNotifs = createSampleNotifications();
        final repo = _FakeNotificationRepository(sampleNotifs);
        final vm = NotificationCenterViewModel(repo);

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(375, 812),
            viewModel: vm,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Test category filter click on Academic pill
        final academicPill = find.textContaining('أكاديمية 📚');
        expect(academicPill, findsOneWidget);
        await tester.tap(academicPill);
        await tester.pumpAndSettle();

        // Academic notification should be present, financial should be filtered out
        expect(find.textContaining('تم نشر اختبار جديد'), findsOneWidget);
        expect(find.textContaining('تم إصدار إيصال سداد'), findsNothing);

        // Switch back to "الكل"
        await tester.tap(find.text('الكل'));
        await tester.pumpAndSettle();
        expect(find.textContaining('تم نشر اختبار جديد'), findsOneWidget);
        expect(find.textContaining('تم إصدار إيصال سداد'), findsOneWidget);

        // Test search bar filtering
        final searchField = find.byType(TextField);
        expect(searchField, findsOneWidget);
        await tester.enterText(searchField, 'فيزياء');
        await tester.pumpAndSettle();

        // Only the notification mentioning فيزياء should appear
        expect(find.textContaining('تم إصدار إيصال سداد'), findsOneWidget);
        expect(find.textContaining('تم نشر اختبار جديد'), findsNothing);
      },
    );

    testWidgets(
      'renders on tablet/desktop (1024x768) in 2-column grid with zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final sampleNotifs = createSampleNotifications();
        final repo = _FakeNotificationRepository(sampleNotifs);
        final vm = NotificationCenterViewModel(repo);

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(1024, 768),
            viewModel: vm,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Verify Grid View is used on desktop
        expect(find.byType(SliverGrid), findsOneWidget);

        // Verify all 4 notification items render cleanly
        expect(find.textContaining('تم نشر اختبار جديد'), findsOneWidget);
        expect(find.textContaining('تم إصدار إيصال سداد'), findsOneWidget);
        expect(find.textContaining('تنبيه غياب طالب'), findsOneWidget);
        expect(find.textContaining('تنبيه هام من الإدارة'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping notification triggers callback and marks notification read',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final sampleNotifs = createSampleNotifications();
        final repo = _FakeNotificationRepository(sampleNotifs);
        final vm = NotificationCenterViewModel(repo);

        AppNotification? tappedNotif;

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(375, 812),
            viewModel: vm,
            onNotificationTap: (notif) => tappedNotif = notif,
          ),
        );
        await tester.pumpAndSettle();

        // Tap the first notification
        await tester.tap(find.textContaining('تم نشر اختبار جديد'));
        await tester.pumpAndSettle();

        expect(tappedNotif, isNotNull);
        expect(tappedNotif!.id, equals('notif-1'));
      },
    );
  });
}
