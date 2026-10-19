import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../design_system/tokens/colors.dart';

enum ReceiptType { studentPayment, teacherSettlement }

/// High-fidelity electronic cash receipt card for Students, Parents, and Teachers.
class DigitalCashReceiptDialog extends StatelessWidget {
  final ReceiptType receiptType;
  final String centerName;
  final String receiptNumber;
  final String dateStr;
  final String recipientName;
  final String? studentCode;
  final String groupName;
  final double amount;
  final String paymentPurpose;
  final String? parentOrTeacherPhone;
  final String paymentMethod;
  final String? invoiceNumber;
  final String? transactionId;
  final String? notes;

  // Teacher settlement specific fields
  final int? studentCount;
  final double? sessionPrice;
  final double? totalRevenue;
  final double? teacherPercent;
  final double? centerShare;
  final double? deductions;
  final String? deductionReason;
  final int? bookletsSold;
  final double? bookletRevenue;

  const DigitalCashReceiptDialog({
    super.key,
    required this.receiptType,
    required this.centerName,
    required this.receiptNumber,
    required this.dateStr,
    required this.recipientName,
    this.studentCode,
    required this.groupName,
    required this.amount,
    required this.paymentPurpose,
    this.parentOrTeacherPhone,
    this.paymentMethod = 'نقداً بالخزينة (كاش) 💵',
    this.invoiceNumber,
    this.transactionId,
    this.notes,
    this.studentCount,
    this.sessionPrice,
    this.totalRevenue,
    this.teacherPercent,
    this.centerShare,
    this.deductions,
    this.deductionReason,
    this.bookletsSold,
    this.bookletRevenue,
  });

  static Future<void> show({
    required BuildContext context,
    required ReceiptType receiptType,
    required String centerName,
    required String receiptNumber,
    required String dateStr,
    required String recipientName,
    String? studentCode,
    required String groupName,
    required double amount,
    required String paymentPurpose,
    String? parentOrTeacherPhone,
    String paymentMethod = 'نقداً بالخزينة (كاش) 💵',
    String? invoiceNumber,
    String? transactionId,
    String? notes,
    int? studentCount,
    double? sessionPrice,
    double? totalRevenue,
    double? teacherPercent,
    double? centerShare,
    double? deductions,
    String? deductionReason,
    int? bookletsSold,
    double? bookletRevenue,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DigitalCashReceiptDialog(
        receiptType: receiptType,
        centerName: centerName,
        receiptNumber: receiptNumber,
        dateStr: dateStr,
        recipientName: recipientName,
        studentCode: studentCode,
        groupName: groupName,
        amount: amount,
        paymentPurpose: paymentPurpose,
        parentOrTeacherPhone: parentOrTeacherPhone,
        paymentMethod: paymentMethod,
        invoiceNumber: invoiceNumber,
        transactionId: transactionId,
        notes: notes,
        studentCount: studentCount,
        sessionPrice: sessionPrice,
        totalRevenue: totalRevenue,
        teacherPercent: teacherPercent,
        centerShare: centerShare,
        deductions: deductions,
        deductionReason: deductionReason,
        bookletsSold: bookletsSold,
        bookletRevenue: bookletRevenue,
      ),
    );
  }

  Future<void> _handlePrint() async {
    final reportService = getIt.isRegistered<ReportGeneratorService>()
        ? getIt<ReportGeneratorService>()
        : ReportGeneratorService();
    if (receiptType == ReceiptType.teacherSettlement) {
      await reportService.generateTeacherSettlementReceiptPdf(
        centerName: centerName,
        receiptNumber: receiptNumber,
        teacherName: recipientName,
        groupName: groupName,
        dateStr: dateStr,
        studentCount: studentCount ?? 0,
        sessionPrice: sessionPrice ?? 0.0,
        totalRevenue: totalRevenue ?? 0.0,
        teacherPercent: teacherPercent ?? 70.0,
        teacherShare: amount + (deductions ?? 0.0),
        centerShare: centerShare ?? 0.0,
        deductions: deductions ?? 0.0,
        deductionReason: deductionReason ?? 'مصاريف وقاعات',
        netPayout: amount,
        bookletsSold: bookletsSold ?? 0,
        bookletRevenue: bookletRevenue ?? 0.0,
        printDirectly: true,
      );
    } else {
      await reportService.generateStudentCashReceiptPdf(
        centerName: centerName,
        receiptNumber: receiptNumber,
        studentName: recipientName,
        studentCode: studentCode ?? 'STU-001',
        groupName: groupName,
        amount: amount,
        purpose: paymentPurpose,
        dateStr: dateStr,
        printDirectly: true,
      );
    }
  }

