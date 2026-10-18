import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/parent/tabs/parent_home_tab.dart';
import 'package:brivio/apps/parent/tabs/parent_progress_tab.dart';
import 'package:brivio/apps/parent/tabs/parent_monthly_report_tab.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/features/academy/domain/models/academy_models.dart';
import 'package:brivio/features/payments/domain/models/payment_models.dart';
import 'package:brivio/features/study_workspace/domain/models/study_workspace_models.dart';

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

  const sampleChild2 = Student(
    id: 'std-203',
    profileId: 'prof-203',
    studentCode: 'BRV-7712',
    primaryBranchId: 'branch-1',
    status: 'active',
    fullName: 'مريم محمد القاضي',
    email: 'mariam@brivio.edu',
  );

  const sampleGroups = [
    GroupEntity(
      id: 'grp-phy',
      name: 'مجموعة الفيزياء 3ث',
      code: 'GRP-PHY-01',
      subjectId: 'sub-1',
      branchId: 'branch-1',
      status: 'نشطة',
    ),
  ];

  final now = DateTime.now();

  final sampleAttendance = [
    ParentAttendanceItem(
      id: 'att-1',
      classSessionId: 'sess-1',
      status: 'present',
      markedAt: now.subtract(const Duration(days: 2)),
      checkOutAt: now.subtract(const Duration(days: 2)),
      sessionDate: now.subtract(const Duration(days: 2)),
      groupName: 'مجموعة الفيزياء 3ث',
      groupCode: 'GRP-PHY-01',
    ),
    ParentAttendanceItem(
      id: 'att-2',
      classSessionId: 'sess-2',
      status: 'late',
      markedAt: now.subtract(const Duration(days: 5)),
      checkOutAt: now.subtract(const Duration(days: 5)),
      sessionDate: now.subtract(const Duration(days: 5)),
      groupName: 'مجموعة الفيزياء 3ث',
      groupCode: 'GRP-PHY-01',
    ),
    ParentAttendanceItem(
      id: 'att-3',
      classSessionId: 'sess-3',
      status: 'absent',
      markedAt: null,
      checkOutAt: null,
      sessionDate: now.subtract(const Duration(days: 8)),
      groupName: 'مجموعة الفيزياء 3ث',
      groupCode: 'GRP-PHY-01',
    ),
  ];

  const sampleLessons = [
    StudyLessonSummary(
      id: 'les-1',
      title: 'قانون أوم والدوائر الكهربية المتقدمة',
      pathName: 'الفيزياء الكهربية',
      unitName: 'الوحدة الأولى',
      progressPercentage: 100,
      estimatedMinutes: 45,
      lastPage: 10,
      totalPages: 10,
      xp: 150,
      hasPdf: true,
      hasCodePlayground: false,
    ),
    StudyLessonSummary(
      id: 'les-2',
      title: 'قوانين كيرشوف وتطبيقات شبكات التيار',
      pathName: 'الفيزياء الكهربية',
      unitName: 'الوحدة الأولى',
      progressPercentage: 65,
      estimatedMinutes: 60,
      lastPage: 6,
      totalPages: 12,
      xp: 100,
      hasPdf: true,
      hasCodePlayground: false,
    ),
  ];

  const sampleExams = [
    ParentExamItem(
      id: 'ex-1',
      title: 'اختبار نصف الفصل - فيزياء كهربية',
      description: 'اختبار تقييمي شهري شامل',
      groupId: 'grp-phy',
      groupName: 'مجموعة الفيزياء 3ث',
      durationMinutes: 60,
      maxAttempts: 1,
      status: 'completed',
      lastAttemptStatus: 'graded',
      attemptCount: 1,
      lastScore: 19.0,
      maxScore: 20.0,
    ),
  ];

  const sampleHomeworks = [
    ParentHomeworkItem(
      id: 'hw-1',
      title: 'واجب كيرشوف العملي والمسائل المركبة',
      description: 'شيت مسائل رقم 3',
      subjectName: 'الفيزياء',
      groupId: 'grp-phy',
      groupName: 'مجموعة الفيزياء 3ث',
      status: 'submitted',
      submissionStatus: 'graded',
      score: 10.0,
      maxScore: 10.0,
      dueAt: null,
      submittedAt: null,
    ),
  ];

  final sampleInvoices = [
    Invoice(
      id: 'inv-101',
      invoiceNumber: 'INV-OCT-01',
      studentId: 'std-202',
      currency: 'EGP',
      subtotalMinor: 75000,
      discountMinor: 0,
      totalMinor: 75000,
      amountPaidMinor: 0,
      status: 'issued',
      dueAt: now.add(const Duration(days: 7)),
      issuedAt: now.subtract(const Duration(days: 5)),
    ),
  ];

  final sampleSummary = FinancialSummary(
    studentId: 'std-202',
    invoiceCount: 1,
    totalDueMinor: 75000,
    totalPaidMinor: 0,
    remainingBalanceMinor: 75000,
    currency: 'EGP',
  );

  Widget createTestWidget({
    required Size screenSize,
    Student? child = sampleChild,
    List<Student>? linkedChildren,
    ValueChanged<Student>? onChildSelected,
    List<ParentAttendanceItem>? attendance,
    List<StudyLessonSummary>? lessons,
    List<ParentExamItem>? exams,
    List<ParentHomeworkItem>? homeworks,
    List<Invoice>? invoices,
    FinancialSummary? summary,
    List<GroupEntity>? groups,
    VoidCallback? onOpenReport,
    Brightness brightness = Brightness.light,
  }) {
    final effectiveAttendance = attendance ?? sampleAttendance;
    final effectiveLessons = lessons ?? sampleLessons;
    final effectiveExams = exams ?? sampleExams;
    final effectiveHomeworks = homeworks ?? sampleHomeworks;
    final effectiveInvoices = invoices ?? sampleInvoices;
    final effectiveSummary = summary ?? sampleSummary;
    final effectiveGroups = groups ?? sampleGroups;
    final effectiveLinked = linkedChildren ?? [sampleChild, sampleChild2];

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
            child: ParentMonthlyReportTab(
              child: child,
              linkedChildren: effectiveLinked,
              onChildSelected: onChildSelected ?? (_) {},
              attendance: effectiveAttendance,
              lessons: effectiveLessons,
              exams: effectiveExams,
              homeworks: effectiveHomeworks,
              invoices: effectiveInvoices,
              financialSummary: effectiveSummary,
              childGroups: effectiveGroups,
              onOpenOfficialReportCard: onOpenReport ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  group('ParentMonthlyReportTab Responsiveness & Comprehensive Functionality Tests', () {
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
        expect(find.textContaining('كود: BRV-7711'), findsOneWidget);
        expect(find.text('نسبة الحضور'), findsOneWidget);
        expect(find.text('التقدم الدراسي'), findsOneWidget);
        expect(find.text('معدل الاختبارات'), findsOneWidget);
        expect(find.text('الموقف المالي'), findsOneWidget);

        // Period Switcher pills
        expect(find.text('الشهر الحالي'), findsOneWidget);
        expect(find.text('الشهر السابق'), findsOneWidget);
        expect(find.text('السجل التراكمي'), findsOneWidget);

        // Action PDF button
        expect(
          find.textContaining('عرض وطباعة كارت التقرير الشهري المعتمد (PDF)'),
          findsOneWidget,
        );

        // Filter chips
        expect(find.text('نظرة شاملة', skipOffstage: false), findsOneWidget);
        expect(find.text('الحضور والانتظام', skipOffstage: false), findsWidgets);
        expect(find.text('التحصيل والدروس', skipOffstage: false), findsWidgets);
      },
    );

    testWidgets(
      'period switching updates metrics correctly on 375x812',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 812)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Switch to Previous Month
        final prevMonthBtn = find.text('الشهر السابق');
        await tester.tap(prevMonthBtn);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Switch to All-time Cumulative
        final allTimeBtn = find.text('السجل التراكمي');
        await tester.tap(allTimeBtn);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('السجل التراكمي الشامل'), findsWidgets);
      },
    );

    testWidgets(
      'category switching filters between overview, attendance, academics, financial, and insights on 375x812',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 812)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // 1. Overview has attendance & academics & financial sections
        expect(find.text('سجل حضور وغياب الشهر'), findsOneWidget);
        expect(find.text('التحصيل الأكاديمي والدروس'), findsOneWidget);
        expect(find.text('متابعة الرسوم والالتزامات المالية'), findsOneWidget);

        // 2. Switch to Attendance category
        final attFilter = find.text('الحضور والانتظام', skipOffstage: false).first;
        await tester.ensureVisible(attFilter);
        await tester.pumpAndSettle();
        await tester.tap(attFilter);
        await tester.pumpAndSettle();

        expect(find.text('سجل حضور وغياب الشهر'), findsOneWidget);
        expect(find.text('التحصيل الأكاديمي والدروس'), findsNothing);

        // 3. Switch to Academics category
        final acadFilter = find.text('التحصيل والدروس', skipOffstage: false).first;
        await tester.ensureVisible(acadFilter);
        await tester.pumpAndSettle();
        await tester.tap(acadFilter);
        await tester.pumpAndSettle();

        expect(find.text('التحصيل الأكاديمي والدروس'), findsOneWidget);
        expect(find.text('سجل حضور وغياب الشهر'), findsNothing);

        // 4. Switch to Financial category
        final finFilter = find.text('الرسوم والمصروفات', skipOffstage: false).first;
        await tester.ensureVisible(finFilter);
        await tester.pumpAndSettle();
        await tester.tap(finFilter);
        await tester.pumpAndSettle();

        expect(find.text('متابعة الرسوم والالتزامات المالية'), findsOneWidget);
        expect(find.text('INV-OCT-01'), findsOneWidget);

        // 5. Switch to Insights category
        final insFilter = find.text('التوجيهات والتوصيات', skipOffstage: false).first;
        await tester.ensureVisible(insFilter);
        await tester.pumpAndSettle();
        await tester.tap(insFilter);
        await tester.pumpAndSettle();

        expect(find.textContaining('توجيهات وتوصيات المتابعة الشهرية 💡'), findsOneWidget);
        expect(find.textContaining('إرشادات دعم الطالب وتشجيعه بالمنزل 🏡'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping official PDF report button invokes onOpenOfficialReportCard',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool reportOpened = false;

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(375, 812),
            onOpenReport: () => reportOpened = true,
          ),
        );
        await tester.pumpAndSettle();

        final pdfBtn = find.textContaining('عرض وطباعة كارت التقرير الشهري المعتمد (PDF)');
        expect(pdfBtn, findsOneWidget);
        await tester.tap(pdfBtn);
        await tester.pump();
        expect(reportOpened, isTrue);
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
        expect(find.text('قانون أوم والدوائر الكهربية المتقدمة'), findsOneWidget);
      },
    );

    testWidgets(
      'renders empty state gracefully without division by zero or errors',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final emptySummary = FinancialSummary(
          studentId: 'std-202',
          invoiceCount: 0,
          totalDueMinor: 0,
          totalPaidMinor: 0,
          remainingBalanceMinor: 0,
          currency: 'EGP',
        );

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(375, 812),
            attendance: const [],
            lessons: const [],
            exams: const [],
            homeworks: const [],
            invoices: const [],
            summary: emptySummary,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Verification of clean empty states
        expect(find.text('لا توجد حصص مسجلة خلال الفترة المحددة.'), findsOneWidget);
        expect(find.text('لا توجد دروس أو نتائج اختبارات مسجلة حالياً.'), findsOneWidget);
        expect(
          find.text('تمت تصفية وسداد كافة المصروفات الشهرية بنجاح ✔️'),
          findsOneWidget,
        );
      },
    );
  });
}
