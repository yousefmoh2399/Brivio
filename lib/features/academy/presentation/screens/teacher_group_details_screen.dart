import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../../../core/services/report_generator_service.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../assessment/data/repositories/supabase_assessment_repositories.dart';
import '../../../assessment/domain/models/assessment_models.dart';
import '../../../attendance/data/repositories/supabase_attendance_repositories.dart';
import '../../../attendance/domain/models/attendance_models.dart';
import '../../data/repositories/supabase_academy_repositories.dart';
import '../../domain/models/academy_models.dart';

class TeacherGroupDetailsScreen extends StatefulWidget {
  final GroupEntity group;

  const TeacherGroupDetailsScreen({super.key, required this.group});

  @override
  State<TeacherGroupDetailsScreen> createState() =>
      _TeacherGroupDetailsScreenState();
}

class _TeacherGroupDetailsScreenState extends State<TeacherGroupDetailsScreen> {
  late final SupabaseStudentRepository _studentRepo;
  late final SupabaseHomeworkRepository _homeworkRepo;
  late final SupabaseExamRepository _examRepo;
  late final SupabaseClassSessionRepository _sessionRepo;

  List<Student> _enrolledStudents = [];
  List<Homework> _groupHomeworks = [];
  List<Exam> _groupExams = [];
  List<ClassSession> _groupSessions = [];

  bool _isLoading = false;
  bool _isExportingGrades = false;
  bool _isExportingAttendance = false;
  bool _isDeleting = false;

