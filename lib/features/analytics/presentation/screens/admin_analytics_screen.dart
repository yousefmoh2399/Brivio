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
  String _selectedPeriod = '6M';

  @override
  void initState() {
    super.initState();
    _loadForPeriod(_selectedPeriod);
  }

  void _loadForPeriod(String period) {
    setState(() => _selectedPeriod = period);
    final now = DateTime.now();
    final start = switch (period) {
      '1M' => now.subtract(const Duration(days: 30)),
      '1Y' => now.subtract(const Duration(days: 365)),
      _ => now.subtract(const Duration(days: 180)),
    };
    _viewModel.loadAnalytics(startDate: start, endDate: now);
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
      subtitle: 'متابعة الإيرادات والتحصيل المالي ومعدلات حضور وأداء الطلاب في السنتر.',
      icon: Icons.analytics_rounded,
      accentColor: Colors.deepPurple,
      actions: [
        PortalAction(
          icon: Icons.refresh_rounded,
          label: 'تحديث',
          onPressed: () => _loadForPeriod(_selectedPeriod),
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
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(
                      _viewModel.errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _loadForPeriod(_selectedPeriod),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final analytics = _viewModel.analytics;
          final revenue = analytics?.totalRevenue ?? 0.0;
          final students = analytics?.totalStudents ?? 0;
          final attendance = analytics?.attendanceRate ?? 0.0;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final isSmall = constraints.maxWidth < 420;

              return RefreshIndicator(
                onRefresh: () async => _loadForPeriod(_selectedPeriod),
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 24,
                    vertical: isMobile ? 12 : 20,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    // Top KPI Summary Strip
                    _buildSummaryCards(
                      isMobile: isMobile,
                      isSmall: isSmall,
                      revenue: revenue,
                      students: students,
                      attendance: attendance,
                    ),

                    SizedBox(height: isMobile ? 14 : 20),

                    // Revenue Growth Chart Card
                    _buildRevenueChartCard(
                      isDark: isDark,
                      isMobile: isMobile,
                      isSmall: isSmall,
                      analytics: analytics,
                    ),

                    SizedBox(height: isMobile ? 14 : 20),

                    // Performance & Demographics Section
                    _buildDetailsSection(
                      isDark: isDark,
                      constraints: constraints,
                      analytics: analytics,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards({
    required bool isMobile,
    required bool isSmall,
    required double revenue,
    required int students,
    required double attendance,
  }) {
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

    if (isSmall) {
      return Column(
        children: [
          cards[0],
          const SizedBox(height: 10),
          cards[1],
          const SizedBox(height: 10),
          cards[2],
        ],
      );
    }

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 10),
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
  }

  Widget _buildRevenueChartCard({
    required bool isDark,
    required bool isMobile,
    required bool isSmall,
    required AdminAnalytics? analytics,
  }) {
    final header = isSmall
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'معدل نمو الإيرادات',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
              ),
              const SizedBox(height: 8),
              _buildPeriodSelector(),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'معدل نمو الإيرادات والتحصيل',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              _buildPeriodSelector(),
            ],
          );

    final chartHeight = isMobile ? 160.0 : 190.0;

    return GlassCard(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          SizedBox(height: isMobile ? 16 : 22),
          Container(
            height: chartHeight,
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
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                      height: 1,
                    ),
                  ),
                ),
                if (analytics != null &&
                    analytics.revenueGrowth.isNotEmpty &&
                    analytics.totalRevenue > 0)
                  CustomPaint(
                    size: Size(double.infinity, chartHeight),
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
                        fontSize: 12.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: '1M', label: Text('شهر')),
        ButtonSegment(value: '6M', label: Text('6 أشهر')),
        ButtonSegment(value: '1Y', label: Text('سنة')),
      ],
      selected: {_selectedPeriod},
      onSelectionChanged: (val) {
        if (val.isNotEmpty) _loadForPeriod(val.first);
      },
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildDetailsSection({
    required bool isDark,
    required BoxConstraints constraints,
    required AdminAnalytics? analytics,
  }) {
    final isMobile = constraints.maxWidth < 750;

    final subjectCard = GlassCard(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'المواد الأكثر تسجيلاً وحضوراً',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 15 : 16,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                  analytics.subjectPerformances.indexOf(perf) % colors.length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: _SubjectPerformanceRow(
                  subject: perf.subjectName,
                  score: perf.averageScore.toInt(),
                  color: colors[colorIndex],
                  isMobile: constraints.maxWidth < 450,
                ),
              );
            })
          else
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  'لا توجد بيانات أداء للمواد مسجلة حتى الآن.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final genderCard = GlassCard(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, color: Colors.deepPurple, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'توزيع الطلاب الديموغرافي',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 15 : 16,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 125,
                  height: 125,
                  child: CircularProgressIndicator(
                    value: analytics?.demographics.malePercentage ?? 0.5,
                    strokeWidth: 10,
                    backgroundColor: Colors.pink.withValues(alpha: 0.2),
                    color: Colors.blue,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${((analytics?.demographics.malePercentage ?? 0.5) * 100).toInt()}%',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Text(
                      'بنين',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _LegendItem(
                label: 'بنين',
                color: Colors.blue,
              ),
              const SizedBox(width: 20),
              _LegendItem(
                label: 'بنات',
                color: Colors.pink.withValues(alpha: 0.8),
              ),
            ],
          ),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          subjectCard,
          const SizedBox(height: 14),
          genderCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: subjectCard),
        const SizedBox(width: 18),
        Expanded(flex: 2, child: genderCard),
      ],
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }
}

class _SubjectPerformanceRow extends StatelessWidget {
  final String subject;
  final int score;
  final Color color;
  final bool isMobile;

  const _SubjectPerformanceRow({
    required this.subject,
    required this.score,
    required this.color,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  subject,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$score%',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            subject,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2.5,
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
                      size: 11,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      trend,
                      style: TextStyle(
                        color: isPositive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
