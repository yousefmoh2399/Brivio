import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/study_workspace/domain/models/study_workspace_models.dart';
import '../../../features/study_workspace/presentation/screens/personal_whiteboards_hub_screen.dart';

class LearnTab extends StatefulWidget {
  final bool isLoading;
  final List<StudyLessonSummary> lessons;
  final List<GroupEntity> groups;
  final ValueChanged<StudyLessonSummary> onOpenLesson;
  final ValueChanged<GroupEntity> onOpenGroup;

  const LearnTab({
    super.key,
    required this.isLoading,
    required this.lessons,
    required this.groups,
    required this.onOpenLesson,
    required this.onOpenGroup,
  });

  @override
  State<LearnTab> createState() => _LearnTabState();
}

class _LearnTabState extends State<LearnTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, in_progress, completed, has_pdf, has_code
  final Set<String> _collapsedPaths = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() {
    HapticFeedback.lightImpact();
    setState(() {
      _searchCtrl.clear();
      _searchQuery = '';
      _selectedFilter = 'all';
    });
  }

  void _togglePathCollapse(String pathName) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_collapsedPaths.contains(pathName)) {
        _collapsedPaths.remove(pathName);
      } else {
        _collapsedPaths.add(pathName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    // Filter Lessons
    final filteredLessons = widget.lessons.where((lesson) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchesTitle = lesson.title.toLowerCase().contains(q);
        final matchesUnit = lesson.unitName.toLowerCase().contains(q);
        final matchesPath = lesson.pathName.toLowerCase().contains(q);
        if (!matchesTitle && !matchesUnit && !matchesPath) return false;
      }
      if (_selectedFilter == 'in_progress') {
        return lesson.progressPercentage > 0 && lesson.progressPercentage < 100;
      } else if (_selectedFilter == 'completed') {
        return lesson.progressPercentage >= 100;
      } else if (_selectedFilter == 'has_pdf') {
        return lesson.hasPdf;
      } else if (_selectedFilter == 'has_code') {
        return lesson.hasCodePlayground;
      }
      return true;
    }).toList();

    // Filter Groups
    final filteredGroups = widget.groups.where((g) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchesName = g.name.toLowerCase().contains(q);
        final matchesCode = g.code.toLowerCase().contains(q);
        if (!matchesName && !matchesCode) return false;
      }
      return true;
    }).toList();

    // Group filtered lessons by path
    final lessonsByPath = <String, List<StudyLessonSummary>>{};
    for (final lesson in filteredLessons) {
      lessonsByPath.putIfAbsent(lesson.pathName, () => []).add(lesson);
    }

    // Key Performance Indicators
    final totalLessons = widget.lessons.length;
    final completedCount = widget.lessons.where((l) => l.progressPercentage >= 100).length;
    final inProgressCount = widget.lessons.where((l) => l.progressPercentage > 0 && l.progressPercentage < 100).length;
    final overallProgress = totalLessons == 0 ? 0.0 : (completedCount / totalLessons);

    return LayoutBuilder(
      builder: (context, screenConstraints) {
        final width = screenConstraints.maxWidth;
        final isMobile = width < 600;
        final isNarrowMobile = width < 360;
        final horizontalPadding = isNarrowMobile ? 12.0 : (isMobile ? 16.0 : 24.0);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Sleek Responsive Sliver App Bar ──
                SliverAppBar(
                  backgroundColor: isDark
                      ? AppColors.darkBackground
                      : AppColors.lightBackground,
                  surfaceTintColor: Colors.transparent,
                  pinned: true,
                  floating: true,
                  titleSpacing: horizontalPadding,
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'الدروس والمناهج',
                          style: TextStyle(
                            fontSize: isNarrowMobile ? 16.5 : 19,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    // Smart Whiteboard & Sketch Hub
                    Container(
                      margin: EdgeInsets.only(left: horizontalPadding),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final uId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PersonalWhiteboardsHubScreen(
                                  userId: uId,
                                  role: 'student',
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.2),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.draw_rounded,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'سبورتي الذكية 🎨',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Loading Indicator ──
                if (widget.isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, 10, horizontalPadding, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // 1. Overall Academic KPI Strip
                        if (totalLessons > 0 || widget.groups.isNotEmpty) ...[
                          _buildKpiSummary(
                            context: context,
                            isDark: isDark,
                            isMobile: isMobile,
                            totalLessons: totalLessons,
                            completedCount: completedCount,
                            overallProgress: overallProgress,
                            groupsCount: widget.groups.length,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 2. Interactive Search & Quick Filter Bar
                        if (totalLessons > 0 || widget.groups.isNotEmpty) ...[
                          _buildSearchAndFilters(
                            isDark: isDark,
                            totalLessons: totalLessons,
                            completedCount: completedCount,
                            inProgressCount: inProgressCount,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          const SizedBox(height: 18),
                        ],

                        // 3. Learning Paths & Curricula
                        if (lessonsByPath.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'مسارات التعلم والمناهج 🗺️',
                                  style: TextStyle(
                                    fontSize: isNarrowMobile ? 13.5 : 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${lessonsByPath.length} مسارات',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final entry in lessonsByPath.entries) ...[
                            _LearningPathSection(
                              pathName: entry.key,
                              lessons: entry.value,
                              isCollapsed: _collapsedPaths.contains(entry.key),
                              onToggleCollapse: () => _togglePathCollapse(entry.key),
                              onOpenLesson: widget.onOpenLesson,
                              isMobile: isMobile,
                            ),
                            const SizedBox(height: 14),
                          ],
                          const SizedBox(height: 12),
                        ],

                        // 4. Enrolled Groups Section
                        if (filteredGroups.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'مجموعاتي الدراسية 🏛️',
                                  style: TextStyle(
                                    fontSize: isNarrowMobile ? 13.5 : 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${filteredGroups.length} مجموعات',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (width >= 680)
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredGroups.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 88,
                              ),
                              itemBuilder: (context, index) {
                                return _StudentGroupItemCard(
                                  group: filteredGroups[index],
                                  onTap: () => widget.onOpenGroup(filteredGroups[index]),
                                );
                              },
                            )
                          else
                            Column(
                              children: filteredGroups
                                  .map(
                                    (group) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _StudentGroupItemCard(
                                        group: group,
                                        onTap: () => widget.onOpenGroup(group),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],

                        // 5. Empty States
                        if (lessonsByPath.isEmpty && filteredGroups.isEmpty)
                          _buildEmptyState(
                            isDark: isDark,
                            hasFilter: _searchQuery.isNotEmpty || _selectedFilter != 'all',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onReset: _clearFilters,
                          ),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Top Academic KPI Overview ──
  Widget _buildKpiSummary({
    required BuildContext context,
    required bool isDark,
    required bool isMobile,
    required int totalLessons,
    required int completedCount,
    required double overallProgress,
    required int groupsCount,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final progressPercent = (overallProgress * 100).toInt();

    final item1 = _buildKpiBox(
      title: 'إنجاز المناهج',
      value: '$progressPercent%',
      icon: Icons.pie_chart_rounded,
      color: AppColors.primary,
      isDark: isDark,
      subText: '$completedCount من $totalLessons درس',
    );

    final item2 = _buildKpiBox(
      title: 'دروس متاحة',
      value: '$totalLessons',
      icon: Icons.play_lesson_rounded,
      color: const Color(0xFF10B981),
      isDark: isDark,
      subText: 'شروحات وتمارين',
    );

    final item3 = _buildKpiBox(
      title: 'مجموعاتي',
      value: '$groupsCount',
      icon: Icons.groups_2_rounded,
      color: const Color(0xFF6366F1),
      isDark: isDark,
      subText: 'مسجل ومعتمد',
    );

    final item4 = _buildKpiBox(
      title: 'مسودة المذاكرة',
      value: 'متاحة ✨',
      icon: Icons.brush_rounded,
      color: const Color(0xFFF59E0B),
      isDark: isDark,
      subText: 'رسم ومسودات',
    );

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: item1),
              const SizedBox(width: 8),
              Expanded(child: item2),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: item3),
              const SizedBox(width: 8),
              Expanded(child: item4),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: item1),
        const SizedBox(width: 10),
        Expanded(child: item2),
        const SizedBox(width: 10),
        Expanded(child: item3),
        const SizedBox(width: 10),
        Expanded(child: item4),
      ],
    );
  }

  Widget _buildKpiBox({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required String subText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search & Filter Controls ──
  Widget _buildSearchAndFilters({
    required bool isDark,
    required int totalLessons,
    required int completedCount,
    required int inProgressCount,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Column(
      children: [
        // Live Search Input Box
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: TextStyle(fontSize: 13, color: textPrimary),
            decoration: InputDecoration(
              hintText: 'ابحث عن درس، وحدة، أو منهج بالاسم...',
              hintStyle: TextStyle(fontSize: 12, color: textSecondary),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Quick Category Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterPill('all', 'الكل ($totalLessons)', Icons.apps_rounded, isDark),
              const SizedBox(width: 6),
              _buildFilterPill('in_progress', 'قيد المذاكرة ⏳ ($inProgressCount)', Icons.timelapse_rounded, isDark),
              const SizedBox(width: 6),
              _buildFilterPill('completed', 'المكتملة ✅ ($completedCount)', Icons.check_circle_rounded, isDark),
              const SizedBox(width: 6),
              _buildFilterPill('has_pdf', 'مذكرات PDF 📄', Icons.picture_as_pdf_rounded, isDark),
              const SizedBox(width: 6),
              _buildFilterPill('has_code', 'مختبر كود 💻', Icons.terminal_rounded, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(String id, String label, IconData icon, bool isDark) {
    final isSelected = _selectedFilter == id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedFilter = id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty State ──
  Widget _buildEmptyState({
    required bool isDark,
    required bool hasFilter,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onReset,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilter ? Icons.search_off_rounded : Icons.menu_book_rounded,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter
                ? 'لا توجد دروس مطابقة لمعايير البحث'
                : 'لا توجد دروس أو مناهج منشورة حتى الآن',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            hasFilter
                ? 'جرب البحث بكلمات مختلفة أو إزالة عوامل التصفية الحالية.'
                : 'ستظهر المحاضرات والمذكرات ومسارات التعلم هنا فور قيام المعلم بنشرها.',
            style: TextStyle(fontSize: 11.5, color: textSecondary),
            textAlign: TextAlign.center,
          ),
          if (hasFilter) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onReset,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('إعادة ضبط التصفية والبحث'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Enrolled Group Item Card ──
class _StudentGroupItemCard extends StatelessWidget {
  final GroupEntity group;
  final VoidCallback onTap;

  const _StudentGroupItemCard({
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.2),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.groups_2_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (group.code.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              group.code,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        Text(
                          group.maxCapacity != null
                              ? 'السعة: ${group.maxCapacity} طالب'
                              : 'المجموعة نشطة',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PortalStatusChip(status: group.status),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: textSecondary.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Interactive Learning Path Section ──
class _LearningPathSection extends StatelessWidget {
  final String pathName;
  final List<StudyLessonSummary> lessons;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<StudyLessonSummary> onOpenLesson;
  final bool isMobile;

  const _LearningPathSection({
    required this.pathName,
    required this.lessons,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.onOpenLesson,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final completeCount = lessons.where((l) => l.progressPercentage >= 100).length;
    final progress = lessons.isEmpty ? 0.0 : completeCount / lessons.length;
    final progressPercent = (progress * 100).toInt();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row (Clickable to collapse/expand)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggleCollapse,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(18),
                bottom: Radius.circular(isCollapsed ? 18 : 0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pathName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$completeCount من ${lessons.length} درس مكتمل • إنجاز $progressPercent%',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Collapse Indicator
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCollapsed
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            size: 18,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: isDark ? Colors.white10 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? const Color(0xFF10B981) : AppColors.primary,
                        ),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Collapsible Body: Grid or List of Lessons
          if (!isCollapsed) ...[
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 640;

                  if (isWide) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: lessons.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: 94,
                      ),
                      itemBuilder: (context, index) {
                        return _LessonCard(
                          lesson: lessons[index],
                          onOpen: () => onOpenLesson(lessons[index]),
                          isDark: isDark,
                        );
                      },
                    );
                  }

                  return Column(
                    children: lessons
                        .map(
                          (lesson) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _LessonCard(
                              lesson: lesson,
                              onOpen: () => onOpenLesson(lesson),
                              isDark: isDark,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Ultra-Sleek Lesson Card ──
class _LessonCard extends StatelessWidget {
  final StudyLessonSummary lesson;
  final VoidCallback onOpen;
  final bool isDark;

  const _LessonCard({
    required this.lesson,
    required this.onOpen,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = lesson.progressPercentage >= 100;
    final inProgress = lesson.progressPercentage > 0 && !isDone;

    final statusColor = isDone
        ? const Color(0xFF10B981)
        : (inProgress ? const Color(0xFFF59E0B) : AppColors.primary);

    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onOpen();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : AppColors.primary.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: statusColor.withValues(alpha: isDark ? 0.35 : 0.22),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              // Circular Status Indicator
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  isDone
                      ? Icons.check_circle_rounded
                      : (inProgress ? Icons.timelapse_rounded : Icons.play_arrow_rounded),
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              // Lesson Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lesson.title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            lesson.unitName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '• ${lesson.estimatedMinutes} د',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Feature Badges
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (isDone)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'مكتمل 100% ✨',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          )
                        else if (inProgress)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'مستمر ${lesson.progressPercentage}% ⏳',
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'جاهز للمذاكرة 🚀',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        if (lesson.hasPdf)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.picture_as_pdf_rounded, size: 9, color: Colors.red),
                                SizedBox(width: 2),
                                Text(
                                  'PDF',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (lesson.hasCodePlayground)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.terminal_rounded, size: 9, color: Color(0xFF10B981)),
                                SizedBox(width: 2),
                                Text(
                                  'كود',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Trailing Action Arrow
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: statusColor,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
