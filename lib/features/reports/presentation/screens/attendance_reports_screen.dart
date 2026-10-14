import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../viewmodels/attendance_reports_viewmodel.dart';

class AttendanceReportsScreen extends StatefulWidget {
  const AttendanceReportsScreen({super.key});

  @override
  State<AttendanceReportsScreen> createState() =>
      _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState extends State<AttendanceReportsScreen>
    with SingleTickerProviderStateMixin {
  final ReportGeneratorService _reportService = getIt<ReportGeneratorService>();
  final AttendanceReportsViewModel _viewModel = AttendanceReportsViewModel();
  late TabController _tabController;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _viewModel.loadData();
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generatePdf(
    String groupName,
    List<Map<String, dynamic>> data,
    String personType,
  ) async {
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا توجد سجلات حضور مسجلة لـ $groupName'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      await _reportService.generateAttendanceReport(
        className: groupName,
        attendanceData: data,
        personType: personType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم استخراج تقرير حضور $groupName بنجاح!'),
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
        title: const Text('تقارير وسجلات الحضور والغياب 📋'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _viewModel.loadData(),
            tooltip: 'تحديث',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'الطلاب'),
            Tab(text: 'المعلمون'),
            Tab(text: 'الكادر الإداري'),
          ],
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_viewModel.isLoading)
              const Center(child: CircularProgressIndicator())
            else
              TabBarView(
                controller: _tabController,
                children: [
                  _buildReportTab(
                    'الطلاب',
                    _viewModel.studentAttendance,
                    'طالب',
                    textPrimary,
                    textSecondary,
                    isDark,
                  ),
                  _buildReportTab(
                    'المعلمين',
                    _viewModel.teacherAttendance,
                    'معلم',
                    textPrimary,
                    textSecondary,
                    isDark,
                  ),
                  _buildReportTab(
                    'الكادر الإداري',
                    _viewModel.staffAttendance,
                    'موظف إداري',
                    textPrimary,
                    textSecondary,
                    isDark,
                  ),
                ],
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

  Widget _buildReportTab(
    String groupName,
    List<Map<String, dynamic>> data,
    String personType,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return RefreshIndicator(
      onRefresh: () => _viewModel.loadData(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سجل حضور $groupName',
                      style: AppTypography.titleLarge(textPrimary).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'إجمالي السجلات المسجلة: ${data.length}',
                      style: AppTypography.caption(textSecondary),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _generatePdf(groupName, data, personType),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text('تصدير PDF'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (data.isEmpty)
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
                  Icon(Icons.event_available_rounded, size: 56, color: textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد سجلات حضور مسجلة لـ $groupName',
                    style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يتم تسجيل الحضور تلقائياً عند مسح باركود الـ QR عند الدخول أو التسجيل اليدوي.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall(textSecondary),
                  ),
                ],
              ),
            )
          else
            ...data.map((item) {
              final present = (item['present'] as num?)?.toInt() ?? 0;
              final absent = (item['absent'] as num?)?.toInt() ?? 0;
              final total = present + absent;
              final rate = total > 0 ? (present / total) * 100 : 100.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          (item['name']?.toString() ?? 'م')[0],
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] ?? '',
                              style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'حضور: $present مرة • غياب: $absent مرة',
                              style: AppTypography.caption(textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (rate >= 85 ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${rate.toStringAsFixed(0)}% التزام',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: rate >= 85 ? Colors.green : Colors.orange,
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
    );
  }
}
