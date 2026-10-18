import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/repositories/supabase_center_repository.dart';
import '../../domain/models/educational_center.dart';

/// Full screen for linking and joining an educational center by code.
/// Features an Executive AAA responsive design, real-time code verification,
/// clipboard integration, and an overview of currently linked centers.
class JoinCenterScreen extends StatefulWidget {
  final VoidCallback? onSuccess;
  final String role; // 'teacher', 'student', 'staff', 'admin'
  final SupabaseCenterRepository? repository;
  final List<UserCenterMembership>? initialMemberships;
  final Future<Map<String, dynamic>> Function(String code)? onJoinCode;

  const JoinCenterScreen({
    super.key,
    this.onSuccess,
    this.role = 'teacher',
    this.repository,
    this.initialMemberships,
    this.onJoinCode,
  });

  @override
  State<JoinCenterScreen> createState() => _JoinCenterScreenState();
}

class _JoinCenterScreenState extends State<JoinCenterScreen> {
  final TextEditingController _codeCtrl = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isLoadingMemberships = true;
  String? _errorMessage;
  String? _successMessage;
  List<UserCenterMembership> _memberships = [];

  bool get _isTeacher => widget.role == 'teacher';

  SupabaseCenterRepository get _repo =>
      widget.repository ??
      SupabaseCenterRepository(
        SupabaseClientWrapper(Supabase.instance.client),
      );

  @override
  void initState() {
    super.initState();
    if (widget.initialMemberships != null) {
      _memberships = List.from(widget.initialMemberships!);
      _isLoadingMemberships = false;
    } else {
      _loadMemberships();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMemberships() async {
    if (widget.initialMemberships != null) return;
    setState(() => _isLoadingMemberships = true);
    try {
      final list = await _repo.fetchUserCenters();
      if (mounted) {
        setState(() {
          _memberships = list;
          _isLoadingMemberships = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMemberships = false);
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    HapticFeedback.selectionClick();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      final clean = data.text!.trim().toUpperCase();
      setState(() {
        _codeCtrl.text = clean;
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleJoin() async {
    HapticFeedback.lightImpact();
    final code = _codeCtrl.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال كود السنتر المعتمد');
      return;
    }

    // Check if already linked
    final alreadyLinked = _memberships.any(
      (m) => m.centerCode.toUpperCase() == code,
    );
    if (alreadyLinked) {
      setState(() => _errorMessage = 'حسابك مرتبط بالفعل بهذا السنتر التعليمي');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final Map<String, dynamic> res;
      if (widget.onJoinCode != null) {
        res = await widget.onJoinCode!(code);
      } else {
        res = await _repo.joinCenterByCode(code);
      }

      final centerName = res['center_name']?.toString() ?? 'السنتر التعليمي';

      // Reload auth bootstrap if available in context
      try {
        if (mounted) {
          await context.read<AuthViewModel>().reloadBootstrap();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage = 'تم الانضمام والربط بنجاح مع سنتر "$centerName" 🏫✨';
          // Optimistically add to memberships if not present
          if (!_memberships.any((m) => m.centerCode.toUpperCase() == code)) {
            _memberships.insert(
              0,
              UserCenterMembership(
                centerId: res['center_id']?.toString() ?? 'new-center',
                centerName: centerName,
                centerCode: code,
                role: widget.role,
                isPrimary: _memberships.isEmpty,
              ),
            );
          }
          _codeCtrl.clear();
        });

        widget.onSuccess?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم ربط السنتر بنجاح: $centerName 🎉'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ $label بنجاح 📋'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent =
        _isTeacher ? AppColors.teacherRole : AppColors.primary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          elevation: 0,
          backgroundColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: primaryAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.add_business_rounded,
                  color: primaryAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _isTeacher
                      ? 'ربط واعتماد سنتر جديد'
                      : 'الانضمام إلى سنتر تعليمي',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث بيانات السناتر',
              onPressed: _loadMemberships,
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isDesktop = screenWidth >= 950;
            final isTablet = screenWidth >= 580 && screenWidth < 950;
            final horizontalPadding = screenWidth < 380 ? 12.0 : 16.0;

            if (isDesktop) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildExecutiveHeroBanner(primaryAccent, isDark, screenWidth),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column: Code Input & Guide
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _buildCodeInputCard(primaryAccent, isDark, screenWidth),
                                  const SizedBox(height: 18),
                                  _buildQuickGuideCard(primaryAccent, isDark),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Right Column: Linked Centers & FAQ
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  _buildLinkedCentersSection(primaryAccent, isDark, 1),
                                  const SizedBox(height: 18),
                                  _buildHelpFooter(primaryAccent, isDark),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Mobile and Tablet Single Column
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Hero Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      14,
                      horizontalPadding,
                      12,
                    ),
                    child: _buildExecutiveHeroBanner(primaryAccent, isDark, screenWidth),
                  ),
                ),

                // Center Code Input Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      16,
                    ),
                    child: _buildCodeInputCard(primaryAccent, isDark, screenWidth),
                  ),
                ),

                // Current Linked Centers Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      16,
                    ),
                    child: _buildLinkedCentersSection(
                      primaryAccent,
                      isDark,
                      isTablet ? 2 : 1,
                    ),
                  ),
                ),

