import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../design_system/tokens/colors.dart';

/// Modern Student Digital Center ID Card with dynamic QR Code for instant gate scanning.
class StudentDigitalIdCard extends StatelessWidget {
  final String studentName;
  final String studentCode;
  final String? gradeLevel;
  final String centerName;
  final String? centerCode;

  const StudentDigitalIdCard({
    super.key,
    required this.studentName,
    required this.studentCode,
    this.gradeLevel,
    this.centerName = 'السنتر التعليمي',
    this.centerCode,
  });

  static void show(
    BuildContext context, {
    required String studentName,
    required String studentCode,
    String? gradeLevel,
    String centerName = 'السنتر التعليمي',
    String? centerCode,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: StudentDigitalIdCard(
          studentName: studentName,
          studentCode: studentCode,
          gradeLevel: gradeLevel,
          centerName: centerName,
          centerCode: centerCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        centerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'بطاقة طالب',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // QR Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: studentCode,
                      version: QrVersions.auto,
                      size: 180,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Student Name
                  Text(
                    studentName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Code Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'كود الطالب: $studentCode',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  if (gradeLevel != null && gradeLevel!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      gradeLevel!,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Text(
                    'أظهر هذا الكود لموظف الاستقبال عند دخول السنتر لتسجيل حضورك في ثانية واحدة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white30),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: studentCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم نسخ كود الطالب!'),
                              backgroundColor: Colors.black87,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('نسخ الكود'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إغلاق'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
