import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../viewmodels/child_schedule_viewmodel.dart';

class ChildScheduleScreen extends StatefulWidget {
  final String? studentId;
  final String? studentName;

  const ChildScheduleScreen({super.key, this.studentId, this.studentName});

  @override
  ChildScheduleScreenState createState() => ChildScheduleScreenState();
}

class ChildScheduleScreenState extends State<ChildScheduleScreen>
    with SingleTickerProviderStateMixin {
  final ChildScheduleViewModel _viewModel = ChildScheduleViewModel();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _viewModel.addListener(_onViewModelChanged);
    final studentId = widget.studentId;
    if (studentId != null && studentId.isNotEmpty) {
      _viewModel.loadForChild(studentId);
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
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
                ? 'جدول مواعيد ${widget.studentName}'
                : 'جدول الحصص والمواعيد 📅',
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
              Tab(text: 'حصص اليوم'),
              Tab(text: 'الامتحانات القادمة'),
              Tab(text: 'العطلات والإجازات'),
            ],
          ),
        ),
        body: _viewModel.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _viewModel.errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(
                        'تعذر تحميل جدول المواعيد: ${_viewModel.errorMessage}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textSecondary),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          if (widget.studentId != null) {
                            _viewModel.loadForChild(widget.studentId!);
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildEventList(
                    _viewModel.todaySchedule,
                    'لا توجد حصص دراسية مجدولة لهذا اليوم 🌟',
                    Icons.event_available,
                  ),
                  _buildEventList(
                    _viewModel.upcomingExams,
                    'لا توجد اختبارات معلنة في الفترة القادمة.',
                    Icons.quiz_outlined,
                  ),
                  _buildEventList(
                    _viewModel.holidays,
                    'لا توجد عطلات رسمية مسجلة حالياً.',
                    Icons.beach_access_outlined,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEventList(
    List<ScheduleEvent> events,
    String emptyMessage,
    IconData emptyIcon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(emptyIcon, size: 56, color: textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 14),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 52,
                  decoration: BoxDecoration(
                    color: event.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: AppTypography.titleMedium(textPrimary).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            event.time,
                            style: AppTypography.bodySmall(textSecondary).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        event.description,
                        style: AppTypography.caption(textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
