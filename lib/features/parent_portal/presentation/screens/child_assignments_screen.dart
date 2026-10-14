import 'package:flutter/material.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import 'package:intl/intl.dart';

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
      title: 'تقرير تجربة الدوائر الكهربية',
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
      grade: 'ممتاز (A)',
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
  const ChildAssignmentsScreen({super.key});

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
    return Scaffold(
      backgroundColor: AppColors.darkBackgroundElevated,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'الواجبات والتكليفات المدرسية',
          style: TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.darkTextSecondary,
          tabs: const [
            Tab(text: 'قيد الحل'),
            Tab(text: 'متأخر'),
            Tab(text: 'تم التسليم'),
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
    );
  }

  Widget _buildAssignmentList(List<Assignment> items, AssignmentStatus status) {
    if (items.isEmpty) {
      final emptyLabel = switch (status) {
        AssignmentStatus.pending => 'لا توجد واجبات قيد الانتظار حالياً',
        AssignmentStatus.missing => 'لا توجد تكليفات متأخرة، عمل رائع!',
        AssignmentStatus.submitted => 'لا توجد واجبات مسلّمة مسجلة مؤخراً',
      };
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_turned_in,
              size: 64,
              color: AppColors.darkTextTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              emptyLabel,
              style: const TextStyle(
                color: AppColors.darkTextSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return FadeInSlide(
          delay: Duration(milliseconds: 50 * index),
          child: _AssignmentCard(assignment: items[index]),
        );
      },
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;

  const _AssignmentCard({required this.assignment});

  @override
  Widget build(BuildContext context) {
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
                      style: const TextStyle(
                        color: AppColors.darkTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${assignment.subject} • ${assignment.childName}',
                      style: const TextStyle(
                        color: AppColors.darkTextSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(),
            ],
          ),
          const SizedBox(height: 16),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (assignment.grade != null)
                Text(
                  'التقييم: ${assignment.grade}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    switch (assignment.status) {
      case AssignmentStatus.pending:
        return const StatusChip(
          label: 'قيد الحل',
          status: ChipStatus.info,
          icon: Icons.hourglass_empty,
          small: true,
        );
      case AssignmentStatus.submitted:
        return const StatusChip(
          label: 'تم التسليم',
          status: ChipStatus.success,
          icon: Icons.check_circle_outline,
          small: true,
        );
      case AssignmentStatus.missing:
        return const StatusChip(
          label: 'متأخر',
          status: ChipStatus.error,
          icon: Icons.warning_amber_rounded,
          small: true,
        );
    }
  }

  Color _getDueDateColor() {
    if (assignment.status == AssignmentStatus.missing) {
      return AppColors.error;
    }
    if (assignment.status == AssignmentStatus.submitted) {
      return AppColors.darkTextSecondary;
    }
    final now = DateTime.now();
    final difference = assignment.dueDate.difference(now);
    if (difference.inHours < 24) {
      return AppColors.warning;
    }
    return AppColors.darkTextSecondary;
  }
}
