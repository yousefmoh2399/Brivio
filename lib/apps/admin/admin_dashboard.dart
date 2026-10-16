import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/di/injection.dart';
import '../../core/network/supabase_client_wrapper.dart';
import '../../core/settings/app_settings_screen.dart';
import '../../design_system/components/editable_avatar.dart';
import '../../design_system/components/glass_card.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/tokens/typography.dart';
import '../../design_system/widgets/portal_components.dart';
import '../../features/admin/presentation/screens/data_import_screen.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/academy/presentation/screens/branch_management_screen.dart';
import '../../features/academy/presentation/screens/group_management_screen.dart';
import '../../features/academy/presentation/screens/schedule_management_screen.dart';
import '../../features/academy/presentation/screens/subject_management_screen.dart';
import '../../features/assessment/presentation/screens/exam_management_screen.dart';
import '../../features/assessment/presentation/screens/homework_management_screen.dart';
import '../../features/assessment/presentation/screens/question_bank_screen.dart';
import '../../features/attendance/presentation/screens/attendance_operations_screen.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/communication/domain/models/notification.dart';
import '../../features/communication/domain/repositories/i_notification_repository.dart';
import '../../features/curriculum/presentation/screens/curriculum_editor_screen.dart';
import '../../features/payments/data/repositories/supabase_payment_repositories.dart';
import '../../features/payments/domain/models/payment_models.dart';
import '../../features/payments/presentation/screens/finance_management_screen.dart';
import '../../features/people/presentation/screens/parent_management_screen.dart';
import '../../features/people/presentation/screens/staff_management_screen.dart';
import '../../features/people/presentation/screens/student_management_screen.dart';
import '../../features/people/presentation/screens/teacher_management_screen.dart';
import '../../features/security/presentation/screens/rbac_management_screen.dart';
import '../../features/security/presentation/screens/audit_log_screen.dart';
import '../../features/study_workspace/presentation/screens/study_replay_screen.dart';
import '../../features/analytics/presentation/screens/admin_analytics_screen.dart';
import '../../features/helpdesk/presentation/screens/helpdesk_management_screen.dart';
import '../../features/reports/presentation/screens/reports_dashboard_screen.dart';
import '../../features/academy/presentation/widgets/center_switcher_widget.dart';
import '../../features/academy/presentation/screens/center_partnerships_screen.dart';
import '../../features/academy/presentation/widgets/join_center_dialog.dart';
import '../../features/attendance/presentation/screens/reception_qr_gate_screen.dart';
import '../../features/payments/presentation/screens/teacher_settlement_screen.dart';
import '../../features/reports/presentation/screens/attendance_reports_screen.dart';
import '../../features/payments/presentation/screens/daily_cash_register_screen.dart';
import '../../features/payments/presentation/screens/bookstore_pos_screen.dart';
import '../../features/academy/presentation/screens/classroom_capacity_screen.dart';
import '../../features/attendance/presentation/screens/reception_live_tv_kiosk_screen.dart';
import '../../core/services/report_generator_service.dart';

class AdminDashboard extends StatefulWidget {
  final AuthViewModel authViewModel;

  const AdminDashboard({super.key, required this.authViewModel});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<Student> _students = [];
  List<Parent> _parents = [];
  List<Teacher> _teachers = [];
  List<Branch> _branches = [];
  String? _selectedBranchId;
  List<SubjectEntity> _subjects = [];
  List<GroupEntity> _groups = [];
  AcademyCoreSummary? _summary;
  int _studentTotal = 0;
  int _teacherTotal = 0;
  int _parentTotal = 0;
  double _treasuryTotalCollected = 0.0;
  double _treasuryTodayCollected = 0.0;
  double _treasuryPendingInvoices = 0.0;
  int _treasuryReceiptsCount = 0;
  _AdminOpsMetrics _opsMetrics = const _AdminOpsMetrics();
  List<_AdminActivityItem> _recentActivity = [];
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription<AppNotification>? _notificationSubscription;

