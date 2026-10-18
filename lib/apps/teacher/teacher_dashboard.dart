import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/di/injection.dart';
import '../../core/error/supabase_error_handler.dart';
import '../../core/network/supabase_client_wrapper.dart';
import '../../design_system/tokens/colors.dart';
import '../../features/academy/data/repositories/supabase_academy_repositories.dart';
import '../../features/academy/domain/models/academy_models.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/communication/domain/models/notification.dart';
import '../../features/communication/domain/repositories/i_notification_repository.dart';
import '../../features/communication/presentation/viewmodels/notification_center_viewmodel.dart';
import 'tabs/home_tab.dart';
import 'tabs/classes_tab.dart';
import 'tabs/workspace_tab.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/notifications_tab.dart';
import 'tabs/account_tab.dart';
import '../../core/localization/app_localizations.dart';

class TeacherDashboard extends StatefulWidget {
  final AuthViewModel authViewModel;

  const TeacherDashboard({super.key, required this.authViewModel});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<GroupEntity> _assignedGroups = [];
  int _openHomeworkCount = 0;
  int _publishedExamsCount = 0;
  int _gradingQueueCount = 0;
  int _todaySessionsCount = 0;
  int _savedBoardCount = 0;
  List<TeacherGroupAnalytics> _groupAnalytics = [];
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription<AppNotification>? _notificationSubscription;
  late final NotificationCenterViewModel _notificationCenterViewModel;

  int get unreadCount => _unreadCount;
  List<AppNotification> get notifications => _notifications;

  @override
  void initState() {
    super.initState();
    _notificationCenterViewModel = NotificationCenterViewModel(
      getIt<INotificationRepository>(),
    );
    _notificationCenterViewModel.addListener(_syncNotificationCenterState);
    _subscribeToNotifications();
    _loadTeacherMetrics();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _notificationCenterViewModel.removeListener(_syncNotificationCenterState);
    _notificationCenterViewModel.dispose();
    super.dispose();
  }

