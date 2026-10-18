import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/parent/tabs/parent_notifications_tab.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/features/academy/domain/models/academy_models.dart';
import 'package:brivio/features/communication/domain/models/notification.dart';

void main() {
  const sampleChild = Student(
    id: 'std-202',
    profileId: 'prof-202',
    studentCode: 'BRV-7711',
    primaryBranchId: 'branch-1',
    status: 'active',
    fullName: 'يوسف محمد القاضي',
    email: 'yousef@brivio.edu',
  );

  final now = DateTime.now();

  final sampleNotifications = [
    AppNotification(
      id: 'notif-1',
      userId: 'usr-parent-1',
      type: 'exam_result',
      title: 'رصد نتيجة اختبار الفيزياء الكهربية',
      message: 'حصل الطالب يوسف على درجة 19/20 (95%) في اختبار كيرشوف الدوري.',
      referenceId: 'exam-101',
      isRead: false,
      createdAt: now.subtract(const Duration(minutes: 45)),
    ),
    AppNotification(
      id: 'notif-2',
      userId: 'usr-parent-1',
      type: 'attendance_checkin',
      title: 'تسجيل حضور الحصة بالسنتر',
      message: 'تم تسجيل حضور الطالب يوسف في مجموعة الفيزياء 3ث بالقاعة 1.',
      referenceId: 'sess-201',
      isRead: false,
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
    AppNotification(
      id: 'notif-3',
      userId: 'usr-parent-1',
      type: 'payment_receipt',
      title: 'إيصال سداد رسوم دراسية معتمد',
      message: 'تم استلام مبلغ 750 ج.م وسداد اشتراك شهر أكتوبر بنجاح بخزينة السنتر.',
      referenceId: 'rec-301',
      isRead: true,
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    AppNotification(
      id: 'notif-4',
      userId: 'usr-parent-1',
      type: 'general_announcement',
      title: 'مراجعة ليلة الامتحان الشاملة',
      message: 'تنوه إدارة السنتر عن عقد حصة مراجعة مجانية شاملة يوم الجمعة القادم.',
      referenceId: null,
      isRead: true,
      createdAt: now.subtract(const Duration(days: 3)),
    ),
  ];

  Widget createTestWidget({
    required Size screenSize,
    Student? child = sampleChild,
    List<AppNotification>? notifications,
    int? unreadCount,
    VoidCallback? onMarkAllRead,
    ValueChanged<AppNotification>? onNotificationTap,
    ValueChanged<AppNotification>? onMarkRead,
    Brightness brightness = Brightness.light,
  }) {
    final effectiveList = notifications ?? sampleNotifications;
    final effectiveUnread =
        unreadCount ?? effectiveList.where((n) => !n.isRead).length;

    return MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        fontFamily: 'Cairo',
        useMaterial3: true,
        brightness: brightness,
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: screenSize,
          textScaler: const TextScaler.linear(1.0),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: ParentNotificationsTab(
              notifications: effectiveList,
              unreadCount: effectiveUnread,
              child: child,
              onMarkAllRead: onMarkAllRead ?? () {},
              onNotificationTap: onNotificationTap ?? (_) {},
              onMarkRead: onMarkRead ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  group('ParentNotificationsTab Responsiveness & Comprehensive Functionality Tests', () {
    testWidgets(
      'renders with zero RenderFlex overflow on narrow 320x640 mobile screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(screenSize: const Size(320, 640)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);

        // Verify Hero elements
        expect(find.text('يوسف محمد القاضي'), findsOneWidget);
        expect(find.textContaining('كود الطالب: BRV-7711'), findsOneWidget);
        expect(find.text('إجمالي الإشعارات'), findsOneWidget);
        expect(find.text('غير مقروءة'), findsWidgets);
        expect(find.text('حالة الاستقبال'), findsOneWidget);

        // Search bar
        expect(find.byType(TextField), findsOneWidget);

        // Filter chips
        expect(find.text('الكل', skipOffstage: false), findsOneWidget);
        expect(find.text('الدرجات والاختبارات', skipOffstage: false), findsOneWidget);

        // Cards rendered without overflow
        expect(find.text('رصد نتيجة اختبار الفيزياء الكهربية'), findsOneWidget);
        expect(find.text('تسجيل حضور الحصة بالسنتر'), findsOneWidget);
      },
    );

    testWidgets(
      'search input filters notifications and clear icon resets list on 375x812',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 812)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Type query matching only the payment receipt
        await tester.enterText(find.byType(TextField), 'سداد');
        await tester.pumpAndSettle();

        expect(find.text('إيصال سداد رسوم دراسية معتمد'), findsOneWidget);
        expect(find.text('رصد نتيجة اختبار الفيزياء الكهربية'), findsNothing);

        // Clear query
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        expect(find.text('رصد نتيجة اختبار الفيزياء الكهربية'), findsOneWidget);
        expect(find.text('إيصال سداد رسوم دراسية معتمد'), findsOneWidget);
      },
    );

    testWidgets(
      'category switching filters between unread, academic, attendance, and financial on 375x812',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 812)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // 1. Switch to Unread
        final unreadFilter = find.text('غير مقروءة', skipOffstage: false).last;
        await tester.ensureVisible(unreadFilter);
        await tester.pumpAndSettle();
        await tester.tap(unreadFilter);
        await tester.pumpAndSettle();

        expect(find.text('رصد نتيجة اختبار الفيزياء الكهربية'), findsOneWidget);
        expect(find.text('تسجيل حضور الحصة بالسنتر'), findsOneWidget);
        expect(find.text('إيصال سداد رسوم دراسية معتمد'), findsNothing);

        // 2. Switch to Academic
        final acadFilter = find.text('الدرجات والاختبارات', skipOffstage: false).first;
        await tester.ensureVisible(acadFilter);
        await tester.pumpAndSettle();
        await tester.tap(acadFilter);
        await tester.pumpAndSettle();

        expect(find.text('رصد نتيجة اختبار الفيزياء الكهربية'), findsOneWidget);
        expect(find.text('تسجيل حضور الحصة بالسنتر'), findsNothing);

        // 3. Switch to Attendance
        final attFilter = find.text('الحضور والغياب', skipOffstage: false).first;
        await tester.ensureVisible(attFilter);
        await tester.pumpAndSettle();
        await tester.tap(attFilter);
        await tester.pumpAndSettle();

        expect(find.text('تسجيل حضور الحصة بالسنتر'), findsOneWidget);
        expect(find.text('رصد نتيجة اختبار الفيزياء الكهربية'), findsNothing);

        // 4. Switch to Financial
        final finFilter = find.text('الرسوم والمصروفات', skipOffstage: false).first;
        await tester.ensureVisible(finFilter);
        await tester.pumpAndSettle();
        await tester.tap(finFilter);
        await tester.pumpAndSettle();

        expect(find.text('إيصال سداد رسوم دراسية معتمد'), findsOneWidget);
        expect(find.text('تسجيل حضور الحصة بالسنتر'), findsNothing);
      },
    );

    testWidgets(
      'tapping mark all read and tapping notification card invokes callbacks',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool allReadCalled = false;
        AppNotification? tappedNotification;

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(375, 812),
            onMarkAllRead: () => allReadCalled = true,
            onNotificationTap: (n) => tappedNotification = n,
          ),
        );
        await tester.pumpAndSettle();

        // Tap mark all read
        final markAllBtn = find.textContaining('تحديد كافة الإشعارات كمقروءة');
        expect(markAllBtn, findsOneWidget);
        await tester.tap(markAllBtn);
        await tester.pump();
        expect(allReadCalled, isTrue);

        // Tap on notification card
        final notifCard = find.text('رصد نتيجة اختبار الفيزياء الكهربية');
        expect(notifCard, findsOneWidget);
        await tester.tap(notifCard);
        await tester.pump();
        expect(tappedNotification, isNotNull);
        expect(tappedNotification!.id, 'notif-1');
      },
    );

    testWidgets(
      'renders cleanly without overflow on large tablet / desktop 1024x768 screen',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(screenSize: const Size(1024, 768)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('يوسف محمد القاضي'), findsOneWidget);
        expect(find.text('مراجعة ليلة الامتحان الشاملة'), findsOneWidget);
      },
    );

    testWidgets(
      'renders empty state gracefully when there are no notifications or no search matches',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(375, 812),
            notifications: const [],
            unreadCount: 0,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Verification of 100% updated status
        expect(find.text('محدث بالكامل ✨'), findsOneWidget);
        expect(
          find.text('لا توجد إشعارات مسجلة حالياً'),
          findsOneWidget,
        );
      },
    );
  });
}
