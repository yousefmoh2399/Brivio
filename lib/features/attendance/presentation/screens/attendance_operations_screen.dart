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
          .order('submitted_at', ascending: false)
          .limit(50);
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

  void _showCreateSessionDialog() {
    final selectedGroup = _selectedGroup;
    if (selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار مجموعة دراسية أولاً.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    DateTime sessionDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 16, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);
    final locationCtrl = TextEditingController(text: 'القاعة الرئيسية');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('إضافة حصة جديدة (${selectedGroup.name})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تاريخ الحصة:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: sessionDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 180)),
                    );
                    if (picked != null) {
                      setStateDialog(() => sessionDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(
                    '${sessionDate.year}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'وقت البدء:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: startTime,
                              );
                              if (picked != null) {
                                setStateDialog(() => startTime = picked);
                              }
                            },
                            icon: const Icon(Icons.access_time_rounded),
                            label: Text(startTime.format(context)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'وقت الانتهاء:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: endTime,
                              );
                              if (picked != null) {
                                setStateDialog(() => endTime = picked);
                              }
                            },
                            icon: const Icon(Icons.access_time_filled_rounded),
                            label: Text(endTime.format(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'مكان انعقاد الحصة / رقم القاعة',
                    prefixIcon: Icon(Icons.room_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setStateDialog(() => isSaving = true);
                      final nav = Navigator.of(ctx);

                      final startDateTime = DateTime(
                        sessionDate.year,
                        sessionDate.month,
                        sessionDate.day,
                        startTime.hour,
                        startTime.minute,
                      );
                      final endDateTime = DateTime(
                        sessionDate.year,
                        sessionDate.month,
                        sessionDate.day,
                        endTime.hour,
                        endTime.minute,
                      );

                      if (endDateTime.isBefore(startDateTime) ||
                          endDateTime.isAtSameMomentAs(startDateTime)) {
                        setStateDialog(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يجب أن يكون وقت الانتهاء بعد وقت البدء.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      try {
                        final newSession = ClassSession(
                          id: '',
                          groupId: selectedGroup.id,
                          sessionDate: sessionDate,
                          scheduledStartAt: startDateTime,
                          scheduledEndAt: endDateTime,
                          status: SessionStatus.scheduled,
                          location: locationCtrl.text.trim().isEmpty
                              ? null
                              : locationCtrl.text.trim(),
                        );
                        await _sessionRepo.createClassSession(newSession);
                        nav.pop();
                        _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم جدولة وإضافة الحصة بنجاح!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل إضافة الحصة: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('جدولة الحصة'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAttendanceRoster(ClassSession session) {
    final statuses = <String, String>{};
    String filterQuery = '';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.how_to_reg_rounded, color: AppColors.adminRole),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'كشف حضور الحصة (${session.sessionDate.year}-${session.sessionDate.month.toString().padLeft(2, '0')}-${session.sessionDate.day.toString().padLeft(2, '0')})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SizedBox(
              width: double.maxFinite,
              child: FutureBuilder<List<dynamic>>(
              future: Future.wait([
                _studentRepo.fetchStudentsForGroup(session.groupId),
                _attendanceRepo.fetchAttendanceForSession(session.id).catchError((_) => <AttendanceRecord>[]),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('فشل تحميل قائمة الطلاب: ${snapshot.error}'),
                  );
                }
                final students = (snapshot.data?[0] as List<Student>?) ?? [];
                final existingRecords = (snapshot.data?[1] as List<AttendanceRecord>?) ?? [];

                if (students.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('لا يوجد طلاب مسجلون في هذه المجموعة حالياً.'),
                    ),
                  );
                }

                // Initialize records once
                for (final student in students) {
                  if (!statuses.containsKey(student.id)) {
                    final existing = existingRecords.where((r) => r.studentId == student.id).firstOrNull;
                    if (existing != null) {
                      statuses[student.id] = existing.attendanceStatus.toDbValue();
                    } else {
                      statuses[student.id] = 'present';
                    }
                  }
                }

                final filteredStudents = students.where((s) {
                  if (filterQuery.isEmpty) return true;
                  final q = filterQuery.toLowerCase();
                  return s.fullName.toLowerCase().contains(q) ||
                      s.studentCode.toLowerCase().contains(q);
                }).toList();

                final presentCount = statuses.values.where((v) => v == 'present').length;
                final absentCount = statuses.values.where((v) => v == 'absent').length;
                final lateCount = statuses.values.where((v) => v == 'late').length;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Summary and bulk action bar
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              children: [
                                Chip(
                                  label: Text('حاضر: $presentCount', style: const TextStyle(fontSize: 11)),
                                  backgroundColor: Colors.green.withValues(alpha: 0.15),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Chip(
                                  label: Text('متأخر: $lateCount', style: const TextStyle(fontSize: 11)),
                                  backgroundColor: Colors.amber.withValues(alpha: 0.15),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Chip(
                                  label: Text('غائب: $absentCount', style: const TextStyle(fontSize: 11)),
                                  backgroundColor: Colors.red.withValues(alpha: 0.15),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              setStateDialog(() {
                                for (final s in students) {
                                  statuses[s.id] = 'present';
                                }
                              });
                            },
                            icon: const Icon(Icons.done_all_rounded, size: 16),
                            label: const Text('تحضير الكل', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Quick Search Bar
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'بحث باسم الطالب أو الكود...',
                        prefixIcon: Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                      ),
                      onChanged: (v) => setStateDialog(() => filterQuery = v.trim()),
                    ),
                    const SizedBox(height: 10),
                    // Students List
                    SizedBox(
                      height: 340,
                      child: filteredStudents.isEmpty
                          ? const Center(child: Text('لا توجد نتائج مطابقة للبحث.'))
                          : ListView.separated(
                              itemCount: filteredStudents.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final student = filteredStudents[idx];
                                final currentStatus = statuses[student.id] ?? 'present';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppColors.adminRole.withValues(alpha: 0.1),
                                        child: Text(
                                          student.fullName.isNotEmpty
                                              ? student.fullName.substring(0, 1)
                                              : 'ط',
                                          style: const TextStyle(
                                            color: AppColors.adminRole,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              student.fullName.isEmpty
                                                  ? 'طالب #${student.studentCode}'
                                                  : student.fullName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'كود: ${student.studentCode}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Status segmented pills
                                      Wrap(
                                        spacing: 4,
                                        children: [
                                          _StatusChoiceChip(
                                            label: 'حاضر',
                                            isSelected: currentStatus == 'present',
                                            activeColor: Colors.green,
                                            onTap: () => setStateDialog(() => statuses[student.id] = 'present'),
                                          ),
                                          _StatusChoiceChip(
                                            label: 'متأخر',
                                            isSelected: currentStatus == 'late',
                                            activeColor: Colors.amber,
                                            onTap: () => setStateDialog(() => statuses[student.id] = 'late'),
                                          ),
                                          _StatusChoiceChip(
                                            label: 'غائب',
                                            isSelected: currentStatus == 'absent',
                                            activeColor: Colors.red,
                                            onTap: () => setStateDialog(() => statuses[student.id] = 'absent'),
                                          ),
                                          _StatusChoiceChip(
                                            label: 'بعذر',
                                            isSelected: currentStatus == 'excused',
                                            activeColor: Colors.blue,
                                            onTap: () => setStateDialog(() => statuses[student.id] = 'excused'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (statuses.isEmpty) return;
                      setStateDialog(() => isSaving = true);
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم رصد واعتماد كشف الحضور بنجاح!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل رصد الحضور: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ واعتماد الكشف'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewLeaveDialog(LeaveRequest leave) {
    final noteCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('مراجعة طلب الإجازة / الاستئذان'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'سبب الاستئذان:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      leave.reason.isEmpty ? 'لم يتم تقديم تفاصيل' : leave.reason,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة الإدارة والمراجع',
                  hintText: 'اكتب سبباً للقرار أو توجيهاً للطالب...',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: isProcessing
                  ? null
                  : () async {
                      setStateDialog(() => isProcessing = true);
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
                        setStateDialog(() => isProcessing = false);
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
              onPressed: isProcessing
                  ? null
                  : () async {
                      setStateDialog(() => isProcessing = true);
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
                        setStateDialog(() => isProcessing = false);
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
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('الموافقة على الطلب'),
            ),
          ],
        ),
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
        subtitle:
            'متابعة الحصص، رصد كشوفات الحضور، ومراجعة طلبات الإجازات والاستئذان.',
        icon: Icons.event_note,
        accentColor: AppColors.adminRole,
        actions: [
          PortalAction(
            icon: Icons.add_circle_outline_rounded,
            label: 'إضافة حصة جديدة',
            onPressed: _showCreateSessionDialog,
            primary: true,
          ),
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
                                prefixIcon: Icon(Icons.groups_rounded),
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
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.event_busy, size: 48, color: Colors.grey),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'لا توجد حصص مسجلة لهذه المجموعة حتى الآن.',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        onPressed: _showCreateSessionDialog,
                                        icon: const Icon(Icons.add),
                                        label: const Text('إضافة أول حصة للمجموعة'),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: _sessions.length,
                                  separatorBuilder: (ctx, i) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final s = _sessions[i];
                                    final startTimeStr =
                                        '${s.scheduledStartAt.hour.toString().padLeft(2, '0')}:${s.scheduledStartAt.minute.toString().padLeft(2, '0')}';
                                    final endTimeStr =
                                        '${s.scheduledEndAt.hour.toString().padLeft(2, '0')}:${s.scheduledEndAt.minute.toString().padLeft(2, '0')}';

                                    return PortalListCard(
                                      icon: Icons.event_note,
                                      accentColor: AppColors.adminRole,
                                      title: 'حصة: ${s.location ?? "القاعة الرئيسية"}',
                                      subtitle:
                                          'التاريخ: ${s.sessionDate.year}-${s.sessionDate.month.toString().padLeft(2, '0')}-${s.sessionDate.day.toString().padLeft(2, '0')} | التوقيت: $startTimeStr - $endTimeStr\nالحالة: ${_sessionStatusLabel(s.status)}',
                                      trailing: [
                                        FilledButton.icon(
                                          onPressed: () =>
                                              _openAttendanceRoster(s),
                                          icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                                          label: const Text('رصد الحضور'),
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
                              final dateStr =
                                  '${l.submittedAt.year}-${l.submittedAt.month.toString().padLeft(2, '0')}-${l.submittedAt.day.toString().padLeft(2, '0')}';
                              return PortalListCard(
                                icon: Icons.event_busy,
                                accentColor: l.status == 'pending'
                                    ? AppColors.warning
                                    : AppColors.info,
                                title:
                                    'طلب استئذان (${_leaveStatusLabel(l.status)})',
                                subtitle: 'تاريخ التقديم: $dateStr\nالسبب: ${l.reason}${l.reviewerNote?.isNotEmpty == true ? "\nملاحظة المراجع: ${l.reviewerNote}" : ""}',
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

class _StatusChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final MaterialColor activeColor;
  final VoidCallback onTap;

  const _StatusChoiceChip({
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? activeColor.shade800 : null,
          ),
        ),
      ),
    );
  }
}
