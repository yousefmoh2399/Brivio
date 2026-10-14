import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../viewmodels/child_attendance_viewmodel.dart';

class ChildAttendanceScreen extends StatelessWidget {
  const ChildAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChildAttendanceViewModel(),
      child: const Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: _ChildAttendanceBody(),
      ),
    );
  }
}

class _ChildAttendanceBody extends StatelessWidget {
  const _ChildAttendanceBody();

  String _formatDate(DateTime date) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChildAttendanceViewModel>();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.darkBackground,
          pinned: true,
          title: const Text(
            'سجل الحضور والغياب والسلوك',
            style: TextStyle(
              color: AppColors.darkTextPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
        ),
        if (viewModel.isLoading)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatsCards(viewModel),
                const SizedBox(height: 28),
                const Text(
                  'سجل الغياب والتأخير الأخير',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildAttendanceList(viewModel.attendanceRecords),
                const SizedBox(height: 28),
                const Text(
                  'الملاحظات والسلوكيات',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBehaviorList(viewModel.behaviorRecords),
                const SizedBox(height: 40),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsCards(ChildAttendanceViewModel viewModel) {
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            borderColor: AppColors.error.withValues(alpha: 0.3),
            child: Column(
              children: [
                const Icon(
                  Icons.event_busy_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  '${viewModel.totalAbsences}',
                  style: const TextStyle(
                    color: AppColors.darkTextPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'مرات الغياب',
                  style: TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            borderColor: AppColors.warning.withValues(alpha: 0.3),
            child: Column(
              children: [
                const Icon(
                  Icons.watch_later_outlined,
                  color: AppColors.warning,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  '${viewModel.totalTardiness}',
                  style: const TextStyle(
                    color: AppColors.darkTextPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'مرات التأخير',
                  style: TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceList(List<AttendanceRecord> records) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'لا توجد غيابات أو تأخيرات مسجلة، الحضور منتظم تماماً 👏',
            style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
          ),
        ),
      );
    }
    return Column(
      children: records.map((r) {
        final isAbsent = r.status == 'absent';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isAbsent ? AppColors.error : AppColors.warning).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isAbsent ? Icons.cancel_outlined : Icons.schedule_rounded,
                    color: isAbsent ? AppColors.error : AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAbsent ? 'غياب' : 'تأخير عن الحصة',
                        style: const TextStyle(
                          color: AppColors.darkTextPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (r.note != null && r.note!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          r.note!,
                          style: const TextStyle(
                            color: AppColors.darkTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  _formatDate(r.date),
                  style: const TextStyle(
                    color: AppColors.darkTextTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBehaviorList(List<BehaviorRecord> records) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'لا توجد ملاحظات سلوكية مسجلة، سجل الطالب ممتاز 🌟',
            style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
          ),
        ),
      );
    }
    return Column(
      children: records.map((b) {
        final isPositive = b.type == 'positive';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isPositive ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPositive ? Icons.thumb_up_alt_outlined : Icons.warning_amber_rounded,
                    color: isPositive ? AppColors.success : AppColors.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.description,
                        style: const TextStyle(
                          color: AppColors.darkTextPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'المعلم: ${b.teacher}',
                        style: const TextStyle(
                          color: AppColors.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDate(b.date),
                  style: const TextStyle(
                    color: AppColors.darkTextTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
