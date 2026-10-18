import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/teacher/tabs/workspace_tab.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/features/assessment/presentation/screens/teacher_grading_screen.dart';

void main() {
  final sampleSubmissions = [
    {
      'id': 'sub-1',
      'student_full_name': 'عمر خالد المنشاوي',
      'assessment_title': 'واجب الفصل الأول: قوانين نيوتن والجاذبية',
      'assessment_type': 'homework',
      'status': 'submitted',
      'score': null,
      'submitted_at': '2026-10-18T10:00:00Z',
    },
    {
      'id': 'sub-2',
      'student_full_name': 'فاطمة الزهراء علي',
      'assessment_title': 'امتحان نصف الفصل: الفيزياء الحرارية',
      'assessment_type': 'exam',
      'status': 'graded',
      'score': 28.5,
      'submitted_at': '2026-10-17T14:30:00Z',
    },
  ];

  final sampleResetRequests = [
    {
      'id': 'reset-1',
      'student_id': 'stud-1',
      'exam_id': 'exam-1',
      'students': {
        'profiles': {'full_name': 'يوسف أحمد عبد الرحمن'}
      },
      'exams': {'title': 'امتحان الميكانيكا الشامل'},
      'reason': 'انقطاع الاتصال بالإنترنت أثناء حل الأسئلة الأخيرة',
      'status': 'pending',
    },
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

  group('WorkspaceTab Responsive Tests', () {
    testWidgets('renders on ultra-compact mobile (320px) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          child: WorkspaceTab(
            teacherId: 'teacher-123',
            questionBankScreen: const Center(child: Text('بنك الأسئلة Mock')),
            homeworkScreen: const Center(child: Text('الواجبات Mock')),
            examScreen: const Center(child: Text('الامتحانات Mock')),
            attendanceScreen: const Center(child: Text('الحضور Mock')),
            gradingScreen: TeacherGradingScreen(
              teacherId: 'teacher-123',
              initialSubmissions: sampleSubmissions,
              initialResetRequests: sampleResetRequests,
            ),
            replayScreen: const Center(child: Text('إعادة الحصص Mock')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('مساحة العمل الأكاديمية'), findsOneWidget);
      expect(find.text('مركز الأدوات الأكاديمية'), findsOneWidget);
      expect(find.text('بنك الأسئلة'), findsOneWidget);
      expect(find.text('السبورة الذكية'), findsOneWidget);
    });

    testWidgets('renders on standard tablet (600px) and allows switching tabs', (tester) async {
      tester.view.physicalSize = const Size(600, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          child: WorkspaceTab(
            teacherId: 'teacher-123',
            questionBankScreen: const Center(child: Text('محتوى بنك الأسئلة')),
            homeworkScreen: const Center(child: Text('محتوى الواجبات والتكليفات')),
            examScreen: const Center(child: Text('محتوى الامتحانات')),
            attendanceScreen: const Center(child: Text('محتوى الحضور والغياب')),
            gradingScreen: const Center(child: Text('محتوى التصحيح والرصد')),
            replayScreen: const Center(child: Text('محتوى إعادة الحصص')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('محتوى بنك الأسئلة'), findsOneWidget);

      // Tap on الواجبات والتكليفات tab
      await tester.tap(find.text('الواجبات والتكليفات'));
      await tester.pumpAndSettle();
      expect(find.text('محتوى الواجبات والتكليفات'), findsOneWidget);

      // Tap on الامتحانات tab
      await tester.tap(find.text('الامتحانات'));
      await tester.pumpAndSettle();
      expect(find.text('محتوى الامتحانات'), findsOneWidget);
    });

    testWidgets('renders on desktop (1024px) with high-fidelity layout', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          child: const WorkspaceTab(
            teacherId: 'teacher-123',
            questionBankScreen: Center(child: Text('Desktop Question Bank')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('مساحة العمل الأكاديمية'), findsOneWidget);
      expect(find.text('السبورة الذكية'), findsOneWidget);
      expect(find.text('سبوراتي ومسوداتي'), findsOneWidget);
      expect(find.text('توليد امتحان ذكي'), findsOneWidget);
    });

    testWidgets('renders cleanly in Dark Mode with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          themeMode: ThemeMode.dark,
          child: const WorkspaceTab(
            teacherId: 'teacher-123',
            questionBankScreen: Center(child: Text('Dark Mode Workspace')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('مساحة العمل الأكاديمية'), findsOneWidget);
    });
  });

  group('TeacherGradingScreen Responsive & State Tests', () {
    testWidgets('renders submissions and reset requests on ultra-narrow mobile (320px) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          child: TeacherGradingScreen(
            teacherId: 'teacher-123',
            initialSubmissions: sampleSubmissions,
            initialResetRequests: sampleResetRequests,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('طلبات إعادة الامتحان'), findsOneWidget);
      expect(find.text('يوسف أحمد عبد الرحمن'), findsOneWidget);
      expect(find.text('قبول وإعادة المحاولة'), findsOneWidget);
      expect(find.text('رفض الطلب'), findsOneWidget);

      expect(find.textContaining('تسليمات الطلاب للتصحيح'), findsOneWidget);
      expect(find.text('عمر خالد المنشاوي'), findsOneWidget);
      expect(find.text('بدء التصحيح والرصد الفوري 📝'), findsOneWidget);

      // Scroll to view second submission
      await tester.scrollUntilVisible(
        find.text('فاطمة الزهراء علي'),
        200.0,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(find.text('فاطمة الزهراء علي'), findsOneWidget);
      expect(find.text('مراجعة وتعديل التصحيح ✏️'), findsOneWidget);
    });

    testWidgets('renders empty state gracefully when no submissions or requests exist', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          child: const TeacherGradingScreen(
            teacherId: 'teacher-123',
            initialSubmissions: [],
            initialResetRequests: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('لا توجد تسليمات معلقة للتصحيح حالياً'), findsOneWidget);
      expect(find.textContaining('تم رصد جميع درجات الطلاب'), findsOneWidget);
    });
  });
}
