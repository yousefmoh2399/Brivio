import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/injection.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/supabase_client_wrapper.dart';
import '../../core/security/permission.dart';
import '../../core/settings/app_settings_screen.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/widgets/portal_components.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/academy/presentation/screens/academy_screens.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/communication/domain/models/notification.dart';
import '../../features/communication/domain/repositories/i_notification_repository.dart';
import '../../features/communication/presentation/screens/notification_center_screen.dart';
import '../../features/communication/presentation/viewmodels/notification_center_viewmodel.dart';
import '../../features/attendance/presentation/screens/attendance_operations_screen.dart';
import '../../features/attendance/presentation/screens/reception_qr_gate_screen.dart';
import '../../features/helpdesk/presentation/screens/helpdesk_management_screen.dart';
import '../../features/payments/presentation/screens/finance_management_screen.dart';
import '../../features/payments/presentation/screens/teacher_settlement_screen.dart';
import '../../features/reports/presentation/screens/reports_dashboard_screen.dart';
import '../../features/reports/presentation/screens/attendance_reports_screen.dart';
import '../../features/payments/presentation/screens/bookstore_pos_screen.dart';
import '../../features/payments/presentation/screens/daily_cash_register_screen.dart';
import '../../features/academy/presentation/screens/classroom_capacity_screen.dart';
import '../../features/attendance/presentation/screens/reception_live_tv_kiosk_screen.dart';
import '../../features/academy/presentation/widgets/center_switcher_widget.dart';
import '../../features/academy/presentation/widgets/join_center_dialog.dart';

class StaffDashboard extends StatefulWidget {
  final AuthViewModel authViewModel;

  const StaffDashboard({super.key, required this.authViewModel});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  bool _isLoading = false;
  String? _errorMessage;
  int _selectedIndex = 0;
  List<Student> _students = [];
  List<Parent> _parents = [];
  List<Teacher> _teachers = [];
  List<GroupEntity> _groups = [];
  List<_StaffQueueItem> _leaveQueue = [];
  List<_StaffQueueItem> _invoiceQueue = [];
  List<_StaffQueueItem> _attendanceQueue = [];
  List<_StaffQueueItem> _enrollmentQueue = [];
  List<_StaffQueueItem> _operationsQueue = [];
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  List<String> _dataWarnings = [];
  StreamSubscription<AppNotification>? _notificationSubscription;
  late final NotificationCenterViewModel _notificationCenterViewModel;
  final _groupSearchController = TextEditingController();
  final _teacherSearchController = TextEditingController();
  String _studentSearch = '';
  String _parentSearch = '';
  String _teacherSearch = '';
  String _groupSearch = '';

  int get unreadCount => _unreadCount;
  List<AppNotification> get notifications => _notifications;

