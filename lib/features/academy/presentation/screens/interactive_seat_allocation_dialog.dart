import 'package:flutter/material.dart';

import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class InteractiveSeatAllocationDialog extends StatefulWidget {
  final String centerName;
  final String hallName;
  final int capacity;
  final String? currentSession;

  const InteractiveSeatAllocationDialog({
    super.key,
    required this.centerName,
    required this.hallName,
    required this.capacity,
    this.currentSession,
  });

  static Future<void> show(
    BuildContext context, {
    required String centerName,
    required String hallName,
    required int capacity,
    String? currentSession,
  }) {
    return showDialog(
      context: context,
      builder: (_) => InteractiveSeatAllocationDialog(
        centerName: centerName,
        hallName: hallName,
        capacity: capacity,
        currentSession: currentSession,
      ),
    );
  }

  @override
  State<InteractiveSeatAllocationDialog> createState() => _InteractiveSeatAllocationDialogState();
}

class _InteractiveSeatAllocationDialogState extends State<InteractiveSeatAllocationDialog> {
  late final Map<int, Map<String, dynamic>> _seats;
  bool _isGeneratingPdf = false;
  final String _groupName = 'ثانوية عامة - فيزياء A';
  final String _teacherName = 'أ. محمد عبد الله';

  final List<Map<String, dynamic>> _availableStudents = [
    {'name': 'عمر أحمد محمود', 'code': 'STU-101', 'phone': '01012345678'},
    {'name': 'مريم طارق سالم', 'code': 'STU-102', 'phone': '01123456789'},
    {'name': 'يوسف كريم عز الدين', 'code': 'STU-103', 'phone': '01234567890'},
    {'name': 'نورهان سعيد كمال', 'code': 'STU-104', 'phone': '01512345678'},
    {'name': 'خالد مصطفى بدر', 'code': 'STU-105', 'phone': '01099887766'},
    {'name': 'حبيبة وائل شريف', 'code': 'STU-106', 'phone': '01188776655'},
    {'name': 'أحمد هاني حسني', 'code': 'STU-107', 'phone': '01277665544'},
    {'name': 'سارة إبراهيم عادل', 'code': 'STU-108', 'phone': '01066554433'},
    {'name': 'علي حسن توفيق', 'code': 'STU-109', 'phone': '01155443322'},
    {'name': 'فاطمة محمود خليل', 'code': 'STU-110', 'phone': '01244332211'},
  ];

  @override
  void initState() {
    super.initState();
    _seats = {};

    // Pre-populate some seats for realistic Egyptian center demonstration
    for (int i = 0; i < _availableStudents.length; i++) {
      final s = _availableStudents[i];
      _seats[i + 1] = {
        'seatNumber': i + 1,
        'studentName': s['name'],
        'studentCode': s['code'],
        'studentPhone': s['phone'],
        'notes': (i == 0) ? 'صف أول - ضعف نظر' : '',
      };
    }
  }

  Future<void> _exportDeskLabelsPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final allocations = <Map<String, dynamic>>[];
      final sortedKeys = _seats.keys.toList()..sort();
      for (final k in sortedKeys) {
        allocations.add(_seats[k]!);
      }

