import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportsDashboardViewModel extends ChangeNotifier {
  bool isLoading = false;

  List<Map<String, dynamic>> studentsData = [];
  List<Map<String, dynamic>> attendanceData = [];
  List<Map<String, dynamic>> financialData = [];
  List<Map<String, dynamic>> teacherData = [];
  List<Map<String, dynamic>> parentsData = [];
  List<Map<String, dynamic>> homeworkData = [];
  List<Map<String, dynamic>> curriculumData = [];

  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();

    try {
      final client = Supabase.instance.client;

      // 1. Students
      try {
        final stuRes = await client
            .from('students')
            .select('id, student_code, profiles(full_name)')
            .limit(100);
        studentsData = (stuRes as List).map((item) {
          final prof = item['profiles'] as Map<String, dynamic>?;
          return {
            'name': prof?['full_name'] ?? 'طالب',
            'exam_score': 0,
            'homework_score': 0,
            'missing_assignments': 0,
          };
        }).toList();
      } catch (_) {
        studentsData = [];
      }

      // 2. Attendance
      try {
        final attRes = await client
            .from('attendance')
            .select('status, date, students(profiles(full_name))')
            .limit(100);
        attendanceData = (attRes as List).map((item) {
          final stu = item['students'] as Map<String, dynamic>?;
          final prof = stu?['profiles'] as Map<String, dynamic>?;
          final isPresent = item['status'] == 'present';
          return {
            'name': prof?['full_name'] ?? 'طالب',
            'present': isPresent ? 1 : 0,
            'absent': isPresent ? 0 : 1,
            'absence_dates': !isPresent ? (item['date']?.toString() ?? '') : '',
          };
        }).toList();
      } catch (_) {
        attendanceData = [];
      }

      // 3. Financial
      try {
        final finRes = await client
            .from('receipts')
            .select('receipt_number, total_amount, payment_method, created_at, notes')
            .limit(100);
        financialData = (finRes as List).map((item) {
          return {
            'date': item['created_at']?.toString().split('T').first ?? '',
            'description': 'إيصال سداد #${item['receipt_number'] ?? ''}',
            'type': 'تحصيل',
            'amount': (item['total_amount'] as num?)?.toDouble() ?? 0.0,
            'notes': item['notes'] ?? '',
          };
        }).toList();
      } catch (_) {
        financialData = [];
      }

      // 4. Teachers
      try {
        final tchRes = await client
            .from('teachers')
            .select('id, profiles(full_name)')
            .limit(50);
        teacherData = (tchRes as List).map((item) {
          final prof = item['profiles'] as Map<String, dynamic>?;
          return {
            'name': prof?['full_name'] ?? 'معلم',
            'classes_taught': 0,
            'avg_attendance': 100.0,
          };
        }).toList();
      } catch (_) {
        teacherData = [];
      }

      // 5. Parents
      try {
        final parRes = await client
            .from('parents')
            .select('id, profiles(full_name, email)')
            .limit(50);
        parentsData = (parRes as List).map((item) {
          final prof = item['profiles'] as Map<String, dynamic>?;
          return {
            'name': prof?['full_name'] ?? 'ولي أمر',
            'students': '-',
            'email': prof?['email'] ?? '',
            'status': 'نشط',
          };
        }).toList();
      } catch (_) {
        parentsData = [];
      }

      // 6. Homework
      try {
        final hwRes = await client.from('homework').select('title, groups(name)').limit(50);
        homeworkData = (hwRes as List).map((item) {
          final grp = item['groups'] as Map<String, dynamic>?;
          return {
            'group': grp?['name'] ?? 'مجموعة',
            'total': 0,
            'completion_rate': '0%',
            'avg_score': 0,
          };
        }).toList();
      } catch (_) {
        homeworkData = [];
      }

      // 7. Curriculum
      try {
        final subRes = await client.from('subjects').select('name, code').limit(50);
        curriculumData = (subRes as List).map((item) {
          return {
            'subject': item['name'] ?? '',
            'total_modules': 0,
            'completed_modules': 0,
            'progress': '0%',
          };
        }).toList();
      } catch (_) {
        curriculumData = [];
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
