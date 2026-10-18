import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../data/services/personal_whiteboards_storage.dart';
import '../../domain/models/personal_whiteboard_item.dart';

enum _BoardBackgroundTheme {
  blankWhite,
  gridMath,
  linedNotebook,
  darkSlate,
}

enum _ToolType {
  pen,
  highlighter,
  line,
  arrow,
  rectangle,
  circle,
  eraser,
  pan,
}

class _StrokePoint {
  final double x;
  final double y;
  const _StrokePoint(this.x, this.y);

  Offset toOffset() => Offset(x, y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory _StrokePoint.fromJson(Map<String, dynamic> j) =>
      _StrokePoint((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
}

class _PersonalStroke {
  final _ToolType tool;
  final Color color;
  final double width;
  final double opacity;
  final List<_StrokePoint> points;

  const _PersonalStroke({
    required this.tool,
    required this.color,
    required this.width,
    this.opacity = 1.0,
    required this.points,
  });

  Map<String, dynamic> toJson() => {
    'tool': tool.name,
    'color': color.toARGB32(),
    'width': width,
    'opacity': opacity,
    'points': points.map((p) => p.toJson()).toList(),
  };

  factory _PersonalStroke.fromJson(Map<String, dynamic> j) {
    _ToolType toolType;
    try {
      toolType = _ToolType.values.byName(j['tool'] as String? ?? 'pen');
    } catch (_) {
      toolType = _ToolType.pen;
    }
    return _PersonalStroke(
      tool: toolType,
      color: Color(j['color'] as int? ?? 0xFF1D4ED8),
      width: (j['width'] as num? ?? 4.0).toDouble(),
      opacity: (j['opacity'] as num? ?? 1.0).toDouble(),
      points: (j['points'] as List? ?? [])
          .whereType<Map>()
          .map((p) => _StrokePoint.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
    );
  }
}

/// 100% Native, high-performance standalone personal whiteboard for the student or teacher.
/// Completely private, persistent, and independent of any class or teacher.
class StudentPersonalBoardScreen extends StatefulWidget {
  final String? studentId;
  final String? boardId;
  final String title;
  final bool isTeacher;

  const StudentPersonalBoardScreen({
    super.key,
    this.studentId,
    this.boardId,
    this.title = 'سبورة الملاحظات والمسودة الشخصية',
    this.isTeacher = false,
  });

  @override
  State<StudentPersonalBoardScreen> createState() =>
      _StudentPersonalBoardScreenState();
}

class _StudentPersonalBoardScreenState
    extends State<StudentPersonalBoardScreen> {
  final TransformationController _transformCtrl = TransformationController();

  late String _boardId;
  late String _boardTitle;
  DateTime? _createdAt;
  bool _hasUnsavedChanges = false;

  List<_PersonalStroke> _strokes = [];
  final List<List<_PersonalStroke>> _undoStack = [];
  final List<List<_PersonalStroke>> _redoStack = [];

  _ToolType _currentTool = _ToolType.pen;
  Color _selectedColor = const Color(0xFF1D4ED8);
  double _strokeWidth = 3.5;
  _BoardBackgroundTheme _bgTheme = _BoardBackgroundTheme.gridMath;
  _PersonalStroke? _activeStroke;
  bool _isLoading = true;

  static const List<Color> _palette = [
    Color(0xFF1D4ED8), // Royal Blue
    Color(0xFF0F172A), // Dark Slate / Black
    Color(0xFFDC2626), // Vivid Red
    Color(0xFF16A34A), // Emerald Green
    Color(0xFFEA580C), // Orange
    Color(0xFF9333EA), // Purple
    Color(0xFF0284C7), // Sky Blue
    Color(0xFFFBBF24), // Gold / Highlighter Yellow
  ];

  @override
  void initState() {
    super.initState();
    _boardId =
        widget.boardId ?? 'board_${DateTime.now().millisecondsSinceEpoch}';
    _boardTitle = widget.title;
    _loadSavedBoard();
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedBoard() async {
    try {
      if (widget.boardId != null) {
        final content =
            await PersonalWhiteboardsStorage.loadBoardContent(widget.boardId!);
        if (content != null) {
          final strokesList = (content['strokes'] as List? ?? [])
              .whereType<Map>()
              .map((s) => _PersonalStroke.fromJson(Map<String, dynamic>.from(s)))
              .toList();
          final savedTheme = content['theme'] as String?;
          if (savedTheme != null) {
            try {
              _bgTheme = _BoardBackgroundTheme.values.byName(savedTheme);
            } catch (_) {}
          }
          _strokes = strokesList;
          _createdAt =
              DateTime.tryParse(content['created_at']?.toString() ?? '');
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBoard({bool showFeedback = false}) async {
    try {
      final uId = widget.studentId ?? 'guest';
      final now = DateTime.now();
      _createdAt ??= now;
      final metadata = PersonalWhiteboardItem(
        id: _boardId,
        userId: uId,
        title: _boardTitle,
        createdAt: _createdAt!,
        updatedAt: now,
        bgTheme: _bgTheme.name,
        strokeCount: _strokes.length,
      );
      final content = {
        'theme': _bgTheme.name,
        'created_at': _createdAt!.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'strokes': _strokes.map((s) => s.toJson()).toList(),
      };
      await PersonalWhiteboardsStorage.saveBoard(
        metadata: metadata,
        content: content,
      );
      if (mounted) {
        setState(() => _hasUnsavedChanges = false);
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                  SizedBox(width: 8),
                  Text('تم حفظ السبورة والمسودة بنجاح ✅'),
                ],
              ),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {}
  }

  void _promptRename() {
    final ctrl = TextEditingController(text: _boardTitle);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تغيير اسم السبورة ✏️'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            labelText: 'اسم السبورة',
            hintText: 'أدخل اسماً للسبورة...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _boardTitle = name;
                  _hasUnsavedChanges = true;
                });
                _saveBoard();
              }
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExit() async {
    // If the canvas is completely blank and no strokes were ever drawn, just exit
    if (_strokes.isEmpty && !_hasUnsavedChanges) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // If there are unsaved changes or this is a new board with strokes:
    final ctrl = TextEditingController(text: _boardTitle);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.save_as_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('حفظ السبورة والمسودة 💾'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'هل ترغب في حفظ ملاحظاتك ومسودتك في دفترك للرجوع إليها لاحقاً؟ يمكنك تحديد اسم للسبورة:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                labelText: 'اسم السبورة',
                hintText: 'مثال: مراجعة الفيزياء، حل مسائل...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.edit_note_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('متابعة المذاكرة'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: const Text('خروج دون حفظ'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('حفظ وخروج'),
            onPressed: () => Navigator.of(ctx).pop('save'),
          ),
        ],
      ),
    );

    if (action == 'save') {
      final newName = ctrl.text.trim();
      if (newName.isNotEmpty) {
        _boardTitle = newName;
      }
      await _saveBoard(showFeedback: false);
      if (mounted) Navigator.of(context).pop();
    } else if (action == 'discard') {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _recordHistory() {
    _hasUnsavedChanges = true;
    _undoStack.add(List.from(_strokes));
    if (_undoStack.length > 30) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _hasUnsavedChanges = true;
      _redoStack.add(List.from(_strokes));
      _strokes = _undoStack.removeLast();
    });
    _saveBoard();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _hasUnsavedChanges = true;
      _undoStack.add(List.from(_strokes));
      _strokes = _redoStack.removeLast();
    });
    _saveBoard();
  }

  void _clearCanvas() {
    if (_strokes.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح السبورة بالكامل؟'),
        content: const Text(
          'هل تريد مسح جميع الرسومات والملاحظات المكتوبة على هذه السبورة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _recordHistory();
              setState(() => _strokes.clear());
              _saveBoard();
            },
            child: const Text('مسح الكل'),
          ),
        ],
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (_currentTool == _ToolType.pan) return;
    _recordHistory();
    final point = details.localPosition;
    final isHighlighter = _currentTool == _ToolType.highlighter;

    setState(() {
      _activeStroke = _PersonalStroke(
        tool: _currentTool,
        color: _currentTool == _ToolType.eraser ? Colors.transparent : _selectedColor,
        width: _currentTool == _ToolType.eraser
            ? _strokeWidth * 4.5
            : (isHighlighter ? _strokeWidth * 3.5 : _strokeWidth),
        opacity: isHighlighter ? 0.38 : 1.0,
        points: [_StrokePoint(point.dx, point.dy)],
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_currentTool == _ToolType.pan || _activeStroke == null) return;
    final point = details.localPosition;
    setState(() {
      if (_currentTool == _ToolType.pen ||
          _currentTool == _ToolType.highlighter ||
          _currentTool == _ToolType.eraser) {
        _activeStroke!.points.add(_StrokePoint(point.dx, point.dy));
      } else {
        // Shapes update second anchor
        if (_activeStroke!.points.length < 2) {
          _activeStroke!.points.add(_StrokePoint(point.dx, point.dy));
        } else {
          _activeStroke!.points[1] = _StrokePoint(point.dx, point.dy);
        }
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentTool == _ToolType.pan || _activeStroke == null) return;
    if (_activeStroke!.points.isNotEmpty) {
      if (_currentTool == _ToolType.eraser) {
        // Eraser removes intersecting strokes or acts as transparent eraser
        _strokes.add(_activeStroke!);
      } else {
        _strokes.add(_activeStroke!);
      }
    }
    setState(() => _activeStroke = null);
    _saveBoard();
  }

  void _resetZoom() {
    _transformCtrl.value = Matrix4.identity();
  }

  Future<Uint8List?> _renderBoardToPng() async {
    if (_strokes.isEmpty) return null;
    double minX = double.infinity, minY = double.infinity;
    double maxX = 0, maxY = 0;
    for (final s in _strokes) {
      for (final p in s.points) {
        if (p.x < minX) minX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.x > maxX) maxX = p.x;
        if (p.y > maxY) maxY = p.y;
      }
    }
    if (minX == double.infinity) {
      minX = 0;
      minY = 0;
      maxX = 1200;
      maxY = 800;
    }
    const margin = 50.0;
    minX = (minX - margin).clamp(0.0, 3800.0);
    minY = (minY - margin).clamp(0.0, 3800.0);
    maxX = (maxX + margin).clamp(minX + 400.0, 3800.0);
    maxY = (maxY + margin).clamp(minY + 300.0, 3800.0);

    final width = maxX - minX;
    final height = maxY - minY;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    canvas.translate(-minX, -minY);

    final painter = _PersonalBoardPainter(
      strokes: _strokes,
      activeStroke: null,
      bgTheme: _bgTheme,
    );
    painter.paint(canvas, Size(maxX, maxY));

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      width.toInt().clamp(100, 3800),
      height.toInt().clamp(100, 3800),
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _exportAsPdf() async {
    final pngBytes = await _renderBoardToPng();
    if (pngBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('السبورة فارغة! لا يوجد محتوى للتصدير.')),
        );
      }
      return;
    }
    final doc = await ReportGeneratorService.createDocument();
    final image = pw.MemoryImage(pngBytes);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (ctx) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
    await Printing.layoutPdf(
      name: 'brivio_whiteboard_${DateTime.now().millisecondsSinceEpoch}.pdf',
      onLayout: (format) async => doc.save(),
    );
  }

  Future<void> _shareAsImage() async {
    final pngBytes = await _renderBoardToPng();
    if (pngBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('السبورة فارغة! لا يوجد محتوى للتصدير.')),
        );
      }
      return;
    }
    await Printing.sharePdf(
      bytes: pngBytes,
      filename: 'brivio_whiteboard_${DateTime.now().millisecondsSinceEpoch}.png',
    );
  }

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'تصدير وحفظ محتوى السبورة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'اختر الصيغة المناسبة لحفظ أو مشاركة مسودتك وملاحظاتك',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                ),
                title: const Text('تصدير كملف PDF للطباعة والحفظ', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('مستند PDF عالي الجودة بحجم A4 جاهز للمشاركة'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportAsPdf();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.image_rounded, color: Colors.blue),
                ),
                title: const Text('مشاركة كصورة عالية الدقة (PNG)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('صورة واضحة لإرسالها بالواتساب أو حفظها في المعرض'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareAsImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBackgroundThemeDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.grid_4x4_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('نوع خلفية السبورة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.crop_square_rounded, color: Colors.grey),
              title: const Text('ورق أبيض ناصع'),
              selected: _bgTheme == _BoardBackgroundTheme.blankWhite,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _bgTheme = _BoardBackgroundTheme.blankWhite);
                _saveBoard();
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_on_rounded, color: Colors.blue),
              title: const Text('شبكة مربعات هندسية (رياضيات)'),
              selected: _bgTheme == _BoardBackgroundTheme.gridMath,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _bgTheme = _BoardBackgroundTheme.gridMath);
                _saveBoard();
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_line_spacing_rounded, color: Colors.teal),
              title: const Text('كشكول مسطر (ملاحظات)'),
              selected: _bgTheme == _BoardBackgroundTheme.linedNotebook,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _bgTheme = _BoardBackgroundTheme.linedNotebook);
                _saveBoard();
              },
            ),
            ListTile(
              leading: const Icon(Icons.nightlight_round, color: Colors.amber),
              title: const Text('سبورة سوداء كلاسيكية (Blackboard)'),
              selected: _bgTheme == _BoardBackgroundTheme.darkSlate,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _bgTheme = _BoardBackgroundTheme.darkSlate);
                _saveBoard();
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, double screenWidth) {
    final saveButton = IconButton(
      icon: Badge(
        isLabelVisible: _hasUnsavedChanges,
        smallSize: 8,
        backgroundColor: Colors.amber,
        child: const Icon(Icons.save_rounded),
      ),
      tooltip: _hasUnsavedChanges ? 'حفظ السبورة 💾' : 'تم الحفظ ✅',
      onPressed: () => _saveBoard(showFeedback: true),
    );

    final undoButton = IconButton(
      icon: const Icon(Icons.undo_rounded),
      tooltip: 'تراجع',
      onPressed: _undoStack.isNotEmpty ? _undo : null,
    );

    final redoButton = IconButton(
      icon: const Icon(Icons.redo_rounded),
      tooltip: 'إعادة',
      onPressed: _redoStack.isNotEmpty ? _redo : null,
    );

    if (screenWidth < 520) {
      final isUltraCompact = screenWidth < 380;
      return [
        saveButton,
        if (!isUltraCompact) undoButton,
        if (!isUltraCompact) redoButton,
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          tooltip: 'المزيد من الخيارات',
          onSelected: (val) {
            switch (val) {
              case 'undo':
                _undo();
                break;
              case 'redo':
                _redo();
                break;
              case 'theme':
                _showBackgroundThemeDialog();
                break;
              case 'zoom':
                _resetZoom();
                break;
              case 'export':
                _showExportSheet();
                break;
              case 'clear':
                _clearCanvas();
                break;
            }
          },
          itemBuilder: (ctx) => [
            if (isUltraCompact) ...[
              PopupMenuItem(
                value: 'undo',
                enabled: _undoStack.isNotEmpty,
                child: const Row(
                  children: [
                    Icon(Icons.undo_rounded, size: 20, color: Colors.blue),
                    SizedBox(width: 10),
                    Text('تراجع'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'redo',
                enabled: _redoStack.isNotEmpty,
                child: const Row(
                  children: [
                    Icon(Icons.redo_rounded, size: 20, color: Colors.blue),
                    SizedBox(width: 10),
                    Text('إعادة'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
            ],
            const PopupMenuItem(
              value: 'theme',
              child: Row(
                children: [
                  Icon(Icons.grid_4x4_rounded, size: 20, color: Colors.teal),
                  SizedBox(width: 10),
                  Text('خلفية السبورة'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'zoom',
              child: Row(
                children: [
                  Icon(Icons.center_focus_strong_rounded, size: 20, color: Colors.indigo),
                  SizedBox(width: 10),
                  Text('إعادة ضبط العرض'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.share_rounded, size: 20, color: Colors.deepPurple),
                  SizedBox(width: 10),
                  Text('تصدير ومشاركة (PDF / صورة)'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text('مسح محتوى السبورة', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
      ];
    }

    return [
      saveButton,
      undoButton,
      redoButton,
      IconButton(
        icon: const Icon(Icons.center_focus_strong_rounded),
        tooltip: 'إعادة ضبط العرض',
        onPressed: _resetZoom,
      ),
      PopupMenuButton<_BoardBackgroundTheme>(
        tooltip: 'نوع خلفية السبورة',
        icon: const Icon(Icons.grid_4x4_rounded),
        onSelected: (t) {
          setState(() => _bgTheme = t);
          _saveBoard();
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(
            value: _BoardBackgroundTheme.blankWhite,
            child: Row(
              children: [
                Icon(Icons.crop_square_rounded, color: Colors.grey),
                SizedBox(width: 8),
                Text('ورق أبيض ناصع'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: _BoardBackgroundTheme.gridMath,
            child: Row(
              children: [
                Icon(Icons.grid_on_rounded, color: Colors.blue),
                SizedBox(width: 8),
                Text('شبكة مربعات هندسية (رياضيات)'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: _BoardBackgroundTheme.linedNotebook,
            child: Row(
              children: [
                Icon(Icons.format_line_spacing_rounded, color: Colors.teal),
                SizedBox(width: 8),
                Text('كشكول مسطر (ملاحظات)'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: _BoardBackgroundTheme.darkSlate,
            child: Row(
              children: [
                Icon(Icons.nightlight_round, color: Colors.amber),
                SizedBox(width: 8),
                Text('سبورة سوداء كلاسيكية (Blackboard)'),
              ],
            ),
          ),
        ],
      ),
      IconButton(
        icon: const Icon(Icons.share_rounded, color: Colors.blueAccent),
        tooltip: 'مشاركة وتصدير السبورة كصورة أو PDF',
        onPressed: _showExportSheet,
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
        tooltip: 'مسح السبورة',
        onPressed: _clearCanvas,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDarkSlate = _bgTheme == _BoardBackgroundTheme.darkSlate;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _handleExit();
        },
        child: Scaffold(
          backgroundColor: isDarkSlate
              ? const Color(0xFF0F172A)
              : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor:
                isDarkSlate ? const Color(0xFF1E293B) : Colors.white,
            foregroundColor: isDarkSlate ? Colors.white : Colors.black87,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'رجوع لقائمة السبورات',
              onPressed: _handleExit,
            ),
            title: InkWell(
              onTap: _promptRename,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _boardTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      _hasUnsavedChanges
                          ? 'تغييرات غير محفوظة'
                          : 'مسودة محفوظة 🔒',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: _hasUnsavedChanges
                            ? Colors.amber.shade700
                            : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
            actions: _buildAppBarActions(context, screenWidth),
          ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: _transformCtrl,
                      panEnabled: _currentTool == _ToolType.pan,
                      scaleEnabled: _currentTool == _ToolType.pan,
                      minScale: 0.25,
                      maxScale: 6.0,
                      constrained: false,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: _currentTool != _ToolType.pan ? _onPanStart : null,
                        onPanUpdate: _currentTool != _ToolType.pan ? _onPanUpdate : null,
                        onPanEnd: _currentTool != _ToolType.pan ? _onPanEnd : null,
                        child: SizedBox(
                          width: 3800,
                          height: 3800,
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _PersonalBoardPainter(
                                strokes: _strokes,
                                activeStroke: _activeStroke,
                                bgTheme: _bgTheme,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Floating Native Control Bar
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: _buildFloatingControls(isDarkSlate),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildFloatingControls(bool isDarkSlate) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkSlate ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDarkSlate ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tool Buttons
              _toolBtn(icon: Icons.edit_rounded, tool: _ToolType.pen, tooltip: 'قلم الكتابة'),
              _toolBtn(icon: Icons.brush_rounded, tool: _ToolType.highlighter, tooltip: 'قلم تمييز شفاف'),
              _toolBtn(icon: Icons.horizontal_rule_rounded, tool: _ToolType.line, tooltip: 'خط مستقيم'),
              _toolBtn(icon: Icons.arrow_right_alt_rounded, tool: _ToolType.arrow, tooltip: 'سهم توضيحي'),
              _toolBtn(icon: Icons.crop_square_rounded, tool: _ToolType.rectangle, tooltip: 'مستطيل'),
              _toolBtn(icon: Icons.circle_outlined, tool: _ToolType.circle, tooltip: 'دائرة'),
              _toolBtn(icon: Icons.auto_fix_normal_rounded, tool: _ToolType.eraser, tooltip: 'ممحاة'),
              _toolBtn(icon: Icons.pan_tool_rounded, tool: _ToolType.pan, tooltip: 'تحريك وتكبير السبورة'),

              const SizedBox(width: 8),
              Container(width: 1.2, height: 28, color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(width: 8),

              // Stroke Width Selector
              PopupMenuButton<double>(
                tooltip: 'سماكة الخط',
                icon: Icon(
                  Icons.line_weight_rounded,
                  color: isDarkSlate ? Colors.white70 : Colors.black87,
                  size: 20,
                ),
                onSelected: (w) => setState(() => _strokeWidth = w),
                itemBuilder: (ctx) => [
                  for (final w in [1.8, 3.5, 6.0, 10.0, 16.0])
                    PopupMenuItem(
                      value: w,
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: w.clamp(2.0, 12.0),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${w.toStringAsFixed(1)} pt'),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 6),

              // Color Palette Picker
              for (final color in _palette)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedColor = color;
                        if (_currentTool == _ToolType.eraser || _currentTool == _ToolType.pan) {
                          _currentTool = _ToolType.pen;
                        }
                      });
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == color && _currentTool != _ToolType.eraser
                              ? Colors.white
                              : Colors.transparent,
                          width: 2.2,
                        ),
                        boxShadow: [
                          if (_selectedColor == color && _currentTool != _ToolType.eraser)
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolBtn({
    required IconData icon,
    required _ToolType tool,
    required String tooltip,
  }) {
    final isSelected = _currentTool == tool;
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
        foregroundColor: isSelected ? AppColors.primary : Colors.grey,
        padding: const EdgeInsets.all(6),
        minimumSize: const Size(36, 36),
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        setState(() => _currentTool = tool);
      },
    );
  }
}

class _PersonalBoardPainter extends CustomPainter {
  final List<_PersonalStroke> strokes;
  final _PersonalStroke? activeStroke;
  final _BoardBackgroundTheme bgTheme;

  _PersonalBoardPainter({
    required this.strokes,
    required this.activeStroke,
    required this.bgTheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Canvas Background
    _drawBackground(canvas, size);

    // 2. Draw Committed Strokes
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }

    // 3. Draw Currently Active Stroke
    if (activeStroke != null) {
      _paintStroke(canvas, activeStroke!);
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    switch (bgTheme) {
      case _BoardBackgroundTheme.blankWhite:
        canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
        break;

      case _BoardBackgroundTheme.gridMath:
        canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF8FAFC));
        final gridPaint = Paint()
          ..color = const Color(0xFFE2E8F0)
          ..strokeWidth = 1.0;
        const step = 32.0;
        for (double x = 0; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
        }
        for (double y = 0; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
        }
        break;

      case _BoardBackgroundTheme.linedNotebook:
        canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFBEB));
        final linePaint = Paint()
          ..color = const Color(0xFFE5E7EB)
          ..strokeWidth = 1.2;
        const lineSpacing = 36.0;
        for (double y = lineSpacing; y < size.height; y += lineSpacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
        }
        // Red notebook margin
        final marginPaint = Paint()
          ..color = const Color(0xFFFCA5A5)
          ..strokeWidth = 1.5;
        canvas.drawLine(const Offset(64, 0), Offset(64, size.height), marginPaint);
        break;

      case _BoardBackgroundTheme.darkSlate:
        canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0F172A));
        final subtleGrid = Paint()
          ..color = const Color(0xFF1E293B)
          ..strokeWidth = 1.0;
        const dStep = 40.0;
        for (double x = 0; x < size.width; x += dStep) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), subtleGrid);
        }
        for (double y = 0; y < size.height; y += dStep) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), subtleGrid);
        }
        break;
    }
  }

  void _paintStroke(Canvas canvas, _PersonalStroke stroke) {
    if (stroke.points.isEmpty) return;

    final isEraser = stroke.tool == _ToolType.eraser;
    final strokePaint = Paint()
      ..color = isEraser
          ? (bgTheme == _BoardBackgroundTheme.darkSlate ? const Color(0xFF0F172A) : Colors.white)
          : stroke.color.withValues(alpha: stroke.opacity)
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    switch (stroke.tool) {
      case _ToolType.pen:
      case _ToolType.highlighter:
      case _ToolType.eraser:
        if (stroke.points.length == 1) {
          canvas.drawCircle(stroke.points.first.toOffset(), stroke.width / 2, strokePaint..style = PaintingStyle.fill);
        } else {
          final path = Path()..moveTo(stroke.points.first.x, stroke.points.first.y);
          for (int i = 1; i < stroke.points.length; i++) {
            // Cubic bezier smoothing
            final p0 = stroke.points[i - 1].toOffset();
            final p1 = stroke.points[i].toOffset();
            final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
            path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
          }
          path.lineTo(stroke.points.last.x, stroke.points.last.y);
          canvas.drawPath(path, strokePaint);
        }
        break;

      case _ToolType.line:
        if (stroke.points.length >= 2) {
          canvas.drawLine(stroke.points.first.toOffset(), stroke.points.last.toOffset(), strokePaint);
        }
        break;

      case _ToolType.arrow:
        if (stroke.points.length >= 2) {
          final start = stroke.points.first.toOffset();
          final end = stroke.points.last.toOffset();
          canvas.drawLine(start, end, strokePaint);

          // Arrowhead
          final angle = (end - start).direction;
          const arrowSize = 14.0;
          final p1 = end - Offset.fromDirection(angle - 0.45, arrowSize);
          final p2 = end - Offset.fromDirection(angle + 0.45, arrowSize);
          final arrowPath = Path()
            ..moveTo(end.dx, end.dy)
            ..lineTo(p1.dx, p1.dy)
            ..lineTo(p2.dx, p2.dy)
            ..close();
          canvas.drawPath(arrowPath, strokePaint..style = PaintingStyle.fill);
        }
        break;

      case _ToolType.rectangle:
        if (stroke.points.length >= 2) {
          final rect = Rect.fromPoints(stroke.points.first.toOffset(), stroke.points.last.toOffset());
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), strokePaint);
        }
        break;

      case _ToolType.circle:
        if (stroke.points.length >= 2) {
          final rect = Rect.fromPoints(stroke.points.first.toOffset(), stroke.points.last.toOffset());
          canvas.drawOval(rect, strokePaint);
        }
        break;

      case _ToolType.pan:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PersonalBoardPainter oldDelegate) => true;
}
