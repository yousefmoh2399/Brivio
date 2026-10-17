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
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
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
          actions: [
            IconButton(
              tooltip: 'تحديث المواعيد',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                if (widget.studentId != null) {
                  _viewModel.loadForChild(widget.studentId!);
                }
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: textSecondary,
            tabs: [
              Tab(
                child: Row(
                  children: [
                    const Text('حصص اليوم'),
                    if (_viewModel.todaySchedule.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_viewModel.todaySchedule.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Text('الجدول الأسبوعي والقادم'),
                    if (_viewModel.weeklySchedule.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_viewModel.weeklySchedule.length}',
                          style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Text('الامتحانات والتقييمات'),
                    if (_viewModel.upcomingExams.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_viewModel.upcomingExams.length}',
                          style: const TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
                      _buildTodayTab(textPrimary, textSecondary),
                      _buildWeeklyTab(textPrimary, textSecondary),
                      _buildExamsTab(textPrimary, textSecondary),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTodayTab(Color textPrimary, Color textSecondary) {
    if (_viewModel.todaySchedule.isEmpty) {
      final nextSession = _viewModel.nextClassSession;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Icon(Icons.event_available_rounded, size: 56, color: textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text(
              'لا توجد حصص دراسية مجدولة لهذا اليوم 🌟',
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'يمكنك تصفح المواعيد الأسبوعية وحصص الأيام القادمة من تبويب الجدول الأسبوعي.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
            if (nextSession != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'الحصة القادمة للطالب:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textSecondary),
                ),
              ),
              const SizedBox(height: 10),
              _buildEventCard(nextSession, textPrimary, textSecondary),
            ],
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: const Text('عرض الجدول الأسبوعي الكامل'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.today_rounded, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'حصص اليوم (${_viewModel.todaySchedule.length} حصة) • يرجى التواجد بالقاعة قبل الموعد بـ 10 دقائق',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ..._viewModel.todaySchedule.map((e) => _buildEventCard(e, textPrimary, textSecondary)),
      ],
    );
  }

  Widget _buildWeeklyTab(Color textPrimary, Color textSecondary) {
    if (_viewModel.weeklySchedule.isEmpty && _viewModel.upcomingSchedule.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_outlined, size: 56, color: textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 14),
              Text(
                'لا توجد مواعيد حصص مسجلة لمجموعات الطالب حالياً.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_viewModel.weeklySchedule.isNotEmpty) ...[
          Text(
            'المواعيد الأسبوعية الثابتة للمجموعات 🗓️',
            style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'أيام وساعات انعقاد الحصص أسبوعياً بالقاعات الرسمية.',
            style: AppTypography.caption(textSecondary),
          ),
          const SizedBox(height: 12),
          ..._viewModel.weeklySchedule.map((e) => _buildEventCard(e, textPrimary, textSecondary)),
        ],
        if (_viewModel.upcomingSchedule.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'الحصص المجدولة خلال الـ 30 يوماً القادمة ⏳',
            style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._viewModel.upcomingSchedule.map((e) => _buildEventCard(e, textPrimary, textSecondary)),
        ],
      ],
    );
  }

  Widget _buildExamsTab(Color textPrimary, Color textSecondary) {
    if (_viewModel.upcomingExams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.quiz_outlined, size: 56, color: textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 14),
              Text(
                'لا توجد اختبارات معلنة في الفترة القادمة.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _viewModel.upcomingExams.length,
      itemBuilder: (context, index) {
        final exam = _viewModel.upcomingExams[index];
        return _buildEventCard(exam, textPrimary, textSecondary);
      },
    );
  }

  Widget _buildEventCard(ScheduleEvent event, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 5,
              height: 64,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: AppTypography.titleMedium(textPrimary).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: event.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: event.color.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          event.statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: event.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.dayName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.access_time_rounded,
                        size: 15,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.time,
                        style: AppTypography.bodySmall(textSecondary).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 14,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.roomName,
                        style: AppTypography.caption(textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.teacherName,
                          style: AppTypography.caption(textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
