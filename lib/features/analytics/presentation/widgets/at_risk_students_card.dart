import 'package:flutter/material.dart';
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
  late List<AtRiskStudentInfo> _students;

  @override
  void initState() {
    super.initState();
    _students = widget.customStudents ?? _generateSimulatedAtRiskStudents();
  }

  List<AtRiskStudentInfo> _generateSimulatedAtRiskStudents() {
    return [
      const AtRiskStudentInfo(
        studentId: 'risk_01',
        studentName: 'عمر أحمد محمود',
        studentCode: 'STU-101',
        parentPhone: '01012345678',
        recentScores: [18.5, 13.0, 7.5],
        maxScore: 20.0,
        severity: AtRiskSeverity.critical,
        declineReason: 'تراجع بنسبة 59% في آخر 3 اختبارات متتالية، صعوبة واضحة في قوانين كيرشوف وتيار المتردد',
        suggestedIntervention: 'تخصيص جلسة مراجعة مجانية (1:1) مع المساعد لحل مسائل الدوائر المركبة',
        missedHomeworkCount: 3,
      ),
      const AtRiskStudentInfo(
        studentId: 'risk_02',
        studentName: 'زياد طارق إبراهيم',
        studentCode: 'STU-108',
        parentPhone: '01234567890',
        recentScores: [16.0, 11.0, 8.5],
        maxScore: 20.0,
        severity: AtRiskSeverity.warning,
        declineReason: 'انخفاض مستمر في درجة الاختبار الأسبوعي مع عدم تسليم آخر واجبين',
        suggestedIntervention: 'متابعة كشكول الواجب مع ولي الأمر وإعادة كويز الفصل الثالث',
        missedHomeworkCount: 2,
      ),
      const AtRiskStudentInfo(
        studentId: 'risk_03',
        studentName: 'سارة خالد علي',
        studentCode: 'STU-114',
        parentPhone: '01198765432',
        recentScores: [19.0, 17.5, 12.0],
        maxScore: 20.0,
        severity: AtRiskSeverity.homework,
        declineReason: 'مستوى متميز سابقاً لكن تراجعت في الاختبار الأخير بسبب التغيب عن حصتين متتاليتين',
        suggestedIntervention: 'إرسال تسجيل الحصة السابقة وإشعار ولي الأمر لتعويض الغياب',
        missedHomeworkCount: 1,
      ),
    ];
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
                    Row(
                      children: [
                        Text(
                          'رادار الطلاب المتعثرين وتحليلات الأداء التنبؤية 📉',
                          style: AppTypography.titleMedium(textPrimary).copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
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
                    Row(
                      children: [
                        Text(
                          student.studentName,
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(width: 8),
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
          Row(
            children: [
              Expanded(
                flex: 4,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: const Text(
                    'تنبيه ولي الأمر واتساب 📲',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _sendWhatsAppIntervention(student),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.assignment_turned_in_outlined, size: 14),
                  label: const Text(
                    'خطة الدعم 📋',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _openInterventionPlanDialog(student),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'اتصال هاتفي بولي الأمر',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                ),
                icon: const Icon(Icons.phone_outlined, size: 16),
                onPressed: () => _callParent(student.parentPhone),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
