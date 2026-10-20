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
  final TextEditingController _searchController = TextEditingController();
  String _selectedDayFilter = 'all'; // 'all', 'today', '1'..'7'

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _scheduleRepo = SupabaseScheduleRepository(wrapper);
    _groupRepo = SupabaseGroupRepository(wrapper);
    _loadSchedules();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final g = await _groupRepo.fetchGroups();
      final groupIds = g.map((item) => item.id).toList();
      final s = <ScheduleEntity>[];

      if (groupIds.isNotEmpty) {
        try {
          final res = await Supabase.instance.client
              .from('schedules')
              .select()
              .inFilter('group_id', groupIds);
          for (final row in res as List) {
            s.add(ScheduleEntity.fromJson(Map<String, dynamic>.from(row as Map)));
          }
        } catch (_) {
          for (final group in g) {
            try {
              s.addAll(await _scheduleRepo.fetchSchedulesForGroup(group.id));
            } catch (_) {}
          }
        }
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

  String _durationLabel(String start, String end) {
    try {
      final sParts = start.split(':');
      final eParts = end.split(':');
      final sH = int.parse(sParts[0]);
      final sM = int.parse(sParts[1]);
      final eH = int.parse(eParts[0]);
      final eM = int.parse(eParts[1]);
      final mins = (eH * 60 + eM) - (sH * 60 + sM);
      if (mins <= 0) return '';
      final hours = mins ~/ 60;
      final remainingMins = mins % 60;
      if (hours > 0 && remainingMins > 0) {
        return '$hours س و $remainingMins د';
      } else if (hours > 0) {
        return '$hours ${hours == 1 ? "ساعة" : (hours == 2 ? "ساعتان" : "ساعات")}';
      } else {
        return '$remainingMins دقيقة';
      }
    } catch (_) {
      return '';
    }
  }

  void _showDeleteScheduleDialog(ScheduleEntity s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('حذف موعد الحصة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من رغبتك في حذف موعد هذه الحصة من الجدول الأسبوعي؟',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _scheduleRepo.deleteSchedule(s.id);
                _loadSchedules();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف موعد الحصة بنجاح'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل الحذف: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
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
                  child: const Icon(Icons.schedule_rounded, color: AppColors.adminRole, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'إضافة موعد حصة جديد',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.sizeOf(context).width.clamp(280.0, 480.0),
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
                            prefixIcon: Icon(Icons.group_work_rounded, size: 20),
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
                          prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
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
                          prefixIcon: Icon(Icons.meeting_room_outlined, size: 20),
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
                              icon: const Icon(Icons.access_time_rounded, size: 15),
                              label: Text(
                                'البداية: ${startTime.format(context)}',
                                style: const TextStyle(fontSize: 11),
                              ),
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
                              icon: const Icon(Icons.access_time_rounded, size: 15),
                              label: Text(
                                'النهاية: ${endTime.format(context)}',
                                style: const TextStyle(fontSize: 11),
                              ),
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
                              behavior: SnackBarBehavior.floating,
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
                                behavior: SnackBarBehavior.floating,
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
                                behavior: SnackBarBehavior.floating,
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
                  child: const Icon(Icons.edit_rounded, color: AppColors.adminRole, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'تعديل موعد الحصة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.sizeOf(context).width.clamp(280.0, 480.0),
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
                          prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
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
                          prefixIcon: Icon(Icons.meeting_room_outlined, size: 20),
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
                              icon: const Icon(Icons.access_time_rounded, size: 15),
                              label: Text(
                                'البداية: ${startTime.format(context)}',
                                style: const TextStyle(fontSize: 11),
                              ),
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
                              icon: const Icon(Icons.access_time_rounded, size: 15),
                              label: Text(
                                'النهاية: ${endTime.format(context)}',
                                style: const TextStyle(fontSize: 11),
                              ),
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
                              behavior: SnackBarBehavior.floating,
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
                                behavior: SnackBarBehavior.floating,
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
                                behavior: SnackBarBehavior.floating,
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

  Widget _buildKpiSection(
    bool isDark,
    int total,
    int todayCount,
    int roomCount,
    int groupCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 750;
        final kpiTotal = _buildKpiItem(
          label: 'إجمالي الحصص',
          value: total.toString(),
          icon: Icons.calendar_today_rounded,
          color: AppColors.adminRole,
          isDark: isDark,
        );
        final kpiToday = _buildKpiItem(
          label: 'حصص اليوم',
          value: todayCount.toString(),
          icon: Icons.today_rounded,
          color: Colors.green,
          isDark: isDark,
        );
        final kpiRooms = _buildKpiItem(
          label: 'القاعات النشطة',
          value: roomCount.toString(),
          icon: Icons.meeting_room_outlined,
          color: Colors.deepPurple,
          isDark: isDark,
        );
        final kpiGroups = _buildKpiItem(
          label: 'المجموعات المجدولة',
          value: groupCount.toString(),
          icon: Icons.group_work_rounded,
          color: Colors.blue,
          isDark: isDark,
        );

        if (isWide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: kpiTotal),
                const SizedBox(width: 8),
                Expanded(child: kpiToday),
                const SizedBox(width: 8),
                Expanded(child: kpiRooms),
                const SizedBox(width: 8),
                Expanded(child: kpiGroups),
              ],
            ),
          );
        }

        // Mobile Layout: 2 rows of 2
        return Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: kpiTotal),
                  const SizedBox(width: 8),
                  Expanded(child: kpiToday),
                ],
              ),
            ),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: kpiRooms),
                  const SizedBox(width: 8),
                  Expanded(child: kpiGroups),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final searchField = TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'بحث باسم المجموعة أو رقم القاعة...',
            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.black12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.black12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.adminRole, width: 1.2),
            ),
            filled: true,
            fillColor: isDark ? AppColors.darkSurface : Colors.white,
          ),
        );

        final dayChips = Row(
          mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
          children: [
            _buildDayFilterChip('all', 'الكل', isDark),
            const SizedBox(width: 4),
            _buildDayFilterChip('today', 'اليوم 🌟', isDark),
            const SizedBox(width: 4),
            _buildDayFilterChip('6', 'السبت', isDark),
            const SizedBox(width: 4),
            _buildDayFilterChip('7', 'الأحد', isDark),
            const SizedBox(width: 4),
            _buildDayFilterChip('1', 'الإثنين', isDark),
            const SizedBox(width: 4),
            _buildDayFilterChip('2', 'الثلاثاء', isDark),
            const SizedBox(width: 4),
            _buildDayFilterChip('3', 'الأربعاء', isDark),
            const SizedBox(width: 4),
            _buildDayFilterChip('4', 'الخميس', isDark),
            const SizedBox(width: 4),
            _buildDayFilterChip('5', 'الجمعة', isDark),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: dayChips,
              ),
            ],
          );
        }

        return Column(
          children: [
            searchField,
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: dayChips,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDayFilterChip(String value, String label, bool isDark) {
    final isSelected = _selectedDayFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedDayFilter = value),
      selectedColor: AppColors.adminRole.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected
            ? AppColors.adminRole
            : (isDark ? Colors.white70 : Colors.black87),
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.adminRole
            : (isDark ? AppColors.darkBorder : Colors.black12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildScheduleCard(BuildContext context, ScheduleEntity s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    final groupName = _groups
        .where((g) => g.id == s.groupId)
        .map((g) => g.name)
        .firstOrNull ?? 'مجموعة دراسية';

    final isToday = s.dayOfWeek == DateTime.now().weekday;
    final duration = _durationLabel(s.startTime, s.endTime);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? AppColors.primary.withValues(alpha: 0.6)
              : (isDark ? AppColors.darkBorder : Colors.black12),
          width: isToday ? 1.4 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Day Badge + Group Name + Today Indicator
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isToday
                      ? AppColors.primary
                      : AppColors.adminRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _dayLabel(s.dayOfWeek),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.white : AppColors.adminRole,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'اليوم',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 6),

          // Badges: Time range + Duration + Room
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.teal.withValues(alpha: 0.2),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: Colors.teal),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatTimeStr(s.startTime)} - ${_formatTimeStr(s.endTime)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
              if (duration.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timelapse_rounded, size: 12, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        duration,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              if (s.roomLocation != null && s.roomLocation!.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.deepPurple.withValues(alpha: 0.2),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.meeting_room_outlined, size: 12, color: Colors.deepPurple),
                      const SizedBox(width: 4),
                      Text(
                        s.roomLocation!.trim(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const Divider(height: 10),

          // Action Toolbar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: AppColors.adminRole.withValues(alpha: 0.3)),
                ),
                onPressed: () => _showEditScheduleDialog(s),
                icon: const Icon(Icons.edit_rounded, size: 13, color: AppColors.adminRole),
                label: const Text(
                  'تعديل الموعد',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.adminRole,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'حذف موعد الحصة',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: Colors.redAccent,
                ),
                onPressed: () => _showDeleteScheduleDialog(s),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _schedules.where((s) {
      final q = _searchController.text.toLowerCase().trim();
      final groupName = _groups
          .where((g) => g.id == s.groupId)
          .map((g) => g.name)
          .firstOrNull ?? '';
      final room = s.roomLocation ?? '';

      final matchesSearch = q.isEmpty ||
          groupName.toLowerCase().contains(q) ||
          room.toLowerCase().contains(q) ||
          _dayLabel(s.dayOfWeek).toLowerCase().contains(q);

      if (!matchesSearch) return false;

      if (_selectedDayFilter == 'today') {
        return s.dayOfWeek == DateTime.now().weekday;
      }
      if (_selectedDayFilter != 'all') {
        final dayNum = int.tryParse(_selectedDayFilter);
        if (dayNum != null && s.dayOfWeek != dayNum) return false;
      }

      return true;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = _schedules.length;
    final todayCount = _schedules.where((s) => s.dayOfWeek == DateTime.now().weekday).length;
    final roomCount = _schedules
        .map((s) => s.roomLocation?.trim())
        .where((r) => r != null && r.isNotEmpty)
        .toSet()
        .length;
    final scheduledGroupCount = _schedules.map((s) => s.groupId).toSet().length;

    return PortalPageShell(
      title: 'جدول الحصص الأسبوعي',
      subtitle: 'تنظيم المواعيد الأسبوعية، القاعات الدراسية، ومنع تعارض الفترات.',
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
      headerWidgets: [
        _buildKpiSection(isDark, totalCount, todayCount, roomCount, scheduledGroupCount),
        const SizedBox(height: 12),
        _buildSearchAndFilterBar(isDark),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: filtered.isEmpty,
              emptyTitle: _searchController.text.isNotEmpty || _selectedDayFilter != 'all'
                  ? 'لا توجد حصص تطابق بحثك أو اليوم المحدد'
                  : 'لا توجد مواعيد حصص في الجدول',
              emptySubtitle: _searchController.text.isNotEmpty || _selectedDayFilter != 'all'
                  ? 'جرّب اختيار يوم آخر أو تعديل مصطلحات البحث.'
                  : 'قم بإضافة مواعيد الحصص والقاعات عبر زر (إضافة موعد حصة) بالأعلى.',
              emptyIcon: Icons.calendar_today_rounded,
              onRetry: _loadSchedules,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 850;
                  final isMedium = constraints.maxWidth > 580;

                  if (isWide) {
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: 175,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => _buildScheduleCard(context, filtered[i]),
                    );
                  }

                  if (isMedium) {
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: 175,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => _buildScheduleCard(context, filtered[i]),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _buildScheduleCard(context, filtered[i]),
                  );
                },
              ),
            ),
          );
        }
      }
