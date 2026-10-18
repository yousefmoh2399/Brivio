import 'package:flutter/material.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class DrawingPoint {
  final Offset point;
  final Paint paint;
  final bool isEndOfStroke;

  const DrawingPoint({
    required this.point,
    required this.paint,
    this.isEndOfStroke = false,
  });
}

class StampItem {
  final Offset position;
  final String label;
  final IconData icon;
  final Color color;

  const StampItem({
    required this.position,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class SmartGradingStudioDialog extends StatefulWidget {
  final String studentName;
  final String submissionId;
  final double initialScore;
  final double maxScore;
  final String initialFeedback;
  final String? attachmentUrl;
  final String? submissionText;
  final String? assessmentTitle;
  final String? assessmentType;

  const SmartGradingStudioDialog({
    super.key,
    required this.studentName,
    required this.submissionId,
    this.initialScore = 15.0,
    this.maxScore = 20.0,
    this.initialFeedback = '',
    this.attachmentUrl,
    this.submissionText,
    this.assessmentTitle,
    this.assessmentType,
  });

  @override
  State<SmartGradingStudioDialog> createState() => _SmartGradingStudioDialogState();
}

class _SmartGradingStudioDialogState extends State<SmartGradingStudioDialog> {
  late double _currentScore;
  late TextEditingController _feedbackCtrl;

  final List<DrawingPoint> _points = [];
  final List<StampItem> _stamps = [];

  // Tools: 'pen_red', 'pen_green', 'highlighter', 'eraser', 'stamp'
  String _activeTool = 'pen_red';
  String _selectedStamp = 'check'; // 'check', 'cross', 'star', 'warning', 'hundred'
  final double _strokeWidth = 3.5;

  final List<String> _quickComments = [
    'حل نموذجي ومنظم يستحق التقدير! 🌟',
    'فهم عميق واستنتاج رياضي دقيق 📐',
    'انتبه لحساب النواتج والوحدات بدقة ⚠️',
    'يرجى كتابة خطوات الحل كاملة في المسائل المقالية 📝',
    'أداء متميز وفخور بيك يا بطل، استمر 🚀',
  ];

  @override
  void initState() {
    super.initState();
    _currentScore = widget.initialScore;
    _feedbackCtrl = TextEditingController(text: widget.initialFeedback);
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Paint _getCurrentPaint() {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    if (_activeTool == 'pen_red') {
      paint.color = Colors.redAccent.shade700;
      paint.strokeWidth = _strokeWidth;
    } else if (_activeTool == 'pen_green') {
      paint.color = Colors.green.shade700;
      paint.strokeWidth = _strokeWidth;
    } else if (_activeTool == 'highlighter') {
      paint.color = Colors.amber.withValues(alpha: 0.4);
      paint.strokeWidth = 16.0;
    } else if (_activeTool == 'eraser') {
      paint.color = Colors.white;
      paint.strokeWidth = 24.0;
      paint.blendMode = BlendMode.clear;
    }
    return paint;
  }

  void _onPanStart(DragStartDetails details, RenderBox box) {
    final localPos = box.globalToLocal(details.globalPosition);

    if (_activeTool == 'stamp') {
      _addStampAtPosition(localPos);
      return;
    }

    setState(() {
      _points.add(DrawingPoint(
        point: localPos,
        paint: _getCurrentPaint(),
      ));
    });
  }

  void _onPanUpdate(DragUpdateDetails details, RenderBox box) {
    if (_activeTool == 'stamp') return;

    final localPos = box.globalToLocal(details.globalPosition);
    setState(() {
      _points.add(DrawingPoint(
        point: localPos,
        paint: _getCurrentPaint(),
      ));
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_activeTool == 'stamp') return;

    setState(() {
      if (_points.isNotEmpty) {
        _points.add(DrawingPoint(
          point: _points.last.point,
          paint: _getCurrentPaint(),
          isEndOfStroke: true,
        ));
      }
    });
  }

  void _addStampAtPosition(Offset position) {
    StampItem? stamp;
    switch (_selectedStamp) {
      case 'check':
        stamp = StampItem(
          position: position,
          label: 'صحيح ✔️',
          icon: Icons.check_circle_rounded,
          color: Colors.green.shade700,
        );
        break;
      case 'cross':
        stamp = StampItem(
          position: position,
          label: 'خطأ ❌',
          icon: Icons.cancel_rounded,
          color: Colors.redAccent.shade700,
        );
        break;
      case 'star':
        stamp = StampItem(
          position: position,
          label: 'امتياز ⭐',
          icon: Icons.stars_rounded,
          color: Colors.amber.shade700,
        );
        break;
      case 'warning':
        stamp = StampItem(
          position: position,
          label: 'راجع القانون ⚠️',
          icon: Icons.warning_amber_rounded,
          color: Colors.orange.shade800,
        );
        break;
      case 'hundred':
        stamp = StampItem(
          position: position,
          label: '10/10 💯',
          icon: Icons.workspace_premium_rounded,
          color: Colors.purple.shade700,
        );
        break;
    }

    if (stamp != null) {
      setState(() {
        _stamps.add(stamp!);
      });
    }
  }

  void _undo() {
    setState(() {
      if (_stamps.isNotEmpty && (_points.isEmpty || _activeTool == 'stamp')) {
        _stamps.removeLast();
        return;
      }

      if (_points.isNotEmpty) {
        int lastIndex = _points.length - 1;
        while (lastIndex >= 0 && !_points[lastIndex].isEndOfStroke) {
          lastIndex--;
        }
        if (lastIndex >= 0) {
          _points.removeRange(lastIndex, _points.length);
        } else {
          _points.clear();
        }
      }
    });
  }

  void _clearCanvas() {
    setState(() {
      _points.clear();
      _stamps.clear();
    });
  }

  void _adjustScore(double delta) {
    setState(() {
      _currentScore = (_currentScore + delta).clamp(0.0, widget.maxScore);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 850),
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.draw_rounded, color: Colors.redAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'استوديو التصحيح الذكي والقلم الرقمي ✍️',
                              style: AppTypography.titleMedium(textPrimary).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.studentName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'صحح كشكول الطالب مباشرة بالقلم الرقمي وضع الأختام والملاحظات التشجيعية',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Toolbar: Pens, Stamps, Eraser, Undo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildToolButton(
                      id: 'pen_red',
                      label: 'قلم أحمر',
                      icon: Icons.edit_rounded,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 8),
                    _buildToolButton(
                      id: 'pen_green',
                      label: 'قلم أخضر',
                      icon: Icons.edit_rounded,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _buildToolButton(
                      id: 'highlighter',
                      label: 'تظليل',
                      icon: Icons.brush_rounded,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    _buildToolButton(
                      id: 'eraser',
                      label: 'ممحاة',
                      icon: Icons.auto_fix_normal_rounded,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 16),
                    Container(height: 24, width: 1, color: Colors.grey.withValues(alpha: 0.4)),
                    const SizedBox(width: 16),

                    // Stamps Selector
                    _buildStampChip('check', 'صح ✔️', Colors.green),
                    const SizedBox(width: 6),
                    _buildStampChip('cross', 'خطأ ❌', Colors.redAccent),
                    const SizedBox(width: 6),
                    _buildStampChip('star', 'امتياز ⭐', Colors.amber),
                    const SizedBox(width: 6),
                    _buildStampChip('warning', 'تنبيه ⚠️', Colors.orange),
                    const SizedBox(width: 6),
                    _buildStampChip('hundred', '10/10 💯', Colors.purple),

                    const SizedBox(width: 16),
                    Container(height: 24, width: 1, color: Colors.grey.withValues(alpha: 0.4)),
                    const SizedBox(width: 16),

                    // Undo / Clear
                    IconButton(
                      tooltip: 'تراجع عن آخر خطوة',
                      icon: const Icon(Icons.undo_rounded, size: 20),
                      onPressed: (_points.isNotEmpty || _stamps.isNotEmpty) ? _undo : null,
                    ),
                    IconButton(
                      tooltip: 'مسح كل الملاحظات من الصفحة',
                      icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: Colors.redAccent),
                      onPressed: (_points.isNotEmpty || _stamps.isNotEmpty) ? _clearCanvas : null,
                    ),
                  ],
                ),
              ),
            ),

            // Canvas & Student Notebook Area
            Expanded(
              child: Builder(
                builder: (canvasContext) {
                  return GestureDetector(
                    onPanStart: (d) {
                      final box = canvasContext.findRenderObject() as RenderBox;
                      _onPanStart(d, box);
                    },
                    onPanUpdate: (d) {
                      final box = canvasContext.findRenderObject() as RenderBox;
                      _onPanUpdate(d, box);
                    },
                    onPanEnd: _onPanEnd,
                    child: Stack(
                      children: [
                        // Notebook Background Pattern (Lined notebook look)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _NotebookPaperBackgroundPainter(isDark: isDark),
                          ),
                        ),

                        // If student submitted an image attachment (homework sheet / solution scan)
                        if (widget.attachmentUrl != null && widget.attachmentUrl!.trim().isNotEmpty)
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: Image.network(
                                  widget.attachmentUrl!,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (ctx, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                  errorBuilder: (ctx, err, _) {
                                    return Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.amber),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.broken_image_rounded, color: Colors.amber),
                                            SizedBox(width: 8),
                                            Text('تعذر تحميل صورة المرفق، يرجى التحقق من الشبكة'),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                        // If student wrote a text answer/essay/solution
                        if (widget.submissionText != null && widget.submissionText!.trim().isNotEmpty)
                          Positioned(
                            top: 24,
                            left: 32,
                            right: 32,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? Colors.white24 : Colors.blueGrey.shade200,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.description_rounded, size: 16, color: Colors.blue),
                                      const SizedBox(width: 6),
                                      Text(
                                        'إجابة الطالب المكتوبة:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.submissionText!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.6,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Freehand ink drawing layer
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DrawingPainter(points: _points),
                          ),
                        ),

                        // Placed Stamps layer
                        ..._stamps.map((stamp) {
                          return Positioned(
                            left: stamp.position.dx - 20,
                            top: stamp.position.dy - 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: stamp.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: stamp.color, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: stamp.color.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(stamp.icon, color: stamp.color, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    stamp.label,
                                    style: TextStyle(
                                      color: stamp.color,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Grading & Feedback Controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Quick Comments Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _quickComments.map((comment) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ActionChip(
                            avatar: const Icon(Icons.bolt_rounded, size: 16, color: Colors.amber),
                            label: Text(comment, style: const TextStyle(fontSize: 11)),
                            backgroundColor: isDark ? Colors.white10 : Colors.white,
                            onPressed: () {
                              setState(() {
                                if (_feedbackCtrl.text.isEmpty) {
                                  _feedbackCtrl.text = comment;
                                } else {
                                  _feedbackCtrl.text += ' - $comment';
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Score Stepper & Final Submission
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 850;

                      final scoreStepperWidget = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                                onPressed: () => _adjustScore(-1.0),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_currentScore.toStringAsFixed(1)} / ${widget.maxScore.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                                onPressed: () => _adjustScore(1.0),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                ),
                                child: const Text('الدرجة النهائية 💯', style: TextStyle(fontSize: 11)),
                                onPressed: () => setState(() => _currentScore = widget.maxScore),
                              ),
                            ],
                          ),
                        ),
                      );

                      final feedbackField = TextField(
                        controller: _feedbackCtrl,
                        decoration: InputDecoration(
                          hintText: 'ملاحظة المعلم للطالب على كشكول الحل...',
                          hintStyle: const TextStyle(fontSize: 12),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );

                      final submitBtn = FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          backgroundColor: Colors.green.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context, {
                            'score': _currentScore,
                            'feedback': _feedbackCtrl.text.trim(),
                            'stampsCount': _stamps.length,
                          });
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('اعتماد التصحيح والدرجة ✨', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      );

                      if (isDesktop) {
                        return Row(
                          children: [
                            scoreStepperWidget,
                            const SizedBox(width: 12),
                            Expanded(child: feedbackField),
                            const SizedBox(width: 12),
                            submitBtn,
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          scoreStepperWidget,
                          const SizedBox(height: 10),
                          feedbackField,
                          const SizedBox(height: 10),
                          submitBtn,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required String id,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _activeTool == id;
    return InkWell(
      onTap: () => setState(() => _activeTool = id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStampChip(String id, String label, Color color) {
    final isSelected = _activeTool == 'stamp' && _selectedStamp == id;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : color)),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.1),
      onSelected: (val) {
        setState(() {
          _activeTool = 'stamp';
          _selectedStamp = id;
        });
      },
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;

  _DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i].isEndOfStroke) continue;
      if (points[i + 1].isEndOfStroke) continue;

      canvas.drawLine(points[i].point, points[i + 1].point, points[i].paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}

class _NotebookPaperBackgroundPainter extends CustomPainter {
  final bool isDark;

  _NotebookPaperBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Fill paper background
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFFDFEFE);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Draw lined notebook horizontal rules
    final linePaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    const lineSpacing = 32.0;
    for (double y = lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Draw notebook margin red line on right side (Arabic RTL)
    final marginPaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(size.width - 48, 0), Offset(size.width - 48, size.height), marginPaint);
  }

  @override
  bool shouldRepaint(covariant _NotebookPaperBackgroundPainter oldDelegate) => false;
}
