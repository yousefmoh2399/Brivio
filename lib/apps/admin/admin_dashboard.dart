import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/di/injection.dart';
import '../../core/network/supabase_client_wrapper.dart';
import '../../core/settings/app_settings_screen.dart';
import '../../design_system/components/glass_card.dart';
import '../../design_system/tokens/colors.dart';
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

  Future<Map<String, dynamic>> _fetchTodayTreasuryCollections() async {
    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final startOfDay = '$todayStr 00:00:00';
      final endOfDay = '$todayStr 23:59:59';

      final res = await Supabase.instance.client
          .from('receipts')
          .select('amount_minor')
          .gte('issued_at', startOfDay)
          .lte('issued_at', endOfDay);

      double sum = 0.0;
      int count = 0;
      for (final row in res) {
        sum += ((row['amount_minor'] as num? ?? 0) / 100.0);
        count++;
      }
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

      final results = await Future.wait([
        studentRepo.fetchStudents().catchError(
          (_) => const PaginatedResult<Student>(
            total: 0,
            page: 1,
            pageSize: 20,
            data: [],
          ),
        ),
        parentRepo.fetchParents().catchError(
          (_) => const PaginatedResult<Parent>(
            total: 0,
            page: 1,
            pageSize: 20,
            data: [],
          ),
        ),
        teacherRepo.fetchTeachers().catchError(
          (_) => const PaginatedResult<Teacher>(
            total: 0,
            page: 1,
            pageSize: 20,
            data: [],
          ),
        ),
        branchRepo.fetchBranches().catchError((_) => <Branch>[]),
        subjectRepo.fetchSubjects().catchError((_) => <SubjectEntity>[]),
        groupRepo.fetchGroups().catchError((_) => <GroupEntity>[]),
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
        _fetchTodayTreasuryCollections(),
      ]);

      if (!mounted) return;
      setState(() {
        final studentResult = results[0] as PaginatedResult<Student>;
        _students = studentResult.data;
        _studentTotal = studentResult.total;

        final parentResult = results[1] as PaginatedResult<Parent>;
        _parents = parentResult.data;
        _parentTotal = parentResult.total;

        final teacherResult = results[2] as PaginatedResult<Teacher>;
        _teachers = teacherResult.data;
        _teacherTotal = teacherResult.total;

        _branches = results[3] as List<Branch>;
        _subjects = results[4] as List<SubjectEntity>;
        _groups = results[5] as List<GroupEntity>;
        _summary = results[6] as AcademyCoreSummary;
        _opsMetrics = results[7] as _AdminOpsMetrics;
        _recentActivity = results[8] as List<_AdminActivityItem>;
        _notifications = results[9] as List<AppNotification>;
        _unreadCount = results[10] as int;

        final sysSummary = results[11] as SystemFinancialSummary;
        _treasuryTotalCollected = sysSummary.totalCollectedMinor / 100.0;
        _treasuryPendingInvoices = sysSummary.totalOutstandingMinor / 100.0;

        final todayFin = results[12] as Map<String, dynamic>;
        _treasuryTodayCollected =
            (todayFin['todayCollected'] as num?)?.toDouble() ?? 0.0;
        _treasuryReceiptsCount =
            (todayFin['todayCount'] as num?)?.toInt() ?? 0;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
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

    final studentCount = summary?.activeStudents != null && summary!.activeStudents > 0
        ? summary!.activeStudents
        : (studentTotal > 0 ? studentTotal : students.length);
    final teacherCount = summary?.activeTeachers != null && summary!.activeTeachers > 0
        ? summary!.activeTeachers
        : (teacherTotal > 0 ? teacherTotal : teachers.length);
    final groupCount = summary?.activeGroups != null && summary!.activeGroups > 0
        ? summary!.activeGroups
        : groups.length;
    final parentCount = parentTotal > 0 ? parentTotal : parents.length;

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
    final branchName = branches.where((b) => b.id == user?.branchId).firstOrNull?.name ??
        (user?.branchId != null && (user!.branchId as String).length < 15 ? (user!.branchId as String) : 'الفرع الرئيسي');

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

          // Main Greeting
          Text(
            'أهلاً بك، ${user?.fullName ?? "مدير المنظومة"} 👋',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${authViewModel.userRole?.displayName ?? "إدارة السنتر العليا"} • $branchName',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
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
