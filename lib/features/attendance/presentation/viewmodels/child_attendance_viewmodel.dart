import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceRecord {
  final DateTime date;
  final String status; // 'present', 'absent', 'late'
  final String? note;

  AttendanceRecord({required this.date, required this.status, this.note});
}

class BehaviorRecord {
  final DateTime date;
  final String type; // 'positive', 'negative'
  final String description;
  final String teacher;

  BehaviorRecord({
    required this.date,
    required this.type,
    required this.description,
    required this.teacher,
  });
}

class ChildAttendanceViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<AttendanceRecord> _attendanceRecords = [];
  List<AttendanceRecord> get attendanceRecords => _attendanceRecords;

  List<BehaviorRecord> _behaviorRecords = [];
  List<BehaviorRecord> get behaviorRecords => _behaviorRecords;

  // Stats
  int get totalAbsences =>
      _attendanceRecords.where((r) => r.status == 'absent').length;
  int get totalTardiness =>
      _attendanceRecords.where((r) => r.status == 'late').length;

  ChildAttendanceViewModel() {
    loadAttendanceData();
  }

  Future<void> loadAttendanceData({String? studentId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      final filter = client.from('attendance').select('date, status, notes');
      final res = await (studentId != null
          ? filter.eq('student_id', studentId).order('date', ascending: false).limit(30)
          : filter.order('date', ascending: false).limit(30));
      final List<AttendanceRecord> attList = [];
      for (final item in (res as List)) {
        final dateStr = item['date']?.toString();
        final dt = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();
        final st = item['status']?.toString() ?? 'present';
        final nt = item['notes']?.toString();
        attList.add(AttendanceRecord(date: dt, status: st, note: nt));
      }
      _attendanceRecords = attList;
      _behaviorRecords = [];
    } catch (_) {
      _attendanceRecords = [];
      _behaviorRecords = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
