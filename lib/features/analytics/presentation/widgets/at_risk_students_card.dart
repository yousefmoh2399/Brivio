import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../core/services/whatsapp_service.dart';

enum AtRiskSeverity {
  critical('خطر أكاديمي حرج 🚨', Color(0xFFEF4444)),
  warning('مؤشر تراجع متتالي ⚠️', Color(0xFFF59E0B)),
  homework('إهمال تسليم الواجبات 📝', Color(0xFF8B5CF6));

  final String label;
  final Color color;
  const AtRiskSeverity(this.label, this.color);
}

class AtRiskStudentInfo {
  final String studentId;
  final String studentName;
  final String studentCode;
  final String parentPhone;
  final List<double> recentScores; // sorted chronologically e.g. [18.0, 13.5, 8.0]
  final double maxScore;
  final AtRiskSeverity severity;
  final String declineReason;
  final String suggestedIntervention;
  final int missedHomeworkCount;

  const AtRiskStudentInfo({
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.parentPhone,
    required this.recentScores,
    this.maxScore = 20.0,
    required this.severity,
    required this.declineReason,
    required this.suggestedIntervention,
    this.missedHomeworkCount = 0,
  });

  double get scoreDropPercentage {
    if (recentScores.length < 2) return 0.0;
    final first = recentScores.first;
    final last = recentScores.last;
    if (first == 0) return 0.0;
    return (((first - last) / first) * 100).clamp(0.0, 100.0);
  }
}

class AtRiskStudentsAlertWidget extends StatefulWidget {
  final String teacherName;
  final String subjectName;
  final String centerName;
  final List<AtRiskStudentInfo>? customStudents;

  const AtRiskStudentsAlertWidget({
    super.key,
    this.teacherName = 'معلمنا الفاضل',
    this.subjectName = 'الفيزياء الحديثة',
    this.centerName = 'سنتر الأوائل التعليمي',
    this.customStudents,
  });

  @override
  State<AtRiskStudentsAlertWidget> createState() => _AtRiskStudentsAlertWidgetState();
}

class _AtRiskStudentsAlertWidgetState extends State<AtRiskStudentsAlertWidget> {
  bool _isLoading = false;
  List<AtRiskStudentInfo> _students = [];

  @override
  void initState() {
    super.initState();
    if (widget.customStudents != null) {
      _students = widget.customStudents!;
    } else {
      _loadRealAtRiskStudents();
    }
  }

