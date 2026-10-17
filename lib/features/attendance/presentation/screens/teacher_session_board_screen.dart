import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../attendance/domain/models/attendance_models.dart';

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

enum _BoardBackgroundTheme {
  darkSlate,
  gridMath,
  linedNotebook,
  blankWhite,
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

class _BoardStroke {
  final _ToolType tool;
  final Color color;
  final double width;
  final double opacity;
  final List<_StrokePoint> points;

  const _BoardStroke({
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

  factory _BoardStroke.fromJson(Map<String, dynamic> j) {
    _ToolType toolType;
    try {
      toolType = _ToolType.values.byName(j['tool'] as String? ?? 'pen');
    } catch (_) {
      toolType = _ToolType.pen;
    }
    return _BoardStroke(
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

/// Professional interactive whiteboard for teachers.
/// Feature-parity with Student Board + Session Sync, Cloud Persistence, & Student Publishing.
class TeacherSessionBoardScreen extends StatefulWidget {
  final String teacherId;
  final ClassSession? session;
  final String? groupName;
  final String? lessonTitle;

  const TeacherSessionBoardScreen({
    super.key,
    required this.teacherId,
    this.session,
    this.groupName,
    this.lessonTitle,
  });

  @override
  State<TeacherSessionBoardScreen> createState() =>
      _TeacherSessionBoardScreenState();
}

class _TeacherSessionBoardScreenState extends State<TeacherSessionBoardScreen> {
  final TransformationController _transformCtrl = TransformationController();

  List<_BoardStroke> _strokes = [];
  final List<List<_BoardStroke>> _undoStack = [];
  final List<List<_BoardStroke>> _redoStack = [];

  _ToolType _currentTool = _ToolType.pen;
  Color _selectedColor = const Color(0xFF1D4ED8);
  double _strokeWidth = 3.5;
  _BoardBackgroundTheme _bgTheme = _BoardBackgroundTheme.darkSlate;
  _BoardStroke? _activeStroke;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPublished = false;

  static const List<Color> _palette = [
    Color(0xFF1D4ED8), // Royal Blue
    Color(0xFFFFFFFF), // Chalk White
    Color(0xFFDC2626), // Vivid Red
    Color(0xFF16A34A), // Emerald Green
    Color(0xFFEA580C), // Orange
    Color(0xFF9333EA), // Purple
    Color(0xFF0284C7), // Sky Blue
    Color(0xFFFBBF24), // Gold / Yellow
  ];

  @override
  void initState() {
    super.initState();
    _loadBoard();
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  String get _localCacheKey =>
      'teacher_board_${widget.teacherId}_${widget.session?.id ?? "general"}';

  Future<void> _loadBoard() async {
    setState(() => _isLoading = true);

    // 1. Try loading from local cache first for instant feedback
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_localCacheKey);
      if (cached != null && cached.isNotEmpty) {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final strokesList = (decoded['strokes'] as List? ?? [])
            .whereType<Map>()
            .map((s) => _BoardStroke.fromJson(Map<String, dynamic>.from(s)))
            .toList();
        final savedTheme = decoded['theme'] as String?;
        if (savedTheme != null) {
          try {
            _bgTheme = _BoardBackgroundTheme.values.byName(savedTheme);
          } catch (_) {}
        }
        _strokes = strokesList;
      }
    } catch (_) {}

    // 2. Fetch latest from Supabase if session is linked
    if (widget.session != null) {
      try {
        final row = await Supabase.instance.client
            .from('class_session_boards')
            .select()
            .eq('class_session_id', widget.session!.id)
            .maybeSingle();

        if (row != null && mounted) {
          final geometry = Map<String, dynamic>.from(
            row['board_data'] as Map? ?? {},
          );
          final strokesRaw = geometry['strokes'] as List? ?? [];
          final remoteStrokes = strokesRaw
              .whereType<Map>()
              .map((s) => _BoardStroke.fromJson(Map<String, dynamic>.from(s)))
              .toList();

          setState(() {
            _isPublished = row['is_published'] as bool? ?? false;
            if (remoteStrokes.isNotEmpty) {
              _strokes = remoteStrokes;
            }
          });
        }
      } catch (e) {
        debugPrint('Supabase board load error: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBoard({bool? publish}) async {
    setState(() => _isSaving = true);
    final targetPublish = publish ?? _isPublished;

    // 1. Save to local device cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode({
        'strokes': _strokes.map((s) => s.toJson()).toList(),
        'theme': _bgTheme.name,
        'updated_at': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_localCacheKey, encoded);
    } catch (_) {}

    // 2. Save to Supabase remote database
    if (widget.session != null) {
      try {
        final payload = {
          'class_session_id': widget.session!.id,
          'group_id': widget.session!.groupId,
          'teacher_id': widget.teacherId,
          'board_data': {
            'strokes': _strokes.map((s) => s.toJson()).toList(),
            'theme': _bgTheme.name,
          },
          'is_published': targetPublish,
          'updated_at': DateTime.now().toIso8601String(),
        };

        final row = await Supabase.instance.client
            .from('class_session_boards')
            .upsert(payload, onConflict: 'class_session_id')
            .select()
            .single();

        if (mounted) {
          setState(() {
            _isPublished = row['is_published'] as bool? ?? targetPublish;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                targetPublish
                    ? 'تم حفظ السبورة ونشرها للطلاب بنجاح! 📢'
                    : 'تم حفظ مسودة الشرح بنجاح 💾',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم الحفظ محلياً على جهازك. (تعذر الاتصال بالسيرفر: $e)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ السبورة محلياً بنجاح 💾'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  void _pushUndo() {
    _undoStack.add(List.from(_strokes));
    if (_undoStack.length > 30) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _redoStack.add(List.from(_strokes));
      _strokes = _undoStack.removeLast();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _undoStack.add(List.from(_strokes));
      _strokes = _redoStack.removeLast();
    });
  }

  void _resetZoom() {
    HapticFeedback.mediumImpact();
    _transformCtrl.value = Matrix4.identity();
  }

  void _clearCanvas() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('مسح السبورة بالكامل؟ ⚠️'),
        content: const Text(
          'هل تريد مسح جميع الشروحات والملاحظات المكتوبة على هذه السبورة؟',
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
              _pushUndo();
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
    HapticFeedback.selectionClick();
    _pushUndo();

    final localPos = details.localPosition;
    final opacity = _currentTool == _ToolType.highlighter ? 0.35 : 1.0;
    final width = _currentTool == _ToolType.highlighter
        ? _strokeWidth * 3.5
        : (_currentTool == _ToolType.eraser ? _strokeWidth * 4.0 : _strokeWidth);

    _activeStroke = _BoardStroke(
      tool: _currentTool,
      color: _currentTool == _ToolType.eraser ? Colors.transparent : _selectedColor,
      width: width,
      opacity: opacity,
      points: [_StrokePoint(localPos.dx, localPos.dy)],
    );
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_activeStroke == null || _currentTool == _ToolType.pan) return;

    final localPos = details.localPosition;
    final pt = _StrokePoint(localPos.dx, localPos.dy);

    switch (_currentTool) {
      case _ToolType.pen:
      case _ToolType.highlighter:
      case _ToolType.eraser:
        setState(() {
          _activeStroke = _BoardStroke(
            tool: _activeStroke!.tool,
            color: _activeStroke!.color,
            width: _activeStroke!.width,
            opacity: _activeStroke!.opacity,
            points: [..._activeStroke!.points, pt],
          );
        });
        break;

      case _ToolType.line:
      case _ToolType.arrow:
      case _ToolType.rectangle:
      case _ToolType.circle:
        setState(() {
          final first = _activeStroke!.points.first;
          _activeStroke = _BoardStroke(
            tool: _activeStroke!.tool,
            color: _activeStroke!.color,
            width: _activeStroke!.width,
            opacity: _activeStroke!.opacity,
            points: [first, pt],
          );
        });
        break;

      case _ToolType.pan:
        break;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_activeStroke == null || _currentTool == _ToolType.pan) return;
    setState(() {
      _strokes.add(_activeStroke!);
      _activeStroke = null;
    });
  }

  Future<Uint8List?> _renderBoardToPng() async {
    if (_strokes.isEmpty) return null;

    double maxX = 1920, maxY = 1080;
    for (final s in _strokes) {
      for (final p in s.points) {
        if (p.x > maxX) maxX = p.x;
        if (p.y > maxY) maxY = p.y;
      }
    }
    maxX = (maxX + 100).clamp(1920.0, 3800.0);
    maxY = (maxY + 100).clamp(1080.0, 3800.0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, maxX, maxY),
    );

    final painter = _TeacherBoardPainter(
      strokes: _strokes,
      activeStroke: null,
      bgTheme: _bgTheme,
    );
    painter.paint(canvas, Size(maxX, maxY));

    final picture = recorder.endRecording();
    final img = await picture.toImage(maxX.toInt(), maxY.toInt());
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
      name: 'brivio_teacher_board_${widget.session?.id ?? "draft"}.pdf',
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
      filename: 'brivio_teacher_board_${widget.session?.id ?? "draft"}.png',
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
          child: Directionality(
            textDirection: TextDirection.rtl,
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
                  'تصدير ونشر شروحات السبورة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'مشاركة مذكرة الشرح مع الطلاب بصيغة PDF أو صورة عالية الدقة',
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
                  title: const Text('تصدير كملف PDF للطباعة (Landscape)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('مستند A4 جاهز للتوزيع على الطلاب والمجموعات'),
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
                  subtitle: const Text('إرسال الصورة مباشرة عبر مجموعات واتساب أو تيليجرام'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareAsImage();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkSlate = _bgTheme == _BoardBackgroundTheme.darkSlate;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDarkSlate ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: isDarkSlate ? const Color(0xFF1E293B) : Colors.white,
          foregroundColor: isDarkSlate ? Colors.white : Colors.black87,
          elevation: 1,
          titleSpacing: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.teacherRole.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.co_present_rounded, color: AppColors.teacherRole, size: 20),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.lessonTitle ?? 'السبورة الذكية للشرح التفاعلي 👨‍🏫',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.groupName ??
                          (widget.session != null
                              ? 'حصة دراسية معتمدة • ${widget.session!.sessionDate.toLocal().toString().split(' ').first}'
                              : 'مسودة حرة للمدرس'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkSlate ? Colors.white60 : Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Publishing Badge / Action
            if (widget.session != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: ActionChip(
                  avatar: Icon(
                    _isPublished ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    size: 16,
                    color: _isPublished ? Colors.green : Colors.grey,
                  ),
                  label: Text(
                    _isPublished ? 'منشورة للطلاب' : 'مسودة خاصة',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isPublished ? Colors.green : Colors.grey,
                    ),
                  ),
                  onPressed: () {
                    _saveBoard(publish: !_isPublished);
                  },
                ),
              ),

            // Undo / Redo
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: 'تراجع',
              onPressed: _undoStack.isNotEmpty ? _undo : null,
            ),
            IconButton(
              icon: const Icon(Icons.redo_rounded),
              tooltip: 'إعادة',
              onPressed: _redoStack.isNotEmpty ? _redo : null,
            ),
            IconButton(
              icon: const Icon(Icons.center_focus_strong_rounded),
              tooltip: 'إعادة ضبط المحاذاة',
              onPressed: _resetZoom,
            ),

            // Background Theme Selector
            PopupMenuButton<_BoardBackgroundTheme>(
              tooltip: 'نوع خلفية السبورة',
              icon: const Icon(Icons.grid_4x4_rounded),
              onSelected: (t) {
                setState(() => _bgTheme = t);
                _saveBoard();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: _BoardBackgroundTheme.darkSlate,
                  child: Row(
                    children: [
                      Icon(Icons.nightlight_round, color: Colors.greenAccent),
                      SizedBox(width: 8),
                      Text('سبورة كلاسيكية خضراء (Blackboard)'),
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
                      Text('كشكول مسطر (لغات وملاحظات)'),
                    ],
                  ),
                ),
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
              ],
            ),

            // Share & Export
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.blueAccent),
              tooltip: 'مشاركة وتصدير كصورة أو PDF',
              onPressed: _showExportSheet,
            ),

            // Save Button
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded, color: Colors.green),
              tooltip: 'حفظ الشرح',
              onPressed: _isSaving ? null : () => _saveBoard(),
            ),

            // Clear
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              tooltip: 'مسح السبورة',
              onPressed: _clearCanvas,
            ),
          ],
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
                              painter: _TeacherBoardPainter(
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

                  // Floating Control Bar
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: _buildFloatingControls(isDarkSlate),
                  ),
                ],
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
              _toolBtn(icon: Icons.edit_rounded, tool: _ToolType.pen, tooltip: 'قلم الكتابة الحر'),
              _toolBtn(icon: Icons.brush_rounded, tool: _ToolType.highlighter, tooltip: 'قلم فسفوري شفاف'),
              _toolBtn(icon: Icons.horizontal_rule_rounded, tool: _ToolType.line, tooltip: 'خط مستقيم'),
              _toolBtn(icon: Icons.arrow_right_alt_rounded, tool: _ToolType.arrow, tooltip: 'سهم توضيحي'),
              _toolBtn(icon: Icons.crop_square_rounded, tool: _ToolType.rectangle, tooltip: 'مستطيل'),
              _toolBtn(icon: Icons.circle_outlined, tool: _ToolType.circle, tooltip: 'دائرة'),
              _toolBtn(icon: Icons.auto_fix_normal_rounded, tool: _ToolType.eraser, tooltip: 'ممحاة'),
              _toolBtn(icon: Icons.pan_tool_rounded, tool: _ToolType.pan, tooltip: 'تحريك وتكبير السبورة'),