  String _studentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    final wrapper = SupabaseClientWrapper(Supabase.instance.client);
    _studentRepo = SupabaseStudentRepository(wrapper);
    _homeworkRepo = SupabaseHomeworkRepository(wrapper);
    _examRepo = SupabaseExamRepository(wrapper);
    _sessionRepo = SupabaseClassSessionRepository(wrapper);
    _loadGroupDetails();
  }

  Future<void> _loadGroupDetails() async {
    setState(() => _isLoading = true);
    try {
      final sRes = await _studentRepo.fetchStudentsForGroup(widget.group.id);
      final hwRes = await _homeworkRepo.fetchHomeworkForGroup(widget.group.id);
      final examRes = await _examRepo.fetchExamsForGroup(widget.group.id);
      final sessRes = await _sessionRepo.fetchSessionsForGroup(widget.group.id);

      if (mounted) {
        setState(() {
          _enrolledStudents = sRes;
          _groupHomeworks = hwRes;
          _groupExams = examRes;
          _groupSessions = sessRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحميل بيانات المجموعة: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _exportGradesReport() async {
    if (_isExportingGrades) return;
    setState(() => _isExportingGrades = true);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جارٍ استخراج وتجميع درجات الطلاب في المجموعة...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      final service = ReportGeneratorService();
      final studentIds = _enrolledStudents.map((s) => s.id).toList();

      List<dynamic> examAttempts = [];
      List<dynamic> hwSubmissions = [];

      if (studentIds.isNotEmpty) {
        examAttempts = await Supabase.instance.client
            .from('exam_attempts')
            .select('student_id, score')
            .filter('student_id', 'in', studentIds);

        hwSubmissions = await Supabase.instance.client
            .from('homework_submissions')
            .select('student_id, score')
            .filter('student_id', 'in', studentIds);
      }

      final data = _enrolledStudents.map((s) {
        final sExams = examAttempts
            .where((e) => e['student_id'] == s.id)
            .toList();
        final sHws = hwSubmissions
            .where((h) => h['student_id'] == s.id)
            .toList();

        final examAvg = sExams.isEmpty
            ? 0.0
            : (sExams.map((e) => e['score'] as num).reduce((a, b) => a + b) /
                  sExams.length).toDouble();
        final hwAvg = sHws.isEmpty
            ? 0.0
            : (sHws.map((h) => h['score'] as num).reduce((a, b) => a + b) /
                  sHws.length).toDouble();

        return {
          'name': s.fullName,
          'exam_score': examAvg.toStringAsFixed(1),
          'homework_score': hwAvg.toStringAsFixed(1),
          'missing_assignments': _groupHomeworks.length - sHws.length > 0
              ? _groupHomeworks.length - sHws.length
              : 0,
        };
      }).toList();

      await service.generateGradesReport(
        className: widget.group.name,
        studentsData: data,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم استخراج كشف الدرجات وحفظه بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تصدير التقرير: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingGrades = false);
    }
  }

  Future<void> _exportAttendanceReport() async {
    if (_isExportingAttendance) return;
    setState(() => _isExportingAttendance = true);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جارٍ جمع بيانات الحضور والغياب للطلاب...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      final service = ReportGeneratorService();
      final studentIds = _enrolledStudents.map((s) => s.id).toList();

      List<dynamic> attendance = [];
      if (studentIds.isNotEmpty) {
        attendance = await Supabase.instance.client
            .from('attendance')
            .select('student_id, date, status')
            .filter('student_id', 'in', studentIds);
      }

      final data = _enrolledStudents.map((s) {
        final sAtt = attendance.where((a) => a['student_id'] == s.id).toList();
        final presentCount = sAtt.where((a) => a['status'] == 'present').length;
        final absentCount = sAtt.where((a) => a['status'] == 'absent').length;
        final absentDates = sAtt
            .where((a) => a['status'] == 'absent')
            .map((a) => a['date'])
            .join('، ');

        return {
          'name': s.fullName,
          'present': presentCount,
          'absent': absentCount,
          'absence_dates': absentDates.isEmpty ? 'لا يوجد غياب' : absentDates,
        };
      }).toList();

      await service.generateAttendanceReport(
        className: widget.group.name,
        attendanceData: data,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم استخراج سجل الحضور والغياب بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تصدير تقرير الحضور: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingAttendance = false);
    }
  }

  Future<void> _confirmDeleteGroup() async {
    if (_isDeleting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('حذف المجموعة نهائياً'),
          ],
        ),
        content: Text(
          'هل أنت متأكد تماماً من رغبتك في حذف مجموعة "${widget.group.name}"؟\n'
          'سيتم إزالة ارتباط الطلاب والواجبات والجداول المسجلة بهذه المجموعة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);
      try {
        await Supabase.instance.client.rpc(
          'delete_group',
          params: {'group_id': widget.group.id},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف المجموعة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل حذف المجموعة: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteHomework(Homework homework) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('حذف الواجب'),
          ],
        ),
        content: Text('هل أنت متأكد من حذف الواجب "${homework.title}" نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _homeworkRepo.deleteHomework(homework.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الواجب بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          _loadGroupDetails();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ أثناء حذف الواجب: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteExam(Exam exam) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('حذف الامتحان'),
          ],
        ),
        content: Text('هل أنت متأكد من حذف امتحان "${exam.title}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _examRepo.deleteExam(exam.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الامتحان بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          _loadGroupDetails();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ أثناء حذف الامتحان: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              'مجموعة: ${widget.group.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'تحديث البيانات',
                onPressed: _isLoading ? null : _loadGroupDetails,
              ),
              IconButton(
                icon: _isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever, color: Colors.redAccent),
                tooltip: 'حذف المجموعة',
                onPressed: _isDeleting ? null : _confirmDeleteGroup,
              ),
            ],
            bottom: const TabBar(
              isScrollable: true,
              indicatorWeight: 3,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(icon: Icon(Icons.dashboard_outlined), text: 'نظرة عامة'),
                Tab(icon: Icon(Icons.people_alt_outlined), text: 'الطلاب'),
                Tab(icon: Icon(Icons.assignment_outlined), text: 'الواجبات'),
                Tab(icon: Icon(Icons.quiz_outlined), text: 'الامتحانات'),
                Tab(icon: Icon(Icons.fact_check_outlined), text: 'سجل الحضور'),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('جارٍ تحميل تفاصيل المجموعة والطلاب...'),
                    ],
                  ),
                )
              : TabBarView(
                  children: [
                    _buildOverviewTab(),
                    _buildStudentsTab(),
                    _buildHomeworkTab(),
                    _buildExamsTab(),
                    _buildAttendanceTab(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final maxCap = widget.group.maxCapacity;
    final enrolledCount = _enrolledStudents.length;
    final occupancyPercent =
        maxCap != null && maxCap > 0 ? (enrolledCount / maxCap).clamp(0.0, 1.0) : 0.0;
    final isFull = maxCap != null && enrolledCount >= maxCap;

    return RefreshIndicator(
      onRefresh: _loadGroupDetails,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: FadeInSlide(
          duration: const Duration(milliseconds: 350),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main Card Info
              GlassCard(
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor:
                              AppColors.teacherRole.withValues(alpha: 0.15),
                          child: const Icon(
                            Icons.groups,
                            color: AppColors.teacherRole,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.group.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.blue.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      'كود: ${widget.group.code}',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: widget.group.status.toLowerCase() ==
                                              'active'
                                          ? Colors.green.withValues(alpha: 0.12)
                                          : Colors.grey.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      widget.group.status.toLowerCase() ==
                                              'active'
                                          ? 'المجموعة نشطة'
                                          : 'مؤرشفة',
                                      style: TextStyle(
                                        color: widget.group.status
                                                    .toLowerCase() ==
                                                'active'
                                            ? Colors.green
                                            : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // Capacity Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'سعة المجموعة والاشتراكات:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          maxCap != null
                              ? '$enrolledCount / $maxCap طالب'
                              : '$enrolledCount طالب (غير محدودة)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isFull ? Colors.redAccent : Colors.white,
                          ),
                        ),
                      ],
                    ),
                    if (maxCap != null && maxCap > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: occupancyPercent,
                          minHeight: 8,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isFull
                                ? Colors.redAccent
                                : occupancyPercent > 0.8
                                    ? Colors.orangeAccent
                                    : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // KPI Counters Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.people_alt,
                      color: AppColors.primary,
                      title: 'الطلاب المقيدين',
                      value: '${_enrolledStudents.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.assignment_turned_in,
                      color: Colors.orangeAccent,
                      title: 'الواجبات المنشورة',
                      value: '${_groupHomeworks.length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.quiz,
                      color: Colors.purpleAccent,
                      title: 'الامتحانات والكويزات',
                      value: '${_groupExams.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.event_available,
                      color: Colors.greenAccent,
                      title: 'الحصص المجدولة',
                      value: '${_groupSessions.length}',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Reports Export Actions
              Text(
                'التقارير وسجلات المجموعة',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: 0.15),
                          child: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.blue,
                          ),
                        ),
                        title: const Text(
                          'تصدير كشف درجات الطلاب',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'تقرير PDF يحتوي على درجات الواجبات والامتحانات والتقييم',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed:
                              _isExportingGrades ? null : _exportGradesReport,
                          icon: _isExportingGrades
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download, size: 18),
                          label: const Text('تصدير PDF'),
                        ),
                      ),
                      const Divider(height: 16),
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.withValues(alpha: 0.15),
                          child: const Icon(
                            Icons.fact_check,
                            color: Colors.green,
                          ),
                        ),
                        title: const Text(
                          'تصدير سجل الحضور والغياب',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'تقرير PDF شامل لنسب حضور الطلاب ومواعيد الغياب',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: _isExportingAttendance
                              ? null
                              : _exportAttendanceReport,
                          icon: _isExportingAttendance
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download, size: 18),
                          label: const Text('تصدير PDF'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsTab() {
    final filtered = _enrolledStudents.where((s) {
      if (_studentSearchQuery.isEmpty) return true;
      final q = _studentSearchQuery.toLowerCase();
      return s.fullName.toLowerCase().contains(q) ||
          s.studentCode.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'بحث باسم الطالب، الكود، أو البريد...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _studentSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          setState(() => _studentSearchQuery = ''),
                    )
                  : null,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (val) => setState(() => _studentSearchQuery = val),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_off_outlined,
                        size: 64,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _studentSearchQuery.isEmpty
                            ? 'لا يوجد طلاب مقيدين في هذه المجموعة حتى الآن'
                            : 'لا توجد نتائج مطابقة لبحثك',
                        style: const TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final s = filtered[i];
                    return Card(
                      elevation: 0,
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            s.fullName.isNotEmpty
                                ? s.fullName.characters.first.toUpperCase()
                                : 'ط',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          s.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('كود الطالب: ${s.studentCode}'),
                            if (s.email.isNotEmpty)
                              Text(
                                'البريد: ${s.email}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'طالب منتظم',
                            style: TextStyle(
                              color: Colors.blue[300],
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHomeworkTab() {
    if (_groupHomeworks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد واجبات منشورة لهذه المجموعة بعد',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: _groupHomeworks.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final h = _groupHomeworks[i];
        final isClosed = h.status.toLowerCase() == 'closed';
        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          Colors.orangeAccent.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.assignment_outlined,
                        color: Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (h.description != null &&
                              h.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              h.description!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isClosed
                            ? Colors.grey.withValues(alpha: 0.15)
                            : Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isClosed ? 'مغلق ومكتمل' : 'متاح للتسليم',
                        style: TextStyle(
                          color: isClosed ? Colors.grey : Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'التسليم: ${_formatDate(h.dueAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.star_outline,
                          size: 15,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'الدرجة: ${h.maxScore}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 20),
                      tooltip: 'حذف الواجب',
                      onPressed: () => _deleteHomework(h),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExamsTab() {
    if (_groupExams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد امتحانات مخصصة لهذه المجموعة حالياً',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: _groupExams.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final exam = _groupExams[i];
        final isClosed = exam.status.toLowerCase() == 'closed';
        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          Colors.purpleAccent.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.quiz,
                        color: Colors.purpleAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exam.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (exam.description != null &&
                              exam.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              exam.description!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isClosed
                            ? Colors.grey.withValues(alpha: 0.15)
                            : Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isClosed ? 'مغلق' : 'منشور ونشط',
                        style: TextStyle(
                          color: isClosed ? Colors.grey : Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Wrap(
                      spacing: 12,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${exam.durationMinutes} دقيقة',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.help_outline,
                              size: 14,
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${exam.questions.length} سؤال',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.grade_outlined,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'النجاح من: ${exam.passScore}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      tooltip: 'حذف الامتحان',
                      onPressed: () => _deleteExam(exam),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceTab() {
    if (_groupSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد حصص مسجلة أو مجدولة لهذه المجموعة بعد',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: _groupSessions.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final sess = _groupSessions[i];
        final statusLabel = switch (sess.status) {
          SessionStatus.scheduled => 'مجدولة',
          SessionStatus.inProgress => 'جارية الآن',
          SessionStatus.completed => 'مكتملة',
          SessionStatus.cancelled => 'ملغاة',
        };
        final statusColor = switch (sess.status) {
          SessionStatus.scheduled => Colors.blue,
          SessionStatus.inProgress => Colors.orangeAccent,
          SessionStatus.completed => Colors.green,
          SessionStatus.cancelled => Colors.redAccent,
        };

        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Icon(Icons.event_note, color: statusColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sess.location ?? 'القاعة الرئيسية',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تاريخ الحصة: ${_formatDate(sess.sessionDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
