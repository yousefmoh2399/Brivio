import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/parent/tabs/parent_payments_tab.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/features/academy/domain/models/academy_models.dart';
import 'package:brivio/features/payments/domain/models/payment_models.dart';

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

  final sampleSummary = FinancialSummary(
    studentId: 'std-202',
    invoiceCount: 3,
    totalDueMinor: 250000, // 2500.00 EGP
    totalPaidMinor: 175000, // 1750.00 EGP
    remainingBalanceMinor: 75000, // 750.00 EGP
    currency: 'EGP',
  );

  final sampleInvoices = [
    Invoice(
      id: 'inv-101',
      invoiceNumber: 'INV-2026-001',
      studentId: 'std-202',
      currency: 'EGP',
      subtotalMinor: 100000,
      discountMinor: 0,
      totalMinor: 100000,
      amountPaidMinor: 100000,
      status: 'paid',
      dueAt: DateTime.now().subtract(const Duration(days: 30)),
      issuedAt: DateTime.now().subtract(const Duration(days: 35)),
    ),
    Invoice(
      id: 'inv-102',
      invoiceNumber: 'INV-2026-002',
      studentId: 'std-202',
      currency: 'EGP',
      subtotalMinor: 75000,
      discountMinor: 0,
      totalMinor: 75000,
      amountPaidMinor: 75000,
      status: 'paid',
      dueAt: DateTime.now().subtract(const Duration(days: 15)),
      issuedAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
    Invoice(
      id: 'inv-103',
      invoiceNumber: 'INV-2026-003',
      studentId: 'std-202',
      currency: 'EGP',
      subtotalMinor: 85000,
      discountMinor: 10000,
      totalMinor: 75000,
      amountPaidMinor: 0,
      status: 'issued',
      dueAt: DateTime.now().add(const Duration(days: 5)),
      issuedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  final sampleReceipts = [
    Receipt(
      id: 'rec-501',
      receiptNumber: 'REC-2026-789',
      transactionId: 'TXN-998822',
      invoiceId: 'inv-101',
      studentId: 'std-202',
      amountMinor: 100000,
      currency: 'EGP',
      issuedAt: DateTime.now().subtract(const Duration(days: 28)),
    ),
    Receipt(
      id: 'rec-502',
      receiptNumber: 'REC-2026-790',
      transactionId: 'TXN-998833',
      invoiceId: 'inv-102',
      studentId: 'std-202',
      amountMinor: 75000,
      currency: 'EGP',
      issuedAt: DateTime.now().subtract(const Duration(days: 14)),
    ),
  ];

  Widget createTestWidget({
    required Size screenSize,
    Student? child = sampleChild,
    List<Student>? linkedChildren,
    ValueChanged<Student>? onChildSelected,
    FinancialSummary? summary,
    List<Invoice>? invoices,
    List<Receipt>? receipts,
    List<GroupEntity>? groups,
    VoidCallback? onExportLedger,
    ValueChanged<Receipt>? onShowReceipt,
    Brightness brightness = Brightness.light,
  }) {
    final effectiveSummary = summary ?? sampleSummary;
    final effectiveInvoices = invoices ?? sampleInvoices;
    final effectiveReceipts = receipts ?? sampleReceipts;
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
            child: ParentPaymentsTab(
              child: child,
              linkedChildren: effectiveLinked,
              onChildSelected: onChildSelected ?? (_) {},
              financialSummary: effectiveSummary,
              invoices: effectiveInvoices,
              receipts: effectiveReceipts,
              childGroups: effectiveGroups,
              onExportLedger: onExportLedger ?? () {},
              onShowReceipt: onShowReceipt ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  group('ParentPaymentsTab Responsiveness & Comprehensive Functionality Tests', () {
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
        expect(find.textContaining('كود الطالب: BRV-7711'), findsOneWidget);
        expect(find.text('إجمالي المستحق'), findsOneWidget);
        expect(find.text('المسدد بالخزينة'), findsOneWidget);
        expect(find.text('المتبقي للسداد'), findsOneWidget);

        // Verify Category Switcher Chips
        expect(find.text('نظرة شاملة', skipOffstage: false), findsOneWidget);
        expect(find.text('فواتير واشتراكات', skipOffstage: false), findsWidgets);
        expect(find.text('إيصالات السداد', skipOffstage: false), findsWidgets);
        expect(find.text('مستحق السداد', skipOffstage: false), findsOneWidget);

        // Verify Alert Section for unpaid invoice
        expect(find.textContaining('فواتير واشتراكات بانتظار السداد'), findsOneWidget);

        // Verify Invoices list
        expect(find.text('INV-2026-003'), findsWidgets);
      },
    );

    testWidgets(
      'category switching filters between overview, invoices, receipts, and unpaid items on 375x812',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 812)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // 1. In Overview, both invoices & receipts sections appear
        expect(find.text('فواتير واشتراكات الحصص'), findsOneWidget);
        expect(find.text('إيصالات السداد والمعاملات'), findsOneWidget);

        // 2. Switch to Invoices category
        final invoicesFilter = find.text('فواتير واشتراكات', skipOffstage: false).first;
        await tester.tap(invoicesFilter, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.text('كافة فواتير واشتراكات الحصص'), findsOneWidget);
        expect(find.text('إيصالات السداد والمعاملات'), findsNothing);

        // 3. Switch to Receipts category
        final receiptsFilter = find.text('إيصالات السداد', skipOffstage: false).first;
        await tester.ensureVisible(receiptsFilter);
        await tester.pumpAndSettle();
        await tester.tap(receiptsFilter);
        await tester.pumpAndSettle();

        expect(find.text('إيصالات السداد والمعاملات'), findsOneWidget);
        expect(find.text('كافة فواتير واشتراكات الحصص'), findsNothing);

        // 4. Switch to Unpaid category
        final unpaidFilter = find.text('مستحق السداد', skipOffstage: false).last;
        await tester.ensureVisible(unpaidFilter);
        await tester.pumpAndSettle();
        await tester.tap(unpaidFilter);
        await tester.pumpAndSettle();

        expect(find.text('المتأخرات والمستحقات المتبقية للسداد'), findsOneWidget);
        expect(find.text('INV-2026-003'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping PDF ledger export button and receipt card invokes respective callbacks',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool ledgerExported = false;
        Receipt? openedReceipt;

        await tester.pumpWidget(
          createTestWidget(
            screenSize: const Size(375, 812),
            onExportLedger: () => ledgerExported = true,
            onShowReceipt: (rec) => openedReceipt = rec,
          ),
        );
        await tester.pumpAndSettle();

        // Tap export ledger button
        final exportBtn = find.textContaining('تحميل وطباعة كشف الحساب المالي المعتمد PDF');
        expect(exportBtn, findsOneWidget);
        await tester.tap(exportBtn, warnIfMissed: false);
        await tester.pump();
        expect(ledgerExported, isTrue);

        // Tap on a receipt card (drag to bring it clearly into view)
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
        await tester.pumpAndSettle();

        final receiptCard = find.text('REC-2026-789');
        expect(receiptCard, findsOneWidget);
        await tester.tap(receiptCard, warnIfMissed: false);
        await tester.pump();
        expect(openedReceipt, isNotNull);
        expect(openedReceipt!.receiptNumber, 'REC-2026-789');
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
        expect(find.text('إرشادات وضوابط السداد بالسنتر ℹ️'), findsOneWidget);
      },
    );

    testWidgets(
      'renders empty state gracefully when there are no invoices or receipts',
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
            summary: emptySummary,
            invoices: const [],
            receipts: const [],
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Verification of 100% clearance badge in hero
        expect(find.text('حساب خالص'), findsOneWidget);
        expect(find.textContaining('تمت تصفية وسداد كافة المستحقات بالكامل'), findsOneWidget);

        // Empty card messages
        expect(find.text('لا توجد فواتير أو مطالبات مالية مسجلة.'), findsOneWidget);
        expect(find.text('لا توجد إيصالات سداد مسجلة حتى الآن.'), findsOneWidget);
      },
    );
  });
}
