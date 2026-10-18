import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../design_system/tokens/colors.dart';
import '../../data/services/personal_whiteboards_storage.dart';
import '../../domain/models/personal_whiteboard_item.dart';
import 'student_personal_board_screen.dart';

/// Screen listing all personal whiteboards for a student or teacher.
/// Allows creating, opening, renaming, duplicating, and deleting personal study boards.
class PersonalWhiteboardsHubScreen extends StatefulWidget {
  final String? userId;
  final String role; // 'student' or 'teacher'

  const PersonalWhiteboardsHubScreen({
    super.key,
    this.userId,
    this.role = 'student',
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
  bool _isSearching = false;

  String get _effectiveUserId => widget.userId ?? 'guest';
  bool get _isTeacher => widget.role == 'teacher';

  @override
  void initState() {
    super.initState();
    _loadBoards();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBoards() async {
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
        title: Row(
          children: const [
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
      await PersonalWhiteboardsStorage.renameBoard(
        userId: _effectiveUserId,
        boardId: item.id,
        newTitle: newTitle,
      );
      if (mounted) _loadBoards();
    }
  }

  Future<void> _duplicateBoard(PersonalWhiteboardItem item) async {
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
      await PersonalWhiteboardsStorage.deleteBoard(
        userId: _effectiveUserId,
        boardId: item.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف السبورة'),
            duration: Duration(seconds: 2),
          ),
        );
        _loadBoards();
      }
    }
  }

  List<PersonalWhiteboardItem> get _filteredBoards {
    if (_searchQuery.trim().isEmpty) return _boards;
    final q = _searchQuery.trim().toLowerCase();
    return _boards.where((b) => b.title.toLowerCase().contains(q)).toList();
  }

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
      'darkSlate' => 'لوح أسود داكن',
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
        ? 'سبوراتي ومسودات التحضير 🎨'
        : 'سبوراتي الذاتية للمذاكرة 🧠✏️';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          elevation: 0,
          backgroundColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          title: _isSearching
              ? TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'ابحث في السبورات بالاسم...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                )
              : Text(
                  titleText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
              tooltip: _isSearching ? 'إغلاق البحث' : 'بحث في السبورات',
              onPressed: () {
                setState(() {
                  if (_isSearching) {
                    _searchQuery = '';
                    _searchCtrl.clear();
                  }
                  _isSearching = !_isSearching;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
              onPressed: _loadBoards,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _boards.isEmpty
                ? _buildEmptyState(primaryAccent, isDark)
                : _buildBoardsList(primaryAccent, isDark),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: primaryAccent,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text(
            'سبورة جديدة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          onPressed: _createNewBoard,
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

  Widget _buildBoardsList(Color primaryAccent, bool isDark) {
    final list = _filteredBoards;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 3
            : (constraints.maxWidth > 550 ? 2 : 1);

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_special_rounded, color: primaryAccent),
                      const SizedBox(width: 10),
                      Text(
                        'إجمالي السبورات المحفوظة: ${_boards.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'مساحة شخصية 🔒',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (list.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'لا توجد سبورة مطابقة لنتيجة البحث',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 170,
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

  Widget _buildBoardCard(
    PersonalWhiteboardItem item,
    Color primaryAccent,
    bool isDark,
  ) {
    final themeColor = _themeColor(item.bgTheme);
    final themeIcon = _themeIcon(item.bgTheme);
    final themeLabel = _themeLabel(item.bgTheme);

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
            // Top Accent Bar with preview theme
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: isDark ? 0.18 : 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Icon(themeIcon, size: 16, color: themeColor),
                  const SizedBox(width: 6),
                  Text(
                    themeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: themeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                    tooltip: 'خيارات',
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
                            Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
                            SizedBox(width: 10),
                            Text('تعديل الاسم'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 2,
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 18, color: Colors.teal),
                            SizedBox(width: 10),
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
                                size: 18, color: Colors.red),
                            SizedBox(width: 10),
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
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          size: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.strokeCount} رسمة/خط',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatFriendlyDate(item.updatedAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
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
}
