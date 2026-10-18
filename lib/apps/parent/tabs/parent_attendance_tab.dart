import 'package:flutter/material.dart';

import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import 'parent_home_tab.dart';

// ─── Shared Models for Attendance & Leave Requests ────────────────────────────

class ParentLeaveItem {
  final String id;
  final String reason;
  final String status;
  final DateTime? submittedAt;
  final DateTime? sessionDate;
  final String groupName;

  const ParentLeaveItem({
    required this.id,
    required this.reason,
    required this.status,
    required this.submittedAt,
    required this.sessionDate,
    required this.groupName,
  });

  factory ParentLeaveItem.fromJson(Map json) {
    return ParentLeaveItem(
      id: json['id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? 'طلب إذن غياب',
      status: json['status']?.toString() ?? 'pending',
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      sessionDate: DateTime.tryParse(json['session_date']?.toString() ?? ''),
      groupName: json['group_name']?.toString() ?? 'عام',
    );
  }
}

// ─── Main Parent Attendance Tab Widget ────────────────────────────────────────

enum AttendanceFilterCategory {
  all,
  present,
  absent,
  leaves,
}

class ParentAttendanceTab extends StatefulWidget {
  final Student? child;
  final List<Student> linkedChildren;
  final ValueChanged<Student> onChildSelected;
  final List<ParentAttendanceItem> attendance;
  final List<ParentLeaveItem> leaveRequests;
  final List<GroupEntity> childGroups;
  final VoidCallback onExcuseRequest;

  const ParentAttendanceTab({
    super.key,
    required this.child,
    required this.linkedChildren,
    required this.onChildSelected,
    required this.attendance,
    required this.leaveRequests,
    required this.childGroups,
    required this.onExcuseRequest,
  });

  @override
  State<ParentAttendanceTab> createState() => _ParentAttendanceTabState();
}

class _ParentAttendanceTabState extends State<ParentAttendanceTab> {
  AttendanceFilterCategory _selectedCategory = AttendanceFilterCategory.all;
  String? _selectedGroupId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isNarrow = screenWidth < 380;
        final isMobile = screenWidth < 650;

        // Filter attendance by group if selected
        final groupFilteredAttendance = _selectedGroupId == null
            ? widget.attendance
            : widget.attendance.where((a) {
                final matchGroup = widget.childGroups.firstWhere(
                  (g) => g.id == _selectedGroupId,
                  orElse: () => const GroupEntity(
                    id: '',
                    name: '',
                    code: '',
                    subjectId: '',
                    branchId: '',
                    status: '',
                  ),
                );
                return a.groupName == matchGroup.name || a.groupCode == matchGroup.code;
              }).toList();

        // Calculate counts
        final presentCount = widget.attendance
            .where((a) => a.status.toLowerCase() == 'present' || a.status.toLowerCase() == 'late')
            .length;
        final absentCount = widget.attendance
            .where((a) => a.status.toLowerCase() == 'absent')
            .length;

