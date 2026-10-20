import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class InteractiveSeatAllocationDialog extends StatefulWidget {
  final String? roomId;
  final String centerName;
  final String hallName;
  final int capacity;
  final String? currentSession;
  final VoidCallback? onSaved;

  const InteractiveSeatAllocationDialog({
    super.key,
    this.roomId,
    required this.centerName,
    required this.hallName,
    required this.capacity,
    this.currentSession,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    String? roomId,
    required String centerName,
    required String hallName,
    required int capacity,
    String? currentSession,
    VoidCallback? onSaved,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => InteractiveSeatAllocationDialog(
        roomId: roomId,
        centerName: centerName,
        hallName: hallName,
        capacity: capacity,
        currentSession: currentSession,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<InteractiveSeatAllocationDialog> createState() => _InteractiveSeatAllocationDialogState();
}

class _InteractiveSeatAllocationDialogState extends State<InteractiveSeatAllocationDialog> {
  final Map<int, Map<String, dynamic>> _seats = {};
  bool _isGeneratingPdf = false;
  bool _isLoadingStudents = false;
  bool _isSaving = false;

  List<Map<String, dynamic>> _groups = [];
  String? _selectedGroupId; // null => All center students
  String? _selectedGroupName;

  final List<Map<String, dynamic>> _availableStudents = [];

  String get _currentBatchDisplay =>
      _selectedGroupName ?? widget.currentSession ?? 'جميع طلاب السنتر';

  int get _actualCapacity => widget.capacity > 0 ? widget.capacity : 40;

  @override
  void initState() {
    super.initState();
    _loadSavedSeats();
    _fetchGroups();
    _fetchStudents();
  }

  Future<void> _loadSavedSeats() async {
    try {
      // 1. Try to load from Supabase if roomId is given
      if (widget.roomId != null) {
        try {
          final client = Supabase.instance.client;
          final res = await client
              .from('rooms')
              .select('seat_allocations')
              .eq('id', widget.roomId!)
              .maybeSingle();

          if (res != null && res['seat_allocations'] != null) {
            final dynamic data = res['seat_allocations'];
            if (data is Map && data.isNotEmpty) {
              final loaded = <int, Map<String, dynamic>>{};
              data.forEach((k, v) {
                final seatNum = int.tryParse(k.toString());
                if (seatNum != null && v is Map) {
                  loaded[seatNum] = Map<String, dynamic>.from(v);
                }
              });
              if (loaded.isNotEmpty && mounted) {
                setState(() {
                  _seats.clear();
                  _seats.addAll(loaded);
                });
                return;
              }
            }
          }
        } catch (e) {
          debugPrint('Supabase room seat loading failed, checking local storage: $e');
        }
      }

      // 2. Fallback / check local SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final key = 'room_seat_allocations_${widget.roomId ?? widget.hallName}';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          final loaded = <int, Map<String, dynamic>>{};
          decoded.forEach((k, v) {
            final seatNum = int.tryParse(k.toString());
            if (seatNum != null && v is Map) {
              loaded[seatNum] = Map<String, dynamic>.from(v);
            }
          });
          if (mounted && loaded.isNotEmpty) {
            setState(() {
              _seats.clear();
              _seats.addAll(loaded);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading seat allocations: $e');
    }
  }

  Future<void> _saveSeats() async {
    setState(() => _isSaving = true);
    try {
      final key = 'room_seat_allocations_${widget.roomId ?? widget.hallName}';
      final stringKeyMap = <String, dynamic>{};
      _seats.forEach((k, v) => stringKeyMap[k.toString()] = v);
      final jsonStr = jsonEncode(stringKeyMap);

      // Save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonStr);

      // Save to Supabase if roomId is present
      if (widget.roomId != null) {
        try {
          final client = Supabase.instance.client;
          await client.from('rooms').update({
            'seat_allocations': stringKeyMap,
          }).eq('id', widget.roomId!);
        } catch (dbErr) {
          debugPrint('Could not update seat_allocations in rooms table: $dbErr');
        }
      }

      widget.onSaved?.call();
    } catch (e) {
      debugPrint('Error saving seat allocations: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _fetchGroups() async {
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('groups')
          .select('id, name, code')
          .order('name');

      if (mounted) {
        setState(() {
          _groups = List<Map<String, dynamic>>.from(res as List);
          // If currentSession matches a group name, pre-select it
          if (widget.currentSession != null && widget.currentSession!.isNotEmpty) {
            final match = _groups.firstWhere(
              (g) =>
                  (g['name'] ?? '').toString().trim() == widget.currentSession!.trim() ||
                  (g['name'] ?? '').toString().contains(widget.currentSession!.trim()),
              orElse: () => {},
            );
            if (match.isNotEmpty) {
              _selectedGroupId = match['id'] as String?;
              _selectedGroupName = match['name'] as String?;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching groups for seating: $e');
    }
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoadingStudents = true);
    final client = Supabase.instance.client;
    final list = <Map<String, dynamic>>[];

    try {
      // 1. If a specific group is selected, query group members
      if (_selectedGroupId != null) {
        try {
          final enrollRes = await client
              .from('enrollments')
              .select('student_id, students(id, student_code, profiles(full_name, phone_number))')
              .eq('group_id', _selectedGroupId!);

          for (final item in (enrollRes as List)) {
            final stu = item['students'] as Map<String, dynamic>?;
            if (stu != null) {
              final prof = stu['profiles'] as Map<String, dynamic>?;
              final name = (prof?['full_name'] as String?)?.trim();
              final code = stu['student_code'] as String? ?? 'N/A';
              final phone = prof?['phone_number'] as String? ?? '';
              final id = stu['id'] as String? ?? item['student_id'] as String? ?? '';
              if (name != null && name.isNotEmpty) {
                list.add({'id': id, 'name': name, 'code': code, 'phone': phone});
              }
            }
          }
        } catch (_) {}

        // Fallback: RPC get_group_students
        if (list.isEmpty) {
          try {
            final rpcRes = await client.rpc(
              'get_group_students',
              params: {'p_group_id': _selectedGroupId!},
            );
            if (rpcRes is List) {
              for (final item in rpcRes) {
                final m = Map<String, dynamic>.from(item as Map);
                final name = (m['full_name'] as String?)?.trim();
                if (name != null && name.isNotEmpty) {
                  list.add({
                    'id': m['id']?.toString() ?? '',
                    'name': name,
                    'code': m['student_code']?.toString() ?? 'N/A',
                    'phone': m['phone_number']?.toString() ?? '',
                  });
                }
              }
            }
          } catch (_) {}
        }
      }

      // 2. If no group selected OR group query returned empty: fetch center students
      if (list.isEmpty) {
        // Option A: RPC get_student_list
        try {
          final rpcRes = await client.rpc('get_student_list', params: {
            'p_page': 1,
            'p_page_size': 300,
          });
          final raw = rpcRes is Map ? (rpcRes['data'] as List?) : (rpcRes as List?);
          if (raw != null) {
            for (final item in raw) {
              final m = Map<String, dynamic>.from(item as Map);
              final name = (m['full_name'] as String?)?.trim();
              if (name != null && name.isNotEmpty) {
                list.add({
                  'id': m['id']?.toString() ?? '',
                  'name': name,
                  'code': m['student_code']?.toString() ?? 'N/A',
                  'phone': m['phone_number']?.toString() ?? '',
                });
              }
            }
          }
        } catch (_) {}

        // Option B: direct query students join profiles
        if (list.isEmpty) {
          try {
            final stuRes = await client
                .from('students')
                .select('id, student_code, profiles(full_name, phone_number)')
                .limit(300);
            for (final item in (stuRes as List)) {
              final prof = item['profiles'] as Map<String, dynamic>?;
              final name = (prof?['full_name'] as String?)?.trim();
              final code = item['student_code'] as String? ?? 'N/A';
              final phone = prof?['phone_number'] as String? ?? '';
              if (name != null && name.isNotEmpty) {
                list.add({
                  'id': item['id']?.toString() ?? '',
                  'name': name,
                  'code': code,
                  'phone': phone,
                });
              }
            }
          } catch (_) {}
        }

        // Option C: direct query profiles where role = 'student'
        if (list.isEmpty) {
          try {
            final profRes = await client
                .from('profiles')
                .select('id, full_name, phone_number')
                .eq('role', 'student')
                .limit(300);
            for (final item in (profRes as List)) {
              final name = (item['full_name'] as String?)?.trim();
              if (name != null && name.isNotEmpty) {
                final idStr = item['id']?.toString() ?? '';
                final shortCode = idStr.length >= 5 ? idStr.substring(0, 5).toUpperCase() : '001';
                list.add({
                  'id': idStr,
                  'name': name,
                  'code': 'STD-$shortCode',
                  'phone': item['phone_number']?.toString() ?? '',
                });
              }
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _availableStudents.clear();
          _availableStudents.addAll(list);
        });
      }
    } catch (e) {
      debugPrint('Error fetching students: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _autoSeatRemaining() async {
    if (_availableStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد طلاب متاحون في هذه الدفعة لتسكينهم ⚠️'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    int seatedCount = 0;
    int currentSeat = 1;
    final totalSeats = _actualCapacity;

    for (final s in _availableStudents) {
      final isAlreadySeated = _seats.values.any((item) =>
          (item['studentCode'] != null && item['studentCode'] == s['code']) ||
          (item['studentId'] != null && item['studentId'] == s['id']) ||
          item['studentName'] == s['name']);

      if (!isAlreadySeated) {
        while (_seats.containsKey(currentSeat) && currentSeat <= totalSeats) {
          currentSeat++;
        }
        if (currentSeat <= totalSeats) {
          _seats[currentSeat] = {
            'seatNumber': currentSeat,
            'studentId': s['id'],
            'studentName': s['name'],
            'studentCode': s['code'],
            'studentPhone': s['phone'],
            'notes': '',
          };
          seatedCount++;
        } else {
          // Reached full hall capacity
          break;
        }
      }
    }

    setState(() {});
    await _saveSeats();

    if (mounted) {
      if (seatedCount > 0) {
        final isFull = _seats.length >= totalSeats;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFull
                  ? 'تم تسكين $seatedCount طالب بنجاح! اكتملت سعة القاعة بالكامل ($totalSeats مقعد) 🪑✅'
                  : 'تم تسكين $seatedCount طالب بنجاح وحفظ التوزيع تلقائياً 🪑💾',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جميع الطلاب في هذه الدفعة مسكنون بالفعل أو لا توجد مقاعد شاغرة ℹ️'),
            backgroundColor: Colors.blueGrey,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmClearAllSeats() async {
    if (_seats.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد إخلاء القاعة'),
          content: Text('هل أنت متأكد من رغبتك في إخلاء كافة المقاعد المسكنة (${_seats.length} مقعد)؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إخلاء الكل'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _seats.clear());
      await _saveSeats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إخلاء جميع مقاعد القاعة بنجاح 🧹'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
        groupName: _currentBatchDisplay,
        teacherName: widget.centerName,
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event_seat_rounded, color: Colors.indigo, size: 20),
                ),
                const SizedBox(width: 8),
                Text('المقعد رقم #$seatNum 🪑'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الطالب: ${existing['studentName']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  'الكود: ${existing['studentCode']}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Text(
                  'هاتف ولي الأمر: ${existing['studentPhone'] ?? 'غير مسجل'}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                if ((existing['notes'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'ملاحظات: ${existing['notes']}',
                    style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
                  ),
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
                onPressed: () async {
                  setState(() => _seats.remove(seatNum));
                  await _saveSeats();
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم إخلاء المقعد رقم #$seatNum وحفظ التعديل 🧹'),
                        backgroundColor: Colors.orange.shade800,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('إلغاء التسكين وإخلاء المقعد'),
              ),
            ],
          ),
        ),
      );
    } else {
      // Seat is empty: quick assign bottom sheet with search
      String searchQuery = '';
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) => StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = _availableStudents.where((s) {
              final q = searchQuery.trim().toLowerCase();
              if (q.isEmpty) return true;
              final name = (s['name'] ?? '').toString().toLowerCase();
              final code = (s['code'] ?? '').toString().toLowerCase();
              return name.contains(q) || code.contains(q);
            }).toList();

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add_circle_outline_rounded, color: Colors.green, size: 20),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'تسكين طالب في المقعد رقم #$seatNum 🪑',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedGroupId != null
                          ? 'الدفعة المختارة: $_selectedGroupName'
                          : 'قائمة طلاب السنتر المتاحة:',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم الطالب أو الكود...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (val) {
                        setSheetState(() => searchQuery = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingStudents)
                      const Expanded(child: Center(child: CircularProgressIndicator()))
                    else if (_availableStudents.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off_outlined, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                'لا يوجد طلاب مسجلون حالياً في هذه الدفعة',
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (filtered.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'لا توجد نتائج مطابقة للبحث',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final s = filtered[i];
                            final isAlreadySeated = _seats.values.any((item) =>
                                (item['studentCode'] != null && item['studentCode'] == s['code']) ||
                                (item['studentId'] != null && item['studentId'] == s['id']) ||
                                item['studentName'] == s['name']);

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isAlreadySeated ? Colors.grey : AppColors.primary,
                                child: Text(
                                  s['name'].toString().isNotEmpty
                                      ? s['name'].toString().split(' ').first[0]
                                      : 'ط',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                s['name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isAlreadySeated ? Colors.grey : null,
                                ),
                              ),
                              subtitle: Text('كود: ${s['code']}', style: const TextStyle(fontSize: 12)),
                              trailing: isAlreadySeated
                                  ? const Text('مسكن بالفعل', style: TextStyle(fontSize: 11, color: Colors.grey))
                                  : FilledButton(
                                      onPressed: () async {
                                        setState(() {
                                          _seats[seatNum] = {
                                            'seatNumber': seatNum,
                                            'studentId': s['id'],
                                            'studentName': s['name'],
                                            'studentCode': s['code'],
                                            'studentPhone': s['phone'],
                                            'notes': '',
                                          };
                                        });
                                        await _saveSeats();
                                        if (mounted) {
                                          Navigator.pop(sheetCtx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('تم تسكين الطالب ${s['name']} في المقعد #$seatNum وحفظ البيانات 🪑✅'),
                                              backgroundColor: Colors.green,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
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
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final totalDisplaySeats = _actualCapacity;
    final occupiedCount = _seats.length;
    final remainingCount = totalDisplaySeats - occupiedCount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 960,
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تسكين وتوزيع مقاعد: ${widget.hallName} 🏛️',
                                style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Text(
                                    'المقاعد: $occupiedCount مسكن / $remainingCount شاغر (سعة $totalDisplaySeats مقعد)',
                                    style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                  if (_isSaving) ...[
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Batch / Group Filter Selector & Action Toolbar
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Group / Batch Selector Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedGroupId,
                        isDense: true,
                        hint: const Row(
                          children: [
                            Icon(Icons.groups_rounded, size: 16, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text('دفعة التسكين: جميع طلاب السنتر', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Row(
                              children: [
                                Icon(Icons.people_outline, size: 16, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text('جميع طلاب السنتر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          ..._groups.map((g) {
                            return DropdownMenuItem<String?>(
                              value: g['id'] as String?,
                              child: Row(
                                children: [
                                  const Icon(Icons.school_outlined, size: 16, color: Colors.indigo),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${g['name']} ${g['code'] != null ? "(${g['code']})" : ""}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedGroupId = val;
                            if (val == null) {
                              _selectedGroupName = 'جميع طلاب السنتر';
                            } else {
                              final g = _groups.firstWhere((x) => x['id'] == val, orElse: () => {});
                              _selectedGroupName = g['name'] as String?;
                            }
                          });
                          _fetchStudents();
                        },
                      ),
                    ),
                  ),

                  // Actions
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _autoSeatRemaining,
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                        label: Text('تسكين تلقائي للدفعة (${_availableStudents.length}) ⚡'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _seats.isEmpty ? null : _confirmClearAllSeats,
                        icon: const Icon(Icons.clear_all_rounded, size: 16, color: Colors.red),
                        label: const Text('إخلاء المقاعد', style: TextStyle(color: Colors.red)),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.indigo.shade800,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: (_isGeneratingPdf || _seats.isEmpty) ? null : _exportDeskLabelsPdf,
                        icon: _isGeneratingPdf
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.print_rounded, size: 16),
                        label: const Text('طباعة استيكرات (A4) 🖨️'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Teacher Podium / Front of Hall Indicator
              Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.25)),
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
              const SizedBox(height: 10),

              // Visual Seats Grid (No 40 seat cap! Displays full hall capacity up to 100+)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 145,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.25,
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
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isOccupied
                                ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isOccupied ? Colors.indigo.shade400 : Colors.green.withValues(alpha: 0.35),
                              width: isOccupied ? 1.5 : 1,
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
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textPrimary),
                                ),
                                Text(
                                  'كود: ${seatData?['studentCode']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 9.5, color: Colors.grey),
                                ),
                              ] else ...[
                                const Center(
                                  child: Text(
                                    'مقعد شاغر\nاضغط للتسكين',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 9.5, color: Colors.green, fontWeight: FontWeight.w600),
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
