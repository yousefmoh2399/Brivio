import 'dart:async';
import 'dart:convert';
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
import '../../../payments/presentation/widgets/express_cashier_dialog.dart';
import '../../../people/presentation/widgets/express_student_registration_dialog.dart';
import '../../data/repositories/supabase_attendance_repositories.dart';
import '../../domain/models/attendance_models.dart';

/// Real-time Scan Result Model
class ScanResultInfo {
  final String studentId;
  final String name;
  final String code;
  final String parentPhone;
  final num totalDue;
  final bool hasDue;
  final String? pendingInvoiceId;
  final DateTime scannedAt;
  final bool isOffline;

  const ScanResultInfo({
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

/// Attendee item displayed in the real-time live attendance feed
class AttendeeItem {
  final String studentId;
  final String name;
  final String code;
  final String parentPhone;
  final DateTime time;
  final bool hasDue;
  final num totalDue;
  final bool isOffline;

  const AttendeeItem({
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

/// Executive AAA Reception QR Gate Screen
/// Features:
/// - Camera QR Scanner with animated scanning radar & laser
/// - Rapid manual barcode / student code entry for damaged cards or no-camera devices
/// - Responsive Multi-Screen Layout (Compact Mobile, Tablet, and Desktop Split-Screen)
/// - Real-time arrears detection and one-click cash receipt issuance
/// - WhatsApp attendance notification to parent
/// - Offline resilience with auto-caching and cold-boot snapshot
class ReceptionQrGateScreen extends StatefulWidget {
  final bool isTestMode;
  final List<GroupEntity>? initialGroups;
  final GroupEntity? initialSelectedGroup;
  final List<AttendeeItem>? initialAttendees;
  final Future<void> Function(String barcode)? onManualBarcodeScan;

  const ReceptionQrGateScreen({
    super.key,
    this.isTestMode = false,
    this.initialGroups,
    this.initialSelectedGroup,
    this.initialAttendees,
    this.onManualBarcodeScan,
  });

  @override
  State<ReceptionQrGateScreen> createState() => _ReceptionQrGateScreenState();
}

class _ReceptionQrGateScreenState extends State<ReceptionQrGateScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _scannerController;
  late final SupabaseGroupRepository _groupRepo;
  late final SupabaseClassSessionRepository _sessionRepo;
  late final SupabaseStudentRepository _studentRepo;

  final TextEditingController _manualCodeController = TextEditingController();
  final FocusNode _manualCodeFocusNode = FocusNode();

  late final AnimationController _laserAnimController;
  late final Animation<double> _laserAnimation;

  List<GroupEntity> _groups = [];
  GroupEntity? _selectedGroup;
  ClassSession? _selectedSession;

  bool _isLoading = true;
  bool _isProcessingScan = false;
  bool _isTorchOn = false;
  bool _voiceBeeperEnabled = true;

  // Real-time scan result
  ScanResultInfo? _lastResult;
  Timer? _clearResultTimer;

  // Attendees in current gate session
  final List<AttendeeItem> _attendees = [];
  int _totalGroupStudents = 0;
  String _centerName = 'المركز التعليمي';

  @override
  void initState() {
    super.initState();

    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    if (!widget.isTestMode) {
      _laserAnimController.repeat(reverse: true);
    }

    _laserAnimation = CurvedAnimation(
      parent: _laserAnimController,
      curve: Curves.easeInOut,
    );

    if (!widget.isTestMode) {
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
    } else {
      _groups = widget.initialGroups ?? [];
      _selectedGroup = widget.initialSelectedGroup ??
          (_groups.isNotEmpty ? _groups.first : null);
      if (widget.initialAttendees != null) {
        _attendees.addAll(widget.initialAttendees!);
      }
      _totalGroupStudents =
          _groups.isNotEmpty ? (_attendees.length + 5) : 0;
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _manualCodeController.dispose();
    _manualCodeFocusNode.dispose();
    _clearResultTimer?.cancel();
    _scannerController?.dispose();
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
        final students =
            await _studentRepo.fetchStudentsForGroup(initialGroup.id);
        totalStudents = students.length;

        try {
          final client = Supabase.instance.client;
          final studentsData = await client
              .from('students')
              .select(
                  'id, student_code, full_name, emergency_contact_phone, profiles(phone_number)')
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
              final currentTotal = (existing?['arrears_amount'] as num? ?? 0) +
                  (inv['amount'] as num? ?? 0);
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
              'parent_phone':
                  (raw['profiles'] as Map?)?['phone_number'] ?? '',
              'arrears_amount': invoiceInfo?['arrears_amount'] ?? 0,
              'pending_invoice_id': invoiceInfo?['pending_invoice_id'],
              'has_due': (invoiceInfo?['arrears_amount'] ?? 0) > 0,
            });
          }
          await offlineService.cacheStudentsDirectory(directoryToCache);
        } catch (_) {}
      }

      String resolvedCenterName = _centerName;
      try {
        final client = Supabase.instance.client;
        final cRes = await client
            .from('educational_centers')
            .select('name')
            .limit(1)
            .maybeSingle();
        if (cRes != null &&
            cRes['name'] != null &&
            (cRes['name'] as String).isNotEmpty) {
          resolvedCenterName = cRes['name'] as String;
        }
      } catch (_) {}

      if (groups.isNotEmpty) {
        await offlineService.cacheGroupsAndSessions(
          groups: groups.map((g) => g.toJson()).toList(),
          sessions: sessions
              .map((s) => {
                    'id': s.id,
                    'group_id': s.groupId,
                    'session_date': s.sessionDate.toIso8601String(),
                    'scheduled_start_at': s.scheduledStartAt.toIso8601String(),
                    'scheduled_end_at': s.scheduledEndAt.toIso8601String(),
                    'status': s.status.toDbValue(),
                  })
              .toList(),
        );
      }

      if (mounted) {
        setState(() {
          _centerName = resolvedCenterName;
          _groups = groups;
          _selectedGroup = initialGroup;
          _selectedSession = initialSession;
          _totalGroupStudents = totalStudents;
          _isLoading = false;
        });
      }
    } catch (_) {
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
            id: '00000000-0000-0000-0000-000000000001',
            name: 'مجموعة الاستقبال (وضع عدم الاتصال)',
            code: 'OFFLINE-01',
            subjectId: '',
            branchId: '',
            status: 'active',
          ),
        );
      }

