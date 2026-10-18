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
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'active', 'inactive'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChange);
    _viewModel.fetchGroupsData();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
          behavior: SnackBarBehavior.floating,
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
          content: Text('تم استخراج تقرير المجموعات والجداول بنجاح! 📄'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل استخراج التقرير: $e'),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final totalGroups = _viewModel.groupsData.length;
    final activeGroups = _viewModel.groupsData
        .where((g) => g['is_active'] == true)
        .length;
    final inactiveGroups = totalGroups - activeGroups;

    // Filter logic
    var displayGroups = _viewModel.groupsData;
    if (_selectedFilter == 'active') {
      displayGroups = displayGroups.where((g) => g['is_active'] == true).toList();
    } else if (_selectedFilter == 'inactive') {
      displayGroups = displayGroups.where((g) => g['is_active'] != true).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      displayGroups = displayGroups.where((g) {
        final name = (g['group_name'] ?? '').toString().toLowerCase();
        final teacher = (g['teacher'] ?? '').toString().toLowerCase();
        final timing = (g['timing'] ?? '').toString().toLowerCase();
        return name.contains(q) || teacher.contains(q) || timing.contains(q);
      }).toList();
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
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
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 20,
                        vertical: 16,
                      ),
                      children: [
                        // Header Title
                        Text(
                          'المجموعات الدراسية ومواعيد الحصص',
                          style: AppTypography.titleLarge(textPrimary)
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'نظرة شاملة على جميع المجموعات الفعالة ومواعيد الحصص الأسبوعية.',
                          style: AppTypography.bodySmall(textSecondary),
                        ),
                        const SizedBox(height: 16),

                        // Stats Strip
                        _buildStatsStrip(
                          screenWidth,
                          totalGroups,
                          activeGroups,
                          inactiveGroups,
                          isDark,
                          textPrimary,
                          textSecondary,
                        ),
                        const SizedBox(height: 16),

                        // Search and Filter Row
                        _buildSearchAndFilters(
                          isMobile,
                          isDark,
                          textPrimary,
                          textSecondary,
                          totalGroups,
                          activeGroups,
                          inactiveGroups,
                        ),
                        const SizedBox(height: 16),

                        // Groups list
                        if (_viewModel.groupsData.isEmpty)
                          _buildEmptyState(
                            isDark,
                            textPrimary,
                            textSecondary,
                            'لا توجد مجموعات دراسية مسجلة حالياً',
                            'أضف مجموعات دراسية وجداول حصص لعرضها واستخراج تقاريرها.',
                            Icons.group_off_rounded,
                          )
                        else if (displayGroups.isEmpty)
                          _buildEmptyState(
                            isDark,
                            textPrimary,
                            textSecondary,
                            'لا توجد نتائج مطابقة لبحثك',
                            'جرّب تغيير فلاتر الحالة أو مسح نص البحث.',
                            Icons.search_off_rounded,
                          )
                        else
                          ...displayGroups.map((group) {
                            final isActive = group['is_active'] == true;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                padding: EdgeInsets.all(isMobile ? 12 : 16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: isMobile ? 18 : 22,
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
                                        size: isMobile ? 18 : 22,
                                      ),
                                    ),
                                    SizedBox(width: isMobile ? 10 : 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            group['group_name'] ?? '',
                                            style: AppTypography.titleSmall(
                                                    textPrimary)
                                                .copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: isMobile ? 13 : 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.schedule_rounded,
                                                size: 13,
                                                color: textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'الموعد: ${group['timing']}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      AppTypography.bodySmall(
                                                          textSecondary),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.person_outline_rounded,
                                                size: 13,
                                                color: textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'المعلم: ${group['teacher']}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTypography.caption(
                                                      textSecondary),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? Colors.green.withValues(alpha: 0.12)
                                            : Colors.grey.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        isActive ? 'نشطة' : 'متوقفة',
                                        style: TextStyle(
                                          color: isActive
                                              ? Colors.green
                                              : Colors.grey,
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
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
            if (_isGenerating)
              Container(
                color: Colors.black38,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          'جارٍ استخراج وتصدير تقرير الجداول PDF...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
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

  Widget _buildStatsStrip(
    double screenWidth,
    int total,
    int active,
    int inactive,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final stats = [
      {'label': 'إجمالي المجموعات', 'count': '$total', 'color': Colors.blue},
      {'label': 'مجموعات نشطة', 'count': '$active', 'color': Colors.green},
      {'label': 'مجموعات متوقفة', 'count': '$inactive', 'color': Colors.grey},
    ];

    return Row(
      children: stats.map((s) {
        final color = s['color'] as Color;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s['count'] as String,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s['label'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchAndFilters(
    bool isMobile,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    int total,
    int active,
    int inactive,
  ) {
    final searchInput = TextField(
      controller: _searchController,
      onChanged: (val) => setState(() => _searchQuery = val),
      decoration: InputDecoration(
        hintText: 'بحث باسم المجموعة أو المعلم...',
        hintStyle: TextStyle(fontSize: 12, color: textSecondary),
        prefixIcon: Icon(Icons.search_rounded, size: 18, color: textSecondary),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      style: TextStyle(fontSize: 12.5, color: textPrimary),
    );

    final filters = [
      {'id': 'all', 'label': 'الكل ($total)'},
      {'id': 'active', 'label': 'نشطة ($active)'},
      {'id': 'inactive', 'label': 'متوقفة ($inactive)'},
    ];

    final chips = Row(
      children: filters.map((f) {
        final isSelected = _selectedFilter == f['id'];
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: ChoiceChip(
            selected: isSelected,
            showCheckmark: false,
            label: Text(
              f['label']!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : textSecondary,
              ),
            ),
            selectedColor: AppColors.primary,
            backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
            ),
            onSelected: (selected) {
              if (selected) {
                setState(() => _selectedFilter = f['id']!);
              }
            },
          ),
        );
      }).toList(),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchInput,
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: chips,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchInput),
        const SizedBox(width: 12),
        chips,
      ],
    );
  }

  Widget _buildEmptyState(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: textSecondary),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppTypography.titleMedium(textPrimary)
                .copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall(textSecondary),
          ),
        ],
      ),
    );
  }
}
