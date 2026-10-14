import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'child_details_screen.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';

class ParentDashboardScreen extends StatefulWidget {
  final String parentId;

  const ParentDashboardScreen({super.key, this.parentId = 'p1'});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  List<Map<String, dynamic>> _children = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchChildren();
  }

  Future<void> _fetchChildren() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final currentUserId = client.auth.currentUser?.id;

      if (currentUserId != null) {
        final parentRes = await client
            .from('parents')
            .select('id')
            .eq('user_id', currentUserId)
            .maybeSingle();
        final pId = parentRes?['id'] as String?;

        if (pId != null) {
          final res = await client
              .from('parent_students')
              .select('students(id, student_code, profiles(full_name, avatar_url))')
              .eq('parent_id', pId);

          final List<Map<String, dynamic>> list = [];
          for (final item in (res as List)) {
            final stu = item['students'] as Map<String, dynamic>?;
            final prof = stu?['profiles'] as Map<String, dynamic>?;
            if (stu != null) {
              final name = prof?['full_name'] as String? ?? 'طالب';
              list.add({
                'id': stu['id'] as String,
                'name': name,
                'grade': 'المرحلة الدراسية',
                'avatar': name.isNotEmpty ? name[0] : 'ط',
                'gpa': 'متميز',
                'attendance': '100%',
              });
            }
          }
          if (mounted) setState(() => _children = list);
        } else {
          if (mounted) setState(() => _children = []);
        }
      } else {
        if (mounted) setState(() => _children = []);
      }
    } catch (_) {
      if (mounted) setState(() => _children = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.purple.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.2),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const FadeInSlide(
                        delay: Duration(milliseconds: 100),
                        child: SectionHeader(
                          title: 'الأبناء المسجلون',
                          actionLabel: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (_children.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.family_restroom_outlined, size: 48, color: AppColors.darkTextSecondary),
                              SizedBox(height: 12),
                              Text(
                                'لا يوجد أبناء مرتبطون بهذا الحساب حالياً',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkTextPrimary,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'يمكنك ربط حسابك بكود الطالب من خلال إدارة السنتر لمتابعة الحضور والدرجات.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.darkTextSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._children.asMap().entries.map((entry) {
                          int index = entry.key;
                          var child = entry.value;
                          return FadeInSlide(
                            delay: Duration(milliseconds: 150 + (index * 100)),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: GlassCard(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ChildDetailsScreen(childData: child),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: AppColors.primarySubtle,
                                      child: Text(
                                        child['avatar'],
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            child['name'],
                                            style: const TextStyle(
                                              color: AppColors.darkTextPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            child['grade'],
                                            style: const TextStyle(
                                              color: AppColors.darkTextSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        StatusChip(
                                          label: '${child['gpa']}',
                                          status: ChipStatus.success,
                                          small: true,
                                        ),
                                        const SizedBox(height: 4),
                                        StatusChip(
                                          label: '${child['attendance']}',
                                          status: ChipStatus.info,
                                          small: true,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 24),
                      const FadeInSlide(
                        delay: Duration(milliseconds: 300),
                        child: SectionHeader(title: 'إجراءات سريعة'),
                      ),
                      const SizedBox(height: 12),
                      FadeInSlide(
                        delay: const Duration(milliseconds: 400),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildQuickAction(
                              Icons.grade_outlined,
                              'الدرجات',
                              AppColors.purple,
                            ),
                            _buildQuickAction(
                              Icons.calendar_month_outlined,
                              'الحضور',
                              AppColors.primary,
                            ),
                            _buildQuickAction(
                              Icons.account_balance_wallet_outlined,
                              'المصروفات',
                              AppColors.success,
                            ),
                            _buildQuickAction(
                              Icons.event_outlined,
                              'الأنشطة',
                              AppColors.warning,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      const FadeInSlide(
                        delay: Duration(milliseconds: 500),
                        child: SectionHeader(title: 'أحدث التنبيهات والفعاليات'),
                      ),
                      const SizedBox(height: 12),
                      FadeInSlide(
                        delay: const Duration(milliseconds: 600),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildEventItem(
                                'اللقاء الدوري لأولياء الأمور والمعلمين',
                                'الأسبوع القادم، 04:00 م',
                                AppColors.primary,
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(
                                  color: AppColors.glassBorder,
                                  height: 1,
                                ),
                              ),
                              _buildEventItem(
                                'إعلان نتائج وتقييمات الشهر الأكاديمي',
                                'يوم الجمعة، 09:00 ص',
                                AppColors.purple,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      expandedHeight: 80,
      pinned: true,
      flexibleSpace: const FlexibleSpaceBar(
        titlePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: FadeInSlide(
          delay: Duration(milliseconds: 0),
          child: Text(
            'بوابة أولياء الأمور 👨‍👧‍👦',
            style: TextStyle(
              color: AppColors.darkTextPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
      actions: [
        FadeInSlide(
          delay: const Duration(milliseconds: 50),
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: AppColors.glassMedium,
              child: const Icon(
                Icons.notifications_outlined,
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color) {
    return Column(
      children: [
        GlowContainer(
          glowColor: color,
          glowOpacity: 0.2,
          padding: const EdgeInsets.all(16),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.darkTextSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEventItem(String title, String time, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.darkTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: const TextStyle(
                  color: AppColors.darkTextSecondary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
