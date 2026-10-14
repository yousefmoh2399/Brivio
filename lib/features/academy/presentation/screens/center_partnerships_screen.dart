import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../data/repositories/supabase_center_repository.dart';
import '../../domain/models/educational_center.dart';
import '../widgets/center_link_dialog.dart';

class CenterPartnershipsScreen extends StatefulWidget {
  const CenterPartnershipsScreen({super.key});

  @override
  State<CenterPartnershipsScreen> createState() =>
      _CenterPartnershipsScreenState();
}

class _CenterPartnershipsScreenState extends State<CenterPartnershipsScreen> {
  late final SupabaseCenterRepository _repo;
  bool _isLoading = true;
  String? _errorMessage;
  CenterStats? _stats;
  List<CenterPartnership> _partnerships = [];

  @override
  void initState() {
    super.initState();
    _repo = SupabaseCenterRepository(
      SupabaseClientWrapper(Supabase.instance.client),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final futures = await Future.wait([
        _repo.fetchCenterStats(),
        _repo.fetchPartnerships(),
      ]);

      if (mounted) {
        setState(() {
          _stats = futures[0] as CenterStats;
          _partnerships = futures[1] as List<CenterPartnership>;
          _isLoading = false;
        });
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

  Future<void> _handleRespond(String partnershipId, String action) async {
    try {
      await _repo.respondToPartnership(
        partnershipId: partnershipId,
        action: action,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'approved'
                  ? 'تم قبول الشراكة بنجاح!'
                  : action == 'rejected'
                      ? 'تم رفض طلب الشراكة.'
                      : 'تم إنهاء الشراكة.',
            ),
            backgroundColor: action == 'approved' ? Colors.green : Colors.grey.shade800,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ $label إلى الحافظة: $text'),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة السنتر والربط (الشراكات)'),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث البيانات',
              onPressed: _loadData,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final res = await CenterLinkDialog.show(context);
            if (res == true) {
              await _loadData();
            }
          },
          icon: const Icon(Icons.add_link_rounded),
          label: const Text('طلب ربط سنتر جديد'),
          backgroundColor: AppColors.primary,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadData,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      children: [
                        _buildCenterIdentityCard(),
                        const SizedBox(height: 16),
                        _buildStatsRow(),
                        const SizedBox(height: 24),
                        _buildIncomingRequestsSection(),
                        const SizedBox(height: 24),
                        _buildActivePartnershipsSection(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildCenterIdentityCard() {
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.centerName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'محافظة ${stats.governorate} • باقة التجربة المجانية',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'سنتر نشط',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'كود السنتر الفريد للربط ودخول الطلاب:',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stats.centerCode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                  icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
                  tooltip: 'نسخ الكود',
                  onPressed: () => _copyToClipboard(stats.centerCode, 'كود السنتر'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();

    return Row(
      children: [
        _buildMiniStatCard('الطلاب', stats.studentsCount.toString(), Icons.school_rounded),
        const SizedBox(width: 8),
        _buildMiniStatCard('المدرسين', stats.teachersCount.toString(), Icons.person_pin_rounded),
        const SizedBox(width: 8),
        _buildMiniStatCard('المجموعات', stats.groupsCount.toString(), Icons.groups_rounded),
        const SizedBox(width: 8),
        _buildMiniStatCard('الشراكات', stats.partnershipsCount.toString(), Icons.handshake_rounded),
      ],
    );
  }

  Widget _buildMiniStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingRequestsSection() {
    final pendingIncoming = _partnerships.where(
      (p) => p.isPending && !p.isRequester,
    ).toList();

    if (pendingIncoming.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              'طلبات الشراكة الواردة (${pendingIncoming.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...pendingIncoming.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          p.partnerCenterName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'طلب وارد',
                            style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'كود: ${p.partnerCenterCode} • المحافظة: ${p.partnerGovernorate ?? 'غير محدد'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (p.notes != null && p.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('رسالة السنتر: "${p.notes}"', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => _handleRespond(p.id, 'rejected'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('رفض'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _handleRespond(p.id, 'approved'),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('قبول الشراكة'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildActivePartnershipsSection() {
    final activeList = _partnerships.where((p) => p.isApproved).toList();
    final pendingOutgoing = _partnerships.where((p) => p.isPending && p.isRequester).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'السناتر الشريكة المرتبطة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${activeList.length} سنتر مرتبط',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'الربط بين السناتر يسمح للمدرسين بالتدريس في السنترين ومشاركة الجداول دون أي تسريب لبيانات الطلاب أو الحسابات المالية.',
          style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
        ),
        const SizedBox(height: 14),
        if (activeList.isEmpty && pendingOutgoing.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Center(
              child: Column(
                children: const [
                  Icon(Icons.link_off_rounded, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('لا توجد سناتر مرتبطة حالياً', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 4),
                  Text(
                    'اضغط على زر "طلب ربط سنتر جديد" بالأسفل لربط سنترك مع سنتر زميل عبر كوده.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ...pendingOutgoing.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.amber,
                  child: Icon(Icons.hourglass_top_rounded, color: Colors.white),
                ),
                title: Text(p.partnerCenterName),
                subtitle: Text('كود: ${p.partnerCenterCode} • بانتظار موافقة السنتر الشريك'),
                trailing: const Chip(
                  label: Text('قيد الانتظار', style: TextStyle(fontSize: 11)),
                  backgroundColor: Color(0xFFFFF3E0),
                ),
              ),
            )),
        ...activeList.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.handshake_rounded, color: AppColors.primary),
                ),
                title: Text(p.partnerCenterName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('كود: ${p.partnerCenterCode} • تم تفعيل مشاركة المدرسين'),
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.link_off_rounded, color: Colors.red),
                                title: const Text('إنهاء الشراكة', style: TextStyle(color: Colors.red)),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _handleRespond(p.id, 'terminated');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            )),
      ],
    );
  }
}
