import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/parent/tabs/parent_attendance_tab.dart';
import 'package:brivio/apps/parent/tabs/parent_home_tab.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/features/academy/domain/models/academy_models.dart';

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

  const sampleGroups = [
    GroupEntity(
      id: 'grp-phy',
      name: 'مجموعة الفيزياء 3ث',
      code: 'GRP-PHY-01',
      subjectId: 'sub-1',
      branchId: 'branch-1',
      status: 'نشطة',
    ),
    GroupEntity(
      id: 'grp-chm',
      name: 'مجموعة الكيمياء العامة',
      code: 'GRP-CHM-02',
      subjectId: 'sub-2',
      branchId: 'branch-1',
      status: 'نشطة',
    ),
  ];

  final sampleAttendance = [
    ParentAttendanceItem(
      id: 'att-1',
      classSessionId: 'sess-1',
      status: 'present',
      markedAt: DateTime.now().subtract(const Duration(hours: 2)),
      checkOutAt: DateTime.now().subtract(const Duration(minutes: 10)),
      sessionDate: DateTime.now(),
      groupName: 'مجموعة الفيزياء 3ث',
      groupCode: 'GRP-PHY-01',
    ),
    ParentAttendanceItem(
      id: 'att-2',
      classSessionId: 'sess-2',
      status: 'absent',
      markedAt: null,
      checkOutAt: null,
      sessionDate: DateTime.now().subtract(const Duration(days: 2)),
      groupName: 'مجموعة الكيمياء العامة',
      groupCode: 'GRP-CHM-02',
    ),
    ParentAttendanceItem(
      id: 'att-3',
      classSessionId: 'sess-3',
      status: 'late',
      markedAt: DateTime.now().subtract(const Duration(days: 4, hours: 1)),
      checkOutAt: DateTime.now().subtract(const Duration(days: 4)),
      sessionDate: DateTime.now().subtract(const Duration(days: 4)),
      groupName: 'مجموعة الفيزياء 3ث',
      groupCode: 'GRP-PHY-01',
    ),
  ];

  final sampleLeaves = [
    ParentLeaveItem(
      id: 'leave-1',
      reason: 'عذر مرضي لوجود نزلة برد حادة مرفق التقرير الطبي',
      status: 'approved',
      submittedAt: DateTime.now().subtract(const Duration(days: 3)),
      sessionDate: DateTime.now().subtract(const Duration(days: 2)),
      groupName: 'مجموعة الكيمياء العامة',
    ),
    ParentLeaveItem(
      id: 'leave-2',
      reason: 'سفر عائلي طارئ خارج المحافظة',
      status: 'pending',
      submittedAt: DateTime.now().subtract(const Duration(days: 1)),
      sessionDate: DateTime.now(),
      groupName: 'مجموعة الفيزياء 3ث',
    ),
  ];

  Widget createTestWidget({
    required Size screenSize,
    Student? child = sampleChild,
    List<ParentAttendanceItem>? attendance,
    List<ParentLeaveItem>? leaves,
    List<GroupEntity>? groups,
    VoidCallback? onExcuseRequest,
  }) {
    final effectiveAttendance = attendance ?? sampleAttendance;
    final effectiveLeaves = leaves ?? sampleLeaves;
    final effectiveGroups = groups ?? sampleGroups;

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
            child: ParentAttendanceTab(
              child: child,
              linkedChildren: [sampleChild],
              onChildSelected: (_) {},
              attendance: effectiveAttendance,
              leaveRequests: effectiveLeaves,
              childGroups: effectiveGroups,
              onExcuseRequest: onExcuseRequest ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  group('ParentAttendanceTab Responsiveness & Comprehensive Functionality Tests', () {
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

        // Verify Hero details
        expect(find.text('يوسف محمد القاضي'), findsOneWidget);
        expect(find.textContaining('كود الطالب: BRV-7711'), findsOneWidget);
        expect(find.text('تقديم عذر أو إذن غياب رسمي مسبق 📝'), findsOneWidget);

        // Verify Category Switcher
        expect(find.text('السجل الكامل', skipOffstage: false), findsOneWidget);
        expect(find.text('الحضور', skipOffstage: false), findsWidgets);
        expect(find.text('الغياب', skipOffstage: false), findsWidgets);
        expect(find.text('طلبات الأعذار', skipOffstage: false), findsOneWidget);

        // Verify Section Titles & items
        expect(find.text('سجل الحصص والتواجد بالسنتر'), findsOneWidget);
        expect(find.text('مجموعة الفيزياء 3ث'), findsWidgets);
        expect(find.text('مجموعة الكيمياء العامة'), findsWidgets);
      },
    );

    testWidgets(
      'switches categories smoothly and handles excuse requests on 375x812 screen',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        int excuseRequestTriggered = 0;

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(375, 812),
            onExcuseRequest: () => excuseRequestTriggered++,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);

        // Tap Excuse button in hero
        await tester.tap(find.text('تقديم عذر أو إذن غياب رسمي مسبق 📝'));
        await tester.pump();
        expect(excuseRequestTriggered, equals(1));

        // Tap quick excuse on absent card (present in full view in "السجل الكامل")
        final absentCardButton = find.text('تقديم عذر رسمي لهذه الحصة 📝');
        expect(absentCardButton, findsOneWidget);
        await tester.tap(absentCardButton);
        await tester.pump();
        expect(excuseRequestTriggered, equals(2));

        // Switch to "الحضور" category
        await tester.tap(find.widgetWithText(InkWell, 'الحضور'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('سجل الحصص المحضورة'), findsOneWidget);
        expect(find.text('حاضر في الموعد 🟢'), findsOneWidget);
        expect(find.text('تأخر عن البداية 🟡'), findsOneWidget);

        // Switch back to "السجل الكامل"
        await tester.tap(find.widgetWithText(InkWell, 'السجل الكامل'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('سجل الحصص والتواجد بالسنتر'), findsOneWidget);
      },
    );

    testWidgets(
      'renders on tablet/desktop 1024x768 with group filter chips and zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(screenSize: const Size(1024, 768)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);

        // Verify Group Chips
        expect(find.text('جميع المواد والمجموعات'), findsOneWidget);

        // Select specific group
        await tester.tap(find.text('مجموعة الفيزياء 3ث').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Verify only physics items are shown
        expect(find.text('مجموعة الفيزياء 3ث'), findsWidgets);
      },
    );

    testWidgets(
      'renders clean empty state when there are no attendance records',
      (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(360, 720),
            attendance: const [],
            leaves: const [],
            groups: const [],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text('سجل الحضور قيد التحديث للفصل الجديد'), findsOneWidget);
        expect(find.text('لا توجد حصص مسجلة في هذا السجل حالياً.'), findsOneWidget);
      },
    );
  });
}
