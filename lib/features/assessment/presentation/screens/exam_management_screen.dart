import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';
import 'exam_submissions_screen.dart';

class ExamManagementScreen extends StatefulWidget {
  const ExamManagementScreen({super.key});

  @override
  State<ExamManagementScreen> createState() => _ExamManagementScreenState();
}

class _ExamManagementScreenState extends State<ExamManagementScreen> {
  late final SupabaseExamRepository _examRepo;
  late final SupabaseGroupRepository _groupRepo;
  late final SupabaseQuestionBankRepository _questionRepo;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<Exam> _exams = [];
  bool _isLoading = false;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'all'; // 'all', 'published', 'closed'

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _examRepo = SupabaseExamRepository(wrapper);
    _groupRepo = SupabaseGroupRepository(wrapper);
    _questionRepo = SupabaseQuestionBankRepository(wrapper);
    _loadExams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _groupRepo.fetchGroups(status: 'active');
      final selected = _selectedGroup ?? (groups.isEmpty ? null : groups.first);
      final list = selected == null
          ? <Exam>[]
          : await _examRepo.fetchExamsForGroup(selected.id);
      if (mounted) {
        setState(() {
          _groups = groups;
          _selectedGroup = selected;
          _exams = list;
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
        const SnackBar(content: Text('يرجى اختيار مجموعة دراسية نشطة أولاً.')),
      );
      return;
    }
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '45');
    final passCtrl = TextEditingController(text: '50');
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          actionsOverflowDirection: VerticalDirection.down,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.adminRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.quiz, color: AppColors.adminRole),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'إضافة وتعيين اختبار جديد',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width.clamp(280.0, 500.0),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.group, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'المجموعة: ${selectedGroup.name} (${selectedGroup.code})',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الاختبار *',
                        hintText: 'مثال: اختبار شهر نوفمبر - الباب الأول',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال عنوان الاختبار' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: durationCtrl,
                            decoration: const InputDecoration(
                              labelText: 'المدة بالدقائق *',
                              hintText: '45',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'أدخل المدة';
                              final val = int.tryParse(v.trim());
                              if (val == null || val <= 0) return 'أدخل رقم صحيح';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: passCtrl,
                            decoration: const InputDecoration(
                              labelText: 'نسبة النجاح (%) *',
                              hintText: '50',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'أدخل النسبة';
                              final val = double.tryParse(v.trim());
                              if (val == null || val < 0 || val > 100) return 'بين 0 و 100';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminRole,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setStateDialog(() => isSubmitting = true);

                      final duration = int.parse(durationCtrl.text.trim());
                      final passScore = double.parse(passCtrl.text.trim());
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
                        setStateDialog(() => isSubmitting = false);
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
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(isSubmitting ? 'جاري النشر...' : 'نشر الاختبار'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditExamDialog(Exam e) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: e.title);
    final durationCtrl = TextEditingController(text: e.durationMinutes.toString());
    final passCtrl = TextEditingController(text: e.passScore.toString());
    String status = e.status;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          actionsOverflowDirection: VerticalDirection.down,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.adminRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: AppColors.adminRole),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تعديل بيانات الاختبار',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width.clamp(280.0, 500.0),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الاختبار *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال عنوان الاختبار' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: durationCtrl,
                            decoration: const InputDecoration(
                              labelText: 'المدة بالدقائق *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'أدخل المدة';
                              final val = int.tryParse(v.trim());
                              if (val == null || val <= 0) return 'أدخل رقم صحيح';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: passCtrl,
                            decoration: const InputDecoration(
                              labelText: 'درجة النجاح (%) *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'أدخل النسبة';
                              final val = double.tryParse(v.trim());
                              if (val == null || val < 0 || val > 100) return 'بين 0 و 100';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'حالة الاختبار',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'published', child: Text('منشور ومتاح')),
                        DropdownMenuItem(value: 'closed', child: Text('مغلق')),
                        DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                      ],
                      onChanged: (v) {
                        if (v != null) setStateDialog(() => status = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adminRole,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setStateDialog(() => isSubmitting = true);

                      final duration = int.parse(durationCtrl.text.trim());
                      final passScore = double.parse(passCtrl.text.trim());
                      final nav = Navigator.of(ctx);

                      try {
                        await Supabase.instance.client
                            .from('exams')
                            .update({
                              'title': titleCtrl.text.trim(),
                              'duration_minutes': duration,
                              'pass_score': passScore,
                              'status': status,
                              'updated_at': DateTime.now().toIso8601String(),
                            })
                            .eq('id', e.id);

                        nav.pop();
                        _loadExams();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم حفظ التعديلات بنجاح!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (err) {
                        setStateDialog(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل حفظ التعديلات: $err'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(isSubmitting ? 'جاري الحفظ...' : 'حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManageQuestionsDialog(Exam exam) async {
    final selectedGroup = _selectedGroup;
    if (selectedGroup == null) return;

    List<Question> bankQuestions = [];
    bool loadingBank = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          if (loadingBank) {
            _questionRepo.fetchQuestionsForSubject(selectedGroup.subjectId).then((qList) {
              if (ctx.mounted) {
                setStateDialog(() {
                  bankQuestions = qList;
                  loadingBank = false;
                });
              }
            }).catchError((_) {
              if (ctx.mounted) {
                setStateDialog(() => loadingBank = false);
              }
            });
          }

          final linkedIds = exam.questions.map((q) => q.id).toSet();

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.format_list_numbered_rtl, color: AppColors.adminRole),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'إدارة أسئلة: ${exam.title}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width.clamp(280.0, 520.0),
              height: 480,
              child: loadingBank
                  ? const Center(child: CircularProgressIndicator())
                  : bankQuestions.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد أسئلة مسجلة في بنك الأسئلة لهذه المادة.\nيمكنك إضافة أسئلة من بنك الأسئلة أولاً.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          itemCount: bankQuestions.length,
                          separatorBuilder: (ctx, i) => const Divider(height: 8),
                          itemBuilder: (ctx, i) {
                            final q = bankQuestions[i];
                            final isLinked = linkedIds.contains(q.id);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              leading: Icon(
                                isLinked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                color: isLinked ? Colors.green : Colors.grey,
                              ),
                              title: Text(
                                q.prompt,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isLinked ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12.5,
                                ),
                              ),
                              subtitle: Text(
                                'النوع: ${_questionTypeLabel(q.questionType)} | الدرجة: ${q.defaultPoints}',
                                style: const TextStyle(fontSize: 10.5),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isLinked ? Colors.red.shade50 : Colors.green.shade50,
                                  foregroundColor: isLinked ? Colors.red : Colors.green.shade800,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () async {
                                  try {
                                    if (isLinked) {
                                      await _examRepo.unlinkQuestion(exam.id, q.id);
                                    } else {
                                      await _examRepo.linkQuestion(exam.id, q.id, q.defaultPoints);
                                    }
                                    _loadExams();
                                    Navigator.pop(ctx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(isLinked ? 'تمت إزالة السؤال من الاختبار' : 'تم ربط السؤال بالاختبار بنجاح'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('فشل تحديث الارتباط: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                },
                                child: Text(isLinked ? 'إزالة' : 'ربط', style: const TextStyle(fontSize: 11)),
                              ),
                            );
                          },
                        ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _questionTypeLabel(QuestionType type) {
    return switch (type) {
      QuestionType.multipleChoice => 'اختيار من متعدد',
      QuestionType.trueFalse => 'صواب أو خطأ',
      QuestionType.shortAnswer => 'إجابة قصيرة',
      QuestionType.longAnswer => 'إجابة مقالية',
    };
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildKpiSection(
    bool isDark,
    int totalCount,
    int activeCount,
    int closedCount,
    int totalQuestionsLinked,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final kpiCards = [
          _buildKpiCard(
            title: 'إجمالي الاختبارات',
            value: '$totalCount',
            icon: Icons.quiz_rounded,
            color: AppColors.adminRole,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'اختبارات نشطة',
            value: '$activeCount',
            icon: Icons.check_circle_outline_rounded,
            color: Colors.green,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'اختبارات مغلقة',
            value: '$closedCount',
            icon: Icons.lock_clock_rounded,
            color: Colors.grey,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'إجمالي الأسئلة المرتبطة',
            value: '$totalQuestionsLinked',
            icon: Icons.format_list_numbered_rtl_rounded,
            color: Colors.blue,
            isDark: isDark,
          ),
        ];

        if (isNarrow) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.3,
            children: kpiCards,
          );
        }

        return Row(
          children: kpiCards
              .map(
                (card) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: card,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;

        final groupSelector = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.darkBorder : Colors.black12, width: 0.8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<GroupEntity>(
              value: _selectedGroup,
              isExpanded: true,
              hint: const Text('اختر المجموعة الدراسية...'),
              items: _groups
                  .map(
                    (g) => DropdownMenuItem(
                      value: g,
                      child: Row(
                        children: [
                          const Icon(Icons.group_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${g.name} (${g.code})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
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
        );

        final searchField = TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'بحث في عنوان الاختبار...',
            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.black12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.black12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.adminRole, width: 1.2),
            ),
            filled: true,
            fillColor: isDark ? AppColors.darkSurface : Colors.white,
          ),
        );

        final filterChips = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusFilterChip('all', 'جميع الاختبارات', isDark),
            const SizedBox(width: 4),
            _buildStatusFilterChip('published', 'النشطة ومتاحة', isDark),
            const SizedBox(width: 4),
            _buildStatusFilterChip('closed', 'المغلقة', isDark),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              groupSelector,
              const SizedBox(height: 8),
              searchField,
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: filterChips,
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(flex: 2, child: groupSelector),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: searchField),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: filterChips,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusFilterChip(String value, String label, bool isDark) {
    final isSelected = _selectedStatusFilter == value;
    final color = value == 'closed' ? Colors.grey : AppColors.adminRole;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedStatusFilter = value),
      selectedColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected
            ? color
            : (isDark ? Colors.white70 : Colors.black87),
      ),
      side: BorderSide(
        color: isSelected
            ? color
            : (isDark ? AppColors.darkBorder : Colors.black12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildExamCard(BuildContext context, Exam e) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final isClosed = e.status.toLowerCase() == 'closed';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.black12,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header Row: Quiz Icon + Title + Status Chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.adminRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.quiz_rounded, color: AppColors.adminRole, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium(textPrimary).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'المعرف: ${e.id.length > 8 ? e.id.substring(0, 8) : e.id}',
                      style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isClosed
                      ? Colors.grey.withValues(alpha: 0.12)
                      : Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isClosed ? 'مغلق' : 'نشط ومتاح',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isClosed ? Colors.grey.shade700 : Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Metadata Badges: Duration, Pass score, Questions count
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2), width: 0.6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 12, color: Colors.blue),
                    const SizedBox(width: 3),
                    Text(
                      '${e.durationMinutes} دقيقة',
                      style: const TextStyle(fontSize: 10.5, color: Colors.blue, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.teal.withValues(alpha: 0.2), width: 0.6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 12, color: Colors.teal),
                    const SizedBox(width: 3),
                    Text(
                      'النجاح: ${e.passScore}%',
                      style: const TextStyle(fontSize: 10.5, color: Colors.teal, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 0.6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.format_list_numbered_rtl, size: 12, color: AppColors.primary),
                    const SizedBox(width: 3),
                    Text(
                      '${e.questions.length} أسئلة',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 12),

          // Action Toolbar Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.adminRole,
                  side: const BorderSide(color: AppColors.adminRole, width: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                icon: const Icon(Icons.people_alt_rounded, size: 15),
                label: const Text(
                  'عرض الإجابات والتصحيح',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => ExamSubmissionsScreen(exam: e),
                    ),
                  );
                },
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'إدارة أسئلة الاختبار',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.format_list_numbered_rtl_rounded, size: 18, color: Colors.indigo),
                    onPressed: () => _showManageQuestionsDialog(e),
                  ),
                  IconButton(
                    tooltip: 'تعديل الاختبار',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 17, color: Colors.blue),
                    onPressed: () => _showEditExamDialog(e),
                  ),
                  if (!isClosed)
                    IconButton(
                      tooltip: 'إغلاق الاختبار',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.lock_outline_rounded, size: 17, color: Colors.orange),
                      onPressed: () async {
                        try {
                          await Supabase.instance.client
                              .from('exams')
                              .update({
                                'status': 'closed',
                                'updated_at': DateTime.now().toIso8601String(),
                              })
                              .eq('id', e.id);
                          _loadExams();
                        } catch (err) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فشل إغلاق الاختبار: $err')),
                            );
                          }
                        }
                      },
                    ),
                  IconButton(
                    tooltip: 'حذف الاختبار نهائياً',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('حذف الاختبار'),
                          content: Text('هل أنت متأكد من رغبتك في حذف اختبار "${e.title}" نهائياً؟'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('تأكيد الحذف'),
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
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حذف الاختبار بنجاح')),
                            );
                          }
                        } catch (err) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فشل الحذف: $err')),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchController.text.toLowerCase().trim();

    final filtered = _exams.where((e) {
      final matchesSearch = q.isEmpty || e.title.toLowerCase().contains(q);
      if (!matchesSearch) return false;

      final isClosed = e.status.toLowerCase() == 'closed';
      if (_selectedStatusFilter == 'published' && isClosed) return false;
      if (_selectedStatusFilter == 'closed' && !isClosed) return false;

      return true;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = _exams.length;
    final activeCount = _exams.where((e) => e.status.toLowerCase() != 'closed').length;
    final closedCount = _exams.where((e) => e.status.toLowerCase() == 'closed').length;
    final totalQuestionsLinked = _exams.fold<int>(0, (sum, e) => sum + e.questions.length);

    return PortalPageShell(
      title: 'إدارة الاختبارات والتقييمات',
      subtitle: 'نشر وجدولة اختبارات المجموعات، تحديد زمن الإجابة، وإدارة بنود الأسئلة.',
      icon: Icons.quiz_rounded,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadExams,
        ),
        if (_selectedGroup != null)
          PortalAction(
            icon: Icons.add,
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
      headerWidgets: [
        _buildKpiSection(
          isDark,
          totalCount,
          activeCount,
          closedCount,
          totalQuestionsLinked,
        ),
        const SizedBox(height: 12),
        if (_groups.isNotEmpty) _buildSearchAndFilterBar(isDark),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: false,
        emptyTitle: 'لا توجد بيانات اختبارات',
        emptySubtitle: 'قم باختيار أو إنشاء مجموعة دراسية أولاً.',
        emptyIcon: Icons.quiz_rounded,
        onRetry: _loadExams,
        child: _selectedGroup == null
                  ? const Center(child: Text('لا توجد مجموعات دراسية نشطة حالياً.'))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.quiz_outlined, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.isNotEmpty || _selectedStatusFilter != 'all'
                                    ? 'لا توجد اختبارات تطابق معايير البحث والتصفية'
                                    : 'لا توجد اختبارات مسجلة لهذه المجموعة.',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'يمكنك إضافة اختبار جديد وربطه بالأسئلة من بنك الأسئلة.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('إضافة أول اختبار'),
                                onPressed: _showCreateExamDialog,
                              ),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 850;
                            final isMedium = constraints.maxWidth > 580;

                            if (isWide || isMedium) {
                              return GridView.builder(
                                padding: const EdgeInsets.only(bottom: 24),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  mainAxisExtent: 200,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (ctx, i) => _buildExamCard(context, filtered[i]),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: filtered.length,
                              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) => _buildExamCard(context, filtered[i]),
                            );
                          },
                        ),
      ),
    );
  }
}
