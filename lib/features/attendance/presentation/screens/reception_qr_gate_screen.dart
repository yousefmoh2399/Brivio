import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../academy/data/repositories/supabase_academy_repositories.dart';
import '../../../academy/domain/models/academy_models.dart';
import '../../../payments/presentation/screens/daily_cash_register_screen.dart';
import '../../../payments/presentation/widgets/digital_cash_receipt_dialog.dart';
import '../../data/repositories/supabase_attendance_repositories.dart';
import '../../domain/models/attendance_models.dart';

class ReceptionQrGateScreen extends StatefulWidget {
  const ReceptionQrGateScreen({super.key});

  @override
  State<ReceptionQrGateScreen> createState() => _ReceptionQrGateScreenState();
}

class _ReceptionQrGateScreenState extends State<ReceptionQrGateScreen> {
  late final MobileScannerController _scannerController;
  late final SupabaseGroupRepository _groupRepo;
  late final SupabaseClassSessionRepository _sessionRepo;
  late final SupabaseStudentRepository _studentRepo;

  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  ClassSession? _selectedSession;

  bool _isLoading = true;
  bool _isProcessingScan = false;
  bool _isTorchOn = false;

  // Real-time scan result
  _ScanResultInfo? _lastResult;
  Timer? _clearResultTimer;

  // Attendees in current gate session
  final List<_AttendeeItem> _attendees = [];
  int _totalGroupStudents = 0;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _groupRepo = SupabaseGroupRepository(wrapper);
    _sessionRepo = SupabaseClassSessionRepository(wrapper);
    _studentRepo = SupabaseStudentRepository(wrapper);

