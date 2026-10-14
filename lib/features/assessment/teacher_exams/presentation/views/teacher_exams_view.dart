import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../design_system/components/glass_card.dart';
import '../../../../../design_system/tokens/colors.dart';
import '../../../../../design_system/tokens/typography.dart';
import '../viewmodels/teacher_exams_view_model.dart';

class TeacherExamsView extends StatefulWidget {
  const TeacherExamsView({super.key});

  @override
  State<TeacherExamsView> createState() => _TeacherExamsViewState();
}

class _TeacherExamsViewState extends State<TeacherExamsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherExamsViewModel>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TeacherExamsViewModel>();

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'الاختبارات والتقييمات 📝',
          style: AppTypography.titleLarge(AppColors.darkTextPrimary),
        ),
      ),
      body: viewModel.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInSlide(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      'بنوك الأسئلة والمقررات',
                      style: AppTypography.titleMedium(
                        AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInSlide(
                    delay: const Duration(milliseconds: 200),
                    child: _buildQuestionBanksList(viewModel.questionBanks),
                  ),
                  const SizedBox(height: 32),
                  FadeInSlide(
                    delay: const Duration(milliseconds: 300),
                    child: Text(
                      'الاختبارات الحالية',
                      style: AppTypography.titleMedium(
                        AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInSlide(
                    delay: const Duration(milliseconds: 400),
                    child: _buildExamsList(viewModel.exams),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildQuestionBanksList(List<QuestionBankModel> banks) {
    if (banks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'لا توجد بنوك أسئلة مسجلة حالياً.',
            style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
          ),
        ),
      );
    }
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: banks.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final bank = banks[index];
          return GlassCard(
            width: 200,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    bank.subject,
                    style: AppTypography.caption(AppColors.primary),
                  ),
                ),
                const Spacer(),
                Text(
                  bank.name,
                  style: AppTypography.titleSmall(AppColors.darkTextPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${bank.questionCount} سؤال',
                  style: AppTypography.caption(AppColors.darkTextSecondary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExamsList(List<ExamModel> exams) {
    if (exams.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'لا توجد اختبارات مسجلة حالياً.',
            style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: exams.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final exam = exams[index];
        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_outlined, color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      style: AppTypography.titleSmall(
                        AppColors.darkTextPrimary,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${exam.subject} • ${exam.totalQuestions} درجة',
                      style: AppTypography.caption(AppColors.darkTextSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        exam.status,
                      ).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusLabel(exam.status),
                      style: AppTypography.caption(
                        _getStatusColor(exam.status),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(exam.dueDate),
                    style: AppTypography.caption(AppColors.darkTextSecondary),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
      case 'منشور':
        return AppColors.success;
      case 'draft':
      case 'مسودة':
        return AppColors.warning;
      case 'grading':
      case 'قيد التصحيح':
        return AppColors.info;
      default:
        return AppColors.darkTextSecondary;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return 'منشور';
      case 'draft':
        return 'مسودة';
      case 'grading':
        return 'قيد التصحيح';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
