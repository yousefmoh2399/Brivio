import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/parent/tabs/parent_home_tab.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/features/academy/domain/models/academy_models.dart';
import 'package:brivio/features/payments/domain/models/payment_models.dart';
import 'package:brivio/features/study_workspace/domain/models/study_workspace_models.dart';

void main() {
  const sampleChild1 = Student(
    id: 'std-1',
    profileId: 'prof-1',
    studentCode: 'BRV-8821',
    primaryBranchId: 'branch-1',
    status: 'active',
    fullName: 'عمر طارق إبراهيم',
    email: 'omar@brivio.edu',
  );

  const sampleChild2 = Student(
    id: 'std-2',
    profileId: 'prof-2',
    studentCode: 'BRV-9932',
    primaryBranchId: 'branch-1',
    status: 'active',
    fullName: 'مريم طارق إبراهيم',
    email: 'mariam@brivio.edu',
  );

  final sampleFinancialSummary = FinancialSummary(
    studentId: 'std-1',
    currency: 'EGP',
    totalDueMinor: 100000,
    totalPaidMinor: 65000,
    remainingBalanceMinor: 35000,
    invoiceCount: 2,
  );

  final List<Invoice> sampleInvoices = [
    Invoice(
      id: 'inv-1',
      studentId: 'std-1',
      invoiceNumber: 'INV-2026-001',
      subtotalMinor: 50000,
      discountMinor: 0,
      totalMinor: 50000,
      currency: 'EGP',
      status: 'paid',
      issuedAt: DateTime.now().subtract(const Duration(days: 30)),
      dueAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    Invoice(
      id: 'inv-2',
      studentId: 'std-1',
      invoiceNumber: 'INV-2026-002',
      subtotalMinor: 50000,
      discountMinor: 0,
      totalMinor: 50000,
      currency: 'EGP',
      status: 'overdue',
      issuedAt: DateTime.now().subtract(const Duration(days: 10)),
      dueAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  const sampleGroups = [
    GroupEntity(
      id: 'grp-1',
      name: 'مجموعة النخبة للثانوية العامة',
      code: 'GRP-PHY-01',
      subjectId: 'sub-1',
      branchId: 'branch-1',
      status: 'نشطة',
    ),
    GroupEntity(
      id: 'grp-2',
      name: 'مجموعة الرياضيات المتقدمة',
      code: 'GRP-MTH-02',
      subjectId: 'sub-2',
      branchId: 'branch-1',
      status: 'نشطة',
    ),
  ];

  final sampleNextClass = ParentScheduleItem(
    id: 'sch-1',
    subjectName: 'اللغة العربية واللغويات',
    groupName: 'مجموعة النخبة',
    teacherName: 'أ. محمد عبد الفتاح',
    location: 'القاعة الكبرى (مدرج 1)',
    startTime: '16:00',
    endTime: '18:00',
    sessionDate: DateTime.now().add(const Duration(hours: 3)),
    status: 'scheduled',
  );

  const sampleSnapshot = StudentLearningSnapshot(
    availableLessons: [
      StudyLessonSummary(
        id: 'lsn-1',
        title: 'شرح قواعد النحو والإعراب المتقدم',
        unitName: 'الوحدة الأولى',
        pathName: 'مسار اللغة العربية',
        progressPercentage: 80,
        estimatedMinutes: 45,
        lastPage: 1,
        totalPages: 10,
        timeSpentSeconds: 3600,
        xp: 100,
        hasPdf: true,
        hasCodePlayground: false,
      ),
    ],
    metrics: [],
    enrolledGroupCount: 2,
  );

  Widget createTestWidget({
    required Size screenSize,
    List<ParentAttendanceItem>? attendance,
    Student? selectedChild,
    List<Student>? children,
    ParentScheduleItem? nextClass,
    bool isDark = false,
  }) {
    final activeAttendance = attendance ??
        [
          ParentAttendanceItem(
            id: 'att-1',
            classSessionId: 'sess-1',
            status: 'present',
            markedAt: DateTime.now().subtract(const Duration(minutes: 45)),
            sessionDate: DateTime.now(),
            groupName: 'مجموعة النخبة',
            groupCode: 'GRP-01',
          ),
        ];

    return MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: ParentHomeTab(
              child: selectedChild ?? sampleChild1,
              linkedChildren: children ?? [sampleChild1, sampleChild2],
              onChildSelected: (_) {},
              onLinkNewChild: () {},
              attendance: activeAttendance,
              learningSnapshot: sampleSnapshot,
              financialSummary: sampleFinancialSummary,
              invoices: sampleInvoices,
              childGroups: sampleGroups,
              unreadCount: 3,
              nextClassSession: nextClass ?? sampleNextClass,
              onExcuseRequest: () {},
              onOpenSchedule: () {},
              onOpenAttendance: () {},
              onOpenProgress: () {},
              onOpenPayments: () {},
              onOpenNotifications: () {},
              onOpenWhatsApp: () {},
            ),
          ),
        ),
      ),
    );
  }

  group('ParentHomeTab Responsiveness & Comprehensive Functionality Tests', () {
    testWidgets(
      'renders with zero RenderFlex overflow on narrow 320x640 mobile screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(screenSize: const Size(320, 640)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);

        // Verify Core Components Rendered
        expect(find.text('التبديل بين الأبناء:'), findsOneWidget);
        expect(find.text('عمر طارق إبراهيم'), findsWidgets);
        expect(find.text('مريم طارق إبراهيم'), findsOneWidget);
        expect(find.text('جدول الحصص'), findsOneWidget);
        expect(find.text('سجل الحضور'), findsOneWidget);
        expect(find.text('الواجبات والدرجات'), findsOneWidget);
        expect(find.text('خدمة أولياء الأمور'), findsOneWidget);
        expect(find.text('مستوى التقدم الدراسي'), findsOneWidget);
        expect(find.text('نسبة الحضور والالتزام'), findsOneWidget);
        expect(find.text('المستحقات المتبقية'), findsOneWidget);
        expect(find.text('تنبيهات غير مقروءة'), findsOneWidget);
      },
    );

    testWidgets(
      'renders on standard 375x812 phone screen with present status and zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(screenSize: const Size(375, 812)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);

        // Verify presence radar status
        expect(
          find.text('الطالب متواجد في القاعة الدراسية الآن 🏫'),
          findsOneWidget,
        );
        expect(find.text('داخل السنتر الآن 🟢'), findsOneWidget);
        expect(
          find.textContaining('حضور موثق بالبوابة الإلكترونية الذكية للسنتر'),
          findsOneWidget,
        );

        // Verify next class banner
        expect(
          find.text('اللغة العربية واللغويات (مجموعة النخبة)'),
          findsOneWidget,
        );
        expect(find.text('القاعة الكبرى (مدرج 1)'), findsOneWidget);
      },
    );

    testWidgets(
      'renders absent status with excuse button cleanly and with zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final absentAttendance = [
          ParentAttendanceItem(
            id: 'att-absent',
            classSessionId: 'sess-2',
            status: 'absent',
            markedAt: null,
            sessionDate: DateTime.now(),
            groupName: 'مجموعة الفيزياء 3ث',
            groupCode: 'GRP-PHY',
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(320, 640),
            attendance: absentAttendance,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);

        expect(find.text('تنبيه غياب: لم يسجل حضوراً اليوم ⚠️'), findsOneWidget);
        expect(find.text('غياب غير مسجل بعذر 🔴'), findsOneWidget);
        expect(
          find.text('تقديم عذر غياب فوري مع تقرير طبي أو ورقي 📝'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders on tablet/desktop 1024x768 with expanded layout and zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(screenSize: const Size(1024, 768)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);

        // Verify active groups section
        expect(find.text('مجموعة النخبة للثانوية العامة'), findsOneWidget);
        expect(find.text('مجموعة الرياضيات المتقدمة'), findsOneWidget);
      },
    );
  });
}
