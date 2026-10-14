import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../viewmodels/groups_schedules_viewmodel.dart';

class GroupsSchedulesReportScreen extends StatefulWidget {
  const GroupsSchedulesReportScreen({super.key});

  @override
  State<GroupsSchedulesReportScreen> createState() =>
      _GroupsSchedulesReportScreenState();
}

class _GroupsSchedulesReportScreenState
    extends State<GroupsSchedulesReportScreen> {
  final ReportGeneratorService _reportService = getIt<ReportGeneratorService>();
  final GroupsSchedulesViewModel _viewModel = GroupsSchedulesViewModel();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChange);
    _viewModel.fetchGroupsData();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChange);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelChange() {
    setState(() {});
  }

  Future<void> _generateReport() async {
    if (_viewModel.groupsData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد مجموعات مسجلة لتصدير التقرير'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      await _reportService.generateGroupsSchedulesReport(
        groupsData: _viewModel.groupsData,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم استخراج تقرير المجموعات والجداول بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل استخراج التقرير: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('تقرير المجموعات والجداول 📅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _viewModel.isLoading || _isGenerating
                ? null
                : _generateReport,
            tooltip: 'تصدير كملف PDF',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _viewModel.fetchGroupsData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _viewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _viewModel.fetchGroupsData,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          'المجموعات الدراسية ومواعيد الحصص',
                          style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'نظرة شاملة على جميع المجموعات الفعالة ومواعيد الحصص الأسبوعية.',
                          style: AppTypography.bodySmall(textSecondary),
                        ),
                        const SizedBox(height: 20),

                        if (_viewModel.groupsData.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.group_off_rounded, size: 56, color: textSecondary),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد مجموعات دراسية مسجلة حالياً',
                                  style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'أضف مجموعات دراسية وجداول حصص لعرضها واستخراج تقاريرها.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodySmall(textSecondary),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._viewModel.groupsData.map((group) {
                            final isActive = group['is_active'] == true;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isActive
                                          ? Colors.green.withValues(alpha: 0.15)
                                          : Colors.grey.withValues(alpha: 0.15),
                                      child: Icon(
                                        isActive
                                            ? Icons.check_circle_rounded
                                            : Icons.pause_circle_rounded,
                                        color: isActive
                                            ? Colors.green
                                            : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            group['group_name'] ?? '',
                                            style: AppTypography.titleSmall(textPrimary).copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'الموعد: ${group['timing']}',
                                            style: AppTypography.bodySmall(textSecondary),
                                          ),
                                          Text(
                                            'المعلم: ${group['teacher']}',
                                            style: AppTypography.caption(textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? Colors.green.withValues(alpha: 0.12)
                                            : Colors.grey.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isActive ? 'نشطة' : 'متوقفة',
                                        style: TextStyle(
                                          color: isActive ? Colors.green : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
            if (_isGenerating)
              Container(
                color: Colors.black38,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
