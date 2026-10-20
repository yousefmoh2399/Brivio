import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import 'interactive_seat_allocation_dialog.dart';

class ClassroomCapacityScreen extends StatefulWidget {
  final String centerName;

  const ClassroomCapacityScreen({
    super.key,
    this.centerName = 'المركز التعليمي',
  });

  @override
  State<ClassroomCapacityScreen> createState() => _ClassroomCapacityScreenState();
}

class _ClassroomCapacityScreenState extends State<ClassroomCapacityScreen> {
  List<Map<String, dynamic>> _halls = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHalls();
  }

  Future<void> _loadHalls() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      String? centerId;
      if (userId != null) {
        final prof = await client
            .from('profiles')
            .select('center_id')
            .eq('id', userId)
            .maybeSingle();
        centerId = prof?['center_id'] as String?;
      }

      List<dynamic> res;
      if (centerId != null) {
        final bRes = await client
            .from('branches')
            .select('id')
            .eq('center_id', centerId);
        final bIds = (bRes as List)
            .map((b) => b['id']?.toString())
            .whereType<String>()
            .toList();
        if (bIds.isNotEmpty) {
          try {
            res = await client
                .from('rooms')
                .select('id, name, code, capacity, status, branch_id, seat_allocations')
                .inFilter('branch_id', bIds)
                .order('name');
          } catch (_) {
            res = await client
                .from('rooms')
                .select('id, name, code, capacity, status, branch_id')
                .inFilter('branch_id', bIds)
                .order('name');
          }
        } else {
          res = [];
        }
      } else {
        try {
          res = await client
              .from('rooms')
              .select('id, name, code, capacity, status, branch_id, seat_allocations')
              .order('name');
        } catch (_) {
          res = await client
              .from('rooms')
              .select('id, name, code, capacity, status, branch_id')
              .order('name');
        }
      }

      // Fetch today's class sessions
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];
      List<dynamic> sessionsRes = [];
      try {
        sessionsRes = await client
            .from('class_sessions')
            .select('id, location, scheduled_start_at, scheduled_end_at, group_id, groups(name, code, max_capacity)')
            .eq('session_date', todayStr);
      } catch (_) {}

      // Collect session IDs to query attendance for actual live headcount
      final activeSessionIds = sessionsRes
          .map((s) => s['id']?.toString())
          .whereType<String>()
          .toList();

      Map<String, int> sessionHeadcounts = {};
      if (activeSessionIds.isNotEmpty) {
        try {
          final attRes = await client
              .from('attendance_records')
              .select('session_id')
              .inFilter('session_id', activeSessionIds)
              .eq('attendance_status', 'present');
          for (final row in (attRes as List)) {
            final sid = row['session_id']?.toString();
            if (sid != null) {
              sessionHeadcounts[sid] = (sessionHeadcounts[sid] ?? 0) + 1;
            }
          }
        } catch (_) {}
      }

      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> loaded = [];
      for (final item in res) {
        final roomId = item['id'] as String;
        final roomName = item['name'] as String? ?? 'قاعة بدون اسم';
        final roomCode = item['code'] as String?;

        // Check if there is an active session for this room right now or today
        Map<String, dynamic>? activeSession;
        for (final s in sessionsRes) {
          final loc = s['location']?.toString();
          if (loc != null &&
              (loc == roomId ||
               loc.trim().toLowerCase() == roomName.trim().toLowerCase() ||
               (roomCode != null && loc.trim().toLowerCase() == roomCode.trim().toLowerCase()))) {
            final start = DateTime.tryParse(s['scheduled_start_at']?.toString() ?? '')?.toLocal();
            final end = DateTime.tryParse(s['scheduled_end_at']?.toString() ?? '')?.toLocal();
            if (start != null && end != null && now.isAfter(start.subtract(const Duration(minutes: 15))) && now.isBefore(end.add(const Duration(minutes: 15)))) {
              activeSession = Map<String, dynamic>.from(s as Map);
              break;
            } else {
              activeSession ??= Map<String, dynamic>.from(s as Map);
            }
          }
        }

        int occupiedCount = 0;
        String? groupName;
        String timeLabel = 'شاغرة حالياً';

        if (activeSession != null) {
          final sid = activeSession['id']?.toString();
          occupiedCount = sid != null ? (sessionHeadcounts[sid] ?? 0) : 0;
          final grp = activeSession['groups'] as Map<String, dynamic>?;
          groupName = grp?['name']?.toString() ?? 'مجموعة دراسية';

          final start = DateTime.tryParse(activeSession['scheduled_start_at']?.toString() ?? '')?.toLocal();
          final end = DateTime.tryParse(activeSession['scheduled_end_at']?.toString() ?? '')?.toLocal();
          if (start != null && end != null) {
            timeLabel = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
          } else {
            timeLabel = 'محاضرة اليوم';
          }
        }

        // Count seated students from Supabase seat_allocations or local cache
        int seatedCount = 0;
        final dbAlloc = item['seat_allocations'];
        if (dbAlloc is Map) {
          seatedCount = dbAlloc.length;
        } else if (dbAlloc is List) {
          seatedCount = dbAlloc.length;
        }

        final localAllocStr = prefs.getString('room_seat_allocations_$roomId') ??
            prefs.getString('room_seat_allocations_$roomName');
        if (localAllocStr != null && localAllocStr.isNotEmpty) {
          try {
            final decoded = jsonDecode(localAllocStr);
            if (decoded is Map && decoded.length > seatedCount) {
              seatedCount = decoded.length;
            }
          } catch (_) {}
        }

        if (seatedCount > occupiedCount) {
          occupiedCount = seatedCount;
        }

        loaded.add({
          'id': roomId,
          'name': roomName,
          'floor': roomCode != null ? 'كود: $roomCode' : 'الطابق الأرضي',
          'capacity': (item['capacity'] as num?)?.toInt() ?? 30,
          'occupied': occupiedCount,
          'current_session': groupName,
          'time': timeLabel,
          'air_conditioned': true,
        });
      }
      if (mounted) {
        setState(() {
          _halls = loaded;
        });
      }
    } catch (_) {
      // If table query fails, _halls remains empty
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddHallDialog() async {
    final nameCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '40');
    final codeCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.down,
        title: const Text('إضافة قاعة دراسية جديدة'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width.clamp(280.0, 480.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم القاعة / المدرج *',
                    hintText: 'مثال: قاعة 1، مدرج أ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: capCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'السعة القصوى (عدد المقاعد) *',
                    hintText: '40',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'كود القاعة (اختياري)',
                    hintText: 'مثال: R-101',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final cap = int.tryParse(capCtrl.text.trim()) ?? 30;
              final code = codeCtrl.text.trim().isNotEmpty
                  ? codeCtrl.text.trim()
                  : 'RM-${DateTime.now().millisecondsSinceEpoch % 10000}';
              if (name.isEmpty) return;

              try {
                final client = Supabase.instance.client;
                final userId = client.auth.currentUser?.id;
                String? centerId;
                if (userId != null) {
                  final prof = await client
                      .from('profiles')
                      .select('center_id')
                      .eq('id', userId)
                      .maybeSingle();
                  centerId = prof?['center_id'] as String?;
                }

                var bQuery = client.from('branches').select('id');
                if (centerId != null) {
                  bQuery = bQuery.eq('center_id', centerId);
                }
                final branchRes = await bQuery.limit(1);

                String? branchId;
                if ((branchRes as List).isNotEmpty) {
                  branchId = branchRes.first['id'] as String;
                } else {
                  final newBranch = await client.from('branches').insert({
                    'name': 'الفرع الرئيسي',
                    'code': 'MAIN-01',
                    'status': 'active',
                    if (centerId != null) 'center_id': centerId,
                  }).select('id').single();
                  branchId = newBranch['id'] as String;
                }

                await client.from('rooms').insert({
                  'name': name,
                  'capacity': cap,
                  'code': code,
                  'branch_id': branchId,
                  'status': 'active',
                });

                if (mounted) {
                  Navigator.pop(ctx);
                  _loadHalls();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل إضافة القاعة: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _editCapacityDialog(Map<String, dynamic> hall) async {
    final capCtrl = TextEditingController(text: '${hall['capacity']}');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsOverflowDirection: VerticalDirection.down,
        title: Text('تعديل سعة مقاعد ${hall['name']}'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width.clamp(280.0, 420.0),
          child: TextField(
            controller: capCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الحد الأقصى لعدد المقاعد'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final newCap = int.tryParse(capCtrl.text.trim());
              if (newCap != null && newCap > 0) {
                try {
                  final client = Supabase.instance.client;
                  await client.from('rooms').update({'capacity': newCap}).eq('id', hall['id']);
                  setState(() => hall['capacity'] = newCap);
                  if (mounted) Navigator.pop(ctx);
                } catch (_) {
                  setState(() => hall['capacity'] = newCap);
                  if (mounted) Navigator.pop(ctx);
                }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'إضافة قاعة جديدة',
            onPressed: _showAddHallDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadHalls,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHalls,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                              Expanded(
                                child: Text(
                                  'إجمالي سعة السنتر: ${widget.centerName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
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
                              Expanded(child: _buildSummaryMetric('إجمالي المقاعد', '$totalCapacity مقعد', Colors.white)),
                              Expanded(child: _buildSummaryMetric('الطلاب الحاضرون الآن', '$totalOccupied طالب', Colors.amberAccent)),
                              Expanded(child: _buildSummaryMetric('المقاعد الشاغرة', '${totalCapacity - totalOccupied} مقعد', Colors.greenAccent)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'القاعات الدراسية (${_halls.length})',
                          style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: _showAddHallDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('قاعة جديدة'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_halls.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.meeting_room_outlined, size: 56, color: textSecondary),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد قاعات مضافة حالياً',
                              style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'أضف قاعات ومدرجات السنتر وحدد السعة الاستيعابية لكل قاعة لتنظيم الحضور والمقاعد.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySmall(textSecondary),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _showAddHallDialog,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('إضافة أول قاعة'),
                            ),
                          ],
                        ),
                      )
                    else
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
                                    Expanded(
                                      child: Row(
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
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  hall['name'],
                                                  style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  hall['floor'],
                                                  style: AppTypography.caption(textSecondary),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
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

                                Wrap(
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.tonalIcon(
                                      onPressed: () async {
                                        await InteractiveSeatAllocationDialog.show(
                                          context,
                                          roomId: hall['id'] as String?,
                                          centerName: widget.centerName,
                                          hallName: hall['name'] as String,
                                          capacity: cap,
                                          currentSession: hall['current_session'] as String?,
                                          onSaved: _loadHalls,
                                        );
                                        _loadHalls();
                                      },
                                      icon: const Icon(Icons.event_seat_rounded, size: 16),
                                      label: const Text('تسكين المقاعد والديسكات 🏷️'),
                                    ),
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
