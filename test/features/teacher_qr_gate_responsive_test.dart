import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/features/academy/domain/models/academy_models.dart';
import 'package:brivio/features/attendance/presentation/screens/reception_qr_gate_screen.dart';

void main() {
  final sampleGroups = [
    const GroupEntity(
      id: 'group-1',
      name: 'ثانوية عامة - لغة إنجليزية (مجموعة أ)',
      code: 'ENG-301',
      subjectId: 'sub-1',
      branchId: 'branch-1',
      status: 'active',
    ),
    const GroupEntity(
      id: 'group-2',
      name: 'الصف الثاني الثانوي - لغة إنجليزية',
      code: 'ENG-201',
      subjectId: 'sub-1',
      branchId: 'branch-1',
      status: 'active',
    ),
  ];

  final sampleAttendees = [
    AttendeeItem(
      studentId: 'student-1',
      name: 'أحمد محمود إبراهيم',
      code: 'STU-101',
      parentPhone: '01012345678',
      time: DateTime(2026, 10, 18, 14, 30),
      hasDue: false,
      totalDue: 0,
      isOffline: false,
    ),
    AttendeeItem(
      studentId: 'student-2',
      name: 'سارة عبد الرحمن حسن',
      code: 'STU-102',
      parentPhone: '01198765432',
      time: DateTime(2026, 10, 18, 14, 32),
      hasDue: true,
      totalDue: 350,
      isOffline: false,
    ),
  ];

  Widget buildTestWidget({
    Size screenSize = const Size(375, 812),
    ThemeMode themeMode = ThemeMode.dark,
    List<GroupEntity>? groups,
    GroupEntity? selectedGroup,
    List<AttendeeItem>? attendees,
    Future<void> Function(String barcode)? onManualBarcodeScan,
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
          child: ReceptionQrGateScreen(
            isTestMode: true,
            initialGroups: groups ?? sampleGroups,
            initialSelectedGroup: selectedGroup ?? sampleGroups.first,
            initialAttendees: attendees ?? sampleAttendees,
            onManualBarcodeScan: onManualBarcodeScan,
          ),
        ),
      ),
    );
  }

  group('ReceptionQrGateScreen Responsive & Feature Tests', () {
    testWidgets('renders cleanly on small mobile (320x640) with zero overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(320, 640)));
      await tester.pumpAndSettle();

      // Check header and titles
      expect(find.text('بوابة الـ QR الذكية'), findsOneWidget);
      expect(find.text('المجموعة:'), findsOneWidget);
      expect(find.text('ثانوية عامة - لغة إنجليزية (مجموعة أ)'), findsWidgets);

      // Check manual input bar
      expect(find.text('تسجيل'), findsOneWidget);

      // Check attendees strip
      expect(find.text('سجل الحاضرين (2)'), findsOneWidget);
      expect(find.text('أحمد محمود إبراهيم'), findsOneWidget);

      // No overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on standard mobile (375x812)', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(375, 812)));
      await tester.pumpAndSettle();

      expect(find.text('بوابة الـ QR الذكية'), findsOneWidget);
      expect(find.text('كود الطالب يدوياً...'), findsOneWidget);
      expect(find.text('سارة عبد الرحمن حسن'), findsOneWidget);
      expect(find.text('متأخر: 350 ج.م'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders split-screen radar layout on desktop (1024x768)',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(1024, 768)));
      await tester.pumpAndSettle();

      // Check desktop sidebar header
      expect(find.text('سجل الحضور اللحظي (2)'), findsOneWidget);
      expect(find.text('كشف الغياب'), findsOneWidget);
      expect(find.text('أحمد محمود إبراهيم'), findsOneWidget);
      expect(find.text('سارة عبد الرحمن حسن'), findsOneWidget);
      expect(find.text('متأخرات: 350 ج.م'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('manual code entry triggers submission', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? scannedCode;
      await tester.pumpWidget(
        buildTestWidget(
          onManualBarcodeScan: (code) async {
            scannedCode = code;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Enter code in text field
      await tester.enterText(find.byType(TextField), 'STU-999');
      await tester.pumpAndSettle();

      // Tap register button
      await tester.tap(find.text('تسجيل'));
      await tester.pumpAndSettle();

      expect(scannedCode, 'STU-999');
      expect(tester.takeException(), isNull);
    });

    testWidgets('displays empty attendees state properly', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(attendees: []));
      await tester.pumpAndSettle();

      expect(find.text('0 حاضر'), findsOneWidget);
      expect(
          find.text('لم يتم تسجيل أي طالب بعد، ابدأ بالمسح أو الإدخال اليدوي!'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens quick tools popup menu without error', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap more tools menu button
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('كشف الغائبين والواتساب'), findsOneWidget);
      expect(find.text('تسجيل طالب جديد (30 ثانية)'), findsOneWidget);
      expect(find.text('كاشير الاستقبال السريع'), findsOneWidget);
      expect(find.text('طباعة كارنيهات المجموعة (PDF)'), findsOneWidget);
      expect(find.text('جرد الخزينة اليومية'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('toggles sound beeper', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initially enabled
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      // Tap to toggle
      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pumpAndSettle();

      // Now off
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.text('تم كتم المنبه الصوتي للبوابة 🔇'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly in light theme', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(themeMode: ThemeMode.light));
      await tester.pumpAndSettle();

      expect(find.text('بوابة الـ QR الذكية'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