  Future<void> _handleSharePdf() async {
    final reportService = getIt.isRegistered<ReportGeneratorService>()
        ? getIt<ReportGeneratorService>()
        : ReportGeneratorService();
    if (receiptType == ReceiptType.teacherSettlement) {
      await reportService.generateTeacherSettlementReceiptPdf(
        centerName: centerName,
        receiptNumber: receiptNumber,
        teacherName: recipientName,
        groupName: groupName,
        dateStr: dateStr,
        studentCount: studentCount ?? 0,
        sessionPrice: sessionPrice ?? 0.0,
        totalRevenue: totalRevenue ?? 0.0,
        teacherPercent: teacherPercent ?? 70.0,
        teacherShare: amount + (deductions ?? 0.0),
        centerShare: centerShare ?? 0.0,
        deductions: deductions ?? 0.0,
        deductionReason: deductionReason ?? 'مصاريف وقاعات',
        netPayout: amount,
        bookletsSold: bookletsSold ?? 0,
        bookletRevenue: bookletRevenue ?? 0.0,
        printDirectly: false,
      );
    } else {
      await reportService.generateStudentCashReceiptPdf(
        centerName: centerName,
        receiptNumber: receiptNumber,
        studentName: recipientName,
        studentCode: studentCode ?? 'STU-001',
        groupName: groupName,
        amount: amount,
        purpose: paymentPurpose,
        dateStr: dateStr,
        printDirectly: false,
      );
    }
  }

  void _handleSendWhatsApp(BuildContext context) {
    if (parentOrTeacherPhone == null || parentOrTeacherPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم الهاتف غير متوفر لإرسال الواتساب')),
      );
      return;
    }

    String message;
    if (receiptType == ReceiptType.teacherSettlement) {
      final bookletInfo = (bookletsSold ?? 0) > 0
          ? '\n📚 مبيعات الملازم: $bookletsSold نسخة (${(bookletRevenue ?? 0).toStringAsFixed(1)} ج.م)'
          : '';
      message = '''
🧾 *إيصال تصفية حساب حصة مدرس (نقداً)*
🏫 سنتر: *$centerName*
━━━━━━━━━━━━━━━━━━
رقم الإيصال: *$receiptNumber*
التاريخ: $dateStr
👤 الأستاذ/ة: *$recipientName*
📚 المجموعة: *$groupName*
👥 الحضور: ${studentCount ?? 0} طالب
💵 سعر الحصة: ${sessionPrice ?? 0} ج.م$bookletInfo
💰 إجمالي الدخل الكلي: ${(totalRevenue ?? 0).toStringAsFixed(1)} ج.م
📊 نسبة المدرس: ${(teacherPercent ?? 70).toStringAsFixed(0)}%
✂️ استقطاعات: -${(deductions ?? 0).toStringAsFixed(1)} ج.م ($deductionReason)
━━━━━━━━━━━━━━━━━━
💵 *الصافي المنصرف نقداً (كاش): ${amount.toStringAsFixed(1)} ج.م*
خالص ومسدد بالكامل من خزينة السنتر ✔️
'''.trim();
    } else {
      final invText = (invoiceNumber != null && invoiceNumber!.isNotEmpty) ? '\n🧾 رقم الفاتورة: $invoiceNumber' : '';
      final txText = (transactionId != null && transactionId!.isNotEmpty) ? '\n🔢 رقم المرجع: $transactionId' : '';
      message = '''
🧾 *إيصال سداد رسمي معتمد*
🏫 سنتر: *$centerName*
━━━━━━━━━━━━━━━━━━
رقم الإيصال: *$receiptNumber*
التاريخ: $dateStr
👤 اسم الطالب: *$recipientName*${studentCode != null && studentCode!.isNotEmpty ? ' (كود: $studentCode)' : ''}
📚 المجموعة / الاشتراك: *$groupName*
📋 البيان: *$paymentPurpose*$invText$txText
💵 *المبلغ المسدد: ${amount.toStringAsFixed(1)} ج.م*
طريقة السداد: $paymentMethod
━━━━━━━━━━━━━━━━━━
خالص ومسدد ومعتمد رسمياً ✔️
شكرًا لتعاونكم مع إدارة السنتر
'''.trim();
    }

