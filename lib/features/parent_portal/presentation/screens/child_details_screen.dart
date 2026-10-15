import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../student/presentation/widgets/student_digital_id_card.dart';
import 'parent_financial_ledger_screen.dart';
import 'monthly_report_card_screen.dart';
import 'absence_excuse_dialog.dart';

class AcademicsViewModel {
  final String childName;
  final List<ExamScore> recentExams;
  final List<ReportCard> reportCards;
  final List<ChartData> performanceHistory;
  final double cumulativeGpa;

  AcademicsViewModel({
    required this.childName,
    required this.recentExams,
    required this.reportCards,
    required this.performanceHistory,
    this.cumulativeGpa = 0.0,
  });

  factory AcademicsViewModel.empty(String name) {
    return AcademicsViewModel(
      childName: name,
      recentExams: const [],
      reportCards: const [],
      performanceHistory: const [],
      cumulativeGpa: 0.0,
    );
  }
}

class ExamScore {
  final String subject;
  final int score;
  final int maxScore;
  final String date;
  final String grade;
  ExamScore({
    required this.subject,
    required this.score,
    required this.maxScore,
    required this.date,
    required this.grade,
  });
}

class ReportCard {
  final String term;
  final double gpa;
  final String status;
  ReportCard({required this.term, required this.gpa, required this.status});
}

class ChartData {
  final String month;
  final double value;
  ChartData({required this.month, required this.value});
}

class ChildDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> childData;

  const ChildDetailsScreen({super.key, required this.childData});

  @override
  State<ChildDetailsScreen> createState() => _ChildDetailsScreenState();
}

