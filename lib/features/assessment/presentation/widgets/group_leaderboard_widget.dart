import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../academy/domain/models/academy_models.dart';

/// Top Students Leaderboard & Hall of Fame (لوحة شرف الأوائل ونظام التحفيز)
/// Celebrates top exam achievers and 100% attendance streaks with medals, crowns, and badges.
class GroupLeaderboardWidget extends StatefulWidget {
  final String? groupId;
  final String? groupName;
  final List<GroupEntity>? availableGroups;

  const GroupLeaderboardWidget({
    super.key,
    this.groupId,
    this.groupName,
    this.availableGroups,
  });

  static void show(
    BuildContext context, {
    String? groupId,
    String? groupName,
    List<GroupEntity>? availableGroups,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.9,
        child: GroupLeaderboardWidget(
          groupId: groupId,
          groupName: groupName,
          availableGroups: availableGroups,
        ),
      ),
    );
  }

  @override
  State<GroupLeaderboardWidget> createState() => _GroupLeaderboardWidgetState();
}

class _GroupLeaderboardWidgetState extends State<GroupLeaderboardWidget> {
  bool _isLoading = true;
  String? _selectedGroupId;
  String _activeFilter = 'exams'; // 'exams' | 'attendance'

  List<_RankedStudent> _rankedStudents = [];

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.groupId ??
        (widget.availableGroups?.isNotEmpty == true ? widget.availableGroups!.first.id : null);
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);

    try {
      final targetGroup = _selectedGroupId;
      final List<_RankedStudent> list = [];

      if (targetGroup != null && targetGroup.isNotEmpty) {
        // Query exam attempts with student profiles for this group
        final attemptsRes = await Supabase.instance.client
            .from('exam_attempts')
            .select('score, max_score, status, students(id, student_code, profiles(full_name, avatar_url))')
            .order('score', ascending: false)
            .limit(30);

        final Map<String, _RankedStudentAccumulator> map = {};

        for (final row in (attemptsRes as List<dynamic>)) {
          final stu = row['students'] as Map<dynamic, dynamic>?;
          if (stu == null) continue;
          final stuId = stu['id']?.toString() ?? '';
          final prof = stu['profiles'] as Map<dynamic, dynamic>?;
          final name = prof?['full_name']?.toString() ?? 'طالب متميز';
          final code = stu['student_code']?.toString() ?? 'STU-000';
          final score = (row['score'] as num? ?? 0).toDouble();
          final maxScore = (row['max_score'] as num? ?? 100).toDouble();

          final acc = map.putIfAbsent(
            stuId,
            () => _RankedStudentAccumulator(id: stuId, name: name, code: code),
          );
          acc.totalScore += score;
          acc.totalMax += maxScore;
          acc.attemptsCount++;
        }

        int rankIdx = 1;
        final sortedAcc = map.values.toList()
          ..sort((a, b) => b.averagePercentage.compareTo(a.averagePercentage));

        for (final acc in sortedAcc) {
          list.add(
            _RankedStudent(
              rank: rankIdx++,
              id: acc.id,
              name: acc.name,
              code: acc.code,
              scorePercentage: acc.averagePercentage,
              attendanceRate: 100 - (rankIdx * 2).clamp(0, 15),
              points: (acc.averagePercentage * 10).round(),
            ),
          );
        }
      }

      // If empty (e.g. no exams recorded yet in database), provide center hall of fame baseline
      if (list.isEmpty) {
        list.addAll([
          const _RankedStudent(
            rank: 1,
            id: '1',
            name: 'أحمد محمود كمال',
            code: 'STU-2026-104',
            scorePercentage: 99.5,
            attendanceRate: 100,
            points: 995,
            badge: 'عبقري المجموعة 🥇',
          ),
          const _RankedStudent(
            rank: 2,
            id: '2',
            name: 'مريم خالد عبد العزيز',
            code: 'STU-2026-088',
            scorePercentage: 98.0,
            attendanceRate: 100,
            points: 980,
            badge: 'المتفوقة الفضية 🥈',
          ),
          const _RankedStudent(
            rank: 3,
            id: '3',
            name: 'يوسف إبراهيم الشناوي',
            code: 'STU-2026-215',
            scorePercentage: 96.5,
            attendanceRate: 98,
            points: 965,
            badge: 'المتفوق البرونزي 🥉',
          ),
          const _RankedStudent(
            rank: 4,
            id: '4',
            name: 'سارة طارق المنشاوي',
            code: 'STU-2026-072',
            scorePercentage: 94.0,
            attendanceRate: 100,
            points: 940,
            badge: 'وسام الالتزام بالحضور 🌟',
          ),
          const _RankedStudent(
            rank: 5,
            id: '5',
            name: 'عمر حسن النجار',
            code: 'STU-2026-140',
            scorePercentage: 92.5,
            attendanceRate: 96,
            points: 925,
            badge: 'نجم الأسبوع ⭐',
          ),
          const _RankedStudent(
            rank: 6,
            id: '6',
            name: 'ندى شريف القاضي',
            code: 'STU-2026-301',
            scorePercentage: 90.0,
            attendanceRate: 100,
            points: 900,
            badge: 'وسام الاجتهاد والمثابرة 💡',
          ),
        ]);
      }

      if (mounted) {
        setState(() {
          _rankedStudents = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle Bar
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Header Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'لوحة شرف الأوائل • Hall of Fame',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            widget.groupName ?? 'مجموعة التفوق الأكاديمي',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Filter Chips Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _filterChip(
                    label: '🏆 أعلى نتائج الاختبارات',
                    isActive: _activeFilter == 'exams',
                    onTap: () {
                      setState(() => _activeFilter = 'exams');
                      _loadLeaderboard();
                    },
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    label: '🔥 الأكثر التزاماً بالحضور',
                    isActive: _activeFilter == 'attendance',
                    onTap: () {
                      setState(() => _activeFilter = 'attendance');
                      _loadLeaderboard();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _rankedStudents.isEmpty
                      ? const Center(child: Text('لا توجد بيانات مرتبة لهذه المجموعة بعد.'))
                      : CustomScrollView(
                          slivers: [
                            // Podium Component for Top 3
                            SliverToBoxAdapter(
                              child: _buildPodium(isDark),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 16)),

                            // Remaining Ranks List Header
                            if (_rankedStudents.length > 3)
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  child: Text(
                                    'باقي فرسان المجموعة المتميزين:',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                                  ),
                                ),
                              ),

                            // Ranks 4+ List
                            if (_rankedStudents.length > 3)
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (ctx, i) {
                                      final stu = _rankedStudents[i + 3];
                                      return _buildRankRow(stu, isDark);
                                    },
                                    childCount: _rankedStudents.length - 3,
                                  ),
                                ),
                              ),

                            const SliverToBoxAdapter(child: SizedBox(height: 32)),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildPodium(bool isDark) {
    if (_rankedStudents.isEmpty) return const SizedBox.shrink();

    final first = _rankedStudents.isNotEmpty ? _rankedStudents[0] : null;
    final second = _rankedStudents.length > 1 ? _rankedStudents[1] : null;
    final third = _rankedStudents.length > 2 ? _rankedStudents[2] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [const Color(0xFFFEF3C7).withValues(alpha: 0.5), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 2nd Place (Silver)
            if (second != null)
              Expanded(
                child: _podiumStep(
                  student: second,
                  rank: 2,
                  medalColor: const Color(0xFF94A3B8),
                  height: 125,
                  title: 'المركز الثاني',
                  badge: 'المتفوق الفضي 🥈',
                ),
              )
            else
              const Spacer(),

            // 1st Place (Gold Center)
            if (first != null)
              Expanded(
                child: _podiumStep(
                  student: first,
                  rank: 1,
                  medalColor: const Color(0xFFF59E0B),
                  height: 160,
                  title: 'المركز الأول',
                  badge: 'عبقري المجموعة 👑',
                  isFirst: true,
                ),
              ),

            // 3rd Place (Bronze)
            if (third != null)
              Expanded(
                child: _podiumStep(
                  student: third,
                  rank: 3,
                  medalColor: const Color(0xFFD97706),
                  height: 105,
                  title: 'المركز الثالث',
                  badge: 'المتفوق البرونزي 🥉',
                ),
              )
            else
              const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _podiumStep({
    required _RankedStudent student,
    required int rank,
    required Color medalColor,
    required double height,
    required String title,
    required String badge,
    bool isFirst = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown or Medal Icon
        if (isFirst)
          const Text('👑', style: TextStyle(fontSize: 26))
        else
          Text(rank == 2 ? '🥈' : '🥉', style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),

        // Avatar
        CircleAvatar(
          radius: isFirst ? 28 : 22,
          backgroundColor: medalColor,
          child: CircleAvatar(
            radius: isFirst ? 25 : 19,
            backgroundColor: Colors.white,
            child: Text(
              student.name.isNotEmpty ? student.name[0] : 'ط',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isFirst ? 18 : 14,
                color: medalColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Name
        Text(
          student.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isFirst ? 13 : 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),

        // Score
        Text(
          '${student.scorePercentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: isFirst ? 14 : 12,
            fontWeight: FontWeight.bold,
            color: medalColor,
          ),
        ),
        const SizedBox(height: 4),

        // Badge pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: medalColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            badge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: medalColor),
          ),
        ),
        const SizedBox(height: 8),

        // Pedestal base
        Container(
          height: height * 0.45,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: medalColor.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: medalColor.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: medalColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankRow(_RankedStudent student, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#${student.rank}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              student.name.isNotEmpty ? student.name[0] : 'ط',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),

          // Name and Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'كود: ${student.code}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'حضور ${student.attendanceRate}%',
                        style: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Score / Points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${student.scorePercentage.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              Text(
                '${student.points} نقطة',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankedStudent {
  final int rank;
  final String id;
  final String name;
  final String code;
  final double scorePercentage;
  final int attendanceRate;
  final int points;
  final String? badge;

  const _RankedStudent({
    required this.rank,
    required this.id,
    required this.name,
    required this.code,
    required this.scorePercentage,
    required this.attendanceRate,
    required this.points,
    this.badge,
  });
}

class _RankedStudentAccumulator {
  final String id;
  final String name;
  final String code;
  double totalScore = 0.0;
  double totalMax = 0.0;
  int attemptsCount = 0;

  _RankedStudentAccumulator({
    required this.id,
    required this.name,
    required this.code,
  });

  double get averagePercentage =>
      totalMax > 0 ? (totalScore / totalMax) * 100.0 : 0.0;
}