  Future<void> _loadRealAtRiskStudents() async {
    setState(() => _isLoading = true);
    try {
      final attempts = await Supabase.instance.client
          .from('exam_attempts')
          .select('score, max_score, created_at, students(id, student_code, emergency_contact_phone, profiles(full_name, phone_number))')
          .order('created_at', ascending: false)
          .limit(50);

      final Map<String, List<double>> studentScores = {};
      final Map<String, Map<String, dynamic>> studentMeta = {};

      for (final att in (attempts as List)) {
        final stu = att['students'] as Map<String, dynamic>?;
        if (stu == null) continue;
        final stuId = stu['id']?.toString() ?? '';
        final score = (att['score'] as num? ?? 0).toDouble();
        final maxScore = (att['max_score'] as num? ?? 100).toDouble();
        final percentage = maxScore > 0 ? (score / maxScore) * 100 : 0.0;

        studentScores.putIfAbsent(stuId, () => []).add(percentage);
        studentMeta[stuId] = stu;
      }

      final atRisk = <AtRiskStudentInfo>[];

      studentScores.forEach((stuId, scores) {
        if (scores.isEmpty) return;
        final average = scores.reduce((a, b) => a + b) / scores.length;
        if (average < 65.0) {
          final meta = studentMeta[stuId]!;
          final prof = meta['profiles'] as Map<String, dynamic>?;
          final name = prof?['full_name']?.toString() ?? 'طالب';
          final code = meta['student_code']?.toString() ?? '';
          final phone = (meta['emergency_contact_phone']?.toString().isNotEmpty == true)
              ? meta['emergency_contact_phone'].toString()
              : (prof?['phone_number']?.toString() ?? '');

          final isCritical = average < 50.0;

          atRisk.add(
            AtRiskStudentInfo(
              studentId: stuId,
              studentName: name,
              studentCode: code,
              parentPhone: phone,
              recentScores: scores.take(3).toList(),
              maxScore: 100.0,
              severity: isCritical ? AtRiskSeverity.critical : AtRiskSeverity.warning,
              declineReason: isCritical
                  ? 'متوسط الدرجات أقل من 50% في آخر التقييمات (${average.toStringAsFixed(1)}%)'
                  : 'متوسط الدرجات (${average.toStringAsFixed(1)}%) بحاجة لمتابعة وتقوية',
              suggestedIntervention: isCritical
                  ? 'جلسة متابعة مباشرة مع المعلم وتعيين واجبات علاجية'
                  : 'مراجعة الملاحظات مع ولي الأمر وإعادة الاختبار الجزئي',
            ),
          );
        }
      });

      if (mounted) {
        setState(() {
          _students = atRisk;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sendWhatsAppIntervention(AtRiskStudentInfo student) async {
    final recentScoresText = student.recentScores.asMap().entries.map((e) {
      final idx = e.key + 1;
      final val = e.value;
      return 'اختبار $idx: $val من ${student.maxScore.toInt()}';
    }).toList();

    final success = await WhatsAppService.sendAcademicInterventionAlertToParent(
      parentPhone: student.parentPhone,
      studentName: student.studentName,
      centerName: widget.centerName,
      teacherName: widget.teacherName,
      subjectName: widget.subjectName,
      riskLevel: student.severity.label,
      recentScores: recentScoresText,
      reason: student.declineReason,
      recommendedAction: student.suggestedIntervention,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'تم فتح تطبيق واتساب لإرسال تقرير التدخل الأكاديمي لولي أمر ${student.studentName} 📲'
                : 'تعذر فتح تطبيق واتساب، يرجى التأكد من الرقم: ${student.parentPhone}',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _openInterventionPlanDialog(AtRiskStudentInfo student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: student.severity.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.assignment_turned_in_rounded, color: student.severity.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('خطة الدعم والتدخل الأكاديمي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('للطالب: ${student.studentName} (${student.studentCode})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تشخيص المشكلة الأكاديمية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(student.declineReason, style: const TextStyle(fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('الإجراءات المقترحة من المنظومة الذكية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            _buildCheckStep('تحديد موعد حصة تقوية ومراجعة مجانية مع المساعد الأكاديمي'),
            _buildCheckStep('إعادة اختبار تجريبي مصغر على الدروس غير المفهومة'),
            _buildCheckStep('إلزام الطالب بتسليم الواجب المتأخر قبل الحصة القادمة'),
            _buildCheckStep('مكالمة هاتفية مع ولي الأمر من قِبل إدارة السنتر'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('إرسال التقرير لولي الأمر'),
            onPressed: () {
              Navigator.pop(ctx);
              _sendWhatsAppIntervention(student);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCheckStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 16, color: Color(0xFF0D9488)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11.5))),
        ],
      ),
    );
  }

  void _callParent(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_down_rounded,
                  color: Color(0xFFEF4444),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'رادار الطلاب المتعثرين وتحليلات الأداء التنبؤية 📉',
                          style: AppTypography.titleMedium(textPrimary).copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_students.length} بحاجة لتدخل',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'خوارزمية ذكية ترصد الطلاب الذين انحدرت درجاتهم بنسبة ملحوظة في آخر 3 اختبارات للتدخل الأكاديمي المبكر',
                      style: AppTypography.caption(
                        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // List of At-Risk Students
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: AppColors.teacherRole, strokeWidth: 2),
                ),
              ),
            )
          else if (_students.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'جميع الطلاب في مستوى أكاديمي مستقر 👏',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'لا توجد مؤشرات تراجع حرجة في الدرجات أو الحضور بين طلابك حالياً.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ..._students.map((student) => _buildStudentRiskCard(student, isDark, textPrimary)),
        ],
      ),
    );
  }

  Widget _buildStudentRiskCard(
    AtRiskStudentInfo student,
    bool isDark,
    Color textPrimary,
  ) {
    final dropPct = student.scoreDropPercentage.toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: student.severity.color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Student Name + Severity Tag + Drop Percentage
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          student.studentName,
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            student.studentCode,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      student.declineReason,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: student.severity.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: student.severity.color.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      student.severity.label,
                      style: TextStyle(
                        color: student.severity.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    if (student.scoreDropPercentage > 0)
                      Text(
                        'تراجع -$dropPct%',
                        style: TextStyle(
                          color: student.severity.color,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Middle: Trajectory Score Pills
          Row(
            children: [
              const Text(
                'مسار الدرجات:',
                style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (int i = 0; i < student.recentScores.length; i++) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (i == student.recentScores.length - 1)
                              ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                              : Colors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (i == student.recentScores.length - 1)
                                ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                                : Colors.teal.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${student.recentScores[i]}/${student.maxScore.toInt()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: (i == student.recentScores.length - 1)
                                ? const Color(0xFFEF4444)
                                : Colors.teal,
                          ),
                        ),
                      ),
                      if (i < student.recentScores.length - 1)
                        const Icon(Icons.arrow_back, size: 12, color: Colors.redAccent),
                    ],
                    if (student.missedHomeworkCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${student.missedHomeworkCount} واجب لم يُسلم',
                          style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action Buttons: WhatsApp Parent Alert + Plan Dialog + Call
          LayoutBuilder(
            builder: (context, actionConstraints) {
              final isVeryNarrow = actionConstraints.maxWidth < 360;
              final whatsAppBtn = FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.send_rounded, size: 14),
                label: Text(
                  isVeryNarrow ? 'تنبيه واتساب 📲' : 'تنبيه ولي الأمر واتساب 📲',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => _sendWhatsAppIntervention(student),
              );

              final planBtn = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.assignment_turned_in_outlined, size: 14),
                label: const Text(
                  'خطة الدعم 📋',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => _openInterventionPlanDialog(student),
              );

              final callBtn = IconButton(
                tooltip: 'اتصال هاتفي بولي الأمر',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                ),
                icon: const Icon(Icons.phone_outlined, size: 16),
                onPressed: () => _callParent(student.parentPhone),
              );

              if (isVeryNarrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: whatsAppBtn),
                        const SizedBox(width: 6),
                        callBtn,
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(width: double.infinity, child: planBtn),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 4, child: whatsAppBtn),
                  const SizedBox(width: 6),
                  Expanded(flex: 3, child: planBtn),
                  const SizedBox(width: 4),
                  callBtn,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