        // Apply category filter
        final filteredAttendance = switch (_selectedCategory) {
          AttendanceFilterCategory.all => groupFilteredAttendance,
          AttendanceFilterCategory.present => groupFilteredAttendance
              .where((a) => a.status.toLowerCase() == 'present' || a.status.toLowerCase() == 'late')
              .toList(),
          AttendanceFilterCategory.absent => groupFilteredAttendance
              .where((a) => a.status.toLowerCase() == 'absent')
              .toList(),
          AttendanceFilterCategory.leaves => <ParentAttendanceItem>[],
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Executive Attendance Hero Card with Radial Commitment Dial
            _ExecutiveAttendanceHero(
              child: widget.child,
              attendance: widget.attendance,
              leaveRequests: widget.leaveRequests,
              isDark: isDark,
              isNarrow: isNarrow,
              isMobile: isMobile,
              onExcuseRequest: widget.onExcuseRequest,
            ),
            const SizedBox(height: 18),

            // 2. Interactive Category Filter Switcher Bar
            _AttendanceCategoryFilterBar(
              selectedCategory: _selectedCategory,
              totalSessionsCount: widget.attendance.length,
              presentCount: presentCount,
              absentCount: absentCount,
              leavesCount: widget.leaveRequests.length,
              isDark: isDark,
              isNarrow: isNarrow,
              onCategoryChanged: (category) {
                setState(() => _selectedCategory = category);
              },
            ),
            const SizedBox(height: 14),

            // 3. Optional Group Filter Pills (if student has multiple groups)
            if (widget.childGroups.length > 1 &&
                _selectedCategory != AttendanceFilterCategory.leaves) ...[
              _buildGroupFilterChips(isDark, isNarrow),
              const SizedBox(height: 14),
            ],

            // 4. Content Area
            if (_selectedCategory == AttendanceFilterCategory.leaves) ...[
              _AbsenceExcusesSection(
                leaveRequests: widget.leaveRequests,
                isDark: isDark,
                isNarrow: isNarrow,
                onNewExcuseRequest: widget.onExcuseRequest,
              ),
            ] else ...[
              _AttendanceSessionsListSection(
                attendanceItems: filteredAttendance,
                selectedCategory: _selectedCategory,
                isDark: isDark,
                isNarrow: isNarrow,
                onExcuseRequest: widget.onExcuseRequest,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildGroupFilterChips(bool isDark, bool isNarrow) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          ChoiceChip(
            label: const Text('جميع المواد والمجموعات', style: TextStyle(fontSize: 11)),
            selected: _selectedGroupId == null,
            onSelected: (_) => setState(() => _selectedGroupId = null),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          ...widget.childGroups.map(
            (group) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: ChoiceChip(
                label: Text(group.name, style: const TextStyle(fontSize: 11)),
                selected: _selectedGroupId == group.id,
                onSelected: (selected) {
                  setState(() => _selectedGroupId = selected ? group.id : null);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 1. Executive Attendance Hero Card ────────────────────────────────────────

class _ExecutiveAttendanceHero extends StatelessWidget {
  final Student? child;
  final List<ParentAttendanceItem> attendance;
  final List<ParentLeaveItem> leaveRequests;
  final bool isDark;
  final bool isNarrow;
  final bool isMobile;
  final VoidCallback onExcuseRequest;

  const _ExecutiveAttendanceHero({
    required this.child,
    required this.attendance,
    required this.leaveRequests,
    required this.isDark,
    required this.isNarrow,
    required this.isMobile,
    required this.onExcuseRequest,
  });

  @override
  Widget build(BuildContext context) {
    final totalSessions = attendance.length;
    final presentSessions = attendance
        .where((a) => a.status.toLowerCase() == 'present')
        .length;
    final lateSessions = attendance
        .where((a) => a.status.toLowerCase() == 'late')
        .length;
    final absentSessions = attendance
        .where((a) => a.status.toLowerCase() == 'absent')
        .length;

    final double attendanceRate =
        totalSessions > 0 ? ((presentSessions + lateSessions) / totalSessions) * 100 : 0.0;
    final int rateInt = attendanceRate.round();

    final Color statusColor;
    final String statusLabel;
    final String statusBadge;

    if (totalSessions == 0) {
      statusColor = AppColors.parentRole;
      statusLabel = 'سجل الحضور قيد التحديث للفصل الجديد';
      statusBadge = 'جديد';
    } else if (rateInt >= 90) {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'نسبة التزام وانضباط ممتازة ومثالية 🌟';
      statusBadge = 'التزام ممتاز';
    } else if (rateInt >= 75) {
      statusColor = const Color(0xFF3B82F6);
      statusLabel = 'نسبة حضور جيدة جداً مع انتظام مستقر 👍';
      statusBadge = 'حضور جيد';
    } else if (rateInt >= 60) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'تنبيه: يوجد تذبذب في الحضور بحاجة للمتابعة ⚠️';
      statusBadge = 'يحتاج متابعة';
    } else {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'إنذار غياب: نسبة الغياب مرتفعة ومقلقة 🔴';
      statusBadge = 'إنذار غياب';
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: statusColor.withValues(alpha: isDark ? 0.40 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isNarrow ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Radial Gauge + Student Name & Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Radial Dial
                SizedBox(
                  width: isNarrow ? 56 : 66,
                  height: isNarrow ? 56 : 66,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: totalSessions > 0 ? (rateInt / 100).clamp(0.0, 1.0) : 0.05,
                        strokeWidth: isNarrow ? 5 : 6,
                        backgroundColor: statusColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            totalSessions > 0 ? '$rateInt%' : '--',
                            style: TextStyle(
                              fontSize: isNarrow ? 13 : 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'الحضور',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Name, Status, and Code
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            child?.fullName ?? 'الطالب',
                            style: TextStyle(
                              fontSize: isNarrow ? 14 : 15.5,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              statusBadge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: isNarrow ? 11 : 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'كود الطالب: ${child?.studentCode ?? "---"} • مسجل في $totalSessions حصة حتى الآن',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 4 KPIs: حضور / غياب / تأخير / أعذار
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 6 : 10,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'حضور',
                      value: '$presentSessions',
                      color: const Color(0xFF10B981),
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'غياب',
                      value: '$absentSessions',
                      color: const Color(0xFFEF4444),
                      icon: Icons.cancel_rounded,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'تأخير',
                      value: '$lateSessions',
                      color: const Color(0xFFF59E0B),
                      icon: Icons.access_time_filled_rounded,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'أعذار',
                      value: '${leaveRequests.length}',
                      color: AppColors.parentRole,
                      icon: Icons.assignment_rounded,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Excuse Request Action Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: child == null ? null : onExcuseRequest,
                icon: const Icon(Icons.note_add_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'تقديم عذر أو إذن غياب رسمي مسبق 📝',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isNarrow ? 12 : 13.5,
            fontWeight: FontWeight.w900,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── 2. Interactive Category Filter Switcher Bar ──────────────────────────────

class _AttendanceCategoryFilterBar extends StatelessWidget {
  final AttendanceFilterCategory selectedCategory;
  final int totalSessionsCount;
  final int presentCount;
  final int absentCount;
  final int leavesCount;
  final bool isDark;
  final bool isNarrow;
  final ValueChanged<AttendanceFilterCategory> onCategoryChanged;

  const _AttendanceCategoryFilterBar({
    required this.selectedCategory,
    required this.totalSessionsCount,
    required this.presentCount,
    required this.absentCount,
    required this.leavesCount,
    required this.isDark,
    required this.isNarrow,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      (
        category: AttendanceFilterCategory.all,
        label: 'السجل الكامل',
        icon: Icons.view_list_rounded,
        count: totalSessionsCount,
      ),
      (
        category: AttendanceFilterCategory.present,
        label: 'الحضور',
        icon: Icons.check_circle_rounded,
        count: presentCount,
      ),
      (
        category: AttendanceFilterCategory.absent,
        label: 'الغياب',
        icon: Icons.cancel_rounded,
        count: absentCount,
      ),
      (
        category: AttendanceFilterCategory.leaves,
        label: 'طلبات الأعذار',
        icon: Icons.fact_check_rounded,
        count: leavesCount,
      ),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = categories[index];
          final isSelected = selectedCategory == item.category;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onCategoryChanged(item.category),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 10 : 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.parentRole
                      : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.parentRole
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.parentRole.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 14,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: isNarrow ? 11 : 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    if (item.count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : AppColors.parentRole.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${item.count}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : AppColors.parentRole,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── 3. Detailed Attendance Sessions Section ──────────────────────────────────

class _AttendanceSessionsListSection extends StatelessWidget {
  final List<ParentAttendanceItem> attendanceItems;
  final AttendanceFilterCategory selectedCategory;
  final bool isDark;
  final bool isNarrow;
  final VoidCallback onExcuseRequest;

  const _AttendanceSessionsListSection({
    required this.attendanceItems,
    required this.selectedCategory,
    required this.isDark,
    required this.isNarrow,
    required this.onExcuseRequest,
  });

  @override
  Widget build(BuildContext context) {
    final title = switch (selectedCategory) {
      AttendanceFilterCategory.all => 'سجل الحصص والتواجد بالسنتر',
      AttendanceFilterCategory.present => 'سجل الحصص المحضورة',
      AttendanceFilterCategory.absent => 'سجل الحصص التي تغيب عنها الطالب',
      AttendanceFilterCategory.leaves => 'طلبات الأعذار',
    };

    final subtitle = switch (selectedCategory) {
      AttendanceFilterCategory.all => 'توثيق مواعيد الدخول والانصراف وحالة الحضور لكل حصة.',
      AttendanceFilterCategory.present => 'قائمة الحصص التي تم رصد حضور الطالب بها بنجاح.',
      AttendanceFilterCategory.absent => 'الحصص التي تم رصد غياب الطالب عنها بالبوابة الإلكترونية.',
      AttendanceFilterCategory.leaves => 'متابعة وفحص قرارات الإدارة على أعذار الغياب.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalSectionTitle(title: title, subtitle: subtitle),
        const SizedBox(height: 10),

        if (attendanceItems.isEmpty)
          _buildEmptyAttendance(isDark)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: attendanceItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = attendanceItems[index];
              return _buildAttendanceCard(item, context);
            },
          ),
      ],
    );
  }

  Widget _buildAttendanceCard(ParentAttendanceItem item, BuildContext context) {
    final status = item.status.toLowerCase();
    final isPresent = status == 'present';
    final isLate = status == 'late';
    final isAbsent = status == 'absent';

    final Color color;
    final String statusBadge;
    final IconData statusIcon;

    if (isPresent) {
      color = const Color(0xFF10B981);
      statusBadge = 'حاضر في الموعد 🟢';
      statusIcon = Icons.check_circle_rounded;
    } else if (isLate) {
      color = const Color(0xFFF59E0B);
      statusBadge = 'تأخر عن البداية 🟡';
      statusIcon = Icons.access_time_filled_rounded;
    } else {
      color = const Color(0xFFEF4444);
      statusBadge = 'غائب 🔴';
      statusIcon = Icons.cancel_rounded;
    }

    final date = item.sessionDate ?? item.markedAt;
    final formattedDate = date != null
        ? '${_dayName(date.weekday)}، ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        : 'موعد الحصة';

    final checkInStr = item.markedAt != null
        ? '${item.markedAt!.hour.toString().padLeft(2, '0')}:${item.markedAt!.minute.toString().padLeft(2, '0')}'
        : null;

    final checkOutStr = item.checkOutAt != null
        ? '${item.checkOutAt!.hour.toString().padLeft(2, '0')}:${item.checkOutAt!.minute.toString().padLeft(2, '0')}'
        : null;

    return GlassCard(
      padding: EdgeInsets.all(isNarrow ? 12 : 14),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Group Icon, Group Name, and Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.groupName,
                      style: TextStyle(
                        fontSize: isNarrow ? 13 : 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  statusBadge,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Check-in / Check-out timing chips
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (checkInStr != null)
                _buildTimeChip(
                  icon: Icons.login_rounded,
                  label: 'تسجيل الدخول: $checkInStr',
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              if (checkOutStr != null)
                _buildTimeChip(
                  icon: Icons.logout_rounded,
                  label: 'الانصراف: $checkOutStr',
                  color: const Color(0xFF3B82F6),
                  isDark: isDark,
                )
              else if (isPresent)
                _buildTimeChip(
                  icon: Icons.timer_outlined,
                  label: 'متواجد داخل السنتر 🏫',
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              if (item.groupCode.isNotEmpty)
                _buildTimeChip(
                  icon: Icons.tag_rounded,
                  label: item.groupCode,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  isDark: isDark,
                ),
            ],
          ),

          // If absent: quick action button to request excuse
          if (isAbsent) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: BorderSide(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                    width: 0.9,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: onExcuseRequest,
                icon: const Icon(
                  Icons.note_add_rounded,
                  size: 15,
                  color: Color(0xFFEF4444),
                ),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'تقديم عذر رسمي لهذه الحصة 📝',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyAttendance(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.fact_check_outlined,
            size: 32,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'لا توجد حصص مسجلة في هذا السجل حالياً.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  static String _dayName(int weekday) {
    return switch (weekday) {
      DateTime.saturday => 'السبت',
      DateTime.sunday => 'الأحد',
      DateTime.monday => 'الإثنين',
      DateTime.tuesday => 'الثلاثاء',
      DateTime.wednesday => 'الأربعاء',
      DateTime.thursday => 'الخميس',
      DateTime.friday => 'الجمعة',
      _ => 'يوم الحصة',
    };
  }
}

// ─── 4. Absence Excuses & Requests Section ────────────────────────────────────

class _AbsenceExcusesSection extends StatelessWidget {
  final List<ParentLeaveItem> leaveRequests;
  final bool isDark;
  final bool isNarrow;
  final VoidCallback onNewExcuseRequest;

  const _AbsenceExcusesSection({
    required this.leaveRequests,
    required this.isDark,
    required this.isNarrow,
    required this.onNewExcuseRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: PortalSectionTitle(
                title: 'أعذار وإذونات الغياب المسجلة',
                subtitle: 'متابعة حالة قرارات الإدارة على طلبات الاعتذار المقدمة.',
              ),
            ),
            FilledButton.icon(
              onPressed: onNewExcuseRequest,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'طلب جديد',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (leaveRequests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 32,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  'لا توجد طلبات أعذار غياب مسجلة لهذا الطالب.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leaveRequests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final leave = leaveRequests[index];
              return _buildLeaveCard(leave, context);
            },
          ),
      ],
    );
  }

  Widget _buildLeaveCard(ParentLeaveItem leave, BuildContext context) {
    final status = leave.status.toLowerCase();
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';

    final Color statusColor;
    final String statusBadge;
    final IconData statusIcon;

    if (isApproved) {
      statusColor = const Color(0xFF10B981);
      statusBadge = 'تم قبول العذر واعتماده ✔️';
      statusIcon = Icons.check_circle_rounded;
    } else if (isRejected) {
      statusColor = const Color(0xFFEF4444);
      statusBadge = 'تم رفض الطلب ❌';
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusBadge = 'قيد المراجعة من الإدارة ⏳';
      statusIcon = Icons.pending_actions_rounded;
    }

    final submitDate = leave.submittedAt != null
        ? '${leave.submittedAt!.year}-${leave.submittedAt!.month.toString().padLeft(2, '0')}-${leave.submittedAt!.day.toString().padLeft(2, '0')}'
        : '';

    return GlassCard(
      padding: EdgeInsets.all(isNarrow ? 12 : 14),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, size: 20, color: statusColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leave.reason,
                      style: TextStyle(
                        fontSize: isNarrow ? 13 : 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${leave.groupName} • تاريخ التقديم: $submitDate',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  statusBadge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
