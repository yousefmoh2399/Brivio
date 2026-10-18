import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/teacher/tabs/home_tab.dart';
import 'package:brivio/apps/teacher/teacher_dashboard.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/features/auth/domain/models/user_profile.dart';
import 'package:brivio/features/auth/domain/models/user_role.dart';

void main() {
  final sampleUser = UserProfile(
    id: 'teacher-101',
    email: 'teacher@brivio.edu',
    fullName: 'أ. دكتور حسام الدين علي',
    phoneNumber: '01012345678',
    role: UserRole.teacher,
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
    updatedAt: DateTime.now(),
  );

  final List<TeacherGroupAnalytics> sampleAnalytics = [
    const TeacherGroupAnalytics(
      groupId: 'grp-1',
      groupName: 'الفيزياء المتقدمة - 3ث - السبت',
      groupCode: 'PHYS-301',
      studentCount: 38,
      completedSessions: 8,
      attendanceRate: 92.5,
      absentCount: 3,
      pendingHomeworkCount: 4,
      averageExamScore: 84.0,
    ),
    const TeacherGroupAnalytics(
      groupId: 'grp-2',
      groupName: 'الميكانيكا والكهرومغناطيسية - 2ث',
      groupCode: 'MECH-202',
      studentCount: 45,
      completedSessions: 5,
      attendanceRate: 78.0,
      absentCount: 10,
      pendingHomeworkCount: 12,
      averageExamScore: 71.5,
    ),
  ];

  Widget buildTestWidget({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
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
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );
  }

  group('Teacher HomeTab AAA & Mobile Responsiveness Tests', () {
    testWidgets('Renders cleanly on narrow 320px mobile with zero RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int navigatedIndex = -1;
      bool retryCalled = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: HomeTab(
            user: sampleUser,
            isLoading: false,
            errorMessage: null,
            assignedGroupsCount: 5,
            openHomeworkCount: 4,
            publishedExamsCount: 2,
            gradingQueueCount: 7,
            todaySessionsCount: 3,
            savedBoardCount: 8,
            groupAnalytics: sampleAnalytics,
            onRetry: () => retryCalled = true,
            onNavigate: (idx) => navigatedIndex = idx,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify zero overflow
      expect(tester.takeException(), isNull);

      // Verify Title badge
      expect(find.text('بوابة التدريس والمتابعة'), findsOneWidget);

      // Verify Teacher Hero name & verified badge
      expect(find.textContaining('أهلاً بك، أ. دكتور حسام الدين علي'), findsOneWidget);
      expect(find.text('معلم معتمد 🌟'), findsOneWidget);

      // Verify Glance strip micro-chips
      expect(find.text('5 مجموعات'), findsOneWidget);
      expect(find.text('3 حصص اليوم'), findsOneWidget);
      expect(find.text('6 تكليفات'), findsOneWidget);
      expect(find.text('7 للتصحيح'), findsOneWidget);

      // Verify Live Session Cockpit
      expect(find.text('رادار الحصص المباشرة'), findsOneWidget);
      expect(find.text('شاشة العرض'), findsOneWidget);

      // Test tap on glance chip triggers navigation
      await tester.tap(find.text('5 مجموعات'));
      await tester.pumpAndSettle();
      expect(navigatedIndex, equals(1));

      // Test tap on refresh icon button
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();
      expect(retryCalled, isTrue);

      // Scroll down to view the tools command hub
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
      await tester.pumpAndSettle();

      expect(find.text('مركز أدوات المعلم الذكية ⚡'), findsOneWidget);
      expect(find.text('9 أدوات متكاملة'), findsOneWidget);
      expect(find.text('سبوراتي ومسودات التحضير'), findsOneWidget);
      expect(find.text('سبورة الحصة المباشرة'), findsOneWidget);
      expect(find.text('استوديو التصحيح'), findsOneWidget);
      expect(find.text('تصفية الأرباح'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on 375px standard mobile with dark theme',
        (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int navigatedIndex = -1;

      await tester.pumpWidget(
        buildTestWidget(
          themeMode: ThemeMode.dark,
          child: HomeTab(
            user: sampleUser,
            isLoading: false,
            errorMessage: null,
            assignedGroupsCount: 6,
            openHomeworkCount: 3,
            publishedExamsCount: 5,
            gradingQueueCount: 0,
            todaySessionsCount: 2,
            savedBoardCount: 4,
            groupAnalytics: sampleAnalytics,
            onRetry: () {},
            onNavigate: (idx) => navigatedIndex = idx,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('6 مجموعات'), findsOneWidget);
      expect(find.text('2 حصص اليوم'), findsOneWidget);
      expect(find.text('0 للتصحيح'), findsOneWidget);

      // Tap on glance chip for '2 حصص اليوم'
      await tester.tap(find.text('2 حصص اليوم'));
      await tester.pumpAndSettle();
      expect(navigatedIndex, equals(1));

      // Tap on glance chip for '8 تكليفات'
      await tester.tap(find.text('8 تكليفات'));
      await tester.pumpAndSettle();
      expect(navigatedIndex, equals(2));

      expect(tester.takeException(), isNull);
    });

    testWidgets('Group analytics cards render cleanly with zero overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestWidget(
          child: HomeTab(
            user: sampleUser,
            isLoading: false,
            errorMessage: null,
            assignedGroupsCount: 2,
            openHomeworkCount: 1,
            publishedExamsCount: 1,
            gradingQueueCount: 2,
            todaySessionsCount: 1,
            savedBoardCount: 3,
            groupAnalytics: sampleAnalytics,
            onRetry: () {},
            onNavigate: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to group analytics in smooth in-bounds increments
      for (int i = 0; i < 4; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
        await tester.pumpAndSettle();
      }

      expect(find.text('الفيزياء المتقدمة - 3ث - السبت'), findsOneWidget);
      expect(find.text('92.5%'), findsOneWidget);

      for (int i = 0; i < 2; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
        await tester.pumpAndSettle();
      }

      expect(find.text('الميكانيكا والكهرومغناطيسية - 2ث'), findsOneWidget);
      expect(find.text('78.0%'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Loading state renders modern loading indicator cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestWidget(
          child: HomeTab(
            user: sampleUser,
            isLoading: true,
            errorMessage: null,
            assignedGroupsCount: 0,
            openHomeworkCount: 0,
            publishedExamsCount: 0,
            gradingQueueCount: 0,
            todaySessionsCount: 0,
            savedBoardCount: 0,
            groupAnalytics: const [],
            onRetry: () {},
            onNavigate: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('جارٍ مزامنة لوحة المعلم والبيانات الأكاديمية...'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Error state renders portal error banner with retry button',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool retryTriggered = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: HomeTab(
            user: sampleUser,
            isLoading: false,
            errorMessage: 'تعذر الاتصال بقاعدة البيانات الأكاديمية',
            assignedGroupsCount: 0,
            openHomeworkCount: 0,
            publishedExamsCount: 0,
            gradingQueueCount: 0,
            todaySessionsCount: 0,
            savedBoardCount: 0,
            groupAnalytics: const [],
            onRetry: () => retryTriggered = true,
            onNavigate: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تعذر الاتصال بقاعدة البيانات الأكاديمية'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(retryTriggered, isTrue);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Empty groups state renders clean message without errors',
        (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestWidget(
          child: HomeTab(
            user: sampleUser,
            isLoading: false,
            errorMessage: null,
            assignedGroupsCount: 0,
            openHomeworkCount: 0,
            publishedExamsCount: 0,
            gradingQueueCount: 0,
            todaySessionsCount: 0,
            savedBoardCount: 0,
            groupAnalytics: const [],
            onRetry: () {},
            onNavigate: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down past hero, cockpit, metrics, tools and at-risk
      for (int i = 0; i < 4; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
        await tester.pumpAndSettle();
      }

      expect(find.text('لا توجد إحصائيات للمجموعات مسجلة حتى الآن.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on 1024px desktop with 4-column layout and zero overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestWidget(
          child: HomeTab(
            user: sampleUser,
            isLoading: false,
            errorMessage: null,
            assignedGroupsCount: 8,
            openHomeworkCount: 5,
            publishedExamsCount: 3,
            gradingQueueCount: 14,
            todaySessionsCount: 4,
            savedBoardCount: 12,
            groupAnalytics: sampleAnalytics,
            onRetry: () {},
            onNavigate: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مركز أدوات المعلم الذكية ⚡'), findsOneWidget);
      expect(find.text('كويز الـ 5 دقائق'), findsOneWidget);
      expect(find.text('بوابة الـ QR'), findsOneWidget);
      expect(find.text('المختبر البرمجي'), findsOneWidget);
      expect(find.text('ربط سنتر جديد'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