                // How it Works Guide
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      16,
                    ),
                    child: _buildQuickGuideCard(primaryAccent, isDark),
                  ),
                ),

                // Help and FAQ
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      36,
                    ),
                    child: _buildHelpFooter(primaryAccent, isDark),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildExecutiveHeroBanner(
    Color primaryAccent,
    bool isDark,
    double screenWidth,
  ) {
    final isSmall = screenWidth < 460;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  primaryAccent.withValues(alpha: 0.28),
                  AppColors.darkSurface,
                ]
              : [
                  primaryAccent.withValues(alpha: 0.12),
                  Colors.white,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryAccent.withValues(alpha: isDark ? 0.35 : 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryAccent.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isSmall ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Wrap with Role Badge & Security Tag
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryAccent.withValues(alpha: isDark ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isTeacher
                          ? Icons.verified_user_rounded
                          : Icons.school_rounded,
                      size: 13,
                      color: primaryAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isTeacher ? 'اعتماد المعلم المعتمد' : 'انضمام طالب',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: primaryAccent,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 12,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ربط سحابي مشفر 🔒',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Title & Description
          Text(
            _isTeacher
                ? 'ربط واعتماد سنتر تعليمي جديد 🏫'
                : 'الانضمام إلى سنترك التعليمي 🎓',
            style: TextStyle(
              fontSize: isSmall ? 17 : 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isTeacher
                ? 'أدخل كود السنتر المعتمد لربط جدولك ومجموعاتك، واستلام كشوف الحضور والغياب، ومزامنة بيانات الطلاب تلقائياً.'
                : 'أدخل كود السنتر المقدم لك من إدارة السنتر للوصول إلى حصصك، كشوف الغياب، وجداولك الدراسية.',
            style: TextStyle(
              fontSize: isSmall ? 12 : 13,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              height: 1.45,
            ),
          ),

          const SizedBox(height: 14),

          // Benefit Chips Wrap
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildBenefitChip(
                icon: Icons.sync_rounded,
                text: 'مزامنة تلقائية للمجموعات',
                color: primaryAccent,
                isDark: isDark,
                maxWidth: (screenWidth - 60).clamp(160.0, 500.0),
              ),
              _buildBenefitChip(
                icon: Icons.schedule_rounded,
                text: 'منع تعارض الحصص',
                color: const Color(0xFF0D9488),
                isDark: isDark,
                maxWidth: (screenWidth - 60).clamp(160.0, 500.0),
              ),
              _buildBenefitChip(
                icon: Icons.assignment_turned_in_rounded,
                text: 'كشوف الحضور والغياب',
                color: const Color(0xFF2563EB),
                isDark: isDark,
                maxWidth: (screenWidth - 60).clamp(160.0, 500.0),
              ),
              _buildBenefitChip(
                icon: Icons.account_balance_wallet_rounded,
                text: 'تقارير مالية مستقلة',
                color: const Color(0xFFD97706),
                isDark: isDark,
                maxWidth: (screenWidth - 60).clamp(160.0, 500.0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitChip({
    required IconData icon,
    required String text,
    required Color color,
    required bool isDark,
    double maxWidth = 240,
  }) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeInputCard(
    Color primaryAccent,
    bool isDark,
    double screenWidth,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.vpn_key_rounded,
                  color: primaryAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'كود ربط السنتر (Center Code)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'أدخل الكود المعطى لك من إدارة السنتر لتوثيق الربط',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Code Input Field
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _errorMessage != null
                    ? Colors.red
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: _errorMessage != null ? 1.5 : 1.0,
              ),
            ),
            child: TextField(
              controller: _codeCtrl,
              focusNode: _codeFocusNode,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: 'مثال: CTR-A8F290',
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
                prefixIcon: Icon(
                  Icons.qr_code_rounded,
                  color: primaryAccent,
                  size: 22,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_codeCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        tooltip: 'مسح',
                        onPressed: () {
                          _codeCtrl.clear();
                          setState(() => _errorMessage = null);
                        },
                      ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: primaryAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.paste_rounded, size: 16),
                      label: const Text('لصق', style: TextStyle(fontSize: 12)),
                      onPressed: _pasteFromClipboard,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
              onSubmitted: (_) => _handleJoin(),
            ),
          ),

          // Error Message Banner
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Success Message Banner
          if (_successMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: primaryAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: _isLoading ? null : _handleJoin,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link_rounded, size: 20),
              label: Text(
                _isLoading ? 'جارِ التحقق والربط...' : 'ربط وتفعيل السنتر الآن 🚀',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedCentersSection(
    Color primaryAccent,
    bool isDark,
    int crossAxisCount,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: Colors.teal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'السناتر التعليمية المرتبطة بحسابك',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_memberships.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryAccent,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Content State
          if (_isLoadingMemberships)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_memberships.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.domain_disabled_rounded,
                      size: 44,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'لا توجد سناتر مرتبطة بعد',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'استخدم كود السنتر بالأعلى لربط أول سنتر تعليمي معتمد.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else if (crossAxisCount == 1)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _memberships.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) =>
                  _buildCenterCard(_memberships[i], primaryAccent, isDark),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 125,
              ),
              itemCount: _memberships.length,
              itemBuilder: (ctx, i) =>
                  _buildCenterCard(_memberships[i], primaryAccent, isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildCenterCard(
    UserCenterMembership center,
    Color primaryAccent,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.25)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: center.isPrimary
              ? primaryAccent.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: center.isPrimary ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: primaryAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.apartment_rounded,
                  size: 18,
                  color: primaryAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      center.centerName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (center.governorate != null &&
                        center.governorate!.isNotEmpty)
                      Text(
                        '📍 ${center.governorate}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (center.isPrimary)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.shade700.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded,
                          size: 11, color: Colors.amber.shade700),
                      const SizedBox(width: 2),
                      Text(
                        'الأساسي',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Footer with Code and Role Badges (Responsive Wrap)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'الكود: ',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Flexible(
                      child: Text(
                        center.centerCode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () =>
                          _copyToClipboard(center.centerCode, 'كود السنتر'),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  center.role == 'student' ? 'طالب 🎓' : 'معلم معتمد 👨‍🏫',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickGuideCard(Color primaryAccent, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.help_center_rounded, color: Colors.indigo, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'كيف يعمل نظام ربط السناتر؟ (3 خطوات)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGuideStep(
            step: '1',
            title: 'طلب الكود من إدارة السنتر',
            desc: 'تواصل مع سكرتارية أو إدارة السنتر التعليمي للحصول على كود الانضمام المعتمد الخاص بهم.',
            color: Colors.blue,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildGuideStep(
            step: '2',
            title: 'إدخال الكود والضغط على ربط',
            desc: 'اكتب الكود في خانة الربط بالأعلى واضغط "ربط وتفعيل السنتر الآن".',
            color: Colors.amber.shade700,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildGuideStep(
            step: '3',
            title: 'مزامنة فورية للجدول والمجموعات',
            desc: 'ستظهر مجموعات وفصول السنتر في جدولك فوراً ويمكنك رصد الحضور وطباعة الباركود والبدء مباشرة.',
            color: Colors.green,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep({
    required String step,
    required String title,
    required String desc,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpFooter(Color primaryAccent, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primaryAccent.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryAccent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.support_agent_rounded, color: primaryAccent, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'هل تواجه صعوبة في الربط؟',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'تواصل مع الدعم الفني للمنصة لمساعدتك في الحصول على كود السنتر أو حل مشاكل الربط فوراً.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
