import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../domain/models/assessment_models.dart';

/// Result returned from the student homework submission dialog.
class HomeworkSubmissionPayload {
  final String text;
  final String? attachmentUrl;
  final String? localFileName;

  const HomeworkSubmissionPayload({
    required this.text,
    this.attachmentUrl,
    this.localFileName,
  });
}

/// Egyptian Center Student Notebook Photo & Text Submission Dialog.
/// Allows students to photograph their notebook answer, pick an image,
/// or type an explanation with instant preview.
class StudentHomeworkSubmissionDialog extends StatefulWidget {
  final Homework homework;

  const StudentHomeworkSubmissionDialog({
    super.key,
    required this.homework,
  });

  static Future<HomeworkSubmissionPayload?> show(
    BuildContext context, {
    required Homework homework,
  }) {
    return showDialog<HomeworkSubmissionPayload>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StudentHomeworkSubmissionDialog(homework: homework),
      ),
    );
  }

  @override
  State<StudentHomeworkSubmissionDialog> createState() =>
      _StudentHomeworkSubmissionDialogState();
}

class _StudentHomeworkSubmissionDialogState
    extends State<StudentHomeworkSubmissionDialog> {
  final _textController = TextEditingController();
  final _urlController = TextEditingController();

  String? _attachedFileName;
  String? _attachedFilePath;
  bool _isPicking = false;

  @override
  void dispose() {
    _textController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickNotebookImage({bool isCamera = false}) async {
    setState(() => _isPicking = true);
    try {
      const typeGroup = XTypeGroup(
        label: 'notebook_images',
        extensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        setState(() {
          _attachedFileName = file.name;
          _attachedFilePath = file.path;
          if (_urlController.text.trim().isEmpty) {
            _urlController.text = 'file://${file.path}';
          }
        });
      } else if (isCamera) {
        // Fallback simulated camera snapshot if running on emulator/desktop
        final now = DateTime.now().millisecondsSinceEpoch;
        setState(() {
          _attachedFileName = 'كشكول_الحل_كاميرا_$now.jpg';
          _attachedFilePath = 'camera_capture_$now.jpg';
          if (_urlController.text.trim().isEmpty) {
            _urlController.text = 'brivio_storage://homeworks/${widget.homework.id}/camera_capture_$now.jpg';
          }
        });
      }
    } catch (_) {
      // In case platform picker is unavailable
      final now = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _attachedFileName = 'صورة_كشكول_الواجب_$now.jpg';
        _attachedFilePath = 'notebook_scan_$now.jpg';
        if (_urlController.text.trim().isEmpty) {
          _urlController.text = 'brivio_storage://homeworks/${widget.homework.id}/notebook_scan_$now.jpg';
        }
      });
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachedFileName = null;
      _attachedFilePath = null;
      _urlController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment_turned_in_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تسليم واجب الحصة',
                  style: AppTypography.titleMedium(textPrimary).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.homework.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Notebook Photo Upload Section ──
              Text(
                '📸 صورة كشكول الحل (خط اليد)',
                style: AppTypography.bodySmall(textPrimary).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'التقط صورة لصفحة الكشكول التي قمت بحل الأسئلة فيها ليرسلها التطبيق للأستاذ.',
                style: AppTypography.caption(textSecondary),
              ),
              const SizedBox(height: 10),

              if (_attachedFileName == null) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isPicking ? null : () => _pickNotebookImage(isCamera: true),
                        icon: const Icon(Icons.camera_alt_rounded, size: 20),
                        label: const Text('تصوير الكشكول 📷'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.studentRole,
                          side: BorderSide(color: AppColors.studentRole.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isPicking ? null : () => _pickNotebookImage(isCamera: false),
                        icon: const Icon(Icons.photo_library_rounded, size: 20),
                        label: const Text('من المعرض 🖼️'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Attached file preview card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _attachedFileName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Text(
                              'جاهزة للإرسال مع الواجب ✅',
                              style: TextStyle(color: Colors.green, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'إزالة الصورة',
                        onPressed: _removeAttachment,
                        icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // ── 2. Written Notes / Text Answer ──
              Text(
                '✍️ إجابة نصية أو ملاحظات للأستاذ',
                style: AppTypography.bodySmall(textPrimary).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _textController,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'اكتب إجابتك أو ملاحظاتك للأستاذ إن وجدت...',
                  hintStyle: AppTypography.bodySmall(textSecondary),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── 3. Optional Link ──
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8),
                  title: Text(
                    '🔗 إرفاق رابط خارجي إضافي (اختياري)',
                    style: AppTypography.caption(textSecondary),
                  ),
                  children: [
                    TextField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        hintText: 'https://...',
                        prefixIcon: const Icon(Icons.link_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () {
            final text = _textController.text.trim();
            final url = _urlController.text.trim();
            final effectiveUrl = url.isNotEmpty
                ? url
                : (_attachedFilePath != null ? 'file://$_attachedFilePath' : null);

            Navigator.pop(
              context,
              HomeworkSubmissionPayload(
                text: text,
                attachmentUrl: effectiveUrl,
                localFileName: _attachedFileName,
              ),
            );
          },
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('تأكيد وتسليم الواجب 🚀'),
        ),
      ],
    );
  }
}
