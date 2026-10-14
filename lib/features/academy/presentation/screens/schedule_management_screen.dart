import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
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

  void _showCreateScheduleDialog() {
    String? selectedGroupId = _groups.isNotEmpty ? _groups.first.id : null;
    int selectedDay = 6; // Saturday by default for Egyptian centers
    TimeOfDay startTime = const TimeOfDay(hour: 16, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);
    final roomCtrl = TextEditingController(text: 'قاعة 1');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('إضافة موعد حصة جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_groups.isNotEmpty)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedGroupId,
                      decoration: const InputDecoration(
                        labelText: 'اختر المجموعة الدراسية',
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
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: selectedDay,
                    decoration: const InputDecoration(labelText: 'يوم الحصة'),
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
                  const SizedBox(height: 10),
                  TextField(
                    controller: roomCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم / رقم القاعة الدراسية',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time_rounded, size: 16),
                          label: Text('البداية ${startTime.format(context)}', style: const TextStyle(fontSize: 11)),
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
                          label: Text('النهاية ${endTime.format(context)}', style: const TextStyle(fontSize: 11)),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedGroupId == null || roomCtrl.text.trim().isEmpty) {
                    return;
                  }

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
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تعارض أو خطأ في الجدول: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('حفظ الموعد'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditScheduleDialog(ScheduleEntity s) {
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('تعديل موعد الحصة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: selectedDay,
                    decoration: const InputDecoration(labelText: 'يوم الحصة'),
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
                  const SizedBox(height: 10),
                  TextField(
                    controller: roomCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم / رقم القاعة الدراسية',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time_rounded, size: 16),
                          label: Text('البداية ${startTime.format(context)}', style: const TextStyle(fontSize: 11)),
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
                          label: Text('النهاية ${endTime.format(context)}', style: const TextStyle(fontSize: 11)),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (roomCtrl.text.trim().isEmpty) return;

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
                      roomLocation: roomCtrl.text.trim(),
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
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تعارض في الجدول: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('حفظ التعديلات'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteSchedule(ScheduleEntity s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف موعد الحصة'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا الموعد من الجدول؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _scheduleRepo.deleteSchedule(s.id);
        _loadSchedules();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الموعد من الجدول')),
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
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'إدارة الجداول والمواعيد',
      subtitle: 'تنظيم مواعيد الحصص الأسبوعية، توزيع القاعات، ومنع تعارض المواعيد.',
      icon: Icons.schedule,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadSchedules,
        ),
        PortalAction(
          icon: Icons.add,
          label: 'إضافة موعد جديد',
          onPressed: _showCreateScheduleDialog,
          primary: true,
        ),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: _schedules.isEmpty,
        emptyTitle: 'لا توجد مواعيد مسجلة',
        emptySubtitle: 'قم بإنشاء مجموعة دراسية أولاً ثم أضف مواعيد الحصص والقاعات.',
        emptyIcon: Icons.schedule,
        onRetry: _loadSchedules,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _schedules.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final s = _schedules[i];
            String? groupName;
            for (final group in _groups) {
              if (group.id == s.groupId) {
                groupName = group.name;
                break;
              }
            }
            return PortalListCard(
              icon: Icons.schedule,
              accentColor: AppColors.adminRole,
              title:
                  '${groupName ?? "مجموعة"} • ${_dayNameArabic(s.dayOfWeek)}: ${_formatTime(s.startTime)} - ${_formatTime(s.endTime)}',
              subtitle: 'القاعة الدراسية: ${s.roomLocation ?? "غير محددة"}',
              trailing: [
                PortalStatusChip(status: s.status),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditScheduleDialog(s),
                  tooltip: 'تعديل الموعد',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteSchedule(s),
                  tooltip: 'حذف الموعد',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _dayNameArabic(int day) {
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

  static String _formatTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts[1];
      final period = h >= 12 ? 'م' : 'ص';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:$m $period';
    }
    return timeStr;
  }
}
