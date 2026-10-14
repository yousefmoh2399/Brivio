import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/report_generator_service.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../viewmodels/reports_dashboard_viewmodel.dart';
import 'groups_schedules_report_screen.dart';

class ReportsDashboardScreen extends StatefulWidget {
  const ReportsDashboardScreen({super.key});

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  final ReportGeneratorService _reportService = getIt<ReportGeneratorService>();
  final ReportsDashboardViewModel _viewModel = ReportsDashboardViewModel();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _viewModel.loadData();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _generateReport(
    String title,
    List<dynamic> data,
    Future<void> Function() generateAction,
  ) async {
    setState(() => _isGenerating = true);
    try {
      await generateAction();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم استخراج وتصدير $title بنجاح! 📄'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل استخراج $title: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'لوحة التقارير الأكاديمية والمالية',
      subtitle:
          'استخراج وتصدير تقارير رسمية (PDF) معتمدة للطلاب، المعلمين، الحضور، الإيرادات والمناهج.',
      icon: Icons.assessment_rounded,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh_rounded,
          label: 'تحديث البيانات',
          onPressed: () => _viewModel.loadData(),
        ),
      ],
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () => _viewModel.loadData(),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                PortalMetricGrid(
                  children: [
                    PortalMetricCard(
                      label: 'درجات الطلاب والاختبارات',
                      value: 'تصدير PDF',
                      icon: Icons.school_rounded,
                      accentColor: Colors.blue,
                      onTap: () => _generateReport(
                        'تقرير درجات الطلاب',
                        _viewModel.studentsData,
                        () => _reportService.generateGradesReport(
                          className: 'كافة الطلاب',
                          studentsData: _viewModel.studentsData,
                        ),
                      ),
                    ),
                    PortalMetricCard(
                      label: 'سجلات ونسب الحضور',
                      value: 'تصدير PDF',
                      icon: Icons.event_note_rounded,
                      accentColor: Colors.green,
                      onTap: () => _generateReport(
                        'تقرير الحضور والغياب',
                        _viewModel.attendanceData,
                        () => _reportService.generateAttendanceReport(
                          className: 'كافة الطلاب',
                          attendanceData: _viewModel.attendanceData,
                        ),
                      ),
                    ),
                    PortalMetricCard(
                      label: 'التقرير المالي والإيرادات',
                      value: 'تصدير PDF',
                      icon: Icons.monetization_on_rounded,
                      accentColor: Colors.orange,
                      onTap: () => _generateReport(
                        'التقرير المالي',
                        _viewModel.financialData,
                        () => _reportService.generateFinancialReport(
                          financialData: _viewModel.financialData,
                        ),
                      ),
                    ),
                    PortalMetricCard(
                      label: 'أداء وتقييم المعلمين',
                      value: 'تصدير PDF',
                      icon: Icons.person_search_rounded,
                      accentColor: Colors.purple,
                      onTap: () => _generateReport(
                        'تقرير أداء المعلمين',
                        _viewModel.teacherData,
                        () => _reportService.generateTeacherMetricsReport(
                          teacherData: _viewModel.teacherData,
                        ),
                      ),
                    ),
                    PortalMetricCard(
                      label: 'جداول الحصص والمجموعات',
                      value: 'عرض الجداول',
                      icon: Icons.schedule_rounded,
                      accentColor: Colors.teal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const GroupsSchedulesReportScreen(),
                          ),
                        );
                      },
                    ),
                    PortalMetricCard(
                      label: 'بيانات أولياء الأمور',
                      value: 'تصدير PDF',
                      icon: Icons.family_restroom_rounded,
                      accentColor: Colors.deepPurple,
                      onTap: () => _generateReport(
                        'تقرير أولياء الأمور',
                        _viewModel.parentsData,
                        () => _reportService.generateParentsReport(
                          parentsData: _viewModel.parentsData,
                        ),
                      ),
                    ),
                    PortalMetricCard(
                      label: 'متابعة الواجبات المدرسية',
                      value: 'تصدير PDF',
                      icon: Icons.menu_book_rounded,
                      accentColor: Colors.brown,
                      onTap: () => _generateReport(
                        'تقرير تسليم الواجبات',
                        _viewModel.homeworkData,
                        () => _reportService.generateHomeworkReport(
                          homeworkData: _viewModel.homeworkData,
                        ),
                      ),
                    ),
                    PortalMetricCard(
                      label: 'المناهج وخطة التدريس',
                      value: 'تصدير PDF',
                      icon: Icons.library_books_rounded,
                      accentColor: Colors.blueGrey,
                      onTap: () => _generateReport(
                        'تقرير المناهج الدراسية',
                        _viewModel.curriculumData,
                        () => _reportService.generateCurriculumReport(
                          curriculumData: _viewModel.curriculumData,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isGenerating || _viewModel.isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    },
  ),
);
}
}
