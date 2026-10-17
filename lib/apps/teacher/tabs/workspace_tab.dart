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
import '../../../features/academy/presentation/screens/teacher_assistants_screen.dart';
import '../../../features/assessment/presentation/screens/smart_exam_generator_dialog.dart';
import '../../../features/communication/presentation/screens/class_broadcast_dialog.dart';
import '../../../core/services/report_generator_service.dart';

class WorkspaceTab extends StatefulWidget {
  final String teacherId;

  const WorkspaceTab({super.key, required this.teacherId});

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInSlide(
                duration: const Duration(milliseconds: 400),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 640;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'مساحة العمل الأكاديمية',
                            style: AppTypography.displaySmall(textPrimary).copyWith(
                              fontSize: isCompact ? 18 : 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCompact) ...[
                          IconButton(
                            tooltip: 'السبورة الذكية للشرح 🎨',
                            icon: const Icon(Icons.draw_rounded, color: Colors.teal, size: 22),
                            onPressed: () {
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
                          PopupMenuButton<int>(
                            icon: const Icon(Icons.more_horiz_rounded),
                            tooltip: 'أدوات إضافية',
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            onSelected: (val) async {
                              switch (val) {
                                case 1:
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const TeacherAssistantsScreen(),
                                    ),
                                  );
                                  break;
                                case 2:
                                  ClassBroadcastDialog.show(
                                    context,
                                    groupName: 'المجموعة الدراسية',
                                  );
                                  break;
                                case 3:
                                  SmartExamGeneratorDialog.show(
                                    context,
                                    subjectName: 'المادة الدراسية',
                                  );
                                  break;
                                case 4:
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
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 1,
                                child: Row(
                                  children: [
                                    Icon(Icons.people_outline_rounded, color: AppColors.primary, size: 18),
                                    SizedBox(width: 8),
                                    Text('طاقم المساعدين (TAs)'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 2,
                                child: Row(
                                  children: [
                                    Icon(Icons.campaign_outlined, color: Colors.amber, size: 18),
                                    SizedBox(width: 8),
                                    Text('إذاعة تنبيه للمجموعة'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 3,
                                child: Row(
                                  children: [
                                    Icon(Icons.auto_awesome_rounded, color: Colors.purple, size: 18),
                                    SizedBox(width: 8),
                                    Text('توليد امتحان ذكي متوازن'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 4,
                                child: Row(
                                  children: [
                                    Icon(Icons.fact_check_outlined, color: Colors.teal, size: 18),
                                    SizedBox(width: 8),
                                    Text('طباعة نموذج بابل شيت فارغ'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ] else
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'السبورة الذكية للشرح 🎨',
                                icon: const Icon(Icons.draw_rounded, color: Colors.teal),
                                onPressed: () {
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
                              IconButton(
                                tooltip: 'طاقم المساعدين (TAs) 👥',
                                icon: const Icon(Icons.people_outline_rounded, color: AppColors.primary),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const TeacherAssistantsScreen(),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: 'إذاعة تنبيه للمجموعة 📢',
                                icon: const Icon(Icons.campaign_outlined, color: Colors.amber),
                                onPressed: () {
                                  ClassBroadcastDialog.show(
                                    context,
                                    groupName: 'المجموعة الدراسية',
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: 'توليد امتحان ذكي متوازن ⚡',
                                icon: const Icon(Icons.auto_awesome_rounded, color: Colors.purple),
                                onPressed: () {
                                  SmartExamGeneratorDialog.show(
                                    context,
                                    subjectName: 'المادة الدراسية',
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: 'طباعة نموذج بابل شيت فارغ 📑',
                                icon: const Icon(Icons.fact_check_outlined, color: Colors.teal),
                                onPressed: () async {
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
                                },
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 100),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: textPrimary,
                    unselectedLabelColor: textPrimary.withValues(alpha: 0.5),
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
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
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              TeacherQuestionBankScreen(teacherId: widget.teacherId),
              TeacherHomeworkScreen(teacherId: widget.teacherId),
              TeacherExamScreen(teacherId: widget.teacherId),
              TeacherAttendanceScreen(teacherId: widget.teacherId),
              TeacherGradingScreen(teacherId: widget.teacherId),
              StudyReplayScreen(teacherId: widget.teacherId),
            ],
          ),
        ),
      ],
    ),
  ),
);
  }
}
