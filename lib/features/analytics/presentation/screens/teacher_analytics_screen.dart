import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../core/services/report_generator_service.dart';
import 'package:brivio/features/reports/presentation/screens/attendance_reports_screen.dart';
import 'package:brivio/features/reports/presentation/screens/groups_schedules_report_screen.dart';
import '../widgets/at_risk_students_card.dart';

class TeacherAnalyticsScreen extends StatefulWidget {
  final String profileId;
  final List<Map<String, dynamic>>? initialExams;
  final List<Map<String, dynamic>>? initialAttempts;
  final List<AtRiskStudentInfo>? initialAtRiskStudents;

  const TeacherAnalyticsScreen({
    super.key,
    required this.profileId,
    this.initialExams,
    this.initialAttempts,
    this.initialAtRiskStudents,
  });

  @override
  State<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends State<TeacherAnalyticsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedTab = 0; // 0: نظرة عامة, 1: نتائج الامتحانات, 2: رادار المتعثرين, 3: مركز التصدير
  String _examSearchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isExporting = false;

  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _attempts = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialExams != null || widget.initialAttempts != null) {
      _exams = widget.initialExams != null
          ? List<Map<String, dynamic>>.from(widget.initialExams!)
          : [];
      _attempts = widget.initialAttempts != null
          ? List<Map<String, dynamic>>.from(widget.initialAttempts!)
          : [];
      _isLoading = false;
    } else {
      _loadData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final examsRes = await Supabase.instance.client
          .from('exams')
          .select('id, title, max_attempts, pass_score, status')
          .eq('created_by', widget.profileId);

      final examsList = List<Map<String, dynamic>>.from(examsRes);

      if (examsList.isEmpty) {
        if (!mounted) return;
        setState(() {
          _exams = [];
          _attempts = [];
          _isLoading = false;
        });
        return;
      }

      final examIds = examsList.map((e) => e['id'] as String).toList();

      final attemptsRes = await Supabase.instance.client
          .from('exam_attempts')
          .select('id, exam_id, status, score, max_score, student_id')
          .inFilter('exam_id', examIds);

      final attemptsList = List<Map<String, dynamic>>.from(attemptsRes);

      if (!mounted) return;

      setState(() {
        _exams = examsList;
        _attempts = attemptsList;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // PDF Export Helpers
  Future<void> _exportGeneralReport() async {
    setState(() => _isExporting = true);
    try {
      final examRows = _exams.map((e) {
        return {
          'title': e['title'] ?? 'امتحان',
          'duration': '60',
          'pass_score': (e['pass_score'] ?? 50).toString(),
          'status': e['status'] ?? 'published',
        };
      }).toList();

      await ReportGeneratorService().generateExamReport(
        groupName: 'التقرير الأكاديمي العام للمعلم',
        examData: examRows,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تصدير التقرير الأكاديمي العام بنجاح 📑'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تصدير التقرير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportExamGradesPdf(Map<String, dynamic> exam) async {
    setState(() => _isExporting = true);
    try {
      final examId = exam['id'];
      final examAttempts = _attempts.where((a) => a['exam_id'] == examId).toList();

      final studentsData = examAttempts.map((a) {
        final score = a['score']?.toString() ?? 'قيد التصحيح';
        final maxScore = a['max_score']?.toString() ?? '100';
        return {
          'name': 'طالب رقم (${a['student_id']?.toString().substring(0, 5) ?? "عام"})',
          'exam_score': '$score / $maxScore',
          'homework_score': '90%',
          'missing_assignments': '0',
        };
      }).toList();

      if (studentsData.isEmpty) {
        studentsData.add({
          'name': 'نموذج رصد فارغ',
          'exam_score': '- / ${exam['pass_score'] ?? 50}',
          'homework_score': '-',
          'missing_assignments': '0',
        });
      }

      await ReportGeneratorService().generateGradesReport(
        className: exam['title'] ?? 'امتحان',
        studentsData: studentsData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير تقرير درجات "${exam['title'] ?? 'الامتحان'}" بنجاح 📑'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تصدير درجات الامتحان: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _generateBubbleSheet() async {
    setState(() => _isExporting = true);
    try {
      await ReportGeneratorService().generateStandaloneBubbleSheetPdf(
        centerName: 'المركز التعليمي',
        teacherName: 'معلم المادة',
        examTitle: 'نموذج إجابة بابل شيت عام (30 سؤال)',
        questionCount: 30,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم توليد وتصدير نموذج البابل شيت بنجاح 📑'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل توليد البابل شيت: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final subtitleColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final bgColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              ),
              const SizedBox(height: 16),
              Text(
                'تعذر تحميل بيانات التقارير والتحليلات',
                style: AppTypography.titleLarge(textColor).copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: AppTypography.bodyMedium(subtitleColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Sticky / Top Executive Banner
              SliverToBoxAdapter(
                child: Container(
                  color: bgColor,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                                // Context Badges
                                Row(
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.teacherRole.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: AppColors.teacherRole.withValues(alpha: 0.25),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.insights_rounded,
                                              size: 13,
                                              color: AppColors.teacherRole,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                'مركز التقارير والتحليلات',
                                                style: TextStyle(
                                                  fontSize: isUltraCompact ? 10 : 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.teacherRole,
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
                                            'مؤشرات ذكية ⚡',
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
                                  'التقارير والتحليلات الأكاديمية',
                                  style: AppTypography.displaySmall(textColor).copyWith(
                                    fontSize: isUltraCompact ? 18 : (isCompact ? 21 : 25),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'متابعة أداء الطلاب، مؤشرات النجاح، تقارير الحضور والواجبات، ورادار الطلاب المتعثرين.',
                                  style: TextStyle(
                                    fontSize: isUltraCompact ? 11 : 12,
                                    color: subtitleColor,
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
                      // Executive Smart Tools Strip
                      FadeInSlide(
                        duration: const Duration(milliseconds: 400),
                        delay: const Duration(milliseconds: 50),
                        child: _buildQuickToolsStrip(context, isDark, textColor, subtitleColor),
                      ),
                      const SizedBox(height: 12),
                      // Segmented Tab Filter Bar
                      FadeInSlide(
                        duration: const Duration(milliseconds: 450),
                        delay: const Duration(milliseconds: 100),
                        child: _buildSegmentedFilterBar(isDark, textColor),
                      ),
                    ],
                  ),
                ),
              ),

              // Content based on selected tab
              if (_selectedTab == 0) ...[
                // Overview & KPIs
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverToBoxAdapter(
                    child: _buildKpisGrid(isDark, textColor, subtitleColor),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverToBoxAdapter(
                    child: _buildGradeDistributionCard(isDark, textColor, subtitleColor),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  sliver: SliverToBoxAdapter(
                    child: AtRiskStudentsAlertWidget(
                      customStudents: widget.initialAtRiskStudents,
                    ),
                  ),
                ),
              ] else if (_selectedTab == 1) ...[
                // Exams Details Tab
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _examSearchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'بحث في الاختبارات المسجلة...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _examSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _examSearchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildExamsListSliver(isDark, textColor, subtitleColor),
              ] else if (_selectedTab == 2) ...[
                // At-Risk Students Radar Tab
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  sliver: SliverToBoxAdapter(
                    child: AtRiskStudentsAlertWidget(
                      customStudents: widget.initialAtRiskStudents,
                    ),
                  ),
                ),
              ] else ...[
                // PDF Export Center Tab
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  sliver: SliverToBoxAdapter(
                    child: _buildPdfExportCenter(context, isDark, textColor, subtitleColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickToolsStrip(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    final actions = [
      _QuickReportTool(
        title: 'تقرير شامل PDF',
        subtitle: 'تصدير رسمي',
        icon: Icons.picture_as_pdf_rounded,
        color: Colors.redAccent,
        onTap: _exportGeneralReport,
      ),
      _QuickReportTool(
        title: 'سجلات الحضور',
        subtitle: 'كشف الغياب',
        icon: Icons.co_present_rounded,
        color: Colors.teal,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AttendanceReportsScreen(),
            ),
          );
        },
      ),
      _QuickReportTool(
        title: 'جداول المجموعات',
        subtitle: 'المواعيد والقاعات',
        icon: Icons.calendar_month_rounded,
        color: Colors.indigo,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GroupsSchedulesReportScreen(),
            ),
          );
        },
      ),
      _QuickReportTool(
        title: 'رادار المتعثرين',
        subtitle: 'تحليل تنبؤي',
        icon: Icons.trending_down_rounded,
        color: Colors.deepOrange,
        onTap: () => setState(() => _selectedTab = 2),
      ),
      _QuickReportTool(
        title: 'طباعة بابل شيت',
        subtitle: 'نماذج جاهزة',
        icon: Icons.fact_check_outlined,
        color: Colors.green,
        onTap: _generateBubbleSheet,
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
            onTap: _isExporting ? null : a.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: a.color.withValues(alpha: isDark ? 0.25 : 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: a.color.withValues(alpha: 0.05),
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
                      color: a.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(a.icon, color: a.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        a.title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.subtitle,
                        style: TextStyle(
                          color: subtitleColor,
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

  Widget _buildSegmentedFilterBar(bool isDark, Color textColor) {
    final tabs = [
      {'label': 'نظرة عامة ومؤشرات', 'icon': Icons.insights_rounded},
      {'label': 'تفاصيل الامتحانات (${_exams.length})', 'icon': Icons.quiz_outlined},
      {'label': 'رادار المتعثرين', 'icon': Icons.trending_down_rounded},
      {'label': 'مركز التصدير والطباعة', 'icon': Icons.print_outlined},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: List.generate(tabs.length, (i) {
        final isSelected = _selectedTab == i;
        return ChoiceChip(
          avatar: Icon(
            tabs[i]['icon'] as IconData,
            size: 16,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
          label: Text(
            tabs[i]['label'] as String,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
          ),
          selected: isSelected,
          selectedColor: AppColors.primary,
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          showCheckmark: false,
          onSelected: (_) => setState(() => _selectedTab = i),
        );
      }),
    );
  }

  Widget _buildKpisGrid(bool isDark, Color textColor, Color subtitleColor) {
    int totalAttempts = _attempts.length;
    int gradedAttempts = _attempts
        .where((a) => a['status'] == 'graded' || a['score'] != null)
        .length;

    double avgScore = 0.0;
    int passedCount = 0;

    if (gradedAttempts > 0) {
      double totalScore = 0.0;
      for (var a in _attempts) {
        if (a['score'] != null) {
          double score = (a['score'] as num).toDouble();
          double maxScore = (a['max_score'] as num?)?.toDouble() ?? 100.0;
          if (maxScore > 0) {
            double pct = (score / maxScore) * 100;
            totalScore += pct;
            if (pct >= 50.0) passedCount++;
          }
        }
      }
      avgScore = totalScore / gradedAttempts;
    }

    double passRate = gradedAttempts > 0 ? (passedCount / gradedAttempts) * 100 : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isCompact ? 2 : 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: isCompact ? 1.55 : 1.7,
          children: [
            _buildKpiCard(
              title: 'الامتحانات المسجلة',
              value: '${_exams.length}',
              icon: Icons.quiz_rounded,
              color: AppColors.primary,
              isDark: isDark,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            _buildKpiCard(
              title: 'المحاولات والتسليمات',
              value: '$totalAttempts',
              icon: Icons.assignment_turned_in_rounded,
              color: Colors.teal,
              isDark: isDark,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            _buildKpiCard(
              title: 'متوسط الدرجات العام',
              value: gradedAttempts > 0 ? '${avgScore.toStringAsFixed(1)}%' : '-',
              icon: Icons.trending_up_rounded,
              color: avgScore >= 75 ? Colors.green : (avgScore >= 50 ? Colors.orange : Colors.red),
              isDark: isDark,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            _buildKpiCard(
              title: 'نسبة النجاح والاجتياز',
              value: gradedAttempts > 0 ? '${passRate.toStringAsFixed(0)}%' : '-',
              icon: Icons.verified_rounded,
              color: passRate >= 70 ? Colors.green : Colors.deepOrange,
              isDark: isDark,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: subtitleColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGradeDistributionCard(bool isDark, Color textColor, Color subtitleColor) {
    int gradedAttempts = _attempts
        .where((a) => a['status'] == 'graded' || a['score'] != null)
        .length;

    int excellent = 0; // >= 85
    int veryGood = 0;  // 75-84
    int good = 0;      // 60-74
    int needsHelp = 0; // < 60

    if (gradedAttempts > 0) {
      for (var a in _attempts) {
        if (a['score'] != null) {
          double score = (a['score'] as num).toDouble();
          double maxScore = (a['max_score'] as num?)?.toDouble() ?? 100.0;
          if (maxScore > 0) {
            double pct = (score / maxScore) * 100;
            if (pct >= 85) {
              excellent++;
            } else if (pct >= 75) {
              veryGood++;
            } else if (pct >= 60) {
              good++;
            } else {
              needsHelp++;
            }
          }
        }
      }
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'توزيع المستويات والتحصيل الأكاديمي',
                      style: AppTypography.titleMedium(textColor).copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'نسب استيعاب الطلاب ودرجات الاختبارات المرصودة',
                      style: AppTypography.caption(subtitleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDistributionRow('ممتاز (85% فأكثر) ⭐', excellent, gradedAttempts, Colors.green),
          const SizedBox(height: 8),
          _buildDistributionRow('جيد جداً (75% - 84%) 👏', veryGood, gradedAttempts, Colors.teal),
          const SizedBox(height: 8),
          _buildDistributionRow('جيد ومقبول (60% - 74%) 👍', good, gradedAttempts, Colors.amber.shade800),
          const SizedBox(height: 8),
          _buildDistributionRow('بحاجة لدعم ومتابعة (< 60%) ⚠️', needsHelp, gradedAttempts, AppColors.error),
        ],
      ),
    );
  }

  Widget _buildDistributionRow(String label, int count, int total, Color color) {
    final double pct = total > 0 ? (count / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$count طالب (${(pct * 100).toStringAsFixed(0)}%)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildExamsListSliver(bool isDark, Color textColor, Color subtitleColor) {
    final filteredExams = _exams.where((e) {
      if (_examSearchQuery.trim().isEmpty) return true;
      final title = (e['title'] ?? '').toString().toLowerCase();
      return title.contains(_examSearchQuery.toLowerCase());
    }).toList();

    if (filteredExams.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded, size: 48, color: subtitleColor),
                const SizedBox(height: 12),
                Text(
                  _exams.isEmpty
                      ? 'لا توجد اختبارات مسجلة حالياً لعرض تقاريرها'
                      : 'لم يتم العثور على اختبارات مطابقة لبحثك',
                  style: AppTypography.titleMedium(textColor).copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'قم بإضافة اختبارات من مساحة العمل لتفعيل مؤشرات الأداء التلقائية.',
                  style: AppTypography.bodySmall(subtitleColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((ctx, i) {
          final exam = filteredExams[i];
          return _buildExamCard(exam, isDark, textColor, subtitleColor);
        }, childCount: filteredExams.length),
      ),
    );
  }

  Widget _buildExamCard(
    Map<String, dynamic> exam,
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    final examId = exam['id'];
    final title = exam['title'] ?? 'امتحان بدون عنوان';
    final passScore = (exam['pass_score'] as num?)?.toDouble() ?? 50.0;
    final isClosed = (exam['status'] ?? '').toString().toLowerCase() == 'closed';

    final examAttempts = _attempts.where((a) => a['exam_id'] == examId).toList();
    final gradedAttempts = examAttempts.where((a) => a['status'] == 'graded' || a['score'] != null).toList();

    double avgScore = 0.0;
    int passedCount = 0;

    if (gradedAttempts.isNotEmpty) {
      double totalScore = 0.0;
      for (var a in gradedAttempts) {
        double score = (a['score'] as num).toDouble();
        double maxScore = (a['max_score'] as num?)?.toDouble() ?? 100.0;
        if (maxScore > 0) {
          double pct = (score / maxScore) * 100;
          totalScore += pct;
          if (score >= passScore) passedCount++;
        }
      }
      avgScore = totalScore / gradedAttempts.length;
    }

    final double passRate = gradedAttempts.isNotEmpty ? (passedCount / gradedAttempts.length) * 100 : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: (isClosed ? Colors.orange : AppColors.primary).withValues(alpha: 0.15),
                  child: Icon(
                    isClosed ? Icons.lock_clock_rounded : Icons.quiz_rounded,
                    color: isClosed ? Colors.orange : AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleMedium(textColor).copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'درجة النجاح: ${passScore.toStringAsFixed(0)} | الحالة: ${isClosed ? "مغلق" : "منشور"}',
                        style: AppTypography.caption(subtitleColor).copyWith(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isClosed ? Colors.orange : Colors.green).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isClosed ? 'مغلق' : 'منشور',
                    style: TextStyle(
                      color: isClosed ? Colors.orange : Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Metrics Wrap
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'المحاولات: ${examAttempts.length}',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'تم التصحيح: ${gradedAttempts.length}',
                    style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (avgScore >= 60 ? Colors.green : Colors.red).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    gradedAttempts.isEmpty ? 'المتوسط: -' : 'المتوسط: ${avgScore.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: avgScore >= 60 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    gradedAttempts.isEmpty ? 'الاجتياز: -' : 'نسبة الاجتياز: ${passRate.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Export Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isExporting ? null : () => _exportExamGradesPdf(exam),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('تصدير كشف درجات الامتحان PDF 📑', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfExportCenter(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    final pdfCards = [
      {
        'title': 'التقرير الأكاديمي العام للمعلم',
        'subtitle': 'كشف معتمد يضم جميع الامتحانات المسجلة ومعدلات النجاح ونسب إنجاز الطلاب.',
        'icon': Icons.insights_rounded,
        'color': AppColors.primary,
        'action': _exportGeneralReport,
        'btnLabel': 'تصدير التقرير الشامل PDF',
      },
      {
        'title': 'سجلات الحضور والغياب التفصيلية',
        'subtitle': 'كشوفات رسمية لنسب حضور الطلاب وانصرافهم في جميع المجموعات والقاعات.',
        'icon': Icons.co_present_rounded,
        'color': Colors.teal,
        'action': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AttendanceReportsScreen(),
            ),
          );
        },
        'btnLabel': 'عرض تقارير الحضور والغياب',
      },
      {
        'title': 'تقرير جداول الحصص والمجموعات',
        'subtitle': 'جدول زمني متكامل للمواعيد، القاعات الدراسية، والسناتر المعتمدة.',
        'icon': Icons.calendar_month_rounded,
        'color': Colors.indigo,
        'action': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GroupsSchedulesReportScreen(),
            ),
          );
        },
      'btnLabel': 'عرض تقارير الجداول والحصص',
      },
      {
        'title': 'نماذج بابل شيت فارغة (Bubble Sheet)',
        'subtitle': 'أوراق إجابة معيارية جاهزة للطباعة الفورية وتوزيعها على الطلاب (30 سؤال).',
        'icon': Icons.fact_check_outlined,
        'color': Colors.green,
        'action': _generateBubbleSheet,
        'btnLabel': 'طباعة نموذج البابل شيت',
      },
    ];

    return Column(
      children: pdfCards.map((card) {
        final color = card['color'] as Color;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(card['icon'] as IconData, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card['title'] as String,
                            style: AppTypography.titleMedium(textColor).copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PDF معتمد جاهز للطباعة',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  card['subtitle'] as String,
                  style: TextStyle(color: subtitleColor, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _isExporting ? null : (card['action'] as VoidCallback),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: Text(
                      card['btnLabel'] as String,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
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

class _QuickReportTool {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickReportTool({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
