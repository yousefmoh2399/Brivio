import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/di/injection.dart';
import '../../core/error/supabase_error_handler.dart';
import '../../core/network/supabase_client_wrapper.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/settings/app_settings_screen.dart';
import '../../design_system/components/editable_avatar.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/widgets/portal_components.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/communication/data/repositories/supabase_notification_repository.dart';
import '../../features/communication/domain/repositories/i_notification_repository.dart';
import '../../features/communication/domain/models/notification.dart';
import '../../features/payments/data/repositories/supabase_payment_repositories.dart';
import '../../features/payments/domain/models/payment_models.dart';
import '../../features/payments/presentation/widgets/digital_cash_receipt_dialog.dart';
import '../../features/study_workspace/data/repositories/supabase_student_learning_repository.dart';
import '../../features/study_workspace/domain/models/study_workspace_models.dart';
import '../../features/parent_portal/presentation/screens/absence_excuse_dialog.dart';
import '../../features/parent_portal/presentation/screens/link_child_screen.dart';
import '../../features/parent_portal/presentation/screens/monthly_report_card_screen.dart';
import '../../features/parent_portal/presentation/screens/parent_financial_ledger_screen.dart';
import '../../features/parent_portal/presentation/screens/child_assignments_screen.dart';
import '../../features/parent_portal/presentation/screens/child_schedule_screen.dart';
import 'screens/parent_helpdesk_screen.dart';
import 'tabs/parent_home_tab.dart';
import 'tabs/parent_progress_tab.dart';
import 'tabs/parent_attendance_tab.dart';
import 'tabs/parent_payments_tab.dart';
import 'tabs/parent_monthly_report_tab.dart';
import 'tabs/parent_notifications_tab.dart';
import 'tabs/parent_helpdesk_tab.dart';
import 'tabs/parent_account_tab.dart';

class ParentDashboard extends StatefulWidget {
  final AuthViewModel authViewModel;

  const ParentDashboard({super.key, required this.authViewModel});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  bool _isLoading = false;
  bool _isChildLoading = false;
  String? _errorMessage;
  int _selectedIndex = 0;
  List<Student> _linkedChildren = [];
  Student? _selectedChild;
  List<GroupEntity> _childGroups = [];
  StudentLearningSnapshot? _learningSnapshot;
  FinancialSummary? _financialSummary;
  List<Invoice> _invoices = [];
  List<Receipt> _receipts = [];
  List<_ParentExamItem> _examItems = [];
  List<_ParentAttendanceItem> _attendance = [];
  List<_ParentLeaveItem> _leaveRequests = [];
  List<_ParentHomeworkItem> _homeworkItems = [];
  List<_ParentScheduleItem> _scheduleItems = [];
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription<AppNotification>? _notificationSubscription;

  static const _destinations = [
    PortalDestination(icon: Icons.dashboard_customize, label: 'الرئيسية'),
    PortalDestination(icon: Icons.school, label: 'التقدم الدراسي'),
    PortalDestination(icon: Icons.fact_check, label: 'سجل الحضور'),
    PortalDestination(icon: Icons.receipt_long, label: 'المدفوعات'),
    PortalDestination(icon: Icons.summarize, label: 'التقرير الشهري'),
    PortalDestination(icon: Icons.notifications, label: 'الإشعارات'),
    PortalDestination(icon: Icons.support_agent, label: 'الدعم الفني'),
    PortalDestination(icon: Icons.account_circle, label: 'حسابي'),
    PortalDestination(icon: Icons.settings, label: 'الإعدادات'),
  ];