      final reportService = ReportGeneratorService();
      await reportService.generateSeatDeskLabelsPdf(
        centerName: widget.centerName,
        hallName: widget.hallName,
        groupName: _groupName,
        teacherName: _teacherName,
        seatAllocations: allocations,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم توليد كروت المقاعد والديسكات (PDF) بنجاح 🏷️✂️'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل توليد الكروت: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  void _onSeatTap(int seatNum) {
    final existing = _seats[seatNum];
    if (existing != null) {
      // Show unseat / details dialog
      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('المقعد رقم #$seatNum 🪑'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الطالب: ${existing['studentName']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('الكود: ${existing['studentCode']}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                Text('هاتف ولي الأمر: ${existing['studentPhone']}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                if ((existing['notes'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('ملاحظات: ${existing['notes']}', style: const TextStyle(fontSize: 12, color: Colors.deepOrange)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
              FilledButton.tonal(
                style: FilledButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  setState(() => _seats.remove(seatNum));
                  Navigator.pop(ctx);
                },
                child: const Text('إلغاء التسكين وإخلاء المقعد'),
              ),
            ],
          ),
        ),
      );
    } else {
      // Seat is empty: quick assign
      showModalBottomSheet(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تسكين طالب في المقعد رقم #$seatNum 🪑', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                const Text('اختر الطالب من القائمة المسجلة بالمجموعة:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: _availableStudents.length,
                    itemBuilder: (_, i) {
                      final s = _availableStudents[i];
                      final isAlreadySeated = _seats.values.any((item) => item['studentCode'] == s['code']);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isAlreadySeated ? Colors.grey : AppColors.primary,
                          child: Text(s['name'].toString().split(' ').first[0], style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(s['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isAlreadySeated ? Colors.grey : null)),
                        subtitle: Text('كود: ${s['code']}', style: const TextStyle(fontSize: 12)),
                        trailing: isAlreadySeated
                            ? const Text('مسكن بالفعل', style: TextStyle(fontSize: 11, color: Colors.grey))
                            : FilledButton(
                                onPressed: () {
                                  setState(() {
                                    _seats[seatNum] = {
                                      'seatNumber': seatNum,
                                      'studentName': s['name'],
                                      'studentCode': s['code'],
                                      'studentPhone': s['phone'],
                                      'notes': '',
                                    };
                                  });
                                  Navigator.pop(ctx);
                                },
                                child: const Text('تسكين'),
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _autoSeatRemaining() {
    int currentSeat = 1;
    for (final s in _availableStudents) {
      final isAlreadySeated = _seats.values.any((item) => item['studentCode'] == s['code']);
      if (!isAlreadySeated) {
        while (_seats.containsKey(currentSeat) && currentSeat <= widget.capacity) {
          currentSeat++;
        }
        if (currentSeat <= widget.capacity) {
          _seats[currentSeat] = {
            'seatNumber': currentSeat,
            'studentName': s['name'],
            'studentCode': s['code'],
            'studentPhone': s['phone'],
            'notes': '',
          };
        }
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final totalDisplaySeats = widget.capacity > 40 ? 40 : widget.capacity;
    final occupiedCount = _seats.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 820,
          height: 680,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.event_seat_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تسكين وتوزيع مقاعد: ${widget.hallName} 🏛️',
                            style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'المقاعد المسكنة: $occupiedCount من ${widget.capacity} مقعد • $_groupName',
                            style: TextStyle(fontSize: 12, color: textSecondary),
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
              const Divider(height: 20),

              // Action Toolbar
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _autoSeatRemaining,
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                        label: const Text('تسكين تلقائي للدفعة ⚡'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _seats.clear()),
                        icon: const Icon(Icons.clear_all_rounded, size: 16, color: Colors.red),
                        label: const Text('إخلاء المقاعد', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo.shade800,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isGeneratingPdf ? null : _exportDeskLabelsPdf,
                    icon: _isGeneratingPdf
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.print_rounded, size: 16),
                    label: const Text('طباعة استيكرات الديسكات (A4) 🖨️'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Teacher Podium / Front of Hall Indicator
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.co_present_rounded, size: 18, color: Colors.blueGrey),
                    SizedBox(width: 8),
                    Text(
                      'مقدمة القاعة • منصة شرح الأستاذ والسبورة الذكية 👨‍🏫',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Visual Seats Grid
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.45,
                    ),
                    itemCount: totalDisplaySeats,
                    itemBuilder: (context, idx) {
                      final seatNum = idx + 1;
                      final isOccupied = _seats.containsKey(seatNum);
                      final seatData = _seats[seatNum];

                      return InkWell(
                        onTap: () => _onSeatTap(seatNum),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isOccupied
                                ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isOccupied ? Colors.indigo.shade400 : Colors.green.withValues(alpha: 0.4),
                              width: isOccupied ? 1.5 : 1,
                              style: isOccupied ? BorderStyle.solid : BorderStyle.solid,
                            ),
                            boxShadow: isOccupied
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isOccupied ? Colors.indigo.shade900 : Colors.green.shade700,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#$seatNum',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                  Icon(
                                    isOccupied ? Icons.person_rounded : Icons.add_circle_outline_rounded,
                                    size: 16,
                                    color: isOccupied ? Colors.indigo : Colors.green,
                                  ),
                                ],
                              ),
                              if (isOccupied) ...[
                                Text(
                                  seatData?['studentName'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: textPrimary),
                                ),
                                Text(
                                  'كود: ${seatData?['studentCode']}',
                                  style: const TextStyle(fontSize: 9.5, color: Colors.grey),
                                ),
                              ] else ...[
                                const Center(
                                  child: Text(
                                    'مقعد شاغر\nاضغط للتسكين',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
