import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brivio/apps/parent/tabs/parent_helpdesk_tab.dart';
import 'package:brivio/core/localization/app_localizations.dart';
import 'package:brivio/features/academy/domain/models/academy_models.dart';
import 'package:brivio/features/helpdesk/data/models/support_ticket.dart';
import 'package:brivio/features/helpdesk/data/models/ticket_reply.dart';
import 'package:brivio/features/helpdesk/data/repositories/helpdesk_repository.dart';

class _FakeHelpdeskRepository implements HelpdeskRepository {
  final List<SupportTicket> tickets;
  final List<HelpdeskGroupOption> groups;
  final Map<String, List<TicketReply>> replies;

  _FakeHelpdeskRepository({
    required this.tickets,
    required this.groups,
    required this.replies,
  });

  @override
  Future<List<SupportTicket>> getTickets() async => tickets;

  @override
  Future<List<HelpdeskGroupOption>> getAvailableGroups() async => groups;

  @override
  Future<List<TicketReply>> getReplies(String ticketId) async =>
      replies[ticketId] ?? [];

  @override
  Future<TicketReply> addReply(String ticketId, String message) async {
    final newReply = TicketReply(
      id: 'rep-${DateTime.now().millisecondsSinceEpoch}',
      ticketId: ticketId,
      userId: 'usr-parent-1',
      message: message,
      createdAt: DateTime.now(),
    );
    replies.putIfAbsent(ticketId, () => []).add(newReply);
    return newReply;
  }

  @override
  Future<SupportTicket> createTicket({
    required String subject,
    required String description,
    required String priority,
    String? groupId,
  }) async {
    final ticket = SupportTicket(
      id: 'ticket-new-99',
      userId: 'usr-parent-1',
      subject: subject,
      description: description,
      status: 'open',
      priority: priority,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      groupId: groupId,
    );
    tickets.insert(0, ticket);
    return ticket;
  }

