import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/features/academy/domain/models/educational_center.dart';
import 'package:brivio/features/academy/presentation/screens/join_center_screen.dart';

void main() {
  final sampleMemberships = [
    const UserCenterMembership(
      centerId: 'center-1',
      centerName: 'سنتر الأوائل التعليمي - فرع الدقي',
      centerCode: 'CTR-A8F290',
      governorate: 'الجيزة',
      role: 'teacher',
      isPrimary: true,
    ),
    const UserCenterMembership(
      centerId: 'center-2',
      centerName: 'أكاديمية التفوق والنخبة',
      centerCode: 'CTR-B99100',
      governorate: 'القاهرة',
      role: 'teacher',
      isPrimary: false,
    ),
  ];

  Widget buildTestWidget({
    Size screenSize = const Size(375, 812),
    ThemeMode themeMode = ThemeMode.light,
    List<UserCenterMembership>? memberships,
    Future<Map<String, dynamic>> Function(String code)? onJoinCode,
    String role = 'teacher',
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
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      locale: const Locale('ar'),
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: SizedBox(
          width: screenSize.width,
          height: screenSize.height,
          child: JoinCenterScreen(
            role: role,
            initialMemberships: memberships ?? sampleMemberships,
            onJoinCode: onJoinCode,
          ),
        ),
      ),
    );
  }

  group('JoinCenterScreen Responsive & Feature Tests', () {
    testWidgets('renders cleanly on small mobile (320x640) with zero overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(320, 640)));
      await tester.pumpAndSettle();

      // Check header title & hero
      expect(find.text('ربط واعتماد سنتر جديد'), findsOneWidget);
      expect(find.text('اعتماد المعلم المعتمد'), findsOneWidget);
      expect(find.text('ربط سحابي مشفر 🔒'), findsOneWidget);

      // Check input elements
      expect(find.text('كود ربط السنتر (Center Code)'), findsOneWidget);
      expect(find.text('ربط وتفعيل السنتر الآن 🚀'), findsOneWidget);

      // Drag scroll view to bring linked centers section into view on small 640px height
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('السناتر التعليمية المرتبطة بحسابك'), findsOneWidget);

      // No overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on standard mobile (375x812)', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(375, 812)));
      await tester.pumpAndSettle();

      expect(find.text('ربط واعتماد سنتر تعليمي جديد 🏫'), findsOneWidget);
      expect(find.text('مزامنة تلقائية للمجموعات'), findsOneWidget);
      expect(find.text('سنتر الأوائل التعليمي - فرع الدقي'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders wide 2-column layout on desktop (1024x768)',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(1024, 768)));
      await tester.pumpAndSettle();

      expect(find.text('ربط واعتماد سنتر جديد'), findsOneWidget);
      expect(find.text('كيف يعمل نظام ربط السناتر؟ (3 خطوات)'), findsOneWidget);
      expect(find.text('سنتر الأوائل التعليمي - فرع الدقي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('validates empty code input', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap join button without entering code
      await tester.tap(find.text('ربط وتفعيل السنتر الآن 🚀'));
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال كود السنتر المعتمد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('detects already linked center code', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Enter code of center-1
      await tester.enterText(find.byType(TextField), 'CTR-A8F290');
      await tester.pumpAndSettle();

      await tester.tap(find.text('ربط وتفعيل السنتر الآن 🚀'));
      await tester.pumpAndSettle();

      expect(find.text('حسابك مرتبط بالفعل بهذا السنتر التعليمي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('successfully links new center code and updates list',
        (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var joinCalled = false;

      await tester.pumpWidget(
        buildTestWidget(
          onJoinCode: (code) async {
            joinCalled = true;
            return {
              'center_id': 'center-3',
              'center_name': 'سنتر المستقبل التفاعلي',
              'center_code': code,
            };
          },
        ),
      );
      await tester.pumpAndSettle();

      // Enter new code
      await tester.enterText(find.byType(TextField), 'CTR-NEW999');
      await tester.pumpAndSettle();

      await tester.tap(find.text('ربط وتفعيل السنتر الآن 🚀'));
      await tester.pumpAndSettle();

      expect(joinCalled, isTrue);
      expect(find.text('تم الانضمام والربط بنجاح مع سنتر "سنتر المستقبل التفاعلي" 🏫✨'),
          findsOneWidget);
      expect(find.text('سنتر المستقبل التفاعلي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('displays empty state when no centers are linked',
        (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(memberships: []));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد سناتر مرتبطة بعد'), findsOneWidget);
      expect(find.text('استخدم كود السنتر بالأعلى لربط أول سنتر تعليمي معتمد.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly in dark theme', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(find.text('ربط واعتماد سنتر جديد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with student role properly', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(role: 'student'));
      await tester.pumpAndSettle();

      expect(find.text('الانضمام إلى سنتر تعليمي'), findsOneWidget);
      expect(find.text('انضمام طالب'), findsOneWidget);
      expect(find.text('الانضمام إلى سنترك التعليمي 🎓'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
