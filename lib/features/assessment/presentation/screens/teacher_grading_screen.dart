import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import 'student_submissions_screen.dart';

class TeacherGradingScreen extends StatefulWidget {
  final String teacherId;

  const TeacherGradingScreen({super.key, required this.teacherId});

  @override
  State<TeacherGradingScreen> createState() => _TeacherGradingScreenState();
}

class _TeacherGradingScreenState extends State<TeacherGradingScreen> {
  List<Map<String, dynamic>> _homeworkSubmissions = [];
  List<Map<String, dynamic>> _resetRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGradingQueue();
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

    return RefreshIndicator(
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
          : _homeworkSubmissions.isEmpty
          ? CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'لا توجد تسليمات معلقة تتطلب تصحيحاً يدوياً حالياً.',
                      style: AppTypography.bodyMedium(subtitleColor),
                    ),
                  ),
                ),
              ],
            )
          : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (_resetRequests.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'طلبات إعادة الامتحان المعلقة',
                        style: AppTypography.titleMedium(textColor).copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        final req = _resetRequests[i];
                        final studentName =
                            req['students']?['profiles']?['full_name'] ??
                            'طالب';
                        final examTitle = req['exams']?['title'] ?? 'امتحان';
                        return Card(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.error),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.error,
                            ),
                            title: Text(
                              'طلب الطالب $studentName إعادة امتحان: $examTitle',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'سبب الطلب: ${req["reason"] ?? "لم يتم تحديد سبب"}',
                              style: TextStyle(color: subtitleColor),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'رفض',
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () =>
                                      _handleResetRequest(req, false),
                                ),
                                IconButton(
                                  tooltip: 'قبول',
                                  icon: const Icon(
                                    Icons.check,
                                    color: AppColors.success,
                                  ),
                                  onPressed: () =>
                                      _handleResetRequest(req, true),
                                ),
                              ],
                            ),
                          ),
                        );
                      }, childCount: _resetRequests.length),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'تسليمات الطلاب للتصحيح والرصد',
                        style: AppTypography.titleMedium(
                          textColor,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 80.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((ctx, i) {
                      final sub = _homeworkSubmissions[i];
                      final isGraded = sub['status'] == 'graded';
                      final typeLabel = sub['assessment_type'] == 'exam' ? 'امتحان' : 'واجب';
                      final statusLabel = isGraded ? 'تم التصحيح' : 'بانتظار التقييم';
                      final scoreLabel = sub['score'] != null ? '${sub['score']} درجة' : 'قيد الرصد';

                      return FadeInSlide(
                        duration: Duration(milliseconds: 300 + (i * 50)),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isGraded
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.orange.withValues(alpha: 0.2),
                                  child: Icon(
                                    Icons.grading,
                                    color: isGraded
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'الطالب: ${sub['student_full_name'] ?? "طالب"}',
                                        style: AppTypography.titleMedium(
                                          textColor,
                                        ).copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '[$typeLabel] ${sub['assessment_title'] ?? "تقييم"} | الحالة: $statusLabel | الدرجة: $scoreLabel',
                                        style: AppTypography.caption(
                                          subtitleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                isGraded
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Text(
                                          'تم التصحيح',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        onPressed: () =>
                                            _showGradeSubmissionDialog(sub),
                                        child: const Text('تصحيح'),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }, childCount: _homeworkSubmissions.length),
                  ),
                ),
              ],
            ),
    );
  }
}
