import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

enum AssignmentStatus { pending, submitted, missing }

class Assignment {
  final String id;
  final String title;
  final String subject;
  final String childName;
  final DateTime dueDate;
  final AssignmentStatus status;
  final String? grade;

  Assignment({
    required this.id,
    required this.title,
    required this.subject,
    required this.childName,
    required this.dueDate,
    required this.status,
    this.grade,
  });
}

class ChildAssignmentsViewModel extends ChangeNotifier {
  final List<Assignment> assignments = [
    Assignment(
      id: '1',
      title: 'واجب الجبر والهندسة الفراغية - شيت ٥',
      subject: 'الرياضيات',
      childName: 'الطالب',
      dueDate: DateTime.now().add(const Duration(days: 2)),
      status: AssignmentStatus.pending,
    ),
    Assignment(
      id: '2',
      title: 'مقال تاريخ الحركة الوطنية الحديثة',
      subject: 'التاريخ',
      childName: 'الطالب',
      dueDate: DateTime.now().add(const Duration(hours: 10)),
      status: AssignmentStatus.pending,
    ),
    Assignment(
      id: '3',
      title: 'تقرير تجربة الدوائر الكهربية وقانون أوم',
      subject: 'الفيزياء',
      childName: 'الطالب',
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      status: AssignmentStatus.missing,
    ),
    Assignment(
      id: '4',
      title: 'شيت تدريبات النحو والبلاغة - الأسبوع ٤',
      subject: 'اللغة العربية',
      childName: 'الطالب',
      dueDate: DateTime.now().subtract(const Duration(days: 3)),
      status: AssignmentStatus.submitted,
      grade: '١٨ / ٢٠ (ممتاز)',
    ),
  ];

  List<Assignment> get pending =>
      assignments.where((a) => a.status == AssignmentStatus.pending).toList();
  List<Assignment> get missing =>
      assignments.where((a) => a.status == AssignmentStatus.missing).toList();
  List<Assignment> get submitted =>
      assignments.where((a) => a.status == AssignmentStatus.submitted).toList();
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
    _viewModel = ChildAssignmentsViewModel();
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
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          elevation: 0,
          title: Text(
            widget.studentName != null
                ? 'واجبات وتكليفات ${widget.studentName}'
                : 'متابعة الواجبات والتكليفات 📝',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAssignmentList(_viewModel.pending, AssignmentStatus.pending),
            _buildAssignmentList(_viewModel.missing, AssignmentStatus.missing),
            _buildAssignmentList(
              _viewModel.submitted,
              AssignmentStatus.submitted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentList(List<Assignment> items, AssignmentStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (items.isEmpty) {
      final emptyLabel = switch (status) {
        AssignmentStatus.pending => 'لا توجد واجبات قيد الحل حالياً، جميع المهام منجزة! 👏',
        AssignmentStatus.missing => 'لا توجد تكليفات متأخرة، الطالب منتظم تماماً! 🌟',
        AssignmentStatus.submitted => 'لا توجد واجبات مسلّمة مسجلة في هذا القسم.',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GlassCard(
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
                      '${assignment.subject} • ${assignment.childName}',
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
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
    );
  }

  Widget _buildStatusBadge() {
    final (label, color, icon) = switch (assignment.status) {
      AssignmentStatus.pending => ('متاح للحل', AppColors.info, Icons.hourglass_top_rounded),
      AssignmentStatus.submitted => ('تم التسليم', AppColors.success, Icons.check_circle_outline_rounded),
      AssignmentStatus.missing => ('متأخر', AppColors.error, Icons.warning_amber_rounded),
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
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
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
