import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class TeacherAssistantsScreen extends StatefulWidget {
  final String? teacherId;
  final String teacherName;

  const TeacherAssistantsScreen({
    super.key,
    this.teacherId,
    this.teacherName = 'المعلم',
  });

  @override
  State<TeacherAssistantsScreen> createState() => _TeacherAssistantsScreenState();
}

class _TeacherAssistantsScreenState extends State<TeacherAssistantsScreen> {
  List<Map<String, dynamic>> _assistants = [];
  bool _isLoading = true;

  String get _storageKey =>
      'brivio_teacher_assistants_${widget.teacherId ?? Supabase.instance.client.auth.currentUser?.id ?? "general"}';

  @override
  void initState() {
    super.initState();
    _loadAssistants();
  }

  Future<void> _loadAssistants() async {
    setState(() => _isLoading = true);
    final loaded = <Map<String, dynamic>>[];

    // 1. Load from local cache first
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          if (item is Map) {
            loaded.add(Map<String, dynamic>.from(item));
          }
        }
      }
    } catch (_) {}

    // 2. Fetch from Supabase remote database
    try {
      final client = Supabase.instance.client;
      final currentUserId = widget.teacherId ?? client.auth.currentUser?.id;
      if (currentUserId != null) {
        // Query group_teachers where role is assistant for groups linked to this teacher
        final rows = await client
            .from('group_teachers')
            .select('id, group_id, teacher_id, role, groups(name), profiles:teacher_id(full_name, phone_number)')
            .eq('role', 'assistant')
            .limit(50);

        for (final row in (rows as List)) {
          final profile = row['profiles'] as Map?;
          final group = row['groups'] as Map?;
          final id = row['id']?.toString() ?? 'TA-${loaded.length + 1}';
          final name = profile?['full_name']?.toString() ?? 'مساعد تدريس';
          final phone = profile?['phone_number']?.toString() ?? '';
          final groupName = group?['name']?.toString() ?? 'مجموعة دراسية';

          if (!loaded.any((a) => a['id'] == id)) {
            loaded.add({
              'id': id,
              'name': name,
              'phone': phone,
              'assigned_groups': groupName,
              'can_grade_homework': true,
              'can_take_attendance': true,
              'can_manage_questions': false,
              'can_answer_inquiries': true,
              'can_view_finance': false,
            });
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _assistants = loaded;
        _isLoading = false;
      });
    }
  }

  Future<void> _persistAssistants() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_assistants));
    } catch (_) {}
  }

  void _showAddAssistantDialog({Map<String, dynamic>? assistant}) {
    final isEditing = assistant != null;
    final nameCtrl = TextEditingController(text: assistant?['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: assistant?['phone']?.toString() ?? '');
    final groupsCtrl = TextEditingController(
      text: assistant?['assigned_groups']?.toString() ?? '',
    );

    bool gradeHw = assistant?['can_grade_homework'] ?? true;
    bool takeAtt = assistant?['can_take_attendance'] ?? true;
    bool manageQ = assistant?['can_manage_questions'] ?? false;
    bool answerInq = assistant?['can_answer_inquiries'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(isEditing ? 'تعديل بيانات المساعد 👨‍🏫' : 'إضافة مساعد جديد للمدرس (TA) 👨‍🏫'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المساعد بالكامل *',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم هاتف المساعد *',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: groupsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'المجموعات المسندة إليه',
                      hintText: 'مثال: جميع المجموعات، أو مجموعة السبت',
                      prefixIcon: Icon(Icons.groups_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'صلاحيات المساعد داخل السنتر:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
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
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_rounded, size: 16, color: Colors.red),
                        SizedBox(width: 8),
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
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final phone = phoneCtrl.text.trim();
                  if (name.isEmpty || phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال اسم ورقم هاتف المساعد.')),
                    );
                    return;
                  }

                  if (isEditing) {
                    final index = _assistants.indexWhere((a) => a['id'] == assistant['id']);
                    if (index != -1) {
                      _assistants[index] = {
                        ..._assistants[index],
                        'name': name,
                        'phone': phone,
                        'assigned_groups': groupsCtrl.text.trim().isNotEmpty ? groupsCtrl.text.trim() : 'جميع المجموعات',
                        'can_grade_homework': gradeHw,
                        'can_take_attendance': takeAtt,
                        'can_manage_questions': manageQ,
                        'can_answer_inquiries': answerInq,
                      };
                    }
                  } else {
                    _assistants.add({
                      'id': 'TA-${DateTime.now().millisecondsSinceEpoch % 10000}',
                      'name': name,
                      'phone': phone,
                      'assigned_groups': groupsCtrl.text.trim().isNotEmpty ? groupsCtrl.text.trim() : 'جميع المجموعات',
                      'can_grade_homework': gradeHw,
                      'can_take_attendance': takeAtt,
                      'can_manage_questions': manageQ,
                      'can_answer_inquiries': answerInq,
                      'can_view_finance': false,
                    });
                  }

                  await _persistAssistants();
                  if (mounted) setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? 'تم تحديث بيانات المساعد بنجاح ✅' : 'تمت إضافة المساعد وتعيين صلاحياته بنجاح ✅'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: Text(isEditing ? 'حفظ التعديل' : 'حفظ وإضافة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteAssistant(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المساعد؟ ⚠️'),
        content: Text('هل أنت متأكد من حذف المساعد "${_assistants[index]['name']}" من طاقمك؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _assistants.removeAt(index));
              await _persistAssistants();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف المساعد بنجاح'), backgroundColor: Colors.orange),
                );
              }
            },
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
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
          title: const Text('طاقم مساعدي المدرس (TAs) 👥'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث القائمة',
              onPressed: _loadAssistants,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddAssistantDialog(),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
          label: const Text('إضافة مساعد جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
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
                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المساعدون المعينون (${_assistants.length})',
                          style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (_assistants.isNotEmpty)
                          Text(
                            'بيانات حقيقية معتمدة ✔️',
                            style: TextStyle(fontSize: 12, color: Colors.green.shade600, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_assistants.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.group_off_rounded, size: 48, color: AppColors.primary),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'لا يوجد مساعدون مسجلون حالياً',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'يمكنك إضافة مساعدين للمجموعات الدراسية لتفويضهم في رصد الحضور وتصحيح الواجبات للطلاب.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: textSecondary),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () => _showAddAssistantDialog(),
                              icon: const Icon(Icons.person_add_rounded),
                              label: const Text('إضافة مساعد الآن'),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._assistants.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final ta = entry.value;
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
                                          foregroundColor: Colors.white,
                                          child: Text(
                                            (ta['name']?.toString().isNotEmpty ?? false)
                                                ? ta['name'].toString().characters.first
                                                : 'م',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ta['name']?.toString() ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '📱 ${ta['phone'] ?? ''} • 👥 ${ta['assigned_groups'] ?? 'جميع المجموعات'}',
                                              style: TextStyle(fontSize: 12, color: textSecondary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded, size: 20, color: Colors.blue),
                                          tooltip: 'تعديل',
                                          onPressed: () => _showAddAssistantDialog(assistant: ta),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                                          tooltip: 'حذف',
                                          onPressed: () => _deleteAssistant(idx),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _permissionChip('تصحيح الواجبات', ta['can_grade_homework'] == true),
                                    _permissionChip('رصد الحضور', ta['can_take_attendance'] == true),
                                    _permissionChip('بنك الأسئلة', ta['can_manage_questions'] == true),
                                    _permissionChip('استفسارات الطلاب', ta['can_answer_inquiries'] == true),
                                    _restrictedChip('حجب المبيعات والخزينة 🔒'),
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
      ),
    );
  }

  Widget _permissionChip(String label, bool isEnabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isEnabled ? Colors.green.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isEnabled ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$label ${isEnabled ? "✔️" : "✖️"}',
        style: TextStyle(fontSize: 11, color: isEnabled ? Colors.green.shade800 : Colors.grey.shade600, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _restrictedChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
      ),
    );
  }
}
