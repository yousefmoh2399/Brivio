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

  // Filter controllers for sessions tab
  final TextEditingController _sessionSearchController = TextEditingController();
  String _selectedSessionStatusFilter = 'all'; // all, scheduled, in_progress, completed, cancelled

  // Filter controllers for leave requests tab
  final TextEditingController _leaveSearchController = TextEditingController();
  String _selectedLeaveStatusFilter = 'all'; // all, pending, approved, rejected

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

  @override
  void dispose() {
    _sessionSearchController.dispose();
    _leaveSearchController.dispose();
    super.dispose();
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
          title: Row(
            children: [
              const Icon(Icons.add_circle_outline_rounded, color: AppColors.adminRole),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'إضافة حصة (${selectedGroup.name})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width.clamp(280.0, 500.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تاريخ الحصة:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
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
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                              icon: const Icon(Icons.access_time_rounded, size: 18),
                              label: Text(
                                startTime.format(context),
                                style: const TextStyle(fontSize: 12),
                              ),
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
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                              icon: const Icon(Icons.access_time_filled_rounded, size: 18),
                              label: Text(
                                endTime.format(context),
                                style: const TextStyle(fontSize: 12),
                              ),
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
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width.clamp(280.0, 560.0),
            child: FutureBuilder<List<dynamic>>(
              future: Future.wait([
                _studentRepo.fetchStudentsForGroup(session.groupId),
                _attendanceRepo
                    .fetchAttendanceForSession(session.id)
                    .catchError((_) => <AttendanceRecord>[]),
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
                final existingRecords =
                    (snapshot.data?[1] as List<AttendanceRecord>?) ?? [];

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
                    final existing = existingRecords
                        .where((r) => r.studentId == student.id)
                        .firstOrNull;
                    if (existing != null) {
                      statuses[student.id] =
                          existing.attendanceStatus.toDbValue();
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

                final presentCount =
                    statuses.values.where((v) => v == 'present').length;
                final absentCount =
                    statuses.values.where((v) => v == 'absent').length;
                final lateCount =
                    statuses.values.where((v) => v == 'late').length;
                final excusedCount =
                    statuses.values.where((v) => v == 'excused').length;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Summary and bulk action bar
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildCounterBadge('حاضر: $presentCount', Colors.green),
                              _buildCounterBadge('متأخر: $lateCount', Colors.amber),
                              _buildCounterBadge('غائب: $absentCount', Colors.red),
                              _buildCounterBadge('بعذر: $excusedCount', Colors.blue),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
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
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setStateDialog(() {
                                    for (final s in students) {
                                      statuses[s.id] = 'absent';
                                    }
                                  });
                                },
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('غياب الكل', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Quick Search Bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'بحث باسم الطالب أو الكود...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        suffixIcon: filterQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => setStateDialog(() => filterQuery = ''),
                              )
                            : null,
                      ),
                      onChanged: (v) => setStateDialog(() => filterQuery = v.trim()),
                    ),
                    const SizedBox(height: 10),
                    // Students List
                    SizedBox(
                      height: 320,
                      child: filteredStudents.isEmpty
                          ? const Center(child: Text('لا توجد نتائج مطابقة للبحث.'))
                          : ListView.separated(
                              itemCount: filteredStudents.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final student = filteredStudents[idx];
                                final currentStatus =
                                    statuses[student.id] ?? 'present';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: LayoutBuilder(
                                    builder: (context, itemConstraints) {
                                      final isItemNarrow = itemConstraints.maxWidth < 420;

                                      final studentInfo = Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: AppColors.adminRole
                                                .withValues(alpha: 0.1),
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
                                          Flexible(
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
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );

                                      final statusSelector = Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: [
                                          _StatusChoiceChip(
                                            label: 'حاضر',
                                            isSelected: currentStatus == 'present',
                                            activeColor: Colors.green,
                                            onTap: () => setStateDialog(
                                                () => statuses[student.id] = 'present'),
                                          ),
                                          _StatusChoiceChip(
                                            label: 'متأخر',
                                            isSelected: currentStatus == 'late',
                                            activeColor: Colors.amber,
                                            onTap: () => setStateDialog(
                                                () => statuses[student.id] = 'late'),
                                          ),
                                          _StatusChoiceChip(
                                            label: 'غائب',
                                            isSelected: currentStatus == 'absent',
                                            activeColor: Colors.red,
                                            onTap: () => setStateDialog(
                                                () => statuses[student.id] = 'absent'),
                                          ),
                                          _StatusChoiceChip(
                                            label: 'بعذر',
                                            isSelected: currentStatus == 'excused',
                                            activeColor: Colors.blue,
                                            onTap: () => setStateDialog(
                                                () => statuses[student.id] = 'excused'),
                                          ),
                                        ],
                                      );

                                      if (isItemNarrow) {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            studentInfo,
                                            const SizedBox(height: 6),
                                            statusSelector,
                                          ],
                                        );
                                      }

                                      return Row(
                                        children: [
                                          Expanded(child: studentInfo),
                                          const SizedBox(width: 8),
                                          statusSelector,
                                        ],
                                      );
                                    },
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
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
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

  Widget _buildCounterBadge(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color.shade800,
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
          title: Row(
            children: [
              const Icon(Icons.rule_folder_rounded, color: AppColors.adminRole),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'مراجعة طلب الإجازة / الاستئذان',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width.clamp(280.0, 500.0),
            child: SingleChildScrollView(
              child: Column(
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
                        const SizedBox(height: 8),
                        Text(
                          'تاريخ التقديم: ${_formatDate(leave.submittedAt)}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
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
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            OutlinedButton(
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
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: const Text('رفض الطلب'),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('الموافقة على الطلب'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(DateTime start, DateTime end) {
    final minutes = end.difference(start).inMinutes;
    if (minutes <= 0) return '';
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      if (hours == 1) return 'ساعة واحدة';
      if (hours == 2) return 'ساعتان';
      return '$hours ساعات';
    }
    return '$minutes دقيقة';
  }

  String _sessionStatusLabel(SessionStatus status) {
    return switch (status) {
      SessionStatus.scheduled => 'مجدولة',
      SessionStatus.inProgress => 'جارية الآن',
      SessionStatus.completed => 'مكتملة',
      SessionStatus.cancelled => 'ملغاة',
    };
  }

  Color _sessionStatusColor(SessionStatus status) {
    return switch (status) {
      SessionStatus.scheduled => Colors.blue,
      SessionStatus.inProgress => Colors.orange,
      SessionStatus.completed => Colors.green,
      SessionStatus.cancelled => Colors.grey,
    };
  }

  IconData _sessionStatusIcon(SessionStatus status) {
    return switch (status) {
      SessionStatus.scheduled => Icons.schedule_rounded,
      SessionStatus.inProgress => Icons.play_circle_filled_rounded,
      SessionStatus.completed => Icons.check_circle_rounded,
      SessionStatus.cancelled => Icons.cancel_rounded,
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

  Color _leaveStatusColor(String status) {
    return switch (status.toLowerCase()) {
      'pending' => Colors.orange,
      'approved' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.grey,
    };
  }

  IconData _leaveStatusIcon(String status) {
    return switch (status.toLowerCase()) {
      'pending' => Icons.hourglass_top_rounded,
      'approved' => Icons.check_circle_outline_rounded,
      'rejected' => Icons.cancel_outlined,
      _ => Icons.help_outline_rounded,
    };
  }

  Widget _buildKpiSection() {
    final totalSessions = _sessions.length;
    final completedSessions = _sessions
        .where((s) => s.status == SessionStatus.completed)
        .length;
    final activeSessions = _sessions
        .where(
          (s) =>
              s.status == SessionStatus.scheduled ||
              s.status == SessionStatus.inProgress,
        )
        .length;
    final pendingLeaves =
        _leaveRequests.where((l) => l.status.toLowerCase() == 'pending').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;
        final isTablet = constraints.maxWidth >= 500 && !isDesktop;

        final items = [
          _buildKpiCard(
            title: 'إجمالي الحصص',
            value: totalSessions.toString(),
            icon: Icons.event_available_rounded,
            color: Colors.indigo,
            subtitle: _selectedGroup != null ? _selectedGroup!.name : 'كل المجموعات',
          ),
          _buildKpiCard(
            title: 'الحصص المكتملة',
            value: completedSessions.toString(),
            icon: Icons.check_circle_rounded,
            color: Colors.green,
            subtitle: 'تم رصد الحضور بها',
          ),
          _buildKpiCard(
            title: 'المجدولة والنشطة',
            value: activeSessions.toString(),
            icon: Icons.access_time_filled_rounded,
            color: Colors.amber.shade800,
            subtitle: 'تنتظر الانعقاد أو الرصد',
          ),
          _buildKpiCard(
            title: 'طلبات استئذان معلقة',
            value: pendingLeaves.toString(),
            icon: Icons.pending_actions_rounded,
            color: Colors.deepOrange,
            subtitle: 'تتطلب مراجعة وقرار الإدارة',
          ),
        ];

        if (isDesktop) {
          return Row(
            children: items
                .map((widget) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: widget,
                      ),
                    ))
                .toList(),
          );
        } else if (isTablet) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: items[0]),
                  const SizedBox(width: 8),
                  Expanded(child: items[1]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: items[2]),
                  const SizedBox(width: 8),
                  Expanded(child: items[3]),
                ],
              ),
            ],
          );
        } else {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: items[0]),
                  const SizedBox(width: 8),
                  Expanded(child: items[1]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: items[2]),
                  const SizedBox(width: 8),
                  Expanded(child: items[3]),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingLeavesCount =
        _leaveRequests.where((l) => l.status.toLowerCase() == 'pending').length;

    return DefaultTabController(
      length: 2,
      child: PortalPageShell(
        title: 'عمليات وإدارة الحضور',
        subtitle:
            'متابعة الحصص الدراسية، تسجيل كشوفات الحضور والغياب، ومراجعة طلبات الإجازة والاستئذان.',
        icon: Icons.event_note_rounded,
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
            icon: Icons.refresh_rounded,
            label: 'تحديث',
            onPressed: _loadData,
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildKpiSection(),
            const SizedBox(height: 14),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                const Tab(
                  icon: Icon(Icons.event_note_rounded),
                  text: 'الحصص ورصد الحضور',
                ),
                Tab(
                  icon: Badge(
                    isLabelVisible: pendingLeavesCount > 0,
                    label: Text(pendingLeavesCount.toString()),
                    child: const Icon(Icons.event_busy_rounded),
                  ),
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
                emptyIcon: Icons.event_note_rounded,
                onRetry: _loadData,
                child: TabBarView(
                  children: [
                    _buildSessionsTab(),
                    _buildLeaveRequestsTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsTab() {
    final query = _sessionSearchController.text.trim().toLowerCase();
    final filteredSessions = _sessions.where((s) {
      if (_selectedSessionStatusFilter != 'all') {
        final matchesStatus = switch (_selectedSessionStatusFilter) {
          'scheduled' => s.status == SessionStatus.scheduled,
          'in_progress' => s.status == SessionStatus.inProgress,
          'completed' => s.status == SessionStatus.completed,
          'cancelled' => s.status == SessionStatus.cancelled,
          _ => true,
        };
        if (!matchesStatus) return false;
      }
      if (query.isEmpty) return true;
      final loc = (s.location ?? '').toLowerCase();
      final dateStr = _formatDate(s.sessionDate);
      return loc.contains(query) || dateStr.contains(query);
    }).toList();

    return Column(
      children: [
        // Group Selector & Filters Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_groups.isNotEmpty)
                DropdownButtonFormField<GroupEntity>(
                  initialValue: _selectedGroup,
                  decoration: const InputDecoration(
                    labelText: 'المجموعة الدراسية المختارة',
                    prefixIcon: Icon(Icons.groups_rounded, color: AppColors.adminRole),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;

                  final searchField = TextField(
                    controller: _sessionSearchController,
                    decoration: InputDecoration(
                      hintText: 'بحث بمكان الحصة أو التاريخ...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      suffixIcon: _sessionSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _sessionSearchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  );

                  final filterChips = SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'الكل (${_sessions.length})',
                          isSelected: _selectedSessionStatusFilter == 'all',
                          onSelected: () =>
                              setState(() => _selectedSessionStatusFilter = 'all'),
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          label: 'مجدولة',
                          isSelected: _selectedSessionStatusFilter == 'scheduled',
                          onSelected: () => setState(
                              () => _selectedSessionStatusFilter = 'scheduled'),
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          label: 'جارية',
                          isSelected: _selectedSessionStatusFilter == 'in_progress',
                          onSelected: () => setState(
                              () => _selectedSessionStatusFilter = 'in_progress'),
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          label: 'مكتملة',
                          isSelected: _selectedSessionStatusFilter == 'completed',
                          onSelected: () => setState(
                              () => _selectedSessionStatusFilter = 'completed'),
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          label: 'ملغاة',
                          isSelected: _selectedSessionStatusFilter == 'cancelled',
                          onSelected: () => setState(
                              () => _selectedSessionStatusFilter = 'cancelled'),
                        ),
                      ],
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 8),
                        filterChips,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      Expanded(child: filterChips),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Sessions List / Grid
        Expanded(
          child: _selectedGroup == null
              ? const Center(
                  child: Text('لا توجد مجموعات نشطة حالياً.'),
                )
              : filteredSessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 54,
                            color: Colors.grey.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _sessions.isEmpty
                                ? 'لا توجد حصص مسجلة لهذه المجموعة حتى الآن.'
                                : 'لا توجد حصص مطابقة للفلاتر المحددة.',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_sessions.isEmpty)
                            ElevatedButton.icon(
                              onPressed: _showCreateSessionDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة أول حصة للمجموعة'),
                            ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth > 850;

                        if (isDesktop) {
                          return GridView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              mainAxisExtent: 200,
                            ),
                            itemCount: filteredSessions.length,
                            itemBuilder: (ctx, i) =>
                                _buildSessionCard(filteredSessions[i]),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: filteredSessions.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, i) =>
                              _buildSessionCard(filteredSessions[i]),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSessionCard(ClassSession session) {
    final startTimeStr = _formatTime(session.scheduledStartAt);
    final endTimeStr = _formatTime(session.scheduledEndAt);
    final durationStr = _formatDuration(
      session.scheduledStartAt,
      session.scheduledEndAt,
    );
    final statusColor = _sessionStatusColor(session.status);
    final statusLabel = _sessionStatusLabel(session.status);
    final statusIcon = _sessionStatusIcon(session.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Date & Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.adminRole.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.adminRole,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(session.sessionDate),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      session.location ?? 'القاعة الرئيسية',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Details: Time and duration
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '$startTimeStr - $endTimeStr',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (durationStr.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timelapse_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        durationStr,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Action button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openAttendanceRoster(session),
              icon: const Icon(Icons.how_to_reg_rounded, size: 18),
              label: const Text('رصد واعتماد كشف الحضور'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.comfortable,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestsTab() {
    final query = _leaveSearchController.text.trim().toLowerCase();
    final filteredLeaves = _leaveRequests.where((l) {
      if (_selectedLeaveStatusFilter != 'all') {
        if (l.status.toLowerCase() != _selectedLeaveStatusFilter) return false;
      }
      if (query.isEmpty) return true;
      final reason = l.reason.toLowerCase();
      final reviewerNote = (l.reviewerNote ?? '').toLowerCase();
      final studentId = l.studentId.toLowerCase();
      return reason.contains(query) ||
          reviewerNote.contains(query) ||
          studentId.contains(query);
    }).toList();

    return Column(
      children: [
        // Search & Filter Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;

              final searchField = TextField(
                controller: _leaveSearchController,
                decoration: InputDecoration(
                  hintText: 'بحث في أسباب الاستئذان أو كود الطالب...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  suffixIcon: _leaveSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _leaveSearchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              );

              final filterChips = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'الكل (${_leaveRequests.length})',
                      isSelected: _selectedLeaveStatusFilter == 'all',
                      onSelected: () =>
                          setState(() => _selectedLeaveStatusFilter = 'all'),
                    ),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      label: 'قيد المراجعة',
                      isSelected: _selectedLeaveStatusFilter == 'pending',
                      onSelected: () =>
                          setState(() => _selectedLeaveStatusFilter = 'pending'),
                    ),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      label: 'مقبولة',
                      isSelected: _selectedLeaveStatusFilter == 'approved',
                      onSelected: () =>
                          setState(() => _selectedLeaveStatusFilter = 'approved'),
                    ),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      label: 'مرفوضة',
                      isSelected: _selectedLeaveStatusFilter == 'rejected',
                      onSelected: () =>
                          setState(() => _selectedLeaveStatusFilter = 'rejected'),
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    filterChips,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  Expanded(child: filterChips),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Requests List / Grid
        Expanded(
          child: filteredLeaves.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.rule_folder_outlined,
                        size: 54,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'لا توجد طلبات إجازة أو استئذان مطابقة.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 850;

                    if (isDesktop) {
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 220,
                        ),
                        itemCount: filteredLeaves.length,
                        itemBuilder: (ctx, i) =>
                            _buildLeaveRequestCard(filteredLeaves[i]),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: filteredLeaves.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) =>
                          _buildLeaveRequestCard(filteredLeaves[i]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLeaveRequestCard(LeaveRequest leave) {
    final statusColor = _leaveStatusColor(leave.status);
    final statusLabel = _leaveStatusLabel(leave.status);
    final statusIcon = _leaveStatusIcon(leave.status);
    final dateStr = _formatDate(leave.submittedAt);
    final isPending = leave.status.toLowerCase() == 'pending';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Date & Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'طلب إجازة / استئذان',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'تاريخ التقديم: $dateStr',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Reason content box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              leave.reason.isEmpty ? 'لا توجد تفاصيل مرفقة' : leave.reason,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (leave.reviewerNote != null && leave.reviewerNote!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'ملاحظة المراجع: ${leave.reviewerNote}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 8),
          // Actions
          if (isPending)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showReviewLeaveDialog(leave),
                icon: const Icon(Icons.gavel_rounded, size: 16),
                label: const Text('مراجعة واتخاذ القرار'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.adminRole,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'تم البت في هذا الطلب ($statusLabel)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: AppColors.adminRole,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
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
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : Colors.transparent,
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
