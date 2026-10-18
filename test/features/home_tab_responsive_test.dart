import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/student/tabs/home_tab.dart';
import 'package:brivio/features/study_workspace/domain/models/study_workspace_models.dart';

void main() {
  group('HomeTab Components Mobile & Screen Responsiveness Tests', () {
    testWidgets('LiveCountdownHeroCard idle state renders cleanly on narrow 320px mobile',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: LiveCountdownHeroCard(
                isLoading: false,
                lesson: null,
                gamification: null,
                onOpen: null,
                groupName: 'مجموعة الفيزياء 101',
              ),
            ),
          ),
        ),
      );

      expect(find.text('جدولك الأكاديمي جاهز'), findsOneWidget);
      expect(find.text('المناهج'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('LiveCountdownHeroCard active countdown renders cleanly on 320px mobile',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lesson = StudyLessonSummary(
        id: 'lesson-1',
        title: 'قوانين نيوتن للحركة وتطبيقاتها العملية',
        pathName: 'مسار الفيزياء',
        unitName: 'الوحدة الأولى: الميكانيكا',
        progressPercentage: 40,
        estimatedMinutes: 45,
        lastPage: 1,
        totalPages: 10,
        xp: 50,
        hasPdf: true,
        hasCodePlayground: false,
        publishedAt: DateTime.now().add(const Duration(hours: 3)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: LiveCountdownHeroCard(
                isLoading: false,
                lesson: lesson,
                gamification: null,
                onOpen: () {},
                groupName: 'ثانوية عامة - لغات',
              ),
            ),
          ),
        ),
      );

      expect(find.text('قوانين نيوتن للحركة وتطبيقاتها العملية'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
