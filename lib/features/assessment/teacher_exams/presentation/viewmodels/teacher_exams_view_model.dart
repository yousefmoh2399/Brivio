import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExamModel {
  final String id;
  final String title;
  final String subject;
  final String status;
  final int totalQuestions;
  final DateTime dueDate;

  ExamModel({
    required this.id,
    required this.title,
    required this.subject,
    required this.status,
    required this.totalQuestions,
    required this.dueDate,
  });
}

class QuestionBankModel {
  final String id;
  final String name;
  final String subject;
  final int questionCount;

  QuestionBankModel({
    required this.id,
    required this.name,
    required this.subject,
    required this.questionCount,
  });
}

class TeacherExamsViewModel extends ChangeNotifier {
  List<ExamModel> _exams = [];
  List<QuestionBankModel> _questionBanks = [];
  bool _isLoading = false;

  List<ExamModel> get exams => _exams;
  List<QuestionBankModel> get questionBanks => _questionBanks;
  bool get isLoading => _isLoading;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = Supabase.instance.client;

      // 1. Fetch real exams
      try {
        final examRes = await client
            .from('exams')
            .select('id, title, status, total_marks, created_at, groups(name)')
            .order('created_at', ascending: false)
            .limit(50);

        final List<ExamModel> exList = [];
        for (final item in (examRes as List)) {
          final grp = item['groups'] as Map<String, dynamic>?;
          final sub = grp?['name'] as String? ?? 'عام';
          final dtStr = item['created_at']?.toString();
          final dt = dtStr != null ? DateTime.tryParse(dtStr) ?? DateTime.now() : DateTime.now();

          exList.add(
            ExamModel(
              id: item['id'] as String,
              title: item['title'] as String? ?? 'اختبار',
              subject: sub,
              status: item['status'] as String? ?? 'منشور',
              totalQuestions: (item['total_marks'] as num?)?.toInt() ?? 10,
              dueDate: dt,
            ),
          );
        }
        _exams = exList;
      } catch (_) {
        _exams = [];
      }

      // 2. Fetch question banks or subjects
      try {
        final qbRes = await client
            .from('subjects')
            .select('id, name')
            .limit(50);

        final List<QuestionBankModel> qbList = [];
        for (final item in (qbRes as List)) {
          qbList.add(
            QuestionBankModel(
              id: item['id'] as String,
              name: 'بنك أسئلة: ${item['name']}',
              subject: item['name'] as String? ?? '',
              questionCount: 0,
            ),
          );
        }
        _questionBanks = qbList;
      } catch (_) {
        _questionBanks = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
