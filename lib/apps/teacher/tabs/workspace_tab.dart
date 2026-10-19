import 'package:flutter/material.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../design_system/components/glass_card.dart';
import '../../../features/assessment/presentation/screens/teacher_exam_screen.dart';
import '../../../features/assessment/presentation/screens/teacher_grading_screen.dart';
import '../../../features/assessment/presentation/screens/teacher_homework_screen.dart';
import '../../../features/assessment/presentation/screens/teacher_question_bank_screen.dart';
import '../../../features/attendance/presentation/screens/teacher_session_board_screen.dart';
import '../../../features/attendance/presentation/screens/teacher_attendance_screen.dart';
import '../../../features/study_workspace/presentation/screens/study_replay_screen.dart';
import '../../../features/study_workspace/presentation/screens/personal_whiteboards_hub_screen.dart';
import '../../../features/academy/presentation/screens/teacher_assistants_screen.dart';
import '../../../features/assessment/presentation/screens/smart_exam_generator_dialog.dart';
import '../../../features/communication/presentation/screens/class_broadcast_dialog.dart';
import '../../../core/services/report_generator_service.dart';

class WorkspaceTab extends StatefulWidget {
  final String teacherId;
  final Widget? questionBankScreen;
  final Widget? homeworkScreen;
  final Widget? examScreen;
  final Widget? attendanceScreen;
  final Widget? gradingScreen;
  final Widget? replayScreen;

  const WorkspaceTab({
    super.key,
    required this.teacherId,
    this.questionBankScreen,
    this.homeworkScreen,
    this.examScreen,
    this.attendanceScreen,
    this.gradingScreen,
    this.replayScreen,
  });

  @override
  State<WorkspaceTab> createState() => _WorkspaceTabState();
}

class _WorkspaceTabState extends State<WorkspaceTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleBubbleSheetGeneration(BuildContext context) async {
    try {
      await ReportGeneratorService().generateStandaloneBubbleSheetPdf(
        centerName: 'المركز التعليمي',
        teacherName: 'معلم المادة',
        examTitle: 'نموذج إجابة بابل شيت عام',
        questionCount: 30,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم توليد نموذج البابل شيت بنجاح 📑'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل توليد البابل شيت: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    final bgColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          children: [
            Container(
              color: bgColor,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInSlide(
                    duration: const Duration(milliseconds: 350),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 640;
                        final isUltraCompact = constraints.maxWidth < 360;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header context chips
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.build_circle_rounded,
                                          size: 13,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'مركز الأدوات الأكاديمية',
                                            style: TextStyle(
                                              fontSize: isUltraCompact ? 10 : 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.purple.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 12,
                                        color: Colors.purple,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'الذكاء الاصطناعي ⚡',
                                        style: TextStyle(
                                          fontSize: isUltraCompact ? 9 : 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Title & Subtitle
                            Text(
                              'مساحة العمل الأكاديمية',
                              style: AppTypography.displaySmall(textPrimary).copyWith(
                                fontSize: isUltraCompact ? 18 : (isCompact ? 21 : 25),
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'إدارة شاملة لبنك الأسئلة، التكليفات، الاختبارات، الحضور، والتصحيح الذكي.',
                              style: TextStyle(
                                fontSize: isUltraCompact ? 11 : 12,
                                color: textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Executive Smart Tools Action Strip
                  FadeInSlide(
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 50),
                    child: _buildQuickActionsStrip(context, isDark, textPrimary, textSecondary),
                  ),
                  const SizedBox(height: 12),
                  // Segmented Modern TabBar
                  FadeInSlide(
                    duration: const Duration(milliseconds: 450),
                    delay: const Duration(milliseconds: 100),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabCtrl,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: textPrimary.withValues(alpha: 0.6),
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: const [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.quiz_outlined, size: 16),
                                SizedBox(width: 6),
                                Text('بنك الأسئلة'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.assignment_outlined, size: 16),
                                SizedBox(width: 6),
                                Text('الواجبات والتكليفات'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.description_outlined, size: 16),
                                SizedBox(width: 6),
                                Text('الامتحانات'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.co_present_outlined, size: 16),
                                SizedBox(width: 6),
                                Text('الحصص والغياب'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.grading_outlined, size: 16),
                                SizedBox(width: 6),
                                Text('التصحيح والرصد'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_circle_outline_rounded, size: 16),
                                SizedBox(width: 6),
                                Text('إعادة الحصص (Replay)'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  widget.questionBankScreen ??
                      TeacherQuestionBankScreen(teacherId: widget.teacherId),
                  widget.homeworkScreen ??
                      TeacherHomeworkScreen(teacherId: widget.teacherId),
                  widget.examScreen ??
                      TeacherExamScreen(teacherId: widget.teacherId),
                  widget.attendanceScreen ??
                      TeacherAttendanceScreen(teacherId: widget.teacherId),
                  widget.gradingScreen ??
                      TeacherGradingScreen(teacherId: widget.teacherId),
                  widget.replayScreen ??
                      StudyReplayScreen(
                        teacherId: widget.teacherId,
                        isEmbedded: true,
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsStrip(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final actions = [
      _QuickToolItem(
        title: 'السبورة الذكية',
        subtitle: 'شرح تفاعلي',
        icon: Icons.draw_rounded,
        accentColor: Colors.teal,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherSessionBoardScreen(
                teacherId: widget.teacherId,
              ),
            ),
          );
        },
      ),
      _QuickToolItem(
        title: 'سبوراتي ومسوداتي',
        subtitle: 'تحضير الدروس',
        icon: Icons.auto_stories_rounded,
        accentColor: Colors.purple,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PersonalWhiteboardsHubScreen(
                userId: widget.teacherId,
                role: 'teacher',
              ),
            ),
          );
        },
      ),
      _QuickToolItem(
        title: 'توليد امتحان ذكي',
        subtitle: 'صياغة الذكاء الاصطناعي',
        icon: Icons.auto_awesome_rounded,
        accentColor: Colors.deepOrange,
        onTap: () {
          SmartExamGeneratorDialog.show(
            context,
            teacherId: widget.teacherId,
          );
        },
      ),
      _QuickToolItem(
        title: 'طباعة بابل شيت',
        subtitle: 'نموذج إجابة جاهز',
        icon: Icons.fact_check_outlined,
        accentColor: Colors.green,
        onTap: () => _handleBubbleSheetGeneration(context),
      ),
      _QuickToolItem(
        title: 'إذاعة تنبيه',
        subtitle: 'إشعار فوري للطلاب',
        icon: Icons.campaign_outlined,
        accentColor: Colors.amber.shade800,
        onTap: () {
          ClassBroadcastDialog.show(
            context,
            groupName: 'المجموعة الدراسية',
          );
        },
      ),
      _QuickToolItem(
        title: 'طاقم المساعدين',
        subtitle: 'إدارة الـ TAs',
        icon: Icons.people_outline_rounded,
        accentColor: AppColors.primary,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TeacherAssistantsScreen(),
            ),
          );
        },
      ),
    ];

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final a = actions[i];
          return InkWell(
            onTap: a.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: a.accentColor.withValues(alpha: isDark ? 0.25 : 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: a.accentColor.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: a.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(a.icon, color: a.accentColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        a.title,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.subtitle,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickToolItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _QuickToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });
}