    WhatsAppService.sendCustomMessage(
      phone: parentOrTeacherPhone!,
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = receiptType == ReceiptType.teacherSettlement;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main Receipt Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Top Receipt Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isTeacher ? const Color(0xFF1E293B) : const Color(0xFF0F766E),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  centerName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isTeacher ? 'إيصال تصفية مستحقات مدرس' : 'إيصال استلام نقدية كاش رسمي',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isTeacher
                                  ? Colors.teal.shade300
                                  : (paymentMethod.contains('كاش') || paymentMethod.contains('نقداً')
                                      ? Colors.amber.shade400
                                      : const Color(0xFF10B981)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isTeacher
                                  ? 'تصفية'
                                  : (paymentMethod.contains('كاش') || paymentMethod.contains('نقداً')
                                      ? 'كاش'
                                      : (paymentMethod.contains('فوري')
                                          ? 'فوري'
                                          : (paymentMethod.contains('إنستا') || paymentMethod.contains('Insta')
                                              ? 'InstaPay'
                                              : 'معتمد'))),
                              style: TextStyle(
                                color: (paymentMethod.contains('كاش') || paymentMethod.contains('نقداً'))
                                    ? const Color(0xFF451A03)
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Receipt Info Strip
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('رقم الإيصال', style: TextStyle(color: Colors.grey, fontSize: 11)),
                              Text(receiptNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('التاريخ والوقت', style: TextStyle(color: Colors.grey, fontSize: 11)),
                              Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, indent: 20, endIndent: 20),

                    // Body Rows
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            isTeacher ? 'اسم المدرس' : 'اسم الطالب',
                            recipientName,
                            subtitle: studentCode != null ? 'كود: $studentCode' : null,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow('المجموعة / الحصة', groupName),
                          const SizedBox(height: 12),
                          _buildDetailRow('البيان والغرض', paymentPurpose),
                          const SizedBox(height: 12),
                          _buildDetailRow('طريقة السداد', paymentMethod),
                          if (invoiceNumber != null && invoiceNumber!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow('رقم الفاتورة المرجعية', invoiceNumber!),
                          ],
                          if (transactionId != null && transactionId!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow('رقم المعاملة / المرجع', transactionId!),
                          ],

                          if (isTeacher && studentCount != null) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow('عدد الحضور', '$studentCount طالب'),
                            if ((bookletsSold ?? 0) > 0) ...[
                              const SizedBox(height: 12),
                              _buildDetailRow('مبيعات الملازم والمذكرات', '$bookletsSold نسخة (${bookletRevenue?.toStringAsFixed(1)} ج.م) 📚'),
                            ],
                            const SizedBox(height: 12),
                            _buildDetailRow('إجمالي الدخل الكلي', '${totalRevenue?.toStringAsFixed(1)} ج.م'),
                            if ((deductions ?? 0) > 0) ...[
                              const SizedBox(height: 12),
                              _buildDetailRow('الاستقطاعات ($deductionReason)', '-${deductions?.toStringAsFixed(1)} ج.م'),
                            ],
                          ],

                          const SizedBox(height: 16),

                          // Total Amount Box
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isTeacher ? 'الصافي المنصرف نقداً:' : 'المبلغ المستلم كاش:',
                                  style: const TextStyle(
                                    color: Color(0xFF166534),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${amount.toStringAsFixed(1)} ج.م',
                                  style: const TextStyle(
                                    color: Color(0xFF15803D),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Stamp & Verified Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.green.shade700, width: 1.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'خالص السداد نقداً ✔️',
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const Text(
                                'ختم خزينة السنتر المعتمد',
                                style: TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _handleSendWhatsApp(context),
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('إرسال واتساب'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _handlePrint,
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('طباعة PDF'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    tooltip: 'مشاركة PDF',
                    onPressed: _handleSharePdf,
                    icon: const Icon(Icons.share_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق الإيصال', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {String? subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
          ],
        ),
      ],
    );
  }
}
