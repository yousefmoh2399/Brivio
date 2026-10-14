import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/attendance_models.dart';

class FastAttendanceStudent {
  final String id;
  final String name;
  final String? avatarUrl;
  AttendanceStatus? status;
  String? incidentRecord;

  FastAttendanceStudent({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.status,
    this.incidentRecord,
  });
}

class FastAttendanceViewModel extends ChangeNotifier {
  List<FastAttendanceStudent> students = [];
  bool isLoading = false;

  FastAttendanceViewModel() {
    loadStudents();
  }

  Future<void> loadStudents({String? groupId}) async {
    isLoading = true;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('students')
          .select('id, profiles(full_name, avatar_url)')
          .limit(100);

      final List<FastAttendanceStudent> list = [];
      for (final item in (res as List)) {
        final prof = item['profiles'] as Map<String, dynamic>?;
        final name = (prof?['full_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          list.add(
            FastAttendanceStudent(
              id: item['id'] as String,
              name: name,
              avatarUrl: prof?['avatar_url'] as String?,
              status: AttendanceStatus.present,
            ),
          );
        }
      }
      students = list;
    } catch (_) {
      students = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void markAttendance(String studentId, AttendanceStatus status) {
    final index = students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      students[index].status = status;
      notifyListeners();
    }
  }

  void logIncident(String studentId, String incident) {
    final index = students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      students[index].incidentRecord = incident;
      notifyListeners();
    }
  }

  Future<void> submitAttendance() async {
    isLoading = true;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      final nowStr = DateTime.now().toIso8601String().split('T').first;
      for (final s in students) {
        if (s.status != null) {
          await client.from('attendance').insert({
            'student_id': s.id,
            'date': nowStr,
            'status': s.status == AttendanceStatus.present
                ? 'present'
                : (s.status == AttendanceStatus.absent ? 'absent' : 'late'),
            'notes': s.incidentRecord,
          });
        }
      }
    } catch (_) {
      // Best-effort insert
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
