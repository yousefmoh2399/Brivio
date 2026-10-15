import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class MonthlyReportCardScreen extends StatefulWidget {
  final String studentName;
  final String studentCode;
  final String groupName;
  final String teacherName;
  final String centerName;

  const MonthlyReportCardScreen({
    super.key,
    this.studentName = 'عمر أحمد محمود',
    this.studentCode = 'STU-101',
    this.groupName = 'ثانوية عامة - لغات A',
    this.teacherName = 'أ. محمد عبد الله',
    this.centerName = 'سنتر الأوائل التعليمي',
  });

  @override
  State<MonthlyReportCardScreen> createState() => _MonthlyReportCardScreenState();
}

class _MonthlyReportCardScreenState extends State<MonthlyReportCardScreen> {
  String _selectedMonth = 'أكتوبر 2026';
  bool _isExporting = false;

  final double _attendanceRate = 92.0;
  final int _attendedSessions = 7;
  final int _totalSessions = 8;
  final double _examAverage = 18.5;
  final double _homeworkAverage = 19.0;
  final String _conductEvaluation = 'ممتاز ومشارك بفاعلية عالية 🌟';
  final String _teacherNotes = 'عمر طالب متفوق وملتزم للغاية؛ درجاته ممتازة في امتحانات الكيرشوف والدوائر الكهربية. نوصي فقط بمزيد من التركيز في حل المسائل المقالية الطويلة لتحقيق الدرجة النهائية.';

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final reportService = ReportGeneratorService();
      await reportService.generateMonthlyReportCardPdf(
        centerName: widget.centerName,
        monthName: _selectedMonth,
        studentName: widget.studentName,
        studentCode: widget.studentCode,
        groupName: widget.groupName,
        teacherName: widget.teacherName,
        attendanceRate: _attendanceRate,
        attendedSessions: _attendedSessions,
        totalSessions: _totalSessions,
        examAverage: _examAverage,
        homeworkAverage: _homeworkAverage,
        conductEvaluation: _conductEvaluation,
        teacherNotes: _teacherNotes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تصدير التقرير الشهري: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareOnWhatsApp() async {
    final text = '''
📊 *تقرير المتابعة الشهري - ${widget.centerName}*
📅 لشهر: $_selectedMonth
━━━━━━━━━━━━━━━━━━━━━
👤 *الطالب:* ${widget.studentName}
🔢 *كود الطالب:* ${widget.studentCode}
👥 *المجموعة:* ${widget.groupName}
👨‍🏫 *المعلم:* ${widget.teacherName}
━━━━━━━━━━━━━━━━━━━━━
📈 *معدل الحضور والالتزام:* %${_attendanceRate.toStringAsFixed(0)} ($_attendedSessions من $_totalSessions حصص)
📝 *متوسط درجات الامتحانات:* $_examAverage / 20.0
📚 *متوسط درجات الواجبات:* $_homeworkAverage / 20.0
🌟 *التقييم السلوكي والتفاعل:* $_conductEvaluation
━━━━━━━━━━━━━━━━━━━━━
💬 *ملاحظات المعلم:*
"$_teacherNotes"
━━━━━━━━━━━━━━━━━━━━━
تم توثيق التقرير وإصداره عبر منصة Brivio الذكية للسناتر التعليمية.
''';

    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    final webUri = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(text)}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
      await SharePlus.instance.share(ShareParams(
        text: text,
        subject: 'تقرير الطالب ${widget.studentName} - $_selectedMonth',
      ));
    } catch (_) {
      try {
        await SharePlus.instance.share(ShareParams(
          text: text,
          subject: 'تقرير الطالب ${widget.studentName} - $_selectedMonth',
        ));
      } catch (e) {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم نسخ نص التقرير بالكامل للحافظة بنجاح')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('كارت التقرير الشهري للدرجات 📄'),
        actions: [
          IconButton(
            tooltip: 'مشاركة التقرير عبر واتساب',
            onPressed: _shareOnWhatsApp,
            icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
          ),
          IconButton(
            tooltip: 'تصدير كارت التقرير PDF معتمد',
            onPressed: _isExporting ? null : _exportPdf,
            icon: _isExporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Month Selector
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text('تقرير شهر:', style: AppTypography.titleSmall(textPrimary)),
                    ],
                  ),
                  DropdownButton<String>(
                    value: _selectedMonth,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'أكتوبر 2026', child: Text('أكتوبر 2026')),
                      DropdownMenuItem(value: 'سبتمبر 2026', child: Text('سبتمبر 2026')),
                      DropdownMenuItem(value: 'أغسطس 2026', child: Text('أغسطس 2026')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMonth = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Official Student Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueGrey.shade900, Colors.indigo.shade900],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'كارت تقييم المستوى الرسمي 🎓',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _selectedMonth,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.studentName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الكود: ${widget.studentCode} • المجموعة: ${widget.groupName}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  Text(
                    'المعلم المعتمد: ${widget.teacherName} • ${widget.centerName}',
                    style: const TextStyle(fontSize: 11, color: Colors.amberAccent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Performance Metrics Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text('نسبة الحضور', style: TextStyle(fontSize: 11, color: Colors.green)),
                        const SizedBox(height: 4),
                        Text(
                          '${_attendanceRate.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        Text('$_attendedSessions من $_totalSessions حصص', style: const TextStyle(fontSize: 10, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text('متوسط الامتحانات', style: TextStyle(fontSize: 11, color: Colors.purple)),
                        const SizedBox(height: 4),
                        Text(
                          _examAverage.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple),
                        ),
                        const Text('من 20.0 درجة', style: TextStyle(fontSize: 10, color: Colors.purple)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text('تقييم الواجبات', style: TextStyle(fontSize: 11, color: Colors.indigo)),
                        const SizedBox(height: 4),
                        Text(
                          _homeworkAverage.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
                        ),
                        const Text('من 20.0 درجة', style: TextStyle(fontSize: 10, color: Colors.indigo)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Conduct Evaluation
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'التقييم السلوكي والتفاعل داخل الفصل: ',
                        style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _conductEvaluation,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Text(
                    'ملاحظات وتوجيه الأستاذ لولي الأمر:',
                    style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _teacherNotes,
                      style: AppTypography.bodySmall(textPrimary).copyWith(height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons (WhatsApp Share + A4 PDF Export)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _shareOnWhatsApp,
                    icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
                    label: const Text(
                      'مشاركة واتساب',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF25D366)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isExporting ? null : _exportPdf,
                    icon: _isExporting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf_rounded),
                    label: Text(
                      _isExporting ? 'جارٍ التصدير...' : 'طباعة وتصدير كارت PDF',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
}