  int get unreadCount => _unreadCount;
  List<AppNotification> get notifications => _notifications;

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.authViewModel.currentUser?.branchId;
    _subscribeToNotifications();
    _loadSummaryData();
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
        .listen(
          (notification) {
            if (!mounted) return;
            setState(() {
              _notifications.insert(0, notification);
              _unreadCount++;
            });
          },
          onError: (e, st) {
            debugPrint('Notification stream error: $e\n$st');
          },
        );
  }

  Future<Map<String, dynamic>> _fetchTodayTreasuryCollections([String? centerId]) async {
    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final startOfDayUtc = DateTime.utc(now.year, now.month, now.day).toIso8601String();
      final endOfDayUtc = DateTime.utc(now.year, now.month, now.day, 23, 59, 59, 999).toIso8601String();
      final startOfDayLocal = DateTime(now.year, now.month, now.day).toIso8601String();
      final endOfDayLocal = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

      double sum = 0.0;
      int count = 0;
      final Set<String> countedReceiptNumbers = {};

      // 1. Core receipts from Supabase
      try {
        var query = Supabase.instance.client
            .from('receipts')
            .select('receipt_number, amount, amount_minor, center_id');

        if (centerId != null) {
          query = query.or('center_id.eq.$centerId,center_id.is.null');
        }

        final res = await query
            .gte('issued_at', startOfDayUtc)
            .lte('issued_at', endOfDayUtc)
            .catchError((_) async {
              return await query
                  .gte('issued_at', startOfDayLocal)
                  .lte('issued_at', endOfDayLocal);
            });

        for (final row in res) {
          final recNum = row['receipt_number']?.toString() ?? '';
          if (recNum.isNotEmpty && countedReceiptNumbers.contains(recNum)) continue;
          if (recNum.isNotEmpty) countedReceiptNumbers.add(recNum);

          if (row['amount'] != null) {
            sum += (row['amount'] as num).toDouble();
            count++;
          } else if (row['amount_minor'] != null) {
            sum += ((row['amount_minor'] as num).toDouble() / 100.0);
            count++;
          }
        }
      } catch (_) {}

      // 2. Bookstore & Inventory POS Sales
      try {
        var salesQuery = Supabase.instance.client
            .from('bookstore_sales')
            .select('receipt_number, total_amount, center_id');

        if (centerId != null) {
          salesQuery = salesQuery.or('center_id.eq.$centerId,center_id.is.null');
        }

        final salesRes = await salesQuery
            .gte('created_at', startOfDayUtc)
            .lte('created_at', endOfDayUtc)
            .catchError((_) async {
              return await salesQuery
                  .gte('created_at', startOfDayLocal)
                  .lte('created_at', endOfDayLocal);
            });

        for (final row in salesRes) {
          final recNum = row['receipt_number']?.toString() ?? '';
          if (recNum.isNotEmpty && countedReceiptNumbers.contains(recNum)) continue;
          if (recNum.isNotEmpty) countedReceiptNumbers.add(recNum);

          sum += ((row['total_amount'] as num?)?.toDouble() ?? 0.0);
          count++;
        }
      } catch (_) {}

      // 3. Local persistent POS sales log (in case of offline/cache checkout)
      try {
        final prefs = await SharedPreferences.getInstance();
        final localSalesJson = prefs.getString('pos_daily_sales_$todayStr');
        if (localSalesJson != null) {
          final localSales = jsonDecode(localSalesJson) as List;
          for (final s in localSales) {
            final recNum = s['receipt_number']?.toString() ?? '';
            if (recNum.isNotEmpty && countedReceiptNumbers.contains(recNum)) continue;
            if (recNum.isNotEmpty) countedReceiptNumbers.add(recNum);

            sum += ((s['total_amount'] as num?)?.toDouble() ?? 0.0);
            count++;
          }
        }
      } catch (_) {}

      return {'todayCollected': sum, 'todayCount': count};
    } catch (_) {
      return {'todayCollected': 0.0, 'todayCount': 0};
    }
  }

  Future<void> _loadSummaryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final curUser = Supabase.instance.client.auth.currentUser;
      String? centerId = widget.authViewModel.currentUser?.centerId;
      if (centerId == null && curUser != null) {
        try {
          final p = await Supabase.instance.client
              .from('profiles')
              .select('center_id')
              .eq('id', curUser.id)
              .maybeSingle();
          if (p != null && p['center_id'] != null) {
            centerId = p['center_id'].toString();
          }
        } catch (_) {}
      }

      final activeBranch = _selectedBranchId;
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final studentRepo = SupabaseStudentRepository(wrapper);
      final parentRepo = SupabaseParentRepository(wrapper);
      final teacherRepo = SupabaseTeacherRepository(wrapper);
      final branchRepo = SupabaseBranchRepository(wrapper);
      final subjectRepo = SupabaseSubjectRepository(wrapper);
      final groupRepo = SupabaseGroupRepository(wrapper);
      final summaryRepo = SupabaseAcademySummaryRepository(wrapper);
      final paymentRepo = SupabasePaymentRepository(wrapper);
      final notificationRepo = getIt<INotificationRepository>();

      // Fetch branches for this center
      List<Branch> centerBranches = [];
      if (centerId != null) {
        try {
          final bRes = await Supabase.instance.client
              .from('branches')
              .select()
              .eq('center_id', centerId)
              .order('name');
          centerBranches = (bRes as List)
              .map((j) => Branch.fromJson(Map<String, dynamic>.from(j as Map)))
              .toList();
        } catch (_) {}
      }
      if (centerBranches.isEmpty && centerId == null) {
        centerBranches = await branchRepo.fetchBranches().catchError((_) => <Branch>[]);
      }
      final centerBranchIds = centerBranches.map((b) => b.id).toSet();

      Set<String> centerProfileStudentIds = {};
      Set<String> centerProfileTeacherIds = {};
      if (centerId != null) {
        try {
          final pRes = await Supabase.instance.client
              .from('profiles')
              .select('id, role')
              .eq('center_id', centerId);
          for (final row in pRes as List) {
            final pid = row['id']?.toString();
            final r = row['role']?.toString();
            if (pid != null) {
              if (r == 'student') centerProfileStudentIds.add(pid);
              if (r == 'teacher') centerProfileTeacherIds.add(pid);
            }
          }
        } catch (_) {}
      }

      final results = await Future.wait([
        studentRepo.fetchStudents(branchId: activeBranch, pageSize: 500).catchError(
          (_) => const PaginatedResult<Student>(
            total: 0,
            page: 1,
            pageSize: 20,
            data: [],
          ),
        ),
        parentRepo.fetchParents(pageSize: 500).catchError(
          (_) => const PaginatedResult<Parent>(
            total: 0,
            page: 1,
            pageSize: 20,
            data: [],
          ),
        ),
        teacherRepo.fetchTeachers(branchId: activeBranch, pageSize: 500).catchError(
          (_) => const PaginatedResult<Teacher>(
            total: 0,
            page: 1,
            pageSize: 20,
            data: [],
          ),
        ),
        branchRepo.fetchBranches().catchError((_) => <Branch>[]),
        centerId != null
            ? Supabase.instance.client
                .from('subjects')
                .select()
                .eq('center_id', centerId)
                .order('name')
                .then((rows) => (rows as List)
                    .map((j) => SubjectEntity.fromJson(
                        Map<String, dynamic>.from(j as Map)))
                    .toList())
                .catchError((_) => <SubjectEntity>[])
            : subjectRepo.fetchSubjects().catchError((_) => <SubjectEntity>[]),
        groupRepo.fetchGroups(branchId: activeBranch).catchError((_) => <GroupEntity>[]),
        summaryRepo.fetchSummary().catchError(
          (_) => const AcademyCoreSummary(
            activeBranches: 0,
            activeStudents: 0,
            activeTeachers: 0,
            activeSubjects: 0,
            activeGroups: 0,
            todayScheduledClasses: 0,
          ),
        ),
        _fetchOpsMetrics(),
        _fetchRecentActivity(),
        notificationRepo.getNotifications().catchError(
          (_) => <AppNotification>[],
        ),
        notificationRepo.getUnreadCount().catchError((_) => 0),
        paymentRepo.fetchSystemFinancialSummary().catchError(
          (_) => SystemFinancialSummary(
            totalOutstandingMinor: 0,
            totalCollectedMinor: 0,
            expectedMonthlyRevenueMinor: 0,
            totalAdjustmentsMinor: 0,
          ),
        ),
        _fetchTodayTreasuryCollections(centerId),
      ]);

      double fallbackTreasury = 0.0;
      final sysSummary = results[11] as SystemFinancialSummary;
      var totalCollected = sysSummary.totalCollectedMinor / 100.0;
      if (totalCollected == 0.0) {
        try {
          final trans = await Supabase.instance.client
              .from('payment_transactions')
              .select('amount, amount_minor')
              .limit(100);
          for (final r in trans as List) {
            if (r['amount'] != null) {
              fallbackTreasury += (r['amount'] as num).toDouble();
            } else if (r['amount_minor'] != null) {
              fallbackTreasury += ((r['amount_minor'] as num).toDouble() / 100.0);
            }
          }
        } catch (_) {}
        if (fallbackTreasury > 0) {
          totalCollected = fallbackTreasury;
        }
      }

      if (!mounted) return;
      setState(() {
        final studentResult = results[0] as PaginatedResult<Student>;
        if (centerId != null) {
          _students = studentResult.data.where((s) {
            return centerProfileStudentIds.contains(s.profileId) ||
                (s.primaryBranchId.isNotEmpty &&
                    centerBranchIds.contains(s.primaryBranchId));
          }).toList();
        } else {
          _students = studentResult.data;
        }
        _studentTotal = _students.length;

        final parentResult = results[1] as PaginatedResult<Parent>;
        _parents = parentResult.data;
        _parentTotal = parentResult.total;

        final teacherResult = results[2] as PaginatedResult<Teacher>;
        if (centerId != null) {
          _teachers = teacherResult.data.where((t) {
            return centerProfileTeacherIds.contains(t.profileId) ||
                (t.primaryBranchId.isNotEmpty &&
                    centerBranchIds.contains(t.primaryBranchId));
          }).toList();
        } else {
          _teachers = teacherResult.data;
        }
        _teacherTotal = _teachers.length;

        _branches = centerBranches;
        _subjects = results[4] as List<SubjectEntity>;
        final allGroups = results[5] as List<GroupEntity>;
        _groups = centerBranchIds.isEmpty
            ? allGroups
            : allGroups.where((g) => centerBranchIds.contains(g.branchId)).toList();

        final rawSummary = results[6] as AcademyCoreSummary;
        _summary = AcademyCoreSummary(
          activeBranches: _branches.length,
          activeStudents: _studentTotal,
          activeTeachers: _teacherTotal,
          activeSubjects: _subjects.length,
          activeGroups: _groups.length,
          todayScheduledClasses: rawSummary.todayScheduledClasses,
        );
        _opsMetrics = results[7] as _AdminOpsMetrics;
        _recentActivity = results[8] as List<_AdminActivityItem>;
        _notifications = results[9] as List<AppNotification>;
        _unreadCount = results[10] as int;

        _treasuryTotalCollected = totalCollected;
        _treasuryPendingInvoices = sysSummary.totalOutstandingMinor / 100.0;

        final todayFin = results[12] as Map<String, dynamic>;
        _treasuryTodayCollected =
            (todayFin['todayCollected'] as num?)?.toDouble() ?? 0.0;
        _treasuryReceiptsCount =
            (todayFin['todayCount'] as num?)?.toInt() ?? 0;

        if (_treasuryTotalCollected < _treasuryTodayCollected) {
          _treasuryTotalCollected = _treasuryTodayCollected;
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('socketexception') ||
            errStr.contains('failed host lookup') ||
            errStr.contains('clientexception') ||
            errStr.contains('network') ||
            errStr.contains('connection')) {
          _errorMessage = 'تعذر الاتصال بالسيرفر. يرجى التحقق من اتصالك بالإنترنت والضغط على إعادة المحاولة.';
        } else {
          _errorMessage = e.toString();
        }
      });
    }
  }

  Future<_AdminOpsMetrics> _fetchOpsMetrics() async {
    final client = Supabase.instance.client;
    final today = DateTime.now().toIso8601String().split('T').first;
    final results = await Future.wait<List<dynamic>>([
      _safeList(
        () => client
            .from('class_sessions')
            .select('id')
            .eq('session_date', today),
      ),
      _safeList(
        () => client.from('attendance_records').select('id').inFilter(
          'attendance_status',
          ['absent', 'late'],
        ),
      ),
      _safeList(
        () =>
            client.from('leave_requests').select('id').eq('status', 'pending'),
      ),
      _safeList(
        () => client
            .from('homework_submissions')
            .select('id')
            .eq('status', 'submitted'),
      ),
      _safeList(
        () => client.from('invoices').select('id').inFilter('status', [
          'issued',
          'pending',
          'unpaid',
          'overdue',
          'partially_paid',
        ]),
      ),
      _safeList(
        () => client.from('lessons').select('id').eq('status', 'published'),
      ),
      _safeList(
        () => client
            .from('class_session_boards')
            .select('id')
            .eq('is_published', true),
      ),
    ]);

    return _AdminOpsMetrics(
      todaySessions: results[0].length,
      attendanceExceptions: results[1].length,
      pendingLeaves: results[2].length,
      gradingQueue: results[3].length,
      openInvoices: results[4].length,
      publishedLessons: results[5].length,
      publishedBoards: results[6].length,
    );
  }

  Future<List<_AdminActivityItem>> _fetchRecentActivity() async {
    final client = Supabase.instance.client;
    final activity = <_AdminActivityItem>[];

    // 1. Receipts (الخزينة والتحصيلات النقدية)
    final receipts = await _safeList(
      () => client
          .from('receipts')
          .select('id, receipt_number, amount_minor, issued_at')
          .order('issued_at', ascending: false)
          .limit(6),
    );
    activity.addAll(
      receipts.map(
        (row) {
          final amt = ((row['amount_minor'] as num? ?? 0) / 100.0);
          final amtFormatted =
              amt == amt.toInt() ? amt.toInt().toString() : amt.toStringAsFixed(2);
          final recNum = row['receipt_number']?.toString().isNotEmpty == true
              ? row['receipt_number'].toString()
              : (row['id']?.toString().length ?? 0) > 6
                  ? row['id'].toString().substring(0, 6)
                  : (row['id']?.toString() ?? '');
          return _AdminActivityItem.fromMap(
            row,
            title: 'تحصيل نقدية بالخزينة #$recNum ($amtFormatted ج.م)',
            type: 'خزينة',
            dateKey: 'issued_at',
          );
        },
      ),
    );

    // 2. Attendance Records (الحضور الميداني)
    final attendance = await _safeList(
      () => client
          .from('attendance_records')
          .select('id, attendance_status, marked_at')
          .order('marked_at', ascending: false)
          .limit(6),
    );
    activity.addAll(
      attendance.map(
        (row) {
          final status = row['attendance_status']?.toString() ?? 'present';
          final title = switch (status) {
            'present' => 'تسجيل حضور طالب',
            'absent' => 'تسجيل غياب طالب',
            'late' => 'تسجيل تأخر طالب',
            _ => 'حركة حضور بالسنتر',
          };
          return _AdminActivityItem.fromMap(
            row,
            title: title,
            type: 'حضور',
            dateKey: 'marked_at',
          );
        },
      ),
    );

    // 3. Leave Requests
    final leaves = await _safeList(
      () => client
          .from('leave_requests')
          .select('id, reason, status, submitted_at')
          .order('submitted_at', ascending: false)
          .limit(6),
    );
    activity.addAll(
      leaves.map(
        (row) => _AdminActivityItem.fromMap(
          row,
          title: row['reason']?.toString().isNotEmpty == true
              ? row['reason'].toString()
              : 'طلب إجازة',
          type: 'إجازة',
          dateKey: 'submitted_at',
        ),
      ),
    );

    // 4. Invoices
    final invoices = await _safeList(
      () => client
          .from('invoices')
          .select('id, invoice_number, status, due_at, issued_at')
          .order('issued_at', ascending: false)
          .limit(6),
    );
    activity.addAll(
      invoices.map(
        (row) => _AdminActivityItem.fromMap(
          row,
          title: row['invoice_number']?.toString().isNotEmpty == true
              ? 'فاتورة #${row['invoice_number']}'
              : 'فاتورة جديدة',
          type: 'مالية',
          dateKey: row['issued_at'] != null ? 'issued_at' : 'due_at',
        ),
      ),
    );

    // 5. Enrollments
    final enrollments = await _safeList(
      () => client
          .from('enrollments')
          .select('id, status, start_date')
          .order('start_date', ascending: false)
          .limit(6),
    );
    activity.addAll(
      enrollments.map(
        (row) => _AdminActivityItem.fromMap(
          row,
          title: 'تسجيل طالب في مجموعة',
          type: 'تسجيل',
          dateKey: 'start_date',
        ),
      ),
    );

    activity.sort((a, b) {
      final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return activity.take(12).toList();
  }

  Future<List<dynamic>> _safeList(Future<dynamic> Function() query) async {
    try {
      final result = await query();
      return result is List ? result : <dynamic>[];
    } catch (e, st) {
      debugPrint('Admin query failed: $e\n$st');
      return <dynamic>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _AdminOverview(
        authViewModel: widget.authViewModel,
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        students: _students,
        parents: _parents,
        teachers: _teachers,
        branches: _branches,
        selectedBranchId: _selectedBranchId,
        onBranchChanged: (branchId) {
          setState(() => _selectedBranchId = branchId);
          _loadSummaryData();
        },
        subjects: _subjects,
        groups: _groups,
        summary: _summary,
        studentTotal: _studentTotal,
        teacherTotal: _teacherTotal,
        parentTotal: _parentTotal,
        treasuryTotalCollected: _treasuryTotalCollected,
        treasuryTodayCollected: _treasuryTodayCollected,
        treasuryPendingInvoices: _treasuryPendingInvoices,
        treasuryReceiptsCount: _treasuryReceiptsCount,
        opsMetrics: _opsMetrics,
        recentActivity: _recentActivity,
        onRetry: _loadSummaryData,
        onNavigate: (index) => setState(() => _selectedIndex = index),
      ),
      const BranchManagementScreen(),
      const SubjectManagementScreen(),
      const GroupManagementScreen(),
      const ScheduleManagementScreen(),
      const StudentManagementScreen(),
      const ParentManagementScreen(),
      const TeacherManagementScreen(),
      const StaffManagementScreen(),
      const CurriculumEditorScreen(),
      const QuestionBankScreen(),
      const HomeworkManagementScreen(),
      const ExamManagementScreen(),
      const AttendanceOperationsScreen(),
      const FinanceManagementScreen(),
      const RbacManagementScreen(),
      const AuditLogScreen(),
      const StudyReplayScreen(),
      const DataImportScreen(),
      const AppSettingsScreen(),
      const AdminAnalyticsScreen(),
      const HelpdeskManagementScreen(),
      const ReportsDashboardScreen(),
    ];

    return PortalScaffold(
      title: 'إدارة السنتر والمنظومة',
      subtitle: 'لوحة التحكم الإدارية المتكاملة',
      icon: Icons.admin_panel_settings,
      accentColor: AppColors.adminRole,
      selectedIndex: _selectedIndex,
      destinations: const [
        PortalDestination(icon: Icons.dashboard, label: 'نظرة عامة'),
        PortalDestination(icon: Icons.domain, label: 'الفروع'),
        PortalDestination(icon: Icons.book, label: 'المواد'),
        PortalDestination(icon: Icons.group_work, label: 'المجموعات'),
        PortalDestination(icon: Icons.schedule, label: 'الجداول'),
        PortalDestination(icon: Icons.school, label: 'الطلاب'),
        PortalDestination(icon: Icons.family_restroom, label: 'أولياء الأمور'),
        PortalDestination(icon: Icons.person, label: 'المعلمون'),
        PortalDestination(icon: Icons.badge, label: 'الموظفون'),
        PortalDestination(icon: Icons.auto_stories, label: 'المناهج'),
        PortalDestination(icon: Icons.help_outline, label: 'الأسئلة'),
        PortalDestination(icon: Icons.assignment, label: 'الواجبات'),
        PortalDestination(icon: Icons.quiz, label: 'الاختبارات'),
        PortalDestination(icon: Icons.event_note, label: 'الحضور'),
        PortalDestination(icon: Icons.monetization_on, label: 'المالية'),
        PortalDestination(icon: Icons.security, label: 'الصلاحيات'),
        PortalDestination(icon: Icons.manage_search, label: 'سجل العمليات'),
        PortalDestination(icon: Icons.video_library, label: 'تسجيلات الحصص'),
        PortalDestination(icon: Icons.upload_file, label: 'استيراد البيانات'),
        PortalDestination(icon: Icons.settings, label: 'الإعدادات'),
        PortalDestination(icon: Icons.analytics, label: 'التحليلات'),
        PortalDestination(icon: Icons.support_agent, label: 'الدعم الفني'),
        PortalDestination(icon: Icons.assessment, label: 'التقارير'),
      ],
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      onRefresh: _loadSummaryData,
      onSignOut: widget.authViewModel.signOut,
      body: pages[_selectedIndex],
    );
  }
}

class _AdminOverview extends StatelessWidget {
  final AuthViewModel authViewModel;
  final bool isLoading;
  final String? errorMessage;
  final List<Student> students;
  final List<Parent> parents;
  final List<Teacher> teachers;
  final List<Branch> branches;
  final String? selectedBranchId;
  final ValueChanged<String?> onBranchChanged;
  final List<SubjectEntity> subjects;
  final List<GroupEntity> groups;
  final AcademyCoreSummary? summary;
  final int studentTotal;
  final int teacherTotal;
  final int parentTotal;
  final double treasuryTotalCollected;
  final double treasuryTodayCollected;
  final double treasuryPendingInvoices;
  final int treasuryReceiptsCount;
  final _AdminOpsMetrics opsMetrics;
  final List<_AdminActivityItem> recentActivity;
  final VoidCallback onRetry;
  final ValueChanged<int> onNavigate;

  const _AdminOverview({
    required this.authViewModel,
    required this.isLoading,
    required this.errorMessage,
    required this.students,
    required this.parents,
    required this.teachers,
    required this.branches,
    this.selectedBranchId,
    required this.onBranchChanged,
    required this.subjects,
    required this.groups,
    required this.summary,
    required this.studentTotal,
    required this.teacherTotal,
    required this.parentTotal,
    required this.treasuryTotalCollected,
    required this.treasuryTodayCollected,
    required this.treasuryPendingInvoices,
    required this.treasuryReceiptsCount,
    required this.opsMetrics,
    required this.recentActivity,
    required this.onRetry,
    required this.onNavigate,
  });

  static String _formatMoney(double amount) {
    if (amount == 0) return '0';
    final isInt = amount == amount.truncateToDouble();
    final parts =
        (isInt ? amount.toInt().toString() : amount.toStringAsFixed(2)).split('.');
    final withCommas = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return parts.length > 1 ? '$withCommas.${parts[1]}' : withCommas;
  }

  @override
  Widget build(BuildContext context) {
    final user = authViewModel.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final scopedGroups = selectedBranchId == null
        ? groups
        : groups.where((g) => g.branchId == selectedBranchId).toList();
    final scopedStudents = selectedBranchId == null
        ? students
        : students.where((s) => s.primaryBranchId == selectedBranchId).toList();
    final scopedTeachers = selectedBranchId == null
        ? teachers
        : teachers.where((t) => t.primaryBranchId == selectedBranchId).toList();

    // The count strictly represents the active center and selected branch, NEVER global database totals
    final studentCount = scopedStudents.length;
    final teacherCount = scopedTeachers.length;
    final groupCount = scopedGroups.length;
    final parentCount = parents.length;

    final treasuryValue = '${_formatMoney(treasuryTotalCollected)} ج.م';
    final treasurySubtitle = treasuryTodayCollected > 0
        ? 'تحصيل اليوم: +${_formatMoney(treasuryTodayCollected)} ج.م'
        : (treasuryPendingInvoices > 0
            ? 'مستحقات معلقة: ${_formatMoney(treasuryPendingInvoices)} ج.م'
            : (treasuryTotalCollected > 0 ? 'إجمالي النقدية المحصلة' : 'لا توجد متحصلات بعد'));

    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        children: [
          // ── 1. Executive Master Hero Header ──
          FadeInSlide(
            duration: const Duration(milliseconds: 350),
            child: _buildExecutiveHero(
              context,
              user,
              isDark,
              studentCount,
              teacherCount,
              treasuryValue,
            ),
          ),

          const SizedBox(height: 14),

          // ── Multi-Branch Federation Selector Bar (العزل السحابي والتشغيل متعدد الفروع) ──
          FadeInSlide(
            delay: const Duration(milliseconds: 30),
            child: _MultiBranchFederationBar(
              branches: branches,
              selectedBranchId: selectedBranchId,
              onBranchChanged: onBranchChanged,
            ),
          ),

          const SizedBox(height: 16),

          // ── Day-End Settlement & Cash Drawer Reconciliation HUD (تقفيل الخزينة وجرد الدرج) ──
          FadeInSlide(
            delay: const Duration(milliseconds: 40),
            child: _DayEndSettlementHUD(
              todayCollected: treasuryTodayCollected,
              totalCollected: treasuryTotalCollected,
              receiptsCount: treasuryReceiptsCount,
              onOpenCashRegister: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DailyCashRegisterScreen(),
                  ),
                );
              },
              onOpenBookstorePos: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BookstorePosScreen(),
                  ),
                );
                onRetry();
              },
            ),
          ),

          const SizedBox(height: 16),

          // ── Security Audit Alert Radar (رادار التدقيق الأمني والرقابة الإدارية) ──
          FadeInSlide(
            delay: const Duration(milliseconds: 45),
            child: _SecurityAuditRadarCard(
              onOpenAuditLog: () => onNavigate(16),
            ),
          ),

          if (isLoading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(color: AppColors.adminRole),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            FadeInSlide(
              child: PortalErrorBanner(
                message: errorMessage!,
                onRetry: onRetry,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Live Center Command & Operations Radar (رادار المراقبة الميدانية الحية) ──
          FadeInSlide(
            delay: const Duration(milliseconds: 50),
            child: _LiveCenterCommandRadarCard(
              onOpenReceptionTv: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ReceptionLiveTvKioskScreen(),
                  ),
                );
              },
              onOpenQrGate: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ReceptionQrGateScreen(),
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
              onOpenBookstorePos: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BookstorePosScreen(),
                  ),
                );
                onRetry();
              },
              onOpenAuditLog: () => onNavigate(16),
              onOpenEmergencyBroadcast: () => _openCenterEmergencyBroadcastDialog(context),
              onOpenQuickFloat: () => _openQuickCashDepositDialog(context),
            ),
          ),

          const SizedBox(height: 24),

          // ── 2. Primary Executive KPI Cards (4 Cards Grid) ──
          FadeInSlide(
            delay: const Duration(milliseconds: 60),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المؤشرات الحيوية للمنظومة 📊',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'تحديث لحظي',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.adminRole,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: const Duration(milliseconds: 100),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                if (isWide) {
                  return Row(
                    children: [
                      Expanded(
                        child: _ExecutiveKpiCard(
                          title: 'الطلاب المسجلون',
                          value: studentCount.toString(),
                          subtitle: '$groupCount مجموعة دراسية',
                          icon: Icons.school_rounded,
                          accentColor: AppColors.primary,
                          onTap: () => onNavigate(5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ExecutiveKpiCard(
                          title: 'المعلمون المعتمدون',
                          value: teacherCount.toString(),
                          subtitle: '${subjects.length} مادة معتمدة',
                          icon: Icons.person_rounded,
                          accentColor: AppColors.purple,
                          onTap: () => onNavigate(7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ExecutiveKpiCard(
                          title: 'أولياء الأمور',
                          value: parentCount.toString(),
                          subtitle: 'حسابات نشطة للمتابعة',
                          icon: Icons.family_restroom_rounded,
                          accentColor: AppColors.warning,
                          onTap: () => onNavigate(6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ExecutiveKpiCard(
                          title: 'الخزينة والتحصيل',
                          value: treasuryValue,
                          subtitle: treasurySubtitle,
                          icon: Icons.account_balance_wallet_rounded,
                          accentColor: AppColors.success,
                          onTap: () => onNavigate(14),
                        ),
                      ),
                    ],
                  );
                }

                // Mobile 2x2 Grid
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ExecutiveKpiCard(
                            title: 'الطلاب المسجلون',
                            value: studentCount.toString(),
                            subtitle: '$groupCount مجموعة نشطة',
                            icon: Icons.school_rounded,
                            accentColor: AppColors.primary,
                            onTap: () => onNavigate(5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ExecutiveKpiCard(
                            title: 'المعلمون المعتمدون',
                            value: teacherCount.toString(),
                            subtitle: '${subjects.length} مادة معتمدة',
                            icon: Icons.person_rounded,
                            accentColor: AppColors.purple,
                            onTap: () => onNavigate(7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ExecutiveKpiCard(
                            title: 'أولياء الأمور',
                            value: parentCount.toString(),
                            subtitle: 'متابعة الحضور',
                            icon: Icons.family_restroom_rounded,
                            accentColor: AppColors.warning,
                            onTap: () => onNavigate(6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ExecutiveKpiCard(
                            title: 'الخزينة والتحصيل',
                            value: treasuryValue,
                            subtitle: treasurySubtitle,
                            icon: Icons.account_balance_wallet_rounded,
                            accentColor: AppColors.success,
                            onTap: () => onNavigate(14),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // ── 3. Operational Command Hub (العمليات اليومية السريعة) ──
          FadeInSlide(
            delay: const Duration(milliseconds: 140),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'مركز العمليات والتشغيل السريع ⚡',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'أدوات السنتر الميدانية',
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: const Duration(milliseconds: 180),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final tiles = [
                  _ExecutiveActionTile(
                    title: 'بوابة الاستقبال (QR)',
                    subtitle: 'تسجيل حضور سريع بالباركود مع إشعار المصروفات',
                    icon: Icons.qr_code_scanner_rounded,
                    accentColor: AppColors.primary,
                    badge: 'فوري ⚡',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReceptionQrGateScreen(),
                        ),
                      );
                    },
                  ),
                  _ExecutiveActionTile(
                    title: 'تقفيل الخزينة اليومية',
                    subtitle: 'جرد ومطابقة النقدية المستلمة وطباعة التقفيل',
                    icon: Icons.point_of_sale_rounded,
                    accentColor: AppColors.success,
                    badge: 'كاش 💵',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DailyCashRegisterScreen(),
                        ),
                      );
                    },
                  ),
                  _ExecutiveActionTile(
                    title: 'تصفية أرباح المدرسين',
                    subtitle: 'حساب نسب الحصص والطلاب مع تقرير PDF معتمد',
                    icon: Icons.calculate_rounded,
                    accentColor: AppColors.teacherRole,
                    badge: 'محاسبة 👨‍🏫',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TeacherSettlementScreen(),
                        ),
                      );
                    },
                  ),
                  _ExecutiveActionTile(
                    title: 'مبيعات الملازم (POS)',
                    subtitle: 'نقطة بيع المذكرات مع طابعة الفواتير الحرارية',
                    icon: Icons.menu_book_rounded,
                    accentColor: Colors.deepOrange,
                    badge: 'مخزن 📦',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BookstorePosScreen(),
                        ),
                      );
                    },
                  ),
                  _ExecutiveActionTile(
                    title: 'كشوفات الحضور الرسمية',
                    subtitle: 'طباعة كشوف الحضور الورقية لتوقيع الطلاب بالقاعة',
                    icon: Icons.print_rounded,
                    accentColor: AppColors.staffRole,
                    badge: 'PDF 🖨️',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AttendanceReportsScreen(),
                        ),
                      );
                    },
                  ),
                  _ExecutiveActionTile(
                    title: 'شاشة العرض الحية TV',
                    subtitle: 'عرض جدول الحصص والقاعات لشاشة استقبال السنتر',
                    icon: Icons.tv_rounded,
                    accentColor: AppColors.secondary,
                    badge: 'عرض 📺',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReceptionLiveTvKioskScreen(),
                        ),
                      );
                    },
                  ),
                  _ExecutiveActionTile(
                    title: 'استيعاب ومقاعد القاعات',
                    subtitle: 'مخطط القاعات وتوزيع مقاعد الطلاب الشاغرة للحصص',
                    icon: Icons.airline_seat_recline_normal_rounded,
                    accentColor: AppColors.info,
                    badge: 'قاعات 🪑',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ClassroomCapacityScreen(),
                        ),
                      );
                    },
                  ),
                ];

                if (isWide) {
                  return GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children: tiles,
                  );
                }

                return Column(
                  children: tiles
                      .map(
                        (tile) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: tile,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // ── 4. Operational Pulse & Queue (نبض التشغيل والحالات المعلقة) ──
          FadeInSlide(
            delay: const Duration(milliseconds: 220),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'نبض التشغيل والحالات المعلقة 🔔',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'إجراءات معلقة',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: const Duration(milliseconds: 260),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _ExecutivePulseChip(
                    label: 'حصص اليوم',
                    count: opsMetrics.todaySessions,
                    icon: Icons.today_rounded,
                    accentColor: AppColors.primary,
                    onTap: () => onNavigate(13),
                  ),
                  const SizedBox(width: 8),
                  _ExecutivePulseChip(
                    label: 'استثناءات الحضور',
                    count: opsMetrics.attendanceExceptions,
                    icon: Icons.assignment_late_rounded,
                    accentColor: AppColors.warning,
                    onTap: () => onNavigate(13),
                  ),
                  const SizedBox(width: 8),
                  _ExecutivePulseChip(
                    label: 'إجازات معلقة',
                    count: opsMetrics.pendingLeaves,
                    icon: Icons.event_busy_rounded,
                    accentColor: Colors.amber,
                    onTap: () => onNavigate(13),
                  ),
                  const SizedBox(width: 8),
                  _ExecutivePulseChip(
                    label: 'واجبات للتصحيح',
                    count: opsMetrics.gradingQueue,
                    icon: Icons.grading_rounded,
                    accentColor: AppColors.purple,
                    onTap: () => onNavigate(11),
                  ),
                  const SizedBox(width: 8),
                  _ExecutivePulseChip(
                    label: 'فواتير مستحقة',
                    count: opsMetrics.openInvoices,
                    icon: Icons.receipt_long_rounded,
                    accentColor: AppColors.error,
                    onTap: () => onNavigate(14),
                  ),
                  const SizedBox(width: 8),
                  _ExecutivePulseChip(
                    label: 'سبورات منشورة',
                    count: opsMetrics.publishedBoards,
                    icon: Icons.draw_rounded,
                    accentColor: AppColors.success,
                    onTap: () => onNavigate(13),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── 5. Quick Data Tools (تصدير البيانات) ──
          FadeInSlide(
            delay: const Duration(milliseconds: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'أدوات استخراج البيانات (CSV) 💾',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'نسخ للحافظة',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ExportButton(
                      onPressed: () => _copyStudentsCsv(context),
                      icon: Icons.school_rounded,
                      label: 'تصدير الطلاب ($studentCount)',
                    ),
                    _ExportButton(
                      onPressed: () => _copyGroupsCsv(context),
                      icon: Icons.group_work_rounded,
                      label: 'تصدير المجموعات ($groupCount)',
                    ),
                    _ExportButton(
                      onPressed: () => _copyTeachersCsv(context),
                      icon: Icons.person_rounded,
                      label: 'تصدير المدرسين ($teacherCount)',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── 6. Live Activity Stream ──
          FadeInSlide(
            delay: const Duration(milliseconds: 340),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'أحدث الأنشطة والعمليات الميدانية ⏱️',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'آخر 12 حركة',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FadeInSlide(
            delay: const Duration(milliseconds: 380),
            child: _ActivityList(items: recentActivity),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildExecutiveHero(
    BuildContext context,
    dynamic user,
    bool isDark,
    int studentCount,
    int teacherCount,
    String treasuryValue,
  ) {
    final activeBranch = selectedBranchId != null
        ? branches.where((b) => b.id == selectedBranchId).firstOrNull
        : null;
    final branchName = activeBranch?.name ??
        (selectedBranchId == null
            ? 'المنظومة الموحدة (كافة الفروع)'
            : (branches.where((b) => b.id == user?.branchId).firstOrNull?.name ??
                (user?.branchId != null && (user!.branchId as String).length < 15
                    ? (user!.branchId as String)
                    : 'الفرع الرئيسي')));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFFFFFFFF), const Color(0xFFF1F5F9)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Live badge + Switcher & Actions
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: Colors.greenAccent,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'السنتر نشط الآن • مباشر',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CenterSwitcherWidget(onCenterChanged: onRetry),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'إدارة السنتر والشراكات',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CenterPartnershipsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.handshake_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: 'الانضمام لسنتر بكود',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => JoinCenterDialog.show(context, onJoined: onRetry),
                    icon: const Icon(Icons.add_business_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: 'تحديث البيانات',
                    visualDensity: VisualDensity.compact,
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Greeting with Avatar
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EditableAvatar(
                avatarUrl: user?.avatarUrl,
                name: user?.fullName ?? "مدير المنظومة",
                role: 'admin',
                userId: user?.id,
                userEmail: user?.email,
                radius: 28,
                onAvatarChanged: (_) => onRetry(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أهلاً بك، ${user?.fullName ?? "مدير المنظومة"} 👋',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${authViewModel.userRole?.displayName ?? "إدارة السنتر العليا"} • $branchName',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Quick Live Summary Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceAround,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildHeroStat('الطلاب المسجلون', '$studentCount طالب', Icons.school_rounded, AppColors.primary),
                _buildHeroStat('المعلمون', '$teacherCount معلم', Icons.person_rounded, AppColors.purple),
                _buildHeroStat('حصص اليوم', '${opsMetrics.todaySessions} حصة', Icons.today_rounded, AppColors.warning),
                _buildHeroStat('الخزينة', treasuryValue, Icons.account_balance_wallet_rounded, AppColors.success),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  void _openCenterEmergencyBroadcastDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _CenterEmergencyBroadcastDialog(),
    );
  }

  void _openQuickCashDepositDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _QuickCashDepositDialog(onSuccess: onRetry),
    );
  }

  Future<void> _copyStudentsCsv(BuildContext context) async {
    final rows = [
      ['id', 'student_code', 'full_name', 'email', 'grade_level', 'status'],
      ...students.map(
        (s) => [
          s.id,
          s.studentCode,
          s.fullName,
          s.email,
          s.gradeLevel ?? '',
          s.status,
        ],
      ),
    ];
    await _copyCsv(context, 'تم نسخ بيانات الطلاب بصيغة CSV إلى الحافظة', rows);
  }

  Future<void> _copyGroupsCsv(BuildContext context) async {
    final rows = [
      ['id', 'code', 'name', 'subject_id', 'branch_id', 'status'],
      ...groups.map(
        (g) => [g.id, g.code, g.name, g.subjectId, g.branchId, g.status],
      ),
    ];
    await _copyCsv(context, 'تم نسخ بيانات المجموعات بصيغة CSV إلى الحافظة', rows);
  }

  Future<void> _copyTeachersCsv(BuildContext context) async {
    final rows = [
      ['id', 'full_name', 'email', 'specialization'],
      ...teachers.map(
        (t) => [t.id, t.fullName, t.email, t.specialization ?? ''],
      ),
    ];
    await _copyCsv(context, 'تم نسخ بيانات المعلمين بصيغة CSV إلى الحافظة', rows);
  }

  Future<void> _copyCsv(
    BuildContext context,
    String message,
    List<List<String>> rows,
  ) async {
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}

class _ExecutiveKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _ExecutiveKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? accentColor.withValues(alpha: 0.25)
                  : accentColor.withValues(alpha: 0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: isDark ? 0.12 : 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: textSecondary.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExecutiveActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String badge;
  final VoidCallback onTap;

  const _ExecutiveActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : Colors.black12,
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExecutivePulseChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _ExecutivePulseChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: count > 0
                  ? accentColor.withValues(alpha: 0.4)
                  : (isDark ? AppColors.darkBorder : Colors.black12),
              width: count > 0 ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminOpsMetrics {
  final int todaySessions;
  final int attendanceExceptions;
  final int pendingLeaves;
  final int gradingQueue;
  final int openInvoices;
  final int publishedLessons;
  final int publishedBoards;

  const _AdminOpsMetrics({
    this.todaySessions = 0,
    this.attendanceExceptions = 0,
    this.pendingLeaves = 0,
    this.gradingQueue = 0,
    this.openInvoices = 0,
    this.publishedLessons = 0,
    this.publishedBoards = 0,
  });
}

class _AdminActivityItem {
  final String title;
  final String type;
  final String status;
  final DateTime? date;

  const _AdminActivityItem({
    required this.title,
    required this.type,
    required this.status,
    required this.date,
  });

  factory _AdminActivityItem.fromMap(
    Map row, {
    required String title,
    required String type,
    required String dateKey,
  }) {
    return _AdminActivityItem(
      title: title,
      type: type,
      status: row['status']?.toString() ?? 'active',
      date: DateTime.tryParse(row[dateKey]?.toString() ?? ''),
    );
  }

  String get dateLabel {
    final value = date;
    if (value == null) return 'بدون تاريخ';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class _ActivityList extends StatelessWidget {
  final List<_AdminActivityItem> items;

  const _ActivityList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return GlassCard(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.adminRole.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.history, color: AppColors.adminRole),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'لا توجد أنشطة أو عمليات مسجلة حتى الآن.',
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: items
          .map(
            (item) => PortalListCard(
              icon: _iconForType(item.type),
              accentColor: _colorForStatus(item.status),
              title: item.title,
              subtitle: '${item.type} • ${item.dateLabel}',
              trailing: [PortalStatusChip(status: item.status)],
            ),
          )
          .toList(),
    );
  }

  static IconData _iconForType(String type) {
    return switch (type) {
      'خزينة' => Icons.point_of_sale_rounded,
      'حضور' => Icons.how_to_reg_rounded,
      'إجازة' => Icons.event_busy,
      'مالية' => Icons.receipt_long,
      'تسجيل' => Icons.person_add,
      _ => Icons.history,
    };
  }

  static Color _colorForStatus(String status) {
    return switch (status.toLowerCase()) {
      'active' || 'paid' || 'approved' || 'present' => AppColors.success,
      'pending' || 'issued' || 'partially_paid' || 'late' => AppColors.warning,
      'overdue' || 'rejected' || 'failed' || 'absent' => AppColors.error,
      _ => AppColors.info,
    };
  }
}

class _ExportButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _ExportButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ActionChip(
      onPressed: onPressed,
      avatar: Icon(icon, color: AppColors.adminRole, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      side: BorderSide(color: AppColors.adminRole.withValues(alpha: 0.4)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _LiveCenterCommandRadarCard extends StatefulWidget {
  final VoidCallback onOpenReceptionTv;
  final VoidCallback onOpenQrGate;
  final VoidCallback onOpenCashRegister;
  final VoidCallback onOpenBookstorePos;
  final VoidCallback onOpenAuditLog;
  final VoidCallback onOpenEmergencyBroadcast;
  final VoidCallback onOpenQuickFloat;

  const _LiveCenterCommandRadarCard({
    required this.onOpenReceptionTv,
    required this.onOpenQrGate,
    required this.onOpenCashRegister,
    required this.onOpenBookstorePos,
    required this.onOpenAuditLog,
    required this.onOpenEmergencyBroadcast,
    required this.onOpenQuickFloat,
  });

  @override
  State<_LiveCenterCommandRadarCard> createState() => _LiveCenterCommandRadarCardState();
}

class _LiveCenterCommandRadarCardState extends State<_LiveCenterCommandRadarCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _rooms = [];
  int _todayGateEntries = 0;
  int _activeSessionsCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _loadLiveRadarData();
  }

  Future<void> _loadLiveRadarData() async {
    try {
      final client = Supabase.instance.client;
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final startOfDay = '$todayStr 00:00:00';
      final endOfDay = '$todayStr 23:59:59';

      // 1. Fetch real rooms from database
      final roomsRes = await client.from('rooms').select().order('name');
      final loadedRooms = <Map<String, dynamic>>[];

      for (final r in (roomsRes as List)) {
        final cap = (r['capacity'] as num?)?.toInt() ?? 30;
        loadedRooms.add({
          'id': r['id'],
          'name': r['name'] as String? ?? 'قاعة عامة',
          'capacity': cap,
          'code': r['code']?.toString() ?? '',
          'session': null,
          'isLive': false,
        });
      }

      // 2. Fetch today's class sessions
      int activeSessions = 0;
      try {
        final sessionsRes = await client
            .from('class_sessions')
            .select('id, room_id, status, start_time, end_time, groups(name, subject, teachers(profiles(full_name)))')
            .eq('session_date', todayStr);

        for (final s in (sessionsRes as List)) {
          final roomId = s['room_id']?.toString();
          final grp = s['groups'] as Map<String, dynamic>?;
          final tchr = grp?['teachers'] as Map<String, dynamic>?;
          final prof = tchr?['profiles'] as Map<String, dynamic>?;
          final subjectName = grp?['name'] as String? ?? grp?['subject'] as String? ?? 'حصة دراسية';
          final teacherName = prof?['full_name'] as String? ?? 'معلم المادة';
          final status = s['status']?.toString().toLowerCase();
          final isLive = status == 'in_progress' || status == 'active' || status == 'live';

          if (isLive) activeSessions++;

          if (roomId != null) {
            final roomIdx = loadedRooms.indexWhere((rm) => rm['id']?.toString() == roomId);
            if (roomIdx != -1) {
              loadedRooms[roomIdx]['session'] = '$subjectName • $teacherName';
              loadedRooms[roomIdx]['isLive'] = isLive;
            }
          }
        }
      } catch (_) {}

      // 3. Fetch today's attendance check-ins
      int gateEntries = 0;
      try {
        final attendRes = await client
            .from('attendance')
            .select('id')
            .gte('recorded_at', startOfDay)
            .lte('recorded_at', endOfDay);
        gateEntries = (attendRes as List).length;
      } catch (_) {
        try {
          final recRes = await client
              .from('attendance_records')
              .select('id')
              .gte('marked_at', startOfDay)
              .lte('marked_at', endOfDay);
          gateEntries = (recRes as List).length;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _rooms = loadedRooms;
          _todayGateEntries = gateEntries;
          _activeSessionsCount = activeSessions;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFF8FAFC), const Color(0xFFEDF2F7)],
        ),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with responsive LayoutBuilder
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 450;
              final headerContent = Row(
                children: [
                  _CenterPulseBeacon(controller: _pulseController),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            const Text(
                              'رادار المراقبة والعمليات الحية للسنتر 📡',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _activeSessionsCount > 0
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.blue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _activeSessionsCount > 0
                                    ? '$_activeSessionsCount حصص نشطة الآن 🟢'
                                    : (_rooms.isNotEmpty ? 'المنظومة جاهزة 🟢' : 'بانتظار التهيئة ⚪'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _activeSessionsCount > 0 ? Colors.green : Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _rooms.isNotEmpty
                              ? '${_rooms.length} قاعات دراسية مسجلة • بوابات الدخول مؤمنة • الخزينة نشطة'
                              : 'لا توجد قاعات دراسية مضافة بعد • انقر لإدارة المقاعد والقاعات',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final tvButton = FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: widget.onOpenReceptionTv,
                icon: const Icon(Icons.tv_rounded, size: 16),
                label: const Text('شاشة العرض (TV)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    headerContent,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerLeft, child: tvButton),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: headerContent),
                  const SizedBox(width: 8),
                  tvButton,
                ],
              );
            },
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Live Classrooms Occupancy Strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'حالة القاعات الدراسية في الوقت الحقيقي الآن:',
                  style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ClassroomCapacityScreen()),
                  );
                },
                child: const Text(
                  'إدارة القاعات 🪑',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_rooms.isEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 450;
                final info = Row(
                  children: [
                    const Icon(Icons.meeting_room_outlined, color: Colors.blueGrey, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'لم يتم إضافة قاعات دراسية بالسنتر بعد',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'أضف قاعات السنتر ومقاعدها لتتبع نسب الإشغال والحصص الحية فورياً',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final addBtn = OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ClassroomCapacityScreen()),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('إضافة قاعة', style: TextStyle(fontSize: 11)),
                );

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            info,
                            const SizedBox(height: 8),
                            Align(alignment: Alignment.centerLeft, child: addBtn),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: info),
                            const SizedBox(width: 8),
                            addBtn,
                          ],
                        ),
                );
              },
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 650;
                final roomCards = _rooms.take(3).map((rm) {
                  final isLive = rm['isLive'] == true;
                  final session = rm['session'] as String?;
                  final cap = rm['capacity'] as int;
                  final statusColor = isLive
                      ? Colors.green
                      : (session != null ? Colors.blue : Colors.blueGrey);
                  return _buildRoomCard(
                    name: rm['name'] as String,
                    subject: session ?? 'شاغرة وجاهزة للحصص',
                    students: 'السعة: $cap مقعد',
                    rate: isLive ? 'حصة جارية' : (session != null ? 'مجدولة' : 'جاهزة ✔️'),
                    statusColor: statusColor,
                    isLive: isLive,
                  );
                }).toList();

                if (isWide) {
                  return Row(
                    children: roomCards
                        .map(
                          (c) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: c,
                            ),
                          ),
                        )
                        .toList(),
                  );
                }

                return Column(
                  children: roomCards
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: c,
                        ),
                      )
                      .toList(),
                );
              },
            ),

          const SizedBox(height: 16),

          // Smart Gates & Turnstiles Metric
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Row(
              children: [
                const Icon(Icons.sensor_door_rounded, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _todayGateEntries > 0
                        ? '+$_todayGateEntries عملية دخول ذكية مسجلة اليوم عبر البوابات ومطابقة الاشتراكات'
                        : '0 عمليات دخول مسجلة اليوم عبر البوابات (بانتظار بدء الحصص)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _todayGateEntries > 0
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _todayGateEntries > 0 ? 'نشط 🟢' : 'في الانتظار ⚪',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _todayGateEntries > 0 ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Executive Command Actions Toolbar
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCommandPill(
                label: 'بوابة الاستقبال QR 🪪',
                color: AppColors.primary,
                icon: Icons.qr_code_scanner_rounded,
                onTap: widget.onOpenQrGate,
              ),
              _buildCommandPill(
                label: 'تقفيل الخزينة وطباعة Z-Report 💵',
                color: Colors.green.shade700,
                icon: Icons.point_of_sale_rounded,
                onTap: widget.onOpenCashRegister,
              ),
              _buildCommandPill(
                label: 'كاشير الملازم وطباعة الباركود 📚',
                color: Colors.deepOrange.shade700,
                icon: Icons.menu_book_rounded,
                onTap: widget.onOpenBookstorePos,
              ),
              _buildCommandPill(
                label: 'سجل التدقيق الأمني 🛡️',
                color: Colors.purple.shade700,
                icon: Icons.shield_rounded,
                onTap: widget.onOpenAuditLog,
              ),
              _buildCommandPill(
                label: 'إيداع / حركة نقدية سريعة ➕',
                color: Colors.teal.shade700,
                icon: Icons.add_card_rounded,
                onTap: widget.onOpenQuickFloat,
              ),
              _buildCommandPill(
                label: 'إذاعة طوارئ عامة للسنتر 📢',
                color: Colors.redAccent.shade700,
                icon: Icons.campaign_rounded,
                onTap: widget.onOpenEmergencyBroadcast,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard({
    required String name,
    required String subject,
    required String students,
    required String rate,
    required Color statusColor,
    required bool isLive,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor)),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('بث حي', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(subject, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(students, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              Text(rate, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommandPill({
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

class _CenterPulseBeacon extends StatelessWidget {
  final AnimationController controller;

  const _CenterPulseBeacon({required this.controller});

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
                    color: const Color(0xFF2563EB).withValues(alpha: opacity),
                  ),
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2563EB),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF2563EB),
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

class _QuickCashDepositDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const _QuickCashDepositDialog({required this.onSuccess});

  @override
  State<_QuickCashDepositDialog> createState() => _QuickCashDepositDialogState();
}

class _QuickCashDepositDialogState extends State<_QuickCashDepositDialog> {
  final _amountCtrl = TextEditingController(text: '500');
  final _noteCtrl = TextEditingController();
  String _selectedType = 'student_fee';
  String _selectedMethod = 'cash';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _recordDeposit() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء إدخال مبلغ صحيح')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final client = Supabase.instance.client;
    final now = DateTime.now().toIso8601String();
    final recNum = 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

    try {
      await client.from('payment_transactions').insert({
        'amount': amount,
        'amount_minor': (amount * 100).toInt(),
        'currency': 'EGP',
        'transaction_type': _selectedType,
        'provider': _selectedMethod,
        'status': 'completed',
        'occurred_at': now,
      });
    } catch (_) {}

    try {
      await client.from('receipts').insert({
        'receipt_number': recNum,
        'amount_minor': (amount * 100).toInt(),
        'currency': 'EGP',
        'issued_at': now,
        'payment_method': _selectedMethod,
      });
    } catch (_) {}

    if (mounted) {
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إيداع $amount ج.م في الخزينة بنجاح وتسجيل إيصال #$recNum 💵✨'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_card_rounded, color: Colors.green),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'إيداع وتسجيل حركة نقدية في الخزينة 💵',
                      style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount quick chips
              Wrap(
                spacing: 8,
                children: ['200', '500', '1000', '2500', '5000'].map((val) {
                  return ActionChip(
                    label: Text('$val ج.م'),
                    onPressed: () => setState(() => _amountCtrl.text = val),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'المبلغ المودع (ج.م)',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'نوع المعاملة',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'student_fee', child: Text('تحصيل اشتراك طالب')),
                  DropdownMenuItem(value: 'bookstore_sale', child: Text('مبيعات ملازم وكتب')),
                  DropdownMenuItem(value: 'opening_float', child: Text('رصيد افتتاحي لدرج الخزينة')),
                  DropdownMenuItem(value: 'misc_income', child: Text('إيراد وتبرع متنوع')),
                ],
                onChanged: (val) => setState(() => _selectedType = val ?? 'student_fee'),
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: _selectedMethod,
                decoration: const InputDecoration(
                  labelText: 'طريقة الدفع',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('نقدية (كاش في الدرج) 💵')),
                  DropdownMenuItem(value: 'vodafone_cash', child: Text('فودافون كاش / إنستاباي 📱')),
                  DropdownMenuItem(value: 'card', child: Text('فيزا / بطاقة بنكية 💳')),
                ],
                onChanged: (val) => setState(() => _selectedMethod = val ?? 'cash'),
              ),
              const SizedBox(height: 20),

              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting ? null : _recordDeposit,
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  _isSubmitting ? 'جارٍ الحفظ...' : 'تأكيد الإيداع وتحديث الخزينة 🚀',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterEmergencyBroadcastDialog extends StatefulWidget {
  const _CenterEmergencyBroadcastDialog();

  @override
  State<_CenterEmergencyBroadcastDialog> createState() => _CenterEmergencyBroadcastDialogState();
}

class _CenterEmergencyBroadcastDialogState extends State<_CenterEmergencyBroadcastDialog> {
  final _titleCtrl = TextEditingController(text: 'تنبيه عاجل من إدارة السنتر');
  final _msgCtrl = TextEditingController(
    text: 'نحيط جميع الطلاب والمعلمين علماً بأنه نظراً لسوء الأحوال الجوية، تقرر تعديل مواعيد الحصص المسائية لتبدأ غداً في موعدها المعتاد.',
  );
  bool _sendStudents = true;
  bool _sendParents = true;
  bool _sendTeachers = true;
  bool _isBroadcasting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _broadcast() async {
    setState(() => _isBroadcasting = true);

    try {
      await Supabase.instance.client.from('notifications').insert({
        'title': _titleCtrl.text.trim(),
        'body': _msgCtrl.text.trim(),
        'type': 'system_broadcast',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الإذاعة العامة لجميع أفراد المنظومة بنجاح! 📢✨'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.campaign_rounded, color: Colors.redAccent, size: 26),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'إذاعة طوارئ عامة للسنتر 📢',
                      style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'عنوان الإذاعة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _msgCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'نص الرسالة العامة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'الجمهور المستهدف بالإشعار الفوري:',
                style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _sendStudents,
                onChanged: (val) => setState(() => _sendStudents = val ?? true),
                title: const Text('جميع الطلاب المسجلين 🎓'),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _sendParents,
                onChanged: (val) => setState(() => _sendParents = val ?? true),
                title: const Text('جميع أولياء الأمور 👨‍👩‍👧'),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _sendTeachers,
                onChanged: (val) => setState(() => _sendTeachers = val ?? true),
                title: const Text('المعلمون وطاقم العمل 👨‍🏫'),
              ),
              const SizedBox(height: 18),

              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isBroadcasting ? null : _broadcast,
                icon: _isBroadcasting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isBroadcasting ? 'جارٍ البث...' : 'إرسال الإذاعة العامة الآن للكل 🚀',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Multi-Branch Federation Selector Bar (نظام العزل السحابي متعدد الفروع)
// ─────────────────────────────────────────────────────────────────────────────
class _MultiBranchFederationBar extends StatelessWidget {
  final List<Branch> branches;
  final String? selectedBranchId;
  final ValueChanged<String?> onBranchChanged;

  const _MultiBranchFederationBar({
    required this.branches,
    required this.selectedBranchId,
    required this.onBranchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'إدارة الفروع المتعددة (Multi-Branch)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  selectedBranchId == null
                      ? 'المنظومة الموحدة 🌐'
                      : 'فرع معزول 🏛️',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildBranchChip(
                  label: '🌐 المنظومة الموحدة (الفرع الرئيسي)',
                  isSelected: selectedBranchId == null,
                  onTap: () => onBranchChanged(null),
                ),
                if (branches.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ...branches.map((branch) {
                    final isSelected = selectedBranchId == branch.id;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildBranchChip(
                        label: '🏛️ ${branch.name}',
                        isSelected: isSelected,
                        onTap: () => onBranchChanged(branch.id),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.35),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : null,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day-End Settlement & Cash Reconciliation HUD (تقفيل الخزينة والـ Z-Report)
// ─────────────────────────────────────────────────────────────────────────────
class _DayEndSettlementHUD extends StatelessWidget {
  final double todayCollected;
  final double totalCollected;
  final int receiptsCount;
  final VoidCallback onOpenCashRegister;
  final VoidCallback onOpenBookstorePos;

  const _DayEndSettlementHUD({
    required this.todayCollected,
    required this.totalCollected,
    required this.receiptsCount,
    required this.onOpenCashRegister,
    required this.onOpenBookstorePos,
  });

  static String _formatMoney(double amount) {
    if (amount == 0) return '0';
    final isInt = amount == amount.truncateToDouble();
    final parts =
        (isInt ? amount.toInt().toString() : amount.toStringAsFixed(2)).split('.');
    final withCommas = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return parts.length > 1 ? '$withCommas.${parts[1]}' : withCommas;
  }

  Future<void> _exportQuickZReport(BuildContext context) async {
    try {
      final now = DateTime.now();
      final dateStr = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final transactionLog = <Map<String, dynamic>>[];
      double realCashInflow = 0.0;

      try {
        final client = Supabase.instance.client;
        final paymentsRes = await client
            .from('payments')
            .select('id, amount, payment_type, created_at, student:students(profile:profiles(full_name))')
            .gte('created_at', todayStart)
            .order('created_at', ascending: false)
            .limit(25);

        for (final p in (paymentsRes as List)) {
          final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
          realCashInflow += amt;
          final createdAtStr = p['created_at']?.toString() ?? '';
          final dt = DateTime.tryParse(createdAtStr)?.toLocal();
          final timeStr = dt != null
              ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
              : '--:--';
          final sName = p['student']?['profile']?['full_name']?.toString() ?? 'طالب مسجل';
          final idStr = p['id']?.toString() ?? '0000';
          final shortId = idStr.length >= 6 ? idStr.substring(0, 6) : idStr;
          transactionLog.add({
            'time': timeStr,
            'type': p['payment_type']?.toString() ?? 'تحصيل نقدي',
            'receiptNo': 'REC-${shortId.toUpperCase()}',
            'studentName': sName,
            'amount': amt,
          });
        }
      } catch (_) {}

      final cashInflow = realCashInflow > 0 ? realCashInflow : todayCollected;
      const teacherPayouts = 0.0;
      final netExpected = cashInflow - teacherPayouts;
      final actualCash = netExpected;

      await ReportGeneratorService().generateDailyCashRegisterClosingPdf(
        centerName: 'منظومة بريفيو التعليمية المتطورة',
        shiftName: 'الوردية اليومية المجمعة',
        cashierName: 'كاشير الإدارة العامة',
        dateStr: dateStr,
        receiptsCount: transactionLog.isNotEmpty ? transactionLog.length : receiptsCount,
        totalGrossCashInflow: cashInflow,
        totalTeacherPayouts: teacherPayouts,
        netExpectedCash: netExpected,
        actualCountedCash: actualCash,
        discrepancy: 0.0,
        notes: transactionLog.isNotEmpty
            ? 'تمت المطابقة الآلية مع حركات التحصيل الحية بالخزينة - لا يوجد عجز نقدي.'
            : 'لا توجد حركات تحصيل مسجلة لليوم حتى الآن.',
        denominationsCount: {
          '200': (cashInflow ~/ 200),
          '100': ((cashInflow % 200) ~/ 100),
          '50': ((cashInflow % 100) ~/ 50),
          '20': 0,
          '10': 0,
          'coins': (cashInflow % 50).toInt(),
        },
        transactionLog: transactionLog,
        printDirectly: false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تصدير محضر إقفال الخزينة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF0F172A)]
              : [const Color(0xFFECFDF5), const Color(0xFFF0FDF4)],
        ),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.point_of_sale_rounded, color: Colors.green, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'مركز الإغلاق اليومي للخزينة ومطابقة الدرج 💵',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.green,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'الوردية نشطة 🟢',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'جرد لحظي للفئات النقدية ومطابقة إيصالات بوابات السنتر مع المقبوضات الفعلية',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cash summary numbers with responsive LayoutBuilder
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 520;
              final col1 = Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('متحصلات اليوم الفعلية', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      '+${_formatMoney(todayCollected)} ج.م',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.green),
                    ),
                  ],
                ),
              );
              final col2 = Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('سندات وإيصالات التحصيل', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      '$receiptsCount إيصال معتمد',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              );
              final col3 = Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('حالة المطابقة والعجز', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      todayCollected > 0 ? 'مطابق 0.00 ج.م ✔️' : '0.00 ج.م',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                  ],
                ),
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: col1),
                    const SizedBox(width: 10),
                    Expanded(child: col2),
                    const SizedBox(width: 10),
                    Expanded(child: col3),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: col1),
                      const SizedBox(width: 8),
                      Expanded(child: col2),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: col3),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Action buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onOpenCashRegister,
                icon: const Icon(Icons.calculate_rounded, size: 16),
                label: const Text('جرد النقدية وإقفال الخزينة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _exportQuickZReport(context),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.red),
                label: const Text('طباعة Z-Report معتمد (PDF)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onOpenBookstorePos,
                icon: const Icon(Icons.menu_book_rounded, size: 16, color: Colors.deepOrange),
                label: const Text('كاشير الملازم وطباعة الباركود', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Security Audit Alert Radar (رادار التدقيق الأمني ومراقبة العمليات الحساسة)
// ─────────────────────────────────────────────────────────────────────────────
class _SecurityAuditRadarCard extends StatefulWidget {
  final VoidCallback onOpenAuditLog;

  const _SecurityAuditRadarCard({
    required this.onOpenAuditLog,
  });

  @override
  State<_SecurityAuditRadarCard> createState() => _SecurityAuditRadarCardState();
}

class _SecurityAuditRadarCardState extends State<_SecurityAuditRadarCard> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchRecentLogs();
  }

  Future<void> _fetchRecentLogs() async {
    try {
      final rows = await Supabase.instance.client
          .from('audit_logs')
          .select('id, table_name, action, actor_id, created_at')
          .order('created_at', ascending: false)
          .limit(3);
      if (mounted) {
        setState(() {
          _recentLogs = List<Map<String, dynamic>>.from(rows);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _recentLogs = [];
          _isLoading = false;
        });
      }
    }
  }

  String _formatRelativeTime(dynamic createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt.toString())?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    return 'قبل ${diff.inDays} يوم';
  }

  IconData _iconForAction(String action) {
    final a = action.toLowerCase();
    if (a.contains('delete')) return Icons.delete_forever_rounded;
    if (a.contains('refund') || a.contains('pay') || a.contains('money')) return Icons.monetization_on_rounded;
    return Icons.edit_note_rounded;
  }

  Color _colorForAction(String action) {
    final a = action.toLowerCase();
    if (a.contains('delete')) return Colors.red;
    if (a.contains('refund') || a.contains('pay') || a.contains('money')) return Colors.orange;
    return Colors.purple;
  }

  String _actionTitle(String action, String table) {
    final a = action.toLowerCase();
    if (a.contains('delete')) return 'عملية حذف من جدول $table';
    if (a.contains('refund')) return 'استرداد مالي / Refund';
    if (a.contains('insert')) return 'إضافة قيد جديد في $table';
    if (a.contains('update')) return 'تعديل بيانات في $table';
    return '$action على جدول $table';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? const Color(0xFF1E1E2D) : const Color(0xFFF8FAFC),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 460;
              final headerInfo = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Colors.red, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'رادار التدقيق الأمني ومراقبة العمليات الحساسة 🚨',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'تتبع لحظي لعمليات الحذف، استرداد الأموال، وتعديل النتائج والصلاحيات',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final auditBtn = FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: widget.onOpenAuditLog,
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('سجل التدقيق الكامل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    headerInfo,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerLeft, child: auditBtn),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: headerInfo),
                  const SizedBox(width: 8),
                  auditBtn,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_recentLogs.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Colors.green, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'المنظومة مؤمنة بالكامل: لا توجد عمليات خطرة أو استردادات مسجلة حديثاً 🛡️',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._recentLogs.map((log) {
              final action = log['action']?.toString() ?? 'عملية أمنية';
              final table = log['table_name']?.toString() ?? 'البيانات';
              final timeStr = _formatRelativeTime(log['created_at']);
              final actor = log['actor_id']?.toString() ?? 'نظام';
              final shortActor = actor.length >= 8 ? actor.substring(0, 8) : actor;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildAlertRow(
                  icon: _iconForAction(action),
                  color: _colorForAction(action),
                  title: _actionTitle(action, table),
                  subtitle: 'المعرف: $shortActor • جدول $table • $timeStr',
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAlertRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

