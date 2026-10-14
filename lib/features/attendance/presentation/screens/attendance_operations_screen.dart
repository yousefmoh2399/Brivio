import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_attendance_repositories.dart';
import '../../domain/models/attendance_models.dart';
import 'reception_qr_gate_screen.dart';

class AttendanceOperationsScreen extends StatefulWidget {
  const AttendanceOperationsScreen({super.key});

  @override
  State<AttendanceOperationsScreen> createState() =>
      _AttendanceOperationsScreenState();
}

class _AttendanceOperationsScreenState
    extends State<AttendanceOperationsScreen> {
  late final SupabaseClassSessionRepository _sessionRepo;
  late final SupabaseAttendanceRepository _attendanceRepo;
  late final SupabaseLeaveRepository _leaveRepo;
  late final SupabaseGroupRepository _groupRepo;
  late final SupabaseStudentRepository _studentRepo;

  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<ClassSession> _sessions = [];
  List<LeaveRequest> _leaveRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _sessionRepo = SupabaseClassSessionRepository(wrapper);
    _attendanceRepo = SupabaseAttendanceRepository(wrapper);
    _leaveRepo = SupabaseLeaveRepository(wrapper);
    _groupRepo = SupabaseGroupRepository(wrapper);
    _studentRepo = SupabaseStudentRepository(wrapper);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _groupRepo.fetchGroups(status: 'active');
      final selected = _selectedGroup ?? (groups.isEmpty ? null : groups.first);
      final s = selected == null
          ? <ClassSession>[]
          : await _sessionRepo.fetchSessionsForGroup(selected.id);
      final rawLeaves = await Supabase.instance.client
          .from('leave_requests')
          .select()
          .order('submitted_at', ascending: false);
      final leaves = (rawLeaves as List)
          .map((j) => LeaveRequest.fromJson(j as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _groups = groups;
          _selectedGroup = selected;
          _sessions = s;
          _leaveRequests = leaves;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _openAttendanceRoster(ClassSession session) {
    final statuses = <String, String>{};
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(
            'كشف حضور الحصة (${session.sessionDate.year}-${session.sessionDate.month.toString().padLeft(2, '0')}-${session.sessionDate.day.toString().padLeft(2, '0')})',
          ),
          content: SizedBox(
            width: 420,
            child: FutureBuilder<List<Student>>(
              future: _studentRepo.fetchStudentsForGroup(session.groupId),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Text('فشل تحميل قائمة الطلاب: ${snapshot.error}');
                }
                final students = snapshot.data ?? [];
                if (students.isEmpty) {
                  return const Text('لا يوجد طلاب مسجلون في هذه المجموعة.');
                }
                for (final student in students) {
                  statuses.putIfAbsent(student.id, () => 'present');
                }
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: students
                        .map(
                          (student) => DropdownButtonFormField<String>(
                            initialValue: statuses[student.id],
                            decoration: InputDecoration(
                              labelText: student.fullName.isEmpty
                                  ? student.studentCode
                                  : student.fullName,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'present',
                                child: Text('حاضر'),
                              ),
                              DropdownMenuItem(
                                value: 'late',
                                child: Text('متأخر'),
                              ),
                              DropdownMenuItem(
                                value: 'absent',
                                child: Text('غائب'),
                              ),
                              DropdownMenuItem(
                                value: 'excused',
                                child: Text('غياب بعذر'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setStateDialog(() => statuses[student.id] = value);
                            },
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (statuses.isEmpty) return;
                final nav = Navigator.of(ctx);
                try {
                  await _attendanceRepo.markSessionAttendance(
                    sessionId: session.id,
                    records: statuses.entries
                        .map(
                          (entry) => {
                            'student_id': entry.key,
                            'attendance_status': entry.value,
                          },
                        )
                        .toList(),
                  );
                  nav.pop();
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('تم رصد واعتماد كشف الحضور بنجاح!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('فشل رصد الحضور: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('حفظ كشف الحضور'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewLeaveDialog(LeaveRequest leave) {
    final noteCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مراجعة طلب الإجازة / الاستئذان'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('السبب: ${leave.reason}'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'ملاحظة الإدارة والمراجع',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await _leaveRepo.reviewLeaveRequest(
                  requestId: leave.id,
                  decision: 'rejected',
                  reviewerNote: noteCtrl.text.trim(),
                );
                nav.pop();
                await _loadData();
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('تم رفض طلب الإجازة.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('فشلت مراجعة الطلب: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'رفض الطلب',
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await _leaveRepo.reviewLeaveRequest(
                  requestId: leave.id,
                  decision: 'approved',
                  reviewerNote: noteCtrl.text.trim(),
                );
                nav.pop();
                await _loadData();
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('تمت الموافقة على طلب الإجازة بنجاح!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('فشلت مراجعة الطلب: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('الموافقة على الطلب'),
          ),
        ],
      ),
    );
  }

  String _sessionStatusLabel(SessionStatus status) {
    return switch (status) {
      SessionStatus.scheduled => 'مجدولة',
      SessionStatus.inProgress => 'جارية الآن',
      SessionStatus.completed => 'مكتملة',
      SessionStatus.cancelled => 'ملغاة',
    };
  }

  String _leaveStatusLabel(String status) {
    return switch (status.toLowerCase()) {
      'pending' => 'معلق بانتظار المراجعة',
      'approved' => 'مقبول',
      'rejected' => 'مرفوض',
      _ => status,
    };
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: PortalPageShell(
        title: 'عمليات وإدارة الحضور',
        subtitle: 'متابعة الحصص، رصد كشوفات الحضور، ومراجعة طلبات الإجازات والاستئذان.',
        icon: Icons.event_note,
        accentColor: AppColors.adminRole,
        actions: [
          PortalAction(
            icon: Icons.qr_code_scanner_rounded,
            label: 'بوابة الاستقبال QR',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ReceptionQrGateScreen(),
                ),
              );
            },
          ),
          PortalAction(
            icon: Icons.refresh,
            label: 'تحديث',
            onPressed: _loadData,
          ),
        ],
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(
                  icon: Icon(Icons.event_note),
                  text: 'الحصص ورصد الحضور',
                ),
                Tab(
                  icon: Icon(Icons.event_busy),
                  text: 'طلبات الاستئذان والإجازات',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PortalStateView(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isEmpty: false,
                emptyTitle: 'لا توجد بيانات حضور',
                emptySubtitle: 'قم بإنشاء المجموعات والحصص أولاً.',
                emptyIcon: Icons.event_note,
                onRetry: _loadData,
                child: TabBarView(
                  children: [
                    Column(
                      children: [
                        if (_groups.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<GroupEntity>(
                              initialValue: _selectedGroup,
                              decoration: const InputDecoration(
                                labelText: 'المجموعة الدراسية',
                              ),
                              items: _groups
                                  .map(
                                    (g) => DropdownMenuItem(
                                      value: g,
                                      child: Text('${g.name} (${g.code})'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (group) {
                                if (group == null) return;
                                setState(() => _selectedGroup = group);
                                _loadData();
                              },
                            ),
                          ),
                        Expanded(
                          child: _selectedGroup == null
                              ? const Center(
                                  child: Text('لا توجد مجموعات نشطة حالياً.'),
                                )
                              : _sessions.isEmpty
                              ? const Center(
                                  child: Text(
                                    'لا توجد حصص مسجلة لهذه المجموعة.',
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: _sessions.length,
                                  separatorBuilder: (ctx, i) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final s = _sessions[i];
                                    return PortalListCard(
                                      icon: Icons.event_note,
                                      accentColor: AppColors.adminRole,
                                      title:
                                          'حصة: ${s.location ?? "القاعة الرئيسية"}',
                                      subtitle:
                                          'التاريخ: ${s.sessionDate.year}-${s.sessionDate.month.toString().padLeft(2, '0')}-${s.sessionDate.day.toString().padLeft(2, '0')} | الحالة: ${_sessionStatusLabel(s.status)}',
                                      trailing: [
                                        FilledButton(
                                          onPressed: () =>
                                              _openAttendanceRoster(s),
                                          child: const Text('رصد الحضور'),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                    _leaveRequests.isEmpty
                        ? const Center(
                            child: Text('لا توجد طلبات إجازة مسجلة.'),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _leaveRequests.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final l = _leaveRequests[i];
                              return PortalListCard(
                                icon: Icons.event_busy,
                                accentColor: l.status == 'pending'
                                    ? AppColors.warning
                                    : AppColors.info,
                                title:
                                    'طلب استئذان (${_leaveStatusLabel(l.status)})',
                                subtitle: 'السبب: ${l.reason}',
                                trailing: [
                                  if (l.status == 'pending')
                                    FilledButton(
                                      onPressed: () =>
                                          _showReviewLeaveDialog(l),
                                      child: const Text('مراجعة الطلب'),
                                    )
                                  else
                                    PortalStatusChip(
                                      status: _leaveStatusLabel(l.status),
                                    ),
                                ],
                              );
                            },
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
