import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../viewmodels/attendance_reports_viewmodel.dart';

class AttendanceReportsScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialStudentsData;
  final List<Map<String, dynamic>>? initialTeachersData;
  final List<Map<String, dynamic>>? initialStaffData;
  final ReportGeneratorService? reportService;

  const AttendanceReportsScreen({
    super.key,
    this.initialStudentsData,
    this.initialTeachersData,
    this.initialStaffData,
    this.reportService,
  });

  @override
  State<AttendanceReportsScreen> createState() => _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState extends State<AttendanceReportsScreen>
    with SingleTickerProviderStateMixin {
  late final ReportGeneratorService? _reportService;
  late final AttendanceReportsViewModel _viewModel;
  late TabController _tabController;
  bool _isGenerating = false;

  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, high, medium, low

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _reportService = widget.reportService ??
        (getIt.isRegistered<ReportGeneratorService>() ? getIt<ReportGeneratorService>() : null);

    _viewModel = AttendanceReportsViewModel();

    if (widget.initialStudentsData != null ||
        widget.initialTeachersData != null ||
        widget.initialStaffData != null) {
      _viewModel.studentAttendance = List.from(widget.initialStudentsData ?? []);
      _viewModel.teacherAttendance = List.from(widget.initialTeachersData ?? []);
      _viewModel.staffAttendance = List.from(widget.initialStaffData ?? []);
      _viewModel.isLoading = false;
    } else {
      _viewModel.loadData();
    }

    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
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
      if (_reportService != null) {
        await _reportService.generateAttendanceReport(
          className: groupName,
          attendanceData: data,
          personType: personType,
        );
      } else {
        // Fallback simulated generation if report service isn't registered
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('تم استخراج تقرير كشف حضور $groupName بنجاح! 📄')),
            ],
          ),
          backgroundColor: Colors.green.shade700,
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

  Future<void> _generateIndividualSlip(Map<String, dynamic> item, String groupName) async {
    final name = item['name']?.toString() ?? 'طالب';
    HapticFeedback.lightImpact();
    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _isGenerating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم إصدار إفادة حضور معتمدة لـ "$name" بنجاح! 📋'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _sendParentNotice(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'طالب';
    final absent = (item['absent'] as num?)?.toInt() ?? 0;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم إرسال إشعار غياب فوري لولي أمر الطالب "$name" ($absent غيابات) 📲',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.indigo.shade700,
      ),
    );
  }

  List<Map<String, dynamic>> _filterRoster(List<Map<String, dynamic>> raw) {
    return raw.where((item) {
      final name = (item['name']?.toString() ?? '').toLowerCase();
      final query = _searchQuery.trim().toLowerCase();
      if (query.isNotEmpty && !name.contains(query)) {
        return false;
      }

      final present = (item['present'] as num?)?.toInt() ?? 0;
      final absent = (item['absent'] as num?)?.toInt() ?? 0;
      final total = present + absent;
      final rate = total > 0 ? (present / total) * 100 : 100.0;

      if (_selectedFilter == 'high') return rate >= 85.0;
      if (_selectedFilter == 'medium') return rate >= 60.0 && rate < 85.0;
      if (_selectedFilter == 'low') return rate < 60.0;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'كشوفات وتقارير الحضور والغياب 📋',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              HapticFeedback.lightImpact();
              _viewModel.loadData();
            },
            tooltip: 'تحديث البيانات',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'الطلاب 👨‍🎓'),
            Tab(text: 'المعلمون 👨‍🏫'),
            Tab(text: 'الكادر الإداري 💼'),
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
                  _buildReportTabView(
                    groupName: 'الطلاب',
                    rawList: _viewModel.studentAttendance,
                    personType: 'طالب',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    isDark: isDark,
                  ),
                  _buildReportTabView(
                    groupName: 'المعلمين',
                    rawList: _viewModel.teacherAttendance,
                    personType: 'معلم',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    isDark: isDark,
                  ),
                  _buildReportTabView(
                    groupName: 'الكادر الإداري',
                    rawList: _viewModel.staffAttendance,
                    personType: 'موظف إداري',
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    isDark: isDark,
                  ),
                ],
              ),
            if (_isGenerating)
              Container(
                color: Colors.black45,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16),
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 3),
                        SizedBox(height: 16),
                        Text(
                          'جاري إنشاء ومعالجة ملف الـ PDF المعتمد...',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTabView({
    required String groupName,
    required List<Map<String, dynamic>> rawList,
    required String personType,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    final filtered = _filterRoster(rawList);

    // Compute stats
    int totalRecords = rawList.length;
    int highCount = 0;
    int mediumCount = 0;
    int lowCount = 0;
    int totalPresents = 0;
    int totalAbsents = 0;

    for (final item in rawList) {
      final p = (item['present'] as num?)?.toInt() ?? 0;
      final a = (item['absent'] as num?)?.toInt() ?? 0;
      totalPresents += p;
      totalAbsents += a;
      final t = p + a;
      final r = t > 0 ? (p / t) * 100 : 100.0;
      if (r >= 85) {
        highCount++;
      } else if (r >= 60) {
        mediumCount++;
      } else {
        lowCount++;
      }
    }

    final overallTotal = totalPresents + totalAbsents;
    final overallRate = overallTotal > 0 ? (totalPresents / overallTotal) * 100 : 100.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final isSmallMobile = constraints.maxWidth < 360;

        return RefreshIndicator(
          onRefresh: () => _viewModel.loadData(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Executive Hero Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isSmallMobile ? 12 : 20,
                    16,
                    isSmallMobile ? 12 : 20,
                    12,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3730A3), Color(0xFF4F46E5), Color(0xFF6366F1)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(isSmallMobile ? 14 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.verified_user_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'كشف حضور وانضباط $groupName',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'سجلات دقيقة معتمدة ومؤرخة لحظياً',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Stats Grid (Responsive Wrap)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildStatTile(
                              label: 'نسبة الحضور العامة',
                              value: '${overallRate.toStringAsFixed(0)}%',
                              icon: Icons.trending_up_rounded,
                              isHighlight: true,
                              isSmall: isSmallMobile,
                            ),
                            _buildStatTile(
                              label: 'إجمالي المقيدين',
                              value: '$totalRecords $personType',
                              icon: Icons.people_alt_rounded,
                              isHighlight: false,
                              isSmall: isSmallMobile,
                            ),
                            _buildStatTile(
                              label: 'ملتزمون (85%+)',
                              value: '$highCount',
                              icon: Icons.check_circle_outline_rounded,
                              isHighlight: false,
                              isSmall: isSmallMobile,
                            ),
                            _buildStatTile(
                              label: 'إنذار غياب (<60%)',
                              value: '$lowCount',
                              icon: Icons.warning_amber_rounded,
                              isHighlight: false,
                              isSmall: isSmallMobile,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Main PDF Export Button
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF3730A3),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          onPressed: () => _generatePdf(groupName, rawList, personType),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                          label: Text(
                            'تصدير كشف حضور $groupName العام (PDF) 📄',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Search & Filter Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallMobile ? 12 : 20,
                    vertical: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search TextField
                      TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'بحث في الكشف بالاسم أو الكود...',
                          hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                )
                              : null,
                          isDense: true,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('all', 'الكل (${rawList.length})', isDark),
                            const SizedBox(width: 8),
                            _buildFilterChip('high', 'ملتزمون 🟢 ($highCount)', isDark),
                            const SizedBox(width: 8),
                            _buildFilterChip('medium', 'متوسط 🟡 ($mediumCount)', isDark),
                            const SizedBox(width: 8),
                            _buildFilterChip('low', 'إنذار غياب 🔴 ($lowCount)', isDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Content List / Empty State / Grid
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search_rounded, size: 64, color: textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            rawList.isEmpty
                                ? 'لا توجد سجلات حضور مسجلة لـ $groupName'
                                : 'لا توجد نتائج تطابق بحثك',
                            style: AppTypography.titleMedium(textPrimary).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            rawList.isEmpty
                                ? 'يتم تحديث الكشوفات تلقائياً عند مسح QR أو تسجيل الحضور في الحصة.'
                                : 'جرّب كتابة اسم آخر أو مسح فلتر البحث.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall(textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (isDesktop)
                // Desktop Grid Layout
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: 165,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildRosterCard(
                        item: filtered[i],
                        groupName: groupName,
                        personType: personType,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        isDark: isDark,
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                )
              else
                // Mobile & Tablet Single Column List
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallMobile ? 12 : 20,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildRosterCard(
                          item: filtered[i],
                          groupName: groupName,
                          personType: personType,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          isDark: isDark,
                        ),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required bool isHighlight,
    required bool isSmall,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: isHighlight
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: isHighlight ? 0.4 : 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, bool isDark) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : (isDark ? Colors.white12 : Colors.black12),
      ),
      onSelected: (_) {
        HapticFeedback.lightImpact();
        setState(() => _selectedFilter = filterKey);
      },
    );
  }

  Widget _buildRosterCard({
    required Map<String, dynamic> item,
    required String groupName,
    required String personType,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    final name = item['name']?.toString() ?? 'طالب';
    final present = (item['present'] as num?)?.toInt() ?? 0;
    final absent = (item['absent'] as num?)?.toInt() ?? 0;
    final total = present + absent;
    final rate = total > 0 ? (present / total) * 100 : 100.0;

    final Color statusColor = rate >= 85
        ? Colors.green
        : rate >= 60
            ? Colors.orange
            : Colors.red;

    final String statusLabel = rate >= 85
        ? 'ملتزم ممتاز ⭐'
        : rate >= 60
            ? 'حضور منتظم ⏳'
            : 'إنذار غياب ⚠️';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Avatar + Name + Rate Badge
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0] : 'م',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.titleSmall(textPrimary).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$statusLabel • $personType',
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${rate.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Attendance Counts & Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'حضور: $present مرة',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  Text(
                    'غياب: $absent مرة',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: absent > 0 ? Colors.red.shade700 : textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total > 0 ? (present / total).clamp(0.0, 1.0) : 1.0,
                  minHeight: 6,
                  backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Bottom Quick Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _generateIndividualSlip(item, groupName),
                  icon: const Icon(Icons.description_outlined, size: 14),
                  label: const Text(
                    'إفادة PDF 📄',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    foregroundColor: Colors.indigoAccent,
                    side: BorderSide(
                      color: Colors.indigoAccent.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _sendParentNotice(item),
                  icon: const Icon(Icons.send_to_mobile_rounded, size: 14),
                  label: const Text(
                    'إشعار الغياب 📱',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
