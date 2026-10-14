import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../data/repositories/supabase_assessment_repositories.dart';
import '../../domain/models/assessment_models.dart';

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

  void _showCreateHomeworkDialog() {
    final selectedGroup = _selectedGroup;
    if (selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار مجموعة دراسية نشطة أولاً.')),
      );
      return;
    }
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ptsCtrl = TextEditingController(text: '10');
    DateTime? dueAt = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('إضافة تكليف / واجب جديد للمجموعة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الواجب أو التكليف',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'التعليمات والتفاصيل المطلوبة',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ptsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الدرجة العظمى / النقاط',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDate:
                          dueAt ?? DateTime.now().add(const Duration(days: 7)),
                    );
                    if (picked != null) setStateDialog(() => dueAt = picked);
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    dueAt == null
                        ? 'تحديد موعد التسليم النهائي'
                        : 'موعد التسليم: ${dueAt!.year}/${dueAt!.month}/${dueAt!.day}',
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
            ElevatedButton(
              onPressed: () async {
                final maxScore = double.tryParse(ptsCtrl.text);
                if (titleCtrl.text.trim().isEmpty ||
                    maxScore == null ||
                    maxScore <= 0 ||
                    dueAt == null) {
                  return;
                }

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
                    dueAt: dueAt!,
                    maxScore: maxScore,
                    status: 'published',
                  );

                  await _homeworkRepo.createHomework(h);
                  nav.pop();
                  _loadHomeworks();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إنشاء الواجب وتكليف الطلاب بنجاح!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
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
              child: const Text('نشر الواجب'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHomeworkDialog(Homework h) {
    final titleCtrl = TextEditingController(text: h.title);
    final descCtrl = TextEditingController(text: h.description ?? '');
    final ptsCtrl = TextEditingController(text: h.maxScore.toString());
    DateTime dueAt = h.dueAt;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('تعديل بيانات الواجب'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'عنوان الواجب'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'التعليمات والتفاصيل',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ptsCtrl,
                  decoration: const InputDecoration(labelText: 'الدرجة العظمى'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDate: dueAt,
                    );
                    if (picked != null) setStateDialog(() => dueAt = picked);
                  },
                  icon: const Icon(Icons.event),
                  label: Text('موعد التسليم: ${dueAt.year}/${dueAt.month}/${dueAt.day}'),
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
                final maxScore = double.tryParse(ptsCtrl.text);
                if (titleCtrl.text.trim().isEmpty ||
                    maxScore == null ||
                    maxScore <= 0) {
                  return;
                }

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
                    status: h.status,
                  );

                  await _homeworkRepo.updateHomework(updated);
                  nav.pop();
                  _loadHomeworks();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث الواجب بنجاح!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('فشل التحديث: $e'),
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
            icon: Icons.assignment,
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
                      padding: EdgeInsets.zero,
                      itemCount: _homeworks.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final h = _homeworks[i];
                        return PortalListCard(
                          icon: Icons.assignment,
                          accentColor: AppColors.adminRole,
                          title: h.title,
                          subtitle:
                              'الدرجة العظمى: ${h.maxScore} | التسليم: ${h.dueAt.year}/${h.dueAt.month}/${h.dueAt.day} | الحالة: ${_statusInArabic(h.status)}',
                          trailing: [
                            PortalStatusChip(status: h.status),
                            PopupMenuButton<String>(
                              tooltip: 'خيارات',
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (value) async {
                                switch (value) {
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('فشل إغلاق الواجب: $e'),
                                          ),
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
                                        await _homeworkRepo.deleteHomework(
                                          h.id,
                                        );
                                        _loadHomeworks();
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('فشل الحذف: $e'),
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
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit),
                                    title: Text('تعديل الواجب'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'close',
                                  child: ListTile(
                                    leading: Icon(Icons.lock_outline),
                                    title: Text('إغلاق التسليم'),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline, color: Colors.red),
                                    title: Text('حذف الواجب', style: TextStyle(color: Colors.red)),
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
        return 'متاح للتسليم';
      case 'draft':
        return 'مسودة';
      case 'closed':
        return 'مغلق التسليم';
      default:
        return status;
    }
  }
}
