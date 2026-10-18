import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/repositories/supabase_center_repository.dart';
import '../../domain/models/educational_center.dart';
import 'join_center_dialog.dart';

/// Top bar pill/widget that shows the current center and allows multi-center switching.
class CenterSwitcherWidget extends StatefulWidget {
  final VoidCallback? onCenterChanged;

  const CenterSwitcherWidget({super.key, this.onCenterChanged});

  @override
  State<CenterSwitcherWidget> createState() => _CenterSwitcherWidgetState();
}

class _CenterSwitcherWidgetState extends State<CenterSwitcherWidget> {
  late final SupabaseCenterRepository _centerRepo;
  List<UserCenterMembership> _centers = [];
  UserCenterMembership? _currentCenter;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _centerRepo = SupabaseCenterRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _loadUserCenters();
  }

  Future<void> _loadUserCenters() async {
    setState(() => _isLoading = true);
    try {
      final centers = await _centerRepo.fetchUserCenters();
      if (mounted) {
        setState(() {
          _centers = centers;
          UserCenterMembership? found;
          for (final c in centers) {
            if (c.isPrimary) {
              found = c;
              break;
            }
          }
          _currentCenter = found ?? (centers.isNotEmpty ? centers.first : _createPlaceholder());
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  UserCenterMembership _createPlaceholder() {
    return const UserCenterMembership(
      centerId: '',
      centerName: 'السنتر التعليمي',
      centerCode: '',
      role: 'student',
    );
  }

  void _showCenterPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'السناتر التابع لها حسابك',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'يمكنك التبديل بين السناتر لمتابعة حصصك ومجموعاتك بشكل منفصل تماماً.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ..._centers.map((center) {
                final isSelected = center.centerId == _currentCenter?.centerId;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: isSelected ? 2 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.2),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected ? AppColors.primary : Colors.grey.shade300,
                      child: Icon(
                        Icons.apartment_rounded,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                    title: Text(
                      center.centerName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      'الكود: ${center.centerCode} • الصفة: ${_translateRole(center.role)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (!isSelected) {
                        await _switchCenter(center);
                      }
                    },
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final joined = await JoinCenterDialog.show(context);
                    if (joined == true) {
                      await _loadUserCenters();
                      widget.onCenterChanged?.call();
                    }
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('الانضمام لسنتر آخر بكود السنتر'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _translateRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'إدارة السنتر';
      case 'teacher':
        return 'مدرس';
      case 'student':
        return 'طالب';
      case 'parent':
        return 'ولي أمر';
      case 'staff':
        return 'موظف / سكرتارية';
      default:
        return role;
    }
  }

  Future<void> _switchCenter(UserCenterMembership center) async {
    setState(() => _isLoading = true);
    try {
      await _centerRepo.switchActiveCenter(center.centerId);
      setState(() {
        _currentCenter = center;
        _isLoading = false;
      });

      // Reload global auth bootstrap
      try {
        if (mounted) {
          await context.read<AuthViewModel>().reloadBootstrap();
        }
      } catch (_) {}

      widget.onCenterChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم التبديل بنجاح إلى: ${center.centerName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التبديل: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_centers.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasMultiple = _centers.length > 1;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: InkWell(
        onTap: hasMultiple ? _showCenterPicker : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.apartment_rounded, size: 15, color: AppColors.primary),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  _currentCenter?.centerName ?? 'السنتر',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (hasMultiple) ...[
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
