import 'package:flutter/material.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import 'interactive_seat_allocation_dialog.dart';

class ClassroomCapacityScreen extends StatefulWidget {
  final String centerName;

  const ClassroomCapacityScreen({
    super.key,
    this.centerName = 'سنتر الأوائل التعليمي',
  });

  @override
  State<ClassroomCapacityScreen> createState() => _ClassroomCapacityScreenState();
}

class _ClassroomCapacityScreenState extends State<ClassroomCapacityScreen> {
  final List<Map<String, dynamic>> _halls = [
    {
      'id': 'hall-1',
      'name': 'قاعة 1 (المسرح الكبير)',
      'floor': 'الطابق الأرضي',
      'capacity': 100,
      'occupied': 92,
      'current_session': 'فيزياء ثانوية عامة - أ. محمد عبد الله',
      'time': '10:00 ص - 12:00 م',
      'air_conditioned': true,
    },
    {
      'id': 'hall-2',
      'name': 'قاعة 2 (مدرج المتفوقين)',
      'floor': 'الطابق الأول',
      'capacity': 70,
      'occupied': 45,
      'current_session': 'رياضيات بحتة - أ. أحمد الشناوي',
      'time': '11:00 ص - 01:00 م',
      'air_conditioned': true,
    },
    {
      'id': 'hall-3',
      'name': 'قاعة 3 (معمل اللغات)',
      'floor': 'الطابق الثاني',
      'capacity': 40,
      'occupied': 39, // 97.5% - Over capacity warning!
      'current_session': 'لغة إنجليزية لغات - Miss Sarah',
      'time': '12:00 م - 02:00 م',
      'air_conditioned': true,
    },
    {
      'id': 'hall-4',
      'name': 'قاعة 4 (القاعة الفرعية)',
      'floor': 'الطابق الأرضي',
      'capacity': 50,
      'occupied': 0, // Empty / Idle
      'current_session': null,
      'time': 'شاغرة حالياً',
      'air_conditioned': false,
    },
  ];

  void _editCapacityDialog(Map<String, dynamic> hall) {
    final capCtrl = TextEditingController(text: '${hall['capacity']}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل سعة مقاعد ${hall['name']}'),
        content: TextField(
          controller: capCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'الحد الأقصى لعدد المقاعد'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final newCap = int.tryParse(capCtrl.text.trim());
              if (newCap != null && newCap > 0) {
                setState(() => hall['capacity'] = newCap);
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    int totalCapacity = 0;
    int totalOccupied = 0;
    for (final h in _halls) {
      totalCapacity += (h['capacity'] as int);
      totalOccupied += (h['occupied'] as int);
    }
    final overallRate = totalCapacity > 0 ? (totalOccupied / totalCapacity) * 100 : 0.0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('إدارة مقاعد وسعة القاعات 🏛️'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Center Capacity Overview Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade800, Colors.blueGrey.shade900],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إجمالي سعة السنتر: ${widget.centerName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${overallRate.toStringAsFixed(0)}% إشغال كلي',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryMetric('إجمالي المقاعد', '$totalCapacity مقعد', Colors.white),
                      _buildSummaryMetric('الطلاب الحاضرون الآن', '$totalOccupied طالب', Colors.amberAccent),
                      _buildSummaryMetric('المقاعد الشاغرة', '${totalCapacity - totalOccupied} مقعد', Colors.greenAccent),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'القاعات الدراسية (${_halls.length})',
              style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            ..._halls.map((hall) {
              final cap = hall['capacity'] as int;
              final occ = hall['occupied'] as int;
              final rate = cap > 0 ? (occ / cap) * 100 : 0.0;
              final isNearFull = rate >= 90.0;
              final isIdle = occ == 0;

              Color statusColor;
              String statusLabel;

              if (isIdle) {
                statusColor = Colors.grey;
                statusLabel = 'شاغرة حالياً';
              } else if (isNearFull) {
                statusColor = Colors.red;
                statusLabel = 'مكتملة تقريباً ⚠️';
              } else if (rate >= 70) {
                statusColor = Colors.orange;
                statusLabel = 'إشغال مرتفع';
              } else {
                statusColor = Colors.green;
                statusLabel = 'سعة متوفرة';
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderColor: isNearFull ? Colors.red.withValues(alpha: 0.4) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.meeting_room_rounded, color: statusColor),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hall['name'],
                                    style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${hall['floor']} • ${hall['air_conditioned'] ? 'مكيفة ❄️' : 'مراوح'}',
                                    style: AppTypography.caption(textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Session detail if active
                      if (hall['current_session'] != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cast_for_education_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'الحصة الجارية: ${hall['current_session']}',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textPrimary),
                                ),
                              ),
                              Text(
                                hall['time'],
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Seats progress bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المقاعد المشغولة: $occ من $cap مقعد',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                          Text(
                            '${rate.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: cap > 0 ? occ / cap : 0,
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        borderRadius: BorderRadius.circular(6),
                        minHeight: 7,
                      ),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () {
                              InteractiveSeatAllocationDialog.show(
                                context,
                                centerName: widget.centerName,
                                hallName: hall['name'] as String,
                                capacity: cap,
                                currentSession: hall['current_session'] as String?,
                              );
                            },
                            icon: const Icon(Icons.event_seat_rounded, size: 16),
                            label: const Text('تسكين المقاعد والديسكات 🏷️'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _editCapacityDialog(hall),
                            icon: const Icon(Icons.tune_rounded, size: 16),
                            label: const Text('تعديل السعة'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
