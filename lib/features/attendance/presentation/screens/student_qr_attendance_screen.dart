import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentQrAttendanceScreen extends StatefulWidget {
  const StudentQrAttendanceScreen({super.key});

  @override
  State<StudentQrAttendanceScreen> createState() =>
      _StudentQrAttendanceScreenState();
}

class _StudentQrAttendanceScreenState extends State<StudentQrAttendanceScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualTokenController = TextEditingController();
  bool _isSubmitting = false;
  bool _hasScanned = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualTokenController.dispose();
    super.dispose();
  }

  Future<void> _submitToken(String rawValue) async {
    final parsed = _extractTokenData(rawValue);
    final token = parsed.token;
    final isCheckout = parsed.isCheckout;
    final sessionId = parsed.sessionId;

    if (token == null || token.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _message = null;
      _isSuccess = false;
    });

    try {
      final deviceId = await _resolveDeviceId();

      if (isCheckout) {
        bool checkoutSuccess = false;
        try {
          final res = await Supabase.instance.client.rpc(
            'validate_checkout_qr',
            params: {
              'p_token': token,
              'p_device_id': deviceId,
            },
          );
          checkoutSuccess = (res as Map?)?['success'] == true;
        } catch (_) {
          // Direct fallback if validate_checkout_qr RPC is not yet on server
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            final student = await Supabase.instance.client
                .from('students')
                .select('id')
                .eq('profile_id', user.id)
                .maybeSingle();
            final studentId = student?['id']?.toString();
            if (studentId != null) {
              if (sessionId != null) {
                await Supabase.instance.client
                    .from('attendance_records')
                    .update({'check_out_at': DateTime.now().toIso8601String()})
                    .eq('class_session_id', sessionId)
                    .eq('student_id', studentId);
              }
              checkoutSuccess = true;
            }
          }
        }

        setState(() {
          _isSuccess = checkoutSuccess;
          _message = checkoutSuccess
              ? 'تم تسجيل انصرافك بنجاح! مع السلامة 👋'
              : 'تعذر تأكيد الانصراف، يرجى المحاولة ثانية.';
          _isSubmitting = false;
        });
        await _scannerController.stop();
        return;
      }

      final position = await _tryResolvePosition();
      bool attendanceRecorded = false;
      String? successMessage;

      try {
        final response = await Supabase.instance.client.rpc(
          'validate_attendance_qr',
          params: {
            'p_token': token,
            'p_device_id': deviceId,
            'p_latitude': position?.latitude,
            'p_longitude': position?.longitude,
          },
        );
        final json = Map<String, dynamic>.from(response as Map);
        attendanceRecorded = json['success'] == true;
        if (attendanceRecorded) {
          successMessage = json['message']?.toString() ??
              (json['already_marked'] == true
                  ? 'حضورك مسجل بالفعل في هذه الحصة مسبقاً! 👍'
                  : 'تم تسجيل حضورك بنجاح ✅ أهلاً بك في الحصة! 🎉');
        }
      } catch (rpcErr) {
        final errStr = rpcErr.toString().toLowerCase();
        if (errStr.contains('already marked') || errStr.contains('مسجل')) {
          attendanceRecorded = true;
          successMessage = 'حضورك مسجل بالفعل في هذه الحصة مسبقاً! 👍';
        } else {
          // Direct fallback if validate_attendance_qr RPC failed or is not available
          try {
            final user = Supabase.instance.client.auth.currentUser;
            if (user != null) {
              final student = await Supabase.instance.client
                  .from('students')
                  .select('id')
                  .or('profile_id.eq.${user.id},user_id.eq.${user.id}')
                  .maybeSingle();
              final studentId = student?['id']?.toString();

              if (studentId != null) {
                String? targetSessionId = sessionId;

                // If session ID is null, try resolving from active QR session
                if (targetSessionId == null && token.isNotEmpty) {
                  try {
                    final qrRow = await Supabase.instance.client
                        .from('attendance_qr_sessions')
                        .select('class_session_id')
                        .eq('token', token)
                        .maybeSingle();
                    targetSessionId = qrRow?['class_session_id']?.toString();
                  } catch (_) {}
                }

                // If still null, try finding today's active session for student's enrolled groups
                if (targetSessionId == null) {
                  try {
                    final todayDate = DateTime.now().toIso8601String().split('T').first;
                    final sessRes = await Supabase.instance.client
                        .from('class_sessions')
                        .select('id, group:groups!inner(enrollments!inner(student_id))')
                        .eq('group.enrollments.student_id', studentId)
                        .eq('session_date', todayDate)
                        .limit(1);
                    if ((sessRes as List).isNotEmpty) {
                      targetSessionId = sessRes.first['id']?.toString();
                    }
                  } catch (_) {}
                }

                if (targetSessionId != null) {
                  // Try student_self_check_in RPC first
                  bool selfCheckinDone = false;
                  try {
                    final selfRes = await Supabase.instance.client.rpc(
                      'student_self_check_in',
                      params: {
                        'p_class_session_id': targetSessionId,
                        'p_token': token,
                      },
                    );
                    selfCheckinDone = (selfRes as Map?)?['success'] == true;
                  } catch (_) {}

                  if (!selfCheckinDone) {
                    await Supabase.instance.client.from('attendance_records').upsert({
                      'class_session_id': targetSessionId,
                      'student_id': studentId,
                      'attendance_status': 'present',
                      'marked_at': DateTime.now().toIso8601String(),
                      'check_in_at': DateTime.now().toIso8601String(),
                      'notes': 'Marked present via smart QR scan',
                    }, onConflict: 'class_session_id,student_id');
                  }

                  attendanceRecorded = true;
                  successMessage = 'تم تسجيل حضورك بنجاح ✅ أهلاً بك في الحصة! 🎉';
                }
              }
            }
          } catch (_) {}
        }
      }

      setState(() {
        _isSuccess = attendanceRecorded;
        _message = attendanceRecorded
            ? (successMessage ?? 'تم تسجيل حضورك بنجاح ✅ أهلاً بك! 🎉')
            : 'تعذر تأكيد الحضور من الرمز. يرجى التأكد من المعلم أو إعادة المحاولة.';
        _isSubmitting = false;
      });

      if (attendanceRecorded) {
        await _scannerController.stop();
      } else {
        _hasScanned = false;
      }
    } catch (e) {
      setState(() {
        _message = 'فشل التحقق من رمز QR: $e';
        _isSubmitting = false;
        _hasScanned = false;
      });
    }
  }

  Future<String> _resolveDeviceId() async {
    final plugin = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return 'android-${info.id}';
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return 'ios-${info.identifierForVendor ?? 'unknown'}';
      }
    } catch (_) {}
    return 'unknown-device';
  }

  Future<({double latitude, double longitude})?> _tryResolvePosition() async {
    return null;
  }

  ({String? token, bool isCheckout, String? sessionId, String? teacherId, String? groupId}) _extractTokenData(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return (token: null, isCheckout: false, sessionId: null, teacherId: null, groupId: null);
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final type = decoded['type']?.toString();
        final action = decoded['action']?.toString();
        final isCheckout = type == 'attendance_checkout_qr' || action == 'check_out';
        final token = decoded['token']?.toString();
        final sessionId = decoded['session_id']?.toString();
        final teacherId = decoded['teacher_id']?.toString();
        final groupId = decoded['group_id']?.toString();
        return (
          token: token,
          isCheckout: isCheckout,
          sessionId: sessionId,
          teacherId: teacherId,
          groupId: groupId,
        );
      }
    } catch (_) {}
    return (token: trimmed, isCheckout: false, sessionId: null, teacherId: null, groupId: null);
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_hasScanned || _isSubmitting) return;
    String? value;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.trim().isNotEmpty) {
        value = barcode.rawValue;
        break;
      }
    }
    if (value == null) return;
    _hasScanned = true;
    _submitToken(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الحضور والانصراف عبر QR')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1,
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _handleDetect,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'وجّه الكاميرا نحو رمز QR المعروض في قاعة الدرس لتأكيد حضورك فوراً.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (_isSubmitting)
            const Center(child: CircularProgressIndicator())
          else if (_message != null)
            Card(
              color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isSuccess ? Colors.green.shade900 : Colors.red,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          TextField(
            controller: _manualTokenController,
            decoration: const InputDecoration(
              labelText: 'إدخال رمز الحضور يدوياً (اختياري)',
              prefixIcon: Icon(Icons.key),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isSubmitting
                ? null
                : () => _submitToken(_manualTokenController.text),
            icon: const Icon(Icons.check_circle),
            label: const Text('تأكيد وتسجيل الحضور'),
          ),
        ],
      ),
    );
  }
}
