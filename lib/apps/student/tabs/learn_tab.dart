import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../features/academy/domain/models/academy_models.dart';
import '../../../design_system/widgets/portal_components.dart';
import '../../../features/study_workspace/domain/models/study_workspace_models.dart';
import '../../../features/study_workspace/presentation/screens/personal_whiteboards_hub_screen.dart';

class LearnTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    final lessonsByPath = <String, List<StudyLessonSummary>>{};
    for (final lesson in lessons) {
      lessonsByPath.putIfAbsent(lesson.pathName, () => []).add(lesson);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
          backgroundColor: isDark
              ? AppColors.darkBackground
              : AppColors.lightBackground,
          surfaceTintColor: Colors.transparent,
          pinned: true,
          title: Text(
            'الدروس والمناهج',
            style: AppTypography.displaySmall(
              textPrimary,
            ).copyWith(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          actions: [
            IconButton(
              tooltip: 'سبوراتي الذاتية ومسودات المذاكرة 🎨',
              onPressed: () {
                final uId =
                    Supabase.instance.client.auth.currentUser?.id ?? 'guest';
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
              icon: const Icon(
                Icons.draw_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        if (isLoading)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (lessonsByPath.isEmpty && groups.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 64,
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا يوجد محتوى دراسي حتى الآن',
                    style: AppTypography.titleLarge(
                      textPrimary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ستظهر الدروس والمذكرات هنا فور نشرها من قبل المعلم.',
                    style: AppTypography.bodyMedium(
                      isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Learning Paths ──
                if (lessonsByPath.isNotEmpty) ...[
                  FadeInSlide(
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      'مسارات التعلم والمناهج',
                      style: AppTypography.titleLarge(textPrimary).copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < lessonsByPath.entries.length; i++) ...[
                    FadeInSlide(
                      duration: const Duration(milliseconds: 600),
                      delay: Duration(milliseconds: 100 + (i * 100)),
                      child: _LearningPathSection(
                        pathName: lessonsByPath.entries.elementAt(i).key,
                        lessons: lessonsByPath.entries.elementAt(i).value,
                        onOpenLesson: onOpenLesson,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 24),
                ],

                // ── Groups ──
                if (groups.isNotEmpty) ...[
                  FadeInSlide(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 300),
                    child: Text(
                      'مجموعاتي الدراسية',
                      style: AppTypography.titleLarge(textPrimary).copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 400),
                    child: Column(
                      children: groups
                          .map(
                            (group) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _StudentGroupItemCard(
                                group: group,
                                onTap: () => onOpenGroup(group),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ]),
            ),
          ),
      ],
    ),
  ),
);
}
}

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

    return GlassCard(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.groups_2_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: AppTypography.titleMedium(textPrimary).copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (group.code.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                group.code,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              group.maxCapacity != null
                                  ? 'السعة القصوى: ${group.maxCapacity} طالب'
                                  : 'المجموعة نشطة',
                              style: AppTypography.caption(textSecondary).copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PortalStatusChip(status: group.status),
                    const SizedBox(height: 6),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: textSecondary.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LearningPathSection extends StatelessWidget {
  final String pathName;
  final List<StudyLessonSummary> lessons;
  final ValueChanged<StudyLessonSummary> onOpenLesson;

  const _LearningPathSection({
    required this.pathName,
    required this.lessons,
    required this.onOpenLesson,
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

    final complete = lessons.where((l) => l.progressPercentage >= 100).length;
    final progress = lessons.isEmpty ? 0.0 : complete / lessons.length;

    return GlassCard(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(
              Icons.route_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          title: Text(
            pathName,
            style: AppTypography.titleMedium(
              textPrimary,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$complete/${lessons.length} درس مكتمل',
                  style: AppTypography.caption(
                    textSecondary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          children: [
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            for (final lesson in lessons)
              _LessonRow(lesson: lesson, onOpen: () => onOpenLesson(lesson)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  final StudyLessonSummary lesson;
  final VoidCallback onOpen;

  const _LessonRow({required this.lesson, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final done = lesson.progressPercentage >= 100;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (done ? AppColors.success : AppColors.studentRole)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done ? Icons.check_rounded : Icons.play_arrow_rounded,
                  color: done ? AppColors.success : AppColors.studentRole,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: AppTypography.bodyMedium(
                        textPrimary,
                      ).copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lesson.unitName}  ·  ${lesson.estimatedMinutes} دقيقة  ·  ${lesson.progressPercentage}%',
                      style: AppTypography.caption(
                        textSecondary,
                      ).copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lesson.hasPdf)
                    const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.error,
                      size: 16,
                    ),
                  if (lesson.hasCodePlayground)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.terminal_rounded,
                        color: AppColors.success,
                        size: 16,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.primary,
                      size: 14,
                    ),
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
