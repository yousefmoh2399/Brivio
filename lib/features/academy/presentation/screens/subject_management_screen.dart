import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';

class SubjectManagementScreen extends StatefulWidget {
  const SubjectManagementScreen({super.key});

  @override
  State<SubjectManagementScreen> createState() =>
      _SubjectManagementScreenState();
}

class _SubjectManagementScreenState extends State<SubjectManagementScreen> {
  late final SupabaseSubjectRepository _subjectRepo;
  List<SubjectEntity> _subjects = [];
  Map<String, int> _subjectGroupCounts = {};
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'all'; // 'all', 'active', 'archived'

  @override
  void initState() {
    super.initState();
    _subjectRepo = SupabaseSubjectRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _loadSubjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? centerId;
      final curUser = Supabase.instance.client.auth.currentUser;
      if (curUser != null) {
        try {
          final p = await Supabase.instance.client
              .from('profiles')
              .select('center_id')
              .eq('id', curUser.id)
              .maybeSingle();
          centerId = p?['center_id']?.toString();
        } catch (_) {}
      }

      List<SubjectEntity> res = [];
      if (centerId != null) {
        try {
          final sRes = await Supabase.instance.client
              .from('subjects')
              .select()
              .eq('center_id', centerId)
              .order('name');
          res = (sRes as List)
              .map((j) => SubjectEntity.fromJson(Map<String, dynamic>.from(j as Map)))
              .toList();
        } catch (_) {}
      }
      if (res.isEmpty) {
        try {
          res = await _subjectRepo.fetchSubjects();
        } catch (_) {}
      }

      // Fetch group counts per subject
      final Map<String, int> groupCounts = {};
      try {
        final groupsRes = await Supabase.instance.client
            .from('groups')
            .select('subject_id');
        for (final item in (groupsRes as List)) {
          final sid = item['subject_id']?.toString();
          if (sid != null && sid.isNotEmpty) {
            groupCounts[sid] = (groupCounts[sid] ?? 0) + 1;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _subjects = res;
          _subjectGroupCounts = groupCounts;
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

  void _copySubjectCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ كود المادة ($code) إلى الحافظة 📋'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleSubjectStatus(SubjectEntity s) async {
    final newStatus = s.status.toLowerCase() == 'active' ? 'archived' : 'active';
    try {
      final updated = SubjectEntity(
        id: s.id,
        name: s.name,
        code: s.code,
        description: s.description,
        status: newStatus,
      );
      await _subjectRepo.updateSubject(updated);
      _loadSubjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'active'
                  ? 'تم تنشيط مادة "${s.name}" بنجاح 🟢'
                  : 'تم أرشفة مادة "${s.name}" ⚪',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تعديل حالة المادة: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDeleteSubjectDialog(SubjectEntity subject) {
    final groupCount = _subjectGroupCounts[subject.id] ?? 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text(
              'حذف المادة الدراسية',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          groupCount > 0
              ? 'تنبيه: يوجد ($groupCount) مجموعة دراسية مرتبطة بمادة "${subject.name}".\nهل أنت متأكد من حذف هذه المادة؟ قد يؤثر ذلك على المجموعات والجدول الدراسي.'
              : 'هل أنت متأكد من حذف مادة "${subject.name}" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                try {
                  await _subjectRepo.deleteSubject(subject.id);
                } catch (_) {
                  await Supabase.instance.client
                      .from('subjects')
                      .delete()
                      .eq('id', subject.id);
                }
                _loadSubjects();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم حذف مادة "${subject.name}" بنجاح.'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تعذر حذف المادة: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  void _showCreateSubjectDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.adminRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded, color: AppColors.adminRole, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'إضافة مادة دراسية جديدة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width.clamp(280.0, 480.0),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم المادة *',
                        hintText: 'مثال: الرياضيات، الفيزياء، الكيمياء',
                        prefixIcon: Icon(Icons.book_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المادة' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'كود المادة *',
                        hintText: 'مثال: MATH-01',
                        prefixIcon: Icon(Icons.tag_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال كود المادة' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الوصف أو الملاحظات الأكاديمية (اختياري)',
                        hintText: 'المرحلة المستهدفة، ملخص المنهج...',
                        prefixIcon: Icon(Icons.notes_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowAlignment: OverflowBarAlignment.end,
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
                        String? centerId;
                        final curUser = Supabase.instance.client.auth.currentUser;
                        if (curUser != null) {
                          try {
                            final p = await Supabase.instance.client
                                .from('profiles')
                                .select('center_id')
                                .eq('id', curUser.id)
                                .maybeSingle();
                            centerId = p?['center_id']?.toString();
                          } catch (_) {}
                        }

                        final subjectPayload = <String, dynamic>{
                          'code': codeCtrl.text.trim().toUpperCase(),
                          'name': nameCtrl.text.trim(),
                          'description': descCtrl.text.trim().isEmpty
                              ? null
                              : descCtrl.text.trim(),
                          'status': 'active',
                        };

                        if (centerId != null) {
                          try {
                            await Supabase.instance.client
                                .from('subjects')
                                .insert({...subjectPayload, 'center_id': centerId});
                          } catch (_) {
                            await Supabase.instance.client
                                .from('subjects')
                                .insert(subjectPayload);
                          }
                        } else {
                          await Supabase.instance.client
                              .from('subjects')
                              .insert(subjectPayload);
                        }

                        nav.pop();
                        _loadSubjects();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تمت إضافة المادة الدراسية بنجاح!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل إضافة المادة: $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
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
              label: Text(isSubmitting ? 'جاري الحفظ...' : 'حفظ المادة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSubjectDialog(SubjectEntity subject) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: subject.name);
    final codeCtrl = TextEditingController(text: subject.code);
    final descCtrl = TextEditingController(text: subject.description ?? '');
    String status = subject.status;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.adminRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_rounded, color: AppColors.adminRole, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تعديل بيانات المادة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width.clamp(280.0, 480.0),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم المادة *',
                        prefixIcon: Icon(Icons.book_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المادة' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'كود المادة *',
                        prefixIcon: Icon(Icons.tag_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال كود المادة' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الوصف أو الملاحظات',
                        prefixIcon: Icon(Icons.notes_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status.toLowerCase() == 'archived' ? 'archived' : 'active',
                      decoration: const InputDecoration(
                        labelText: 'حالة المادة',
                        prefixIcon: Icon(Icons.toggle_on_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('نشطة ومتاحة (Active) 🟢'),
                        ),
                        DropdownMenuItem(
                          value: 'archived',
                          child: Text('مؤرشفة (Archived) ⚪'),
                        ),
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
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowAlignment: OverflowBarAlignment.end,
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
                        final updated = SubjectEntity(
                          id: subject.id,
                          code: codeCtrl.text.trim().toUpperCase(),
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim().isEmpty
                              ? null
                              : descCtrl.text.trim(),
                          status: status,
                        );

                        await _subjectRepo.updateSubject(updated);
                        nav.pop();
                        _loadSubjects();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم حفظ تعديلات المادة بنجاح!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
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
                              behavior: SnackBarBehavior.floating,
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

  Widget _buildKpiSection(
    bool isDark,
    int total,
    int active,
    int archived,
    int totalGroups,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 750;
        final kpiTotal = _buildKpiItem(
          label: 'إجمالي المواد',
          value: total.toString(),
          icon: Icons.menu_book_rounded,
          color: AppColors.adminRole,
          isDark: isDark,
        );
        final kpiActive = _buildKpiItem(
          label: 'المواد النشطة',
          value: active.toString(),
          icon: Icons.check_circle_rounded,
          color: Colors.green,
          isDark: isDark,
        );
        final kpiArchived = _buildKpiItem(
          label: 'المؤرشفة',
          value: archived.toString(),
          icon: Icons.archive_rounded,
          color: Colors.grey,
          isDark: isDark,
        );
        final kpiGroups = _buildKpiItem(
          label: 'المجموعات المرتبطة',
          value: totalGroups.toString(),
          icon: Icons.groups_rounded,
          color: Colors.blue,
          isDark: isDark,
        );

        if (isWide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: kpiTotal),
                const SizedBox(width: 8),
                Expanded(child: kpiActive),
                const SizedBox(width: 8),
                Expanded(child: kpiArchived),
                const SizedBox(width: 8),
                Expanded(child: kpiGroups),
              ],
            ),
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: kpiTotal),
              const SizedBox(width: 6),
              Expanded(child: kpiActive),
              const SizedBox(width: 6),
              Expanded(child: kpiArchived),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 14, color: color),
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
        final isNarrow = constraints.maxWidth < 540;
        final searchField = TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'بحث باسم المادة، الكود، أو الوصف...',
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
          mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
          children: [
            _buildStatusFilterChip('all', 'الكل', isDark),
            const SizedBox(width: 4),
            _buildStatusFilterChip('active', 'النشطة', isDark),
            const SizedBox(width: 4),
            _buildStatusFilterChip('archived', 'المؤرشفة', isDark),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 10),
            filterChips,
          ],
        );
      },
    );
  }

  Widget _buildStatusFilterChip(String value, String label, bool isDark) {
    final isSelected = _selectedStatusFilter == value;
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
      selectedColor: AppColors.adminRole.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected
            ? AppColors.adminRole
            : (isDark ? Colors.white70 : Colors.black87),
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.adminRole
            : (isDark ? AppColors.darkBorder : Colors.black12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildSubjectCard(BuildContext context, SubjectEntity s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final isActive = s.status.toLowerCase() == 'active';
    final groupCount = _subjectGroupCounts[s.id] ?? 0;

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
          // Header: Icon + Name + Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.adminRole.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.adminRole,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: () => _copySubjectCode(context, s.code),
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.adminRole.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: AppColors.adminRole.withValues(alpha: 0.2),
                            width: 0.6,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.copy_rounded,
                              size: 10,
                              color: AppColors.adminRole,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'كود: ${s.code}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.adminRole,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isActive ? 'نشطة' : 'مؤرشفة',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Badges / Info Row: Groups count
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.2),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_rounded, size: 12, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      groupCount == 0 ? 'لا توجد مجموعات بعد' : '$groupCount مجموعة دراسية',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Description (if available)
          if (s.description != null && s.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              s.description!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: textSecondary,
                height: 1.25,
              ),
            ),
          ],

          const Divider(height: 10),

          // Action Toolbar Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: AppColors.adminRole.withValues(alpha: 0.3)),
                ),
                onPressed: () => _showEditSubjectDialog(s),
                icon: const Icon(Icons.edit_rounded, size: 13, color: AppColors.adminRole),
                label: const Text(
                  'تعديل',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.adminRole,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: isActive ? 'أرشفة المادة' : 'إلغاء الأرشفة والتنشيط',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      isActive ? Icons.archive_outlined : Icons.unarchive_outlined,
                      size: 17,
                      color: isActive ? Colors.amber.shade800 : Colors.green,
                    ),
                    onPressed: () => _toggleSubjectStatus(s),
                  ),
                  IconButton(
                    tooltip: 'حذف المادة',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 17,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _showDeleteSubjectDialog(s),
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
    final filtered = _subjects.where((s) {
      final q = _searchController.text.toLowerCase().trim();
      final matchesSearch = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.code.toLowerCase().contains(q) ||
          (s.description != null && s.description!.toLowerCase().contains(q));
      if (!matchesSearch) return false;
      if (_selectedStatusFilter == 'active') return s.status.toLowerCase() == 'active';
      if (_selectedStatusFilter == 'archived') return s.status.toLowerCase() == 'archived';
      return true;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = _subjects.length;
    final activeCount = _subjects.where((s) => s.status.toLowerCase() == 'active').length;
    final archivedCount = _subjects.where((s) => s.status.toLowerCase() == 'archived').length;
    int totalGroups = 0;
    for (final c in _subjectGroupCounts.values) {
      totalGroups += c;
    }

    return PortalPageShell(
      title: 'إدارة المواد والمناهج',
      subtitle: 'إضافة وتعديل المواد الدراسية، متابعة المجموعات المرتبطة، والأرشفة.',
      icon: Icons.book,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadSubjects,
        ),
        PortalAction(
          icon: Icons.add,
          label: 'إضافة مادة جديدة',
          onPressed: _showCreateSubjectDialog,
          primary: true,
        ),
      ],
      child: Column(
        children: [
          _buildKpiSection(isDark, totalCount, activeCount, archivedCount, totalGroups),
          const SizedBox(height: 12),
          _buildSearchAndFilterBar(isDark),
          const SizedBox(height: 12),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: filtered.isEmpty,
              emptyTitle: _searchController.text.isNotEmpty || _selectedStatusFilter != 'all'
                  ? 'لا توجد نتائج تطابق بحثك'
                  : 'لا توجد مواد دراسية مسجلة',
              emptySubtitle: _searchController.text.isNotEmpty || _selectedStatusFilter != 'all'
                  ? 'جرّب تعديل مصطلحات البحث أو تغيير فلتر الحالة.'
                  : 'قم بإضافة المادة الدراسية الأولى عبر زر (إضافة مادة جديدة) بالأعلى.',
              emptyIcon: Icons.menu_book_rounded,
              onRetry: _loadSubjects,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 850;
                  final isMedium = constraints.maxWidth > 580;

                  if (isWide) {
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: 185,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => _buildSubjectCard(context, filtered[i]),
                    );
                  }

                  if (isMedium) {
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: 185,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => _buildSubjectCard(context, filtered[i]),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _buildSubjectCard(context, filtered[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
