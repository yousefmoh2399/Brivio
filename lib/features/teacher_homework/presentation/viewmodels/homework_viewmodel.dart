import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/homework_models.dart';

class HomeworkViewModel extends ChangeNotifier {
  final List<HomeworkAssignment> _assignments = [];
  final List<HomeworkSubmission> _submissions = [];
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<HomeworkAssignment> get assignments => _assignments;

  HomeworkViewModel() {
    loadAssignments();
  }

  Future<void> loadAssignments() async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('homework')
          .select('id, title, description, due_date, groups(name)')
          .order('due_date', ascending: false);

      _assignments.clear();
      for (final item in (res as List)) {
        final grp = item['groups'] as Map<String, dynamic>?;
        final grpName = grp?['name'] as String? ?? 'عام';
        final dueStr = item['due_date']?.toString();
        final due = dueStr != null ? DateTime.tryParse(dueStr) ?? DateTime.now() : DateTime.now();

        _assignments.add(
          HomeworkAssignment(
            id: item['id'] as String,
            title: item['title'] as String? ?? 'واجب منزلي',
            description: item['description'] as String? ?? '',
            dueDate: due,
            assignedClasses: [grpName],
            totalPoints: 100,
          ),
        );
      }
    } catch (_) {
      // Keep empty if query fails or table empty
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<HomeworkSubmission> getSubmissionsForAssignment(String assignmentId) {
    return _submissions.where((s) => s.assignmentId == assignmentId).toList();
  }

  void createAssignment({
    required String title,
    required String description,
    required DateTime dueDate,
    required List<String> assignedClasses,
    required int totalPoints,
  }) {
    final newAssignment = HomeworkAssignment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      dueDate: dueDate,
      assignedClasses: assignedClasses,
      totalPoints: totalPoints,
    );
    _assignments.insert(0, newAssignment);
    notifyListeners();
  }

  void gradeSubmission(String submissionId, int score, String feedback) {
    final index = _submissions.indexWhere((s) => s.id == submissionId);
    if (index != -1) {
      final old = _submissions[index];
      _submissions[index] = HomeworkSubmission(
        id: old.id,
        assignmentId: old.assignmentId,
        studentId: old.studentId,
        studentName: old.studentName,
        submittedAt: old.submittedAt,
        fileUrl: old.fileUrl,
        score: score,
        teacherFeedback: feedback,
      );
      notifyListeners();
    }
  }
}