      final initialGroup = fallbackGroups.first;
      final cachedSessionsRaw =
          await offlineService.getCachedSessions(initialGroup.id);
      ClassSession? fallbackSession;
      if (cachedSessionsRaw.isNotEmpty) {
        try {
          fallbackSession = ClassSession.fromJson(cachedSessionsRaw.first);
        } catch (_) {}
      }

      fallbackSession ??= ClassSession(
        id: '00000000-0000-0000-0000-000000000002',
        groupId: initialGroup.id,
        sessionDate: DateTime.now(),
        scheduledStartAt: DateTime.now(),
        scheduledEndAt: DateTime.now().add(const Duration(hours: 2)),
        status: SessionStatus.inProgress,
      );

      final cachedStudents =
          await offlineService.getCachedStudentsDirectory();

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

    if (widget.isTestMode) {
      setState(() => _isLoading = false);
      return;
    }

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
      final cachedSessionsRaw =
          await offlineService.getCachedSessions(group.id);
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

  void _handleBarcodeScanned(BarcodeCapture capture) {
    if (_isProcessingScan || _selectedSession == null) return;
    final rawBarcode = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (rawBarcode == null || rawBarcode.isEmpty) return;
    _processBarcode(rawBarcode);
  }

  Future<void> _processBarcode(String rawBarcode) async {
    if (_isProcessingScan) return;

    if (widget.onManualBarcodeScan != null) {
      setState(() => _isProcessingScan = true);
      try {
        await widget.onManualBarcodeScan!(rawBarcode);
      } finally {
        if (mounted) setState(() => _isProcessingScan = false);
      }
      return;
    }

    // 1. Resolve barcode payload (extract student_code if scanned from digital 3D card or JSON token)
    String barcode = rawBarcode;
    if (barcode.startsWith('BRIVIO-SEC-GATE:')) {
      final parts = barcode.split(':');
      if (parts.length >= 2) {
        barcode = parts[1].trim();
      }
    } else if (barcode.contains('student_code=')) {
      final match =
          RegExp(r'student_code=([a-zA-Z0-9_\-]+)').firstMatch(barcode);
      if (match != null) {
        barcode = match.group(1)!;
      }
    } else if (barcode.startsWith('{') && barcode.endsWith('}')) {
      try {
        final decoded = jsonDecode(barcode);
        if (decoded is Map) {
          barcode = (decoded['student_code'] ??
                  decoded['code'] ??
                  decoded['student_id'] ??
                  decoded['id'] ??
                  barcode)
              .toString();
        }
      } catch (_) {}
    }

    setState(() => _isProcessingScan = true);

    try {
      final client = Supabase.instance.client;
      final offlineService = OfflineSyncService();

      Map<String, dynamic>? studentRes;
      bool isOfflineMode = false;

      try {
        studentRes = await client
            .from('students')
            .select(
                'id, student_code, full_name, emergency_contact_phone, profile_id, profiles(phone_number)')
            .or('student_code.eq.$barcode,id.eq.$barcode,profile_id.eq.$barcode')
            .limit(1)
            .maybeSingle();

        studentRes ??= await client
            .from('students')
            .select(
                'id, student_code, full_name, emergency_contact_phone, profile_id, profiles(phone_number)')
            .ilike('student_code', barcode)
            .limit(1)
            .maybeSingle();
      } catch (_) {
        isOfflineMode = true;
      }

      Map<String, dynamic>? offlineStudent;
      if (isOfflineMode || studentRes == null) {
        offlineStudent = await offlineService.resolveStudentOffline(barcode);
      }

      if (!isOfflineMode && studentRes == null && offlineStudent == null) {
        _showScanError('كود الطالب غير موجود في النظام: $barcode');
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
      String? pendingInvoiceId =
          offlineStudent?['pending_invoice_id'] as String?;

      if (!isOfflineMode && studentRes != null) {
        try {
          String targetSessionId = _selectedSession?.id ?? '';
          try {
            final now = DateTime.now();
            final todayStr = now.toIso8601String().split('T').first;
            final studentEnrollments = await client
                .from('group_students')
                .select('group_id, groups(id, name)')
                .eq('student_id', studentId);
            final enrolledGroupIds = (studentEnrollments as List)
                .map((e) => e['group_id']?.toString())
                .whereType<String>()
                .toList();

            if (enrolledGroupIds.isNotEmpty &&
                !enrolledGroupIds.contains(_selectedGroup?.id)) {
              final activeSession = await client
                  .from('class_sessions')
                  .select('id, group_id, groups(name)')
                  .inFilter('group_id', enrolledGroupIds)
                  .eq('session_date', todayStr)
                  .limit(1)
                  .maybeSingle();

              if (activeSession != null) {
                targetSessionId = activeSession['id'] as String;
              }
            }
          } catch (_) {}

          if (targetSessionId.isNotEmpty) {
            await client.from('attendance_records').upsert({
              'class_session_id': targetSessionId,
              'student_id': studentId,
              'attendance_status': 'present',
              'marked_at': DateTime.now().toIso8601String(),
              'arrival_at': DateTime.now().toIso8601String(),
            }, onConflict: 'class_session_id,student_id');
          }

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

      if (isOfflineMode) {
        final queueResult = await offlineService.queueAttendanceCheckIn(
          studentId: studentId,
          groupId: _selectedGroup?.id ?? '',
          sessionId: _selectedSession?.id ?? '',
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
      if (_voiceBeeperEnabled) {
        if (hasDue) {
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.alert);
        } else {
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.click);
        }
      }

      final result = ScanResultInfo(
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
            AttendeeItem(
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
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _isProcessingScan = false);
    }
  }

  void _submitManualCode() {
    final code = _manualCodeController.text.trim();
    if (code.isEmpty) return;
    _manualCodeController.clear();
    _manualCodeFocusNode.unfocus();
    _processBarcode(code);
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

  Future<void> _collectCashNow(ScanResultInfo result) async {
    try {
      final receiptNumber =
          'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

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

      await OfflineSyncService().updateStudentArrearsLocally(
        studentIdOrCode: result.code,
        amountDeducted: result.totalDue,
      );

      if (mounted) {
        setState(() {
          _lastResult = ScanResultInfo(
            studentId: result.studentId,
            name: result.name,
            code: result.code,
            parentPhone: result.parentPhone,
            totalDue: 0,
            hasDue: false,
            scannedAt: DateTime.now(),
            isOffline: result.isOffline,
          );

          final idx =
              _attendees.indexWhere((a) => a.studentId == result.studentId);
          if (idx != -1) {
            final old = _attendees[idx];
            _attendees[idx] = AttendeeItem(
              studentId: old.studentId,
              name: old.name,
              code: old.code,
              parentPhone: old.parentPhone,
              time: old.time,
              hasDue: false,
              totalDue: 0,
              isOffline: old.isOffline,
            );
          }
        });

        DigitalCashReceiptDialog.show(
          context: context,
          receiptType: ReceiptType.studentPayment,
          centerName: _centerName,
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

        if (result.parentPhone.isNotEmpty) {
          WhatsAppService.sendCashReceiptToParent(
            parentPhone: result.parentPhone,
            studentName: result.name,
            studentCode: result.code,
            receiptNo: receiptNumber,
            amountPaid: result.totalDue.toDouble(),
            purpose: 'سداد مصاريف دراسية متأخرة بالبوابة',
            centerName: _centerName,
            cashierName: 'موظف الاستقبال',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في التحصيل: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAbsentStudentsSheet() async {
    if (_selectedGroup == null) return;

    final session = _selectedSession ??
        ClassSession(
          id: 'test_session',
          groupId: _selectedGroup!.id,
          sessionDate: DateTime.now(),
          scheduledStartAt: DateTime.now(),
          scheduledEndAt: DateTime.now().add(const Duration(hours: 2)),
          status: SessionStatus.inProgress,
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AbsentStudentsModal(
        group: _selectedGroup!,
        session: session,
        presentStudentIds: _attendees.map((a) => a.studentId).toSet(),
      ),
    );
  }

  Future<void> _printGroupCards() async {
    if (_selectedGroup == null) return;

    try {
      final isOfflineGroup = _selectedGroup!.id.startsWith('offline_') ||
          !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
              .hasMatch(_selectedGroup!.id);

      List<Map<String, String>> studentsData = [];

      if (isOfflineGroup) {
        final offlineService = OfflineSyncService();
        final cached = await offlineService.getCachedStudentsDirectory();
        studentsData = cached
            .map(
              (s) => {
                'name':
                    (s['full_name'] ?? s['name'] ?? 'طالب سنتر').toString(),
                'code':
                    (s['student_code'] ?? s['code'] ?? 'STU-00').toString(),
                'phone':
                    (s['emergency_contact_phone'] ?? s['phone'] ?? '').toString(),
                'grade': _selectedGroup!.name,
              },
            )
            .toList();
      } else {
        final students =
            await _studentRepo.fetchStudentsForGroup(_selectedGroup!.id);
        studentsData = students
            .map(
              (s) => {
                'name': s.fullName,
                'code': s.studentCode,
                'phone': s.phoneNumber ?? '',
                'grade': _selectedGroup!.name,
              },
            )
            .toList();
      }

      if (studentsData.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'لا يوجد طلاب مسجلون في هذه المجموعة لطباعة الكارنيهات.',
              ),
            ),
          );
        }
        return;
      }

      await ReportGeneratorService().generateBulkStudentIdCardsPdf(
        students: studentsData,
        centerName: _centerName,
        groupName: _selectedGroup!.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'تم توليد كروت هوية طلاب مجموعة (${_selectedGroup!.name}) جاهزة للطباعة 🪪'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('فشل توليد الكارنيهات: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 780;
          final isSmallMobile = constraints.maxWidth < 520;

          return Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: const Color(0xFF0B132B),
            appBar: _buildResponsiveAppBar(isDesktop, isSmallMobile),
            body: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : Column(
                    children: [
                      // Top Session & Quick Stats Bar
                      _buildSessionControlBar(isDesktop, isSmallMobile),

                      // Manual Barcode / Student Code Quick Input Bar
                      _buildManualCodeInputBar(isDesktop, isSmallMobile),

                      // Main Content: Split on Desktop, Stack on Mobile
                      Expanded(
                        child: isDesktop
                            ? _buildDesktopSplitLayout()
                            : _buildMobileVerticalLayout(constraints),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  /// Responsive AppBar: Consolidates action buttons on mobile to avoid overflows
  PreferredSizeWidget _buildResponsiveAppBar(
      bool isDesktop, bool isSmallMobile) {
    return AppBar(
      backgroundColor: const Color(0xFF1C2541),
      elevation: 0,
      centerTitle: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'بوابة الـ QR الذكية',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_selectedGroup != null)
                  Text(
                    _selectedGroup!.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Sync / Offline Status Pill
        ValueListenableBuilder<bool>(
          valueListenable: OfflineSyncService().isOnline,
          builder: (context, isOnline, _) {
            return ValueListenableBuilder<int>(
              valueListenable: OfflineSyncService().pendingSyncCount,
              builder: (context, pendingCount, _) {
                final isSyncing = OfflineSyncService().isSyncing.value;
                if (pendingCount == 0 && isOnline) {
                  return IconButton(
                    icon: const Icon(Icons.cloud_done_rounded,
                        color: Colors.greenAccent, size: 20),
                    tooltip: 'السحابة متصلة • مزمّن 🟢',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'الاتصال ممتاز وسجلات الحضور مزمّنة سحابياً 🟢'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  );
                }
                return InkWell(
                  onTap: () async {
                    final res =
                        await OfflineSyncService().syncQueuedAttendance();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.message),
                          backgroundColor: res.success
                              ? Colors.green.shade700
                              : Colors.orange.shade800,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.amber.shade400, width: 1.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSyncing)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.amber),
                          )
                        else
                          Icon(
                            isOnline
                                ? Icons.cloud_upload_rounded
                                : Icons.cloud_off_rounded,
                            color: Colors.amber,
                            size: 14,
                          ),
                        const SizedBox(width: 4),
                        Text(
                          '$pendingCount',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),

        // Sound Beeper Toggle
        IconButton(
          icon: Icon(
            _voiceBeeperEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            color: _voiceBeeperEnabled ? Colors.greenAccent : Colors.grey,
            size: 20,
          ),
          tooltip: _voiceBeeperEnabled ? 'المنبه الصوتي مفعل 🔊' : 'صامت 🔇',
          onPressed: () {
            setState(() => _voiceBeeperEnabled = !_voiceBeeperEnabled);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_voiceBeeperEnabled
                    ? 'تم تفعيل المنبه الصوتي للبوابة 🔊'
                    : 'تم كتم المنبه الصوتي للبوابة 🔇'),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),

        // Flashlight Toggle
        IconButton(
          icon: Icon(
            _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            color: _isTorchOn ? Colors.amber : Colors.white70,
            size: 20,
          ),
          tooltip: 'الفلاش',
          onPressed: () {
            _scannerController?.toggleTorch();
            setState(() => _isTorchOn = !_isTorchOn);
          },
        ),

        // More Tools Menu (Compact for Mobile, rich items inside)
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          tooltip: 'أدوات الاستقبال السريعة',
          color: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (val) {
            switch (val) {
              case 'absents':
                _showAbsentStudentsSheet();
                break;
              case 'register_student':
                ExpressStudentRegistrationDialog.show(
                  context: context,
                  availableGroups: _groups,
                  onRegistered: (newStudent) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'تم تسجيل الطالب ${newStudent.fullName} بنجاح')),
                    );
                  },
                );
                break;
              case 'print_cards':
                _printGroupCards();
                break;
              case 'cashier':
                ExpressCashierDialog.show(
                  context: context,
                  students: _attendees
                      .map((a) => Student(
                            id: a.studentId,
                            profileId: '',
                            studentCode: a.code,
                            primaryBranchId: '',
                            status: 'active',
                            fullName: a.name,
                            email: '',
                            phoneNumber: a.parentPhone,
                          ))
                      .toList(),
                );
                break;
              case 'cash_register':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DailyCashRegisterScreen(),
                  ),
                );
                break;
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'absents',
              child: Row(
                children: [
                  Icon(Icons.person_off_rounded,
                      color: Colors.redAccent, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'كشف الغائبين والواتساب',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'register_student',
              child: Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded,
                      color: Color(0xFFF59E0B), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تسجيل طالب جديد (30 ثانية)',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'cashier',
              child: Row(
                children: [
                  Icon(Icons.attach_money_rounded,
                      color: Colors.greenAccent, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'كاشير الاستقبال السريع',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'print_cards',
              child: Row(
                children: [
                  Icon(Icons.badge_outlined, color: Colors.blueAccent, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'طباعة كارنيهات المجموعة (PDF)',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'cash_register',
              child: Row(
                children: [
                  Icon(Icons.point_of_sale_rounded,
                      color: Colors.tealAccent, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'جرد الخزينة اليومية',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Session & Group Switcher with Live Attendance Metrics
  Widget _buildSessionControlBar(bool isDesktop, bool isSmallMobile) {
    final presentCount = _attendees.length;
    final totalCount = _totalGroupStudents > 0
        ? _totalGroupStudents
        : (presentCount > 0 ? presentCount : 0);
    final percentage = totalCount > 0
        ? ((presentCount / totalCount) * 100).toInt()
        : 0;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded,
              color: AppColors.primary, size: 13),
          const SizedBox(width: 4),
          Text(
            '$presentCount حاضر',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
          if (totalCount > 0) ...[
            const SizedBox(width: 4),
            Text(
              '($percentage%)',
              style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.8),
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );

    if (isSmallMobile) {
      return Container(
        color: const Color(0xFF1E293B),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.groups_rounded,
                    color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'المجموعة:',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<GroupEntity>(
                        value: _selectedGroup,
                        dropdownColor: const Color(0xFF1E293B),
                        isExpanded: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.white70, size: 20),
                        items: _groups.map((g) {
                          return DropdownMenuItem(
                            value: g,
                            child: Text(
                              g.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (g) {
                          if (g != null) _onGroupChanged(g);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                badge,
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 6),
          const Text(
            'المجموعة:',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<GroupEntity>(
                  value: _selectedGroup,
                  dropdownColor: const Color(0xFF1E293B),
                  isExpanded: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  items: _groups.map((g) {
                    return DropdownMenuItem(
                      value: g,
                      child: Text(
                        g.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (g) {
                    if (g != null) _onGroupChanged(g);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          badge,
        ],
      ),
    );
  }

  /// Manual Barcode / Student Code Quick Input Bar
  Widget _buildManualCodeInputBar(bool isDesktop, bool isSmallMobile) {
    return Container(
      color: const Color(0xFF161F36),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallMobile ? 10 : 16,
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF0B132B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: TextField(
                controller: _manualCodeController,
                focusNode: _manualCodeFocusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitManualCode(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: InputBorder.none,
                  hintText: isSmallMobile
                      ? 'كود الطالب يدوياً...'
                      : 'أدخل كود الطالب أو الباركود يدوياً (مثال: STU-100)',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11.5,
                    fontFamily: 'Cairo',
                  ),
                  prefixIcon: const Icon(
                    Icons.keyboard_alt_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  suffixIcon: _manualCodeController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              size: 16, color: Colors.grey),
                          onPressed: () {
                            _manualCodeController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _isProcessingScan ? null : _submitManualCode,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: _isProcessingScan
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.login_rounded, size: 15),
            label: const Text(
              'تسجيل',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Mobile Vertical Stack Layout (Scanner + Recent Attendees below)
  Widget _buildMobileVerticalLayout(BoxConstraints constraints) {
    return Column(
      children: [
        // Camera Scanner Viewport
        Expanded(
          flex: 6,
          child: Stack(
            children: [
              _buildCameraOrSimulatedViewfinder(),
              _buildScannerOverlay(),
              if (_lastResult != null)
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: SingleChildScrollView(
                      child: _buildResultHudCard(_lastResult!),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Live Attendees Feed Strip
        _buildRecentAttendeesSection(isCompact: true),
      ],
    );
  }

  /// Desktop / Tablet Split-Screen Radar Layout
  Widget _buildDesktopSplitLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: Camera Scanner + Result HUD (55% width)
        Expanded(
          flex: 55,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    _buildCameraOrSimulatedViewfinder(),
                    _buildScannerOverlay(),
                  ],
                ),
              ),
              if (_lastResult != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildResultHudCard(_lastResult!),
                ),
            ],
          ),
        ),

        Container(
          width: 1,
          color: Colors.white.withValues(alpha: 0.1),
        ),

        // Right Column: Live Attendees Stream & Quick Actions (45% width)
        Expanded(
          flex: 45,
          child: _buildDesktopAttendeesSidebar(),
        ),
      ],
    );
  }

  /// Camera Viewfinder: uses real MobileScanner on devices, animated viewfinder in testMode
  Widget _buildCameraOrSimulatedViewfinder() {
    if (widget.isTestMode || _scannerController == null) {
      return Container(
        color: const Color(0xFF050B18),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                color: Colors.white.withValues(alpha: 0.3),
                size: 48,
              ),
              const SizedBox(height: 10),
              Text(
                'ماسح كاميرا الـ QR نشط 📷',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return MobileScanner(
      controller: _scannerController!,
      onDetect: _handleBarcodeScanned,
    );
  }

  /// High-Tech Scanning Overlay with Corner Brackets & Animated Laser
  Widget _buildScannerOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 80 || constraints.maxWidth < 80) {
          return const SizedBox.shrink();
        }

        const double targetSize = 240.0;
        final double boxWidth = constraints.maxWidth < targetSize
            ? constraints.maxWidth * 0.82
            : targetSize;
        final double boxHeight = constraints.maxHeight < targetSize
            ? constraints.maxHeight * 0.82
            : targetSize;
        final double boxSize = boxWidth < boxHeight ? boxWidth : boxHeight;

        return Stack(
          children: [
            // Centered Target Box
            Center(
              child: SizedBox(
                width: boxSize,
                height: boxSize,
                child: Stack(
                  children: [
                    // Outer Corner Border
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.7),
                          width: 2.0,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),

                    // Animated Glowing Laser Line
                    AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (context, _) {
                        return Positioned(
                          top: _laserAnimation.value * (boxSize - 4),
                          left: 12,
                          right: 12,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.primary,
                                  Colors.cyanAccent,
                                  AppColors.primary,
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.cyanAccent,
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Top Instruction Pill
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _isProcessingScan
                              ? 'جارِ التحقق من الكود...'
                              : 'وجّه الكاميرا نحو كود الطالب 🪪',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    // Bottom progress indicator when scanning
                    if (_isProcessingScan)
                      const Align(
                        alignment: Alignment.bottomCenter,
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(20)),
                          child: LinearProgressIndicator(
                            color: AppColors.primary,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Real-Time Scan Result HUD Card (Adaptive, Arrears Warning & WhatsApp)
  Widget _buildResultHudCard(ScanResultInfo result) {
    final hasDue = result.hasDue;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasDue ? const Color(0xFF7F1D1D) : const Color(0xFF064E3B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDue ? const Color(0xFFEF4444) : Colors.greenAccent,
          width: 1.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    hasDue ? Colors.red.shade400 : Colors.green.shade400,
                radius: 22,
                child: Icon(
                  hasDue
                      ? Icons.priority_high_rounded
                      : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.isOffline
                          ? 'كود: ${result.code} • حُفظ أوفلاين (بانتظار المزامنة) 💾'
                          : 'كود: ${result.code} • تم تسجيل الحضور بنجاح ✅',
                      style: TextStyle(
                        color: result.isOffline
                            ? Colors.amberAccent
                            : Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: result.isOffline
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                  icon: const Icon(Icons.chat, size: 18),
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

          // Arrears Warning & One-Click Instant Cash Collection
          if (hasDue) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.amberAccent, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'تنبيه مالي: على الطالب ${result.totalDue.toStringAsFixed(0)} ج.م مصاريف متأخرة!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _collectCashNow(result),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.payments_rounded, size: 16),
                    label: Text(
                      'تحصيل كاش الآن (${result.totalDue.toStringAsFixed(0)} ج.م) وإصدار إيصال',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded,
                      color: Colors.greenAccent, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'حساب الطالب مسدد بالكامل ✔️',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Recent Attendees Horizontal Feed on Mobile
  Widget _buildRecentAttendeesSection({required bool isCompact}) {
    return Container(
      height: 185,
      color: const Color(0xFF1C2541),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded,
                        color: AppColors.primary, size: 17),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'سجل الحاضرين (${_attendees.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _showAbsentStudentsSheet,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  minimumSize: const Size(0, 30),
                ),
                icon: const Icon(Icons.send_rounded,
                    size: 13, color: Colors.greenAccent),
                label: const Text(
                  'كشف الغياب',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _attendees.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_2_rounded,
                          color: Colors.grey.shade600,
                          size: 32,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'لم يتم تسجيل أي طالب بعد، ابدأ بالمسح أو الإدخال اليدوي!',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _attendees.length,
                    itemBuilder: (ctx, i) {
                      final item = _attendees[i];
                      return _buildAttendeeHorizontalCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Attendee Horizontal Card
  Widget _buildAttendeeHorizontalCard(AttendeeItem item) {
    return Container(
      width: 190,
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.hasDue
              ? Colors.red.withValues(alpha: 0.45)
              : Colors.green.withValues(alpha: 0.35),
          width: 1.2,
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
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'كود: ${item.code}',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (item.isOffline) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.cloud_off_rounded,
                            color: Colors.amber, size: 11),
                      ],
                    ],
                  ),
                  if (item.parentPhone.isNotEmpty)
                    InkWell(
                      onTap: () {
                        WhatsAppService.sendMessage(
                          phoneNumber: item.parentPhone,
                          message:
                              'تم تسجيل حضور الطالب ${item.name} بنجاح ✅ - سنتر التعليمي.',
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.chat_bubble_outline,
                            color: Colors.green, size: 15),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Bottom card row: Time and Financial Status Badge (Wrap to avoid overflow)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.time.hour}:${item.time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (item.hasDue)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'متأخر: ${item.totalDue.toStringAsFixed(0)} ج.م',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Desktop Attendance Sidebar
  Widget _buildDesktopAttendeesSidebar() {
    return Container(
      color: const Color(0xFF161F36),
      child: Column(
        children: [
          // Sidebar Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'سجل الحضور اللحظي (${_attendees.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _showAbsentStudentsSheet,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: const Text(
                    'كشف الغياب',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Attendees Vertical List
          Expanded(
            child: _attendees.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'لا يوجد طلاب حاضرون حتى الآن في هذه الجلسة',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _attendees.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final item = _attendees[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: item.hasDue
                                ? Colors.red.withValues(alpha: 0.4)
                                : Colors.green.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: item.hasDue
                                  ? Colors.red.withValues(alpha: 0.2)
                                  : Colors.green.withValues(alpha: 0.2),
                              radius: 18,
                              child: Icon(
                                item.hasDue
                                    ? Icons.priority_high_rounded
                                    : Icons.check_circle_rounded,
                                color: item.hasDue
                                    ? Colors.redAccent
                                    : Colors.greenAccent,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 2,
                                    children: [
                                      Text(
                                        'كود: ${item.code}',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      Text(
                                        '${item.time.hour}:${item.time.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (item.hasDue)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'متأخرات: ${item.totalDue.toStringAsFixed(0)} ج.م',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (item.parentPhone.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.chat,
                                    size: 16, color: Color(0xFF25D366)),
                                tooltip: 'إشعار واتساب',
                                onPressed: () {
                                  WhatsAppService.sendMessage(
                                    phoneNumber: item.parentPhone,
                                    message:
                                        'تم تسجيل حضور الطالب ${item.name} بنجاح ✅.',
                                  );
                                },
                              ),
                            ],
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

/// Modal Bottom Sheet for Viewing Absent Students & Batch WhatsApp Notices
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
      final allStudents =
          await studentRepo.fetchStudentsForGroup(widget.group.id);
      final absents = allStudents
          .where((s) => !widget.presentStudentIds.contains(s.id))
          .toList();
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
    buffer.writeln(
        '📅 التاريخ: ${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}');
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
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendWhatsAppToStudent(Student student) async {
    final phone = student.phoneNumber ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'لا يوجد رقم هاتف مسجل لولي أمر الطالب ${student.fullName}'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
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
            content: Text(
                'تم فتح محادثة واتساب لولي أمر ${student.fullName} ✅'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _sendBatchWhatsAppToAll() async {
    final pending =
        _absentStudents.where((s) => !_sentStudentIds.contains(s.id)).toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال إشعار الغياب لجميع الغائبين بالفعل!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final student = pending.first;
    await _sendWhatsAppToStudent(student);

    if (pending.length > 1 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'تم فتح محادثة ${student.fullName}. متبقي ${pending.length - 1} طلاب.'),
          backgroundColor: Colors.blueGrey,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        _absentStudents.where((s) => !_sentStudentIds.contains(s.id)).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_off_rounded,
                        color: Colors.redAccent, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'كشف الغائبين (${_absentStudents.length} طالب)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'المجموعة: ${widget.group.name} • إرسال إشعارات غياب فورية بالواتساب',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade400),
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
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _sendBatchWhatsAppToAll,
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: Text(
                        pendingCount > 0
                            ? 'إرسال واتساب للغائبين ($pendingCount)'
                            : 'تم إرسال الإشعار للجميع ✅',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _copyAbsenteesList,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('نسخ الكشف',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    )
                  : _absentStudents.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: Colors.greenAccent, size: 44),
                              SizedBox(height: 10),
                              Text(
                                'رائع! جميع طلاب المجموعة حاضرون اليوم.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _absentStudents.length,
                          separatorBuilder: (_, __) => Divider(
                            color: Colors.white.withValues(alpha: 0.08),
                            height: 1,
                          ),
                          itemBuilder: (ctx, i) {
                            final student = _absentStudents[i];
                            final isSent = _sentStudentIds.contains(student.id);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 6),
                              leading: CircleAvatar(
                                backgroundColor: isSent
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.2),
                                radius: 18,
                                child: Icon(
                                  isSent
                                      ? Icons.done_all_rounded
                                      : Icons.person_off_rounded,
                                  color: isSent
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                student.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                'كود: ${student.studentCode} • هاتف: ${student.phoneNumber ?? 'غير مسجل'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              trailing: isSent
                                  ? OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.greenAccent,
                                        side: const BorderSide(
                                            color: Colors.greenAccent),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        minimumSize: const Size(0, 30),
                                      ),
                                      icon: const Icon(Icons.check_rounded,
                                          size: 14),
                                      label: const Text('تم الإرسال',
                                          style: TextStyle(fontSize: 11)),
                                      onPressed: () =>
                                          _sendWhatsAppToStudent(student),
                                    )
                                  : FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF25D366),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        minimumSize: const Size(0, 32),
                                      ),
                                      icon: const Icon(Icons.chat, size: 14),
                                      label: const Text('واتساب',
                                          style: TextStyle(fontSize: 11.5)),
                                      onPressed: () =>
                                          _sendWhatsAppToStudent(student),
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
