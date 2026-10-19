import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../viewmodels/reports_dashboard_viewmodel.dart';
import 'attendance_reports_screen.dart';
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
  String? _generatingReportId;
  String _selectedCategory = 'all'; // 'all', 'academic', 'admin', 'attendance'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel.loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _generateReport(
    String id,
    String title,
    List<dynamic> data,
    Future<void> Function() generateAction,
  ) async {
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('لا توجد سجلات مسجلة لاستخراج $title حالياً.'),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatingReportId = id;
    });

    try {
      await generateAction();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('تم استخراج وتصدير $title بنجاح! 📄'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('فشل استخراج $title: $e'),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generatingReportId = null;
        });
      }
    }
  }

  List<_ReportDefinition> _buildReportDefinitions() {
    return [
      _ReportDefinition(
        id: 'grades',
        title: 'درجات الطلاب والاختبارات',
        category: 'academic',
        icon: Icons.school_rounded,
        accentColor: const Color(0xFF2563EB),
        count: _viewModel.studentsData.length,
        countUnit: 'طالب مسجل',
        description:
            'كشف تفصيلي بنتائج الاختبارات الشهرية، متوسط درجات الواجبات، ونسب التحصيل للطلاب.',
        buttonLabel: 'تصدير تقرير PDF',
        onExport: () => _generateReport(
          'grades',
          'تقرير درجات الطلاب',
          _viewModel.studentsData,
          () => _reportService.generateGradesReport(
            className: 'كافة الطلاب',
            studentsData: _viewModel.studentsData,
          ),
        ),
      ),
      _ReportDefinition(
        id: 'attendance',
        title: 'سجلات ونسب الحضور',
        category: 'attendance',
        icon: Icons.event_note_rounded,
        accentColor: const Color(0xFF10B981),
        count: _viewModel.attendanceData.length,
        countUnit: 'سجل حضور',
        description:
            'بيان شامل لحالات الحضور، الغياب، التأخير، ونسب الانضباط الأكاديمي للطلاب.',
        buttonLabel: 'تصدير تقرير PDF',
        secondaryButtonLabel: 'تقارير تفصيلية',
        onSecondaryAction: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AttendanceReportsScreen(),
            ),
          );
        },
        onExport: () => _generateReport(
          'attendance',
          'تقرير الحضور والغياب',
          _viewModel.attendanceData,
          () => _reportService.generateAttendanceReport(
            className: 'كافة الطلاب',
            attendanceData: _viewModel.attendanceData,
          ),
        ),
      ),
      _ReportDefinition(
        id: 'finance',
        title: 'التقرير المالي والإيرادات',
        category: 'admin',
        icon: Icons.monetization_on_rounded,
        accentColor: const Color(0xFFF59E0B),
        count: _viewModel.financialData.length,
        countUnit: 'معاملة مالية',
        description:
            'ملخص تدفقات الإيرادات، المصروفات التشغيلية، وأرصدة الاشتراكات والمدفوعات المتبقية.',
        buttonLabel: 'تصدير تقرير PDF',
        onExport: () => _generateReport(
          'finance',
          'التقرير المالي والإيرادات',
          _viewModel.financialData,
          () => _reportService.generateFinancialReport(
            financialData: _viewModel.financialData,
          ),
        ),
      ),
      _ReportDefinition(
        id: 'teachers',
        title: 'أداء وتقييم المعلمين',
        category: 'admin',
        icon: Icons.person_search_rounded,
        accentColor: const Color(0xFF8B5CF6),
        count: _viewModel.teacherData.length,
        countUnit: 'معلم مسجل',
        description:
            'مؤشرات الأداء التدريسي، عدد الحصص المنفذة، ودرجات رضا وتقييم الطلاب.',
        buttonLabel: 'تصدير تقرير PDF',
        onExport: () => _generateReport(
          'teachers',
          'تقرير أداء المعلمين',
          _viewModel.teacherData,
          () => _reportService.generateTeacherMetricsReport(
            teacherData: _viewModel.teacherData,
          ),
        ),
      ),
      _ReportDefinition(
        id: 'schedules',
        title: 'جداول الحصص والمجموعات',
        category: 'attendance',
        icon: Icons.schedule_rounded,
        accentColor: const Color(0xFF0D9488),
        count: _viewModel.groupsCount,
        countUnit: 'مجموعات وجداول نشطة',
        description:
            'استعراض تفاعلي لجميع المجموعات الدراسية، مواعيد الحصص الأسبوعية، والمعلمين المكلفين.',
        buttonLabel: 'عرض وتصدير الجداول',
        onExport: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const GroupsSchedulesReportScreen(),
            ),
          );
        },
      ),
      _ReportDefinition(
        id: 'parents',
        title: 'بيانات أولياء الأمور',
        category: 'admin',
        icon: Icons.family_restroom_rounded,
        accentColor: const Color(0xFF6366F1),
        count: _viewModel.parentsData.length,
        countUnit: 'ولي أمر',
        description:
            'دليل بيانات التواصل مع أولياء الأمور، ربط الطلاب، وسجلات المتابعة والتبليغ.',
        buttonLabel: 'تصدير تقرير PDF',
        onExport: () => _generateReport(
          'parents',
          'تقرير أولياء الأمور',
          _viewModel.parentsData,
          () => _reportService.generateParentsReport(
            parentsData: _viewModel.parentsData,
          ),
        ),
      ),
      _ReportDefinition(
        id: 'homework',
        title: 'متابعة الواجبات المدرسية',
        category: 'academic',
        icon: Icons.menu_book_rounded,
        accentColor: const Color(0xFFD97706),
        count: _viewModel.homeworkData.length,
        countUnit: 'سجل واجبات',
        description:
            'معدلات تسليم الواجبات المنزلية، المهام المتأخرة، ومتوسط الدرجات المستحقة.',
        buttonLabel: 'تصدير تقرير PDF',
        onExport: () => _generateReport(
          'homework',
          'تقرير تسليم الواجبات',
          _viewModel.homeworkData,
          () => _reportService.generateHomeworkReport(
            homeworkData: _viewModel.homeworkData,
          ),
        ),
      ),
      _ReportDefinition(
        id: 'curriculum',
        title: 'المناهج وخطة التدريس',
        category: 'academic',
        icon: Icons.library_books_rounded,
        accentColor: const Color(0xFF64748B),
        count: _viewModel.curriculumData.length,
        countUnit: 'وحدة/درس',
        description:
            'نسب إنجاز وتغطية الخطط الدراسية، الفصول المعتمدة، والمحتوى التعليمي المقرّر.',
        buttonLabel: 'تصدير تقرير PDF',
        onExport: () => _generateReport(
          'curriculum',
          'تقرير المناهج الدراسية',
          _viewModel.curriculumData,
          () => _reportService.generateCurriculumReport(
            curriculumData: _viewModel.curriculumData,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return PortalPageShell(
      title: 'لوحة التقارير الأكاديمية والمالية',
      subtitle:
          'استخراج وتصدير تقارير رسمية (PDF) معتمدة للطلاب، المعلمين، الحضور، الإيرادات والمناهج.',
      icon: Icons.assessment_rounded,
      accentColor: AppColors.adminRole,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 12,
      ),
      actions: [
        PortalAction(
          icon: Icons.refresh_rounded,
          label: 'تحديث البيانات',
          onPressed: () {
            if (!_viewModel.isLoading) {
              _viewModel.loadData();
            }
          },
        ),
      ],
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final allReports = _buildReportDefinitions();

          // Filter by category
          var filteredReports = allReports;
          if (_selectedCategory != 'all') {
            filteredReports = filteredReports
                .where((r) => r.category == _selectedCategory)
                .toList();
          }

          // Filter by search query
          if (_searchQuery.trim().isNotEmpty) {
            final query = _searchQuery.trim().toLowerCase();
            filteredReports = filteredReports.where((r) {
              return r.title.toLowerCase().contains(query) ||
                  r.description.toLowerCase().contains(query);
            }).toList();
          }

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () => _viewModel.loadData(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    vertical: isMobile ? 8 : 12,
                  ),
                  children: [
                    // 1. KPI Summary Strip
                    _buildKpiSummary(context, screenWidth, isDark),
                    const SizedBox(height: 16),

                    // 2. Search & Category Filter Section
                    _buildFilterSection(
                      context,
                      isMobile,
                      isDark,
                      textPrimary,
                      textSecondary,
                      allReports.length,
                    ),
                    const SizedBox(height: 16),

                    // 3. Grid of Report Cards
                    if (filteredReports.isEmpty)
                      _buildEmptyState(textPrimary, textSecondary, isDark)
                    else
                      _buildReportsGrid(
                        context,
                        screenWidth,
                        filteredReports,
                        isDark,
                        textPrimary,
                        textSecondary,
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),

              // Full Loading or PDF generation indicator overlay
              if (_isGenerating || _viewModel.isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkCard
                              : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              _isGenerating
                                  ? 'جارٍ تجهيز واستخراج ملف PDF المعتمد...'
                                  : 'جارٍ تحديث وتدقيق بيانات التقارير...',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // KPI Summary Strip
  // ==========================================
  Widget _buildKpiSummary(
    BuildContext context,
    double screenWidth,
    bool isDark,
  ) {
    final kpiItems = [
      _KpiStat(
        title: 'الطلاب والأكاديمي',
        value: '${_viewModel.studentsData.length}',
        unit: 'طالب مسجل',
        icon: Icons.school_rounded,
        color: const Color(0xFF2563EB),
      ),
      _KpiStat(
        title: 'سجلات الحضور',
        value: '${_viewModel.attendanceData.length}',
        unit: 'سجل رصد',
        icon: Icons.event_available_rounded,
        color: const Color(0xFF10B981),
      ),
      _KpiStat(
        title: 'العمليات المالية',
        value: '${_viewModel.financialData.length}',
        unit: 'معاملة مسجلة',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFFF59E0B),
      ),
      _KpiStat(
        title: 'المعلمون والمناهج',
        value: '${_viewModel.teacherData.length + _viewModel.curriculumData.length}',
        unit: 'عنصر تدريسي',
        icon: Icons.co_present_rounded,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    if (screenWidth >= 900) {
      // 4 cards in a Row on Desktop
      return Row(
        children: kpiItems.map((stat) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _buildKpiCard(stat, isDark),
            ),
          );
        }).toList(),
      );
    }

    // 2x2 grid on Tablet and Mobile
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kpiItems.map((stat) {
            final cardWidth = (constraints.maxWidth - 8) / 2;
            return SizedBox(
              width: cardWidth,
              child: _buildKpiCard(stat, isDark),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(_KpiStat stat, bool isDark) {
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(stat.icon, color: stat.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      stat.value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        stat.unit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  stat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Filter & Search Section
  // ==========================================
  Widget _buildFilterSection(
    BuildContext context,
    bool isMobile,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    int totalCount,
  ) {
    final searchField = TextField(
      controller: _searchController,
      onChanged: (val) => setState(() => _searchQuery = val),
      decoration: InputDecoration(
        hintText: 'بحث في التقارير المتاحة...',
        hintStyle: TextStyle(fontSize: 12.5, color: textSecondary),
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: textSecondary),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      style: TextStyle(fontSize: 13, color: textPrimary),
    );

    final categories = [
      {'id': 'all', 'label': 'الكل ($totalCount)'},
      {'id': 'academic', 'label': 'أكاديمي وطلاب'},
      {'id': 'admin', 'label': 'مالي وإداري'},
      {'id': 'attendance', 'label': 'حضور وجداول'},
    ];

    final chipsList = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat['id'];
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: ChoiceChip(
              selected: isSelected,
              showCheckmark: false,
              label: Text(
                cat['label']!,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : textSecondary,
                ),
              ),
              selectedColor: AppColors.primary,
              backgroundColor:
                  isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedCategory = cat['id']!);
                }
              },
            ),
          );
        }).toList(),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          const SizedBox(height: 10),
          chipsList,
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 3, child: chipsList),
        const SizedBox(width: 14),
        Expanded(flex: 2, child: searchField),
      ],
    );
  }

  // ==========================================
  // Reports Grid (Responsive Layout)
  // ==========================================
  Widget _buildReportsGrid(
    BuildContext context,
    double screenWidth,
    List<_ReportDefinition> reports,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (screenWidth < 650) {
      // 1 column list on Mobile for optimum readability & zero truncation
      return Column(
        children: reports.map((report) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildReportCard(
              context,
              report,
              isDark,
              textPrimary,
              textSecondary,
            ),
          );
        }).toList(),
      );
    }

    // Grid layout for Tablet (2 cols) and Desktop (3 cols)
    final int crossAxisCount = screenWidth >= 1050 ? 3 : 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = (crossAxisCount - 1) * 12.0;
        final itemWidth = (constraints.maxWidth - totalSpacing) / crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: reports.map((report) {
            return SizedBox(
              width: itemWidth,
              child: _buildReportCard(
                context,
                report,
                isDark,
                textPrimary,
                textSecondary,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ==========================================
  // Report Card Component
  // ==========================================
  Widget _buildReportCard(
    BuildContext context,
    _ReportDefinition report,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isCurrentGenerating =
        _isGenerating && _generatingReportId == report.id;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? report.accentColor.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title + Count Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: report.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  report.icon,
                  color: report.accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: report.accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        report.count != null
                            ? '${report.count} ${report.countUnit}'
                            : report.countUnit,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: report.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description Body
          Text(
            report.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: textSecondary,
            ),
          ),

          const SizedBox(height: 14),

          // Action Buttons
          if (report.secondaryButtonLabel != null &&
              report.onSecondaryAction != null) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildExportButton(report, isCurrentGenerating),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: report.onSecondaryAction,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: report.accentColor,
                      side: BorderSide(
                        color: report.accentColor.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      report.secondaryButtonLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: _buildExportButton(report, isCurrentGenerating),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExportButton(
    _ReportDefinition report,
    bool isCurrentGenerating,
  ) {
    return FilledButton.icon(
      onPressed: (_isGenerating || _viewModel.isLoading)
          ? null
          : report.onExport,
      style: FilledButton.styleFrom(
        backgroundColor: report.accentColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: report.accentColor.withValues(alpha: 0.4),
        disabledForegroundColor: Colors.white70,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: isCurrentGenerating
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              report.id == 'schedules'
                  ? Icons.open_in_new_rounded
                  : Icons.picture_as_pdf_rounded,
              size: 16,
            ),
      label: Text(
        isCurrentGenerating ? 'جارٍ التصدير...' : report.buttonLabel,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ==========================================
  // Empty Filter State
  // ==========================================
  Widget _buildEmptyState(
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'لا توجد تقارير مطابقة لمعايير البحث',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'جرّب تغيير التصنيف المحدد أو كتابة كلمة بحث أخرى.',
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedCategory = 'all';
                _searchQuery = '';
                _searchController.clear();
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('إعادة ضبط الفلاتر'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Data Structures
// ==========================================
class _ReportDefinition {
  final String id;
  final String title;
  final String category;
  final IconData icon;
  final Color accentColor;
  final int? count;
  final String countUnit;
  final String description;
  final String buttonLabel;
  final String? secondaryButtonLabel;
  final VoidCallback onExport;
  final VoidCallback? onSecondaryAction;

  const _ReportDefinition({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.accentColor,
    required this.count,
    required this.countUnit,
    required this.description,
    required this.buttonLabel,
    this.secondaryButtonLabel,
    required this.onExport,
    this.onSecondaryAction,
  });
}

class _KpiStat {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _KpiStat({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });
}
