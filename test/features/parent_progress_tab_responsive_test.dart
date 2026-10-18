import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/parent/tabs/parent_home_tab.dart';
import 'package:brivio/apps/parent/tabs/parent_progress_tab.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/features/academy/domain/models/academy_models.dart';
import 'package:brivio/features/study_workspace/domain/models/study_workspace_models.dart';

void main() {
  const sampleChild = Student(
    id: 'std-101',
    profileId: 'prof-101',
    studentCode: 'BRV-8821',
    primaryBranchId: 'branch-1',
    status: 'active',
    fullName: 'عمر طارق إبراهيم',
    email: 'omar@brivio.edu',
  );

  const sampleGroups = [
    GroupEntity(
      id: 'grp-1',
      name: 'مجموعة الفيزياء 3ث (نخبة)',
      code: 'GRP-PHY-01',
      subjectId: 'sub-1',
      branchId: 'branch-1',
      status: 'نشطة',
    ),
    GroupEntity(
      id: 'grp-2',
      name: 'مجموعة الرياضيات التطبيقية',
      code: 'GRP-MTH-02',
      subjectId: 'sub-2',
      branchId: 'branch-1',
      status: 'نشطة',
    ),
  ];

  final sampleExams = [
    const ParentExamItem(
      id: 'exam-1',
      title: 'اختبار الفصل الأول: الديناميكا والحركة',
      description: 'اختبار شامل على قوانين نيوتن وتطبيقات الحركة',
      groupId: 'grp-1',
      groupName: 'مجموعة الفيزياء 3ث (نخبة)',
      durationMinutes: 45,
      maxAttempts: 2,
      status: 'published',
      lastAttemptStatus: 'graded',
      attemptCount: 1,
      lastScore: 48,
      maxScore: 50,
    ),
    const ParentExamItem(
      id: 'exam-2',
      title: 'اختبار التفاضل والتكامل النصفي',
      description: 'اختبار نصف الفصل الدراسي',
      groupId: 'grp-2',
      groupName: 'مجموعة الرياضيات التطبيقية',
      durationMinutes: 60,
      maxAttempts: 1,
      status: 'published',
      lastAttemptStatus: 'submitted',
      attemptCount: 1,
      lastScore: null,
      maxScore: 60,
    ),
  ];

  final sampleHomework = [
    ParentHomeworkItem(
      id: 'hw-1',
      title: 'واجب المسائل المقالية على قانون الجذب العام',
      description: 'حل المسائل من صفحة 30 إلى 34',
      subjectId: 'sub-1',
      subjectName: 'فيزياء',
      groupId: 'grp-1',
      groupName: 'مجموعة الفيزياء 3ث (نخبة)',
      dueAt: DateTime.now().add(const Duration(days: 3)),
      maxScore: 20,
      status: 'graded',
      submissionStatus: 'graded',
      score: 19,
      submittedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    ParentHomeworkItem(
      id: 'hw-2',
      title: 'تكليف تدريبات التفاضل والتكامل المستمر',
      description: 'مسائل الواجب الأسبوعي الخامس',
      subjectId: 'sub-2',
      subjectName: 'رياضيات',
      groupId: 'grp-2',
      groupName: 'مجموعة الرياضيات التطبيقية',
      dueAt: DateTime.now().add(const Duration(days: 1)),
      maxScore: 15,
      status: 'pending',
      submissionStatus: null,
      score: null,
      submittedAt: null,
    ),
  ];

  final sampleAttendance = [
    ParentAttendanceItem(
      id: 'att-1',
      classSessionId: 'sess-1',
      status: 'present',
      markedAt: DateTime.now().subtract(const Duration(hours: 1)),
      sessionDate: DateTime.now(),
      groupName: 'مجموعة الفيزياء 3ث (نخبة)',
      groupCode: 'GRP-PHY-01',
    ),
    ParentAttendanceItem(
      id: 'att-2',
      classSessionId: 'sess-2',
      status: 'present',
      markedAt: DateTime.now().subtract(const Duration(days: 2)),
      sessionDate: DateTime.now().subtract(const Duration(days: 2)),
      groupName: 'مجموعة الرياضيات التطبيقية',
      groupCode: 'GRP-MTH-02',
    ),
  ];

  const sampleSnapshot = StudentLearningSnapshot(
    availableLessons: [
      StudyLessonSummary(
        id: 'les-1',
        title: 'الدرس الأول: قوانين الحركة الخطية والسرعة المتجهة',
        pathName: 'الفيزياء الحديثة',
        unitName: 'الوحدة الأولى',
        totalPages: 24,
        lastPage: 18,
        progressPercentage: 75,
        estimatedMinutes: 45,
        timeSpentSeconds: 3600,
        xp: 100,
        hasPdf: true,
        hasCodePlayground: false,
      ),
      StudyLessonSummary(
        id: 'les-2',
        title: 'الدرس الثاني: حساب النهايات والاشتقاق الدالي',
        pathName: 'الرياضيات البحتة',
        unitName: 'الوحدة الثانية',
        totalPages: 20,
        lastPage: 20,
        progressPercentage: 100,
        estimatedMinutes: 60,
        timeSpentSeconds: 5400,
        xp: 150,
        hasPdf: false,
        hasCodePlayground: false,
      ),
    ],
    metrics: [
      StudyMetric(
        label: 'معدل الحضور والالتزام',
        value: '95%',
        helper: 'معدل ممتاز',
      ),
      StudyMetric(
        label: 'إجمالي ساعات المذاكرة',
        value: '14 ساعة',
        helper: 'هذا الشهر',
      ),
      StudyMetric(
        label: 'الدروس المنجزة',
        value: '12 درس',
        helper: 'منهج الفصل',
      ),
      StudyMetric(
        label: 'معدل درجات الاختبارات',
        value: '92%',
        helper: 'تقدير امتياز',
      ),
    ],
    enrolledGroupCount: 2,
  );

  Widget createTestWidget({
    required Size screenSize,
    Student? child = sampleChild,
    StudentLearningSnapshot? snapshot = sampleSnapshot,
    List<ParentExamItem>? exams,
    List<ParentHomeworkItem>? homework,
    List<GroupEntity>? groups,
    List<ParentAttendanceItem>? attendance,
    VoidCallback? onOpenReportCard,
    VoidCallback? onOpenAssignments,
    ValueChanged<ParentExamItem>? onReviewExam,
  }) {
    final effectiveExams = exams ?? sampleExams;
    final effectiveHomework = homework ?? sampleHomework;
    final effectiveGroups = groups ?? sampleGroups;
    final effectiveAttendance = attendance ?? sampleAttendance;
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
        brightness: Brightness.light,
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: screenSize,
          textScaler: const TextScaler.linear(1.0),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: ParentProgressTab(
              child: child,
              linkedChildren: [sampleChild],
              onChildSelected: (_) {},
              learningSnapshot: snapshot,
              examItems: effectiveExams,
              homeworkItems: effectiveHomework,
              childGroups: effectiveGroups,
              attendance: effectiveAttendance,
              onOpenAssignments: onOpenAssignments ?? () {},
              onOpenReportCard: onOpenReportCard ?? () {},
              onReviewExam: onReviewExam ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  group('ParentProgressTab Responsiveness & Comprehensive Functionality Tests', () {
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

        // Verify Core Hero details
        expect(find.text('عمر طارق إبراهيم'), findsWidgets);
        expect(find.textContaining('كود الطالب: BRV-8821'), findsOneWidget);
        expect(find.text('عرض الشهادة وكشف التقرير الشهري المعتمد 📜'), findsOneWidget);

        // Verify Category Switcher
        expect(find.text('نظرة شاملة', skipOffstage: false), findsOneWidget);
        expect(find.text('الاختبارات', skipOffstage: false), findsOneWidget);
        expect(find.text('الواجبات', skipOffstage: false), findsOneWidget);
        expect(find.text('المناهج والدروس', skipOffstage: false), findsOneWidget);

        // Verify Section Titles
        expect(find.text('تحليل الأداء حسب المواد الدراسية'), findsOneWidget);
        expect(find.text('الاختبارات والتقييمات الدورية'), findsOneWidget);
        expect(find.text('الواجبات والتكليفات المدرسية'), findsOneWidget);
        expect(find.text('الدروس والمناهج المنشورة'), findsOneWidget);
      },
    );

    testWidgets(
      'switches categories smoothly and filters items correctly on 375x812 phone screen',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool reportCardOpened = false;
        ParentExamItem? reviewedExam;

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(375, 812),
            onOpenReportCard: () => reportCardOpened = true,
            onReviewExam: (exam) => reviewedExam = exam,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);

        // Tap Report Card Button
        await tester.tap(find.text('عرض الشهادة وكشف التقرير الشهري المعتمد 📜'));
        await tester.pump();
        expect(reportCardOpened, isTrue);

        // Switch to "الاختبارات" category
        await tester.tap(find.text('الاختبارات'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // When in exams category, only exams section should show
        expect(find.text('الاختبارات والتقييمات الدورية'), findsOneWidget);
        expect(find.text('تحليل الأداء حسب المواد الدراسية'), findsNothing);

        // Tap Review Exam Button in exams category
        final reviewButtons = find.text('مراجعة نموذج الإجابات وتصحيح المعلم 🔍');
        expect(reviewButtons, findsWidgets);
        await tester.tap(reviewButtons.first);
        await tester.pump();
        expect(reviewedExam?.id, equals('exam-1'));

        // Switch back to "نظرة شاملة"
        await tester.tap(find.text('نظرة شاملة'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('تحليل الأداء حسب المواد الدراسية'), findsOneWidget);
        expect(find.text('الدروس والمناهج المنشورة'), findsOneWidget);
      },
    );

    testWidgets(
      'renders on tablet/desktop 1024x768 with expanded metrics and zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(screenSize: const Size(1024, 768)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);

        // Verify subjects breakdown in expanded view
        expect(find.text('مجموعة الفيزياء 3ث (نخبة)'), findsWidgets);
        expect(find.text('مجموعة الرياضيات التطبيقية'), findsWidgets);
      },
    );

    testWidgets(
      'renders empty state cleanly when student has no exams or homework',
      (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(360, 720),
            exams: const [],
            homework: const [],
            snapshot: const StudentLearningSnapshot(
              availableLessons: [],
              metrics: [],
              enrolledGroupCount: 0,
            ),
            groups: const [],
            attendance: const [],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text('بيانات التقييم قيد التجميع والاعتماد ⏳'), findsOneWidget);
        expect(find.text('لا توجد اختبارات مسجلة لهذا الطالب حتى الآن.'), findsOneWidget);
        expect(
          find.text('لا توجد واجبات أو تكليفات مدرسية مسجلة لهذا الطالب حالياً.'),
          findsOneWidget,
        );
      },
    );
  });
}