  static const _destinations = [
    PortalDestination(icon: Icons.dashboard_customize, label: 'Overview'),
    PortalDestination(icon: Icons.assignment_late, label: 'Queues'),
    PortalDestination(icon: Icons.school, label: 'Students'),
    PortalDestination(icon: Icons.family_restroom, label: 'Parents'),
    PortalDestination(icon: Icons.co_present, label: 'Teachers'),
    PortalDestination(icon: Icons.group_work, label: 'Groups'),
    PortalDestination(icon: Icons.fact_check, label: 'Attendance'),
    PortalDestination(icon: Icons.receipt_long, label: 'Finance'),
    PortalDestination(icon: Icons.support_agent, label: 'Helpdesk'),
    PortalDestination(icon: Icons.notifications, label: 'Notifications'),
    PortalDestination(icon: Icons.analytics, label: 'Reports'),
    PortalDestination(icon: Icons.settings, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _notificationCenterViewModel = NotificationCenterViewModel(
      getIt<INotificationRepository>(),
    );
    _subscribeToNotifications();
    _loadStaffData();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _notificationCenterViewModel.dispose();
    _groupSearchController.dispose();
    _teacherSearchController.dispose();
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

  bool _has(Permission permission) =>
      widget.authViewModel.state.hasPermission(permission);

  Future<void> _loadStaffData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _dataWarnings = [];
    });
    try {
      final wrapper = _wrapper;
      final studentRepo = SupabaseStudentRepository(wrapper);
      final parentRepo = SupabaseParentRepository(wrapper);
      final teacherRepo = SupabaseTeacherRepository(wrapper);
      final groupRepo = SupabaseGroupRepository(wrapper);
      final notificationRepo = getIt<INotificationRepository>();
      final warnings = <String>[];

      final results = await Future.wait<Object>([
        _has(Permission.studentsView)
            ? studentRepo.fetchStudents()
            : Future.value(
                const PaginatedResult<Student>(
                  total: 0,
                  page: 1,
                  pageSize: 20,
                  data: [],
                ),
              ),
        _safePageQuery<Parent>(
          'Parents',
          warnings,
          () => parentRepo.fetchParents(pageSize: 100),
          const PaginatedResult<Parent>(
            total: 0,
            page: 1,
            pageSize: 100,
            data: [],
          ),
        ),
        _safePageQuery<Teacher>(
          'Teachers',
          warnings,
          () => teacherRepo.fetchTeachers(pageSize: 100),
          const PaginatedResult<Teacher>(
            total: 0,
            page: 1,
            pageSize: 100,
            data: [],
          ),
        ),
        _has(Permission.groupsView)
            ? groupRepo.fetchGroups()
            : Future.value([]),
        _fetchLeaveQueue(warnings),
        _fetchInvoiceQueue(warnings),
        _fetchAttendanceQueue(warnings),
        _fetchEnrollmentQueue(warnings),
        _fetchOperationsQueue(warnings),
        notificationRepo.getNotifications().catchError((error) {
          warnings.add('Notifications: $error');
          return <AppNotification>[];
        }),
        notificationRepo.getUnreadCount().catchError((error) {
          warnings.add('Unread notifications: $error');
          return 0;
        }),
      ]);

      if (!mounted) return;
      setState(() {
        _students = (results[0] as PaginatedResult<Student>).data;
        _parents = (results[1] as PaginatedResult<Parent>).data;
        _teachers = (results[2] as PaginatedResult<Teacher>).data;
        _groups = results[3] as List<GroupEntity>;
        _leaveQueue = results[4] as List<_StaffQueueItem>;
        _invoiceQueue = results[5] as List<_StaffQueueItem>;
        _attendanceQueue = results[6] as List<_StaffQueueItem>;
        _enrollmentQueue = results[7] as List<_StaffQueueItem>;
        _operationsQueue = results[8] as List<_StaffQueueItem>;
        _notifications = results[9] as List<AppNotification>;
        _unreadCount = results[10] as int;
        _dataWarnings = warnings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<_StaffQueueItem>> _fetchLeaveQueue(List<String> warnings) async {
    return _safeQuery('Leave requests', warnings, () async {
      final rows = await Supabase.instance.client
          .from('leave_requests')
          .select(
            'id, reason, status, submitted_at, students(student_code, profiles(full_name)), class_sessions(session_date, groups(name, code))',
          )
          .eq('status', 'pending')
          .order('submitted_at')
          .limit(30);
      return (rows as List)
          .whereType<Map>()
          .map(
            (row) => _StaffQueueItem(
              type: _StaffQueueType.leave,
              id: row['id']?.toString() ?? '',
              title: _studentLabel(row['students']),
              subtitle:
                  '${row['reason'] ?? 'Leave request'} • ${_sessionLabel(row['class_sessions'])}',
              status: row['status']?.toString() ?? 'pending',
              createdAt: DateTime.tryParse(
                row['submitted_at']?.toString() ?? '',
              ),
            ),
          )
          .toList();
    });
  }

  Future<List<_StaffQueueItem>> _fetchInvoiceQueue(
    List<String> warnings,
  ) async {
    return _safeQuery('Payment follow-up', warnings, () async {
      final rows = await Supabase.instance.client
          .from('invoices')
          .select(
            'id, invoice_number, status, total_minor, amount_paid_minor, currency, due_at, students(student_code, profiles(full_name))',
          )
          .inFilter('status', ['issued', 'overdue', 'partially_paid'])
          .order('due_at')
          .limit(30);
      return (rows as List).whereType<Map>().map((row) {
        final total = row['total_minor'] as int? ?? 0;
        final paid = row['amount_paid_minor'] as int? ?? 0;
        final currency = row['currency']?.toString() ?? 'EGP';
        return _StaffQueueItem(
          type: _StaffQueueType.invoice,
          id: row['id']?.toString() ?? '',
          title: row['invoice_number']?.toString().isNotEmpty == true
              ? row['invoice_number'].toString()
              : _studentLabel(row['students']),
          subtitle:
              '${_studentLabel(row['students'])} • ${_money(total - paid, currency)} remaining',
          status: row['status']?.toString() ?? 'issued',
          createdAt: DateTime.tryParse(row['due_at']?.toString() ?? ''),
          amountMinor: total - paid,
          currency: currency,
        );
      }).toList();
    });
  }

  Future<List<_StaffQueueItem>> _fetchAttendanceQueue(
    List<String> warnings,
  ) async {
    return _safeQuery('Attendance exceptions', warnings, () async {
      final rows = await Supabase.instance.client
          .from('attendance_records')
          .select(
            'id, attendance_status, marked_at, students(student_code, profiles(full_name)), class_sessions(session_date, groups(name, code))',
          )
          .inFilter('attendance_status', ['absent', 'late'])
          .order('marked_at', ascending: false)
          .limit(30);
      return (rows as List)
          .whereType<Map>()
          .map(
            (row) => _StaffQueueItem(
              type: _StaffQueueType.attendance,
              id: row['id']?.toString() ?? '',
              title: _studentLabel(row['students']),
              subtitle: _sessionLabel(row['class_sessions']),
              status: row['attendance_status']?.toString() ?? 'unknown',
              createdAt: DateTime.tryParse(row['marked_at']?.toString() ?? ''),
            ),
          )
          .toList();
    });
  }

  Future<List<_StaffQueueItem>> _fetchEnrollmentQueue(
    List<String> warnings,
  ) async {
    return _safeQuery('Recent enrollments', warnings, () async {
      final rows = await Supabase.instance.client
          .from('enrollments')
          .select(
            'id, status, start_date, students(student_code, profiles(full_name)), groups(name, code)',
          )
          .order('start_date', ascending: false)
          .limit(30);
      return (rows as List)
          .whereType<Map>()
          .map(
            (row) => _StaffQueueItem(
              type: _StaffQueueType.enrollment,
              id: row['id']?.toString() ?? '',
              title: _studentLabel(row['students']),
              subtitle: _groupLabel(row['groups']),
              status: row['status']?.toString() ?? 'active',
              createdAt: DateTime.tryParse(row['start_date']?.toString() ?? ''),
            ),
          )
          .toList();
    });
  }

  Future<List<_StaffQueueItem>> _fetchOperationsQueue(
    List<String> warnings,
  ) async {
    return _safeQuery('Unified operations queue', warnings, () async {
      final rows = await Supabase.instance.client.rpc(
        'get_staff_operations_queue',
        params: {'p_limit': 80},
      );
      return (rows as List)
          .whereType<Map>()
          .map((row) => _StaffQueueItem.fromQueueJson(row))
          .toList();
    });
  }

  Future<List<_StaffQueueItem>> _safeQuery(
    String label,
    List<String> warnings,
    Future<List<_StaffQueueItem>> Function() query,
  ) async {
    try {
      return await query();
    } catch (e) {
      warnings.add('$label: $e');
      return [];
    }
  }

  Future<PaginatedResult<T>> _safePageQuery<T>(
    String label,
    List<String> warnings,
    Future<PaginatedResult<T>> Function() query,
    PaginatedResult<T> fallback,
  ) async {
    try {
      return await query();
    } catch (e) {
      warnings.add('$label: $e');
      return fallback;
    }
  }

  Future<void> _reviewLeaveQueueItem(_StaffQueueItem item, String decision) {
    final noteController = TextEditingController();
    return _runQueueDialog(
      title: decision == 'approved'
          ? 'Approve leave request'
          : 'Reject leave request',
      content: TextField(
        controller: noteController,
        decoration: InputDecoration(
          labelText: context.tr('Reviewer note'),
          prefixIcon: const Icon(Icons.notes),
        ),
        minLines: 2,
        maxLines: 4,
      ),
      confirmLabel: decision == 'approved' ? 'Approve' : 'Reject',
      confirmIcon: decision == 'approved' ? Icons.check : Icons.close,
      action: () => Supabase.instance.client.rpc(
        'review_leave_request',
        params: {
          'p_request_id': item.id,
          'p_decision': decision,
          'p_reviewer_note': noteController.text.trim(),
        },
      ),
      successMessage: decision == 'approved'
          ? 'Leave request approved.'
          : 'Leave request rejected.',
      onDispose: noteController.dispose,
    );
  }

  Future<void> _recordCashPayment(_StaffQueueItem item) {
    final amountController = TextEditingController(
      text: (item.amountMinor / 100).toStringAsFixed(
        item.amountMinor % 100 == 0 ? 0 : 2,
      ),
    );
    final noteController = TextEditingController(text: 'Recorded by staff');
    return _runQueueDialog(
      title: 'Record cash payment',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amountController,
            decoration: InputDecoration(
              labelText: 'Amount (${item.currency})',
              prefixIcon: const Icon(Icons.payments),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            decoration: InputDecoration(
              labelText: context.tr('Notes'),
              prefixIcon: const Icon(Icons.notes),
            ),
          ),
        ],
      ),
      confirmLabel: 'Record',
      confirmIcon: Icons.payments,
      action: () {
        final amount = double.tryParse(amountController.text.trim()) ?? 0;
        final amountMinor = (amount * 100).round();
        if (amountMinor <= 0) {
          throw Exception('Payment amount must be greater than zero.');
        }
        return Supabase.instance.client.rpc(
          'record_manual_payment',
          params: {
            'p_invoice_id': item.id,
            'p_amount_minor': amountMinor,
            'p_payment_method': 'cash',
            'p_notes': noteController.text.trim(),
          },
        );
      },
      successMessage: 'Cash payment recorded.',
      onDispose: () {
        amountController.dispose();
        noteController.dispose();
      },
    );
  }

  Future<void> _resolveAttendanceException(
    _StaffQueueItem item,
    String status,
  ) {
    final noteController = TextEditingController(
      text: status == 'excused'
          ? 'Resolved by staff as excused'
          : 'Resolved by staff',
    );
    return _runQueueDialog(
      title: status == 'excused'
          ? 'Mark attendance excused'
          : 'Mark attendance present',
      content: TextField(
        controller: noteController,
        decoration: InputDecoration(
          labelText: context.tr('Resolution note'),
          prefixIcon: const Icon(Icons.notes),
        ),
        minLines: 2,
        maxLines: 4,
      ),
      confirmLabel: status == 'excused' ? 'Mark Excused' : 'Mark Present',
      confirmIcon: status == 'excused' ? Icons.event_available : Icons.check,
      action: () => Supabase.instance.client.rpc(
        'staff_update_attendance_exception',
        params: {
          'p_attendance_record_id': item.id,
          'p_attendance_status': status,
          'p_notes': noteController.text.trim(),
        },
      ),
      successMessage: 'Attendance exception resolved.',
      onDispose: noteController.dispose,
    );
  }

  Future<void> _decideAdjustment(_StaffQueueItem item, bool approve) {
    return _runQueueDialog(
      title: approve ? 'Approve adjustment' : 'Reject adjustment',
      content: Text(
        approve
            ? 'This will apply the requested discount or exemption.'
            : 'This will reject the requested discount or exemption.',
      ),
      confirmLabel: approve ? 'Approve' : 'Reject',
      confirmIcon: approve ? Icons.check : Icons.close,
      action: () => Supabase.instance.client.rpc(
        'apply_payment_adjustment_request',
        params: {
          'p_request_id': item.id,
          'p_approve': approve,
          'p_decision_note': approve
              ? 'Approved by staff operations.'
              : 'Rejected by staff operations.',
        },
      ),
      successMessage: approve ? 'Adjustment applied.' : 'Adjustment rejected.',
    );
  }

  Future<void> _runQueueDialog({
    required String title,
    required Widget content,
    required String confirmLabel,
    required IconData confirmIcon,
    required Future<dynamic> Function() action,
    required String successMessage,
    VoidCallback? onDispose,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: Icon(confirmIcon),
            label: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      onDispose?.call();
      return;
    }

    try {
      await action();
      await _loadStaffData();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Operation failed: $e')));
    } finally {
      onDispose?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authViewModel.currentUser;
    return PortalScaffold(
      title: user?.fullName ?? 'Staff Member',
      subtitle: 'Operations workspace',
      icon: Icons.badge,
      accentColor: AppColors.primary,
      selectedIndex: _selectedIndex,
      destinations: _destinations,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      onRefresh: _loadStaffData,
      onSignOut: widget.authViewModel.signOut,
      body: _selectedIndex <= 5
          ? _dashboardBody(user?.fullName)
          : _selectedPage(),
    );
  }

  Widget _dashboardBody(String? userName) {
    return RefreshIndicator(
      onRefresh: _loadStaffData,
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: false,
        emptyTitle: 'No operations data',
        emptySubtitle: 'Refresh after staff permissions are assigned.',
        emptyIcon: Icons.badge,
        onRetry: _loadStaffData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PortalHeader(
              eyebrow: 'Operations Portal',
              title: userName ?? 'Staff Member',
              subtitle: 'Students, groups, attendance, leave, and payments',
              icon: Icons.badge,
              accentColor: AppColors.primary,
              trailing: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CenterSwitcherWidget(
                    onCenterChanged: _loadStaffData,
                  ),
                  IconButton.filledTonal(
                    tooltip: 'بوابة الاستقبال والباركود',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReceptionQrGateScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'تصفية أرباح المدرسين',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TeacherSettlementScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calculate_rounded),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'كشوفات الحضور للطباعة (PDF)',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AttendanceReportsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.print_rounded),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'جرد وتقفيل الخزينة والوردية (Shift Closing)',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DailyCashRegisterScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.point_of_sale_rounded),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'بيع الملازم والمخزن (POS)',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BookstorePosScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.shopping_bag_rounded),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'سعة القاعات والمقاعد',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ClassroomCapacityScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.meeting_room_rounded),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'شاشة العرض التلفزيونية للاستقبال (TV)',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReceptionLiveTvKioskScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.tv_rounded),
                  ),
                ],
              ),
            ),
            if (_dataWarnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              _WarningsCard(warnings: _dataWarnings),
            ],
            const SizedBox(height: 16),
            _selectedPage(),
          ],
        ),
      ),
    );
  }

  Widget _selectedPage() {
    return switch (_selectedIndex) {
      0 => _overviewPage(),
      1 => _queuesPage(),
      2 => _studentsPage(),
      3 => _parentsPage(),
      4 => _teachersPage(),
      5 => _groupsPage(),
      6 => const AttendanceOperationsScreen(),
      7 => const FinanceManagementScreen(),
      8 => const HelpdeskManagementScreen(),
      9 => NotificationCenterScreen(
        viewModel: _notificationCenterViewModel,
        onNotificationTap: _openNotification,
      ),
      10 => const ReportsDashboardScreen(),
      11 => const AppSettingsPanel(),
      _ => _overviewPage(),
    };
  }

  void _openNotification(AppNotification notification) {
    final type = notification.type.toLowerCase();
    final nextIndex = switch (type) {
      'payment' || 'invoice' || 'receipt' || 'finance' => 7,
      'attendance' || 'leave' || 'session' => 6,
      'support' || 'ticket' || 'helpdesk' => 8,
      'report' || 'analytics' => 10,
      _ => 0,
    };
    setState(() => _selectedIndex = nextIndex);
  }

  Widget _overviewPage() {
    final openTasks = _operationsQueue.isNotEmpty
        ? _operationsQueue.length
        : _leaveQueue.length + _invoiceQueue.length + _attendanceQueue.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Staff Front Desk & Instant Student Lookup HUD
        _StaffFrontDeskHud(
          students: _students,
          onOpenQrGate: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReceptionQrGateScreen(),
              ),
            );
          },
          onOpenTvKiosk: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReceptionLiveTvKioskScreen(),
              ),
            );
          },
          onOpenBookstorePos: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BookstorePosScreen(),
              ),
            );
          },
          onOpenCashRegister: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const DailyCashRegisterScreen(),
              ),
            );
          },
          onOpenAttendanceReports: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AttendanceReportsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        const PortalSectionTitle(
          title: 'العمليات السريعة للاستقبال',
          subtitle: 'مسح الباركود، تحصيل فوري، وتصفية مستحقات المدرسين',
        ),
        const SizedBox(height: 12),
        PortalMetricGrid(
          children: [
            PortalMetricCard(
              label: 'بوابة الاستقبال (QR)',
              value: 'مسح فوري',
              icon: Icons.qr_code_scanner_rounded,
              accentColor: AppColors.primary,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ReceptionQrGateScreen(),
                  ),
                );
              },
            ),
            PortalMetricCard(
              label: 'تصفية أرباح المدرسين',
              value: 'حساب النسب',
              icon: Icons.calculate_rounded,
              accentColor: AppColors.teacherRole,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TeacherSettlementScreen(),
                  ),
                );
              },
            ),
            PortalMetricCard(
              label: 'كشوفات الحضور (PDF)',
              value: 'تصدير وطباعة',
              icon: Icons.print_rounded,
              accentColor: AppColors.staffRole,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AttendanceReportsScreen(),
                  ),
                );
              },
            ),
            PortalMetricCard(
              label: 'تقفيل الخزينة اليومية',
              value: 'جرد الوردية',
              icon: Icons.point_of_sale_rounded,
              accentColor: AppColors.success,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DailyCashRegisterScreen(),
                  ),
                );
              },
            ),
            PortalMetricCard(
              label: 'انضمام لسنتر بكود',
              value: 'ربط الفروع',
              icon: Icons.add_business_rounded,
              accentColor: AppColors.warning,
              onTap: () {
                JoinCenterDialog.show(context, onJoined: _loadStaffData);
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        const PortalSectionTitle(
          title: 'ملخص العمليات والمهام',
          subtitle: 'متابعة الطلبات المعلقة والطلاب والمجموعات',
        ),
        const SizedBox(height: 12),
        PortalMetricGrid(
          children: [
            PortalMetricCard(
              label: 'Open tasks',
              value: openTasks.toString(),
              icon: Icons.assignment_late,
              accentColor: AppColors.warning,
              onTap: () => setState(() => _selectedIndex = 1),
            ),
            PortalMetricCard(
              label: 'Students visible',
              value: _has(Permission.studentsView)
                  ? _students.length.toString()
                  : 'No access',
              icon: Icons.school,
              accentColor: AppColors.info,
              onTap: _has(Permission.studentsView)
                  ? () => setState(() => _selectedIndex = 2)
                  : null,
            ),
            PortalMetricCard(
              label: 'Groups visible',
              value: _has(Permission.groupsView)
                  ? _groups.length.toString()
                  : 'No access',
              icon: Icons.group_work,
              accentColor: AppColors.primary,
              onTap: _has(Permission.groupsView)
                  ? () => setState(() => _selectedIndex = 5)
                  : null,
            ),
            PortalMetricCard(
              label: 'Parents visible',
              value: _parents.length.toString(),
              icon: Icons.family_restroom,
              accentColor: AppColors.secondary,
              onTap: () => setState(() => _selectedIndex = 3),
            ),
            PortalMetricCard(
              label: 'Teachers visible',
              value: _teachers.length.toString(),
              icon: Icons.co_present,
              accentColor: AppColors.success,
              onTap: () => setState(() => _selectedIndex = 4),
            ),
            PortalMetricCard(
              label: 'Recent enrollments',
              value: _enrollmentQueue.length.toString(),
              icon: Icons.person_add,
              accentColor: AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(
          title: 'Priority queue',
          subtitle: 'Pending items that usually need staff follow-up.',
        ),
        const SizedBox(height: 8),
        _QueueList(
          emptyText: 'No priority items right now.',
          items: _operationsQueue.isNotEmpty
              ? _operationsQueue.take(12).toList()
              : [
                  ..._leaveQueue.take(5),
                  ..._invoiceQueue.take(5),
                  ..._attendanceQueue.take(5),
                ],
          onApproveLeave: (item) => _reviewLeaveQueueItem(item, 'approved'),
          onRejectLeave: (item) => _reviewLeaveQueueItem(item, 'rejected'),
          onRecordPayment: _recordCashPayment,
          onMarkExcused: (item) => _resolveAttendanceException(item, 'excused'),
          onMarkPresent: (item) => _resolveAttendanceException(item, 'present'),
          onApproveAdjustment: (item) => _decideAdjustment(item, true),
          onRejectAdjustment: (item) => _decideAdjustment(item, false),
        ),
      ],
    );
  }

  Widget _queuesPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PortalSectionTitle(title: 'Leave requests'),
        const SizedBox(height: 8),
        _QueueList(
          emptyText: 'No pending leave requests.',
          items: _leaveQueue,
          onApproveLeave: (item) => _reviewLeaveQueueItem(item, 'approved'),
          onRejectLeave: (item) => _reviewLeaveQueueItem(item, 'rejected'),
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'Payment follow-up'),
        const SizedBox(height: 8),
        _QueueList(
          emptyText: 'No invoices need follow-up.',
          items: _invoiceQueue,
          onRecordPayment: _recordCashPayment,
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'Attendance exceptions'),
        const SizedBox(height: 8),
        _QueueList(
          emptyText: 'No recent absent or late records.',
          items: _attendanceQueue,
          onMarkExcused: (item) => _resolveAttendanceException(item, 'excused'),
          onMarkPresent: (item) => _resolveAttendanceException(item, 'present'),
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'Recent enrollments'),
        const SizedBox(height: 8),
        _QueueList(
          emptyText: 'No recent enrollments visible.',
          items: _enrollmentQueue,
        ),
        const SizedBox(height: 18),
        const PortalSectionTitle(title: 'Unified operations queue'),
        const SizedBox(height: 8),
        _QueueList(
          emptyText:
              'Run the latest operations migration to enable this queue.',
          items: _operationsQueue,
          onApproveLeave: (item) => _reviewLeaveQueueItem(item, 'approved'),
          onRejectLeave: (item) => _reviewLeaveQueueItem(item, 'rejected'),
          onRecordPayment: _recordCashPayment,
          onMarkExcused: (item) => _resolveAttendanceException(item, 'excused'),
          onMarkPresent: (item) => _resolveAttendanceException(item, 'present'),
          onApproveAdjustment: (item) => _decideAdjustment(item, true),
          onRejectAdjustment: (item) => _decideAdjustment(item, false),
        ),
      ],
    );
  }

  Widget _studentsPage() {
    if (!_has(Permission.studentsView)) {
      return const _AccessCard(
        message: 'students.view permission is required.',
      );
    }
    final filteredStudents = _filteredStudents();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalSectionTitle(
          title: 'Students Directory',
          subtitle: '${filteredStudents.length}/${_students.length}',
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 520,
          child: StudentListWidget(
            students: filteredStudents,
            isLoading: _isLoading,
            onRefresh: _loadStaffData,
            onSearchChanged: (value) =>
                setState(() => _studentSearch = value.trim().toLowerCase()),
            onStudentSelected: _showStudentDetails,
          ),
        ),
      ],
    );
  }

  Widget _parentsPage() {
    if (!_has(Permission.parentsView)) {
      return const _AccessCard(
        message: 'parents.view permission is required.',
      );
    }
    final filteredParents = _filteredParents();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalSectionTitle(
          title: 'Parents Directory',
          subtitle: '${filteredParents.length}/${_parents.length}',
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 520,
          child: ParentListWidget(
            parents: filteredParents,
            isLoading: _isLoading,
            onSearchChanged: (value) =>
                setState(() => _parentSearch = value.trim().toLowerCase()),
          ),
        ),
      ],
    );
  }

  Widget _teachersPage() {
    final filteredTeachers = _filteredTeachers();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalSectionTitle(
          title: 'Teachers Directory',
          subtitle: '${filteredTeachers.length}/${_teachers.length}',
        ),
        const SizedBox(height: 8),
        PortalSearchField(
          controller: _teacherSearchController,
          label: 'Search teachers',
          onChanged: (value) =>
              setState(() => _teacherSearch = value.trim().toLowerCase()),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 520,
          child: TeacherListWidget(
            teachers: filteredTeachers,
            isLoading: _isLoading,
          ),
        ),
      ],
    );
  }

  Widget _groupsPage() {
    if (!_has(Permission.groupsView)) {
      return const _AccessCard(message: 'groups.view permission is required.');
    }
    final filteredGroups = _filteredGroups();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalSectionTitle(
          title: 'Groups Roster',
          subtitle: '${filteredGroups.length}/${_groups.length}',
        ),
        const SizedBox(height: 8),
        PortalSearchField(
          controller: _groupSearchController,
          label: 'Search groups',
          onChanged: (value) =>
              setState(() => _groupSearch = value.trim().toLowerCase()),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 520,
          child: GroupListWidget(
            groups: filteredGroups,
            isLoading: _isLoading,
            onGroupSelected: _showGroupDetails,
          ),
        ),
      ],
    );
  }

  List<Student> _filteredStudents() {
    final q = _studentSearch;
    if (q.isEmpty) return _students;
    return _students.where((student) {
      return student.fullName.toLowerCase().contains(q) ||
          student.studentCode.toLowerCase().contains(q) ||
          student.email.toLowerCase().contains(q) ||
          (student.phoneNumber ?? '').toLowerCase().contains(q) ||
          (student.gradeLevel ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<GroupEntity> _filteredGroups() {
    final q = _groupSearch;
    if (q.isEmpty) return _groups;
    return _groups.where((group) {
      return group.name.toLowerCase().contains(q) ||
          group.code.toLowerCase().contains(q) ||
          group.status.toLowerCase().contains(q);
    }).toList();
  }

  List<Parent> _filteredParents() {
    final q = _parentSearch;
    if (q.isEmpty) return _parents;
    return _parents.where((parent) {
      return parent.fullName.toLowerCase().contains(q) ||
          parent.email.toLowerCase().contains(q) ||
          (parent.phoneNumber ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<Teacher> _filteredTeachers() {
    final q = _teacherSearch;
    if (q.isEmpty) return _teachers;
    return _teachers.where((teacher) {
      return teacher.fullName.toLowerCase().contains(q) ||
          teacher.email.toLowerCase().contains(q) ||
          (teacher.specialization ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _showStudentDetails(Student student) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          student.fullName.isNotEmpty ? student.fullName : student.studentCode,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailLine('Student Code', student.studentCode),
              _detailLine('Email', student.email),
              _detailLine('Phone', student.phoneNumber ?? 'N/A'),
              _detailLine('Grade', student.gradeLevel ?? 'N/A'),
              _detailLine('School', student.schoolName ?? 'N/A'),
              _detailLine('Status', student.status),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Close')),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedIndex = 5);
            },
            icon: const Icon(Icons.receipt_long),
            label: Text(context.tr('Finance')),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedIndex = 4);
            },
            icon: const Icon(Icons.fact_check),
            label: Text(context.tr('Attendance')),
          ),
        ],
      ),
    );
  }

  void _showGroupDetails(GroupEntity group) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${group.name} (${group.code})'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailLine('Status', group.status),
              _detailLine(
                'Max Capacity',
                group.maxCapacity?.toString() ?? 'Unlimited',
              ),
              _detailLine('Subject', group.subjectId),
              _detailLine('Branch', group.branchId),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Close')),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedIndex = 4);
            },
            icon: const Icon(Icons.fact_check),
            label: Text(context.tr('Attendance')),
          ),
        ],
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              context.tr(label),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(context.tr(value))),
        ],
      ),
    );
  }

  static String _studentLabel(Object? value) {
    final row = _asMap(value);
    final profile = _asMap(row['profiles']);
    final name = profile['full_name']?.toString();
    final code = row['student_code']?.toString();
    if (name != null && name.isNotEmpty && code != null && code.isNotEmpty) {
      return '$name ($code)';
    }
    return name?.isNotEmpty == true ? name! : code ?? 'Student';
  }

  static String _sessionLabel(Object? value) {
    final row = _asMap(value);
    final date = row['session_date']?.toString() ?? 'No date';
    final group = _groupLabel(row['groups']);
    return '$group • $date';
  }

  static String _groupLabel(Object? value) {
    final row = _asMap(value);
    final name = row['name']?.toString();
    final code = row['code']?.toString();
    if (name != null && name.isNotEmpty && code != null && code.isNotEmpty) {
      return '$name ($code)';
    }
    return name?.isNotEmpty == true ? name! : code ?? 'Group';
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static String _money(int minor, String currency) {
    final amount = minor / 100;
    return '${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)} $currency';
  }
}

