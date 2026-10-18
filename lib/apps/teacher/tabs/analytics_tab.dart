import 'package:flutter/material.dart';
import '../../../features/analytics/presentation/screens/teacher_analytics_screen.dart';
import '../../../features/analytics/presentation/widgets/at_risk_students_card.dart';

class AnalyticsTab extends StatelessWidget {
  final String profileId;
  final List<Map<String, dynamic>>? initialExams;
  final List<Map<String, dynamic>>? initialAttempts;
  final List<AtRiskStudentInfo>? initialAtRiskStudents;

  const AnalyticsTab({
    super.key,
    required this.profileId,
    this.initialExams,
    this.initialAttempts,
    this.initialAtRiskStudents,
  });

  @override
  Widget build(BuildContext context) {
    return TeacherAnalyticsScreen(
      profileId: profileId,
      initialExams: initialExams,
      initialAttempts: initialAttempts,
      initialAtRiskStudents: initialAtRiskStudents,
    );
  }
}
