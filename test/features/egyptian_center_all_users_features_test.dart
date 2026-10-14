import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brivio/core/services/offline_sync_service.dart';
import 'package:brivio/core/services/report_generator_service.dart';
import 'package:brivio/features/curriculum/presentation/widgets/watermarked_material_viewer.dart';
import 'package:brivio/features/academy/presentation/screens/classroom_capacity_screen.dart';
import 'package:brivio/features/academy/presentation/screens/teacher_assistants_screen.dart';
import 'package:brivio/features/payments/presentation/screens/bookstore_pos_screen.dart';
import 'package:brivio/core/services/thermal_printer_service.dart';
import 'package:brivio/features/payments/presentation/widgets/thermal_printer_settings_dialog.dart';
import 'package:brivio/features/academy/presentation/screens/interactive_seat_allocation_dialog.dart';
import 'package:brivio/features/curriculum/presentation/screens/student_materials_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    OfflineSyncService().stopAutoSyncWatcher();
  });

  group('Egyptian Center Complete Suite Tests (All User Roles)', () {
    test('OfflineSyncService handles cold-boot snapshots, student directory, arrears, and deduplication', () async {
      final syncService = OfflineSyncService();
      await syncService.init(startWatcher: false);

      expect(syncService.pendingSyncCount.value, equals(0));

      // 1. Queue an offline check-in
      final res1 = await syncService.queueAttendanceCheckIn(
        studentId: 'stu_123',
        groupId: 'grp_sec3',
        sessionId: 'sess_phys_1',
        studentName: 'محمود عبد الرحمن',
        studentCode: 'EGY-2026-99',
        centerId: 'center_al_awael',
        notes: 'تسجيل يدوي أوفلاين',
      );

      expect(res1.isDuplicate, isFalse);
      expect(syncService.pendingSyncCount.value, equals(1));

      // 2. Test duplicate check-in within same session (Deduplication)
      final resDuplicate = await syncService.queueAttendanceCheckIn(
        studentId: 'stu_123',
        groupId: 'grp_sec3',
        sessionId: 'sess_phys_1',
        studentName: 'محمود عبد الرحمن',
        studentCode: 'EGY-2026-99',
      );
      expect(resDuplicate.isDuplicate, isTrue);
      expect(syncService.pendingSyncCount.value, equals(1)); // Did not increase!

      // 3. Test Offline Student Directory & Arrears Resolver
      await syncService.cacheStudentsDirectory([
        {
          'id': 'stu_999',
          'student_code': 'STU-999',
          'full_name': 'يوسف عبد الله سالم',
          'emergency_contact_phone': '01099887766',
          'parent_phone': '01122334455',
          'arrears_amount': 150.0,
          'pending_invoice_id': 'inv_oct_999',
          'has_due': true,
        },
      ]);

      final resolvedStudent = await syncService.resolveStudentOffline('STU-999');
      expect(resolvedStudent, isNotNull);
      expect(resolvedStudent!['full_name'], equals('يوسف عبد الله سالم'));
      expect(resolvedStudent['arrears_amount'], equals(150.0));
      expect(resolvedStudent['has_due'], isTrue);

      // 4. Test deducting arrears locally upon offline cash collection
      await syncService.updateStudentArrearsLocally(
        studentIdOrCode: 'STU-999',
        amountDeducted: 150.0,
      );

      final updatedStudent = await syncService.resolveStudentOffline('STU-999');
      expect(updatedStudent!['arrears_amount'], equals(0.0));
      expect(updatedStudent['has_due'], isFalse);

      // 5. Test Cold-boot groups & sessions snapshot
      await syncService.cacheGroupsAndSessions(
        groups: [
          {'id': 'grp_1', 'name': 'فيزياء لغات A', 'code': 'PHYS-01', 'capacity': 40, 'status': 'active'},
        ],
        sessions: [
          {
            'id': 'sess_1',
            'group_id': 'grp_1',
            'session_date': DateTime.now().toIso8601String(),
            'scheduled_start_at': DateTime.now().toIso8601String(),
            'scheduled_end_at': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
            'status': 'in_progress',
          },
        ],
      );

      final cachedGroups = await syncService.getCachedGroups();
      expect(cachedGroups.length, equals(1));
      expect(cachedGroups.first['name'], equals('فيزياء لغات A'));

      final cachedSessions = await syncService.getCachedSessions('grp_1');
      expect(cachedSessions.length, equals(1));
      expect(cachedSessions.first['id'], equals('sess_1'));

      // 6. Test Offline Materials download tracker
      await syncService.setMaterialDownloaded('mat_physics_ch1', true);
      final isDownloaded = await syncService.isMaterialDownloaded('mat_physics_ch1');
      expect(isDownloaded, isTrue);

      final downloadedIds = await syncService.getDownloadedMaterialIds();
      expect(downloadedIds.contains('mat_physics_ch1'), isTrue);

      // Clear queue
      await syncService.clearQueue();
      expect(syncService.pendingSyncCount.value, equals(0));
    });

    test('ReportGeneratorService generates Parent Ledger, Monthly Card, and POS Receipts without throwing', () async {
      final service = ReportGeneratorService();

      // 1. Parent Financial Ledger PDF
      expect(
        () => service.generateParentFinancialLedgerPdf(
          centerName: 'سنتر الأوائل التعليمي',
          studentName: 'أحمد محمود',
          studentCode: 'STU-100',
          parentName: 'محمود أحمد السيد',
          parentPhone: '01012345678',
          groupName: 'ثانوية عامة - لغات A',
          totalPaid: 425.0,
          totalRemaining: 50.0,
          records: [
            {
              'receiptNumber': 'REC-1001',
              'date': '2026-10-01',
              'amount': 350.0,
              'purpose': 'مصاريف شهر أكتوبر كاملة',
              'collector': 'سارة (استقبال)',
            },
            {
              'receiptNumber': 'REC-1002',
              'date': '2026-10-05',
              'amount': 75.0,
              'purpose': 'ملزمة الفيزياء الحديثة',
              'collector': 'أحمد (مكتبة السنتر)',
            },
          ],
        ),
        returnsNormally,
      );

      // 2. Monthly Performance Report Card PDF
      expect(
        () => service.generateMonthlyReportCardPdf(
          centerName: 'سنتر الأوائل التعليمي',
          monthName: 'أكتوبر 2026',
          studentName: 'أحمد محمود',
          studentCode: 'STU-100',
          groupName: 'ثانوية عامة - لغات A',
          teacherName: 'أ. محمد عبد الله',
          attendanceRate: 95.0,
          attendedSessions: 8,
          totalSessions: 8,
          examAverage: 19.5,
          homeworkAverage: 20.0,
          conductEvaluation: 'ممتاز ومثالي 🌟',
          teacherNotes: 'أداء متميز في جميع الامتحانات والاختبارات الدورية.',
        ),
        returnsNormally,
      );

      // 3. Bookstore & Notes 80mm Cash POS Receipt PDF
      expect(
        () => service.generateBookstoreReceiptPdf(
          centerName: 'سنتر الأوائل التعليمي',
          receiptNumber: 'POS-8821',
          studentName: 'كريم وائل',
          studentCode: 'STU-205',
          cashierName: 'أحمد موظف الخزينة',
          saleDate: DateTime.now(),
          items: [
            {'title': 'مذكرة مراجعة الكيمياء العضوية', 'qty': 1, 'unitPrice': 65.0, 'subtotal': 65.0},
            {'title': 'كراسة إجابات كيرشوف', 'qty': 2, 'unitPrice': 20.0, 'subtotal': 40.0},
          ],
          totalAmount: 105.0,
        ),
        returnsNormally,
      );
    });

    testWidgets('WatermarkedMaterialViewer renders protection overlay with student metadata', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: WatermarkedMaterialViewer(
              title: 'مذكرة شرح الديناميكا الحرارية',
              subjectName: 'فيزياء',
              teacherName: 'أ. محمد عبد الله',
              studentName: 'عبد الله طارق',
              studentCode: 'STU-777',
              studentPhone: '01012345678',
              centerName: 'سنتر الأوائل',
              samplePages: [
                'الصفحة الأولى: مقدمة في قوانين الديناميكا والتمدد الحراري',
                'الصفحة الثانية: مسائل تطبيقية وتمارين الثانوية العامة',
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('مذكرة شرح الديناميكا الحرارية'), findsOneWidget);
      expect(find.textContaining('الصفحة الأولى'), findsOneWidget);
      expect(find.textContaining('صفحة 1 من 2'), findsOneWidget);
    });

    testWidgets('ClassroomCapacityScreen renders hall cards and occupancy meters', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: ClassroomCapacityScreen(
              centerName: 'سنتر الأوائل التعليمي',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('إدارة مقاعد وسعة القاعات 🏛️'), findsOneWidget);
      expect(find.textContaining('المسرح الكبير'), findsOneWidget);
      expect(find.textContaining('إجمالي سعة السنتر'), findsOneWidget);
    });

    testWidgets('TeacherAssistantsScreen renders TA cards and granular permission chips', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: TeacherAssistantsScreen(
              teacherName: 'أ. محمد عبد الله',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('طاقم مساعدي المدرس (TAs) 👥'), findsOneWidget);
      expect(find.textContaining('م. أحمد خالد'), findsOneWidget);
      expect(find.textContaining('حظر الماليات والأرباح 🔒'), findsWidgets);
    });

    testWidgets('BookstorePosScreen renders catalog, search, and cash checkout controls', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: BookstorePosScreen(
              centerName: 'سنتر الأوائل التعليمي',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('نظام بيع المذكرات والمخزن (POS) 📦'), findsOneWidget);
      expect(find.text('تحصيل كاش وطباعة الإيصال 💵'), findsOneWidget);
      expect(find.textContaining('مذكرة فيزياء 3 ث'), findsOneWidget);
    });

    test('ThermalPrinterService initializes, persists preferences, and generates ESC/POS commands', () async {
      final printerService = ThermalPrinterService();
      await printerService.init();

      // Verify defaults
      expect(printerService.directPrintEnabled.value, isFalse);
      expect(printerService.paperWidth.value, equals(ThermalPaperWidth.mm80));
      expect(printerService.autoDrawerKick.value, isTrue);

      // Verify toggling direct print
      await printerService.setDirectPrintEnabled(true);
      expect(printerService.directPrintEnabled.value, isTrue);

      // Verify toggling paper width
      await printerService.setPaperWidth(ThermalPaperWidth.mm58);
      expect(printerService.paperWidth.value, equals(ThermalPaperWidth.mm58));

      // Verify ESC/POS raw commands
      final drawerBytes = printerService.generateCashDrawerKickCommand();
      expect(drawerBytes, equals([0x1B, 0x70, 0x00, 0x19, 0xFA]));

      final cutBytes = printerService.generatePaperCutCommand();
      expect(cutBytes, equals([0x1D, 0x56, 0x41, 0x10]));
    });

    test('ReportGeneratorService generates Printable Seat Desk Labels Sheet PDF without throwing', () async {
      final service = ReportGeneratorService();

      expect(
        () => service.generateSeatDeskLabelsPdf(
          centerName: 'سنتر الأوائل التعليمي',
          hallName: 'المسرح الكبير (A)',
          groupName: 'ثانوية عامة - فيزياء A',
          teacherName: 'أ. محمد عبد الله',
          seatAllocations: [
            {'seat': 1, 'name': 'عمر أحمد محمود', 'code': 'STU-101', 'phone': '01012345678'},
            {'seat': 2, 'name': 'مريم طارق سالم', 'code': 'STU-102', 'phone': '01123456789'},
            {'seat': 3, 'name': 'يوسف كريم عز الدين', 'code': 'STU-103', 'phone': '01234567890'},
          ],
        ),
        returnsNormally,
      );
    });

    testWidgets('InteractiveSeatAllocationDialog renders hall podium, seat grid, and action buttons', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: InteractiveSeatAllocationDialog(
                centerName: 'سنتر الأوائل التعليمي',
                hallName: 'المسرح الكبير (A)',
                capacity: 12,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('تسكين وتوزيع مقاعد: المسرح الكبير (A)'), findsOneWidget);
      expect(find.textContaining('منصة شرح الأستاذ'), findsOneWidget);
      expect(find.text('تسكين تلقائي للدفعة ⚡'), findsOneWidget);
      expect(find.text('طباعة استيكرات الديسكات (A4) 🖨️'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
    });

    testWidgets('ThermalPrinterSettingsDialog renders direct print toggles and settings', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: ThermalPrinterSettingsDialog(),
            ),
          ),
        ),
      );

      await tester.pump();
      // Pump 2 seconds to let printer discovery timer (1.5s) expire and settle
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('إعدادات الطابعة الحرارية'), findsOneWidget);
      expect(find.textContaining('الطباعة السريعة المباشرة'), findsOneWidget);
      expect(find.textContaining('عرض الورق الحراري'), findsOneWidget);
      expect(find.textContaining('طباعة تجريبية'), findsOneWidget);
    });

    testWidgets('StudentMaterialsScreen renders offline badge, subject filter, and download toggles', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: StudentMaterialsScreen(
              studentName: 'أحمد محمود',
              studentCode: 'STU-108',
              studentPhone: '01011122233',
              centerName: 'سنتر الأوائل',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('مكتبة الملازم والمذكرات 📚'), findsOneWidget);
      expect(find.textContaining('أوفلاين'), findsWidgets);
      expect(find.text('المحفوظة أوفلاين 📥'), findsOneWidget);
      expect(find.textContaining('فتح وقراءة المذكرة'), findsWidgets);
    });
  });
}
