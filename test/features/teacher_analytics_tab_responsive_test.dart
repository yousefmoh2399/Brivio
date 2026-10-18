import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/teacher/tabs/analytics_tab.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/features/analytics/presentation/screens/teacher_analytics_screen.dart';
import 'package:brivio/features/analytics/presentation/widgets/at_risk_students_card.dart';

void main() {
  final sampleExams = [
    {
      'id': 'exam-1',
      'title': 'امتحان الفيزياء الحديثة الشامل (3ث)',
      'max_attempts': 2,
      'pass_score': 50.0,
      'status': 'published',
    },
    {
      'id': 'exam-2',
      'title': 'اختبار الميكانيكا وقوانين الحركة الدائرية',
      'max_attempts': 1,
      'pass_score': 60.0,
      'status': 'closed',
    },
    {
      'id': 'exam-3',
      'title': 'كويز الكهرومغناطيسية والحث الكهرومغناطيسي',
      'max_attempts': 3,
      'pass_score': 40.0,
      'status': 'published',
    },
  ];

  final sampleAttempts = [
    {
      'id': 'att-1',
      'exam_id': 'exam-1',
      'status': 'graded',
      'score': 88.0,
      'max_score': 100.0,
      'student_id': 'stu-001',
    },
    {
      'id': 'att-2',
      'exam_id': 'exam-1',
      'status': 'graded',
      'score': 74.0,
      'max_score': 100.0,
      'student_id': 'stu-002',
    },
    {
      'id': 'att-3',
      'exam_id': 'exam-1',
      'status': 'graded',
      'score': 45.0,
      'max_score': 100.0,
      'student_id': 'stu-003',
    },
    {
      'id': 'att-4',
      'exam_id': 'exam-2',
      'status': 'graded',
      'score': 92.0,
      'max_score': 100.0,
      'student_id': 'stu-004',
    },
    {
      'id': 'att-5',
      'exam_id': 'exam-2',
      'status': 'submitted',
      'score': null,
      'max_score': 100.0,
      'student_id': 'stu-005',
    },
  ];

  const sampleAtRiskStudents = [
    AtRiskStudentInfo(
      studentId: 'stu-003',
      studentName: 'محمود عبد الرحيم المنشاوي',
      studentCode: 'PHY-890',
      parentPhone: '01012345678',
      recentScores: [18.0, 13.5, 8.0],
      maxScore: 20.0,
      severity: AtRiskSeverity.critical,
      declineReason: 'تراجع ملحوظ بنسبة 55% في آخر 3 اختبارات متتالية',
      suggestedIntervention: 'تحديد جلسة دعم ومراجعة خاصة مع المساعد الأكاديمي',
      missedHomeworkCount: 2,
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
      locale: const Locale('ar'),
      home: Scaffold(body: child),
    );
  }

  group('Teacher Reports & Analytics Tab Responsive Architecture Tests', () {
    testWidgets('renders on ultra-compact mobile (320px) without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          child: AnalyticsTab(
            profileId: 'teacher-prof-1',
            initialExams: sampleExams,
            initialAttempts: sampleAttempts,
            initialAtRiskStudents: sampleAtRiskStudents,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('التقارير والتحليلات الأكاديمية'), findsOneWidget);
      expect(find.text('مركز التقارير والتحليلات'), findsOneWidget);
      expect(find.text('الامتحانات المسجلة'), findsOneWidget);
      expect(find.text('المحاولات والتسليمات'), findsOneWidget);
      expect(find.text('توزيع المستويات والتحصيل الأكاديمي'), findsOneWidget);
    });

    testWidgets('allows switching between tabs and searching exams on standard mobile (375px)', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          child: AnalyticsTab(
            profileId: 'teacher-prof-1',
            initialExams: sampleExams,
            initialAttempts: sampleAttempts,
            initialAtRiskStudents: sampleAtRiskStudents,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Switch to تفاصيل الامتحانات tab
      await tester.tap(find.textContaining('تفاصيل الامتحانات'));
      await tester.pumpAndSettle();

      expect(find.text('امتحان الفيزياء الحديثة الشامل (3ث)'), findsOneWidget);
      expect(find.text('اختبار الميكانيكا وقوانين الحركة الدائرية'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('كويز الكهرومغناطيسية والحث الكهرومغناطيسي'), findsOneWidget);

      // Search for specific exam
      await tester.enterText(find.byType(TextField), 'الميكانيكا');
      await tester.pumpAndSettle();

      expect(find.text('اختبار الميكانيكا وقوانين الحركة الدائرية'), findsOneWidget);
      expect(find.text('امتحان الفيزياء الحديثة الشامل (3ث)'), findsNothing);

      // Switch to مركز التصدير والطباعة tab
      await tester.tap(find.text('مركز التصدير والطباعة'));
      await tester.pumpAndSettle();

      expect(find.text('التقرير الأكاديمي العام للمعلم'), findsOneWidget);
      expect(find.text('نماذج بابل شيت فارغة (Bubble Sheet)'), findsOneWidget);
      expect(find.text('سجلات الحضور والغياب التفصيلية'), findsOneWidget);
    });

    testWidgets('renders on desktop (1024px) with high-fidelity layout and 4-column KPI cards', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          child: const AnalyticsTab(
            profileId: 'teacher-prof-1',
            initialExams: [],
            initialAttempts: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('التقارير والتحليلات الأكاديمية'), findsOneWidget);
      expect(find.text('تقرير شامل PDF'), findsOneWidget);
      expect(find.text('سجلات الحضور'), findsOneWidget);
      expect(find.text('جداول المجموعات'), findsOneWidget);
      expect(find.text('طباعة بابل شيت'), findsOneWidget);
    });

    testWidgets('renders cleanly in Dark Mode with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          themeMode: ThemeMode.dark,
          child: AnalyticsTab(
            profileId: 'teacher-prof-1',
            initialExams: sampleExams,
            initialAttempts: sampleAttempts,
            initialAtRiskStudents: sampleAtRiskStudents,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('التقارير والتحليلات الأكاديمية'), findsOneWidget);
    });

    testWidgets('renders empty state cleanly when no exams are found in exams tab', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          child: const TeacherAnalyticsScreen(
            profileId: 'teacher-prof-1',
            initialExams: [],
            initialAttempts: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Switch to exams tab
      await tester.tap(find.textContaining('تفاصيل الامتحانات'));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد اختبارات مسجلة حالياً لعرض تقاريرها'), findsOneWidget);
    });
  });
}
