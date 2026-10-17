import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

enum AssignmentStatus { pending, submitted, missing }

class Assignment {
  final String id;
  final String title;
  final String? description;
  final String subject;
  final String groupName;
  final String childName;
  final DateTime dueDate;
  final AssignmentStatus status;
  final String? grade;
  final double? score;
  final double maxScore;
  final DateTime? submittedAt;

  Assignment({
    required this.id,
    required this.title,
    this.description,
    required this.subject,
    required this.groupName,
    required this.childName,
    required this.dueDate,
    required this.status,
    this.grade,
    this.score,
    this.maxScore = 100.0,
    this.submittedAt,
  });
}

class ChildAssignmentsViewModel extends ChangeNotifier {
  final SupabaseClientWrapper wrapper;
  final String? studentId;
  final String? studentName;

  List<Assignment> _assignments = [];
  bool _isLoading = true;
  String? _errorMessage;

  ChildAssignmentsViewModel({
    required this.wrapper,
    this.studentId,
    this.studentName,
  }) {
    fetchAssignments();
  }

  List<Assignment> get assignments => _assignments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Assignment> get pending =>
      _assignments.where((a) => a.status == AssignmentStatus.pending).toList();
  List<Assignment> get missing =>
      _assignments.where((a) => a.status == AssignmentStatus.missing).toList();
  List<Assignment> get submitted =>
      _assignments.where((a) => a.status == AssignmentStatus.submitted).toList();

