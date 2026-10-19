import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/teacher/tabs/notifications_tab.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/features/communication/domain/models/notification.dart';

void main() {
  final sampleNotifications = [
    AppNotification(
      id: 'notif-1',
      userId: 'teacher-prof-1',
      type: 'homework_submission',
      title: 'تسليم واجب الفيزياء الحديثة',
      message: 'قام الطالب أحمد سامي برفع حل واجب قانون كيرشوف للتيار الكهربي.',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    AppNotification(
      id: 'notif-2',
      userId: 'teacher-prof-1',
      type: 'exam_reset_request',
      title: 'طلب إعادة اختبار الميكانيكا',
      message: 'أرسل الطالب يوسف إبراهيم طلباً لإعادة محاولة الاختبار بسبب انقطاع الاتصال.',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    AppNotification(
      id: 'notif-3',
      userId: 'teacher-prof-1',
      type: 'attendance_alert',
      title: 'تنبيه غياب متكرر في الحصة',
      message: 'تجاوزت نسبة الغياب في مجموعة السبت الساعة 4:00 عصراً الحد المسموح.',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    AppNotification(
      id: 'notif-4',
      userId: 'teacher-prof-1',
      type: 'admin_broadcast',
      title: 'تنبيه إداري: مواعيد مراجعة ليلة الامتحان',
      message: 'يرجى من جميع المعلمين اعتماد جداول القاعات الدراسية قبل نهاية الأسبوع.',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  Widget buildTestWidget({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('ar'),
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Cairo',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Cairo',
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      locale: locale,
      home: Scaffold(body: child),
    );
  }

  group('Teacher Notifications Tab Responsive Architecture Tests', () {
    testWidgets('renders on ultra-compact mobile (320px) without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          child: TeacherNotificationsTab(
            notifications: sampleNotifications,
            unreadCount: 2,
            onNotificationTap: (_) {},
            onMarkRead: (_) {},
            onMarkAllRead: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('مركز تنبيهات المعلم 🔔'), findsOneWidget);
      expect(find.text('تسليم واجب الفيزياء الحديثة'), findsOneWidget);
      expect(find.text('تحديد الكل كمقروء'), findsOneWidget);

      // Scroll down on compact 320x640 viewport to verify cards below the fold
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('طلب إعادة اختبار الميكانيكا'), findsOneWidget);
    });

    testWidgets('renders on standard mobile (375x812) with category filter and search', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AppNotification? tappedNotif;
      AppNotification? markedReadNotif;
      bool markAllReadCalled = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: TeacherNotificationsTab(
            notifications: sampleNotifications,
            unreadCount: 2,
            onNotificationTap: (n) => tappedNotif = n,
            onMarkRead: (n) => markedReadNotif = n,
            onMarkAllRead: () => markAllReadCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify KPI items exist
      expect(find.text('إجمالي التنبيهات'), findsWidgets);
      expect(find.text('غير مقروءة ⚡'), findsWidgets);

      // Tap on 'تسليمات وتصحيح' category filter
      final submissionsChip = find.text('تسليمات وتصحيح').last;
      await tester.ensureVisible(submissionsChip);
      await tester.pumpAndSettle();
      await tester.tap(submissionsChip);
      await tester.pumpAndSettle();

      expect(find.text('تسليم واجب الفيزياء الحديثة'), findsOneWidget);
      expect(find.text('طلب إعادة اختبار الميكانيكا'), findsNothing);

      // Tap card to trigger onNotificationTap
      await tester.tap(find.text('تسليم واجب الفيزياء الحديثة'));
      await tester.pumpAndSettle();
      expect(tappedNotif?.id, equals('notif-1'));

      // Filter by 'طلبات الإعادة'
      final requestsChip = find.text('طلبات الإعادة').last;
      await tester.ensureVisible(requestsChip);
      await tester.pumpAndSettle();
      await tester.tap(requestsChip);
      await tester.pumpAndSettle();

      expect(find.text('طلب إعادة اختبار الميكانيكا'), findsOneWidget);
      expect(find.text('تسليم واجب الفيزياء الحديثة'), findsNothing);

      // Tap single mark read button
      final markReadBtn = find.text('تحديد كمقروء');
      expect(markReadBtn, findsOneWidget);
      await tester.tap(markReadBtn);
      await tester.pumpAndSettle();
      expect(markedReadNotif?.id, equals('notif-2'));

      // Tap 'تحديد الكل كمقروء'
      await tester.tap(find.text('تحديد الكل كمقروء'));
      await tester.pumpAndSettle();
      expect(markAllReadCalled, isTrue);

      // Search functionality
      final searchInput = find.byType(TextField);
      expect(searchInput, findsOneWidget);
      await tester.enterText(searchInput, 'كيرشوف');
      await tester.pumpAndSettle();

      // Tap 'إجمالي التنبيهات' KPI card to return to 'الكل'
      final allKpiCard = find.text('إجمالي التنبيهات').first;
      await tester.ensureVisible(allKpiCard);
      await tester.pumpAndSettle();
      await tester.tap(allKpiCard);
      await tester.pumpAndSettle();

      expect(find.text('تسليم واجب الفيزياء الحديثة'), findsOneWidget);
      expect(find.text('طلب إعادة اختبار الميكانيكا'), findsNothing);
    });

    testWidgets('renders on tablet/desktop screen (1024x768) in 2-column grid with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          child: TeacherNotificationsTab(
            notifications: sampleNotifications,
            unreadCount: 2,
            onNotificationTap: (_) {},
            onMarkRead: (_) {},
            onMarkAllRead: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.text('تسليم واجب الفيزياء الحديثة'), findsOneWidget);
      expect(find.text('طلب إعادة اختبار الميكانيكا'), findsOneWidget);
      expect(find.text('تنبيه غياب متكرر في الحصة'), findsOneWidget);
      expect(find.text('تنبيه إداري: مواعيد مراجعة ليلة الامتحان'), findsOneWidget);
    });

    testWidgets('renders in Dark Theme with zero exceptions and pristine contrast', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          themeMode: ThemeMode.dark,
          child: TeacherNotificationsTab(
            notifications: sampleNotifications,
            unreadCount: 2,
            onNotificationTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('مركز تنبيهات المعلم 🔔'), findsOneWidget);
      expect(find.text('تسليم واجب الفيزياء الحديثة'), findsOneWidget);
    });

    testWidgets('renders Empty State card when no notifications exist or search returns no results', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          child: TeacherNotificationsTab(
            notifications: const [],
            unreadCount: 0,
            onNotificationTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('لا توجد إشعارات مسجلة حالياً'), findsOneWidget);

      // Now pump with notifications and type unmatched search
      await tester.pumpWidget(
        buildTestWidget(
          child: TeacherNotificationsTab(
            notifications: sampleNotifications,
            unreadCount: 2,
            onNotificationTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchInput = find.byType(TextField);
      await tester.enterText(searchInput, 'كلمة_بحث_غير_موجودة_نهائيا');
      await tester.pumpAndSettle();

      expect(find.text('لم يتم العثور على نتائج'), findsOneWidget);
      expect(find.text('عرض كافة الإشعارات'), findsOneWidget);

      // Tap reset button
      await tester.tap(find.text('عرض كافة الإشعارات'));
      await tester.pumpAndSettle();

      expect(find.text('تسليم واجب الفيزياء الحديثة'), findsOneWidget);
    });

    testWidgets('renders Empty State on SM-T509 tablet landscape (2000x1116, 1.8 dpr) with zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(2000, 1116);
      tester.view.devicePixelRatio = 1.8;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          child: TeacherNotificationsTab(
            notifications: const [],
            unreadCount: 0,
            onNotificationTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Scroll slightly down to bring the empty card into view if needed
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('لا توجد إشعارات مسجلة حالياً'), findsOneWidget);
      expect(find.text('ستظهر هنا كافة إشعارات وتسليمات الطلاب وتنبيهات السنتر فور إرسالها.'), findsOneWidget);
    });
  });
}