  @override
  void initState() {
    super.initState();
    _subscribeToNotifications();
    _loadLinkedChildren();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToNotifications() {
    final notificationRepo = getIt<INotificationRepository>();
    _notificationSubscription = notificationRepo
        .subscribeToNotifications()
        .listen((notification) {
          if (!mounted) return;
          setState(() {
            _notifications.insert(0, notification);
            _unreadCount++;
          });
        });
  }

  SupabaseClientWrapper get _wrapper =>
      SupabaseClientWrapper(Supabase.instance.client);

  Future<void> _loadLinkedChildren() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final parentRepo = SupabaseParentRepository(_wrapper);
      final parentId =
          widget.authViewModel.bootstrap?.parentId ??
          widget.authViewModel.bootstrap?.profile.id;
      final children = parentId == null
          ? <Student>[]
          : await parentRepo.fetchLinkedStudents(parentId);
      final previousId = _selectedChild?.id;
      final selected = children.isEmpty
          ? null
          : children.firstWhere(
              (child) => child.id == previousId,
              orElse: () => children.first,
            );

      if (!mounted) return;
      setState(() {
        _linkedChildren = children;
        _selectedChild = selected;
        _isLoading = false;
      });

      if (selected != null) {
        await _loadChildDetails(selected);
      } else {
        _clearChildState();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = SupabaseErrorHandler.parseError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChildDetails(Student child) async {
    setState(() {
      _isChildLoading = true;
      _errorMessage = null;
    });

    try {
      final wrapper = _wrapper;
      final enrollmentRepo = SupabaseEnrollmentRepository(wrapper);
      final learningRepo = SupabaseStudentLearningRepository(wrapper);
      final paymentRepo = SupabasePaymentRepository(wrapper);
      final invoiceRepo = SupabaseInvoiceRepository(wrapper);
      final receiptRepo = SupabaseReceiptRepository(wrapper);
      final notificationRepo = getIt<INotificationRepository>();

      final results = await Future.wait<Object>([
        enrollmentRepo.fetchGroupsForStudent(child.id),
        learningRepo.fetchSnapshotForStudent(child.id),
        paymentRepo.fetchStudentFinancialSummary(child.id),
        invoiceRepo.fetchInvoicesForStudent(child.id),
        receiptRepo.fetchReceiptsForStudent(child.id),
        _safeList(_fetchExamFeed(child.id)),
        _safeList(_fetchAttendance(child.id)),
        _safeList(_fetchLeaveRequests(child.id)),
        _safeList(_fetchHomeworkFeed(child.id)),
        _safeList(_fetchSchedule(child.id)),
        notificationRepo.getNotifications(),
      ]);

      if (!mounted || _selectedChild?.id != child.id) return;
      final childNotifications = _filterNotificationsForChild(
        results[10] as List<AppNotification>,
        child.id,
      );
      setState(() {
        _childGroups = results[0] as List<GroupEntity>;
        _learningSnapshot = results[1] as StudentLearningSnapshot;
        _financialSummary = results[2] as FinancialSummary;
        _invoices = results[3] as List<Invoice>;
        _receipts = results[4] as List<Receipt>;
        _examItems = results[5] as List<_ParentExamItem>;
        _attendance = results[6] as List<_ParentAttendanceItem>;
        _leaveRequests = results[7] as List<_ParentLeaveItem>;
        _homeworkItems = results[8] as List<_ParentHomeworkItem>;
        _scheduleItems = results[9] as List<_ParentScheduleItem>;
        _notifications = childNotifications;
        _unreadCount = childNotifications.where((n) => !n.isRead).length;
        _isChildLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = SupabaseErrorHandler.parseError(e);
        _isChildLoading = false;
      });
    }
  }

  Future<List<T>> _safeList<T>(Future<List<T>> future) async {
    try {
      return await future;
    } catch (_) {
      return <T>[];
    }
  }

  void _clearChildState() {
    setState(() {
      _childGroups = [];
      _learningSnapshot = null;
      _financialSummary = null;
      _invoices = [];
      _receipts = [];
      _examItems = [];
      _attendance = [];
      _leaveRequests = [];
      _homeworkItems = [];
      _scheduleItems = [];
      _notifications = [];
      _unreadCount = 0;
    });
  }

  List<AppNotification> _filterNotificationsForChild(
    List<AppNotification> notifications,
    String childId,
  ) {
    return notifications
        .toList(); // Simplified since parent gets notifications directly or via referenceId.
  }

  Future<List<_ParentAttendanceItem>> _fetchAttendance(String studentId) async {
    final response = await _wrapper.client.rpc(
      'get_parent_child_attendance_history',
      params: {'p_student_id': studentId, 'p_limit': 80},
    );
    return (response as List)
        .map((row) => _ParentAttendanceItem.fromJson(row as Map))
        .toList();
  }

  Future<List<_ParentLeaveItem>> _fetchLeaveRequests(String studentId) async {
    final response = await _wrapper.client.rpc(
      'get_parent_child_leave_requests',
      params: {'p_student_id': studentId},
    );
    return (response as List)
        .map((row) => _ParentLeaveItem.fromJson(row as Map))
        .toList();
  }

  Future<List<_ParentExamItem>> _fetchExamFeed(String studentId) async {
    final response = await _wrapper.client.rpc(
      'get_parent_child_exam_feed',
      params: {'p_student_id': studentId},
    );
    return (response as List)
        .map((row) => _ParentExamItem.fromJson(row as Map))
        .toList();
  }

  Future<List<_ParentHomeworkItem>> _fetchHomeworkFeed(String studentId) async {
    final response = await _wrapper.client.rpc(
      'get_parent_child_homework_feed',
      params: {'p_student_id': studentId},
    );
    return (response as List)
        .map((row) => _ParentHomeworkItem.fromJson(row as Map))
        .toList();
  }

  Future<List<_ParentScheduleItem>> _fetchSchedule(String studentId) async {
    try {
      final response = await _wrapper.client.rpc(
        'get_parent_child_schedule',
        params: {'p_student_id': studentId},
      );
      if (response is List && response.isNotEmpty) {
        final items = response
            .map((row) => _ParentScheduleItem.fromJson(row as Map))
            .toList();
        items.sort((a, b) {
          if (a.sessionDate != null && b.sessionDate != null) {
            final cmp = a.sessionDate!.compareTo(b.sessionDate!);
            if (cmp != 0) return cmp;
          }
          return (a.startTime ?? '').compareTo(b.startTime ?? '');
        });
        return items;
      }
    } catch (_) {}

    // Fallback: direct table query
    try {
      final client = _wrapper.client;
      String effectiveStudentId = studentId;
      try {
        final sRes = await client
            .from('students')
            .select('id')
            .or('id.eq.$studentId,profile_id.eq.$studentId')
            .maybeSingle();
        if (sRes != null && sRes['id'] != null) {
          effectiveStudentId = sRes['id'].toString();
        }
      } catch (_) {}

      final enRes = await client
          .from('enrollments')
          .select('group_id, status')
          .or('student_id.eq.$effectiveStudentId,student_id.eq.$studentId');

      final groupIds = <String>{};
      for (final row in (enRes as List)) {
        final status = row['status']?.toString().toLowerCase();
        if (status != 'cancelled' && status != 'dropped' && status != 'suspended') {
          final gId = row['group_id']?.toString();
          if (gId != null && gId.isNotEmpty) {
            groupIds.add(gId);
          }
        }
      }

      if (groupIds.isEmpty) return [];

      final groupsRes = await client
          .from('groups')
          .select('id, name, subject_id, teacher_id')
          .inFilter('id', groupIds.toList());

      final gList = (groupsRes as List).cast<Map<String, dynamic>>();

      final subjectIds = gList
          .map((g) => g['subject_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final Map<String, String> subjectNames = {};
      if (subjectIds.isNotEmpty) {
        try {
          final subs = await client
              .from('subjects')
              .select('id, name')
              .inFilter('id', subjectIds);
          for (final s in (subs as List)) {
            subjectNames[s['id'].toString()] = s['name']?.toString() ?? 'حصة دراسية';
          }
        } catch (_) {}
      }

      final teacherIds = gList
          .map((g) => g['teacher_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final Map<String, String> teacherNames = {};
      if (teacherIds.isNotEmpty) {
        try {
          final tRes = await client
              .from('teachers')
              .select('id, profiles(full_name)')
              .inFilter('id', teacherIds);
          for (final t in (tRes as List)) {
            final prof = t['profiles'] as Map<String, dynamic>?;
            if (prof != null && prof['full_name'] != null) {
              teacherNames[t['id'].toString()] = prof['full_name'].toString();
            }
          }
        } catch (_) {}
      }

      final List<_ParentScheduleItem> items = [];
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 1. Check class_sessions
      try {
        final sessionsRes = await client
            .from('class_sessions')
            .select('id, group_id, session_date, day_of_week, scheduled_start_at, scheduled_end_at, status, location')
            .inFilter('group_id', groupIds.toList())
            .gte('session_date', todayStr)
            .order('session_date', ascending: true)
            .limit(10);

        for (final cs in (sessionsRes as List)) {
          final gId = cs['group_id']?.toString();
          final grp = gList.firstWhere(
            (g) => g['id'].toString() == gId,
            orElse: () => <String, dynamic>{},
          );
          final subId = grp['subject_id']?.toString();
          final tId = grp['teacher_id']?.toString();
          items.add(_ParentScheduleItem(
            id: cs['id']?.toString() ?? '',
            subjectName: subjectNames[subId] ?? 'حصة دراسية',
            groupName: grp['name']?.toString() ?? 'المجموعة',
            teacherName: teacherNames[tId] ?? 'معلم المادة',
            location: cs['location']?.toString() ?? 'القاعة الرئيسية',
            startTime: cs['scheduled_start_at']?.toString().split('T').last.substring(0, 5),
            endTime: cs['scheduled_end_at']?.toString().split('T').last.substring(0, 5),
            sessionDate: DateTime.tryParse(cs['session_date']?.toString() ?? ''),
            dayOfWeek: (cs['day_of_week'] as num?)?.toInt(),
            status: cs['status']?.toString() ?? 'scheduled',
          ));
        }
      } catch (_) {}

      // 2. Fallback to recurring schedules if no specific upcoming class_sessions found
      if (items.isEmpty) {
        try {
          final schRes = await client
              .from('schedules')
              .select('id, group_id, day_of_week, start_time, end_time, location, room_location, status')
              .inFilter('group_id', groupIds.toList());

          for (final sch in (schRes as List)) {
            final gId = sch['group_id']?.toString();
            final grp = gList.firstWhere(
              (g) => g['id'].toString() == gId,
              orElse: () => <String, dynamic>{},
            );
            final subId = grp['subject_id']?.toString();
            final tId = grp['teacher_id']?.toString();
            final dayNum = (sch['day_of_week'] as num?)?.toInt();
            DateTime? computedDate;
            if (dayNum != null) {
              final currentWeekday = now.weekday;
              final targetWeekday = (dayNum == 0 || dayNum == 7) ? 7 : dayNum;
              int daysUntil = targetWeekday - currentWeekday;
              if (daysUntil < 0) daysUntil += 7;
              computedDate = DateTime(now.year, now.month, now.day).add(Duration(days: daysUntil));
            }

            items.add(_ParentScheduleItem(
              id: sch['id']?.toString() ?? '',
              subjectName: subjectNames[subId] ?? 'حصة دراسية',
              groupName: grp['name']?.toString() ?? 'المجموعة',
              teacherName: teacherNames[tId] ?? 'معلم المادة',
              location: sch['location']?.toString() ?? sch['room_location']?.toString() ?? 'القاعة الرئيسية',
              startTime: sch['start_time']?.toString(),
              endTime: sch['end_time']?.toString(),
              sessionDate: computedDate,
              dayOfWeek: dayNum,
              status: sch['status']?.toString() ?? 'active',
            ));
          }
        } catch (_) {}
      }

      items.sort((a, b) {
        if (a.sessionDate != null && b.sessionDate != null) {
          final cmp = a.sessionDate!.compareTo(b.sessionDate!);
          if (cmp != 0) return cmp;
        }
        return (a.startTime ?? '').compareTo(b.startTime ?? '');
      });

      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> _openLinkChildScreen() async {
    final linked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LinkChildScreen()),
    );
    if (linked == true) {
      await _loadLinkedChildren();
    }
  }

  void _exportFinancialLedger() {
    final child = _selectedChild;
    if (child == null) return;
    final paid = _financialSummary != null
        ? _financialSummary!.totalPaidMinor / 100.0
        : null;
    final remaining = _financialSummary != null
        ? _financialSummary!.remainingBalanceMinor / 100.0
        : null;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParentFinancialLedgerScreen(
          studentId: child.id,
          studentName: child.fullName,
          studentCode: child.studentCode,
          parentName: widget.authViewModel.currentUser?.fullName ?? 'ولي الأمر',
          parentPhone: widget.authViewModel.currentUser?.phoneNumber ?? '',
          groupName: _childGroups.isNotEmpty ? _childGroups.first.name : 'المجموعة الدراسية',
          initialTotalPaid: paid,
          initialTotalRemaining: remaining,
        ),
      ),
    );
  }

  void _openOfficialReportCard() {
    final child = _selectedChild;
    if (child == null) return;

    final totalSessions = _attendance.length;
    final attendedSessions =
        _attendance.where((a) => a.status.toLowerCase() == 'present').length;
    final attendanceRate =
        totalSessions > 0 ? (attendedSessions / totalSessions) * 100 : null;

    final gradedExams = _examItems.where((e) => e.percentage != null).toList();
    final examAverage = gradedExams.isNotEmpty
        ? gradedExams.map((e) => e.percentage!).reduce((a, b) => a + b) /
            gradedExams.length
        : null;

    final gradedHomework =
        _homeworkItems.where((h) => h.percentage != null).toList();
    final homeworkAverage = gradedHomework.isNotEmpty
        ? gradedHomework.map((h) => h.percentage!).reduce((a, b) => a + b) /
            gradedHomework.length
        : null;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MonthlyReportCardScreen(
          studentId: child.id,
          studentName: child.fullName,
          studentCode: child.studentCode,
          groupName: _childGroups.isNotEmpty ? _childGroups.first.name : 'المجموعة الدراسية',
          teacherName: _childGroups.isNotEmpty ? 'أ. معلم المادة' : 'إدارة السنتر',
          initialAttendanceRate: attendanceRate,
          initialAttendedSessions: attendedSessions,
          initialTotalSessions: totalSessions,
          initialExamAverage: examAverage,
          initialHomeworkAverage: homeworkAverage,
        ),
      ),
    );
  }

  Future<void> _createLeaveRequest() async {
    final child = _selectedChild;
    if (child == null) return;

    final confirmed = await AbsenceExcuseDialog.show(
      context,
      initialStudentName: child.fullName,
      initialStudentId: child.id,
      initialGroupName: _childGroups.isNotEmpty ? _childGroups.first.name : null,
      availableSessions: _attendance
          .take(15)
          .map((a) => {
                'id': a.classSessionId,
                'title': a.groupName,
                'date': _formatDate(a.sessionDate),
              })
          .toList(),
    );

    if (confirmed == true) {
      await _loadChildDetails(child);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال عذر الغياب إلى إدارة السنتر بنجاح ✅'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _markAllNotificationsRead() async {
    final repo = SupabaseNotificationRepository(_wrapper);
    await repo.markAllRead();
    final child = _selectedChild;
    if (child != null) await _loadChildDetails(child);
  }

  Future<void> _markNotificationRead(AppNotification notification) async {
    if (notification.isRead) return;
    final repo = SupabaseNotificationRepository(_wrapper);
    await repo.markRead(notification.id);
    if (!mounted) return;
    setState(() {
      _notifications = _notifications
          .map((n) => n.id == notification.id ? n.copyWith(isRead: true) : n)
          .toList();
      if (_unreadCount > 0) _unreadCount--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final parentName = widget.authViewModel.currentUser?.fullName ?? 'ولي الأمر';
    final selectedName = _selectedChild?.fullName ?? 'لم يتم تحديد طالب';

    return PortalScaffold(
      title: parentName,
      subtitle: selectedName,
      icon: Icons.family_restroom,
      accentColor: AppColors.parentRole,
      selectedIndex: _selectedIndex,
      destinations: _destinations,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      onRefresh: _loadLinkedChildren,
      onSignOut: widget.authViewModel.signOut,
      body: RefreshIndicator(
        onRefresh: _loadLinkedChildren,
        child: PortalStateView(
          isLoading: _isLoading,
          errorMessage: null,
          isEmpty: _linkedChildren.isEmpty,
          emptyTitle: 'لا يوجد أبناء مرتبطين بحسابك',
          emptySubtitle:
              'يرجى إدخال كود الطالب المسلّم لك من إدارة السنتر لربطه بحسابك ومتابعة دراسته لحظياً.',
          emptyIcon: Icons.family_restroom,
          onRetry: _openLinkChildScreen,
          child: _selectedIndex == 8
              ? Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: _buildHeader(),
                    ),
                    const Expanded(child: AppSettingsPanel()),
                  ],
                )
              : LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        return ListView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 20,
                            vertical: isMobile ? 12 : 20,
                          ),
                          children: [
                            _buildHeader(),
                            if (_isChildLoading) ...[
                              const SizedBox(height: 12),
                              const LinearProgressIndicator(),
                            ],
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              PortalErrorBanner(
                                message: _errorMessage!,
                                onRetry: _loadLinkedChildren,
                              ),
                            ],
                            const SizedBox(height: 16),
                            _buildSelectedPage(),
                          ],
                        );
                      },
                    ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final parentUser = widget.authViewModel.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalHeader(
          eyebrow: 'بوابة أولياء الأمور',
          title: parentUser?.fullName ?? 'ولي الأمر',
          subtitle: _selectedChild == null
              ? '${_linkedChildren.length} طلاب مسجلين بالمنظومة'
              : 'متابعة شؤون: ${_selectedChild!.fullName} (${_selectedChild!.studentCode}) • ${_childGroups.length} مجموعات',
          icon: Icons.family_restroom,
          accentColor: AppColors.parentRole,
          leading: EditableAvatar(
            avatarUrl: parentUser?.avatarUrl,
            name: parentUser?.fullName ?? 'ولي الأمر',
            role: 'parent',
            userId: parentUser?.id,
            userEmail: parentUser?.email,
            radius: 23,
            onAvatarChanged: (_) async {
              await widget.authViewModel.restoreSession();
              if (mounted) {
                setState(() {});
              }
            },
          ),
          trailing: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _openLinkChildScreen,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
            label: const Text('ربط طالب جديد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
        if (_linkedChildren.length > 1 && _selectedIndex != 0) ...[
          const SizedBox(height: 10),
          _buildChildSelectorBar(),
        ],
      ],
    );
  }

  Widget _buildChildSelectorBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.parentRole),
          const SizedBox(width: 8),
          const Text(
            'الطالب الحالي:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Student>(
                value: _selectedChild,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.parentRole),
                items: _linkedChildren
                    .map(
                      (child) => DropdownMenuItem<Student>(
                        value: child,
                        child: Text(
                          '${child.fullName} (${child.studentCode})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (child) {
                  if (child == null) return;
                  setState(() => _selectedChild = child);
                  _loadChildDetails(child);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPage() {
    return switch (_selectedIndex) {
      0 => _buildOverviewPage(),
      1 => _buildProgressPage(),
      2 => _buildAttendancePage(),
      3 => _buildPaymentsPage(),
      4 => _buildMonthlyReportPage(),
      5 => _buildNotificationsPage(),
      6 => _buildHelpdeskPage(),
      7 => _buildAccountPage(),
      8 => const AppSettingsPanel(),
      _ => _buildOverviewPage(),
    };
  }

  Widget _buildAccountPage() {
    return ParentAccountTab(
      profile: widget.authViewModel.currentUser,
      authViewModel: widget.authViewModel,
      selectedChild: _selectedChild,
      linkedChildren: _linkedChildren,
      financialSummary: _financialSummary,
      invoices: _invoices,
      receipts: _receipts,
      childGroups: _childGroups,
      unreadCount: _unreadCount,
      onChildSelected: (child) {
        setState(() => _selectedChild = child);
        _loadChildDetails(child);
      },
      onLinkNewChild: _openLinkChildScreen,
      onProfileChanged: () async {
        await widget.authViewModel.restoreSession();
        if (mounted) setState(() {});
      },
      onSignOut: widget.authViewModel.signOut,
      onNavigateToTab: (index) {
        setState(() => _selectedIndex = index);
      },
      onOpenWhatsApp: _launchWhatsAppSupport,
      onExportLedger: _exportFinancialLedger,
      onShowReceipt: _showReceiptDialog,
    );
  }

  Future<void> _launchWhatsAppSupport() async {
    HapticFeedback.lightImpact();
    final child = _selectedChild;
    final childName = child?.fullName ?? 'الطالب';
    final childCode = child?.studentCode ?? '';
    final groupName = _childGroups.isNotEmpty ? _childGroups.first.name : 'السنتر';

    String? supportPhone;
    try {
      final branchId = _selectedChild?.primaryBranchId;
      if (branchId != null && branchId.isNotEmpty) {
        final branchRow = await Supabase.instance.client
            .from('branches')
            .select('phone, contact_phone')
            .eq('id', branchId)
            .maybeSingle();
        supportPhone = branchRow?['contact_phone']?.toString() ??
            branchRow?['phone']?.toString();
      }
    } catch (_) {}

    final phone = (supportPhone != null && supportPhone.isNotEmpty)
        ? supportPhone.replaceAll(RegExp(r'[^0-9+]'), '')
        : null;

    final msg =
        'السلام عليكم، أنا ولي أمر الطالب $childName (كود: $childCode) المسجل في مجموعة $groupName. أود الاستفسار بخصوص المستوى الدراسي والدرجات.';

    if (phone != null && phone.isNotEmpty) {
      final uri = Uri.parse(
          'https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (mounted) {
      Clipboard.setData(ClipboardData(text: msg));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ رسالة الاستفسار إلى الحافظة!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildOverviewPage() {
    return ParentHomeTab(
      child: _selectedChild,
      linkedChildren: _linkedChildren,
      onChildSelected: (child) {
        setState(() => _selectedChild = child);
        _loadChildDetails(child);
      },
      onLinkNewChild: _openLinkChildScreen,
      attendance: _attendance,
      learningSnapshot: _learningSnapshot,
      financialSummary: _financialSummary,
      invoices: _invoices,
      childGroups: _childGroups,
      unreadCount: _unreadCount,
      nextClassSession: _nextClassSession,
      onExcuseRequest: _createLeaveRequest,
      onOpenSchedule: () {
        final child = _selectedChild;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChildScheduleScreen(
              studentId: child?.id,
              studentName: child?.fullName,
            ),
          ),
        );
      },
      onOpenAttendance: () => setState(() => _selectedIndex = 2),
      onOpenProgress: () => setState(() => _selectedIndex = 1),
      onOpenPayments: () => setState(() => _selectedIndex = 3),
      onOpenNotifications: () => setState(() => _selectedIndex = 5),
      onOpenWhatsApp: _launchWhatsAppSupport,
    );
  }

  Widget _buildProgressPage() {
    return ParentProgressTab(
      child: _selectedChild,
      linkedChildren: _linkedChildren,
      onChildSelected: (child) {
        setState(() => _selectedChild = child);
        _loadChildDetails(child);
      },
      learningSnapshot: _learningSnapshot,
      examItems: _examItems,
      homeworkItems: _homeworkItems,
      childGroups: _childGroups,
      attendance: _attendance,
      onOpenAssignments: () {
        final child = _selectedChild;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChildAssignmentsScreen(
              studentId: child?.id,
              studentName: child?.fullName,
            ),
          ),
        );
      },
      onOpenReportCard: _openOfficialReportCard,
      onReviewExam: _showParentExamReview,
    );
  }

  Widget _buildAttendancePage() {
    return ParentAttendanceTab(
      child: _selectedChild,
      linkedChildren: _linkedChildren,
      onChildSelected: (child) {
        setState(() => _selectedChild = child);
        _loadChildDetails(child);
      },
      attendance: _attendance,
      leaveRequests: _leaveRequests,
      childGroups: _childGroups,
      onExcuseRequest: _createLeaveRequest,
    );
  }

  Widget _buildPaymentsPage() {
    return ParentPaymentsTab(
      child: _selectedChild,
      linkedChildren: _linkedChildren,
      onChildSelected: (child) {
        setState(() => _selectedChild = child);
        _loadChildDetails(child);
      },
      financialSummary: _financialSummary,
      invoices: _invoices,
      receipts: _receipts,
      childGroups: _childGroups,
      onExportLedger: _exportFinancialLedger,
      onShowReceipt: _showReceiptDialog,
    );
  }

  Widget _buildMonthlyReportPage() {
    return ParentMonthlyReportTab(
      child: _selectedChild,
      linkedChildren: _linkedChildren,
      onChildSelected: (child) {
        setState(() => _selectedChild = child);
        _loadChildDetails(child);
      },
      attendance: _attendance,
      lessons: _learningSnapshot?.availableLessons ?? const [],
      exams: _examItems,
      homeworks: _homeworkItems,
      invoices: _invoices,
      financialSummary: _financialSummary,
      childGroups: _childGroups,
      onOpenOfficialReportCard: _openOfficialReportCard,
    );
  }

  Widget _buildNotificationsPage() {
    return ParentNotificationsTab(
      notifications: _notifications,
      unreadCount: _unreadCount,
      child: _selectedChild,
      onMarkAllRead: _markAllNotificationsRead,
      onNotificationTap: _openNotification,
      onMarkRead: _markNotificationRead,
    );
  }

  Widget _buildHelpdeskPage() {
    return ParentHelpdeskTab(
      child: _selectedChild,
      childGroups: _childGroups,
    );
  }

  void _openNotification(AppNotification notification) {
    unawaited(_markNotificationRead(notification));
    final targetIndex = _parentNotificationTargetIndex(notification.type);
    if (targetIndex != null) {
      setState(() => _selectedIndex = targetIndex);
      return;
    }
    final pushService = getIt.isRegistered<PushNotificationService>()
        ? getIt<PushNotificationService>()
        : PushNotificationService(_wrapper);
    pushService.handleNotificationTap({
      'type': notification.type,
      'reference_id': notification.referenceId,
      'id': notification.id,
      'title': notification.title,
      'message': notification.message,
    });
  }

  int? _parentNotificationTargetIndex(String type) {
    final normalized = type.toLowerCase();
    if (normalized.contains('payment') ||
        normalized.contains('invoice') ||
        normalized.contains('receipt')) {
      return 3;
    }
    if (normalized.contains('exam') ||
        normalized.contains('grade') ||
        normalized.contains('homework')) {
      return 1;
    }
    if (normalized.contains('attendance') ||
        normalized.contains('absence') ||
        normalized.contains('late') ||
        normalized.contains('session')) {
      return 2;
    }
    if (normalized.contains('report')) {
      return 4;
    }
    if (normalized.contains('help') || normalized.contains('ticket')) {
      return 6;
    }
    return null;
  }

  void _showReceiptDialog(Receipt receipt) {
    final child = _selectedChild;
    final dateStr = _formatDate(receipt.issuedAt);
    final groupName = _childGroups.isNotEmpty ? _childGroups.first.name : 'المجموعة الدراسية';
    final recNum = receipt.receiptNumber.isNotEmpty
        ? receipt.receiptNumber
        : 'REC-${receipt.id.length >= 8 ? receipt.id.substring(0, 8).toUpperCase() : receipt.id}';

    DigitalCashReceiptDialog.show(
      context: context,
      receiptType: ReceiptType.studentPayment,
      centerName: 'منظومة بريفيو التعليمية المتطورة',
      receiptNumber: recNum,
      dateStr: dateStr,
      recipientName: child?.fullName ?? 'الطالب',
      studentCode: child?.studentCode ?? '',
      groupName: groupName,
      amount: receipt.amountMinor / 100.0,
      paymentPurpose: 'سداد رسوم واشتراك معتمد',
      parentOrTeacherPhone: widget.authViewModel.currentUser?.phoneNumber,
      paymentMethod: 'إيصال دفع إلكتروني / معتمد',
      invoiceNumber: receipt.invoiceId.isNotEmpty
          ? 'INV-${receipt.invoiceId.length >= 8 ? receipt.invoiceId.substring(0, 8).toUpperCase() : receipt.invoiceId}'
          : null,
      transactionId: receipt.transactionId.isNotEmpty ? receipt.transactionId : null,
    );
  }

  Future<void> _showParentExamReview(_ParentExamItem item) async {
    final child = _selectedChild;
    if (child == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    late final dynamic raw;
    try {
      raw = await _wrapper.client.rpc(
        'get_parent_child_exam_review',
        params: {'p_student_id': child.id, 'p_exam_id': item.id},
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تحميل مراجعة إجابات الاختبار: $e')));
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    final review = Map<String, dynamic>.from(raw as Map);
    final released = review['released'] == true;
    final answers = (review['answers'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: released
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              review['title']?.toString() ?? item.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'الدرجة المستحقة: ${review['score'] ?? 0} من ${review['max_score'] ?? 0}',
                        style: const TextStyle(
                          color: AppColors.parentRole,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if ((review['teacher_feedback']?.toString() ?? '')
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('ملاحظات المعلم: ${review['teacher_feedback']}'),
                      ],
                      const SizedBox(height: 16),
                      Expanded(
                        child: answers.isEmpty
                            ? const Center(child: Text('لا توجد إجابات مسجلة.'))
                            : ListView.separated(
                                itemCount: answers.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, index) {
                                  final answer = answers[index];
                                  final isCorrect =
                                      answer['is_correct'] == true;
                                  final color = isCorrect
                                      ? AppColors.success
                                      : AppColors.error;
                                  return DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.08),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.35),
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                isCorrect
                                                    ? Icons.check_circle
                                                    : Icons.cancel,
                                                color: color,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  answer['prompt']
                                                          ?.toString() ??
                                                      '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'إجابة الطالب: ${answer['student_answer'] ?? '-'}',
                                          ),
                                          Text(
                                            'الإجابة النموذجية: ${answer['correct_answer'] ?? '-'}',
                                          ),
                                          Text(
                                            'النقاط: ${answer['points_awarded'] ?? 0} / ${answer['max_points'] ?? 0}',
                                          ),
                                          if ((answer['explanation']
                                                      ?.toString() ??
                                                  '')
                                              .trim()
                                              .isNotEmpty)
                                            Text(
                                              'الشرح والتوضيح: ${answer['explanation']}',
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_clock, size: 42),
                      const SizedBox(height: 12),
                      Text(
                        review['message']?.toString() ??
                            'لم يتم اعتماد وإعلان نتائج هذا الاختبار بعد.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('إغلاق'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  _ParentScheduleItem? get _nextClassSession {
    if (_scheduleItems.isEmpty) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final futureSessions = _scheduleItems.where((s) {
      if (s.sessionDate != null) {
        return !s.sessionDate!.isBefore(today);
      }
      return true;
    }).toList();
    return futureSessions.isNotEmpty ? futureSessions.first : _scheduleItems.first;
  }









  static String _formatDate(DateTime? value) {
    if (value == null) return 'غير محدد';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}





typedef _ParentExamItem = ParentExamItem;
typedef _ParentHomeworkItem = ParentHomeworkItem;
typedef _ParentScheduleItem = ParentScheduleItem;
typedef _ParentAttendanceItem = ParentAttendanceItem;

typedef _ParentLeaveItem = ParentLeaveItem;