              const SizedBox(width: 8),
              Container(width: 1.2, height: 28, color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(width: 8),

              // Stroke Width
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
                              color: AppColors.teacherRole,
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

              // Palette Picker
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
                              ? (isDarkSlate ? Colors.white : Colors.black87)
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
        backgroundColor: isSelected ? AppColors.teacherRole.withValues(alpha: 0.2) : Colors.transparent,
        foregroundColor: isSelected ? AppColors.teacherRole : Colors.grey,
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

class _TeacherBoardPainter extends CustomPainter {
  final List<_BoardStroke> strokes;
  final _BoardStroke? activeStroke;
  final _BoardBackgroundTheme bgTheme;

  _TeacherBoardPainter({
    required this.strokes,
    required this.activeStroke,
    required this.bgTheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }

    if (activeStroke != null) {
      _paintStroke(canvas, activeStroke!);
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    switch (bgTheme) {
      case _BoardBackgroundTheme.darkSlate:
        canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0F241D)); // Teacher green chalkboard
        final subtleGrid = Paint()
          ..color = const Color(0xFF1B3B30)
          ..strokeWidth = 1.0;
        const dStep = 40.0;
        for (double x = 0; x < size.width; x += dStep) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), subtleGrid);
        }
        for (double y = 0; y < size.height; y += dStep) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), subtleGrid);
        }
        break;

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
        final marginPaint = Paint()
          ..color = const Color(0xFFFCA5A5)
          ..strokeWidth = 1.5;
        canvas.drawLine(const Offset(64, 0), Offset(64, size.height), marginPaint);
        break;
    }
  }

  void _paintStroke(Canvas canvas, _BoardStroke stroke) {
    if (stroke.points.isEmpty) return;

    final isEraser = stroke.tool == _ToolType.eraser;
    final strokePaint = Paint()
      ..color = isEraser
          ? (bgTheme == _BoardBackgroundTheme.darkSlate ? const Color(0xFF0F241D) : Colors.white)
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
          canvas.drawCircle(
            stroke.points.first.toOffset(),
            stroke.width / 2,
            strokePaint..style = PaintingStyle.fill,
          );
        } else {
          final path = Path()..moveTo(stroke.points.first.x, stroke.points.first.y);
          for (int i = 1; i < stroke.points.length; i++) {
            final p0 = stroke.points[i - 1].toOffset();
            final p1 = stroke.points[i].toOffset();
            final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
            path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
          }
          canvas.drawPath(path, strokePaint);
        }
        break;

      case _ToolType.line:
        if (stroke.points.length >= 2) {
          canvas.drawLine(
            stroke.points.first.toOffset(),
            stroke.points.last.toOffset(),
            strokePaint,
          );
        }
        break;

      case _ToolType.arrow:
        if (stroke.points.length >= 2) {
          final start = stroke.points.first.toOffset();
          final end = stroke.points.last.toOffset();
          canvas.drawLine(start, end, strokePaint);

          final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
          const arrowLen = 18.0;
          const arrowAngle = math.pi / 6;

          final path = Path()
            ..moveTo(end.dx, end.dy)
            ..lineTo(
              end.dx - arrowLen * math.cos(angle - arrowAngle),
              end.dy - arrowLen * math.sin(angle - arrowAngle),
            )
            ..lineTo(
              end.dx - arrowLen * math.cos(angle + arrowAngle),
              end.dy - arrowLen * math.sin(angle + arrowAngle),
            )
            ..close();

          canvas.drawPath(path, strokePaint..style = PaintingStyle.fill);
        }
        break;

      case _ToolType.rectangle:
        if (stroke.points.length >= 2) {
          final rect = Rect.fromPoints(
            stroke.points.first.toOffset(),
            stroke.points.last.toOffset(),
          );
          canvas.drawRect(rect, strokePaint);
        }
        break;

      case _ToolType.circle:
        if (stroke.points.length >= 2) {
          final rect = Rect.fromPoints(
            stroke.points.first.toOffset(),
            stroke.points.last.toOffset(),
          );
          canvas.drawOval(rect, strokePaint);
        }
        break;

      case _ToolType.pan:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _TeacherBoardPainter oldDelegate) => true;
}
