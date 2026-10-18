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
import '../../design_system/tokens/typography.dart';
import '../../design_system/widgets/portal_components.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/auth/domain/repositories/i_auth_repository.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/communication/data/repositories/supabase_notification_repository.dart';
import '../../features/communication/domain/repositories/i_notification_repository.dart';
import '../../features/communication/domain/models/notification.dart';
import '../../features/payments/data/repositories/supabase_payment_repositories.dart';
import '../../features/payments/domain/models/payment_models.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/viewmodels/profile_viewmodel.dart';
import '../../features/study_workspace/data/repositories/supabase_student_learning_repository.dart';
import '../../features/study_workspace/domain/models/study_workspace_models.dart';
import '../../features/parent_portal/presentation/screens/absence_excuse_dialog.dart';
import '../../features/parent_portal/presentation/screens/link_child_screen.dart';
import '../../features/parent_portal/presentation/screens/monthly_report_card_screen.dart';
import '../../features/parent_portal/presentation/screens/parent_financial_ledger_screen.dart';
import '../../features/parent_portal/presentation/screens/child_assignments_screen.dart';
import '../../features/parent_portal/presentation/screens/child_schedule_screen.dart';
import 'screens/parent_helpdesk_screen.dart';

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
          child: _selectedIndex == 6
              ? Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: _buildHeader(),
                    ),
                    const Expanded(child: ParentHelpdeskScreen()),
                  ],
                )
              : _selectedIndex == 8
                  ? Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                          child: _buildHeader(),
                        ),
                        const Expanded(child: AppSettingsPanel()),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
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
              if (mounted) {
                await widget.authViewModel.restoreSession();
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
        if (_linkedChildren.length > 1) ...[
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
      6 => const ParentHelpdeskScreen(),
      7 => _buildAccountPage(),
      8 => const AppSettingsPanel(),
      _ => _buildOverviewPage(),
    };
  }

  Widget _buildAccountPage() {
    final profile = widget.authViewModel.currentUser;
    final name = profile?.fullName ?? 'ولي الأمر';
    final email = profile?.email ?? '';
    final phone = profile?.phoneNumber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PortalSectionTitle(
          title: 'الملف الشخصي',
          subtitle: 'إدارة حساب ولي الأمر وصلاحيات الدخول.',
        ),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: EditableAvatar(
              avatarUrl: profile?.avatarUrl,
              name: name,
              role: 'parent',
              userId: profile?.id,
              userEmail: profile?.email,
              radius: 46,
              onAvatarChanged: (_) async {
                if (mounted) {
                  await widget.authViewModel.restoreSession();
                  setState(() {});
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        PortalListCard(
          icon: Icons.account_circle,
          accentColor: AppColors.parentRole,
          title: name,
          subtitle: [
            if (email.isNotEmpty) email,
            if (phone != null && phone.isNotEmpty) phone,
          ].join(' • '),
          trailing: [
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      viewModel: ProfileViewModel(
                        getIt<IAuthRepository>(),
                        widget.authViewModel.currentUser,
                      ),
                      onSignedOut: widget.authViewModel.signOut,
                    ),
                  ),
                );
                if (mounted) {
                  await widget.authViewModel.restoreSession();
                }
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('تعديل'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PortalListCard(
          icon: Icons.notifications_active,
          accentColor: AppColors.parentRole,
          title: 'الإشعارات والتنبيهات',
          subtitle: _unreadCount == 0
              ? 'لا توجد إشعارات غير مقروءة.'
              : 'لديك $_unreadCount إشعارات جديدة غير مقروءة.',
          trailing: [
            TextButton(
              onPressed: () => setState(() => _selectedIndex = 5),
              child: const Text('عرض'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PortalListCard(
          icon: Icons.settings,
          accentColor: AppColors.info,
          title: 'الإعدادات',
          subtitle: 'تخصيص المظهر، تفضيلات التنبيهات، واللغة.',
          trailing: [
            TextButton(
              onPressed: () => setState(() => _selectedIndex = 8),
              child: const Text('فتح'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PortalListCard(
          icon: Icons.logout,
          accentColor: AppColors.error,
          title: 'تسجيل الخروج',
          subtitle: 'الخروج من حساب ولي الأمر على هذا الجهاز.',
          trailing: [
            TextButton(
              onPressed: widget.authViewModel.signOut,
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ],
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
    final progress = _averageProgress();
    final attendanceRate = _attendanceRate();
    final balance = _financialSummary?.remainingBalanceMinor ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LiveChildPresenceRadar(
          child: _selectedChild,
          attendance: _attendance,
          learningSnapshot: _learningSnapshot,
          onExcuseRequest: _createLeaveRequest,
        ),
        const SizedBox(height: 14),
        _ParentQuickActionsGrid(
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
          onOpenWhatsApp: _launchWhatsAppSupport,
        ),
        const SizedBox(height: 18),
        PortalMetricGrid(
          children: [
            PortalMetricCard(
              label: 'مستوى التقدم الدراسي',
              value: '${progress.round()}%',
              icon: Icons.trending_up,
              accentColor: AppColors.success,
              onTap: () => setState(() => _selectedIndex = 1),
            ),
            PortalMetricCard(
              label: 'نسبة الحضور والالتزام',
              value: '${attendanceRate.round()}%',
              icon: Icons.fact_check,
              accentColor: AppColors.info,
              onTap: () => setState(() => _selectedIndex = 2),
            ),
            PortalMetricCard(
              label: 'المستحقات المتبقية',
              value: _money(balance, _financialSummary?.currency ?? 'EGP'),
              icon: Icons.receipt_long,
              accentColor: balance > 0 ? AppColors.warning : AppColors.success,
              onTap: () => setState(() => _selectedIndex = 3),
            ),
            PortalMetricCard(
              label: 'تنبيهات غير مقروءة',
              value: _unreadCount.toString(),
              icon: Icons.notifications_active,
              accentColor: AppColors.parentRole,
              onTap: () => setState(() => _selectedIndex = 5),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ParentInsightPanel(insights: _buildParentInsights()),
        const SizedBox(height: 18),
        const PortalSectionTitle(
          title: 'المجموعات والفصول النشطة',
          subtitle: 'المجموعات المسجل بها الطالب حالياً بالسنتر والمدرس المشرف.',
        ),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: _childGroups.isEmpty,
          emptyText: 'لا توجد مجموعات نشطة مسجلة لهذا الطالب حالياً.',
          children: _childGroups
              .map(
                (group) => PortalListCard(
                  icon: Icons.group_work,
                  accentColor: AppColors.info,
                  title: group.name,
                  subtitle: '${group.code} • ${group.status}',
                  trailing: [PortalStatusChip(status: group.status)],
                ),
              )
              .toList(),
        ),
        Row(
          children: [
            const Expanded(
              child: PortalSectionTitle(
                title: 'الحصة القادمة وجدول المواعيد',
                subtitle: 'الحصة الدراسية القادمة ومكان انعقادها بالسنتر.',
              ),
            ),
            TextButton.icon(
              onPressed: () {
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
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text('جدول المواعيد'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildNextLessonCard(),
      ],
    );
  }

  Widget _buildProgressPage() {
    final snapshot = _learningSnapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalMetricGrid(
          children: (snapshot?.metrics ?? const <StudyMetric>[])
              .map(
                (metric) => PortalMetricCard(
                  label: metric.label,
                  value: metric.value,
                  icon: Icons.insights,
                  accentColor: AppColors.studentRole,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(
          title: 'الاختبارات والتقييمات',
          subtitle: 'الاختبارات المنجزة، الدرجات المسجلة، ومراجعة الإجابات.',
        ),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: _examItems.isEmpty,
          emptyText: 'لا توجد اختبارات مسجلة لهذا الطالب حتى الآن.',
          children: _examItems
              .map(
                (item) => PortalListCard(
                  icon: Icons.quiz,
                  accentColor: item.canReview
                      ? AppColors.success
                      : item.attemptCount > 0
                      ? AppColors.warning
                      : AppColors.info,
                  title: item.title,
                  subtitle:
                      '${item.groupName} • ${item.durationMinutes} دقيقة • المحاولات: ${item.attemptCount}/${item.maxAttempts}',
                  trailing: [
                    if (item.scoreLabel != null)
                      PortalStatusChip(status: item.scoreLabel!),
                    PortalStatusChip(
                      status: item.lastAttemptStatus ?? item.status,
                    ),
                  ],
                  onTap: item.canReview
                      ? () => _showParentExamReview(item)
                      : null,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: PortalSectionTitle(
                title: 'الواجبات والتكليفات المدرسية',
                subtitle: 'متابعة حل وتسليم الواجبات والتكليفات الدورية.',
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
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
              icon: const Icon(Icons.assignment_outlined, size: 18),
              label: const Text('كافة الواجبات'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: _homeworkItems.isEmpty,
          emptyText: 'لا توجد واجبات أو تكليفات مدرسية مسجلة لهذا الطالب حالياً.',
          children: _homeworkItems
              .take(5)
              .map(
                (hw) => PortalListCard(
                  icon: Icons.assignment_outlined,
                  accentColor: hw.status == 'graded'
                      ? AppColors.success
                      : hw.status == 'submitted'
                          ? AppColors.info
                          : hw.status == 'missing'
                              ? AppColors.error
                              : AppColors.warning,
                  title: hw.title,
                  subtitle:
                      '${hw.subjectName} • ${hw.groupName}${hw.dueAt != null ? ' • التسليم قبل: ${_formatDate(hw.dueAt)}' : ''}',
                  trailing: [
                    if (hw.scoreLabel != null)
                      PortalStatusChip(status: hw.scoreLabel!),
                    PortalStatusChip(
                      status: hw.status == 'graded'
                          ? 'تم التصحيح'
                          : hw.status == 'submitted'
                              ? 'تم التسليم'
                              : hw.status == 'missing'
                                  ? 'متأخر'
                                  : 'مطلوب حله',
                    ),
                  ],
                  onTap: () {
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
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(
          title: 'الدروس والمناهج المنشورة',
          subtitle: 'يتم احتساب التقدم الدراسي بناءً على إنجاز الطالب.',
        ),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: snapshot == null || snapshot.availableLessons.isEmpty,
          emptyText: 'لا توجد دروس أو شروحات منشورة لهذا الطالب حالياً.',
          children: (snapshot?.availableLessons ?? const <StudyLessonSummary>[])
              .map(
                (lesson) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text('${lesson.pathName} • ${lesson.unitName}'),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(value: lesson.progress),
                        const SizedBox(height: 6),
                        Text(
                          '${lesson.progressPercentage}% • صفحة ${lesson.lastPage} من ${lesson.totalPages} • ${_formatStudyTime(lesson.timeSpentSeconds)}',
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildAttendancePage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalMetricGrid(
          children: [
            PortalMetricCard(
              label: 'حضور',
              value: _attendance
                  .where((item) => item.status == 'present')
                  .length
                  .toString(),
              icon: Icons.check_circle,
              accentColor: AppColors.success,
            ),
            PortalMetricCard(
              label: 'غياب',
              value: _attendance
                  .where((item) => item.status == 'absent')
                  .length
                  .toString(),
              icon: Icons.cancel,
              accentColor: AppColors.error,
            ),
            PortalMetricCard(
              label: 'تأخير',
              value: _attendance
                  .where((item) => item.status == 'late')
                  .length
                  .toString(),
              icon: Icons.schedule,
              accentColor: AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: PortalSectionTitle(
                title: 'أعذار وطلبات الغياب',
                subtitle: 'تقديم ومتابعة طلبات الاعتذار عن الحضور للسنتر.',
              ),
            ),
            FilledButton.icon(
              onPressed: _selectedChild == null ? null : _createLeaveRequest,
              icon: const Icon(Icons.add),
              label: const Text('تقديم عذر'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: _leaveRequests.isEmpty,
          emptyText: 'لا توجد طلبات أعذار غياب مسجلة.',
          children: _leaveRequests
              .map(
                (item) => PortalListCard(
                  icon: Icons.event_busy,
                  accentColor: _statusColor(item.status),
                  title: item.reason,
                  subtitle:
                      '${item.groupName} • ${_formatDate(item.submittedAt)}',
                  trailing: [PortalStatusChip(status: item.status)],
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'سجل الحضور والغياب التفصيلي'),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: _attendance.isEmpty,
          emptyText: 'لا توجد حصص مسجلة في سجل الحضور بعد.',
          children: _attendance
              .map(
                (item) => PortalListCard(
                  icon: item.status == 'present'
                      ? Icons.check_circle
                      : item.status == 'late'
                      ? Icons.schedule
                      : Icons.cancel,
                  accentColor: _statusColor(item.status),
                  title: item.groupName,
                  subtitle:
                      '${_formatDate(item.sessionDate)} • ${item.groupCode}',
                  trailing: [PortalStatusChip(status: item.status)],
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPaymentsPage() {
    final summary = _financialSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalMetricGrid(
          children: [
            PortalMetricCard(
              label: 'عدد الفواتير',
              value: (summary?.invoiceCount ?? _invoices.length).toString(),
              icon: Icons.receipt,
              accentColor: AppColors.info,
            ),
            PortalMetricCard(
              label: 'إجمالي المستحق',
              value: _money(summary?.totalDueMinor ?? 0, summary?.currency),
              icon: Icons.account_balance_wallet,
              accentColor: AppColors.warning,
            ),
            PortalMetricCard(
              label: 'المدفوع كاش',
              value: _money(summary?.totalPaidMinor ?? 0, summary?.currency),
              icon: Icons.verified,
              accentColor: AppColors.success,
            ),
            PortalMetricCard(
              label: 'المتبقي للسداد',
              value: _money(
                summary?.remainingBalanceMinor ?? 0,
                summary?.currency,
              ),
              icon: Icons.pending_actions,
              accentColor: (summary?.remainingBalanceMinor ?? 0) > 0
                  ? AppColors.error
                  : AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: PortalSectionTitle(title: 'فواتير واشتراكات الحصص')),
            FilledButton.tonalIcon(
              onPressed: _selectedChild == null ? null : _exportFinancialLedger,
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('كشف حساب PDF معتمد'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: _invoices.isEmpty,
          emptyText: 'لا توجد فواتير صادرة لهذا الطالب.',
          children: _invoices
              .map(
                (invoice) => PortalListCard(
                  icon: Icons.receipt_long,
                  accentColor: _statusColor(invoice.status),
                  title: invoice.invoiceNumber.isEmpty
                      ? 'فاتورة'
                      : invoice.invoiceNumber,
                  subtitle:
                      '${_money(invoice.totalMinor, invoice.currency)} • استحقاق ${_formatDate(invoice.dueAt)}',
                  trailing: [PortalStatusChip(status: invoice.status)],
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'إيصالات السداد والمعاملات'),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: _receipts.isEmpty,
          emptyText: 'لا توجد إيصالات سداد مسجلة حتى الآن.',
          children: _receipts
              .map(
                (receipt) => PortalListCard(
                  icon: Icons.receipt,
                  accentColor: AppColors.success,
                  title: receipt.receiptNumber.isEmpty
                      ? 'إيصال #${_shortId(receipt.id)}'
                      : receipt.receiptNumber,
                  subtitle:
                      'المبلغ المسدد: ${_money(receipt.amountMinor, receipt.currency)} • التاريخ: ${_formatDate(receipt.issuedAt)}',
                  trailing: const [PortalStatusChip(status: 'paid')],
                  onTap: () => _showReceiptDialog(receipt),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMonthlyReportPage() {
    final report = _ParentMonthlyReport.fromState(
      attendance: _attendance,
      lessons: _learningSnapshot?.availableLessons ?? const [],
      invoices: _invoices,
      summary: _financialSummary,
    );
    final child = _selectedChild;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: PortalSectionTitle(
                title: 'التقرير الشهري التراكمي',
                subtitle:
                    'ملخص شهر ${report.monthLabel} للطالب ${child?.fullName ?? "المحدد"}.',
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _selectedChild == null ? null : _openOfficialReportCard,
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('كارت تقرير معتمد (PDF)'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PortalMetricGrid(
          children: [
            PortalMetricCard(
              label: 'نسبة الحضور',
              value: '${report.attendanceRate.round()}%',
              icon: Icons.fact_check,
              accentColor: report.attendanceRate >= 85
                  ? AppColors.success
                  : AppColors.warning,
            ),
            PortalMetricCard(
              label: 'التقدم الدراسي',
              value: '${report.averageProgress.round()}%',
              icon: Icons.trending_up,
              accentColor: AppColors.studentRole,
            ),
            PortalMetricCard(
              label: 'الحصص المكتملة',
              value: report.completedLessons.toString(),
              icon: Icons.done_all,
              accentColor: AppColors.success,
            ),
            PortalMetricCard(
              label: 'المستحقات المتبقية',
              value: _money(
                report.remainingBalanceMinor,
                _financialSummary?.currency,
              ),
              icon: Icons.payments,
              accentColor: report.remainingBalanceMinor > 0
                  ? AppColors.error
                  : AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ParentInsightPanel(insights: report.recommendations),
        const SizedBox(height: 18),
        const PortalSectionTitle(
          title: 'سجل حضور وغياب الشهر',
          subtitle: 'الحصص المنعقدة خلال الشهر الحالي فقط.',
        ),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: report.monthAttendance.isEmpty,
          emptyText: 'لا توجد حصص مسجلة خلال هذا الشهر.',
          children: report.monthAttendance
              .map(
                (item) => PortalListCard(
                  icon: item.status == 'present'
                      ? Icons.check_circle
                      : item.status == 'late'
                      ? Icons.schedule
                      : Icons.cancel,
                  accentColor: _statusColor(item.status),
                  title: item.groupName,
                  subtitle:
                      '${_formatDate(item.sessionDate)} | ${item.groupCode}',
                  trailing: [PortalStatusChip(status: item.status)],
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'متابعة سداد الرسوم والفواتير'),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: report.openInvoices.isEmpty,
          emptyText: 'لا توجد فواتير معلقة.',
          children: report.openInvoices
              .map(
                (invoice) => PortalListCard(
                  icon: Icons.receipt_long,
                  accentColor: _statusColor(invoice.status),
                  title: invoice.invoiceNumber.isEmpty
                      ? 'فاتورة'
                      : invoice.invoiceNumber,
                  subtitle:
                      '${_money(invoice.totalMinor - invoice.amountPaidMinor, invoice.currency)} متبقي • استحقاق ${_formatDate(invoice.dueAt)}',
                  trailing: [PortalStatusChip(status: invoice.status)],
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildNotificationsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: PortalSectionTitle(
                title: 'الإشعارات والتنبيهات',
                subtitle: 'تنبيهات وتحديثات السنتر المرسلة لولي الأمر.',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _notifications.isEmpty
                  ? null
                  : _markAllNotificationsRead,
              icon: const Icon(Icons.done_all),
              label: const Text('تحديد الكل كمقروء'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _InfoList(
          isEmpty: _notifications.isEmpty,
          emptyText: 'لا توجد إشعارات مسجلة حالياً.',
          children: _notifications
              .map(
                (notification) => PortalListCard(
                  icon: notification.isRead
                      ? Icons.notifications_none
                      : Icons.notifications_active,
                  accentColor: notification.isRead
                      ? AppColors.info
                      : AppColors.parentRole,
                  title: notification.title,
                  subtitle:
                      '${notification.message} • ${_formatDate(notification.createdAt)}',
                  trailing: notification.isRead
                      ? const []
                      : [const PortalStatusChip(status: 'pending')],
                  onTap: () => _openNotification(notification),
                ),
              )
              .toList(),
        ),
      ],
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          receipt.receiptNumber.isEmpty
              ? 'إيصال دفع إلكتروني'
              : receipt.receiptNumber,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.verified_rounded,
              color: AppColors.success,
              size: 42,
            ),
            const SizedBox(height: 12),
            _ReceiptDetailLine(
              label: 'المبلغ المسدد',
              value: _money(receipt.amountMinor, receipt.currency),
            ),
            _ReceiptDetailLine(
              label: 'تاريخ السداد',
              value: _formatDate(receipt.issuedAt),
            ),
            _ReceiptDetailLine(
              label: 'رقم الفاتورة',
              value: _shortId(receipt.invoiceId),
            ),
            _ReceiptDetailLine(
              label: 'رقم المعاملة (المرجع)',
              value: _shortId(receipt.transactionId),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
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

  Widget _buildNextLessonCard() {
    final nextClass = _nextClassSession;
    final child = _selectedChild;
    if (nextClass != null) {
      return PortalListCard(
        icon: Icons.access_time_filled_rounded,
        accentColor: AppColors.primary,
        title: '${nextClass.subjectName} (${nextClass.groupName})',
        subtitle:
            '${nextClass.formattedTiming} • ${nextClass.location} • ${nextClass.teacherName}',
        trailing: [PortalStatusChip(status: nextClass.statusLabel)],
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChildScheduleScreen(
                studentId: child?.id,
                studentName: child?.fullName,
              ),
            ),
          );
        },
      );
    }

    final lesson = _learningSnapshot?.nextLesson;
    if (lesson != null) {
      return PortalListCard(
        icon: lesson.hasPdf ? Icons.picture_as_pdf : Icons.menu_book,
        accentColor: AppColors.studentRole,
        title: lesson.title,
        subtitle:
            '${lesson.pathName} • ${lesson.unitName} • ${lesson.progressPercentage}% • ${_formatStudyTime(lesson.timeSpentSeconds)}',
        trailing: [PortalStatusChip(status: lesson.hasPdf ? 'ملف PDF' : 'شرح')],
      );
    }

    return const _InfoList(
      isEmpty: true,
      emptyText: 'لا توجد حصص قادمة مجدولة لهذا الطالب حالياً.',
      children: [],
    );
  }

  double _averageProgress() {
    final lessons = _learningSnapshot?.availableLessons ?? [];
    if (lessons.isEmpty) return 0;
    final total = lessons.fold<int>(
      0,
      (sum, lesson) => sum + lesson.progressPercentage,
    );
    return total / lessons.length;
  }

  double _attendanceRate() {
    if (_attendance.isEmpty) return 0;
    final present = _attendance
        .where((item) => item.status == 'present' || item.status == 'late')
        .length;
    return present * 100 / _attendance.length;
  }

  String _formatStudyTime(int seconds) {
    if (seconds < 60) return '$seconds ثانية';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes دقيقة';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours ساعة' : '$hours ساعة و $rest دقيقة';
  }

  List<_ParentInsight> _buildParentInsights() {
    final insights = <_ParentInsight>[];
    final attendanceRate = _attendanceRate();
    final progress = _averageProgress();
    final balance = _financialSummary?.remainingBalanceMinor ?? 0;
    final absentCount = _attendance
        .where((item) => item.status == 'absent')
        .length;
    final overdueInvoices = _invoices
        .where((invoice) => invoice.status == 'overdue')
        .length;

    if (attendanceRate < 75 && _attendance.isNotEmpty) {
      insights.add(
        _ParentInsight(
          icon: Icons.warning_amber,
          color: AppColors.error,
          title: 'متابعة نسبة الحضور',
          body:
              'نسبة الحضور الحالية ${attendanceRate.round()}% مع تسجيل $absentCount مرات غياب.',
        ),
      );
    }
    if (progress < 40 &&
        (_learningSnapshot?.availableLessons.isNotEmpty ?? false)) {
      insights.add(
        _ParentInsight(
          icon: Icons.menu_book,
          color: AppColors.warning,
          title: 'مستوى التقدم الدراسي بحاجة لمتابعة',
          body: 'متوسط إنجاز المناهج والدروس ${progress.round()}% فقط.',
        ),
      );
    }
    if (balance > 0) {
      insights.add(
        _ParentInsight(
          icon: Icons.payments,
          color: overdueInvoices > 0 ? AppColors.error : AppColors.warning,
          title: overdueInvoices > 0 ? 'متأخرات مالية مستحقة' : 'رسوم دراسية مستحقة السداد',
          body: 'المتبقي للسداد: ${_money(balance, _financialSummary?.currency)}.',
        ),
      );
    }
    if (_unreadCount > 0) {
      insights.add(
        _ParentInsight(
          icon: Icons.notifications_active,
          color: AppColors.parentRole,
          title: 'تنبيهات وإشعارات جديدة',
          body: 'لديك $_unreadCount إشعارات غير مقروءة من السنتر.',
        ),
      );
    }
    if (insights.isEmpty) {
      insights.add(
        const _ParentInsight(
          icon: Icons.verified,
          color: AppColors.success,
          title: 'المستوى ممتاز ومستقر',
          body: 'الحضور والتحصيل الدراسي والمدفوعات منتظمة دون أي ملاحظات.',
        ),
      );
    }
    return insights;
  }

  static String _money(int minor, String? currency) {
    final amount = minor / 100;
    final formatted = amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
    final cur = (currency == null || currency == 'EGP') ? 'ج.م' : currency;
    return '$formatted $cur';
  }

  static String _shortId(String value) {
    if (value.length <= 8) return value;
    return value.substring(0, 8);
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return 'غير محدد';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'present' || 'paid' || 'approved' || 'submitted' => AppColors.success,
      'late' || 'pending' || 'issued' => AppColors.warning,
      'absent' || 'overdue' || 'rejected' || 'failed' => AppColors.error,
      _ => AppColors.info,
    };
  }
}

class _InfoList extends StatelessWidget {
  final bool isEmpty;
  final String emptyText;
  final List<Widget> children;

  const _InfoList({
    required this.isEmpty,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 10),
              Expanded(child: Text(emptyText)),
            ],
          ),
        ),
      );
    }
    return Column(children: children);
  }
}

class _ReceiptDetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptDetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption(Theme.of(context).hintColor),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.bodyMedium(
                Theme.of(context).colorScheme.onSurface,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentQuickActionsGrid extends StatelessWidget {
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenProgress;
  final VoidCallback onOpenWhatsApp;

  const _ParentQuickActionsGrid({
    required this.onOpenSchedule,
    required this.onOpenAttendance,
    required this.onOpenProgress,
    required this.onOpenWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final actions = [
      _ParentActionData(
        title: 'جدول المواعيد',
        subtitle: 'الحصص والقاعات الأسبوعية',
        badge: 'مواعيد 📅',
        icon: Icons.calendar_month_rounded,
        gradient: const [Color(0xFF0284C7), Color(0xFF0EA5E9)],
        borderAccent: const Color(0xFF38BDF8),
        onTap: () {
          HapticFeedback.lightImpact();
          onOpenSchedule();
        },
      ),
      _ParentActionData(
        title: 'سجل الحضور',
        subtitle: 'نسبة الالتزام والغياب',
        badge: 'متابعة 📊',
        icon: Icons.fact_check_rounded,
        gradient: const [Color(0xFF0D9488), Color(0xFF14B8A6)],
        borderAccent: const Color(0xFF14B8A6),
        onTap: () {
          HapticFeedback.lightImpact();
          onOpenAttendance();
        },
      ),
      _ParentActionData(
        title: 'الواجبات والدرجات',
        subtitle: 'متابعة الحل والتسليم',
        badge: 'أكاديمي ✍️',
        icon: Icons.assignment_rounded,
        gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        borderAccent: const Color(0xFF818CF8),
        onTap: () {
          HapticFeedback.lightImpact();
          onOpenProgress();
        },
      ),
      _ParentActionData(
        title: 'خدمة واتساب',
        subtitle: 'تواصل مباشر مع السنتر',
        badge: 'دعم 💬',
        icon: Icons.chat_rounded,
        gradient: const [Color(0xFF059669), Color(0xFF10B981)],
        borderAccent: const Color(0xFF10B981),
        onTap: () {
          HapticFeedback.lightImpact();
          onOpenWhatsApp();
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 640;
        final crossAxisCount = isWide ? 4 : 2;
        final childAspectRatio = isWide ? 1.6 : 1.35;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            return _ParentActionTile(action: actions[index], isDark: isDark);
          },
        );
      },
    );
  }
}

class _ParentActionData {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final List<Color> gradient;
  final Color borderAccent;
  final VoidCallback onTap;

  const _ParentActionData({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.gradient,
    required this.borderAccent,
    required this.onTap,
  });
}

class _ParentActionTile extends StatelessWidget {
  final _ParentActionData action;
  final bool isDark;

  const _ParentActionTile({
    required this.action,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.9)
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: action.borderAccent.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: action.borderAccent.withValues(alpha: isDark ? 0.12 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: action.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: action.gradient.first.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(action.icon, color: Colors.white, size: 19),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: action.borderAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: action.borderAccent.withValues(alpha: 0.3),
                        width: 0.7,
                      ),
                    ),
                    child: Text(
                      action.badge,
                      style: TextStyle(
                        color: action.borderAccent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParentInsight {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _ParentInsight({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}

class _ParentInsightPanel extends StatelessWidget {
  final List<_ParentInsight> insights;

  const _ParentInsightPanel({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PortalSectionTitle(
              title: 'توجيهات وملاحظات ولي الأمر',
              subtitle: 'نقاط متابعة هامة مستخلصة من أداء الطالب الفعلي.',
            ),
            const SizedBox(height: 12),
            ...insights.map(
              (insight) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(insight.icon, color: insight.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(insight.body),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentMonthlyReport {
  final String monthLabel;
  final List<_ParentAttendanceItem> monthAttendance;
  final List<Invoice> openInvoices;
  final double attendanceRate;
  final double averageProgress;
  final int completedLessons;
  final int remainingBalanceMinor;
  final List<_ParentInsight> recommendations;

  const _ParentMonthlyReport({
    required this.monthLabel,
    required this.monthAttendance,
    required this.openInvoices,
    required this.attendanceRate,
    required this.averageProgress,
    required this.completedLessons,
    required this.remainingBalanceMinor,
    required this.recommendations,
  });

  factory _ParentMonthlyReport.fromState({
    required List<_ParentAttendanceItem> attendance,
    required List<StudyLessonSummary> lessons,
    required List<Invoice> invoices,
    required FinancialSummary? summary,
  }) {
    final now = DateTime.now();
    final monthAttendance = attendance.where((item) {
      final date = item.sessionDate;
      return date != null && date.year == now.year && date.month == now.month;
    }).toList();
    final present = monthAttendance
        .where(
          (item) =>
              item.status == 'present' ||
              item.status == 'late' ||
              item.status == 'excused',
        )
        .length;
    final attendanceRate = monthAttendance.isEmpty
        ? 0.0
        : present * 100 / monthAttendance.length;
    final averageProgress = lessons.isEmpty
        ? 0.0
        : lessons.fold<int>(
                0,
                (sum, lesson) => sum + lesson.progressPercentage,
              ) /
              lessons.length;
    final completedLessons = lessons
        .where((lesson) => lesson.progressPercentage >= 100)
        .length;
    final openInvoices = invoices
        .where(
          (invoice) =>
              invoice.status == 'issued' ||
              invoice.status == 'overdue' ||
              invoice.status == 'partially_paid',
        )
        .toList();
    final remaining = summary?.remainingBalanceMinor ?? 0;
    final recommendations = <_ParentInsight>[];

    if (attendanceRate < 85 && monthAttendance.isNotEmpty) {
      recommendations.add(
        _ParentInsight(
          icon: Icons.event_busy,
          color: AppColors.warning,
          title: 'تحسين الانتظام في الحضور',
          body:
              'نسبة الحضور لهذا الشهر ${attendanceRate.round()}%. يرجى الحرص على حضور الحصص القادمة.',
        ),
      );
    }
    if (averageProgress < 50 && lessons.isNotEmpty) {
      recommendations.add(
        _ParentInsight(
          icon: Icons.schedule,
          color: AppColors.warning,
          title: 'تخصيص وقت يومي للمذاكرة',
          body:
              'متوسط التقدم في الدروس ${averageProgress.round()}%. نوصي بجدول مراجعة يومي.',
        ),
      );
    }
    if (remaining > 0) {
      recommendations.add(
        _ParentInsight(
          icon: Icons.receipt_long,
          color: AppColors.error,
          title: 'سداد الرسوم الدراسية',
          body: 'يوجد مستحق مالي متبقي يرجى سداده بخزينة السنتر.',
        ),
      );
    }
    if (recommendations.isEmpty) {
      recommendations.add(
        const _ParentInsight(
          icon: Icons.verified,
          color: AppColors.success,
          title: 'الوضع الشهري ممتاز ومستقر',
          body: 'لا توجد أي ملاحظات أو متأخرات عاجلة.',
        ),
      );
    }

    return _ParentMonthlyReport(
      monthLabel: '${now.year}-${now.month.toString().padLeft(2, '0')}',
      monthAttendance: monthAttendance,
      openInvoices: openInvoices,
      attendanceRate: attendanceRate,
      averageProgress: averageProgress,
      completedLessons: completedLessons,
      remainingBalanceMinor: remaining,
      recommendations: recommendations,
    );
  }
}

class _ParentExamItem {
  final String id;
  final String title;
  final String? description;
  final String? groupId;
  final String groupName;
  final int durationMinutes;
  final int maxAttempts;
  final String status;
  final String? lastAttemptStatus;
  final int attemptCount;
  final double? lastScore;
  final double? maxScore;

  const _ParentExamItem({
    required this.id,
    required this.title,
    required this.description,
    required this.groupId,
    required this.groupName,
    required this.durationMinutes,
    required this.maxAttempts,
    required this.status,
    required this.lastAttemptStatus,
    required this.attemptCount,
    required this.lastScore,
    required this.maxScore,
  });

  bool get canReview =>
      lastAttemptStatus == 'submitted' ||
      lastAttemptStatus == 'graded' ||
      lastAttemptStatus == 'expired';

  double? get percentage =>
      (lastScore != null && maxScore != null && maxScore! > 0)
          ? (lastScore! / maxScore!) * 100
          : null;

  String? get scoreLabel {
    if (lastScore == null) return null;
    final score = lastScore == lastScore!.roundToDouble()
        ? lastScore!.toStringAsFixed(0)
        : lastScore!.toStringAsFixed(1);
    final max = maxScore == null
        ? ''
        : maxScore == maxScore!.roundToDouble()
        ? ' / ${maxScore!.toStringAsFixed(0)}'
        : ' / ${maxScore!.toStringAsFixed(1)}';
    return '$score$max';
  }

  factory _ParentExamItem.fromJson(Map json) {
    return _ParentExamItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'اختبار',
      description: json['description']?.toString(),
      groupId: json['group_id']?.toString(),
      groupName: json['group_name']?.toString() ?? 'المجموعة',
      durationMinutes: (json['duration_minutes'] as num? ?? 30).toInt(),
      maxAttempts: (json['max_attempts'] as num? ?? 1).toInt(),
      status: json['status']?.toString() ?? 'published',
      lastAttemptStatus: json['last_attempt_status']?.toString(),
      attemptCount: (json['attempt_count'] as num? ?? 0).toInt(),
      lastScore: (json['last_score'] as num?)?.toDouble(),
      maxScore: (json['max_score'] as num?)?.toDouble(),
    );
  }
}

class _ParentHomeworkItem {
  final String id;
  final String title;
  final String? description;
  final String? subjectId;
  final String subjectName;
  final String? groupId;
  final String groupName;
  final DateTime? dueAt;
  final double? maxScore;
  final String status;
  final String? submissionStatus;
  final double? score;
  final DateTime? submittedAt;

  const _ParentHomeworkItem({
    required this.id,
    required this.title,
    this.description,
    this.subjectId,
    required this.subjectName,
    this.groupId,
    required this.groupName,
    this.dueAt,
    this.maxScore,
    required this.status,
    this.submissionStatus,
    this.score,
    this.submittedAt,
  });

  double? get percentage =>
      (score != null && maxScore != null && maxScore! > 0)
          ? (score! / maxScore!) * 100
          : null;

  String? get scoreLabel {
    if (score == null) return null;
    final s = score == score!.roundToDouble()
        ? score!.toStringAsFixed(0)
        : score!.toStringAsFixed(1);
    final m = maxScore == null
        ? ''
        : maxScore == maxScore!.roundToDouble()
            ? ' / ${maxScore!.toStringAsFixed(0)}'
            : ' / ${maxScore!.toStringAsFixed(1)}';
    return '$s$m';
  }

  factory _ParentHomeworkItem.fromJson(Map json) {
    return _ParentHomeworkItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'واجب منزلي',
      description: json['description']?.toString(),
      subjectId: json['subject_id']?.toString(),
      subjectName: json['subject_name']?.toString() ?? 'مادة دراسية',
      groupId: json['group_id']?.toString(),
      groupName: json['group_name']?.toString() ?? 'المجموعة',
      dueAt: DateTime.tryParse(json['due_at']?.toString() ?? ''),
      maxScore: (json['max_score'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'pending',
      submissionStatus: json['submission_status']?.toString(),
      score: (json['score'] as num?)?.toDouble(),
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
    );
  }
}

class _ParentScheduleItem {
  final String id;
  final String subjectName;
  final String groupName;
  final String teacherName;
  final String location;
  final String? startTime;
  final String? endTime;
  final DateTime? sessionDate;
  final int? dayOfWeek;
  final String status;

  const _ParentScheduleItem({
    required this.id,
    required this.subjectName,
    required this.groupName,
    required this.teacherName,
    required this.location,
    this.startTime,
    this.endTime,
    this.sessionDate,
    this.dayOfWeek,
    required this.status,
  });

  String get formattedTiming {
    final time = (startTime != null && endTime != null)
        ? '$startTime - $endTime'
        : (startTime ?? 'الموعد المحدد');
    final dateStr = sessionDate != null
        ? '${sessionDate!.day}/${sessionDate!.month}'
        : _dayName(dayOfWeek ?? 6);
    return '$dateStr • $time';
  }

  static String _dayName(int day) {
    return switch (day) {
      6 => 'السبت',
      7 || 0 => 'الأحد',
      1 => 'الإثنين',
      2 => 'الثلاثاء',
      3 => 'الأربعاء',
      4 => 'الخميس',
      5 => 'الجمعة',
      _ => 'يوم الحصة',
    };
  }

  String get statusLabel => switch (status.toLowerCase()) {
    'scheduled' || 'active' => 'مجدولة',
    'cancelled' => 'ملغاة',
    'completed' => 'مكتملة',
    'in_progress' => 'جارية الآن',
    _ => status,
  };

  factory _ParentScheduleItem.fromJson(Map json) {
    DateTime? sessionDate = DateTime.tryParse(json['session_date']?.toString() ?? '');
    final dayOfWeek = (json['day_of_week'] as num?)?.toInt();
    if (sessionDate == null && dayOfWeek != null) {
      final now = DateTime.now();
      final currentWeekday = now.weekday; // 1 = Mon .. 6 = Sat, 7 = Sun
      final targetWeekday = (dayOfWeek == 0 || dayOfWeek == 7) ? 7 : dayOfWeek;
      int daysUntil = targetWeekday - currentWeekday;
      if (daysUntil < 0) daysUntil += 7;
      sessionDate = DateTime(now.year, now.month, now.day).add(Duration(days: daysUntil));
    }
    return _ParentScheduleItem(
      id: json['class_session_id']?.toString() ??
          json['schedule_id']?.toString() ??
          json['id']?.toString() ??
          '',
      subjectName: json['subject_name']?.toString() ?? 'حصة دراسية',
      groupName: json['group_name']?.toString() ?? 'المجموعة',
      teacherName: json['teacher_name']?.toString() ?? 'معلم المادة',
      location: json['location']?.toString() ??
          json['room_name']?.toString() ??
          'القاعة الرئيسية',
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      sessionDate: sessionDate,
      dayOfWeek: dayOfWeek,
      status: json['status']?.toString() ?? 'scheduled',
    );
  }
}

class _ParentAttendanceItem {
  final String id;
  final String classSessionId;
  final String status;
  final DateTime? markedAt;
  final DateTime? sessionDate;
  final String groupName;
  final String groupCode;
  final DateTime? checkOutAt;

  const _ParentAttendanceItem({
    required this.id,
    required this.classSessionId,
    required this.status,
    required this.markedAt,
    required this.sessionDate,
    required this.groupName,
    required this.groupCode,
    this.checkOutAt,
  });

  factory _ParentAttendanceItem.fromJson(Map json) {
    return _ParentAttendanceItem(
      id: json['id']?.toString() ?? '',
      classSessionId: json['class_session_id']?.toString() ?? '',
      status: json['attendance_status']?.toString() ?? 'unknown',
      markedAt: DateTime.tryParse(json['marked_at']?.toString() ?? json['check_in_at']?.toString() ?? ''),
      sessionDate: DateTime.tryParse(json['session_date']?.toString() ?? ''),
      groupName: json['group_name']?.toString() ?? 'المجموعة',
      groupCode: json['group_code']?.toString() ?? '',
      checkOutAt: DateTime.tryParse(json['check_out_at']?.toString() ?? ''),
    );
  }
}

class _ParentLeaveItem {
  final String id;
  final String reason;
  final String status;
  final DateTime? submittedAt;
  final DateTime? sessionDate;
  final String groupName;

  const _ParentLeaveItem({
    required this.id,
    required this.reason,
    required this.status,
    required this.submittedAt,
    required this.sessionDate,
    required this.groupName,
  });

  factory _ParentLeaveItem.fromJson(Map json) {
    return _ParentLeaveItem(
      id: json['id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? 'طلب إذن غياب',
      status: json['status']?.toString() ?? 'pending',
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      sessionDate: DateTime.tryParse(json['session_date']?.toString() ?? ''),
      groupName: json['group_name']?.toString() ?? 'عام',
    );
  }
}

class _LiveChildPresenceRadar extends StatefulWidget {
  final Student? child;
  final List<_ParentAttendanceItem> attendance;
  final StudentLearningSnapshot? learningSnapshot;
  final VoidCallback onExcuseRequest;

  const _LiveChildPresenceRadar({
    required this.child,
    required this.attendance,
    required this.learningSnapshot,
    required this.onExcuseRequest,
  });

  @override
  State<_LiveChildPresenceRadar> createState() => _LiveChildPresenceRadarState();
}

class _LiveChildPresenceRadarState extends State<_LiveChildPresenceRadar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    if (child == null) return const SizedBox.shrink();

    final now = DateTime.now();
    _ParentAttendanceItem? todayItem;
    for (final item in widget.attendance) {
      final date = item.sessionDate ?? item.markedAt;
      if (date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        todayItem = item;
        break;
      }
    }

    final isPresent = todayItem != null &&
        (todayItem.status == 'present' || todayItem.status == 'late') &&
        todayItem.checkOutAt == null;
    final isCheckedOut = todayItem != null && todayItem.checkOutAt != null;
    final isAbsent = todayItem != null && todayItem.status == 'absent';

    Color cardColor;
    Color accentColor;
    String statusTitle;
    String statusSubtitle;
    String badgeText;

    if (isPresent) {
      cardColor = const Color(0xFF064E3B).withValues(alpha: 0.16);
      accentColor = const Color(0xFF10B981);
      statusTitle = 'الطالب متواجد في القاعة الدراسية الآن 🏫';
      final timeStr = todayItem.markedAt != null
          ? '${todayItem.markedAt!.hour.toString().padLeft(2, '0')}:${todayItem.markedAt!.minute.toString().padLeft(2, '0')}'
          : '';
      final elapsedMinutes = todayItem.markedAt != null
          ? now.difference(todayItem.markedAt!).inMinutes
          : 0;
      statusSubtitle =
          'سجل حضور الساعة $timeStr • ${todayItem.groupName} • متواجد منذ $elapsedMinutes دقيقة ⏱️';
      badgeText = 'داخل السنتر الآن 🟢';
    } else if (isCheckedOut) {
      cardColor = const Color(0xFF1E3A8A).withValues(alpha: 0.16);
      accentColor = const Color(0xFF3B82F6);
      statusTitle = 'غادر السنتر بأمان بعد الحصة 👋';
      final outTime = todayItem.checkOutAt != null
          ? '${todayItem.checkOutAt!.hour.toString().padLeft(2, '0')}:${todayItem.checkOutAt!.minute.toString().padLeft(2, '0')}'
          : '';
      statusSubtitle =
          'تم تسجيل الانصراف في تمام $outTime • نتمنى له عودة سالمة للبيت 🏠';
      badgeText = 'انصرف بنجاح ✔️';
    } else if (isAbsent) {
      cardColor = const Color(0xFF7F1D1D).withValues(alpha: 0.20);
      accentColor = const Color(0xFFEF4444);
      statusTitle = 'تنبيه غياب: الطالب لم يسجل حضوراً اليوم ⚠️';
      statusSubtitle =
          'حصة ${todayItem.groupName} المقررة اليوم لم يتم رصد حضور الطالب بها بالبوابة حتى الآن';
      badgeText = 'غياب غير مسجل بعذر 🔴';
    } else {
      cardColor = AppColors.primary.withValues(alpha: 0.08);
      accentColor = AppColors.primary;
      statusTitle = 'رادار التواجد ومتابعة الدخول والخروج';
      final next = widget.learningSnapshot?.nextLesson;
      statusSubtitle = next != null
          ? 'الحصة القادمة: ${next.title} (${next.pathName})'
          : 'لا توجد حصص مسجلة لليوم.';
      badgeText = 'في الانتظار ⏳';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPresent)
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 24 + (_pulseAnimation.value * 20),
                            height: 24 + (_pulseAnimation.value * 20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentColor.withValues(
                                alpha: (1.0 - _pulseAnimation.value) * 0.45,
                              ),
                            ),
                          );
                        },
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isAbsent
                        ? Icons.warning_amber_rounded
                        : (isCheckedOut
                            ? Icons.directions_walk_rounded
                            : Icons.school_rounded),
                    color: accentColor,
                    size: 22,
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      statusSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          if (isPresent) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'حضور موثق بالبوابة الإلكترونية الذكية للسنتر • القاعة مؤمنة بالكامل 🛡️',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          if (isAbsent) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: widget.onExcuseRequest,
                icon: const Icon(Icons.note_add_rounded, size: 18),
                label: const Text(
                  'تقديم عذر غياب فوري مع تقرير طبي/ورقي 📝',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
