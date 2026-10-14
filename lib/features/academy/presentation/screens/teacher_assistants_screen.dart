import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class TeacherAssistantsScreen extends StatefulWidget {
  final String teacherName;

  const TeacherAssistantsScreen({
    super.key,
    this.teacherName = 'أ. محمد عبد الله',
  });

  @override
  State<TeacherAssistantsScreen> createState() => _TeacherAssistantsScreenState();
}

class _TeacherAssistantsScreenState extends State<TeacherAssistantsScreen> {
  final List<Map<String, dynamic>> _assistants = [
    {
      'id': 'TA-101',
      'name': 'م. أحمد خالد',
      'phone': '01019998888',
      'assigned_groups': 'ثانوية عامة (أ، ب)',
      'can_grade_homework': true,
      'can_take_attendance': true,
      'can_manage_questions': true,
      'can_answer_inquiries': true,
      'can_view_finance': false, // Always restricted!
    },
    {
      'id': 'TA-102',
      'name': 'أ. سارة إبراهيم',
      'phone': '01122233344',
      'assigned_groups': 'أولى ثانوية (عام ولغات)',
      'can_grade_homework': true,
      'can_take_attendance': true,
      'can_manage_questions': false,
      'can_answer_inquiries': true,
      'can_view_finance': false, // Always restricted!
    },
  ];

  void _showAddAssistantDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final groupsCtrl = TextEditingController();

    bool gradeHw = true;
    bool takeAtt = true;
    bool manageQ = false;
    bool answerInq = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('إضافة مساعد جديد للمدرس (TA) 👨‍🏫'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المساعد بالكامل'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم هاتف المساعد'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: groupsCtrl,
                  decoration: const InputDecoration(labelText: 'المجموعات المسندة إليه'),
                ),
                const SizedBox(height: 16),
                const Text('صلاحيات المساعد داخل السنتر:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                SwitchListTile(
                  dense: true,
                  title: const Text('تصحيح الواجبات ورصد الدرجات', style: TextStyle(fontSize: 12)),
                  value: gradeHw,
                  onChanged: (val) => setDlgState(() => gradeHw = val),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('رصد الحضور والغياب للطلاب', style: TextStyle(fontSize: 12)),
                  value: takeAtt,
                  onChanged: (val) => setDlgState(() => takeAtt = val),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('إدارة وتعديل بنك الأسئلة', style: TextStyle(fontSize: 12)),
                  value: manageQ,
                  onChanged: (val) => setDlgState(() => manageQ = val),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('الرد على استفسارات الطلاب', style: TextStyle(fontSize: 12)),
                  value: answerInq,
                  onChanged: (val) => setDlgState(() => answerInq = val),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 16, color: Colors.red),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'محظور تماماً: الاطلاع على أرباح الحصة وتصفية الخزينة النقدية (خاص بالمدرس والسنتر فقط).',
                          style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) return;
                setState(() {
                  _assistants.add({
                    'id': 'TA-${DateTime.now().millisecondsSinceEpoch % 1000}',
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'assigned_groups': groupsCtrl.text.trim().isNotEmpty ? groupsCtrl.text.trim() : 'جميع المجموعات',
                    'can_grade_homework': gradeHw,
                    'can_take_attendance': takeAtt,
                    'can_manage_questions': manageQ,
                    'can_answer_inquiries': answerInq,
                    'can_view_finance': false,
                  });
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تمت إضافة المساعد وتعيين صلاحياته بنجاح')),
                );
              },
              child: const Text('حفظ وإضافة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('طاقم مساعدي المدرس (TAs) 👥'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAssistantDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('إضافة مساعد جديد', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إدارة طاقم مساعدي ${widget.teacherName}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'تخصيص صلاحيات تصحيح الواجبات والحضور للمساعدين، مع حجب كامل للبيانات المالية وتصفية الأرباح.',
                          style: TextStyle(fontSize: 11.5, color: textSecondary, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'المساعدون المعينون (${_assistants.length})',
              style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            ..._assistants.map((ta) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  ta['name'].toString().split(' ').first[0],
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ta['name'],
                                    style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${ta['phone']} • كود: ${ta['id']}',
                                    style: AppTypography.caption(textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onPressed: () {
                              setState(() => _assistants.remove(ta));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'المجموعات المسندة: ${ta['assigned_groups']}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),

                      // Permissions wrap
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildPermissionChip('تصحيح الواجبات', ta['can_grade_homework'] == true, isDark),
                          _buildPermissionChip('رصد الحضور', ta['can_take_attendance'] == true, isDark),
                          _buildPermissionChip('بنك الأسئلة', ta['can_manage_questions'] == true, isDark),
                          _buildPermissionChip('الرد على الطلاب', ta['can_answer_inquiries'] == true, isDark),
                          _buildPermissionChip('حظر الماليات والأرباح 🔒', true, isDark, isRestricted: true),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionChip(String label, bool isGranted, bool isDark, {bool isRestricted = false}) {
    if (isRestricted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.red)),
      );
    }

    final color = isGranted ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isGranted ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
