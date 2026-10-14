import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

/// Screen to view protected course materials with a continuous, dynamic security watermark
/// to prevent unauthorized re-distribution and camera piracy in Egyptian educational centers.
class WatermarkedMaterialViewer extends StatelessWidget {
  final String title;
  final String subjectName;
  final String teacherName;
  final String studentName;
  final String studentCode;
  final String studentPhone;
  final String centerName;
  final List<String>? samplePages;

  const WatermarkedMaterialViewer({
    super.key,
    required this.title,
    required this.subjectName,
    required this.teacherName,
    required this.studentName,
    required this.studentCode,
    required this.studentPhone,
    this.centerName = 'سنتر الأوائل التعليمي',
    this.samplePages,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final watermarkText = '$studentName • $studentCode • $studentPhone • $centerName';

    final pages = samplePages ?? [
      'مقدمة الفصل الدراسي: القوانين الأساسية والملاحظات الهامة...',
      'القسم الأول: استنتاج المعادلات والتطبيقات المباشرة في الامتحانات...',
      'القسم الثاني: مسائل وتدريبات الفائقين ونماذج السنوات السابقة...',
    ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(
              '$subjectName • الأستاذ: $teacherName',
              style: TextStyle(fontSize: 11, color: textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'حماية المذكرة مفعلة',
            icon: const Icon(Icons.security_rounded, color: Colors.green),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('المذكرة محمية بعلامة مائية رقمية مخصصة بحسابك لمنع التسريب.'),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Content pages
          ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: pages.length,
            itemBuilder: (context, idx) {
              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(24),
                constraints: const BoxConstraints(minHeight: 480),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header of page
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$subjectName - $title',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        Text(
                          'صفحة ${idx + 1} من ${pages.length}',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    const SizedBox(height: 10),
                    Text(
                      pages[idx],
                      style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '١. شرح المفاهيم الأساسية وتوضيح نقاط الربط بين الوحدات.\n'
                      '٢. التركيز على أسئلة المستويات العليا ونماذج الوزارة.\n'
                      '٣. أمثلة محلولة بالخطوات النموذجية الكاملة.\n'
                      '٤. واجب تطبيقي يسلّم في الحصة القادمة.',
                      style: AppTypography.bodyMedium(textPrimary).copyWith(height: 1.8),
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 20),
                    Center(
                      child: Text(
                        'سنتر $centerName • جميع الحقوق محفوظة للأستاذ $teacherName',
                        style: TextStyle(fontSize: 10, color: textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Security Watermark Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.12,
                child: CustomPaint(
                  painter: _WatermarkPainter(watermarkText: watermarkText),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  final String watermarkText;

  _WatermarkPainter({required this.watermarkText});

  @override
  void paint(Canvas canvas, Size size) {
    const textStyle = TextStyle(
      color: Colors.black,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: watermarkText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.rtl,
    );
    textPainter.layout();

    const double stepX = 260.0;
    const double stepY = 180.0;

    for (double y = -50; y < size.height + 100; y += stepY) {
      for (double x = -100; x < size.width + 100; x += stepX) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-math.pi / 6); // -30 degrees
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
