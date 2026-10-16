import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';
import '../widgets/homework_submissions_dialog.dart';

class HomeworkManagementScreen extends StatefulWidget {
  const HomeworkManagementScreen({super.key});

  @override
  State<HomeworkManagementScreen> createState() =>
      _HomeworkManagementScreenState();
}

class _HomeworkManagementScreenState extends State<HomeworkManagementScreen> {
  late final SupabaseHomeworkRepository _homeworkRepo;
  late final SupabaseGroupRepository _groupRepo;
  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  List<Homework> _homeworks = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _homeworkRepo = SupabaseHomeworkRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _groupRepo = SupabaseGroupRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _loadHomeworks();
  }

  Future<void> _loadHomeworks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _groupRepo.fetchGroups(status: 'active');
      final selected = _selectedGroup ?? (groups.isEmpty ? null : groups.first);
      final h = selected == null
          ? <Homework>[]
          : await _homeworkRepo.fetchHomeworkForGroup(selected.id);
      if (mounted) {
        setState(() {
          _groups = groups;
          _selectedGroup = selected;
          _homeworks = h;
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

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  void _showCreateHomeworkDialog() {
    final selectedGroup = _selectedGroup;
    if (selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار مجموعة دراسية نشطة أولاً.')),
      );
      return;
    }
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ptsCtrl = TextEditingController(text: '10');
    DateTime dueAt = DateTime.now().add(const Duration(days: 7));
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
                child: const Icon(Icons.assignment_add, color: AppColors.adminRole),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'إضافة واجب وتكليف جديد',
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
                          Text(
                            'المجموعة: ${selectedGroup.name} (${selectedGroup.code})',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الواجب أو التكليف *',
                        hintText: 'مثال: واجب الدرس الأول - الحركة في اتجاه واحد',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال عنوان الواجب' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'التعليمات والتفاصيل المطلوبة',
                        hintText: 'اكتب إرشادات حل الواجب أو صفحات الكتاب المطلوب حلها...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: ptsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الدرجة العظمى / النقاط المستحقة *',
                        hintText: '10',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'يرجى إدخال الدرجة العظمى';
                        final num = double.tryParse(v.trim());
                        if (num == null || num <= 0) return 'يرجى إدخال رقم صحيح أو عشري أكبر من صفر';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.event, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('آخر موعد لتسليم الواجب', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDate(dueAt),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dueAt,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 730)),
                              );
                              if (picked != null) {
                                setStateDialog(() => dueAt = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_month, size: 16),
                            label: const Text('تغيير التاريخ'),
                          ),
                        ],
                      ),
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

                      final maxScore = double.tryParse(ptsCtrl.text.trim()) ?? 10.0;
                      final nav = Navigator.of(ctx);
                      try {
                        final h = Homework(
                          id: '',
                          subjectId: selectedGroup.subjectId,
                          groupId: selectedGroup.id,
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim().isEmpty
                              ? null
                              : descCtrl.text.trim(),
                          dueAt: dueAt,
                          maxScore: maxScore,
                          status: 'published',
                        );

                        await _homeworkRepo.createHomework(h);
                        nav.pop();
                        _loadHomeworks();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إنشاء ونشر الواجب بنجاح!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل إنشاء الواجب: $e'),
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
              label: Text(isSubmitting ? 'جاري النشر...' : 'نشر الواجب'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHomeworkDialog(Homework h) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: h.title);
    final descCtrl = TextEditingController(text: h.description ?? '');
    final ptsCtrl = TextEditingController(text: h.maxScore.toString());
    DateTime dueAt = h.dueAt;
    String status = h.status;
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
                  'تعديل بيانات الواجب',
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
                        labelText: 'عنوان الواجب *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال عنوان الواجب' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'التعليمات والتفاصيل',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: ptsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'الدرجة العظمى *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'يرجى إدخال الدرجة';
                              final num = double.tryParse(v.trim());
                              if (num == null || num <= 0) return 'قيمة أكبر من صفر';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: status,
                            decoration: const InputDecoration(
                              labelText: 'حالة الواجب',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'published', child: Text('متاح للتسليم')),
                              DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                              DropdownMenuItem(value: 'closed', child: Text('مغلق التسليم')),
                            ],
                            onChanged: (v) {
                              if (v != null) setStateDialog(() => status = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.event, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('موعد التسليم النهائي', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDate(dueAt),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dueAt,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 730)),
                              );
                              if (picked != null) {
                                setStateDialog(() => dueAt = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_month, size: 16),
                            label: const Text('تغيير التاريخ'),
                          ),
                        ],
                      ),
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

                      final maxScore = double.tryParse(ptsCtrl.text.trim()) ?? 10.0;
                      final nav = Navigator.of(ctx);
                      try {
                        final updated = Homework(
                          id: h.id,
                          subjectId: h.subjectId,
                          groupId: h.groupId,
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim().isEmpty
                              ? null
                              : descCtrl.text.trim(),
                          dueAt: dueAt,
                          maxScore: maxScore,
                          status: status,
                        );

                        await _homeworkRepo.updateHomework(updated);
                        nav.pop();
                        _loadHomeworks();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تحديث بيانات الواجب بنجاح!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل تحديث الواجب: $e'),
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

  Widget _buildHomeworkCard(BuildContext context, Homework h) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final isOverdue = DateTime.now().isAfter(h.dueAt) && h.status != 'closed';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.adminRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment, color: AppColors.adminRole, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.title,
                      style: AppTypography.titleMedium(textPrimary).copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    if (h.description != null && h.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        h.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(textSecondary),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'الدرجة العظمى: ${h.maxScore}',
                            style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOverdue
                                ? Colors.red.withValues(alpha: 0.12)
                                : Colors.teal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event,
                                size: 14,
                                color: isOverdue ? Colors.red : Colors.teal,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'التسليم: ${_formatDate(h.dueAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOverdue ? Colors.red : Colors.teal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PortalStatusChip(status: h.status),
                  const SizedBox(height: 4),
                  PopupMenuButton<String>(
                    tooltip: 'خيارات',
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (value) async {
                      switch (value) {
                        case 'submissions':
                          _showSubmissionsDialog(h);
                          break;
                        case 'edit':
                          _showEditHomeworkDialog(h);
                          break;
                        case 'close':
                          if (h.status == 'closed') return;
                          try {
                            await _homeworkRepo.closeHomework(h.id);
                            _loadHomeworks();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('فشل إغلاق الواجب: $e')),
                              );
                            }
                          }
                          break;
                        case 'delete':
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('حذف الواجب'),
                              content: const Text(
                                'هل أنت متأكد من رغبتك في حذف هذا الواجب نهائياً؟',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('إلغاء'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('حذف'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await _homeworkRepo.deleteHomework(h.id);
                              _loadHomeworks();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم حذف الواجب بنجاح')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('فشل الحذف: $e')),
                                );
                              }
                            }
                          }
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'submissions',
                        child: ListTile(
                          leading: Icon(Icons.assignment_turned_in_outlined, color: AppColors.adminRole, size: 18),
                          title: Text('كشف التسليمات والتصحيح'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit, size: 18),
                          title: Text('تعديل الواجب'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (h.status != 'closed')
                        const PopupMenuItem(
                          value: 'close',
                          child: ListTile(
                            leading: Icon(Icons.lock_outline, size: 18),
                            title: Text('إغلاق التسليم'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          title: Text('حذف الواجب', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.adminRole,
                  side: const BorderSide(color: AppColors.adminRole),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.assignment_turned_in_rounded, size: 18),
                label: const Text('تسليمات الطلاب والتصحيح', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => _showSubmissionsDialog(h),
              ),
              Text(
                'معرف: ${h.id.length > 8 ? h.id.substring(0, 8) : h.id}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSubmissionsDialog(Homework h) {
    if (_selectedGroup == null) return;
    showDialog(
      context: context,
      builder: (ctx) => HomeworkSubmissionsDialog(
        homework: h,
        group: _selectedGroup!,
        onDataChanged: _loadHomeworks,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PortalPageShell(
      title: 'إدارة الواجبات والتكليفات',
      subtitle: 'نشر ومتابعة واجبات المجموعات، مواعيد التسليم، والدرجات المستحقة.',
      icon: Icons.assignment,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadHomeworks,
        ),
        if (_selectedGroup != null)
          PortalAction(
            icon: Icons.assignment_add,
            label: 'إضافة واجب جديد',
            onPressed: _showCreateHomeworkDialog,
            primary: true,
          ),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: false,
        emptyTitle: 'لا توجد بيانات واجبات',
        emptySubtitle: 'قم باختيار أو إنشاء مجموعة دراسية أولاً.',
        emptyIcon: Icons.assignment,
        onRetry: _loadHomeworks,
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
                    _loadHomeworks();
                  },
                ),
              ),
            Expanded(
              child: _selectedGroup == null
                  ? const Center(child: Text('لا توجد مجموعات دراسية نشطة حالياً.', style: TextStyle(color: Colors.grey)))
                  : _homeworks.isEmpty
                      ? const Center(
                          child: Text('لا توجد واجبات مسجلة لهذه المجموعة.', style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _homeworks.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _buildHomeworkCard(context, _homeworks[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