class _ChildDetailsScreenState extends State<ChildDetailsScreen> {
  late AcademicsViewModel _viewModel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _viewModel = AcademicsViewModel.empty(
      widget.childData['name'] ?? widget.childData['full_name'] ?? 'الطالب',
    );
    _loadRealAcademicData();
  }

  Future<void> _loadRealAcademicData() async {
    final studentId = widget.childData['id']?.toString();
    final childName = widget.childData['name'] ?? widget.childData['full_name'] ?? 'الطالب';

    if (studentId == null || studentId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final client = Supabase.instance.client;

      // 1. Fetch real exam attempts
      final examAttemptsRes = await client
          .from('exam_attempts')
          .select('id, score, status, completed_at, exams(title, total_marks, subjects(name))')
          .eq('student_id', studentId)
          .order('completed_at', ascending: false)
          .limit(10);

      final examScores = <ExamScore>[];
      final monthlyBuckets = <String, List<double>>{};
      double totalScorePercentage = 0;
      int scoredExamsCount = 0;

      for (final row in (examAttemptsRes as List)) {
        final examMap = row['exams'] as Map<String, dynamic>?;
        final title = examMap?['title']?.toString() ??
            examMap?['subjects']?['name']?.toString() ??
            'اختبار تقييمي';
        final score = (row['score'] as num?)?.round() ?? 0;
        final maxScore = (examMap?['total_marks'] as num?)?.round() ?? 100;
        final completedStr = row['completed_at']?.toString() ?? '';
        final dt = DateTime.tryParse(completedStr)?.toLocal();
        final dateStr = dt != null
            ? '${dt.day}/${dt.month}/${dt.year}'
            : 'مؤخراً';

        final percentage = maxScore > 0 ? (score / maxScore) * 100 : 0.0;
        totalScorePercentage += percentage;
        scoredExamsCount++;

        String grade;
        if (percentage >= 90) {
          grade = 'ممتاز';
        } else if (percentage >= 80) {
          grade = 'جيد جداً';
        } else if (percentage >= 65) {
          grade = 'جيد';
        } else if (percentage >= 50) {
          grade = 'مقبول';
        } else {
          grade = 'يحتاج دعم';
        }

        examScores.add(ExamScore(
          subject: title,
          score: score,
          maxScore: maxScore,
          date: dateStr,
          grade: grade,
        ));

        if (dt != null) {
          final monthName = _monthName(dt.month);
          monthlyBuckets.putIfAbsent(monthName, () => []).add(percentage);
        }
      }

      // 2. Fetch homework submissions
      final hwRes = await client
          .from('homework_submissions')
          .select('id, score, status, submitted_at, homework(title, max_score)')
          .eq('student_id', studentId)
          .order('submitted_at', ascending: false)
          .limit(10);

      for (final hw in (hwRes as List)) {
        final hwMap = hw['homework'] as Map<String, dynamic>?;
        final score = (hw['score'] as num?)?.toDouble();
        final max = (hwMap?['max_score'] as num?)?.toDouble() ?? 20.0;
        if (score != null && max > 0) {
          final pct = (score / max) * 100;
          totalScorePercentage += pct;
          scoredExamsCount++;
          final dt = DateTime.tryParse(hw['submitted_at']?.toString() ?? '')?.toLocal();
          if (dt != null) {
            final monthName = _monthName(dt.month);
            monthlyBuckets.putIfAbsent(monthName, () => []).add(pct);
          }
        }
      }

      // 3. Attendance records
      final attRes = await client
          .from('attendance_records')
          .select('id, attendance_status')
          .eq('student_id', studentId);
      final attList = attRes as List;
      final presentCount = attList.where((a) {
        final s = (a['attendance_status'] ?? a['status'])?.toString().toLowerCase();
        return s == 'present' || s == 'late' || s == 'attended';
      }).length;
      final totalSessions = attList.length;
      final attendanceRate = totalSessions > 0
          ? ((presentCount / totalSessions) * 100).toStringAsFixed(1)
          : '100';

      // 4. Performance history bars
      final chartData = <ChartData>[];
      if (monthlyBuckets.isNotEmpty) {
        monthlyBuckets.forEach((month, pcts) {
          final avg = pcts.reduce((a, b) => a + b) / pcts.length;
          chartData.add(ChartData(month: month, value: avg.clamp(0, 100)));
        });
      } else {
        final currentMonth = _monthName(DateTime.now().month);
        chartData.add(ChartData(
          month: currentMonth,
          value: scoredExamsCount > 0 ? (totalScorePercentage / scoredExamsCount) : 0,
        ));
      }

      final overallAvg = scoredExamsCount > 0
          ? (totalScorePercentage / scoredExamsCount)
          : 0.0;

      // 5. Reports
      final reports = <ReportCard>[
        ReportCard(
          term: 'سجل الحضور والانتظام',
          gpa: double.tryParse(attendanceRate) ?? 100.0,
          status: '$presentCount من $totalSessions حصص حضور',
        ),
        ReportCard(
          term: 'التقييم الفصلي الشامل',
          gpa: overallAvg,
          status: '$scoredExamsCount اختبارات وواجبات مسجلة',
        ),
      ];

      if (mounted) {
        setState(() {
          _viewModel = AcademicsViewModel(
            childName: childName,
            recentExams: examScores,
            reportCards: reports,
            performanceHistory: chartData,
            cumulativeGpa: overallAvg,
          );
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  static String _monthName(int m) {
    const months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    if (m >= 1 && m <= 12) return months[m];
    return 'الشهر';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'المستوى الأكاديمي - ${_viewModel.childName}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'كارت الطالب الذكي (QR)',
            icon: const Icon(Icons.badge_rounded),
            onPressed: () {
              final studentCode = widget.childData['student_code'] ??
                  widget.childData['id'] ??
                  'STU-BRIVIO';
              StudentDigitalIdCard.show(
                context,
                studentName: _viewModel.childName,
                studentCode: studentCode.toString(),
                gradeLevel: widget.childData['grade'] as String?,
              );
            },
          ),
          IconButton(
            tooltip: 'تواصل مع السنتر (واتساب)',
            icon: const Icon(Icons.chat_rounded),
            onPressed: () {
              final phone = widget.childData['center_phone']?.toString() ??
                  widget.childData['phone']?.toString() ??
                  '';
              WhatsAppService.sendCustomMessage(
                phone: phone,
                message:
                    'السلام عليكم سنتر التعليمي، أستفسر بخصوص الطالب ${_viewModel.childName}',
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A2980), Color(0xFF26D0CE)], // Premium gradient
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // ── Parent Enterprise Actions Row ──
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ParentFinancialLedgerScreen(
                              studentName: _viewModel.childName,
                              studentCode: (widget.childData['student_code'] ?? widget.childData['id'] ?? 'STU-101').toString(),
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                            SizedBox(height: 4),
                            Text(
                              'كشف الحساب 💳',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MonthlyReportCardScreen(
                              studentName: _viewModel.childName,
                              studentCode: (widget.childData['student_code'] ?? widget.childData['id'] ?? 'STU-101').toString(),
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.assessment_rounded, color: Colors.white, size: 22),
                            SizedBox(height: 4),
                            Text(
                              'تقرير الشهر 📄',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        AbsenceExcuseDialog.show(
                          context,
                          initialStudentName: _viewModel.childName,
                          initialStudentId: widget.childData['id']?.toString(),
                          initialGroupName: widget.childData['grade'] as String?,
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.event_busy_rounded, color: Colors.white, size: 22),
                            SizedBox(height: 4),
                            Text(
                              'عذر غياب 🗓️',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              else ...[
                _buildSectionTitle('المستوى العام والتطور الدراسي'),
                const SizedBox(height: 12),
                _buildPerformanceChart(),
                const SizedBox(height: 24),

                _buildSectionTitle('نتائج الاختبارات الأخيرة'),
                const SizedBox(height: 12),
                if (_viewModel.recentExams.isEmpty)
                  _buildGlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: const Center(
                      child: Text(
                        'لم تسجل أي درجات اختبارات رسمية حتى الآن لهذا الطالب.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ..._viewModel.recentExams.map((exam) => _buildExamCard(exam)),
                const SizedBox(height: 24),

                _buildSectionTitle('التقارير والشهادات الدورية'),
                const SizedBox(height: 12),
                ..._viewModel.reportCards.map(
                  (report) => _buildReportCard(report),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildGlassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double height = -1,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          height: height > 0 ? height : null,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildPerformanceChart() {
    return _buildGlassContainer(
      height: 220,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'المعدل التراكمي العام',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                _viewModel.cumulativeGpa > 0
                    ? '${_viewModel.cumulativeGpa.toStringAsFixed(1)}%'
                    : '--',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _viewModel.performanceHistory.map((data) {
                return _buildChartBar(data);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar(ChartData data) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Tooltip(
          message: 'النسبة: ${data.value.toInt()}%',
          child: Container(
            width: 40,
            height: (data.value / 100) * 120, // max height approx 120
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          data.month,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildExamCard(ExamScore exam) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: _buildGlassContainer(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  exam.grade,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.subject,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exam.date,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${exam.score}/${exam.maxScore}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'الدرجة',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(ReportCard report) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: _buildGlassContainer(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.picture_as_pdf,
            color: Colors.white,
            size: 36,
          ),
          title: Text(
            report.term,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            'المعدل: ${report.gpa} • ${report.status}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          trailing: IconButton(
            tooltip: 'عرض وتصدير الشهادة PDF معتمد',
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MonthlyReportCardScreen(
                    studentName: _viewModel.childName,
                    studentCode: (widget.childData['student_code'] ??
                            widget.childData['id'] ??
                            'STU-101')
                        .toString(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