  Future<void> fetchAssignments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final sId = studentId;
      if (sId == null || sId.isEmpty) {
        _assignments = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      List<dynamic> rows = [];
      try {
        final res = await wrapper.client.rpc(
          'get_parent_child_homework_feed',
          params: {'p_student_id': sId},
        );
        if (res is List) rows = res;
      } catch (_) {
        // Fallback: direct table query
        try {
          final res = await wrapper.client
              .from('homework')
              .select('*, groups(name), subjects(name), homework_submissions(*)')
              .order('due_at', ascending: false);
          rows = res.map((item) {
            final m = Map<String, dynamic>.from(item as Map);
            final subs = (m['homework_submissions'] as List<dynamic>? ?? [])
                .whereType<Map>()
                .where((s) => s['student_id'] == sId)
                .toList();
            final sub = subs.isNotEmpty ? subs.first : null;
            final dueAt =
                DateTime.tryParse(m['due_at'] as String? ?? '') ?? DateTime.now();
            final isPassed = dueAt.isBefore(DateTime.now());

              String submissionStatus = 'pending';
              if (sub != null) {
                submissionStatus =
                    sub['status'] == 'graded' ? 'graded' : 'submitted';
              } else if (isPassed) {
                submissionStatus = 'missing';
              }

              return {
                'id': m['id'],
                'title': m['title'],
                'description': m['description'],
                'subject_name':
                    (m['subjects'] as Map?)?['name'] ?? 'مادة دراسية',
                'group_name': (m['groups'] as Map?)?['name'] ?? 'المجموعة',
                'due_at': m['due_at'],
                'max_score': m['max_score'] ?? 100.0,
                'submission_status': submissionStatus,
                'score': sub?['score'],
                'submitted_at': sub?['submitted_at'],
              };
            }).toList();
        } catch (_) {}
      }

      _assignments = rows.map((r) {
        final map = Map<String, dynamic>.from(r as Map);
        final dueAt =
            DateTime.tryParse(map['due_at']?.toString() ?? '') ?? DateTime.now();
        final subStatus = map['submission_status']?.toString() ?? 'pending';
        final score = (map['score'] as num?)?.toDouble();
        final maxScore = (map['max_score'] as num?)?.toDouble() ?? 100.0;

        AssignmentStatus status;
        if (subStatus == 'graded' || subStatus == 'submitted') {
          status = AssignmentStatus.submitted;
        } else if (subStatus == 'missing' || dueAt.isBefore(DateTime.now())) {
          status = AssignmentStatus.missing;
        } else {
          status = AssignmentStatus.pending;
        }

        String? grade;
        if (subStatus == 'graded' && score != null) {
          final sStr = score.truncateToDouble() == score
              ? score.toInt().toString()
              : score.toStringAsFixed(1);
          final mStr = maxScore.truncateToDouble() == maxScore
              ? maxScore.toInt().toString()
              : maxScore.toStringAsFixed(0);
          grade = '$sStr / $mStr';
        } else if (subStatus == 'submitted') {
          grade = 'قيد التصحيح';
        }

        return Assignment(
          id: map['id']?.toString() ?? '',
          title: map['title']?.toString() ?? 'واجب منزلي',
          description: map['description']?.toString(),
          subject: map['subject_name']?.toString() ?? 'مادة دراسية',
          groupName: map['group_name']?.toString() ?? 'المجموعة',
          childName: studentName ?? 'الطالب',
          dueDate: dueAt,
          status: status,
          grade: grade,
          score: score,
          maxScore: maxScore,
          submittedAt:
              DateTime.tryParse(map['submitted_at']?.toString() ?? ''),
        );
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}

class ChildAssignmentsScreen extends StatefulWidget {
  final String? studentName;
  final String? studentId;

  const ChildAssignmentsScreen({
    super.key,
    this.studentName,
    this.studentId,
  });

  @override
  State<ChildAssignmentsScreen> createState() => _ChildAssignmentsScreenState();
}

class _ChildAssignmentsScreenState extends State<ChildAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late ChildAssignmentsViewModel _viewModel;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _viewModel = ChildAssignmentsViewModel(
      wrapper: SupabaseClientWrapper(Supabase.instance.client),
      studentId: widget.studentId,
      studentName: widget.studentName,
    );
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          elevation: 0,
          title: Text(
            widget.studentName != null
                ? 'واجبات وتكليفات ${widget.studentName}'
                : 'متابعة الواجبات والتكليفات 📝',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث الواجبات',
              onPressed: _viewModel.fetchAssignments,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: textSecondary,
            tabs: const [
              Tab(text: 'مطلوب حلها'),
              Tab(text: 'متأخرة عن الموعد'),
              Tab(text: 'تم التسليم والتصحيح'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            if (_viewModel.isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (_viewModel.errorMessage != null &&
                _viewModel.assignments.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        'تعذر تحميل الواجبات: ${_viewModel.errorMessage}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _viewModel.fetchAssignments,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _buildAssignmentList(
                  _viewModel.pending,
                  AssignmentStatus.pending,
                ),
                _buildAssignmentList(
                  _viewModel.missing,
                  AssignmentStatus.missing,
                ),
                _buildAssignmentList(
                  _viewModel.submitted,
                  AssignmentStatus.submitted,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAssignmentList(List<Assignment> items, AssignmentStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (items.isEmpty) {
      final emptyLabel = switch (status) {
        AssignmentStatus.pending =>
          'لا توجد واجبات قيد الحل حالياً، جميع المهام منجزة! 👏',
        AssignmentStatus.missing =>
          'لا توجد تكليفات متأخرة، الطالب منتظم تماماً! 🌟',
        AssignmentStatus.submitted =>
          'لا توجد واجبات مسلّمة مسجلة في هذا القسم.',
      };
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_turned_in_outlined,
                size: 64,
                color: textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                emptyLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _AssignmentCard(assignment: items[index]);
      },
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;

  const _AssignmentCard({required this.assignment});

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        assignment.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildStatusBadge(),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${assignment.subject} • ${assignment.groupName}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Divider(height: 24),
                if (assignment.description != null &&
                    assignment.description!.isNotEmpty) ...[
                  const Text(
                    'تعليمات المعلم ومحتوى الواجب:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    assignment.description!,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'آخر موعد للتسليم: ${DateFormat('yyyy/MM/dd hh:mm a').format(assignment.dueDate)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (assignment.grade != null)
                      Text(
                        'التقييم: ${assignment.grade}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return InkWell(
      onTap: () => _showDetails(context),
      borderRadius: BorderRadius.circular(12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.title,
                        style: AppTypography.titleMedium(textPrimary).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${assignment.subject} • ${assignment.groupName}',
                        style: AppTypography.bodySmall(textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: _getDueDateColor(),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'موعد التسليم: ${DateFormat('yyyy/MM/dd hh:mm a').format(assignment.dueDate)}',
                      style: TextStyle(
                        color: _getDueDateColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (assignment.grade != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'الدرجة: ${assignment.grade}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final (label, color, icon) = switch (assignment.status) {
      AssignmentStatus.pending => (
        'متاح للحل',
        AppColors.info,
        Icons.hourglass_top_rounded
      ),
      AssignmentStatus.submitted => (
        'تم التسليم',
        AppColors.success,
        Icons.check_circle_outline_rounded
      ),
      AssignmentStatus.missing => (
        'متأخر',
        AppColors.error,
        Icons.warning_amber_rounded
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDueDateColor() {
    if (assignment.status == AssignmentStatus.missing) {
      return AppColors.error;
    }
    if (assignment.status == AssignmentStatus.submitted) {
      return AppColors.success;
    }
    final now = DateTime.now();
    final difference = assignment.dueDate.difference(now);
    if (difference.inHours < 24) {
      return AppColors.warning;
    }
    return Colors.grey;
  }
}
