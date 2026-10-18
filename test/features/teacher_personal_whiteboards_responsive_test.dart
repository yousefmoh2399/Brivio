import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/features/study_workspace/domain/models/personal_whiteboard_item.dart';
import 'package:brivio/features/study_workspace/presentation/screens/personal_whiteboards_hub_screen.dart';
import 'package:brivio/features/study_workspace/presentation/screens/student_personal_board_screen.dart';

void main() {
  final sampleBoards = [
    PersonalWhiteboardItem(
      id: 'board-1',
      userId: 'teacher-101',
      title: 'تحضير درس قوانين نيوتن للحركة فيزياء',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      bgTheme: 'gridMath',
      strokeCount: 42,
    ),
    PersonalWhiteboardItem(
      id: 'board-2',
      userId: 'teacher-101',
      title: 'ملاحظات كيمياء عضوية ومعادلات تفاعل',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
      bgTheme: 'linedNotebook',
      strokeCount: 18,
    ),
    PersonalWhiteboardItem(
      id: 'board-3',
      userId: 'teacher-101',
      title: 'مسودة رسم الدائرة الكهربائية والمقاومات',
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      bgTheme: 'darkSlate',
      strokeCount: 75,
    ),
    PersonalWhiteboardItem(
      id: 'board-4',
      userId: 'teacher-101',
      title: 'خريطة ذهنية لقواعد النحو والإعراب',
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      bgTheme: 'blankWhite',
      strokeCount: 29,
    ),
  ];

  Widget buildTestWidget({
    Size screenSize = const Size(375, 812),
    ThemeMode themeMode = ThemeMode.light,
    List<PersonalWhiteboardItem>? boards,
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
          child: PersonalWhiteboardsHubScreen(
            userId: 'teacher-101',
            role: role,
            initialBoards: boards ?? sampleBoards,
          ),
        ),
      ),
    );
  }

  group('PersonalWhiteboardsHubScreen Responsive & Feature Tests', () {
    testWidgets('renders cleanly on ultra-compact mobile (320x640) with zero overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(320, 640)));
      await tester.pumpAndSettle();

      // Check header title & hero
      expect(find.text('سبوراتي ومسودات التحضير'), findsOneWidget);
      expect(find.text('استوديو التحضير'), findsOneWidget);
      expect(find.text('مساحة مشفرة 🔒'), findsOneWidget);

      // Check KPI chips
      expect(find.text('السبورات: '), findsOneWidget);
      expect(find.text('4'), findsWidgets);

      // Check board card in initial viewport
      expect(find.text('تحضير درس قوانين نيوتن للحركة فيزياء'), findsOneWidget);

      // No overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on standard mobile (375x812)', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(375, 812)));
      await tester.pumpAndSettle();

      expect(find.text('سبوراتي ومسودات الدروس 🎨'), findsOneWidget);
      expect(find.text('4 أنماط'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly on desktop screen (1024x768)', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(1024, 768)));
      await tester.pumpAndSettle();

      expect(find.text('سبوراتي ومسودات التحضير'), findsOneWidget);
      expect(find.text('تحضير درس قوانين نيوتن للحركة فيزياء'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('filters board list using real-time search', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('تحضير درس قوانين نيوتن للحركة فيزياء'), findsOneWidget);
      expect(find.text('ملاحظات كيمياء عضوية ومعادلات تفاعل'), findsOneWidget);

      // Enter search term
      await tester.enterText(find.byType(TextField), 'نيوتن');
      await tester.pumpAndSettle();

      expect(find.text('تحضير درس قوانين نيوتن للحركة فيزياء'), findsOneWidget);
      expect(find.text('ملاحظات كيمياء عضوية ومعادلات تفاعل'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('تحضير درس قوانين نيوتن للحركة فيزياء'), findsOneWidget);
      expect(find.text('ملاحظات كيمياء عضوية ومعادلات تفاعل'), findsOneWidget);
    });

    testWidgets('filters board list by theme chip', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on 'شبكة هندسية 📐' filter chip
      await tester.tap(find.text('شبكة هندسية 📐'));
      await tester.pumpAndSettle();

      // Only gridMath board should remain
      expect(find.text('تحضير درس قوانين نيوتن للحركة فيزياء'), findsOneWidget);
      expect(find.text('ملاحظات كيمياء عضوية ومعادلات تفاعل'), findsNothing);

      // Tap 'الكل'
      await tester.tap(find.text('الكل'));
      await tester.pumpAndSettle();

      expect(find.text('تحضير درس قوانين نيوتن للحركة فيزياء'), findsOneWidget);
      expect(find.text('ملاحظات كيمياء عضوية ومعادلات تفاعل'), findsOneWidget);
    });

    testWidgets('supports dark theme rendering without error', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(find.text('سبوراتي ومسودات التحضير'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('displays rich empty state when no boards exist', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(boards: []));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد سبورات مسودة بعد'), findsOneWidget);
      expect(find.text('فتح سبورة جديدة الآن'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('displays student role titles properly', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(role: 'student'));
      await tester.pumpAndSettle();

      expect(find.text('سبوراتي الذاتية للمذاكرة'), findsOneWidget);
      expect(find.text('مذكراتي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('StudentPersonalBoardScreen Responsive Tests', () {
    testWidgets('renders responsive compact AppBar on 320x640 with popup menu',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(320, 640)),
            child: const StudentPersonalBoardScreen(
              studentId: 'teacher-101',
              title: 'سبورة تحضير تفاعلية',
              isTeacher: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Save icon should be present
      expect(find.byIcon(Icons.save_rounded), findsOneWidget);
      // Compact 'more_vert_rounded' icon for consolidated actions on ultra-compact mobile
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
