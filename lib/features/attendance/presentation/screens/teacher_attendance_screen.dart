import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_attendance_repositories.dart';
import '../../domain/models/attendance_models.dart';
import 'teacher_session_board_screen.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/components/glass_card.dart';

String _attendanceStatusArabic(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.present:
      return 'حاضر';
    case AttendanceStatus.absent:
      return 'غائب';
    case AttendanceStatus.late:
      return 'متأخر';
    case AttendanceStatus.excused:
      return 'غياب بعذر';
  }
}

String _attendanceStatusStringArabic(String status) {
  switch (status.toLowerCase()) {
    case 'present':
      return 'حاضر';
    case 'absent':
      return 'غائب';
    case 'late':
      return 'متأخر';
    case 'excused':
      return 'بعذر';
    case 'pending':
      return 'قيد الانتظار';
    default:
      return status;
  }
}

String _sessionStatusArabic(SessionStatus status) {
  switch (status) {
    case SessionStatus.scheduled:
      return 'مجدولة';
    case SessionStatus.inProgress:
      return 'جارية الآن';
    case SessionStatus.completed:
      return 'مكتملة ومسجلة';
    case SessionStatus.cancelled:
      return 'ملغاة';
  }
}

class TeacherAttendanceScreen extends StatefulWidget {
  final String teacherId;