class _QueueList extends StatelessWidget {
  final String emptyText;
  final List<_StaffQueueItem> items;
  final ValueChanged<_StaffQueueItem>? onApproveLeave;
  final ValueChanged<_StaffQueueItem>? onRejectLeave;
  final ValueChanged<_StaffQueueItem>? onRecordPayment;
  final ValueChanged<_StaffQueueItem>? onMarkExcused;
  final ValueChanged<_StaffQueueItem>? onMarkPresent;
  final ValueChanged<_StaffQueueItem>? onApproveAdjustment;
  final ValueChanged<_StaffQueueItem>? onRejectAdjustment;

  const _QueueList({
    required this.emptyText,
    required this.items,
    this.onApproveLeave,
    this.onRejectLeave,
    this.onRecordPayment,
    this.onMarkExcused,
    this.onMarkPresent,
    this.onApproveAdjustment,
    this.onRejectAdjustment,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.inbox_outlined),
              const SizedBox(width: 10),
              Expanded(child: Text(context.l10n.t(emptyText))),
            ],
          ),
        ),
      );
    }

    return Column(
      children: items
          .map(
            (item) => PortalListCard(
              icon: item.icon,
              accentColor: item.color,
              title: item.title,
              subtitle: '${item.subtitle} • ${item.dateLabel}',
              trailing: [
                PortalStatusChip(status: item.status),
                ..._actionsFor(item),
              ],
            ),
          )
          .toList(),
    );
  }

  List<Widget> _actionsFor(_StaffQueueItem item) {
    return switch (item.type) {
      _StaffQueueType.leave => [
        IconButton(
          tooltip: 'Approve leave',
          onPressed: onApproveLeave == null
              ? null
              : () => onApproveLeave!(item),
          icon: const Icon(Icons.check),
        ),
        IconButton(
          tooltip: 'Reject leave',
          onPressed: onRejectLeave == null ? null : () => onRejectLeave!(item),
          icon: const Icon(Icons.close),
        ),
      ],
      _StaffQueueType.invoice => [
        IconButton(
          tooltip: 'Record cash payment',
          onPressed: onRecordPayment == null
              ? null
              : () => onRecordPayment!(item),
          icon: const Icon(Icons.payments),
        ),
      ],
      _StaffQueueType.attendance => [
        IconButton(
          tooltip: 'Mark excused',
          onPressed: onMarkExcused == null ? null : () => onMarkExcused!(item),
          icon: const Icon(Icons.event_available),
        ),
        IconButton(
          tooltip: 'Mark present',
          onPressed: onMarkPresent == null ? null : () => onMarkPresent!(item),
          icon: const Icon(Icons.check_circle),
        ),
      ],
      _StaffQueueType.adjustment => [
        IconButton(
          tooltip: 'Approve adjustment',
          onPressed: onApproveAdjustment == null
              ? null
              : () => onApproveAdjustment!(item),
          icon: const Icon(Icons.check),
        ),
        IconButton(
          tooltip: 'Reject adjustment',
          onPressed: onRejectAdjustment == null
              ? null
              : () => onRejectAdjustment!(item),
          icon: const Icon(Icons.close),
        ),
      ],
      _StaffQueueType.enrollment => const [],
    };
  }
}