  void _syncNotificationCenterState() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _notifications = _notificationCenterViewModel.notifications;
        _unreadCount = _notificationCenterViewModel.unreadCount;
      });
    });
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
          onError: (error) {
            debugPrint('Notification stream error caught: $error');
          },
        );
  }

  Future<void> _loadTeacherMetrics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final teacherRepo = SupabaseTeacherRepository(wrapper);
      final teacherId = widget.authViewModel.bootstrap?.teacherId;
      final profileId = widget.authViewModel.currentUser?.id;

      if (teacherId == null || profileId == null) {
        throw Exception(
          'Teacher account is missing its linked teacher profile. Contact an admin to complete provisioning.',
        );
      }

      final notificationRepo = getIt<INotificationRepository>();
      final initialNotifications = await notificationRepo
          .getNotifications()
          .catchError((_) => <AppNotification>[]);
      final initialUnreadCount = await notificationRepo
          .getUnreadCount()
          .catchError((_) => 0);

      final groups = await teacherRepo.fetchAssignedGroups(teacherId);
      final hwRes = await Supabase.instance.client
          .from('homework')
          .select('id')
          .eq('assigned_by', profileId);
      final exRes = await Supabase.instance.client
          .from('exams')
          .select('id')
          .eq('created_by', profileId);
      final gradingQueue = await _safeList(
        () => Supabase.instance.client.rpc(
          'get_teacher_grading_queue',
          params: {'p_teacher_id': teacherId},
        ),
      );
      final groupIds = groups.map((group) => group.id).toList();
      final today = DateTime.now().toIso8601String().split('T').first;
      final todaySessions = groupIds.isEmpty
          ? <dynamic>[]
          : await _safeList(
              () => Supabase.instance.client
                  .from('class_sessions')
                  .select('id')
                  .inFilter('group_id', groupIds)
                  .eq('session_date', today),
            );
      final savedBoards = await _safeList(
        () => Supabase.instance.client
            .from('class_session_boards')
            .select('id')
            .eq('teacher_id', teacherId),
      );
      final analytics = await _safeList(
        () =>
            Supabase.instance.client.rpc('get_current_teacher_group_analytics'),
      );

      if (mounted) {
        setState(() {
          _assignedGroups = groups;
          _openHomeworkCount = (hwRes as List).length;
          _publishedExamsCount = (exRes as List).length;
          _gradingQueueCount = gradingQueue.length;
          _todaySessionsCount = todaySessions.length;
          _savedBoardCount = savedBoards.length;
          _groupAnalytics = analytics
              .whereType<Map>()
              .map(TeacherGroupAnalytics.fromJson)
              .toList();
          _notifications = initialNotifications;
          _unreadCount = initialUnreadCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = SupabaseErrorHandler.parseError(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<List<dynamic>> _safeList(Future<dynamic> Function() query) async {
    try {
      final result = await query();
      return result is List ? result : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }

  void _openNotification(AppNotification notification) {
    unawaited(_notificationCenterViewModel.markRead(notification.id));
    final targetIndex = _teacherNotificationTargetIndex(notification.type);
    if (targetIndex != null) {
      setState(() => _selectedIndex = targetIndex);
    }
  }

  int? _teacherNotificationTargetIndex(String type) {
    final normalized = type.toLowerCase();
    if (normalized.contains('payment') ||
        normalized.contains('invoice') ||
        normalized.contains('receipt') ||
        normalized.contains('report') ||
        normalized.contains('analytics')) {
      return 3;
    }
    if (normalized.contains('exam') ||
        normalized.contains('homework') ||
        normalized.contains('grading') ||
        normalized.contains('submission') ||
        normalized.contains('solution') ||
        normalized.contains('reset') ||
        normalized.contains('retake') ||
        normalized.contains('board') ||
        normalized.contains('workspace')) {
      return 2;
    }
    if (normalized.contains('attendance') ||
        normalized.contains('session') ||
        normalized.contains('group') ||
        normalized.contains('class') ||
        normalized.contains('academic')) {
      return 1;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final teacherId = widget.authViewModel.bootstrap?.teacherId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (teacherId == null) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('بوابة المعلم'),
          actions: [
            IconButton(
              tooltip: 'تسجيل الخروج',
              icon: const Icon(Icons.logout),
              onPressed: () => widget.authViewModel.signOut(),
            ),
          ],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'هذا الحساب غير مربوط بملف معلم حتى الآن. برجاء التواصل مع إدارة السنتر لتفعيل صلاحيات التدريس.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final tabs = [
      HomeTab(
        user: widget.authViewModel.currentUser,
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        assignedGroupsCount: _assignedGroups.length,
        openHomeworkCount: _openHomeworkCount,
        publishedExamsCount: _publishedExamsCount,
        gradingQueueCount: _gradingQueueCount,
        todaySessionsCount: _todaySessionsCount,
        savedBoardCount: _savedBoardCount,
        groupAnalytics: _groupAnalytics,
        onRetry: _loadTeacherMetrics,
        onNavigate: (i) => setState(() => _selectedIndex = i),
      ),
      ClassesTab(teacherId: teacherId),
      WorkspaceTab(teacherId: teacherId),
      AnalyticsTab(profileId: widget.authViewModel.currentUser!.id),
      TeacherNotificationsTab(
        notifications: _notifications,
        unreadCount: _unreadCount,
        viewModel: _notificationCenterViewModel,
        onNotificationTap: _openNotification,
        onMarkRead: (n) => _notificationCenterViewModel.markRead(n.id),
        onMarkAllRead: () => _notificationCenterViewModel.markAllRead(),
        onRefresh: () async {
          await _loadTeacherMetrics();
          await _notificationCenterViewModel.loadNotifications();
        },
      ),
      AccountTab(teacherId: teacherId, authViewModel: widget.authViewModel),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        final body = SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: tabs[_selectedIndex],
          ),
        );

        if (isWide) {
          return Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: bgColor,
            body: Row(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: NavigationRail(
                            backgroundColor: surfaceColor,
                            selectedIndex: _selectedIndex,
                            onDestinationSelected: (i) =>
                                setState(() => _selectedIndex = i),
                            labelType: NavigationRailLabelType.all,
                            indicatorColor:
                                AppColors.teacherRole.withValues(alpha: 0.12),
                            selectedIconTheme: const IconThemeData(
                              color: AppColors.teacherRole,
                            ),
                            destinations: [
                              NavigationRailDestination(
                                icon: const Icon(Icons.home_outlined),
                                selectedIcon: const Icon(Icons.home_rounded),
                                label: Text(context.tr('الرئيسية')),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.groups_2_outlined),
                                selectedIcon: const Icon(Icons.groups_2_rounded),
                                label: Text(context.tr('المجموعات')),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.dashboard_customize_outlined),
                                selectedIcon: const Icon(
                                  Icons.dashboard_customize_rounded,
                                ),
                                label: Text(context.tr('مساحة العمل')),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.insights_outlined),
                                selectedIcon: const Icon(Icons.insights_rounded),
                                label: Text(context.tr('التقارير')),
                              ),
                              NavigationRailDestination(
                                icon: Badge(
                                  isLabelVisible: _unreadCount > 0,
                                  label: Text(
                                    _unreadCount > 9 ? '9+' : '$_unreadCount',
                                  ),
                                  child: const Icon(
                                    Icons.notifications_none_rounded,
                                  ),
                                ),
                                selectedIcon:
                                    const Icon(Icons.notifications_rounded),
                                label: Text(context.tr('الإشعارات')),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.person_outline_rounded),
                                selectedIcon: const Icon(Icons.person_rounded),
                                label: Text(context.tr('حسابي')),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                VerticalDivider(thickness: 1, width: 1, color: borderColor),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: bgColor,
          body: body,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(top: BorderSide(color: borderColor, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.teacherRole,
                      );
                    }
                    return TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    );
                  }),
                ),
                child: NavigationBar(
                  height: 64,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  indicatorColor: AppColors.teacherRole.withValues(alpha: 0.16),
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _selectedIndex = i),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.home_outlined, size: 21),
                      selectedIcon: const Icon(
                        Icons.home_rounded,
                        color: AppColors.teacherRole,
                        size: 21,
                      ),
                      label: context.tr('الرئيسية'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.groups_2_outlined, size: 21),
                      selectedIcon: const Icon(
                        Icons.groups_2_rounded,
                        color: AppColors.teacherRole,
                        size: 21,
                      ),
                      label: context.tr('المجموعات'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.dashboard_customize_outlined, size: 21),
                      selectedIcon: const Icon(
                        Icons.dashboard_customize_rounded,
                        color: AppColors.teacherRole,
                        size: 21,
                      ),
                      label: context.tr('مساحة العمل'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.insights_outlined, size: 21),
                      selectedIcon: const Icon(
                        Icons.insights_rounded,
                        color: AppColors.teacherRole,
                        size: 21,
                      ),
                      label: context.tr('التقارير'),
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: _unreadCount > 0,
                        label: Text(_unreadCount > 9 ? '9+' : '$_unreadCount'),
                        child: const Icon(Icons.notifications_none_rounded, size: 21),
                      ),
                      selectedIcon: const Icon(
                        Icons.notifications_rounded,
                        color: AppColors.teacherRole,
                        size: 21,
                      ),
                      label: context.tr('الإشعارات'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.person_outline_rounded, size: 21),
                      selectedIcon: const Icon(
                        Icons.person_rounded,
                        color: AppColors.teacherRole,
                        size: 21,
                      ),
                      label: context.tr('حسابي'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class TeacherGroupAnalytics {
  final String? groupId;
  final String groupName;
  final String groupCode;
  final int studentCount;
  final int completedSessions;
  final double attendanceRate;
  final int absentCount;
  final int pendingHomeworkCount;
  final double averageExamScore;

  const TeacherGroupAnalytics({
    this.groupId,
    required this.groupName,
    required this.groupCode,
    required this.studentCount,
    required this.completedSessions,
    required this.attendanceRate,
    required this.absentCount,
    required this.pendingHomeworkCount,
    required this.averageExamScore,
  });

  factory TeacherGroupAnalytics.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return TeacherGroupAnalytics(
      groupId: json['group_id']?.toString(),
      groupName: json['group_name']?.toString() ?? 'المجموعة الدراسية',
      groupCode: json['group_code']?.toString() ?? '',
      studentCount: (json['student_count'] as num?)?.round() ?? 0,
      completedSessions: (json['completed_sessions'] as num?)?.round() ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0,
      absentCount: (json['absent_count'] as num?)?.round() ?? 0,
      pendingHomeworkCount:
          (json['pending_homework_count'] as num?)?.round() ?? 0,
      averageExamScore: (json['average_exam_score'] as num?)?.toDouble() ?? 0,
    );
  }
}
