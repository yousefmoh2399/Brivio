import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';

class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({super.key});

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen> {
  late final SupabaseScheduleRepository _scheduleRepo;
  late final SupabaseGroupRepository _groupRepo;
  List<ScheduleEntity> _schedules = [];
  List<GroupEntity> _groups = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _scheduleRepo = SupabaseScheduleRepository(wrapper);
    _groupRepo = SupabaseGroupRepository(wrapper);
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final g = await _groupRepo.fetchGroups();
      final s = <ScheduleEntity>[];
      for (final group in g) {
        s.addAll(await _scheduleRepo.fetchSchedulesForGroup(group.id));
      }
      s.sort((a, b) {
        final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (dayCompare != 0) return dayCompare;
        return a.startTime.compareTo(b.startTime);
      });
      if (mounted) {
        setState(() {
          _groups = g;
          _schedules = s;
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

  String _dayLabel(int day) {
    return switch (day) {
      6 => 'السبت',
      7 => 'الأحد',
      1 => 'الإثنين',
      2 => 'الثلاثاء',
      3 => 'الأربعاء',
      4 => 'الخميس',
      5 => 'الجمعة',
      _ => 'يوم $day',
    };
  }

  String _formatTimeStr(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.isEmpty) return timeStr;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? parts[1] : '00';
    final isPm = h >= 12;
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${displayH.toString().padLeft(2, '0')}:$m ${isPm ? "م" : "ص"}';
  }

  void _showCreateScheduleDialog() {
    final formKey = GlobalKey<FormState>();
    String? selectedGroupId = _groups.isNotEmpty ? _groups.first.id : null;
    int selectedDay = 6;
    TimeOfDay startTime = const TimeOfDay(hour: 16, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);
    final roomCtrl = TextEditingController(text: 'قاعة 1');
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.adminRole.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.schedule, color: AppColors.adminRole),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'إضافة موعد حصة جديد',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_groups.isNotEmpty)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedGroupId,
                          decoration: const InputDecoration(
                            labelText: 'المجموعة الدراسية *',
                            border: OutlineInputBorder(),
                          ),
                          items: _groups
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g.id,
                                  child: Text(g.name, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setStateDialog(() => selectedGroupId = v),
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: selectedDay,
                        decoration: const InputDecoration(
                          labelText: 'يوم الحصة الأسبوعي',
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
                        onChanged: (v) {
                          if (v != null) setStateDialog(() => selectedDay = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: roomCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم / رقم القاعة الدراسية *',
                          hintText: 'مثال: قاعة 1، معمل الفيزياء',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'يرجى إدخال اسم القاعة' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time_rounded, size: 16),
                              label: Text('البداية: ${startTime.format(context)}', style: const TextStyle(fontSize: 12)),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: startTime,
                                );
                                if (picked != null) {
                                  setStateDialog(() => startTime = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time_rounded, size: 16),
                              label: Text('النهاية: ${endTime.format(context)}', style: const TextStyle(fontSize: 12)),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: endTime,
                                );
                                if (picked != null) {
                                  setStateDialog(() => endTime = picked);
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
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.adminRole,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        if (selectedGroupId == null) return;

                        final startMinutes = startTime.hour * 60 + startTime.minute;
                        final endMinutes = endTime.hour * 60 + endTime.minute;
                        if (endMinutes <= startMinutes) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('وقت نهاية الحصة يجب أن يكون بعد وقت البداية'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setStateDialog(() => isSubmitting = true);
                        final nav = Navigator.of(ctx);

                        try {
                          final startStr =
                              '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                          final endStr =
                              '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

                          await _scheduleRepo.createSchedule(
                            groupId: selectedGroupId!,
                            dayOfWeek: selectedDay,
                            startTime: startStr,
                            endTime: endStr,
                            roomLocation: roomCtrl.text.trim(),
                          );
                          nav.pop();
                          _loadSchedules();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تمت إضافة موعد الحصة بنجاح!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تعارض أو خطأ في الموعد: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(isSubmitting ? 'جاري الحفظ...' : 'حفظ الموعد'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditScheduleDialog(ScheduleEntity s) {
    final formKey = GlobalKey<FormState>();
    int selectedDay = s.dayOfWeek;
    final startParts = s.startTime.split(':');
    final endParts = s.endTime.split(':');
    TimeOfDay startTime = TimeOfDay(
      hour: int.tryParse(startParts[0]) ?? 16,
      minute: int.tryParse(startParts.length > 1 ? startParts[1] : '0') ?? 0,
    );
    TimeOfDay endTime = TimeOfDay(
      hour: int.tryParse(endParts[0]) ?? 18,
      minute: int.tryParse(endParts.length > 1 ? endParts[1] : '0') ?? 0,
    );
    final roomCtrl = TextEditingController(text: s.roomLocation ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.adminRole.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit, color: AppColors.adminRole),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'تعديل موعد الحصة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: selectedDay,
                        decoration: const InputDecoration(
                          labelText: 'يوم الحصة',
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
                        onChanged: (v) {
                          if (v != null) setStateDialog(() => selectedDay = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: roomCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم / رقم القاعة الدراسية *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'يرجى إدخال اسم القاعة' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time_rounded, size: 16),
                              label: Text('البداية: ${startTime.format(context)}', style: const TextStyle(fontSize: 12)),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: startTime,
                                );
                                if (picked != null) {
                                  setStateDialog(() => startTime = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time_rounded, size: 16),
                              label: Text('النهاية: ${endTime.format(context)}', style: const TextStyle(fontSize: 12)),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: endTime,
                                );
                                if (picked != null) {
                                  setStateDialog(() => endTime = picked);
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
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.adminRole,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        final startMinutes = startTime.hour * 60 + startTime.minute;
                        final endMinutes = endTime.hour * 60 + endTime.minute;
                        if (endMinutes <= startMinutes) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('وقت نهاية الحصة يجب أن يكون بعد وقت البداية'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setStateDialog(() => isSubmitting = true);
                        final nav = Navigator.of(ctx);

                        try {
                          final startStr =
                              '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                          final endStr =
                              '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

                          await _scheduleRepo.updateSchedule(
                            scheduleId: s.id,
                            dayOfWeek: selectedDay,
                            startTime: startStr,
                            endTime: endStr,
                            roomLocation: roomCtrl.text.trim().isEmpty ? null : roomCtrl.text.trim(),
                          );
                          nav.pop();
                          _loadSchedules();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تحديث موعد الحصة بنجاح!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('فشل تحديث الموعد: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(isSubmitting ? 'جاري الحفظ...' : 'حفظ التعديلات'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context, ScheduleEntity s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    final groupName = _groups
        .where((g) => g.id == s.groupId)
        .map((g) => g.name)
        .firstOrNull ?? 'مجموعة دراسية';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.adminRole.withValues(alpha: 0.12),
            child: const Icon(Icons.access_time_rounded, color: AppColors.adminRole, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  style: AppTypography.titleMedium(textPrimary).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _dayLabel(s.dayOfWeek),
                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule, size: 14, color: Colors.teal),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatTimeStr(s.startTime)} - ${_formatTimeStr(s.endTime)}',
                            style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (s.roomLocation != null && s.roomLocation!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.meeting_room_outlined, size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              s.roomLocation!,
                              style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'تعديل موعد الحصة',
                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                onPressed: () => _showEditScheduleDialog(s),
              ),
              IconButton(
                tooltip: 'حذف الموعد',
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('حذف موعد الحصة'),
                      content: const Text(
                        'هل أنت متأكد من رغبتك في حذف موعد هذه الحصة من الجدول الأسبوعي؟',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('إلغاء'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('حذف'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await _scheduleRepo.deleteSchedule(s.id);
                      _loadSchedules();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم حذف موعد الحصة بنجاح')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل الحذف: $e')),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'جدول الحصص الأسبوعي',
      subtitle: 'تنظيم المواعيد الأسبوعية والقاعات الدراسية، ومنع تعارض الفترات.',
      icon: Icons.calendar_today,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadSchedules,
        ),
        PortalAction(
          icon: Icons.add,
          label: 'إضافة موعد حصة',
          onPressed: _showCreateScheduleDialog,
          primary: true,
        ),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: _schedules.isEmpty,
        emptyTitle: 'لا توجد مواعيد حصص في الجدول',
        emptySubtitle: 'قم بإضافة مواعيد الحصص والقاعات عبر زر (إضافة موعد حصة) بالأعلى.',
        emptyIcon: Icons.calendar_today,
        onRetry: _loadSchedules,
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: _schedules.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) => _buildScheduleCard(context, _schedules[i]),
        ),
      ),
    );
  }
}
