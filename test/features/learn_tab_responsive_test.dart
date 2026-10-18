import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/student/tabs/learn_tab.dart';
import 'package:brivio/features/academy/domain/models/academy_models.dart';
import 'package:brivio/features/study_workspace/domain/models/study_workspace_models.dart';

void main() {
  group('LearnTab Responsiveness & Component Rendering Tests', () {
    final mockLessons = [
      const StudyLessonSummary(
        id: 'lesson-1',
        title: 'قوانين نيوتن للحركة وتطبيقاتها العملية في الحياة اليومية',
        pathName: 'مسار الفيزياء العامة 3 ثانوى',
        unitName: 'الوحدة الأولى: الميكانيكا الكلاسيكية',
        progressPercentage: 100,
        estimatedMinutes: 45,
        lastPage: 1,
        totalPages: 10,
        xp: 50,
        hasPdf: true,
        hasCodePlayground: true,
      ),
      const StudyLessonSummary(
        id: 'lesson-2',
        title: 'قانون بقاء الطاقة والشغل والقدرة',
        pathName: 'مسار الفيزياء العامة 3 ثانوى',
        unitName: 'الوحدة الأولى: الميكانيكا الكلاسيكية',
        progressPercentage: 45,
        estimatedMinutes: 30,
        lastPage: 1,
        totalPages: 10,
        xp: 30,
        hasPdf: true,
        hasCodePlayground: false,
      ),
      const StudyLessonSummary(
        id: 'lesson-3',
        title: 'مقدمة في الكيمياء العضوية والألكانات',
        pathName: 'مسار الكيمياء العضوية الحديثة',
        unitName: 'الوحدة الخامسة: الهيدروكربونات',
        progressPercentage: 0,
        estimatedMinutes: 60,
        lastPage: 1,
        totalPages: 12,
        xp: 60,
        hasPdf: false,
        hasCodePlayground: false,
      ),
    ];

    final mockGroups = [
      const GroupEntity(
        id: 'grp-1',
        name: 'مجموعة الأوائل للفيزياء - الصف الثالث الثانوي',
        code: 'PHY-301',
        subjectId: 'sub-1',
        branchId: 'branch-1',
        teacherId: 'teacher-1',
        maxCapacity: 60,
        status: 'active',
      ),
      const GroupEntity(
        id: 'grp-2',
        name: 'مجموعة النخبة للكيمياء',
        code: 'CHM-201',
        subjectId: 'sub-2',
        branchId: 'branch-1',
        teacherId: 'teacher-2',
        maxCapacity: 50,
        status: 'active',
      ),
    ];

    testWidgets('LearnTab renders without any overflow on narrow 320px mobile',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearnTab(
              isLoading: false,
              lessons: mockLessons,
              groups: mockGroups,
              onOpenLesson: (_) {},
              onOpenGroup: (_) {},
            ),
          ),
        ),
      );

      // Verify header and core sections render cleanly without overflow
      expect(find.text('الدروس والمناهج'), findsOneWidget);
      expect(find.text('مسارات التعلم والمناهج 🗺️'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('مجموعاتي الدراسية 🏛️'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('LearnTab interactive filter and search work as expected on 375px mobile',
        (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearnTab(
              isLoading: false,
              lessons: mockLessons,
              groups: mockGroups,
              onOpenLesson: (_) {},
              onOpenGroup: (_) {},
            ),
          ),
        ),
      );

      // Tap on completed filter pill
      final completedPill = find.textContaining('المكتملة ✅');
      expect(completedPill, findsOneWidget);
      await tester.ensureVisible(completedPill);
      await tester.pumpAndSettle();
      await tester.tap(completedPill);
      await tester.pumpAndSettle();

      // Only completed lesson should be listed
      expect(find.text('قوانين نيوتن للحركة وتطبيقاتها العملية في الحياة اليومية'), findsOneWidget);
      expect(find.text('قانون بقاء الطاقة والشغل والقدرة'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('LearnTab renders cleanly on wide 1024px desktop canvas',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearnTab(
              isLoading: false,
              lessons: mockLessons,
              groups: mockGroups,
              onOpenLesson: (_) {},
              onOpenGroup: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('الدروس والمناهج'), findsOneWidget);
      expect(find.text('إنجاز المناهج'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
