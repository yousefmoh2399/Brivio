import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../domain/models/assessment_models.dart';

class ExamSubmissionsScreen extends StatefulWidget {
  final Exam exam;

  const ExamSubmissionsScreen({super.key, required this.exam});

  @override
  State<ExamSubmissionsScreen> createState() => _ExamSubmissionsScreenState();
}

class _ExamSubmissionsScreenState extends State<ExamSubmissionsScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _submissions = [];

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await Supabase.instance.client
          .from('exam_attempts')
          .select('*, students(profiles(full_name, email, phone_number))')
          .eq('exam_id', widget.exam.id)
          .order('score', ascending: false);

      if (mounted) {
        setState(() {
          _submissions = res as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showSendWhatsAppDialog({
    required String studentName,
    required String examTitle,
    required num score,
    required num maxScore,
    String? defaultPhone,
    int? rank,
  }) {
    final phoneCtrl = TextEditingController(text: defaultPhone ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.chat_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('إرسال النتيجة لواتساب ولي الأمر'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الطالب: $studentName', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('الدرجة: $score من $maxScore'),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم هاتف ولي الأمر (واتساب)',
                hintText: 'مثال: 01012345678',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            icon: const Icon(Icons.send_rounded),
            label: const Text('إرسال عبر واتساب'),
            onPressed: () async {
              final phone = phoneCtrl.text.trim();
              if (phone.isEmpty) return;
              Navigator.pop(ctx);
              await WhatsAppService.sendExamResultToParent(
                parentPhone: phone,
                studentName: studentName,
                examTitle: examTitle,
                score: score,
                maxScore: maxScore,
                centerName: 'سنتر الأوائل التعليمي',
                rank: rank,
                totalStudentsInGroup: _submissions.length,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Submissions for ${widget.exam.title}')),
      body: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: _submissions.isEmpty,
        emptyTitle: 'No submissions yet',
        emptySubtitle: 'Students have not submitted this exam.',
        emptyIcon: Icons.assignment_ind,
        onRetry: _loadSubmissions,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _submissions.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final sub = _submissions[i];
            final studentInfo = sub['students'] ?? {};
            final profile = studentInfo['profiles'] ?? {};
            final studentName = profile['full_name'] ?? 'Unknown Student';
            final phone = profile['phone_number']?.toString();
            final score = sub['score'] ?? 0;
            final maxScore = sub['max_score'] ?? (widget.exam.passScore * 2);

            return PortalListCard(
              icon: Icons.person,
              accentColor: AppColors.adminRole,
              title: studentName,
              subtitle:
                  'Score: $score / $maxScore | Rank: #${i + 1} | Submitted: ${sub['submitted_at'] ?? 'N/A'}',
              trailing: [
                IconButton(
                  icon: const Icon(Icons.chat_rounded, color: Colors.green),
                  tooltip: 'إرسال لولي الأمر عبر واتساب',
                  onPressed: () {
                    _showSendWhatsAppDialog(
                      studentName: studentName,
                      examTitle: widget.exam.title,
                      score: score,
                      maxScore: maxScore,
                      defaultPhone: phone,
                      rank: i + 1,
                    );
                  },
                ),
                Text(
                  'Score: $score',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
