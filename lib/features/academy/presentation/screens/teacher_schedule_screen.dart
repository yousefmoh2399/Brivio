import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';

class TeacherScheduleScreen extends StatefulWidget {
  final String teacherId;

  const TeacherScheduleScreen({super.key, required this.teacherId});

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseScheduleRepository _scheduleRepo;

  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<ScheduleEntity> _schedules = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _scheduleRepo = SupabaseScheduleRepository(wrapper);
    _loadTeacherSchedules();
  }

  Future<void> _loadTeacherSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      GroupEntity? selected = _selectedGroup;
      if (selected == null && groups.isNotEmpty) {
        selected = groups.first;
      } else if (selected != null) {
        selected = groups.where((g) => g.id == selected!.id).firstOrNull;
      }

      final schedules = selected == null
          ? <ScheduleEntity>[]
          : await _scheduleRepo.fetchSchedulesForGroup(selected.id);

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _schedules = schedules;
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
    await _loadTeacherSchedules();
  }

  String _dayName(int day) {
    switch (day) {
      case 6:
        return 'السبت';
      case 7:
        return 'الأحد';
      case 1:
        return 'الإثنين';
      case 2:
        return 'الثلاثاء';
      case 3:
        return 'الأربعاء';
      case 4:
        return 'الخميس';
      case 5:
        return 'الجمعة';
      default:
        return 'يوم $day';
    }
  }

  String _formatTimeStr(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return timeStr;
    final hour = int.tryParse(parts[0]) ?? 0;
    final min = int.tryParse(parts[1]) ?? 0;
    final period = hour >= 12 ? 'م' : 'ص';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:${min.toString().padLeft(2, '0')} $period';
  }

  String _timeString(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  TimeOfDay _parseTime(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length < 2) return fallback;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? fallback.hour,
      minute: int.tryParse(parts[1]) ?? fallback.minute,
    );
  }

  bool _isEndTimeAfter(TimeOfDay start, TimeOfDay end) {
    if (end.hour > start.hour) return true;
    if (end.hour == start.hour && end.minute > start.minute) return true;
    return false;
  }

  void _showScheduleDialog({ScheduleEntity? schedule}) {
    final group = _selectedGroup;
    if (group == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('برجاء اختيار مجموعة دراسية أولاً لإضافة الموعد'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final isEditing = schedule != null;
    int selectedDay = schedule?.dayOfWeek ?? 6; // Default to Saturday
    TimeOfDay startTime = schedule == null
        ? const TimeOfDay(hour: 10, minute: 0)
        : _parseTime(schedule.startTime, const TimeOfDay(hour: 10, minute: 0));
    TimeOfDay endTime = schedule == null
        ? const TimeOfDay(hour: 12, minute: 0)
        : _parseTime(schedule.endTime, const TimeOfDay(hour: 12, minute: 0));

    final formKey = GlobalKey<FormState>();
    final roomCtrl = TextEditingController(text: schedule?.roomLocation ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_calendar : Icons.add_alarm,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'تعديل موعد الحصة' : 'إضافة موعد حصة جديد',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SizedBox(
                width: double.maxFinite,
                child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.groups,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'المجموعة: ${group.name} (${group.code})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: selectedDay,
                        decoration: const InputDecoration(
                          labelText: 'يوم الحصة',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 6, child: Text('السبت')),
                          DropdownMenuItem(value: 7, child: Text('الأحد')),
                          DropdownMenuItem(value: 1, child: Text('الإثنين')),
                          DropdownMenuItem(value: 2, child: Text('الثلاثاء')),
                          DropdownMenuItem(value: 3, child: Text('الأربعاء')),
                          DropdownMenuItem(value: 4, child: Text('الخميس')),
                          DropdownMenuItem(value: 5, child: Text('الجمعة')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedDay = value);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: roomCtrl,
                        decoration: const InputDecoration(
                          labelText: 'مكان الحصة أو القاعة',
                          hintText: 'مثال: القاعة الكبرى، سنتر التميز، أونلاين',
                          prefixIcon: Icon(Icons.meeting_room_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'برجاء كتابة القاعة أو مكان انعقاد الحصة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'توقيت الحصة (البدء والانتهاء):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.access_time),
                              label: Text(
                                'من: ${startTime.format(context)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: startTime,
                                );
                                if (picked != null) {
                                  setDialogState(() => startTime = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.access_time_filled),
                              label: Text(
                                'إلى: ${endTime.format(context)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: endTime,
                                );
                                if (picked != null) {
                                  setDialogState(() => endTime = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(isEditing ? Icons.save : Icons.add_circle_outline),
                label: Text(isEditing ? 'حفظ التعديلات' : 'إضافة الموعد'),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        if (!_isEndTimeAfter(startTime, endTime)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تنبيه: يجب أن يكون وقت نهاية الحصة بعد وقت البدء!',
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        final nav = Navigator.of(ctx);
                        try {
                          if (isEditing) {
                            await _scheduleRepo.updateSchedule(
                              scheduleId: schedule.id,
                              dayOfWeek: selectedDay,
                              startTime: _timeString(startTime),
                              endTime: _timeString(endTime),
                              roomLocation: roomCtrl.text.trim(),
                            );
                          } else {
                            await _scheduleRepo.createSchedule(
                              groupId: group.id,
                              dayOfWeek: selectedDay,
                              startTime: _timeString(startTime),
                              endTime: _timeString(endTime),
                              roomLocation: roomCtrl.text.trim(),
                            );
                          }
                          nav.pop();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEditing
                                      ? 'تم تعديل موعد الحصة بنجاح'
                                      : 'تم إضافة موعد الحصة الجديد بنجاح',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                          await _loadTeacherSchedules();
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل حفظ الموعد: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSchedule(ScheduleEntity schedule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('حذف موعد الحصة'),
            ],
          ),
          content: Text(
            'هل أنت متأكد من حذف هذا الموعد الأسبوعي (يوم ${_dayName(schedule.dayOfWeek)})؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الحذف'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;

    try {
      await _scheduleRepo.deleteSchedule(schedule.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف موعد الحصة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadTeacherSchedules();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حذف الموعد: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed:
              _selectedGroup == null ? null : () => _showScheduleDialog(),
          icon: const Icon(Icons.add_alarm),
          label: const Text(
            'إضافة موعد حصة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadTeacherSchedules,
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('جارٍ تحميل جدول المواعيد والحصص...'),
                    ],
                  ),
                )
              : _errorMessage != null
                  ? CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.redAccent,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'حدث خطأ: $_errorMessage',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _loadTeacherSchedules,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        // Group Selector Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: DropdownButtonFormField<GroupEntity>(
                            initialValue: _selectedGroup,
                            decoration: InputDecoration(
                              labelText: 'المجموعة الدراسية',
                              prefixIcon: const Icon(Icons.groups_outlined),
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: _groups
                                .map(
                                  (group) => DropdownMenuItem(
                                    value: group,
                                    child: Text(
                                      '${group.name} (${group.code})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _groups.isEmpty ? null : _selectGroup,
                          ),
                        ),
                        Expanded(
                          child: _schedules.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 64,
                                        color:
                                            Colors.grey.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _selectedGroup == null
                                            ? 'برجاء اختيار مجموعة لعرض مواعيدها'
                                            : 'لا توجد مواعيد حصص مسجلة لهذه المجموعة',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (_selectedGroup != null) ...[
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _showScheduleDialog(),
                                          icon: const Icon(Icons.add),
                                          label: const Text(
                                            'إضافة موعد الحصة الأسبوعي',
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _schedules.length,
                                  separatorBuilder: (ctx, i) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (ctx, i) {
                                    final schedule = _schedules[i];
                                    return FadeInSlide(
                                      delay: Duration(milliseconds: 40 * i),
                                      child: Card(
                                        elevation: 0,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHigh,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 24,
                                                backgroundColor: AppColors
                                                    .primary
                                                    .withValues(alpha: 0.15),
                                                child: const Icon(
                                                  Icons.schedule,
                                                  color: AppColors.primary,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 8,
                                                            vertical: 2,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: AppColors
                                                                .teacherRole
                                                                .withValues(
                                                                    alpha: 0.15),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                          ),
                                                          child: Text(
                                                            _dayName(schedule
                                                                .dayOfWeek),
                                                            style:
                                                                const TextStyle(
                                                              color: AppColors
                                                                  .teacherRole,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          'من ${_formatTimeStr(schedule.startTime)} إلى ${_formatTimeStr(schedule.endTime)}',
                                                          style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .meeting_room_outlined,
                                                          size: 15,
                                                          color: Colors.grey,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'المكان: ${schedule.roomLocation ?? "القاعة الرئيسية"}',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 20,
                                                ),
                                                tooltip: 'تعديل الموعد',
                                                onPressed: () =>
                                                    _showScheduleDialog(
                                                  schedule: schedule,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.redAccent,
                                                  size: 20,
                                                ),
                                                tooltip: 'حذف الموعد',
                                                onPressed: () =>
                                                    _deleteSchedule(schedule),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