    OfflineSyncService().init();
    _initGate();
  }

  @override
  void dispose() {
    _clearResultTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _initGate() async {
    setState(() => _isLoading = true);
    final offlineService = OfflineSyncService();

    try {
      final groups = await _groupRepo.fetchGroups(status: 'active');
      GroupEntity? initialGroup = groups.isNotEmpty ? groups.first : null;
      List<ClassSession> sessions = [];
      ClassSession? initialSession;

      if (initialGroup != null) {
        sessions = await _sessionRepo.fetchSessionsForGroup(initialGroup.id);
        if (sessions.isNotEmpty) {
          initialSession = sessions.first;
        } else {
          // If no session exists for today, create one automatically
          initialSession = await _sessionRepo.createClassSession(
            ClassSession(
              id: '',
              groupId: initialGroup.id,
              sessionDate: DateTime.now(),
              scheduledStartAt: DateTime.now(),
              scheduledEndAt: DateTime.now().add(const Duration(hours: 2)),
              status: SessionStatus.inProgress,
            ),
          );
        }
      }

      int totalStudents = 0;
      if (initialGroup != null) {
        final students = await _studentRepo.fetchStudentsForGroup(initialGroup.id);
        totalStudents = students.length;

        // Background caching of student directory & arrears for offline resilience
        try {
          final client = Supabase.instance.client;
          final studentsData = await client
              .from('students')
              .select('id, student_code, full_name, emergency_contact_phone, profiles(phone_number)')
              .limit(500);

          final invoicesData = await client
              .from('invoices')
              .select('id, student_id, amount, status')
              .inFilter('status', ['unpaid', 'overdue']);

          final invoicesMap = <String, Map<String, dynamic>>{};
          for (final inv in (invoicesData as List)) {
            final stuId = inv['student_id'] as String?;
            if (stuId != null) {
              final existing = invoicesMap[stuId];
              final currentTotal = (existing?['arrears_amount'] as num? ?? 0) + (inv['amount'] as num? ?? 0);
              invoicesMap[stuId] = {
                'pending_invoice_id': inv['id'],
                'arrears_amount': currentTotal,
              };
            }
          }

          final directoryToCache = <Map<String, dynamic>>[];
          for (final raw in (studentsData as List)) {
            final stuId = raw['id'] as String;
            final invoiceInfo = invoicesMap[stuId];
            directoryToCache.add({
              'id': stuId,
              'student_code': raw['student_code'] ?? '',
              'full_name': raw['full_name'] ?? '',
              'emergency_contact_phone': raw['emergency_contact_phone'] ?? '',
              'parent_phone': (raw['profiles'] as Map?)?['phone_number'] ?? '',
              'arrears_amount': invoiceInfo?['arrears_amount'] ?? 0,
              'pending_invoice_id': invoiceInfo?['pending_invoice_id'],
              'has_due': (invoiceInfo?['arrears_amount'] ?? 0) > 0,
            });
          }
          await offlineService.cacheStudentsDirectory(directoryToCache);
        } catch (_) {}
      }

      // Snapshot groups and sessions for cold-boot offline startup
      if (groups.isNotEmpty) {
        await offlineService.cacheGroupsAndSessions(
          groups: groups.map((g) => g.toJson()).toList(),
          sessions: sessions.map((s) => {
            'id': s.id,
            'group_id': s.groupId,
            'session_date': s.sessionDate.toIso8601String(),
            'scheduled_start_at': s.scheduledStartAt.toIso8601String(),
            'scheduled_end_at': s.scheduledEndAt.toIso8601String(),
            'status': s.status.toDbValue(),
          }).toList(),
        );
      }

      if (mounted) {
        setState(() {
          _groups = groups;
          _selectedGroup = initialGroup;
          _selectedSession = initialSession;
          _totalGroupStudents = totalStudents;
          _isLoading = false;
        });
      }
    } catch (_) {
      // COLD-BOOT OFFLINE FALLBACK: Load from local snapshot
      final cachedGroupsRaw = await offlineService.getCachedGroups();
      List<GroupEntity> fallbackGroups = [];
      for (final g in cachedGroupsRaw) {
        try {
          fallbackGroups.add(GroupEntity.fromJson(g));
        } catch (_) {}
      }

      if (fallbackGroups.isEmpty) {
        fallbackGroups.add(
          const GroupEntity(
            id: 'offline_default_group',
            name: 'مجموعة الاستقبال (وضع عدم الاتصال)',
            code: 'OFFLINE-01',
            subjectId: '',
            branchId: '',
            status: 'active',
          ),
        );
      }

      final initialGroup = fallbackGroups.first;
      final cachedSessionsRaw = await offlineService.getCachedSessions(initialGroup.id);
      ClassSession? fallbackSession;
      if (cachedSessionsRaw.isNotEmpty) {
        try {
          fallbackSession = ClassSession.fromJson(cachedSessionsRaw.first);
        } catch (_) {}
      }

      fallbackSession ??= ClassSession(
        id: 'offline_session_${initialGroup.id}',
        groupId: initialGroup.id,
        sessionDate: DateTime.now(),
        scheduledStartAt: DateTime.now(),
        scheduledEndAt: DateTime.now().add(const Duration(hours: 2)),
        status: SessionStatus.inProgress,
      );

      final cachedStudents = await offlineService.getCachedStudentsDirectory();

      if (mounted) {
        setState(() {
          _groups = fallbackGroups;
          _selectedGroup = initialGroup;
          _selectedSession = fallbackSession;
          _totalGroupStudents = cachedStudents.length;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onGroupChanged(GroupEntity group) async {
    setState(() {
      _selectedGroup = group;
      _isLoading = true;
    });

    try {
      final sessions = await _sessionRepo.fetchSessionsForGroup(group.id);
      final students = await _studentRepo.fetchStudentsForGroup(group.id);

      ClassSession? session = sessions.isNotEmpty ? sessions.first : null;
      session ??= await _sessionRepo.createClassSession(
        ClassSession(
          id: '',
          groupId: group.id,
          sessionDate: DateTime.now(),
          scheduledStartAt: DateTime.now(),
          scheduledEndAt: DateTime.now().add(const Duration(hours: 2)),
          status: SessionStatus.inProgress,
        ),
      );

      if (mounted) {
        setState(() {
          _selectedSession = session;
          _totalGroupStudents = students.length;
          _attendees.clear();
          _isLoading = false;
        });
      }
    } catch (_) {
      final offlineService = OfflineSyncService();
      final cachedSessionsRaw = await offlineService.getCachedSessions(group.id);
      ClassSession? session;
      if (cachedSessionsRaw.isNotEmpty) {
        try {
          session = ClassSession.fromJson(cachedSessionsRaw.first);
        } catch (_) {}
      }
      session ??= ClassSession(
        id: 'offline_session_${group.id}',
        groupId: group.id,
        sessionDate: DateTime.now(),
        scheduledStartAt: DateTime.now(),
        scheduledEndAt: DateTime.now().add(const Duration(hours: 2)),
        status: SessionStatus.inProgress,
      );

      if (mounted) {
        setState(() {
          _selectedSession = session;
          _attendees.clear();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleBarcodeScanned(BarcodeCapture capture) async {
    if (_isProcessingScan || _selectedSession == null) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (barcode == null || barcode.isEmpty) return;

    setState(() => _isProcessingScan = true);

    try {
      final client = Supabase.instance.client;
      final offlineService = OfflineSyncService();

      // 1. Resolve student (Try online first, fallback to offline directory)
      Map<String, dynamic>? studentRes;
      bool isOfflineMode = false;

      try {
        studentRes = await client
            .from('students')
            .select('id, student_code, full_name, emergency_contact_phone, profiles(phone_number)')
            .or('student_code.eq.$barcode,id.eq.$barcode')
            .limit(1)
            .maybeSingle();
      } catch (_) {
        // Network or connection failure: switch to offline mode
        isOfflineMode = true;
      }

      // Check offline directory if offline or online search gave nothing
      Map<String, dynamic>? offlineStudent;
      if (isOfflineMode || studentRes == null) {
        offlineStudent = await offlineService.resolveStudentOffline(barcode);
      }

      // If online and student code truly does not exist in both DB and offline directory
      if (!isOfflineMode && studentRes == null && offlineStudent == null) {
        _showScanError('كود الطالب غير موجود في النظام!');
        return;
      }

      final studentId = studentRes?['id'] as String? ??
          offlineStudent?['id'] as String? ??
          'offline_$barcode';

      final studentName = studentRes?['full_name'] as String? ??
          offlineStudent?['full_name'] as String? ??
          'طالب (كود: $barcode)';

      final studentCode = studentRes?['student_code'] as String? ??
          offlineStudent?['student_code'] as String? ??
          barcode;

      final parentPhone = studentRes?['emergency_contact_phone'] as String? ??
          (studentRes?['profiles'] as Map?)?['phone_number'] as String? ??
          offlineStudent?['emergency_contact_phone'] as String? ??
          offlineStudent?['parent_phone'] as String? ??
          '';

      num totalDue = offlineStudent?['arrears_amount'] as num? ?? 0;
      String? pendingInvoiceId = offlineStudent?['pending_invoice_id'] as String?;

      if (!isOfflineMode && studentRes != null) {
        try {
          // 2. Mark attendance in DB
          await client.from('attendance_records').upsert({
            'class_session_id': _selectedSession!.id,
            'student_id': studentId,
            'attendance_status': 'present',
            'marked_at': DateTime.now().toIso8601String(),
            'arrival_at': DateTime.now().toIso8601String(),
          }, onConflict: 'class_session_id,student_id');

          // 3. Check open/unpaid invoices
          final openInvoices = await client
              .from('invoices')
              .select('id, amount, status')
              .eq('student_id', studentId)
              .inFilter('status', ['unpaid', 'overdue']);

          if (openInvoices.isNotEmpty) {
            totalDue = 0;
            for (final inv in openInvoices) {
              totalDue += (inv['amount'] as num? ?? 0);
              pendingInvoiceId ??= inv['id'] as String?;
            }
          }
        } catch (_) {
          isOfflineMode = true;
        }
      }

      // If in offline mode, queue local attendance record with deduplication
      if (isOfflineMode) {
        final queueResult = await offlineService.queueAttendanceCheckIn(
          studentId: studentId,
          groupId: _selectedGroup?.id ?? '',
          sessionId: _selectedSession!.id,
          studentName: studentName,
          studentCode: studentCode,
          notes: 'تسجيل سريع أوفلاين (انقطاع الاتصال المؤقت)',
        );

        if (queueResult.isDuplicate) {
          HapticFeedback.vibrate();
          SystemSound.play(SystemSoundType.alert);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(queueResult.message),
                backgroundColor: Colors.amber.shade900,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      final hasDue = totalDue > 0;
      if (hasDue) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      } else {
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
      }

      final result = _ScanResultInfo(
        studentId: studentId,
        name: studentName,
        code: studentCode,
        parentPhone: parentPhone,
        totalDue: totalDue,
        hasDue: hasDue,
        pendingInvoiceId: pendingInvoiceId,
        scannedAt: DateTime.now(),
        isOffline: isOfflineMode,
      );

      if (mounted) {
        setState(() {
          _lastResult = result;
          _attendees.removeWhere((a) => a.studentId == studentId);
          _attendees.insert(
            0,
            _AttendeeItem(
              studentId: studentId,
              name: studentName,
              code: studentCode,
              parentPhone: parentPhone,
              time: DateTime.now(),
              hasDue: hasDue,
              totalDue: totalDue,
              isOffline: isOfflineMode,
            ),
          );
        });

        _clearResultTimer?.cancel();
        _clearResultTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) {
            setState(() => _lastResult = null);
          }
        });
      }
    } catch (e) {
      _showScanError('حدث خطأ في التسجيل: $e');
    } finally {
      // Rapid batch scanning delay for quick entrance gate flow
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) setState(() => _isProcessingScan = false);
    }
  }

  void _showScanError(String msg) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _collectCashNow(_ScanResultInfo result) async {
    try {
      final receiptNumber = 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // 1. If online and invoice exists, update Supabase
      if (!result.isOffline && result.pendingInvoiceId != null) {
        try {
          final client = Supabase.instance.client;
          await client.from('invoices').update({
            'status': 'paid',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', result.pendingInvoiceId!);

          await client.from('receipts').insert({
            'invoice_id': result.pendingInvoiceId,
            'amount': result.totalDue,
            'payment_method': 'cash',
            'issued_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }

      // 2. Always deduct from local offline student directory cache
      await OfflineSyncService().updateStudentArrearsLocally(
        studentIdOrCode: result.code,
        amountDeducted: result.totalDue,
      );

      if (mounted) {
        setState(() {
          _lastResult = _ScanResultInfo(
            studentId: result.studentId,
            name: result.name,
            code: result.code,
            parentPhone: result.parentPhone,
            totalDue: 0,
            hasDue: false,
            scannedAt: DateTime.now(),
            isOffline: result.isOffline,
          );
        });

        // Instantly display official electronic cash receipt modal
        DigitalCashReceiptDialog.show(
          context: context,
          receiptType: ReceiptType.studentPayment,
          centerName: 'السنتر التعليمي',
          receiptNumber: receiptNumber,
          dateStr:
              '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
          recipientName: result.name,
          studentCode: result.code,
          groupName: _selectedGroup?.name ?? 'المجموعة الدراسية',
          amount: result.totalDue.toDouble(),
          paymentPurpose: 'سداد مصاريف دراسية متأخرة - نقداً بالخزينة',
          parentOrTeacherPhone: result.parentPhone,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التحصيل: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAbsentStudentsSheet() async {
    if (_selectedSession == null || _selectedGroup == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AbsentStudentsModal(
        group: _selectedGroup!,
        session: _selectedSession!,
        presentStudentIds: _attendees.map((a) => a.studentId).toSet(),
      ),
    );
  }

  Future<void> _printGroupCards() async {
    if (_selectedGroup == null) return;

    try {
      final students = await _studentRepo.fetchStudentsForGroup(_selectedGroup!.id);
      if (students.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يوجد طلاب مسجلون في هذه المجموعة لطباعة الكارنيهات.')),
          );
        }
        return;
      }

      final studentsData = students
          .map(
            (s) => {
              'name': s.fullName,
              'code': s.studentCode,
              'phone': s.phoneNumber ?? '',
              'grade': _selectedGroup!.name,
            },
          )
          .toList();

      await ReportGeneratorService().generateBulkStudentIdCardsPdf(
        students: studentsData,
        centerName: 'سنتر الأوائل التعليمي',
        groupName: _selectedGroup!.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم توليد كروت هوية طلاب مجموعة (${_selectedGroup!.name}) جاهزة للطباعة 🪪'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل توليد الكارنيهات: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'بوابة الاستقبال • تسجيل حضور سريع بالـ QR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (_selectedGroup != null)
                Text(
                  'المجموعة: ${_selectedGroup!.name} (${_attendees.length} / $_totalGroupStudents حاضر)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: OfflineSyncService().isOnline,
              builder: (context, isOnline, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: OfflineSyncService().pendingSyncCount,
                  builder: (context, pendingCount, _) {
                    final isSyncing = OfflineSyncService().isSyncing.value;
                    if (pendingCount == 0 && isOnline) {
                      return IconButton(
                        icon: const Icon(Icons.cloud_done_rounded, color: Colors.greenAccent),
                        tooltip: 'السحابة متصلة • كافة السجلات مزمّنة 🟢',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('الاتصال ممتاز وسجلات الحضور مزمّنة سحابياً 🟢'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      );
                    }
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.amber.shade900.withValues(alpha: 0.35),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.amber.shade400, width: 1.2),
                          ),
                        ),
                        icon: isSyncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                              )
                            : Icon(
                                isOnline ? Icons.cloud_upload_rounded : Icons.sync_problem_rounded,
                                color: Colors.amber,
                                size: 16,
                              ),
                        label: Text(
                          isOnline ? 'مزامنة معلقة ($pendingCount)' : 'أوفلاين ($pendingCount)',
                          style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final res = await OfflineSyncService().syncQueuedAttendance();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: res.success ? Colors.green.shade700 : Colors.orange.shade800,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.badge_outlined, color: Colors.white),
              tooltip: 'طباعة كارنيهات هذه المجموعة (PDF)',
              onPressed: _printGroupCards,
            ),
            IconButton(
              icon: const Icon(Icons.point_of_sale_rounded, color: Colors.tealAccent),
              tooltip: 'جرد وتقفيل الخزينة اليومية',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DailyCashRegisterScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(
                _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _isTorchOn ? Colors.amber : Colors.white,
              ),
              tooltip: 'تشغيل الفلاش',
              onPressed: () {
                _scannerController.toggleTorch();
                setState(() => _isTorchOn = !_isTorchOn);
              },
            ),
            IconButton(
              icon: const Icon(Icons.people_outline_rounded, color: Colors.white),
              tooltip: 'كشف الغائبين والواتساب',
              onPressed: _showAbsentStudentsSheet,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildGroupPickerHeader(),
                  Expanded(
                    flex: 5,
                    child: Stack(
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: _handleBarcodeScanned,
                        ),
                        _buildScannerOverlay(),
                        if (_lastResult != null)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: _buildResultHudCard(_lastResult!),
                          ),
                      ],
                    ),
                  ),
                  _buildRecentAttendeesSection(),
                ],
              ),
      ),
    );
  }

  Widget _buildGroupPickerHeader() {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          const Text('المجموعة:', style: TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<GroupEntity>(
                value: _selectedGroup,
                dropdownColor: const Color(0xFF1E293B),
                isExpanded: true,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                items: _groups.map((g) {
                  return DropdownMenuItem(value: g, child: Text(g.name));
                }).toList(),
                onChanged: (g) {
                  if (g != null) _onGroupChanged(g);
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_attendees.length} حاضر',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 2.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _isProcessingScan ? 'جاري التحقق...' : 'وجّه الكاميرا لكود الطالب',
                style: const TextStyle(
                  color: Colors.white,
                  backgroundColor: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_isProcessingScan)
              const LinearProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHudCard(_ScanResultInfo result) {
    final hasDue = result.hasDue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasDue ? const Color(0xFF991B1B) : const Color(0xFF064E3B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasDue ? const Color(0xFFEF4444) : Colors.greenAccent,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: hasDue ? Colors.red.shade400 : Colors.green.shade400,
                radius: 24,
                child: Icon(
                  hasDue ? Icons.priority_high_rounded : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      result.isOffline
                          ? 'كود: ${result.code} • تم الحفظ أوفلاين (بانتظار المزامنة) 💾'
                          : 'كود: ${result.code} • تم تسجيل الحضور ✅',
                      style: TextStyle(
                        color: result.isOffline ? Colors.amberAccent : Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: result.isOffline ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (result.parentPhone.isNotEmpty)
                IconButton(
                  tooltip: 'إشعار واتساب فوري لولي الأمر',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.chat, size: 20),
                  onPressed: () {
                    final groupTitle = _selectedGroup?.name ?? 'الحصة';
                    WhatsAppService.sendCustomMessage(
                      phone: result.parentPhone,
                      message:
                          'تم تسجيل حضور الطالب/ة (${result.name}) لحصة ($groupTitle) بنجاح ✅ - سنتر التعليمي',
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasDue) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⚠️ تنبيه مالي أحمر: الطالب عليه ${result.totalDue.toStringAsFixed(0)} ج.م مصاريف متأخرة!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => _collectCashNow(result),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.payments_rounded, size: 18),
                    label: Text(
                      'تحصيل كاش الآن (${result.totalDue.toStringAsFixed(0)} ج.م) وإصدار إيصال',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 16),
                  SizedBox(width: 6),
                  Text('حساب الطالب مسدد بالكامل ✔️', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentAttendeesSection() {
    return Container(
      height: 190,
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سجل الحاضرين في الجلسة (${_attendees.length})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              TextButton.icon(
                onPressed: _showAbsentStudentsSheet,
                icon: const Icon(Icons.send_rounded, size: 14, color: Colors.greenAccent),
                label: const Text(
                  'إرسال واتساب للغائبين',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _attendees.isEmpty
                ? const Center(
                    child: Text(
                      'لم يتم تسجيل أي طالب بعد، ابدأ بمسح الأكواد!',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _attendees.length,
                    itemBuilder: (ctx, i) {
                      final item = _attendees[i];
                      return Container(
                        width: 170,
                        margin: const EdgeInsets.only(left: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: item.hasDue ? Colors.red.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      'كود: ${item.code}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                                    ),
                                    if (item.isOffline) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.cloud_off_rounded, color: Colors.amber, size: 12),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${item.time.hour}:${item.time.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                                if (item.parentPhone.isNotEmpty)
                                  InkWell(
                                    onTap: () {
                                      WhatsAppService.sendMessage(
                                        phoneNumber: item.parentPhone,
                                        message: 'تم تسجيل حضور الطالب ${item.name} بنجاح.',
                                      );
                                    },
                                    child: const Icon(Icons.chat_bubble_outline, color: Colors.green, size: 18),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScanResultInfo {
  final String studentId;
  final String name;
  final String code;
  final String parentPhone;
  final num totalDue;
  final bool hasDue;
  final String? pendingInvoiceId;
  final DateTime scannedAt;
  final bool isOffline;

  _ScanResultInfo({
    required this.studentId,
    required this.name,
    required this.code,
    required this.parentPhone,
    required this.totalDue,
    required this.hasDue,
    this.pendingInvoiceId,
    required this.scannedAt,
    this.isOffline = false,
  });
}

class _AttendeeItem {
  final String studentId;
  final String name;
  final String code;
  final String parentPhone;
  final DateTime time;
  final bool hasDue;
  final num totalDue;
  final bool isOffline;

  _AttendeeItem({
    required this.studentId,
    required this.name,
    required this.code,
    required this.parentPhone,
    required this.time,
    required this.hasDue,
    required this.totalDue,
    this.isOffline = false,
  });
}

class _AbsentStudentsModal extends StatefulWidget {
  final GroupEntity group;
  final ClassSession session;
  final Set<String> presentStudentIds;

  const _AbsentStudentsModal({
    required this.group,
    required this.session,
    required this.presentStudentIds,
  });

  @override
  State<_AbsentStudentsModal> createState() => _AbsentStudentsModalState();
}

class _AbsentStudentsModalState extends State<_AbsentStudentsModal> {
  bool _isLoading = true;
  List<Student> _absentStudents = [];
  final Set<String> _sentStudentIds = {};

  @override
  void initState() {
    super.initState();
    _loadAbsentStudents();
  }

  Future<void> _loadAbsentStudents() async {
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    final studentRepo = SupabaseStudentRepository(wrapper);
    try {
      final allStudents = await studentRepo.fetchStudentsForGroup(widget.group.id);
      final absents = allStudents.where((s) => !widget.presentStudentIds.contains(s.id)).toList();
      if (mounted) {
        setState(() {
          _absentStudents = absents;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyAbsenteesList() {
    if (_absentStudents.isEmpty) return;
    final buffer = StringBuffer();
    buffer.writeln('📋 *كشف غياب حصة: ${widget.group.name}*');
    buffer.writeln('📅 التاريخ: ${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}');
    buffer.writeln('👥 إجمالي الغائبين: ${_absentStudents.length} طالب');
    buffer.writeln('━━━━━━━━━━━━━━━━━━');
    for (int i = 0; i < _absentStudents.length; i++) {
      final s = _absentStudents[i];
      buffer.writeln('${i + 1}. ${s.fullName} (كود: ${s.studentCode})');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ كشف الغياب بالكامل للحافظة!'),
        backgroundColor: Colors.black87,
      ),
    );
  }

  Future<void> _sendWhatsAppToStudent(Student student) async {
    final phone = student.phoneNumber ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا يوجد رقم هاتف مسجل لولي أمر الطالب ${student.fullName}'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final sent = await WhatsAppService.sendAbsenceNotice(
      parentPhone: phone,
      studentName: student.fullName,
      subjectName: widget.group.name,
      centerName: 'السنتر التعليمي',
    );

    if (mounted) {
      setState(() {
        _sentStudentIds.add(student.id);
      });
      if (sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم فتح محادثة واتساب لولي أمر ${student.fullName} ✅'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _sendBatchWhatsAppToAll() async {
    final pending = _absentStudents.where((s) => !_sentStudentIds.contains(s.id)).toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال إشعار الغياب لجميع الغائبين بالفعل!')),
      );
      return;
    }

    final student = pending.first;
    await _sendWhatsAppToStudent(student);

    if (pending.length > 1 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم فتح محادثة ${student.fullName}. متبقي ${pending.length - 1} طلاب.'),
          backgroundColor: Colors.blueGrey,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _absentStudents.where((s) => !_sentStudentIds.contains(s.id)).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_off_rounded, color: Colors.redAccent, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'كشف الغائبين (${_absentStudents.length} طالب)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'المجموعة: ${widget.group.name} • إرسال إشعارات غياب فورية بالواتساب',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (!_isLoading && _absentStudents.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _sendBatchWhatsAppToAll,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        pendingCount > 0
                            ? 'إرسال واتساب للغائبين ($pendingCount متبقي)'
                            : 'تم إرسال الإشعار للجميع ✅',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _copyAbsenteesList,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('نسخ الكشف'),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _absentStudents.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                              SizedBox(height: 12),
                              Text(
                                'رائع! جميع طلاب المجموعة حاضرون اليوم.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _absentStudents.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final student = _absentStudents[i];
                            final isSent = _sentStudentIds.contains(student.id);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              leading: CircleAvatar(
                                backgroundColor: isSent ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                child: Icon(
                                  isSent ? Icons.done_all_rounded : Icons.person_off_rounded,
                                  color: isSent ? Colors.green.shade700 : Colors.red,
                                ),
                              ),
                              title: Text(
                                student.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                'كود: ${student.studentCode} • هاتف: ${student.phoneNumber ?? 'غير مسجل'}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              trailing: isSent
                                  ? OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.green.shade700,
                                        side: BorderSide(color: Colors.green.shade400),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      icon: const Icon(Icons.check_rounded, size: 16),
                                      label: const Text('تم الإرسال', style: TextStyle(fontSize: 12)),
                                      onPressed: () => _sendWhatsAppToStudent(student),
                                    )
                                  : FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF25D366),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.chat, size: 16),
                                      label: const Text('واتساب ولي الأمر', style: TextStyle(fontSize: 12)),
                                      onPressed: () => _sendWhatsAppToStudent(student),
                                    ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
