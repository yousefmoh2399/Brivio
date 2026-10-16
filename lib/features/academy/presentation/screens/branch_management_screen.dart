import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  late final SupabaseBranchRepository _branchRepo;
  List<Branch> _branches = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _branchRepo = SupabaseBranchRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _loadBranches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
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

      List<Branch> res = [];
      if (centerId != null) {
        try {
          final bRes = await Supabase.instance.client
              .from('branches')
              .select()
              .eq('center_id', centerId)
              .order('name');
          res = (bRes as List)
              .map((j) => Branch.fromJson(Map<String, dynamic>.from(j as Map)))
              .toList();
        } catch (_) {}
      }
      if (res.isEmpty) {
        res = await _branchRepo.fetchBranches();
      }

      if (mounted) {
        setState(() {
          _branches = res;
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

  void _showCreateBranchDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
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
                child: const Icon(Icons.domain, color: AppColors.adminRole),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'إضافة مقر / فرع جديد',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width.clamp(280.0, 480.0),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم الفرع *',
                        hintText: 'مثال: فرع مدينة نصر',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال اسم الفرع' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'كود الفرع *',
                        hintText: 'مثال: NASR-01',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال كود الفرع' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addrCtrl,
                      decoration: const InputDecoration(
                        labelText: 'العنوان بالتفصيل',
                        hintText: 'الشارع، الحي، أقرب علامة مميزة...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رقم هاتف الفرع للتواصل',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
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

                        final branchPayload = <String, dynamic>{
                          'code': codeCtrl.text.trim(),
                          'name': nameCtrl.text.trim(),
                          'address': addrCtrl.text.trim().isEmpty
                              ? null
                              : addrCtrl.text.trim(),
                          'phone_number': phoneCtrl.text.trim().isEmpty
                              ? null
                              : phoneCtrl.text.trim(),
                          'status': 'active',
                          if (centerId != null) 'center_id': centerId,
                        };

                        await Supabase.instance.client
                            .from('branches')
                            .insert(branchPayload);

                        nav.pop();
                        _loadBranches();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إنشاء الفرع وربطه بالسنتر بنجاح!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل إنشاء الفرع: $e'),
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
              label: Text(isSubmitting ? 'جاري الحفظ...' : 'حفظ الفرع'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBranchDialog(Branch branch) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: branch.name);
    final codeCtrl = TextEditingController(text: branch.code);
    final addrCtrl = TextEditingController(text: branch.address ?? '');
    final phoneCtrl = TextEditingController(text: branch.phoneNumber ?? '');
    String status = branch.status;
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
                child: const Icon(Icons.edit, color: AppColors.adminRole),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تعديل بيانات الفرع',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width.clamp(280.0, 480.0),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم الفرع *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال اسم الفرع' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'كود الفرع *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'يرجى إدخال كود الفرع' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addrCtrl,
                      decoration: const InputDecoration(
                        labelText: 'العنوان بالتفصيل',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف للتواصل',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'الحالة التشغيلية',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('نشط (Active)')),
                        DropdownMenuItem(value: 'archived', child: Text('مؤرشف (Archived)')),
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
                        final updated = Branch(
                          id: branch.id,
                          code: codeCtrl.text.trim(),
                          name: nameCtrl.text.trim(),
                          address: addrCtrl.text.trim().isEmpty
                              ? null
                              : addrCtrl.text.trim(),
                          phoneNumber: phoneCtrl.text.trim().isEmpty
                              ? null
                              : phoneCtrl.text.trim(),
                          status: status,
                        );

                        await _branchRepo.updateBranch(updated);
                        nav.pop();
                        _loadBranches();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم حفظ تعديلات بيانات الفرع بنجاح!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isSubmitting = false);
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

  Widget _buildBranchCard(BuildContext context, Branch b) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.adminRole.withValues(alpha: 0.12),
            child: const Icon(Icons.domain, color: AppColors.adminRole, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.name,
                  style: AppTypography.titleMedium(textPrimary).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (b.address != null && b.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          b.address!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(textSecondary),
                        ),
                      ),
                    ],
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
                        color: AppColors.adminRole.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'كود: ${b.code}',
                        style: const TextStyle(fontSize: 12, color: AppColors.adminRole, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (b.phoneNumber != null && b.phoneNumber!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'هاتف: ${b.phoneNumber}',
                          style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600),
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
              PortalStatusChip(status: b.status),
              const SizedBox(height: 4),
              IconButton(
                tooltip: 'تعديل بيانات الفرع',
                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                onPressed: () => _showEditBranchDialog(b),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _branches.where((b) {
      final q = _searchController.text.toLowerCase();
      return b.name.toLowerCase().contains(q) ||
          b.code.toLowerCase().contains(q);
    }).toList();

    return PortalPageShell(
      title: 'إدارة الفروع والمقرات',
      subtitle: 'إنشاء وتعديل فروع السنتر، وإدارة العناوين وأرقام التواصل.',
      icon: Icons.domain,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.refresh,
          label: 'تحديث',
          onPressed: _loadBranches,
        ),
        PortalAction(
          icon: Icons.add,
          label: 'إضافة فرع جديد',
          onPressed: _showCreateBranchDialog,
          primary: true,
        ),
      ],
      child: Column(
        children: [
          PortalSearchField(
            controller: _searchController,
            label: 'بحث باسم الفرع أو الكود...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PortalStateView(
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEmpty: filtered.isEmpty,
              emptyTitle: 'لا توجد فروع مسجلة',
              emptySubtitle: 'قم بإضافة المقر أو الفرع الأول للسنتر عبر زر (إضافة فرع جديد) بالأعلى.',
              emptyIcon: Icons.domain,
              onRetry: _loadBranches,
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _buildBranchCard(context, filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