class _AccessCard extends StatelessWidget {
  final String message;

  const _AccessCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.lock_outline),
            const SizedBox(width: 10),
            Expanded(child: Text(context.l10n.t(message))),
          ],
        ),
      ),
    );
  }
}

class _WarningsCard extends StatelessWidget {
  final List<String> warnings;

  const _WarningsCard({required this.warnings});

  @override
  Widget build(BuildContext context) {
    final visible = warnings.take(4).toList();
    return Card(
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Some operations could not be loaded.'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  ...visible.map(
                    (warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        warning,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  if (warnings.length > visible.length)
                    Text(
                      context.tr('More issues are available in logs.'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StaffQueueType { leave, invoice, attendance, enrollment, adjustment }

class _StaffQueueItem {
  final _StaffQueueType type;
  final String id;
  final String title;
  final String subtitle;
  final String status;
  final DateTime? createdAt;
  final int amountMinor;
  final String currency;

  const _StaffQueueItem({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.createdAt,
    this.amountMinor = 0,
    this.currency = 'EGP',
  });

  factory _StaffQueueItem.fromQueueJson(Map raw) {
    final row = Map<String, dynamic>.from(raw);
    final type = switch (row['item_type']?.toString()) {
      'leave' => _StaffQueueType.leave,
      'invoice' => _StaffQueueType.invoice,
      'attendance' => _StaffQueueType.attendance,
      'adjustment' => _StaffQueueType.adjustment,
      _ => _StaffQueueType.enrollment,
    };
    return _StaffQueueItem(
      type: type,
      id: row['item_id']?.toString() ?? '',
      title: row['title']?.toString() ?? 'Operation',
      subtitle: row['subtitle']?.toString() ?? '',
      status: row['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      amountMinor: _asInt(row['amount_minor']),
      currency: row['currency']?.toString() ?? 'EGP',
    );
  }

  IconData get icon {
    return switch (status.toLowerCase()) {
      'pending' => Icons.pending_actions,
      'issued' || 'overdue' || 'partially_paid' => Icons.receipt_long,
      'absent' => Icons.cancel,
      'late' => Icons.schedule,
      'active' => Icons.person_add,
      'applied' => Icons.verified,
      _ => Icons.assignment,
    };
  }

  Color get color {
    return switch (status.toLowerCase()) {
      'overdue' || 'absent' => AppColors.error,
      'pending' || 'issued' || 'partially_paid' || 'late' => AppColors.warning,
      'active' => AppColors.success,
      _ => AppColors.info,
    };
  }

  String get dateLabel {
    final value = createdAt;
    if (value == null) return 'No date';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class _StaffFrontDeskHud extends StatefulWidget {
  final List<Student> students;
  final VoidCallback onOpenQrGate;
  final VoidCallback onOpenTvKiosk;
  final VoidCallback onOpenBookstorePos;
  final VoidCallback onOpenCashRegister;
  final VoidCallback onOpenAttendanceReports;

  const _StaffFrontDeskHud({
    required this.students,
    required this.onOpenQrGate,
    required this.onOpenTvKiosk,
    required this.onOpenBookstorePos,
    required this.onOpenCashRegister,
    required this.onOpenAttendanceReports,
  });

  @override
  State<_StaffFrontDeskHud> createState() => _StaffFrontDeskHudState();
}

class _StaffFrontDeskHudState extends State<_StaffFrontDeskHud>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final TextEditingController _searchCtrl = TextEditingController();
  Student? _matchedStudent;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      setState(() => _matchedStudent = null);
      return;
    }

    final match = widget.students.cast<Student?>().firstWhere(
      (s) {
        if (s == null) return false;
        final name = s.fullName.toLowerCase();
        final code = s.studentCode.toLowerCase();
        final phone = (s.phoneNumber ?? '').toLowerCase();
        return name.contains(clean) || code.contains(clean) || phone.contains(clean);
      },
      orElse: () => null,
    );

    setState(() => _matchedStudent = match);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
        ),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              _StaffPulseBeacon(controller: _pulseController),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'مكتب الاستقبال وشؤون الطلاب (Front Desk HUD) 🪪',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'شفت الاستقبال نشط 🟢',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'استعلام فوري عن الطلاب • تحصيل اشتراكات • بيع ملازم • بوابات الحضور',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: widget.onOpenTvKiosk,
                icon: const Icon(Icons.tv_rounded, size: 16),
                label: const Text('شاشة السنتر (TV)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Instant Student Lookup Input
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: 'ابحث بكود الطالب (STU-101) أو الاسم أو رقم هاتف ولي الأمر...',
              prefixIcon: const Icon(Icons.person_search_rounded, color: Color(0xFFD97706)),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
          ),

          // Student Instant Result Card
          if (_matchedStudent != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _matchedStudent!.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                'كود: ${_matchedStudent!.studentCode} • ${_matchedStudent!.gradeLevel ?? "المرحلة التعليمية"}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'مسدد الاشتراك ✔️',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.how_to_reg_rounded, size: 16, color: Colors.green),
                          label: const Text('تسجيل حضور يدوي', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم تسجيل حضور الطالب ${_matchedStudent!.fullName} بنجاح! ⏱️'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.point_of_sale_rounded, size: 16, color: AppColors.primary),
                          label: const Text('تحصيل رسوم 💵', style: TextStyle(fontSize: 11)),
                          onPressed: widget.onOpenCashRegister,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'مراسلة ولي الأمر واتساب',
                        icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                        onPressed: () async {
                          final phone = _matchedStudent!.phoneNumber;
                          if (phone != null && phone.isNotEmpty) {
                            final text = 'أهلاً بحضرتك، بخصوص الطالب ${_matchedStudent!.fullName} (كود ${_matchedStudent!.studentCode}) من سنتر الأوائل.';
                            final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Reception Quick Tools Dock
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStaffDockPill(
                label: 'بوابة الاستقبال QR 🪪',
                color: AppColors.primary,
                icon: Icons.qr_code_scanner_rounded,
                onTap: widget.onOpenQrGate,
              ),
              _buildStaffDockPill(
                label: 'منفذ بيع الملازم والكتب 📚',
                color: Colors.purple.shade700,
                icon: Icons.menu_book_rounded,
                onTap: widget.onOpenBookstorePos,
              ),
              _buildStaffDockPill(
                label: 'تقفيل الخزينة اليومية 💵',
                color: Colors.green.shade700,
                icon: Icons.point_of_sale_rounded,
                onTap: widget.onOpenCashRegister,
              ),
              _buildStaffDockPill(
                label: 'كشوفات الحضور PDF 🖨️',
                color: Colors.blueGrey,
                icon: Icons.print_rounded,
                onTap: widget.onOpenAttendanceReports,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaffDockPill({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffPulseBeacon extends StatelessWidget {
  final AnimationController controller;

  const _StaffPulseBeacon({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1.0 + (controller.value * 0.25);
        final opacity = 0.8 - (controller.value * 0.4);
        return SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF59E0B).withValues(alpha: opacity),
                  ),
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF59E0B),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFF59E0B),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

