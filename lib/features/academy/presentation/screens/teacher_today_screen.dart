import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';

class TeacherTodayScreen extends StatefulWidget {
  final String teacherId;

  const TeacherTodayScreen({super.key, required this.teacherId});

  @override
  State<TeacherTodayScreen> createState() => _TeacherTodayScreenState();
}

class _TeacherTodayScreenState extends State<TeacherTodayScreen> {
  late final SupabaseTeacherRepository _teacherRepo;
  late final SupabaseScheduleRepository _scheduleRepo;

  List<GroupEntity> _assignedGroups = [];
  List<ScheduleEntity> _todaySchedules = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _teacherRepo = SupabaseTeacherRepository(wrapper);
    _scheduleRepo = SupabaseScheduleRepository(wrapper);
    _loadTodaySchedule();
  }

  Future<void> _loadTodaySchedule() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _teacherRepo.fetchAssignedGroups(widget.teacherId);
      final todayWeekday = DateTime.now().weekday; // 1 = Mon, 7 = Sun

      final List<ScheduleEntity> matchingSchedules = [];
      for (final g in groups) {
        final schs = await _scheduleRepo.fetchSchedulesForGroup(g.id);
        matchingSchedules.addAll(
          schs.where((s) => s.dayOfWeek == todayWeekday),
        );
      }

      // Sort by start time
      matchingSchedules.sort((a, b) => a.startTime.compareTo(b.startTime));

      if (mounted) {
        setState(() {
          _assignedGroups = groups;
          _todaySchedules = matchingSchedules;
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

  String _arabicDayName(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'السبت';
      case DateTime.sunday:
        return 'الأحد';
      case DateTime.monday:
        return 'الإثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.thursday:
        return 'الخميس';
      case DateTime.friday:
        return 'الجمعة';
      default:
        return '';
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayName = _arabicDayName(now.weekday);
    final dateStr = '$dayName، ${now.day}/${now.month}/${now.year}';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'حصص اليوم',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث الجدول',
              onPressed: _isLoading ? null : _loadTodaySchedule,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('جارٍ تحميل مواعيد حصص اليوم...'),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
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
                            'حدث خطأ أثناء تحميل الحصص: $_errorMessage',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadTodaySchedule,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTodaySchedule,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Today Header Banner Card
                        GlassCard(
                          borderRadius: BorderRadius.circular(16),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.15),
                                child: const Icon(
                                  Icons.today,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _todaySchedules.isEmpty
                                          ? 'لا توجد حصص مجدولة اليوم'
                                          : 'لديك ${_todaySchedules.length} حصة مجدولة لهذا اليوم',
                                      style: TextStyle(
                                        color: _todaySchedules.isEmpty
                                            ? Colors.grey
                                            : Colors.green,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (_todaySchedules.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.beach_access,
                                    size: 64,
                                    color: Colors.grey.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'لا توجد حصص تدريس مجدولة لليوم!',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'إجمالي مجموعاتك النشطة: ${_assignedGroups.length} مجموعة',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...List.generate(_todaySchedules.length, (i) {
                            final sch = _todaySchedules[i];
                            final group = _assignedGroups.firstWhere(
                              (g) => g.id == sch.groupId,
                              orElse: () => GroupEntity(
                                id: sch.groupId,
                                code: 'GRP',
                                name: 'مجموعة دراسية',
                                subjectId: '',
                                branchId: '',
                                status: 'active',
                              ),
                            );

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: FadeInSlide(
                                delay: Duration(milliseconds: 40 * i),
                                child: Card(
                                  elevation: 0,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHigh,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: AppColors
                                                  .teacherRole
                                                  .withValues(alpha: 0.15),
                                              child: const Icon(
                                                Icons.class_outlined,
                                                color: AppColors.teacherRole,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    group.name,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'كود المجموعة: ${group.code}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'اليوم',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 20),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time,
                                              size: 16,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'من ${_formatTimeStr(sch.startTime)} إلى ${_formatTimeStr(sch.endTime)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const Spacer(),
                                            const Icon(
                                              Icons.meeting_room_outlined,
                                              size: 16,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              sch.roomLocation ??
                                                  'القاعة الرئيسية',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
      ),
    );
  }
}