  @override
  Future<void> updateTicketStatus(String ticketId, String status) async {}
}

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

  final now = DateTime.now();

  final sampleTickets = [
    SupportTicket(
      id: 'tkt-open-101',
      userId: 'usr-parent-1',
      subject: 'استفسار عن موعد بدء المراجعة النهائية لمادة الفيزياء',
      description: 'نود الاستفسار عن جدول المراجعات النهائية وقاعة المحاضرات المقررة للأسبوع القادم.',
      status: 'open',
      priority: 'high',
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now.subtract(const Duration(hours: 2)),
      groupId: 'grp-phys-1',
    ),
    SupportTicket(
      id: 'tkt-prog-202',
      userId: 'usr-parent-1',
      subject: 'طلب تعديل ميعاد حصة الكيمياء لتعارضها مع موعد خارجي',
      description: 'أرجو التكرم بنقل الطالب يوسف إلى مجموعة الكيمياء ليوم السبت الساعة 5 مساء بدلاً من الأحد.',
      status: 'in_progress',
      priority: 'urgent',
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(days: 1)),
      groupId: 'grp-chem-2',
    ),
    SupportTicket(
      id: 'tkt-res-303',
      userId: 'usr-parent-1',
      subject: 'تأكيد استلام إيصال سداد رسوم الشهر الحالي',
      description: 'تم سداد المصروفات بخزينة السنتر ومرفق رقم الإيصال لتأكيد تحديث حسابه في التطبيق.',
      status: 'resolved',
      priority: 'normal',
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now.subtract(const Duration(days: 4)),
      groupId: null,
    ),
  ];

  final sampleGroups = [
    const HelpdeskGroupOption(id: 'grp-phys-1', name: 'الفيزياء 3ث - أ. أحمد فتحي'),
    const HelpdeskGroupOption(id: 'grp-chem-2', name: 'الكيمياء 3ث - د. محمد علي'),
  ];

  final sampleReplies = {
    'tkt-open-101': [
      TicketReply(
        id: 'rep-open-1',
        ticketId: 'tkt-open-101',
        userId: 'usr-staff-admin',
        message: 'أهلاً بحضرتك، ستبدأ المراجعة يوم السبت القادم بالقاعة الكبرى.',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
    ],
    'tkt-prog-202': [
      TicketReply(
        id: 'rep-1',
        ticketId: 'tkt-prog-202',
        userId: 'usr-staff-admin',
        message: 'أهلاً بك يا فندم. جاري التنسيق مع مشرف السنتر للتحقق من الأماكن الشاغرة بمجموعة السبت.',
        createdAt: now.subtract(const Duration(hours: 12)),
      ),
    ],
    'tkt-res-303': [
      TicketReply(
        id: 'rep-2',
        ticketId: 'tkt-res-303',
        userId: 'usr-staff-finance',
        message: 'تم تأكيد السداد وتحديث المحفظة الإلكترونية بنجاح. شكراً لتعاونكم.',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
    ],
  };

  Widget createTestWidget({
    required Size screenSize,
    List<SupportTicket>? initialTickets,
    Brightness brightness = Brightness.light,
  }) {
    final repo = _FakeHelpdeskRepository(
      tickets: List.from(initialTickets ?? sampleTickets),
      groups: sampleGroups,
      replies: Map.from(sampleReplies),
    );

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
            child: ParentHelpdeskTab(
              child: sampleChild,
              repository: repo,
              initialTickets: initialTickets ?? sampleTickets,
            ),
          ),
        ),
      ),
    );
  }

  group('ParentHelpdeskTab Responsiveness & Comprehensive Functionality Tests', () {
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
        expect(find.text('الدعم الفني والشكاوى'), findsOneWidget);
        expect(find.text('إجمالي التذاكر'), findsOneWidget);
        expect(find.text('مفتوحة'), findsWidgets);
        expect(find.text('قيد المتابعة'), findsWidgets);
        expect(find.text('تم الحل'), findsWidgets);

        // Verify Search bar
        expect(find.byType(TextField), findsOneWidget);

        // Verify Filter pills
        expect(find.text('الكل'), findsOneWidget);

        // Verify Tickets render properly
        expect(find.text('استفسار عن موعد بدء المراجعة النهائية لمادة الفيزياء'), findsOneWidget);
        expect(find.text('طلب تعديل ميعاد حصة الكيمياء لتعارضها مع موعد خارجي'), findsOneWidget);
        expect(find.text('تأكيد استلام إيصال سداد رسوم الشهر الحالي'), findsOneWidget);
      },
    );

    testWidgets(
      'search input filters tickets by subject and clear button resets list on 375x812',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 812)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Type search query matching only physics ticket
        await tester.enterText(find.byType(TextField), 'الفيزياء');
        await tester.pumpAndSettle();

        expect(find.text('استفسار عن موعد بدء المراجعة النهائية لمادة الفيزياء'), findsOneWidget);
        expect(find.text('طلب تعديل ميعاد حصة الكيمياء لتعارضها مع موعد خارجي'), findsNothing);
        expect(find.text('تأكيد استلام إيصال سداد رسوم الشهر الحالي'), findsNothing);

        // Tap clear button
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // All tickets restored
        expect(find.text('استفسار عن موعد بدء المراجعة النهائية لمادة الفيزياء'), findsOneWidget);
        expect(find.text('طلب تعديل ميعاد حصة الكيمياء لتعارضها مع موعد خارجي'), findsOneWidget);
        expect(find.text('تأكيد استلام إيصال سداد رسوم الشهر الحالي'), findsOneWidget);
      },
    );

    testWidgets(
      'status filter pills switch views between open, in_progress, and resolved on 375x812',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 812)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Filter: Open tickets (tap on the open filter pill)
        await tester.tap(find.widgetWithText(InkWell, 'مفتوحة').first);
        await tester.pumpAndSettle();

        expect(find.text('استفسار عن موعد بدء المراجعة النهائية لمادة الفيزياء'), findsOneWidget);
        expect(find.text('طلب تعديل ميعاد حصة الكيمياء لتعارضها مع موعد خارجي'), findsNothing);

        // Filter: In Progress
        await tester.tap(find.widgetWithText(InkWell, 'قيد المتابعة').first);
        await tester.pumpAndSettle();

        expect(find.text('طلب تعديل ميعاد حصة الكيمياء لتعارضها مع موعد خارجي'), findsOneWidget);
        expect(find.text('استفسار عن موعد بدء المراجعة النهائية لمادة الفيزياء'), findsNothing);

        // Filter: Resolved
        await tester.tap(find.widgetWithText(InkWell, 'تم الحل').first);
        await tester.pumpAndSettle();

        expect(find.text('تأكيد استلام إيصال سداد رسوم الشهر الحالي'), findsOneWidget);
        expect(find.text('طلب تعديل ميعاد حصة الكيمياء لتعارضها مع موعد خارجي'), findsNothing);
      },
    );

    testWidgets(
      'tapping ticket card opens details sheet with thread and reply composer on 375x812',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(screenSize: const Size(375, 812)));
        await tester.pumpAndSettle();

        // Tap the visible first ticket card
        await tester.tap(find.text('استفسار عن موعد بدء المراجعة النهائية لمادة الفيزياء'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Verify bottom sheet content
        expect(find.text('تفاصيل الاستفسار الأصلي (ولي الأمر)'), findsOneWidget);
        expect(find.text('سجل المحادثة والردود'), findsOneWidget);
        expect(find.textContaining('ستبدأ المراجعة يوم السبت القادم'), findsOneWidget);
        expect(find.text('اكتب ردك أو استفسارك هنا...'), findsOneWidget);
      },
    );

    testWidgets(
      'empty state displays gracefully when no tickets exist or match query',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(
          screenSize: const Size(375, 812),
          initialTickets: const [],
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('لا توجد تذاكر دعم مسجلة في هذا القسم'), findsOneWidget);
        expect(find.text('إنشاء تذكرة دعم جديدة 🎫'), findsOneWidget);
      },
    );

    testWidgets(
      'renders with zero RenderFlex overflow on wide tablet/desktop 1024x768 screen',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(screenSize: const Size(1024, 768)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('الدعم الفني والشكاوى'), findsOneWidget);
        expect(find.text('تذكرة جديدة'), findsOneWidget);
        expect(find.text('استفسار عن موعد بدء المراجعة النهائية لمادة الفيزياء'), findsOneWidget);
      },
    );
  });
}
