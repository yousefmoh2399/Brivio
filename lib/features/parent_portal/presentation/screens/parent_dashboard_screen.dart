import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import 'child_assignments_screen.dart';
import 'child_details_screen.dart';
import 'child_schedule_screen.dart';
import 'link_child_screen.dart';
import 'parent_comms_screen.dart';
import 'parent_finance_screen.dart';

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
        var parentRes = await client
            .from('parents')
            .select('id')
            .eq('profile_id', currentUserId)
            .maybeSingle();

        String? pId = parentRes?['id'] as String?;
        if (pId == null) {
          final created = await client
              .from('parents')
              .insert({'profile_id': currentUserId})
              .select('id')
              .maybeSingle();
          pId = created?['id'] as String?;
        }

        if (pId != null) {
          final res = await client
              .from('parent_students')
              .select(
                'students(id, student_code, grade_level, profiles(full_name, avatar_url))',
              )
              .eq('parent_id', pId);

          final List<Map<String, dynamic>> list = [];
          for (final item in (res as List)) {
            final stu = item['students'] as Map<String, dynamic>?;
            final prof = stu?['profiles'] as Map<String, dynamic>?;
            if (stu != null) {
              final name = prof?['full_name'] as String? ?? 'طالب';
              final grade =
                  stu['grade_level'] as String? ?? 'المرحلة الدراسية';
              final studentCode =
                  stu['student_code'] as String? ?? 'STU-BRIVIO';
              list.add({
                'id': stu['id'] as String,
                'student_code': studentCode,
                'name': name,
                'grade': grade,
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

  Future<void> _navigateToLinkChild() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LinkChildScreen()),
    );
    if (result == true) {
      _fetchChildren();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Background Glows in dark mode
          if (isDark) ...[
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
          ],

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(textPrimary),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      FadeInSlide(
                        delay: const Duration(milliseconds: 100),
                        child: SectionHeader(
                          title: 'الأبناء المسجلون',
                          actionLabel: _children.isNotEmpty ? '+ ربط طالب' : '',
                          onAction: _children.isNotEmpty
                              ? _navigateToLinkChild
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_children.isEmpty)
                        FadeInSlide(
                          delay: const Duration(milliseconds: 150),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.family_restroom_rounded,
                                  size: 48,
                                  color: AppColors.parentRole,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'لا يوجد أبناء مرتبطون بهذا الحساب حالياً',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'قم بربط حسابك بكود الطالب المعتمد من السنتر لمتابعة الدرجات والواجبات والحضور لحظة بلحظة.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.parentRole,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                  onPressed: _navigateToLinkChild,
                                  icon: const Icon(Icons.add_link_rounded),
                                  label: const Text(
                                    'ربط طالب جديد بكود السنتر',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
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
                                      backgroundColor: AppColors.parentRole.withValues(alpha: 0.15),
                                      child: Text(
                                        child['avatar'],
                                        style: const TextStyle(
                                          color: AppColors.parentRole,
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
                                            style: TextStyle(
                                              color: textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${child['grade']} • كود: ${child['student_code']}',
                                            style: TextStyle(
                                              color: textSecondary,
                                              fontSize: 12,
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
                        child: SectionHeader(title: 'إجراءات سريعة ومتابعة'),
                      ),
                      const SizedBox(height: 12),
                      FadeInSlide(
                        delay: const Duration(milliseconds: 400),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildQuickAction(
                              icon: Icons.assignment_outlined,
                              label: 'الواجبات',
                              color: AppColors.purple,
                              textSecondary: textSecondary,
                              onTap: () {
                                if (_children.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChildAssignmentsScreen(
                                        studentId: _children.first['id'] as String,
                                      ),
                                    ),
                                  );
                                } else {
                                  _navigateToLinkChild();
                                }
                              },
                            ),
                            _buildQuickAction(
                              icon: Icons.calendar_month_outlined,
                              label: 'الجدول',
                              color: AppColors.primary,
                              textSecondary: textSecondary,
                              onTap: () {
                                if (_children.isNotEmpty) {
                                  final firstChild = _children.first;
                                  final childId = firstChild['id']?.toString() ?? '';
                                  final childName = firstChild['full_name']?.toString() ?? firstChild['name']?.toString();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChildScheduleScreen(
                                        studentId: childId,
                                        studentName: childName,
                                      ),
                                    ),
                                  );
                                } else {
                                  _navigateToLinkChild();
                                }
                              },
                            ),
                            _buildQuickAction(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'المصروفات',
                              color: AppColors.success,
                              textSecondary: textSecondary,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ParentFinanceScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildQuickAction(
                              icon: Icons.campaign_outlined,
                              label: 'الإعلانات',
                              color: AppColors.warning,
                              textSecondary: textSecondary,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ParentCommsScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      const FadeInSlide(
                        delay: Duration(milliseconds: 500),
                        child: SectionHeader(title: 'أحدث التنبيهات والفعاليات 📢'),
                      ),
                      const SizedBox(height: 12),
                      FadeInSlide(
                        delay: const Duration(milliseconds: 600),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildEventItem(
                                title: 'اللقاء الدوري لأولياء الأمور والمعلمين',
                                time: 'الأسبوع القادم، 04:00 م',
                                color: AppColors.primary,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Divider(
                                  color: isDark ? AppColors.glassBorder : Colors.black12,
                                  height: 1,
                                ),
                              ),
                              _buildEventItem(
                                title: 'إعلان نتائج وتقييمات الشهر الأكاديمي',
                                time: 'يوم الجمعة، 09:00 ص',
                                color: AppColors.purple,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
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

  SliverAppBar _buildAppBar(Color textPrimary) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      expandedHeight: 80,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: FadeInSlide(
          delay: const Duration(milliseconds: 0),
          child: Text(
            'بوابة أولياء الأمور 👨‍👧‍👦',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'ربط طالب جديد',
          icon: const Icon(Icons.person_add_alt_1_rounded),
          onPressed: _navigateToLinkChild,
        ),
        IconButton(
          tooltip: 'مركز الإعلانات والرسائل',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ParentCommsScreen()),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
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
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventItem({
    required String title,
    required String time,
    required Color color,
    required Color textPrimary,
    required Color textSecondary,
  }) {
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
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: TextStyle(
                  color: textSecondary,
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
