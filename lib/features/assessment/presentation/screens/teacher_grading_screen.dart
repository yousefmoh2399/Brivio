import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import 'student_submissions_screen.dart';

class TeacherGradingScreen extends StatefulWidget {
  final String teacherId;
  final List<Map<String, dynamic>>? initialSubmissions;
  final List<Map<String, dynamic>>? initialResetRequests;

  const TeacherGradingScreen({
    super.key,
    required this.teacherId,
    this.initialSubmissions,
    this.initialResetRequests,
  });

  @override
  State<TeacherGradingScreen> createState() => _TeacherGradingScreenState();
}

class _TeacherGradingScreenState extends State<TeacherGradingScreen> {
  List<Map<String, dynamic>> _homeworkSubmissions = [];
  List<Map<String, dynamic>> _resetRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  final TextEditingController _searchCtrl = TextEditingController();
  String _filterType = 'all'; // 'all', 'pending', 'graded', 'resets'

  @override
  void initState() {
    super.initState();
    if (widget.initialSubmissions != null || widget.initialResetRequests != null) {
      _homeworkSubmissions = widget.initialSubmissions != null
          ? List<Map<String, dynamic>>.from(widget.initialSubmissions!)
          : [];
      _resetRequests = widget.initialResetRequests != null
          ? List<Map<String, dynamic>>.from(widget.initialResetRequests!)
          : [];
    } else {
      _loadGradingQueue();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGradingQueue() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await Supabase.instance.client.rpc(
        'get_teacher_grading_queue',
        params: {'p_teacher_id': widget.teacherId},
      );

      final resetsRes = await Supabase.instance.client
          .from('exam_reset_requests')
          .select('*, exams(title), students(profiles(full_name))')
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          _homeworkSubmissions = (res as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _resetRequests = (resetsRes as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _handleResetRequest(Map<String, dynamic> req, bool approve) async {
    try {
      if (approve) {
        await Supabase.instance.client.rpc(
          'reset_student_exam_attempt',
          params: {
            'p_student_id': req['student_id'],
            'p_exam_id': req['exam_id'],
          },
        );
      }

      await Supabase.instance.client
          .from('exam_reset_requests')
          .update({
            'status': approve ? 'approved' : 'rejected',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', req['id']);

      _loadGradingQueue();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? 'تم قبول طلب إعادة الامتحان بنجاح.'
                  : 'تم رفض طلب إعادة الامتحان.',
            ),
            backgroundColor: approve ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تنفيذ الإجراء: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showGradeSubmissionDialog(Map<String, dynamic> submission) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentSubmissionsScreen(
          initialSubmission: submission,
          onGraded: _loadGradingQueue,
        ),
      ),
    );
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

    final totalSubmissions = _homeworkSubmissions.length;
    final pendingCount = _homeworkSubmissions.where((s) => s['status'] != 'graded').length;
    final gradedCount = _homeworkSubmissions.where((s) => s['status'] == 'graded').length;
    final resetsCount = _resetRequests.length;

    final query = _searchCtrl.text.trim().toLowerCase();

    final filteredSubmissions = _homeworkSubmissions.where((sub) {
      if (_filterType == 'resets') return false;
      if (_filterType == 'pending' && sub['status'] == 'graded') return false;
      if (_filterType == 'graded' && sub['status'] != 'graded') return false;
      if (query.isNotEmpty) {
        final name = (sub['student_full_name'] ?? '').toString().toLowerCase();
        final title = (sub['assessment_title'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !title.contains(query)) return false;
      }
      return true;
    }).toList();

    final filteredResets = _resetRequests.where((req) {
      if (_filterType == 'pending' || _filterType == 'graded') return false;
      if (query.isNotEmpty) {
        final name = (req['students']?['profiles']?['full_name'] ?? '').toString().toLowerCase();
        final title = (req['exams']?['title'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !title.contains(query)) return false;
      }
      return true;
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: RefreshIndicator(
          onRefresh: _loadGradingQueue,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'حدث خطأ: $_errorMessage',
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _loadGradingQueue,
                                child: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1000),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildHeroBanner(isDark, totalSubmissions, pendingCount, gradedCount, resetsCount),
                                    const SizedBox(height: 16),
                                    _buildSearchAndFilters(isDark, totalSubmissions, pendingCount, gradedCount, resetsCount),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (filteredResets.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1000),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.warning_amber_rounded,
                                          color: AppColors.error,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'طلبات إعادة الامتحان المعلقة (${filteredResets.length})',
                                          style: AppTypography.titleMedium(textColor).copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((ctx, i) {
                                final req = filteredResets[i];
                                return Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 1000),
                                    child: _buildResetRequestCard(req, isDark, textColor, subtitleColor),
                                  ),
                                );
                              }, childCount: filteredResets.length),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        ],
                        if (filteredSubmissions.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1000),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.assignment_turned_in_rounded,
                                          color: AppColors.primary,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'تسليمات الطلاب للتصحيح والرصد (${filteredSubmissions.length})',
                                          style: AppTypography.titleMedium(
                                            textColor,
                                          ).copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 80.0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((ctx, i) {
                                final sub = filteredSubmissions[i];
                                return Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 1000),
                                    child: _buildSubmissionCard(sub, i, isDark, textColor, subtitleColor),
                                  ),
                                );
                              }, childCount: filteredSubmissions.length),
                            ),
                          ),
                        ] else if (filteredResets.isEmpty) ...[
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.fact_check_outlined,
                                        size: 48,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      query.isNotEmpty || _filterType != 'all'
                                          ? 'لا توجد نتائج مطابقة لبحثك أو الفلتر'
                                          : 'لا توجد تسليمات معلقة للتصحيح حالياً',
                                      style: AppTypography.titleMedium(textColor).copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      query.isNotEmpty || _filterType != 'all'
                                          ? 'جرّب تغيير كلمات البحث أو اختيار فلتر آخر.'
                                          : 'تم رصد جميع درجات الطلاب والواجبات بنجاح. ستظهر هنا أي تسليمات أو طلبات إعادة فور وصولها. ✨',
                                      style: AppTypography.bodySmall(subtitleColor),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(
    bool isDark,
    int total,
    int pending,
    int graded,
    int resets,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF1E1B4B), const Color(0xFF312E81)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rate_review_rounded, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'استوديو ومحطة التصحيح الذكية ✍️',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'متابعة كشاكيل الطلاب، رصد الدرجات، وفحص طلبات إعادة الاختبارات',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 460;
              final kpiCards = [
                _buildKpiTile(
                  icon: Icons.assignment_outlined,
                  label: 'إجمالي التسليمات',
                  value: '$total',
                  color: Colors.white,
                ),
                _buildKpiTile(
                  icon: Icons.hourglass_top_rounded,
                  label: 'بانتظار التقييم',
                  value: '$pending',
                  color: Colors.amberAccent,
                ),
                _buildKpiTile(
                  icon: Icons.check_circle_rounded,
                  label: 'تم رصدها',
                  value: '$graded',
                  color: Colors.greenAccent,
                ),
                _buildKpiTile(
                  icon: Icons.warning_amber_rounded,
                  label: 'طلبات الإعادة',
                  value: '$resets',
                  color: Colors.redAccent,
                ),
              ];

              if (isNarrow) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kpiCards.map((tile) {
                    return SizedBox(
                      width: (constraints.maxWidth - 16) / 2,
                      child: tile,
                    );
                  }).toList(),
                );
              }

              return Row(
                children: kpiCards
                    .map((tile) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: tile,
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(
    bool isDark,
    int total,
    int pending,
    int graded,
    int resets,
  ) {
    return Column(
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'ابحث باسم الطالب أو عنوان الواجب / الامتحان...',
            hintStyle: const TextStyle(fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                  )
                : null,
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('الكل ($total)', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('بانتظار التقييم ($pending) ⏳', 'pending'),
              const SizedBox(width: 8),
              _buildFilterChip('تم التصحيح ($graded) ✅', 'graded'),
              const SizedBox(width: 8),
              _buildFilterChip('طلبات الإعادة ($resets) ⚠️', 'resets'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _filterType == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _filterType = filterKey);
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
    );
  }

  Widget _buildResetRequestCard(
    Map<String, dynamic> req,
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    final studentName = req['students']?['profiles']?['full_name'] ?? 'طالب';
    final examTitle = req['exams']?['title'] ?? 'امتحان';
    final reason = req['reason'] ?? 'لم يتم تحديد سبب';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.error.withValues(alpha: 0.12),
                  child: const Icon(Icons.person_outline_rounded, color: AppColors.error, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'طلب إعادة: $examTitle',
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'قيد المراجعة',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'السبب: $reason',
                style: TextStyle(color: subtitleColor, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _handleResetRequest(req, true),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('قبول وإعادة المحاولة', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _handleResetRequest(req, false),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('رفض الطلب', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(
    Map<String, dynamic> sub,
    int index,
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    final isGraded = sub['status'] == 'graded';
    final typeLabel = sub['assessment_type'] == 'exam' ? 'امتحان' : 'واجب';
    final statusLabel = isGraded ? 'تم التصحيح' : 'بانتظار التقييم';
    final scoreLabel = sub['score'] != null ? '${sub['score']} درجة' : 'قيد الرصد';
    final studentName = sub['student_full_name'] ?? 'طالب';
    final assessmentTitle = sub['assessment_title'] ?? 'تقييم';

    return FadeInSlide(
      duration: Duration(milliseconds: 250 + (index * 30)),
      child: Padding(
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
                    backgroundColor: isGraded
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    child: Icon(
                      isGraded ? Icons.check_circle_rounded : Icons.grading_rounded,
                      color: isGraded ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: AppTypography.titleMedium(textColor).copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          assessmentTitle,
                          style: AppTypography.caption(subtitleColor).copyWith(
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isGraded ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: isGraded ? Colors.green : Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      typeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'الدرجة: $scoreLabel',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: isGraded
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: BorderSide(color: Colors.green.withValues(alpha: 0.4)),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _showGradeSubmissionDialog(sub),
                        icon: const Icon(Icons.rate_review_outlined, size: 16),
                        label: const Text('مراجعة وتعديل التصحيح ✏️', style: TextStyle(fontSize: 12)),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _showGradeSubmissionDialog(sub),
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('بدء التصحيح والرصد الفوري 📝', style: TextStyle(fontSize: 12)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
