import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../design_system/tokens/colors.dart';
import '../../data/services/personal_whiteboards_storage.dart';
import '../../domain/models/personal_whiteboard_item.dart';
import 'student_personal_board_screen.dart';

/// Screen listing all personal whiteboards for a student or teacher.
/// Allows creating, opening, renaming, duplicating, and deleting personal study boards.
/// Redesigned with an Executive AAA responsive UI supporting mobile (320px+), tablet, and desktop.
class PersonalWhiteboardsHubScreen extends StatefulWidget {
  final String? userId;
  final String role; // 'student' or 'teacher'
  final List<PersonalWhiteboardItem>? initialBoards;

  const PersonalWhiteboardsHubScreen({
    super.key,
    this.userId,
    this.role = 'teacher',
    this.initialBoards,
  });

  @override
  State<PersonalWhiteboardsHubScreen> createState() =>
      _PersonalWhiteboardsHubScreenState();
}

class _PersonalWhiteboardsHubScreenState
    extends State<PersonalWhiteboardsHubScreen> {
  List<PersonalWhiteboardItem> _boards = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedThemeFilter = 'all';

  String get _effectiveUserId => widget.userId ?? 'guest';
  bool get _isTeacher => widget.role == 'teacher';

  @override
  void initState() {
    super.initState();
    if (widget.initialBoards != null) {
      _boards = List.from(widget.initialBoards!);
      _isLoading = false;
    } else {
      _loadBoards();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBoards() async {
    if (widget.initialBoards != null) return;
    setState(() => _isLoading = true);
    try {
      final list = await PersonalWhiteboardsStorage.getBoards(_effectiveUserId);
      if (mounted) {
        setState(() {
          _boards = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewBoard() async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final defaultTitle = _isTeacher
        ? 'تحضير درس - ${DateFormat('d MMMM', 'ar').format(now)}'
        : 'سبورة مذاكرة - ${DateFormat('d MMMM', 'ar').format(now)}';

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentPersonalBoardScreen(
          studentId: _effectiveUserId,
          title: defaultTitle,
          isTeacher: _isTeacher,
        ),
      ),
    );

    if (mounted) _loadBoards();
  }

  Future<void> _openBoard(PersonalWhiteboardItem item) async {
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentPersonalBoardScreen(
          studentId: _effectiveUserId,
          boardId: item.id,
          title: item.title,
          isTeacher: _isTeacher,
        ),
      ),
    );

    if (mounted) _loadBoards();
  }

  Future<void> _renameBoard(PersonalWhiteboardItem item) async {
    final ctrl = TextEditingController(text: item.title);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('تعديل اسم السبورة'),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            labelText: 'اسم السبورة الجديد',
            hintText: 'مثال: مراجعة الفيزياء، حل تمارين...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('حفظ التعديل'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != item.title) {
      if (widget.initialBoards != null) {
        setState(() {
          final idx = _boards.indexWhere((b) => b.id == item.id);
          if (idx >= 0) {
            _boards[idx] = _boards[idx].copyWith(
              title: newTitle,
              updatedAt: DateTime.now(),
            );
          }
        });
      } else {
        await PersonalWhiteboardsStorage.renameBoard(
          userId: _effectiveUserId,
          boardId: item.id,
          newTitle: newTitle,
        );
        if (mounted) _loadBoards();
      }
    }
  }

  Future<void> _duplicateBoard(PersonalWhiteboardItem item) async {
    if (widget.initialBoards != null) {
      final copyItem = PersonalWhiteboardItem(
        id: 'board_${DateTime.now().millisecondsSinceEpoch}',
        userId: item.userId,
        title: '${item.title} (نسخة)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        bgTheme: item.bgTheme,
        strokeCount: item.strokeCount,
      );
      setState(() {
        _boards.insert(0, copyItem);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نسخ السبورة بنجاح 📋'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final res = await PersonalWhiteboardsStorage.duplicateBoard(
      userId: _effectiveUserId,
      boardId: item.id,
    );
    if (res != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ السبورة بنجاح 📋'),
          duration: Duration(seconds: 2),
        ),
      );
      _loadBoards();
    }
  }

  Future<void> _deleteBoard(PersonalWhiteboardItem item) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف السبورة؟ 🗑️'),
        content: Text('هل أنت متأكد من حذف "${item.title}" نهائياً من دفترك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (widget.initialBoards != null) {
        setState(() {
          _boards.removeWhere((b) => b.id == item.id);
        });
      } else {
        await PersonalWhiteboardsStorage.deleteBoard(
          userId: _effectiveUserId,
          boardId: item.id,
        );
        if (mounted) _loadBoards();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف السبورة'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  List<PersonalWhiteboardItem> get _filteredBoards {
    var list = _boards;
    if (_selectedThemeFilter != 'all') {
      list = list.where((b) => b.bgTheme == _selectedThemeFilter).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((b) => b.title.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  int _countByTheme(String themeKey) {
    if (themeKey == 'all') return _boards.length;
    return _boards.where((b) => b.bgTheme == themeKey).length;
  }

  int get _totalStrokes =>
      _boards.fold<int>(0, (sum, b) => sum + b.strokeCount);

  String _formatFriendlyDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 2) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24 && dt.day == now.day) {
      return 'اليوم ${DateFormat('hh:mm a', 'ar').format(dt)}';
    }
    if (diff.inDays < 2) {
      return 'أمس ${DateFormat('hh:mm a', 'ar').format(dt)}';
    }
    return DateFormat('d MMMM yyyy', 'ar').format(dt);
  }

  String _themeLabel(String themeName) {
    return switch (themeName) {
      'gridMath' => 'شبكة مربعات هندسية',
      'linedNotebook' => 'كشكول مسطر',
      'darkSlate' => 'سبورة سوداء',
      'blankWhite' || _ => 'ورق أبيض ناصع',
    };
  }

  IconData _themeIcon(String themeName) {
    return switch (themeName) {
      'gridMath' => Icons.grid_on_rounded,
      'linedNotebook' => Icons.format_line_spacing_rounded,
      'darkSlate' => Icons.nightlight_round,
      'blankWhite' || _ => Icons.crop_square_rounded,
    };
  }

  Color _themeColor(String themeName) {
    return switch (themeName) {
      'gridMath' => const Color(0xFF2563EB),
      'linedNotebook' => const Color(0xFF0D9488),
      'darkSlate' => const Color(0xFF475569),
      'blankWhite' || _ => const Color(0xFF64748B),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent =
        _isTeacher ? AppColors.teacherRole : AppColors.primary;
    final titleText = _isTeacher
        ? 'سبوراتي ومسودات التحضير'
        : 'سبوراتي الذاتية للمذاكرة';

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
                  _isTeacher ? Icons.draw_rounded : Icons.menu_book_rounded,
                  color: primaryAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  titleText,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث السبورات',
              onPressed: _loadBoards,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _boards.isEmpty
                ? _buildEmptyState(primaryAccent, isDark)
                : _buildBoardsContent(primaryAccent, isDark),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: primaryAccent,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_rounded, size: 22),
          label: Text(
            _isTeacher ? 'سبورة جديدة' : 'مذاكرة جديدة',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          onPressed: _createNewBoard,
        ),
      ),
    );
  }

  Widget _buildBoardsContent(Color primaryAccent, bool isDark) {
    final list = _filteredBoards;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final int crossAxisCount;
        if (screenWidth >= 950) {
          crossAxisCount = 3;
        } else if (screenWidth >= 580) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        final horizontalPadding = screenWidth < 380 ? 12.0 : 16.0;

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Executive AAA Hero Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  14,
                  horizontalPadding,
                  10,
                ),
                child: _buildExecutiveHeroBanner(primaryAccent, isDark, screenWidth),
              ),
            ),

            // Search Bar & Theme Filter Chips
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  4,
                  horizontalPadding,
                  8,
                ),
                child: _buildSearchAndFilterSection(primaryAccent, isDark),
              ),
            ),

            // Filter Active Status or Results Header
            if (_searchQuery.isNotEmpty || _selectedThemeFilter != 'all')
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    2,
                    horizontalPadding,
                    10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'نتائج البحث: ${list.length} من أصل ${_boards.length} سبورة',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: primaryAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        icon: const Icon(Icons.clear_all_rounded, size: 16),
                        label: const Text('إلغاء الفلتر', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchCtrl.clear();
                            _selectedThemeFilter = 'all';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // Whiteboard Cards Grid or Empty Search State
            if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 54,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'لا توجد سبورات مطابقة لبحثك',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'جرب البحث باسم آخر أو إزالة تصنيف الخلفية المحدد.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchCtrl.clear();
                              _selectedThemeFilter = 'all';
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('عرض جميع السبورات'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  4,
                  horizontalPadding,
                  96,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 180,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildBoardCard(list[i], primaryAccent, isDark),
                    childCount: list.length,
                  ),
                ),
              ),
          ],
        );
      },
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
          // Header Wrap with Tag & Privacy Lock
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: primaryAccent.withValues(alpha: isDark ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isTeacher ? Icons.school_rounded : Icons.auto_stories_rounded,
                      size: 13,
                      color: primaryAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isTeacher ? 'استوديو التحضير' : 'مذكراتي',
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
                      'مساحة مشفرة 🔒',
                      style: TextStyle(
                        fontSize: 11,
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
                ? 'سبوراتي ومسودات الدروس 🎨'
                : 'دفتر السبورات والمذاكرة الذاتية 🧠✏️',
            style: TextStyle(
              fontSize: isSmall ? 17 : 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isTeacher
                ? 'مساحتك الحرة والآمنة لتجهيز الشروحات التفاعلية، مسودات الدروس، ورسم المخططات الهندسية.'
                : 'دفترك الرقمي الخاص لمذاكرة دروسك، حل المسائل والمعادلات، وتلخيص القوانين بحرية تامة.',
            style: TextStyle(
              fontSize: isSmall ? 12 : 13,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              height: 1.45,
            ),
          ),

          const SizedBox(height: 14),

          // Dynamic Responsive KPIs Strip
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildKpiChip(
                icon: Icons.dashboard_customize_rounded,
                label: 'السبورات',
                value: '${_boards.length}',
                color: primaryAccent,
                isDark: isDark,
              ),
              _buildKpiChip(
                icon: Icons.gesture_rounded,
                label: 'الرسومات',
                value: '$_totalStrokes',
                color: const Color(0xFF0D9488),
                isDark: isDark,
              ),
              _buildKpiChip(
                icon: Icons.brush_rounded,
                label: 'الخلفيات',
                value: '4 أنماط',
                color: const Color(0xFFEA580C),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
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
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10.5,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection(Color primaryAccent, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Field
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: TextField(
            controller: _searchCtrl,
            textDirection: TextDirection.rtl,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'ابحث في السبورات بالاسم أو الموضوع...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: primaryAccent,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Filter Theme Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip(
                key: 'all',
                label: 'الكل',
                count: _boards.length,
                icon: Icons.layers_rounded,
                accentColor: primaryAccent,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                key: 'gridMath',
                label: 'شبكة هندسية 📐',
                count: _countByTheme('gridMath'),
                icon: Icons.grid_on_rounded,
                accentColor: const Color(0xFF2563EB),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                key: 'linedNotebook',
                label: 'كشكول مسطر 📝',
                count: _countByTheme('linedNotebook'),
                icon: Icons.format_line_spacing_rounded,
                accentColor: const Color(0xFF0D9488),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                key: 'darkSlate',
                label: 'سبورة سوداء 🖤',
                count: _countByTheme('darkSlate'),
                icon: Icons.nightlight_round,
                accentColor: const Color(0xFF475569),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                key: 'blankWhite',
                label: 'ورق أبيض 📄',
                count: _countByTheme('blankWhite'),
                icon: Icons.crop_square_rounded,
                accentColor: const Color(0xFF64748B),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String key,
    required String label,
    required int count,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    final isSelected = _selectedThemeFilter == key;

    return InkWell(
      onTap: () => setState(() => _selectedThemeFilter = key),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: isDark ? 0.35 : 0.15)
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? accentColor
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? accentColor
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.25)
                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? accentColor
                      : (isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardCard(
    PersonalWhiteboardItem item,
    Color primaryAccent,
    bool isDark,
  ) {
    final themeColor = _themeColor(item.bgTheme);
    final themeIcon = _themeIcon(item.bgTheme);
    final themeLabel = _themeLabel(item.bgTheme);
    final metaColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return InkWell(
      onTap: () => _openBoard(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Accent Ribbon with safe ellipsis
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: isDark ? 0.2 : 0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Icon(themeIcon, size: 15, color: themeColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      themeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                    tooltip: 'خيارات السبورة',
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (val) {
                      switch (val) {
                        case 1:
                          _renameBoard(item);
                          break;
                        case 2:
                          _duplicateBoard(item);
                          break;
                        case 3:
                          _deleteBoard(item);
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 1,
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 17, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('تعديل الاسم'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 2,
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 17, color: Colors.teal),
                            SizedBox(width: 8),
                            Text('نسخ ومضاعفة'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 3,
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 17, color: Colors.red),
                            SizedBox(width: 8),
                            Text('حذف', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Bottom Metadata Row completely guarded from overflow
                    Row(
                      children: [
                        Icon(
                          Icons.draw_rounded,
                          size: 13,
                          color: metaColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${item.strokeCount} خط/رسمة',
                            style: TextStyle(
                              fontSize: 11,
                              color: metaColor,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: metaColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _formatFriendlyDate(item.updatedAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: metaColor,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color primaryAccent, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    primaryAccent.withValues(alpha: 0.2),
                    primaryAccent.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: primaryAccent.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.draw_rounded,
                size: 52,
                color: primaryAccent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isTeacher
                  ? 'لا توجد سبورات مسودة بعد'
                  : 'دفتر السبورات فارغ حتى الآن',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                _isTeacher
                    ? 'ابدأ بإنشاء سبورة جديدة لتحضير شروحاتك، كتابة الملاحظات، أو مسودات الدروس الخاصة بك.'
                    : 'ابدأ بإنشاء سبورتك الأولى لمذاكرة دروسك، حل المسائل والمعادلات، وتلخيص القوانين بحرية تامة!',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: primaryAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'فتح سبورة جديدة الآن',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _createNewBoard,
            ),
          ],
        ),
      ),
    );
  }
}
