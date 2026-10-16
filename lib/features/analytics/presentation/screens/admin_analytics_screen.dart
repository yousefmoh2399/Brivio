import 'package:flutter/material.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../admin/domain/models/admin_models.dart';
import '../viewmodels/admin_analytics_viewmodel.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _viewModel = AdminAnalyticsViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.loadAnalytics();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PortalPageShell(
      title: 'التحليلات والمؤشرات البيانية 📈',
      subtitle:
          'متابعة الإيرادات والتحصيل المالي ومعدلات حضور وأداء الطلاب في السنتر.',
      icon: Icons.analytics_rounded,
      accentColor: Colors.deepPurple,
      actions: [
        PortalAction(
          icon: Icons.refresh_rounded,
          label: 'تحديث',
          onPressed: () => _viewModel.loadAnalytics(),
        ),
      ],
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_viewModel.errorMessage != null) {
            return Center(
              child: Text(
                _viewModel.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final analytics = _viewModel.analytics;
          final revenue = analytics?.totalRevenue ?? 0.0;
          final students = analytics?.totalStudents ?? 0;
          final attendance = analytics?.attendanceRate ?? 0.0;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              FadeInSlide(
                delay: const Duration(milliseconds: 100),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 650;
                    final cards = [
                      _AnalyticsSummaryCard(
                        title: 'إجمالي الإيرادات',
                        value: '${revenue.toStringAsFixed(0)} ج.م',
                        trend: '+0.0%',
                        isPositive: true,
                        icon: Icons.monetization_on_rounded,
                        color: Colors.green,
                      ),
                      _AnalyticsSummaryCard(
                        title: 'الطلاب المسجلون',
                        value: '$students طالب',
                        trend: '+0.0%',
                        isPositive: true,
                        icon: Icons.school_rounded,
                        color: Colors.blue,
                      ),
                      _AnalyticsSummaryCard(
                        title: 'نسبة الحضور',
                        value: '${attendance.toStringAsFixed(1)}%',
                        trend: '0.0%',
                        isPositive: true,
                        icon: Icons.fact_check_rounded,
                        color: Colors.orange,
                      ),
                    ];

                    if (isMobile) {
                      return Column(
                        children: [
                          cards[0],
                          const SizedBox(height: 12),
                          cards[1],
                          const SizedBox(height: 12),
                          cards[2],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 16),
                        Expanded(child: cards[1]),
                        const SizedBox(width: 16),
                        Expanded(child: cards[2]),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              FadeInSlide(
                delay: const Duration(milliseconds: 200),
                child: GlassCard(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderColor: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          Text(
                            'معدل نمو الإيرادات',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: '1M', label: Text('شهر')),
                              ButtonSegment(value: '6M', label: Text('6 أشهر')),
                              ButtonSegment(value: '1Y', label: Text('سنة')),
                            ],
                            selected: const {'6M'},
                            onSelectionChanged: (val) {},
                            style: SegmentedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.deepPurple.withValues(alpha: 0.1),
                              Colors.deepPurple.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(
                                5,
                                (index) => Divider(
                                  color: Colors.grey.withValues(alpha: 0.15),
                                ),
                              ),
                            ),
                            if (analytics != null &&
                                analytics.revenueGrowth.isNotEmpty &&
                                analytics.totalRevenue > 0)
                              CustomPaint(
                                size: const Size(double.infinity, 180),
                                painter: _RealChartPainter(
                                  points: analytics.revenueGrowth,
                                  color: Colors.deepPurple,
                                ),
                              )
                            else
                              const Center(
                                child: Text(
                                  'لا توجد عمليات تحصيل مسجلة خلال هذه الفترة',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 750;

                  final subjectCard = FadeInSlide(
                    delay: const Duration(milliseconds: 300),
                    child: GlassCard(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderColor: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المواد الأكثر تسجيلاً وحضوراً',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
                          if (analytics?.subjectPerformances != null &&
                              analytics!.subjectPerformances.isNotEmpty)
                            ...analytics.subjectPerformances.map((perf) {
                              final colors = [
                                Colors.blue,
                                Colors.purple,
                                Colors.teal,
                                Colors.orange,
                              ];
                              final colorIndex =
                                  analytics.subjectPerformances.indexOf(
                                    perf,
                                  ) %
                                  colors.length;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: _SubjectPerformanceRow(
                                  subject: perf.subjectName,
                                  score: perf.averageScore.toInt(),
                                  color: colors[colorIndex],
                                ),
                              );
                            })
                          else
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  'لا توجد بيانات أداء مسجلة حتى الآن.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );

                  final genderCard = FadeInSlide(
                    delay: const Duration(milliseconds: 400),
                    child: GlassCard(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderColor: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'توزيع الطلاب',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 130,
                                  height: 130,
                                  child: CircularProgressIndicator(
                                    value:
                                        analytics
                                            ?.demographics
                                            .malePercentage ??
                                        0.5,
                                    strokeWidth: 10,
                                    backgroundColor: Colors.pink.withValues(
                                      alpha: 0.2,
                                    ),
                                    color: Colors.blue,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${((analytics?.demographics.malePercentage ?? 0.5) * 100).toInt()}%',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const Text(
                                      'بنين',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              const _LegendItem(
                                label: 'بنين',
                                color: Colors.blue,
                              ),
                              _LegendItem(
                                label: 'بنات',
                                color: Colors.pink.withValues(alpha: 0.8),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );

                  if (isMobile) {
                    return Column(
                      children: [
                        subjectCard,
                        const SizedBox(height: 16),
                        genderCard,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: subjectCard),
                      const SizedBox(width: 24),
                      Expanded(flex: 1, child: genderCard),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }
}

class _SubjectPerformanceRow extends StatelessWidget {
  final String subject;
  final int score;
  final Color color;

  const _SubjectPerformanceRow({
    required this.subject,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            subject,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text('$score%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}

class _RealChartPainter extends CustomPainter {
  final List<RevenueDataPoint> points;
  final Color color;

  _RealChartPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxAmount = points
        .map((p) => p.amount)
        .fold<double>(0.0, (m, a) => a > m ? a : m);
    if (maxAmount <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX =
        points.length > 1 ? size.width / (points.length - 1) : size.width;

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final normalizedY = (points[i].amount / maxAmount).clamp(0.0, 1.0);
      final y = size.height - (normalizedY * (size.height - 30)) - 15;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw point markers
    final dotPaint = Paint()..color = color;
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final normalizedY = (points[i].amount / maxAmount).clamp(0.0, 1.0);
      final y = size.height - (normalizedY * (size.height - 30)) - 15;
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }

    // Gradient fill beneath curve
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _RealChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

class _AnalyticsSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final bool isPositive;
  final IconData icon;
  final Color color;

  const _AnalyticsSummaryCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.isPositive,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 12,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          trend,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isPositive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
