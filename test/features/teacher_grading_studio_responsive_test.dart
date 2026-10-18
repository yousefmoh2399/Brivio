import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/features/assessment/presentation/screens/teacher_grading_screen.dart';
import 'package:brivio/features/assessment/presentation/widgets/smart_grading_studio.dart';

void main() {
  final mockSubmissions = [
    {
      'id': 'sub-1',
      'student_full_name': 'زياد أحمد كمال',
      'assessment_title': 'واجب الفصل الأول: قوانين كيرشوف وتطبيقاتها',
      'assessment_type': 'homework',
      'status': 'pending',
      'score': null,
    },
    {
      'id': 'sub-2',
      'student_full_name': 'فاطمة محمود إبراهيم',
      'assessment_title': 'اختبار نصف الفصل: الحركة التوافقية البسيطة',
      'assessment_type': 'exam',
      'status': 'graded',
      'score': 19.5,
    },
  ];

  final mockResetRequests = [
    {
      'id': 'rst-1',
      'student_id': 'std-1',
      'exam_id': 'ex-1',
      'reason': 'انقطاع التيار الكهربائي أثناء الاختبار',
      'students': {
        'profiles': {'full_name': 'عمر خالد فؤاد'}
      },
      'exams': {'title': 'امتحان الدوائر الكهربائية'},
    },
  ];

  Widget buildGradingScreenTestWidget({
    Size screenSize = const Size(375, 812),
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
          child: TeacherGradingScreen(
            teacherId: 'teacher-101',
            initialSubmissions: mockSubmissions,
            initialResetRequests: mockResetRequests,
          ),
        ),
      ),
    );
  }

  Widget buildSmartStudioTestWidget({
    Size screenSize = const Size(375, 812),
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
          child: const Scaffold(
            body: SmartGradingStudioDialog(
              studentName: 'زياد أحمد كمال',
              submissionId: 'sub-1',
              initialScore: 16.0,
              maxScore: 20.0,
              assessmentTitle: 'واجب الفيزياء 3 ث',
            ),
          ),
        ),
      ),
    );
  }

  group('TeacherGradingScreen Executive Hub & Responsive Tests', () {
    testWidgets('renders cleanly on small mobile (320px) with 0 overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      await tester.pumpWidget(buildGradingScreenTestWidget(screenSize: const Size(320, 700)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('استوديو ومحطة التصحيح الذكية ✍️'), findsOneWidget);
      expect(find.textContaining('إجمالي التسليمات'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('زياد أحمد كمال'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(find.text('فاطمة محمود إبراهيم'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders cleanly on standard mobile (375px)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(buildGradingScreenTestWidget(screenSize: const Size(375, 812)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('طلبات إعادة الامتحان المعلقة (1)'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
      await tester.pumpAndSettle();

      expect(find.text('تسليمات الطلاب للتصحيح والرصد (2)'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders executive layout on desktop (1024px+)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pumpWidget(buildGradingScreenTestWidget(screenSize: const Size(1024, 768)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('استوديو ومحطة التصحيح الذكية ✍️'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.text('بدء التصحيح والرصد الفوري 📝'), findsOneWidget);
      expect(find.text('مراجعة وتعديل التصحيح ✏️'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('search filters submissions accurately', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildGradingScreenTestWidget(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'فاطمة');
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.text('فاطمة محمود إبراهيم'), findsOneWidget);
      expect(find.text('زياد أحمد كمال'), findsNothing);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('filter chips filter grading queue status', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildGradingScreenTestWidget(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Tap on "تم التصحيح" chip
      final gradedChip = find.text('تم التصحيح (1) ✅');
      expect(gradedChip, findsOneWidget);

      await tester.ensureVisible(gradedChip);
      await tester.pumpAndSettle();
      await tester.tap(gradedChip);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.text('فاطمة محمود إبراهيم'), findsOneWidget);
      expect(find.text('زياد أحمد كمال'), findsNothing);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders cleanly in dark theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(buildGradingScreenTestWidget(
        screenSize: const Size(375, 812),
        themeMode: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('استوديو ومحطة التصحيح الذكية ✍️'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });

  group('SmartGradingStudioDialog Responsive Tests', () {
    testWidgets('renders cleanly on small mobile (320px) with 0 overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      await tester.pumpWidget(buildSmartStudioTestWidget(screenSize: const Size(320, 700)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('استوديو التصحيح الذكي والقلم الرقمي ✍️'), findsOneWidget);
      expect(find.text('زياد أحمد كمال'), findsOneWidget);
      expect(find.text('اعتماد التصحيح والدرجة ✨'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders cleanly on standard mobile (375px)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(buildSmartStudioTestWidget(screenSize: const Size(375, 812)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('16.0 / 20'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders cleanly on desktop (1024px+)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pumpWidget(buildSmartStudioTestWidget(screenSize: const Size(1024, 768)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('اعتماد التصحيح والدرجة ✨'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('adjusts score with stepper and final score button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildSmartStudioTestWidget(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(find.textContaining('16.0 / 20'), findsOneWidget);

      // Tap final score 100% button
      final finalScoreBtn = find.text('الدرجة النهائية 💯');
      expect(finalScoreBtn, findsOneWidget);

      await tester.ensureVisible(finalScoreBtn);
      await tester.pumpAndSettle();
      await tester.tap(finalScoreBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('20.0 / 20'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders flawlessly in dark theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(buildSmartStudioTestWidget(
        screenSize: const Size(375, 812),
        themeMode: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('اعتماد التصحيح والدرجة ✨'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
