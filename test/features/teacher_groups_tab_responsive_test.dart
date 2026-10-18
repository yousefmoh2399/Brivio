import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/teacher/tabs/classes_tab.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/features/academy/domain/models/academy_models.dart';
import 'package:brivio/features/academy/presentation/screens/teacher_groups_screen.dart';

void main() {
  const sampleBranches = [
    Branch(
      id: 'br-1',
      name: 'الفرع الرئيسي - مدينة نصر',
      code: 'NASR-01',
      status: 'active',
    ),
    Branch(
      id: 'br-2',
      name: 'فرع المهندسين',
      code: 'MOH-02',
      status: 'active',
    ),
  ];

  const sampleSubjects = [
    SubjectEntity(
      id: 'sub-1',
      name: 'الفيزياء الحديثة 3ث',
      code: 'PHYS-300',
      status: 'active',
    ),
    SubjectEntity(
      id: 'sub-2',
      name: 'الكيمياء العضوية 2ث',
      code: 'CHEM-200',
      status: 'active',
    ),
  ];

  const sampleGroups = [
    GroupEntity(
      id: 'grp-1',
      name: 'مجموعة السبت والثلاثاء - فيزياء 3ث (نخبة)',
      code: 'PHY-301',
      subjectId: 'sub-1',
      branchId: 'br-1',
      maxCapacity: 30,
      status: 'active',
    ),
    GroupEntity(
      id: 'grp-2',
      name: 'مجموعة الأحد والأربعاء - كيمياء 2ث',
      code: 'CHM-202',
      subjectId: 'sub-2',
      branchId: 'br-2',
      maxCapacity: 25,
      status: 'active',
    ),
    GroupEntity(
      id: 'grp-3',
      name: 'مجموعة المراجعة النهائية المكثفة للعام السابق',
      code: 'REV-101',
      subjectId: 'sub-1',
      branchId: 'br-1',
      maxCapacity: 40,
      status: 'archived',
    ),
  ];

  final sampleEnrolledCounts = {
    'grp-1': 26,
    'grp-2': 25,
    'grp-3': 12,
  };

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
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('Teacher Groups & Classes Tab Responsive Architecture Tests', () {
    testWidgets(
      'View 1: Ultra-narrow 320x640 screen renders without RenderFlex overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final groupsScreen = TeacherGroupsScreen(
          teacherId: 'teacher-101',
          initialGroups: sampleGroups,
          initialSubjects: sampleSubjects,
          initialBranches: sampleBranches,
          initialEnrolledCounts: sampleEnrolledCounts,
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: ClassesTab(
              teacherId: 'teacher-101',
              groupsScreen: groupsScreen,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify Header renders
        expect(find.text('إدارة المجموعات والحصص'), findsOneWidget);
        expect(find.text('الأكاديمية والسنتر'), findsOneWidget);
        expect(find.text('مزامنة فورية'), findsOneWidget);

        // 2. Verify TabBar items
        expect(find.text('المجموعات'), findsOneWidget);
        expect(find.text('جدول الحصص'), findsOneWidget);
        expect(find.text('المناهج والدروس'), findsOneWidget);

        // 3. Verify KPI cards
        expect(find.text('إجمالي المجموعات'), findsOneWidget);
        expect(find.text('المجموعات النشطة'), findsOneWidget);
        expect(find.text('الطلاب المقيدين'), findsOneWidget);
        expect(find.text('المجموعات المؤرشفة'), findsOneWidget);
        expect(find.text('3'), findsOneWidget); // total groups count
        expect(find.text('2'), findsOneWidget); // active count
        expect(find.text('63'), findsOneWidget); // total enrolled: 26+25+12 = 63

        // 4. Verify group cards and badges
        expect(find.text('مجموعة السبت والثلاثاء - فيزياء 3ث (نخبة)'), findsOneWidget);
        expect(find.text('كود: PHY-301'), findsOneWidget);
        expect(find.text('26 من 30 طالب'), findsOneWidget);

        // 5. Verify no RenderFlex overflow was thrown
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'View 2: Standard Mobile 375x812 supports search, filtering, and tab switching',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final groupsScreen = TeacherGroupsScreen(
          teacherId: 'teacher-101',
          initialGroups: sampleGroups,
          initialSubjects: sampleSubjects,
          initialBranches: sampleBranches,
          initialEnrolledCounts: sampleEnrolledCounts,
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: ClassesTab(
              teacherId: 'teacher-101',
              groupsScreen: groupsScreen,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check filter chips
        expect(find.text('الكل (3)'), findsOneWidget);
        expect(find.text('النشطة (2)'), findsOneWidget);
        expect(find.text('المؤرشفة (1)'), findsOneWidget);

        // Tap 'النشطة' filter chip
        await tester.ensureVisible(find.text('النشطة (2)'));
        await tester.tap(find.text('النشطة (2)'));
        await tester.pumpAndSettle();

        expect(find.text('مجموعة السبت والثلاثاء - فيزياء 3ث (نخبة)'), findsOneWidget);
        expect(find.text('مجموعة الأحد والأربعاء - كيمياء 2ث'), findsOneWidget);
        expect(find.text('مجموعة المراجعة النهائية المكثفة للعام السابق'), findsNothing);

        // Tap 'المؤرشفة' filter chip
        await tester.ensureVisible(find.text('المؤرشفة (1)'));
        await tester.tap(find.text('المؤرشفة (1)'));
        await tester.pumpAndSettle();

        expect(find.text('مجموعة السبت والثلاثاء - فيزياء 3ث (نخبة)'), findsNothing);
        expect(find.text('مجموعة المراجعة النهائية المكثفة للعام السابق'), findsOneWidget);

        // Tap 'الكل (3)' to reset
        await tester.ensureVisible(find.text('الكل (3)'));
        await tester.tap(find.text('الكل (3)'));
        await tester.pumpAndSettle();

        // Search for 'CHM'
        final searchField = find.byType(TextField);
        expect(searchField, findsOneWidget);
        await tester.enterText(searchField, 'CHM');
        await tester.pumpAndSettle();

        expect(find.text('مجموعة الأحد والأربعاء - كيمياء 2ث'), findsOneWidget);
        expect(find.text('مجموعة السبت والثلاثاء - فيزياء 3ث (نخبة)'), findsNothing);

        // Clear search
        await tester.enterText(searchField, '');
        await tester.pumpAndSettle();
        expect(find.text('مجموعة السبت والثلاثاء - فيزياء 3ث (نخبة)'), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'View 3: Tablet / Desktop 1024x768 renders grid layout and dialog cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final groupsScreen = TeacherGroupsScreen(
          teacherId: 'teacher-101',
          initialGroups: sampleGroups,
          initialSubjects: sampleSubjects,
          initialBranches: sampleBranches,
          initialEnrolledCounts: sampleEnrolledCounts,
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: ClassesTab(
              teacherId: 'teacher-101',
              groupsScreen: groupsScreen,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check wide layout displays GridView for group cards
        expect(find.byType(GridView), findsOneWidget);
        expect(find.text('إنشاء مجموعة جديدة 👥'), findsOneWidget);

        // Tap Floating Action Button to open Create Group Dialog
        await tester.tap(find.text('إنشاء مجموعة جديدة 👥'));
        await tester.pumpAndSettle();

        // Verify Dialog opened and rendered
        expect(find.text('إنشاء مجموعة دراسية جديدة'), findsOneWidget);
        expect(find.text('اسم المجموعة *'), findsOneWidget);
        expect(find.text('كود المجموعة *'), findsOneWidget);
        expect(find.text('المادة الدراسية *'), findsOneWidget);
        expect(find.text('الفرع / السنتر *'), findsOneWidget);
        expect(find.text('السعة القصوى (عدد الطلاب) *'), findsOneWidget);
        expect(find.text('إلغاء'), findsOneWidget);
        expect(find.text('إنشاء المجموعة'), findsOneWidget);

        // Close dialog
        await tester.tap(find.text('إلغاء'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'View 4: Dark mode theme renders with high contrast and zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final groupsScreen = TeacherGroupsScreen(
          teacherId: 'teacher-101',
          initialGroups: sampleGroups,
          initialSubjects: sampleSubjects,
          initialBranches: sampleBranches,
          initialEnrolledCounts: sampleEnrolledCounts,
        );

        await tester.pumpWidget(
          buildTestWidget(
            themeMode: ThemeMode.dark,
            child: ClassesTab(
              teacherId: 'teacher-101',
              groupsScreen: groupsScreen,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('إدارة المجموعات والحصص'), findsOneWidget);
        expect(find.text('مجموعة السبت والثلاثاء - فيزياء 3ث (نخبة)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'View 5: Empty states render gracefully without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final emptyGroupsScreen = TeacherGroupsScreen(
          teacherId: 'teacher-101',
          initialGroups: const [],
          initialSubjects: const [],
          initialBranches: const [],
          initialEnrolledCounts: const {},
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: ClassesTab(
              teacherId: 'teacher-101',
              groupsScreen: emptyGroupsScreen,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('لا توجد مجموعات دراسية مسندة إليك حالياً'), findsOneWidget);
        expect(find.text('إنشاء أول مجموعة دراسية'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'View 6: Search with no results shows reset action and resets search on click',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final groupsScreen = TeacherGroupsScreen(
          teacherId: 'teacher-101',
          initialGroups: sampleGroups,
          initialSubjects: sampleSubjects,
          initialBranches: sampleBranches,
          initialEnrolledCounts: sampleEnrolledCounts,
        );

        await tester.pumpWidget(
          buildTestWidget(
            child: ClassesTab(
              teacherId: 'teacher-101',
              groupsScreen: groupsScreen,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Search for non-existent text
        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'غير_موجود_نهائيا');
        await tester.pumpAndSettle();

        expect(find.text('لم يتم العثور على مجموعات مطابقة'), findsOneWidget);
        expect(find.text('إعادة تعيين البحث'), findsOneWidget);

        // Tap reset button
        await tester.tap(find.text('إعادة تعيين البحث'));
        await tester.pumpAndSettle();

        // All groups should reappear
        expect(find.text('مجموعة السبت والثلاثاء - فيزياء 3ث (نخبة)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
