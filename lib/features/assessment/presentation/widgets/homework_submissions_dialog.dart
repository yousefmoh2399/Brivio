import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../domain/models/assessment_models.dart';
import '../screens/student_submissions_screen.dart';

class HomeworkSubmissionsDialog extends StatefulWidget {
  final Homework homework;
  final GroupEntity group;
  final VoidCallback onDataChanged;

  const HomeworkSubmissionsDialog({
    super.key,
    required this.homework,
    required this.group,
    required this.onDataChanged,
  });

  @override
  State<HomeworkSubmissionsDialog> createState() =>
      _HomeworkSubmissionsDialogState();
}

class _HomeworkSubmissionsDialogState extends State<HomeworkSubmissionsDialog> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];
  String _filter = 'all'; // 'all', 'submitted', 'missing'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final wrapper = SupabaseClientWrapper(Supabase.instance.client);
      final studentRepo = SupabaseStudentRepository(wrapper);
      final students = await studentRepo.fetchStudentsForGroup(widget.group.id);

      final subsRes = await Supabase.instance.client
          .from('homework_submissions')
          .select('*')
          .eq('homework_id', widget.homework.id);

      final subsList = List<Map<String, dynamic>>.from(subsRes);
      final subsByStudent = {
        for (final sub in subsList) sub['student_id']?.toString(): sub,
      };

      final records = <Map<String, dynamic>>[];
      for (final st in students) {
        final sub = subsByStudent[st.id];
        final isSubmitted = sub != null;
        DateTime? submittedAt;
        if (sub != null) {
          final dateStr = sub['submitted_at'] ?? sub['created_at'];
          if (dateStr != null) {
            submittedAt = DateTime.tryParse(dateStr.toString())?.toLocal();
          }
        }
        final isLate = submittedAt != null && submittedAt.isAfter(widget.homework.dueAt);

        records.add({
          'student_id': st.id,
          'student_name': st.fullName,
          'student_code': st.studentCode,
          'phone_number': st.phoneNumber,
          'is_submitted': isSubmitted,
          'is_late': isLate,
          'submitted_at': submittedAt != null
              ? '${submittedAt.month}/${submittedAt.day} ${submittedAt.hour.toString().padLeft(2, '0')}:${submittedAt.minute.toString().padLeft(2, '0')}'
              : null,
          'score': sub?['score'],
          'status': sub?['status'] ?? (isSubmitted ? 'submitted' : 'missing'),
          'feedback': sub?['teacher_feedback'],
          'submission_raw': sub,
        });
      }

      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportRosterPdf() async {
    try {
      await ReportGeneratorService().generateHomeworkSubmissionsRosterPdf(
        centerName: 'المركز التعليمي',
        homeworkTitle: widget.homework.title,
        subjectName: widget.group.name,
        teacherName: 'المعلم المعتمد',
        groupName: widget.group.name,
        dueAt: widget.homework.dueAt,
        maxScore: widget.homework.maxScore,
        submissionsData: _records,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تصدير كشف التسليمات: $e')),
        );
      }
    }
  }

  Future<void> _exportPrintableSheetPdf() async {
    try {
      final questionsData = widget.homework.questions.map((q) => {
        'prompt': q.prompt,
        'points': q.defaultPoints,
        'type': q.questionType.toDbValue(),
        'options': q.options.map((o) => {'text': o.text, 'is_correct': o.isCorrect}).toList(),
      }).toList();

      await ReportGeneratorService().generatePrintableHomeworkSheet(
        centerName: 'المركز التعليمي',
        homeworkTitle: widget.homework.title,
        subjectName: widget.group.name,
        teacherName: 'المعلم المعتمد',
        groupName: widget.group.name,
        dueAt: widget.homework.dueAt,
        maxScore: widget.homework.maxScore,
        questions: questionsData,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في توليد شيت الواجب للطباعة: $e')),
        );
      }
    }
  }

  Future<void> _sendWhatsAppReminder(Map<String, dynamic> r) async {
    final phone = r['phone_number']?.toString() ?? '';
    final studentName = r['student_name']?.toString() ?? '';

    final phoneController = TextEditingController(text: phone);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('إرسال تذكير بالواجب لولي الأمر عبر واتساب 📲'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الطالب: $studentName', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('الواجب: ${widget.homework.title}'),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم هاتف ولي الأمر (واتساب)',
                prefixIcon: Icon(Icons.phone_rounded),
                hintText: '01XXXXXXXXX',
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('إرسال الآن'),
          ),
        ],
      ),
    );

    if (confirmed == true && phoneController.text.trim().isNotEmpty) {
      await WhatsAppService.sendHomeworkReminderToParent(
        parentPhone: phoneController.text.trim(),
        studentName: studentName,
        homeworkTitle: widget.homework.title,
        dueAt: widget.homework.dueAt,
        centerName: 'المركز التعليمي',
        subjectName: widget.group.name,
        groupName: widget.group.name,
      );
    }
  }

  Future<void> _sendWhatsAppResult(Map<String, dynamic> r) async {
    final phone = r['phone_number']?.toString() ?? '';
    final studentName = r['student_name']?.toString() ?? '';
    final score = (r['score'] as num?) ?? 0;

    final phoneController = TextEditingController(text: phone);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('إرسال نتيجة الواجب لولي الأمر عبر واتساب 📲'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الطالب: $studentName', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('الدرجة المحققة: $score من ${widget.homework.maxScore}'),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'رقم هاتف ولي الأمر (واتساب)',
                prefixIcon: Icon(Icons.phone_rounded),
                hintText: '01XXXXXXXXX',
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('إرسال الآن'),
          ),
        ],
      ),
    );

    if (confirmed == true && phoneController.text.trim().isNotEmpty) {
      await WhatsAppService.sendHomeworkResultToParent(
        parentPhone: phoneController.text.trim(),
        studentName: studentName,
        homeworkTitle: widget.homework.title,
        score: score,
        maxScore: widget.homework.maxScore,
        centerName: 'المركز التعليمي',
        teacherFeedback: r['feedback']?.toString(),
        subjectName: widget.group.name,
        groupName: widget.group.name,
      );
    }
  }

  void _openGrading(Map<String, dynamic> r) async {
    final sub = r['submission_raw'];
    if (sub == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentSubmissionsScreen(
          initialSubmission: {
            'id': sub['id'],
            'assessment_type': 'homework',
            'assessment_id': widget.homework.id,
            'assessment_title': widget.homework.title,
            'student_id': r['student_id'],
            'student_full_name': r['name'] ?? r['student_name'] ?? 'طالب',
            'score': sub['score'] ?? 0,
            'max_score': widget.homework.maxScore,
            'attachment_url': sub['attachment_url'],
            'submission_text': sub['submission_text'],
            'teacher_feedback': sub['teacher_feedback'] ?? '',
          },
          onGraded: () {
            widget.onDataChanged();
          },
        ),
      ),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    final totalStudents = _records.length;
    final submittedCount = _records.where((r) => r['is_submitted'] == true).length;
    final missingCount = totalStudents - submittedCount;
    final submissionRate = totalStudents > 0 ? (submittedCount / totalStudents) * 100 : 0.0;

    double totalGrades = 0;
    int gradedCount = 0;
    for (final r in _records) {
      if (r['score'] != null) {
        totalGrades += (r['score'] as num).toDouble();
        gradedCount++;
      }
    }
    final avgScore = gradedCount > 0 ? totalGrades / gradedCount : 0.0;

    final filteredRecords = _records.where((r) {
      if (_filter == 'submitted' && r['is_submitted'] != true) return false;
      if (_filter == 'missing' && r['is_submitted'] == true) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final name = (r['student_name']?.toString() ?? '').toLowerCase();
        final code = (r['student_code']?.toString() ?? '').toLowerCase();
        if (!name.contains(query) && !code.contains(query)) return false;
      }
      return true;
    }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 20,
        vertical: isCompact ? 12 : 24,
      ),
      child: Container(
        width: screenWidth.clamp(320.0, 780.0),
        height: MediaQuery.of(context).size.height * 0.90,
        padding: EdgeInsets.all(isCompact ? 14 : 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Dialog Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.adminRole.withValues(alpha: 0.15),
                  child: const Icon(Icons.assignment_turned_in_rounded, color: AppColors.adminRole),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'كشف تسليمات وتصحيح الواجب 📋',
                        style: TextStyle(
                          fontSize: isCompact ? 15 : 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${widget.homework.title} • ${widget.group.name}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Metrics Row
            if (isCompact)
              Column(
                children: [
                  Row(
                    children: [
                      _buildMetricCard('إجمالي الطلاب', '$totalStudents', Colors.blueGrey),
                      const SizedBox(width: 8),
                      _buildMetricCard('تم التسليم', '$submittedCount (${submissionRate.toStringAsFixed(0)}%)', Colors.green),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildMetricCard('لم يسلّم', '$missingCount', missingCount > 0 ? Colors.red : Colors.grey),
                      const SizedBox(width: 8),
                      _buildMetricCard('متوسط الدرجات', '${avgScore.toStringAsFixed(1)} / ${widget.homework.maxScore.toStringAsFixed(0)}', Colors.purple),
                    ],
                  ),
                ],
              )
            else
              Row(
                children: [
                  _buildMetricCard('إجمالي الطلاب', '$totalStudents', Colors.blueGrey),
                  const SizedBox(width: 8),
                  _buildMetricCard('تم التسليم', '$submittedCount (${submissionRate.toStringAsFixed(0)}%)', Colors.green),
                  const SizedBox(width: 8),
                  _buildMetricCard('لم يسلّم', '$missingCount', missingCount > 0 ? Colors.red : Colors.grey),
                  const SizedBox(width: 8),
                  _buildMetricCard('متوسط الدرجات', '${avgScore.toStringAsFixed(1)} / ${widget.homework.maxScore.toStringAsFixed(0)}', Colors.purple),
                ],
              ),
            const SizedBox(height: 12),

            // PDF Actions Bar
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _exportRosterPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.indigo),
                  label: const Text('كشف التسليمات (PDF)', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton.icon(
                  onPressed: _exportPrintableSheetPdf,
                  icon: const Icon(Icons.print_rounded, size: 16, color: Colors.deepPurple),
                  label: const Text('شيت واجب للطباعة (PDF)', style: TextStyle(fontSize: 12)),
                ),
                IconButton(
                  tooltip: 'تحديث البيانات',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadData,
                ),
              ],
            ),
            const Divider(height: 18),

            // Search and Filters
            if (isCompact) ...[
              TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث باسم الطالب أو الكود...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'all', label: Text('الكل ($totalStudents)', style: const TextStyle(fontSize: 10))),
                    ButtonSegment(value: 'submitted', label: Text('سلّم ($submittedCount)', style: const TextStyle(fontSize: 10))),
                    ButtonSegment(value: 'missing', label: Text('لم يسلّم ($missingCount)', style: const TextStyle(fontSize: 10))),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (set) => setState(() => _filter = set.first),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم الطالب أو الكود...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'all', label: Text('الكل ($totalStudents)', style: const TextStyle(fontSize: 11))),
                      ButtonSegment(value: 'submitted', label: Text('سلّم ($submittedCount)', style: const TextStyle(fontSize: 11))),
                      ButtonSegment(value: 'missing', label: Text('لم يسلّم ($missingCount)', style: const TextStyle(fontSize: 11))),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (set) => setState(() => _filter = set.first),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),

            // Students List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text('خطأ: $_error', style: const TextStyle(color: Colors.red)))
                  : filteredRecords.isEmpty
                  ? Center(
                      child: Text(
                        'لا يوجد طلاب مطابقين للبحث',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredRecords.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final r = filteredRecords[idx];
                        final isSubmitted = r['is_submitted'] == true;
                        final isLate = r['is_late'] == true;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSubmitted
                                  ? Colors.green.withValues(alpha: 0.3)
                                  : Colors.red.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: isSubmitted
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.red.withValues(alpha: 0.1),
                                child: Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSubmitted ? Colors.green.shade800 : Colors.red.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      children: [
                                        Text(
                                          r['student_name']?.toString() ?? 'طالب',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: textColor,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isSubmitted
                                                ? (isLate ? Colors.amber.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.12))
                                                : Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            !isSubmitted
                                                ? 'لم يسلّم ❌'
                                                : (isLate ? 'متأخر ⚠️' : 'في الموعد ✔️'),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: !isSubmitted
                                                  ? Colors.red.shade700
                                                  : (isLate ? Colors.orange.shade800 : Colors.green.shade700),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'كود: ${r['student_code'] ?? '-'} ${r['submitted_at'] != null ? '• تاريخ: ${r['submitted_at']}' : ''}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                    if (r['feedback'] != null && r['feedback'].toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          'ملاحظة: ${r['feedback']}',
                                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Score and Action buttons
                              if (isSubmitted) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    r['score'] != null ? '${r['score']} / ${widget.homework.maxScore.toStringAsFixed(0)}' : 'قيد التصحيح',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: 'مراجعة وتصحيح الإجابات 📝',
                                  icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 20),
                                  onPressed: () => _openGrading(r),
                                ),
                                IconButton(
                                  tooltip: 'إرسال النتيجة لولي الأمر واتساب 📲',
                                  icon: const Icon(Icons.chat_rounded, color: Colors.green, size: 18),
                                  onPressed: () => _sendWhatsAppResult(r),
                                ),
                              ] else ...[
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green.shade800,
                                    side: BorderSide(color: Colors.green.shade400),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  ),
                                  icon: const Icon(Icons.chat_rounded, size: 13),
                                  label: const Text('تذكير واتساب', style: TextStyle(fontSize: 11)),
                                  onPressed: () => _sendWhatsAppReminder(r),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade700), maxLines: 1),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
