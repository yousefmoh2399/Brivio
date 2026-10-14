import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../domain/models/assessment_models.dart';
import 'exam_submissions_screen.dart';
import '../../../../core/services/report_generator_service.dart';

class ExamManagementScreen extends StatefulWidget {
  const ExamManagementScreen({super.key});

  @override
  State<ExamManagementScreen> createState() => _ExamManagementScreenState();
}

class _ExamManagementScreenState extends State<ExamManagementScreen> {
  late final SupabaseGroupRepository _groupRepo;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<Exam> _exams = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _groupRepo = SupabaseGroupRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _groupRepo.fetchGroups(status: 'active');
      final selected = _selectedGroup ?? (groups.isEmpty ? null : groups.first);
      final res = selected == null
          ? <dynamic>[]
          : await Supabase.instance.client
                .from('exams')
                .select()
                .eq('group_id', selected.id)
                .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _groups = groups;
          _selectedGroup = selected;
          _exams = res
              .map((e) => Exam.fromJson(e as Map<String, dynamic>))
              .toList();
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

  void _showCreateExamDialog() {
    final selectedGroup = _selectedGroup;
    if (selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إنشاء مجموعة دراسية نشطة أولاً.')),
      );
      return;
    }
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '45');
    final passCtrl = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة اختبار جديد للمجموعة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'عنوان الاختبار (مثال: اختبار شهر نوفمبر فيزياء)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: durationCtrl,
                decoration: const InputDecoration(
                  labelText: 'المدة بالدقائق',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(
                  labelText: 'درجة النجاح (%)',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final duration = int.tryParse(durationCtrl.text);
              final passScore = double.tryParse(passCtrl.text);
              if (titleCtrl.text.trim().isEmpty ||
                  duration == null ||
                  duration <= 0 ||
                  passScore == null ||
                  passScore < 0) {
                return;
              }

              final nav = Navigator.of(ctx);
              try {
                await Supabase.instance.client.rpc(
                  'create_exam_assignment',
                  params: {
                    'p_title': titleCtrl.text.trim(),
                    'p_subject_id': selectedGroup.subjectId,
                    'p_group_id': selectedGroup.id,
                    'p_duration_minutes': duration,
                    'p_pass_score': passScore,
                    'p_status': 'published',
                  },
                );
                nav.pop();
                _loadExams();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم إنشاء ونشر الاختبار بنجاح!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل إنشاء الاختبار: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('نشر الاختبار'),
          ),
        ],
      ),
    );
  }

  void _showEditExamDialog(Exam e) {
    final titleCtrl = TextEditingController(text: e.title);
    final durationCtrl = TextEditingController(
      text: e.durationMinutes.toString(),
    );
    final passCtrl = TextEditingController(text: e.passScore.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل بيانات الاختبار'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'عنوان الاختبار',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: durationCtrl,
                decoration: const InputDecoration(
                  labelText: 'المدة بالدقائق',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(
                  labelText: 'درجة النجاح (%)',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final duration = int.tryParse(durationCtrl.text);
              final passScore = double.tryParse(passCtrl.text);
              if (titleCtrl.text.trim().isEmpty ||
                  duration == null ||
                  duration <= 0 ||
                  passScore == null ||
                  passScore < 0) {
                return;
              }

              final nav = Navigator.of(ctx);
              try {
                await Supabase.instance.client
                    .from('exams')
                    .update({
                      'title': titleCtrl.text.trim(),
                      'duration_minutes': duration,
                      'pass_score': passScore,
                    })
                    .eq('id', e.id);
                nav.pop();
                _loadExams();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تحديث الاختبار بنجاح!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (err) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل التحديث: $err'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportExamData() async {
    try {
      final service = ReportGeneratorService();
      final examDataList = _exams
          .map(
            (e) => {
              'title': e.title,
              'duration': e.durationMinutes,
              'pass_score': e.passScore,
              'status': e.status,
            },
          )
          .toList();

      final groupName = _selectedGroup?.name ?? 'مجموعة';
      await service.generateExamReport(
        groupName: groupName,
        examData: examDataList,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصدير تقرير الاختبارات بنجاح 📄')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تصدير التقرير: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'إدارة الاختبارات والتقييمات',
      subtitle: 'نشر وجدولة اختبارات المجموعات وتحديد زمن الإجابة والتصحيح الآلي.',
      icon: Icons.quiz,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadExams,
        ),
        if (_selectedGroup != null)
          PortalAction(
            icon: Icons.quiz,
            label: 'إضافة اختبار',
            onPressed: _showCreateExamDialog,
            primary: true,
          ),
        if (_selectedGroup != null)
          PortalAction(
            icon: Icons.picture_as_pdf,
            label: 'تصدير تقرير (PDF)',
            onPressed: _exportExamData,
            primary: false,
          ),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: false,
        emptyTitle: 'لا توجد بيانات اختبارات',
        emptySubtitle: 'قم باختيار أو إنشاء مجموعة دراسية أولاً.',
        emptyIcon: Icons.quiz,
        onRetry: _loadExams,
        child: Column(
          children: [
            if (_groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<GroupEntity>(
                  initialValue: _selectedGroup,
                  decoration: const InputDecoration(labelText: 'اختر المجموعة الدراسية'),
                  items: _groups
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text('${g.name} (${g.code})'),
                        ),
                      )
                      .toList(),
                  onChanged: (group) {
                    if (group == null) return;
                    setState(() => _selectedGroup = group);
                    _loadExams();
                  },
                ),
              ),
            Expanded(
              child: _selectedGroup == null
                  ? const Center(child: Text('لا توجد مجموعات دراسية نشطة حالياً.', style: TextStyle(color: Colors.grey)))
                  : _exams.isEmpty
                  ? const Center(child: Text('لا توجد اختبارات مسجلة لهذه المجموعة.', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _exams.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final e = _exams[i];
                        return PortalListCard(
                          icon: Icons.quiz,
                          accentColor: AppColors.adminRole,
                          title: e.title,
                          subtitle:
                              'المدة: ${e.durationMinutes} دقيقة | درجة النجاح: ${e.passScore}% | الحالة: ${_statusInArabic(e.status)}',
                          trailing: [
                            PortalStatusChip(status: e.status),
                            PopupMenuButton<String>(
                              tooltip: 'خيارات',
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (value) async {
                                switch (value) {
                                  case 'submissions':
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (ctx) =>
                                            ExamSubmissionsScreen(exam: e),
                                      ),
                                    );
                                    break;
                                  case 'edit':
                                    _showEditExamDialog(e);
                                    break;
                                  case 'close':
                                    if (e.status == 'closed') return;
                                    try {
                                      await Supabase.instance.client
                                          .from('exams')
                                          .update({
                                            'status': 'closed',
                                            'updated_at': DateTime.now()
                                                .toIso8601String(),
                                          })
                                          .eq('id', e.id);
                                      _loadExams();
                                    } catch (err) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('فشل إغلاق الاختبار: $err'),
                                          ),
                                        );
                                      }
                                    }
                                    break;
                                  case 'delete':
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('حذف الاختبار'),
                                        content: const Text(
                                          'هل أنت متأكد من رغبتك في حذف هذا الاختبار نهائياً؟',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('إلغاء'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('حذف'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      try {
                                        await Supabase.instance.client.rpc(
                                          'delete_exam',
                                          params: {'exam_id': e.id},
                                        );
                                        _loadExams();
                                      } catch (err) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('فشل الحذف: $err'),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                    break;
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'submissions',
                                  child: ListTile(
                                    leading: Icon(Icons.people),
                                    title: Text('عرض الإجابات والتصحيح'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit),
                                    title: Text('تعديل الاختبار'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'close',
                                  child: ListTile(
                                    leading: Icon(Icons.lock_outline),
                                    title: Text('إغلاق الاختبار'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline, color: Colors.red),
                                    title: Text('حذف الاختبار', style: TextStyle(color: Colors.red)),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusInArabic(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return 'منشور';
      case 'draft':
        return 'مسودة';
      case 'closed':
        return 'مغلق';
      default:
        return status;
    }
  }
}
