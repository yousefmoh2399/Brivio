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

  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'all'; // 'all', 'active', 'closed', 'overdue'

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                              content: Text('تم نشر الواجب للمجموعة بنجاح!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل إضافة الواجب: $e'),
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
              label: Text(isSubmitting ? 'جاري النشر...' : 'تأكيد ونشر الواجب'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHomeworkDialog(Homework homework) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: homework.title);
    final descCtrl = TextEditingController(text: homework.description ?? '');
    final ptsCtrl = TextEditingController(text: homework.maxScore.toString());
    DateTime dueAt = homework.dueAt;
    String status = homework.status;
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
                        labelText: 'التعليمات والإرشادات',
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
                              if (v == null || v.trim().isEmpty) return 'أدخل الدرجة';
                              if (double.tryParse(v.trim()) == null) return 'رقم غير صحيح';
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
                              DropdownMenuItem(value: 'published', child: Text('منشور ومفتوح')),
                              DropdownMenuItem(value: 'closed', child: Text('مغلق التسليم')),
                              DropdownMenuItem(value: 'draft', child: Text('مسودة')),
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
                                const Text('آخر موعد للتسليم', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                            label: const Text('تغيير'),
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

                      final nav = Navigator.of(ctx);
                      try {
                        final updated = Homework(
                          id: homework.id,
                          subjectId: homework.subjectId,
                          groupId: homework.groupId,
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim().isEmpty
                              ? null
                              : descCtrl.text.trim(),
                          dueAt: dueAt,
                          maxScore: double.tryParse(ptsCtrl.text.trim()) ?? homework.maxScore,
                          status: status,
                        );

                        await _homeworkRepo.updateHomework(updated);
                        nav.pop();
                        _loadHomeworks();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم حفظ تعديلات الواجب بنجاح!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل حفظ التعديلات: $e'),
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

  Widget _buildKpiSection(
    bool isDark,
    int totalCount,
    int activeCount,
    int overdueCount,
    int closedCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final kpiCards = [
          _buildKpiCard(
            title: 'إجمالي الواجبات',
            value: '$totalCount',
            icon: Icons.assignment_rounded,
            color: AppColors.adminRole,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'الواجبات النشطة',
            value: '$activeCount',
            icon: Icons.pending_actions_rounded,
            color: Colors.teal,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'تجاوزت الموعد',
            value: '$overdueCount',
            icon: Icons.alarm_off_rounded,
            color: Colors.red,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'واجبات مغلقة',
            value: '$closedCount',
            icon: Icons.lock_clock_rounded,
            color: Colors.blueGrey,
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
                _loadHomeworks();
              },
            ),
          ),
        );

        final searchField = TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'بحث في عنوان الواجب أو التعليمات...',
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
            _buildStatusFilterChip('all', 'جميع الواجبات', isDark),
            const SizedBox(width: 4),
            _buildStatusFilterChip('active', 'النشطة مفتوحة', isDark),
            const SizedBox(width: 4),
            _buildStatusFilterChip('overdue', 'متأخرة', isDark),
            const SizedBox(width: 4),
            _buildStatusFilterChip('closed', 'مغلقة', isDark),
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
    final color = value == 'overdue'
        ? Colors.red
        : value == 'closed'
            ? Colors.grey
            : AppColors.adminRole;

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

  Widget _buildHomeworkCard(BuildContext context, Homework h) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final isClosed = h.status.toLowerCase() == 'closed';
    final isOverdue = DateTime.now().isAfter(h.dueAt) && !isClosed;

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
          // Header Row: Assignment icon + Title / Description + Status Chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (isOverdue ? Colors.red : AppColors.adminRole).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.assignment_rounded,
                  color: isOverdue ? Colors.red : AppColors.adminRole,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium(textPrimary).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    if (h.description != null && h.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        h.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isClosed
                      ? Colors.grey.withValues(alpha: 0.12)
                      : isOverdue
                          ? Colors.red.withValues(alpha: 0.12)
                          : Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isClosed
                      ? 'مغلق'
                      : isOverdue
                          ? 'متأخر'
                          : 'مفتوح',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isClosed
                        ? Colors.grey.shade700
                        : isOverdue
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Metadata badges: Max score, Due date
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
                    const Icon(Icons.star_border_rounded, size: 12, color: Colors.blue),
                    const SizedBox(width: 3),
                    Text(
                      'الدرجة: ${h.maxScore}',
                      style: const TextStyle(fontSize: 10.5, color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isOverdue ? Colors.red.withValues(alpha: 0.08) : Colors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isOverdue ? Colors.red.withValues(alpha: 0.25) : Colors.teal.withValues(alpha: 0.25),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 12,
                      color: isOverdue ? Colors.red : Colors.teal,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'التسليم: ${_formatDate(h.dueAt)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isOverdue ? Colors.red : Colors.teal,
                        fontWeight: FontWeight.w600,
                      ),
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
              Flexible(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.adminRole,
                    side: const BorderSide(color: AppColors.adminRole, width: 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                  ),
                  icon: const Icon(Icons.assignment_turned_in_rounded, size: 15),
                  label: const Text(
                    'كشف التسليمات والتصحيح',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                  onPressed: () => _showSubmissionsDialog(h),
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'تعديل الواجب',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(5),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.edit_outlined, size: 17, color: Colors.blue),
                    onPressed: () => _showEditHomeworkDialog(h),
                  ),
                  if (!isClosed) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'إغلاق التسليم',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(5),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.lock_outline_rounded, size: 17, color: Colors.orange),
                      onPressed: () async {
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
                      },
                    ),
                  ],
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'حذف الواجب',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(5),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('حذف الواجب'),
                          content: Text('هل أنت متأكد من رغبتك في حذف واجب "${h.title}" نهائياً؟'),
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

    final filtered = _homeworks.where((h) {
      final matchesSearch = q.isEmpty ||
          h.title.toLowerCase().contains(q) ||
          (h.description?.toLowerCase().contains(q) ?? false);

      if (!matchesSearch) return false;

      final isClosed = h.status.toLowerCase() == 'closed';
      final isOverdue = DateTime.now().isAfter(h.dueAt) && !isClosed;
      final isActive = !isClosed && !isOverdue;

      if (_selectedStatusFilter == 'active' && !isActive) return false;
      if (_selectedStatusFilter == 'overdue' && !isOverdue) return false;
      if (_selectedStatusFilter == 'closed' && !isClosed) return false;

      return true;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = _homeworks.length;
    final activeCount = _homeworks.where((h) => h.status.toLowerCase() != 'closed' && !DateTime.now().isAfter(h.dueAt)).length;
    final overdueCount = _homeworks.where((h) => h.status.toLowerCase() != 'closed' && DateTime.now().isAfter(h.dueAt)).length;
    final closedCount = _homeworks.where((h) => h.status.toLowerCase() == 'closed').length;

    return PortalPageShell(
      title: 'إدارة الواجبات والتكليفات',
      subtitle: 'نشر ومتابعة واجبات المجموعات، مواعيد التسليم، ومتابعة تصحيح كشوفات الطلاب.',
      icon: Icons.assignment_rounded,
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
      headerWidgets: [
        _buildKpiSection(
          isDark,
          totalCount,
          activeCount,
          overdueCount,
          closedCount,
        ),
        const SizedBox(height: 12),
        if (_groups.isNotEmpty) _buildSearchAndFilterBar(isDark),
      ],
      child: PortalStateView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        isEmpty: false,
        emptyTitle: 'لا توجد بيانات واجبات',
        emptySubtitle: 'قم باختيار أو إنشاء مجموعة دراسية أولاً.',
        emptyIcon: Icons.assignment_rounded,
        onRetry: _loadHomeworks,
        child: _selectedGroup == null
                  ? const Center(child: Text('لا توجد مجموعات دراسية نشطة حالياً.'))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.assignment_late_outlined, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.isNotEmpty || _selectedStatusFilter != 'all'
                                    ? 'لا توجد واجبات تطابق معايير البحث'
                                    : 'لا توجد واجبات مسجلة لهذه المجموعة.',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'يمكنك إضافة واجب جديد لطلاب المجموعة وتحديد الموعد والدرجات.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('إضافة أول واجب'),
                                onPressed: _showCreateHomeworkDialog,
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
                                itemBuilder: (ctx, i) => _buildHomeworkCard(context, filtered[i]),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: filtered.length,
                              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) => _buildHomeworkCard(context, filtered[i]),
                            );
                          },
                        ),
      ),
    );
  }
}
