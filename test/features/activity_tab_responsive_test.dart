import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/student/tabs/activity_tab.dart';
import 'package:brivio/apps/student/student_dashboard_models.dart';
import 'package:brivio/features/assessment/domain/models/assessment_models.dart';

void main() {
  group('ActivityTab Responsiveness & Component Rendering Tests', () {
    final mockHomework = [
      StudentHomeworkItem(
        homework: Homework(
          id: 'hw-1',
          title: 'واجب قوانين نيوتن للحركة والجاذبية الأرضية مع التطبيقات',
          subjectId: 'sub-1',
          dueAt: DateTime.now().add(const Duration(days: 2)),
          maxScore: 20,
        ),
        groupName: 'مجموعة الفيزياء 3 ثانوى',
      ),
      StudentHomeworkItem(
        homework: Homework(
          id: 'hw-2',
          title: 'تدريبات على معادلات الاتزان الكيميائي وقاعدة لوشاتيليه',
          subjectId: 'sub-2',
          dueAt: DateTime.now().subtract(const Duration(days: 1)),
          maxScore: 15,
        ),
        groupName: 'مجموعة الكيمياء النخبة',
        submissionStatus: 'graded',
        submissionScore: 14,
      ),
    ];

    final mockExams = [
      StudentExamItem(
        exam: Exam(
          id: 'exam-1',
          title: 'اختبار تجريبي شامل لمادة الرياضيات البحتة والتفاضل والتكامل',
          subjectId: 'sub-3',
          durationMinutes: 60,
          maxAttempts: 2,
          passScore: 50,
        ),
        groupName: 'مجموعة الرياضيات العامة',
        attemptCount: 0,
      ),
      StudentExamItem(
        exam: Exam(
          id: 'exam-2',
          title: 'كويز قصير في قواعد النحو والصرف العربية',
          subjectId: 'sub-4',
          durationMinutes: 20,
          maxAttempts: 1,
          passScore: 60,
        ),
        groupName: 'مجموعة اللغة العربية المتفوقين',
        attemptCount: 1,
        lastAttemptStatus: 'submitted',
        lastScore: 90,
      ),
    ];

    final mockAttendance = [
      StudentAttendanceItem(
        id: 'att-1',
        classSessionId: 'sess-1',
        status: 'present',
        markedAt: DateTime.now(),
        sessionDate: DateTime.now(),
        scheduledStartAt: DateTime.now().subtract(const Duration(hours: 2)),
        scheduledEndAt: DateTime.now(),
        groupName: 'مجموعة الفيزياء 3 ثانوى',
        notes: 'تم مسح رمز الحضور الذكي بالقاعة',
      ),
      StudentAttendanceItem(
        id: 'att-2',
        classSessionId: 'sess-2',
        status: 'late',
        markedAt: DateTime.now().subtract(const Duration(days: 3)),
        sessionDate: DateTime.now().subtract(const Duration(days: 3)),
        scheduledStartAt: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
        scheduledEndAt: DateTime.now().subtract(const Duration(days: 3)),
        groupName: 'مجموعة الكيمياء النخبة',
        notes: 'تأخير 10 دقائق',
      ),
      StudentAttendanceItem(
        id: 'att-3',
        classSessionId: 'sess-3',
        status: 'absent',
        markedAt: DateTime.now().subtract(const Duration(days: 7)),
        sessionDate: DateTime.now().subtract(const Duration(days: 7)),
        scheduledStartAt: DateTime.now().subtract(const Duration(days: 7, hours: 2)),
        scheduledEndAt: DateTime.now().subtract(const Duration(days: 7)),
        groupName: 'مجموعة الرياضيات العامة',
      ),
    ];

    final mockLeave = [
      StudentLeaveItem(
        id: 'leave-1',
        reason: 'ظرف صحي ومراجعة الطبيب',
        status: 'pending',
        submittedAt: DateTime.now(),
        groupName: 'مجموعة الفيزياء 3 ثانوى',
      ),
      StudentLeaveItem(
        id: 'leave-2',
        reason: 'سفر عائلي طارئ',
        status: 'approved',
        submittedAt: DateTime.now().subtract(const Duration(days: 5)),
        groupName: 'مجموعة الكيمياء النخبة',
        reviewerNote: 'تم قبول العذر الطبي',
      ),
    ];

    final mockBoards = [
      PublishedSessionBoard(
        id: 'board-1',
        title: 'سبورة شرح قانون كيرشوف الأول والثاني وتوزيع الجهود',
        groupName: 'مجموعة الفيزياء 3 ثانوى',
        sessionDate: DateTime.now(),
        updatedAt: DateTime.now(),
        boardData: const {},
      ),
      PublishedSessionBoard(
        id: 'board-2',
        title: 'مخطط الروابط الأيونية والتساهمية في الكيمياء',
        groupName: 'مجموعة الكيمياء النخبة',
        sessionDate: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        boardData: const {},
      ),
    ];

    testWidgets('ActivityTab renders cleanly without overflow on narrow 320px mobile',
        (tester) async {
      tester.view.physicalSize = const Size(320, 680);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityTab(
              isLoading: false,
              homeworkItems: mockHomework,
              examItems: mockExams,
              attendanceItems: mockAttendance,
              leaveItems: mockLeave,
              sessionBoards: mockBoards,
              onSubmitHomework: (_) {},
              onStartExam: (_) {},
              onCreateLeaveRequest: () {},
              onScanQr: () {},
              onOpenBoard: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الأنشطة والمهام'), findsOneWidget);
      expect(find.text('كويز الـ 5 دقائق المباشر ⚡'), findsOneWidget);
      expect(find.text('واجبات مستحقة'), findsOneWidget);
      expect(find.text('الواجبات المنزلية'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.text('الاختبارات والتقييمات'), findsOneWidget);
    });

    testWidgets('ActivityTab tabs switch cleanly to Attendance and Whiteboards',
        (tester) async {
      tester.view.physicalSize = const Size(375, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityTab(
              isLoading: false,
              homeworkItems: mockHomework,
              examItems: mockExams,
              attendanceItems: mockAttendance,
              leaveItems: mockLeave,
              sessionBoards: mockBoards,
              onSubmitHomework: (_) {},
              onStartExam: (_) {},
              onCreateLeaveRequest: () {},
              onScanQr: () {},
              onOpenBoard: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Attendance tab (Tab index 1)
      await tester.tap(find.text('الحضور'));
      await tester.pumpAndSettle();

      expect(find.text('تسجيل الحضور السريع بـ QR'), findsOneWidget);
      expect(find.text('سجل الحصص والانصراف'), findsOneWidget);

      // Filter by Present pill
      await tester.tap(find.text('حاضر').first);
      await tester.pumpAndSettle();
      expect(find.text('تم مسح رمز الحضور الذكي بالقاعة'), findsOneWidget);

      // Switch to Whiteboards tab (Tab index 2)
      await tester.tap(find.text('السبورات'));
      await tester.pumpAndSettle();

      expect(find.text('سبورات وشروحات الحصص'), findsOneWidget);
      expect(find.text('سبورة شرح قانون كيرشوف الأول والثاني وتوزيع الجهود'),
          findsOneWidget);
    });

    testWidgets('ActivityTab renders cleanly on wide 1024px desktop canvas',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityTab(
              isLoading: false,
              homeworkItems: mockHomework,
              examItems: mockExams,
              attendanceItems: mockAttendance,
              leaveItems: mockLeave,
              sessionBoards: mockBoards,
              onSubmitHomework: (_) {},
              onStartExam: (_) {},
              onCreateLeaveRequest: () {},
              onScanQr: () {},
              onOpenBoard: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الأنشطة والمهام'), findsOneWidget);
      expect(find.text('واجبات مستحقة'), findsOneWidget);
      expect(find.text('نسبة الالتزام'), findsOneWidget);
      expect(find.text('سبورات الحصص'), findsNWidgets(2)); // KPI card + Tab
    });
  });
}