  const TeacherAttendanceScreen({super.key, required this.teacherId});

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseStudentRepository _studentRepo;
  late final SupabaseClassSessionRepository _sessionRepo;
  late final SupabaseAttendanceRepository _attendanceRepo;

  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<ClassSession> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _studentRepo = SupabaseStudentRepository(wrapper);
    _sessionRepo = SupabaseClassSessionRepository(wrapper);
    _attendanceRepo = SupabaseAttendanceRepository(wrapper);
    _loadGroupsAndSessions();
  }

  Future<void> _loadGroupsAndSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      GroupEntity? selected;
      if (_selectedGroup == null) {
        selected = groups.isNotEmpty ? groups.first : null;
      } else {
        for (final group in groups) {
          if (group.id == _selectedGroup!.id) {
            selected = group;
            break;
          }
        }
      }
      final sessions = selected == null
          ? <ClassSession>[]
          : await _sessionRepo.fetchSessionsForGroup(selected.id);

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _sessions = sessions;
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

  Future<void> _selectGroup(GroupEntity? group) async {
    setState(() => _selectedGroup = group);
    await _loadGroupsAndSessions();
  }

  Future<void> _openRollCall(ClassSession session) async {
    final roster = await _studentRepo.fetchStudentsForGroup(session.groupId);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (roster.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('لا يوجد طلاب مقيدين في هذه المجموعة.'),
        ),
      );
      return;
    }

    final statuses = {
      for (final student in roster) student.id: AttendanceStatus.present,
    };

    final Map<String, double> studentArrears = {};
    try {
      final studentIds = roster.map((s) => s.id).toList();
      final invoices = await Supabase.instance.client
          .from('invoices')
          .select('student_id, total_amount, paid_amount, status')
          .inFilter('student_id', studentIds);
      for (final inv in (invoices as List)) {
        final sid = inv['student_id']?.toString() ?? '';
        final total = (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
        final paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final remaining = total - paid;
        if (remaining > 0) {
          studentArrears[sid] = (studentArrears[sid] ?? 0.0) + remaining;
        }
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (stateCtx, setStateDialog) => AlertDialog(
          title: Text(
            'تسجيل الحضور: ${session.location ?? "الحصة الدراسية"}',
          ),
          content: SizedBox(
            width: 540,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: roster.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (listCtx, index) {
                final student = roster[index];
                final arrears = studentArrears[student.id] ?? 0.0;
                final isPaid = arrears <= 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isPaid
                                  ? Colors.green.withValues(alpha: 0.3)
                                  : Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            isPaid
                                ? '🟢 مسدد بالكامل'
                                : '🔴 متأخرات: ${arrears.toStringAsFixed(0)} ج.م',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPaid ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<AttendanceStatus>(
                      initialValue: statuses[student.id],
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: AttendanceStatus.values
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(_attendanceStatusArabic(status)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setStateDialog(() => statuses[student.id] = value);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nav = Navigator.of(dialogCtx);
                try {
                  await _attendanceRepo.markSessionAttendance(
                    sessionId: session.id,
                    records: statuses.entries
                        .map(
                          (entry) => {
                            'student_id': entry.key,
                            'attendance_status': entry.value.toDbValue(),
                          },
                        )
                        .toList(),
                  );
                  await _attendanceRepo.finalizeSessionAttendance(session.id);
                  nav.pop();
                  await _loadGroupsAndSessions();
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('تم اعتماد وتأكيد الحضور بنجاح.'),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('فشل اعتماد الحضور: $e'),
                    ),
                  );
                }
              },
              child: const Text('اعتماد الحضور'),
            ),
          ],
        ),
      ),
    );
  }

  void _openQrAttendance(ClassSession session) {
    showDialog(
      context: context,
      builder: (_) => _TeacherAttendanceQrDialog(
        session: session,
        onFinalized: _loadGroupsAndSessions,
      ),
    );
  }

  Future<void> _openRosterDialog(ClassSession session) async {
    final messenger = ScaffoldMessenger.of(context);
    List<AttendanceRosterEntry> roster;
    try {
      roster = await _attendanceRepo.fetchRosterForSession(session.id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('فشل تحميل كشف الحضور: $e')),
      );
      return;
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (stateCtx, setStateDialog) {
          final presentCount = roster.where((entry) => entry.isPresent).length;
          final absentCount = roster.where((entry) => entry.isAbsent).length;
          final checkedOutCount = roster
              .where((entry) => entry.checkOutAt != null)
              .length;

          Future<void> refreshRoster() async {
            final updated = await _attendanceRepo.fetchRosterForSession(
              session.id,
            );
            setStateDialog(() => roster = updated);
          }

          return AlertDialog(
            title: const Text('سجل وكشف الحضور والغياب'),
            content: SizedBox(
              width: 620,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text('حاضر: $presentCount'),
                      ),
                      Chip(
                        label: Text('غائب: $absentCount'),
                      ),
                      Chip(
                        label: Text(
                          'تم تسجيل الخروج: $checkedOutCount',
                        ),
                      ),
                      Chip(
                        label: Text('الإجمالي: ${roster.length}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: roster.isEmpty
                        ? const Center(
                            child: Text('لا يوجد طلاب مقيدين في هذه الحصة.'),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: roster.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final entry = roster[index];
                              final statusLabel =
                                  entry.attendanceStatus?.name ?? 'pending';
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      entry.isPresent
                                          ? Icons.check_circle
                                          : entry.isAbsent
                                          ? Icons.cancel
                                          : Icons.radio_button_unchecked,
                                      color: entry.isPresent
                                          ? Colors.green
                                          : entry.isAbsent
                                          ? Colors.red
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.fullName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              Text(entry.studentCode),
                                              Text(_attendanceStatusStringArabic(statusLabel)),
                                              if (entry.checkInAt != null)
                                                Text(
                                                  'دخول: ${_formatQrTime(entry.checkInAt!)}',
                                                ),
                                              if (entry.checkOutAt != null)
                                                Text(
                                                  'خروج: ${_formatQrTime(entry.checkOutAt!)}',
                                                ),
                                            ],
                                          ),
                                          if (entry.isPresent &&
                                              entry.checkOutAt == null) ...[
                                            const SizedBox(height: 8),
                                            Align(
                                              alignment: AlignmentDirectional
                                                  .centerStart,
                                              child: TextButton.icon(
                                                onPressed: () async {
                                                  try {
                                                    await _attendanceRepo
                                                        .markStudentCheckout(
                                                          sessionId: session.id,
                                                          studentId:
                                                              entry.studentId,
                                                        );
                                                    await refreshRoster();
                                                  } catch (e) {
                                                    if (!mounted) return;
                                                    messenger.showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'فشل تسجيل خروج الطالب: $e',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                                icon: const Icon(Icons.logout),
                                                label: const Text(
                                                  'تسجيل خروج الطالب',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إغلاق'),
              ),
              FilledButton.icon(
                onPressed: refreshRoster,
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GroupPicker(
          groups: _groups,
          selectedGroup: _selectedGroup,
          onChanged: _selectGroup,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadGroupsAndSessions,
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          _ErrorState(message: _errorMessage!, onRetry: _loadGroupsAndSessions),
        ],
      );
    }
    if (_selectedGroup == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Text(
              'لم يتم العثور على مجموعات دراسية مسندة.',
              style: AppTypography.bodyMedium(AppColors.darkTextSecondary),
            ),
          ),
        ],
      );
    }
    if (_sessions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Text(
              'لا توجد حصص دراسية نشطة لهذه المجموعة.',
              style: AppTypography.bodyMedium(AppColors.darkTextSecondary),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length + 1,
      itemBuilder: (ctx, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FilledButton.icon(
              onPressed: _showCreateSessionDialog,
              icon: const Icon(Icons.add),
              label: const Text('إنشاء حصة جديدة'),
            ),
          );
        }

        final i = index - 1;
        final session = _sessions[i];
        final isFinalized = session.status == SessionStatus.completed;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FadeInSlide(
            delay: Duration(milliseconds: 30 * i),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: isFinalized
                        ? AppColors.successSubtle
                        : AppColors.warningSubtle,
                    child: Icon(
                      Icons.event_available,
                      color: isFinalized
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الحصة: ${session.location ?? "القاعة الرئيسية"}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium(
                            AppColors.darkTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'التاريخ: ${session.sessionDate.year}-${session.sessionDate.month}-${session.sessionDate.day}',
                              style: AppTypography.bodySmall(
                                AppColors.darkTextSecondary,
                              ),
                            ),
                            Text(
                              'الحالة: ${_sessionStatusArabic(session.status)}',
                              style: AppTypography.bodySmall(
                                AppColors.darkTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TeacherSessionBoardScreen(
                                      teacherId: widget.teacherId,
                                      session: session,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.draw, size: 18),
                              label: const Text('السبورة الذكية'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.info,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            if (!isFinalized)
                              IconButton.filledTonal(
                                tooltip: 'عرض كود الحضور التفاعلي (QR)',
                                onPressed: () => _openQrAttendance(session),
                                icon: const Icon(Icons.qr_code_2),
                              ),
                            IconButton.filledTonal(
                              tooltip: 'عرض كشف الحضور',
                              onPressed: () => _openRosterDialog(session),
                              icon: const Icon(Icons.fact_check),
                            ),
                            if (isFinalized)
                              const StatusChip(
                                label: 'مكتملة ومسجلة',
                                status: ChipStatus.success,
                              )
                            else
                              ElevatedButton(
                                onPressed: () => _openRollCall(session),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text('تسجيل الحضور'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateSessionDialog() async {
    if (_selectedGroup == null) return;

    final locationController = TextEditingController();
    DateTime? selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (stateCtx, setState) {
          return AlertDialog(
            title: const Text('إنشاء حصة جديدة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'القاعة أو المكان',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تاريخ الحصة'),
                  subtitle: Text(
                    '${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: stateCtx,
                      initialDate: selectedDate!,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('إنشاء الحصة'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      try {
        await _sessionRepo.createClassSession(
          ClassSession(
            id: '', // Will be generated by DB
            groupId: _selectedGroup!.id,
            sessionDate: selectedDate!,
            scheduledStartAt: selectedDate!,
            scheduledEndAt: selectedDate!.add(const Duration(hours: 1)),
            status: SessionStatus.scheduled,
            location: locationController.text.trim().isEmpty
                ? null
                : locationController.text.trim(),
          ),
        );
        await _loadGroupsAndSessions();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إنشاء الحصة: $e'),
          ),
        );
      }
    }
  }
}

class _TeacherAttendanceQrDialog extends StatefulWidget {
  final ClassSession session;
  final Future<void> Function()? onFinalized;

  const _TeacherAttendanceQrDialog({required this.session, this.onFinalized});

  @override
  State<_TeacherAttendanceQrDialog> createState() =>
      _TeacherAttendanceQrDialogState();
}

class _TeacherAttendanceQrDialogState
    extends State<_TeacherAttendanceQrDialog> {
  Timer? _timer;
  bool _isLoading = true;
  bool _isFinalizing = false;
  String? _error;
  String? _token;
  DateTime? _expiresAt;
  List<_QrRosterItem> _roster = [];

  @override
  void initState() {
    super.initState();
    _refreshQrWorkspace();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshQrWorkspace(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshQrWorkspace() async {
    if (!mounted) return;
    setState(() {
      _isLoading = _token == null;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'get_current_attendance_qr',
        params: {'p_class_session_id': widget.session.id},
      );
      final rosterResponse = await Supabase.instance.client.rpc(
        'get_session_qr_attendance_roster',
        params: {'p_class_session_id': widget.session.id},
      );
      final json = Map<String, dynamic>.from(response as Map);
      final roster = (rosterResponse as List)
          .whereType<Map>()
          .map((row) => _QrRosterItem.fromMap(row))
          .toList();
      if (!mounted) return;
      setState(() {
        _token = json['token']?.toString();
        _expiresAt = DateTime.tryParse(json['expires_at']?.toString() ?? '');
        _roster = roster;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _finalizeAttendance() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اعتماد الحضور عبر رمز QR؟'),
        content: const Text(
          'سيتم تسجيل الطلاب الذين لم يقوموا بمسح الرمز كغائبين تلقائياً وإنهاء هذه الحصة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('اعتماد'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isFinalizing = true);
    try {
      final response = await Supabase.instance.client.rpc(
        'finalize_qr_attendance',
        params: {'p_class_session_id': widget.session.id},
      );
      final json = Map<String, dynamic>.from(response as Map);
      _timer?.cancel();
      await widget.onFinalized?.call();
      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'تم اعتماد الحضور: ${json['present_count'] ?? 0} حاضر، '
            '${json['late_count'] ?? 0} متأخر، ${json['absent_count'] ?? 0} غائب.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFinalizing = false);
      messenger.showSnackBar(
        SnackBar(content: Text('فشل اعتماد الحضور: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = _token;
    final qrPayload = token == null
        ? null
        : jsonEncode({'type': 'attendance_qr', 'token': token});
    final secondsLeft = _expiresAt
        ?.difference(DateTime.now())
        .inSeconds
        .clamp(0, 999);
    final presentCount = _roster
        .where((item) => item.status == 'present' || item.status == 'late')
        .length;

    return AlertDialog(
      title: const Text('رمز الحضور الذكي (QR Code)'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'يمسح الطلاب هذا الرمز لتسجيل الحضور فورياً. يتجدد الرمز أوتوماتيكياً كل دقيقة لضمان الأمان.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                )
              else if (_error != null)
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                )
              else if (qrPayload != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: qrPayload,
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                secondsLeft == null
                    ? 'بانتظار إنشاء الرمز'
                    : 'ينتهي خلال $secondsLeft ثانية',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'حاضر: $presentCount',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    'غائب: ${_roster.length - presentCount}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                  Text(
                    'الإجمالي: ${_roster.length}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: _roster.isEmpty
                    ? const Center(
                        child: Text('ستظهر أسماء الطلاب فور تسجيل حضورهم هنا.'),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _roster.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _roster[index];
                          final checkedIn =
                              item.status == 'present' || item.status == 'late';
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              checkedIn
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: checkedIn ? Colors.green : Colors.grey,
                            ),
                            title: Text(item.fullName),
                            subtitle: Text(
                              item.checkInAt == null
                                  ? item.studentCode
                                  : '${item.studentCode} | ${_formatQrTime(item.checkInAt!)} | ${item.markedByQr ? "QR" : "يدوي"}',
                            ),
                            trailing: Text(_attendanceStatusStringArabic(item.status)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isFinalizing ? null : () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
        OutlinedButton.icon(
          onPressed: _isFinalizing ? null : _finalizeAttendance,
          icon: _isFinalizing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.done_all),
          label: const Text('اعتماد الحضور النهائي'),
        ),
        FilledButton.icon(
          onPressed: _isFinalizing ? null : _refreshQrWorkspace,
          icon: const Icon(Icons.refresh),
          label: const Text('تحديث'),
        ),
      ],
    );
  }
}

class _QrRosterItem {
  final String studentId;
  final String studentCode;
  final String fullName;
  final String status;
  final DateTime? checkInAt;
  final String? deviceId;
  final bool markedByQr;

  const _QrRosterItem({
    required this.studentId,
    required this.studentCode,
    required this.fullName,
    required this.status,
    required this.checkInAt,
    required this.deviceId,
    required this.markedByQr,
  });

  factory _QrRosterItem.fromMap(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _QrRosterItem(
      studentId: json['student_id']?.toString() ?? '',
      studentCode: json['student_code']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'طالب',
      status: json['attendance_status']?.toString() ?? 'pending',
      checkInAt: DateTime.tryParse(json['check_in_at']?.toString() ?? ''),
      deviceId: json['device_id']?.toString(),
      markedByQr: json['marked_by_qr'] == true,
    );
  }
}

String _formatQrTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _GroupPicker extends StatelessWidget {
  final List<GroupEntity> groups;
  final GroupEntity? selectedGroup;
  final ValueChanged<GroupEntity?> onChanged;

  const _GroupPicker({
    required this.groups,
    required this.selectedGroup,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<GroupEntity>(
        initialValue: selectedGroup,
        decoration: const InputDecoration(
          labelText: 'المجموعة الدراسية',
          border: OutlineInputBorder(),
        ),
        items: groups
            .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
            .toList(),
        onChanged: groups.isEmpty ? null : onChanged,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
