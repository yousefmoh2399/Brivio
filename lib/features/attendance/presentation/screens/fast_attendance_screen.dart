import 'package:flutter/material.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../../domain/models/attendance_models.dart';
import '../viewmodels/fast_attendance_viewmodel.dart';

class FastAttendanceScreen extends StatefulWidget {
  const FastAttendanceScreen({super.key});

  @override
  State<FastAttendanceScreen> createState() => _FastAttendanceScreenState();
}

class _FastAttendanceScreenState extends State<FastAttendanceScreen> {
  final FastAttendanceViewModel _viewModel = FastAttendanceViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChange);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChange);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelChange() {
    setState(() {});
  }

  void _showIncidentDialog(FastAttendanceStudent student) {
    final controller = TextEditingController(text: student.incidentRecord);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'تسجيل ملاحظة / سلوك للطالب: ${student.name}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'اكتب وصف الملاحظة أو سبب التأخير...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                _viewModel.logIncident(student.id, controller.text.trim());
                Navigator.pop(context);
              },
              child: const Text('حفظ الملاحظة'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('تسجيل الحضور السريع ⚡'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _viewModel.loadStudents(),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'اسحب لليمين لتسجيل الطالب (حاضر 🟢) أو لليسار (غائب 🔴)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _viewModel.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _viewModel.students.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline_rounded, size: 56, color: textSecondary),
                                const SizedBox(height: 16),
                                Text(
                                  'لا يوجد طلاب مسجلون حالياً',
                                  style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'أضف طلاب في النظام أولاً لتتمكن من تسجيل الحضور السريع.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodySmall(textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _viewModel.students.length,
                            itemBuilder: (context, index) {
                              final student = _viewModel.students[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Dismissible(
                                  key: ValueKey(student.id),
                                  background: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.success,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                                        SizedBox(width: 8),
                                        Text('حاضر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  secondaryBackground: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text('غائب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        SizedBox(width: 8),
                                        Icon(Icons.cancel_rounded, color: Colors.white, size: 28),
                                      ],
                                    ),
                                  ),
                                  confirmDismiss: (direction) async {
                                    if (direction == DismissDirection.startToEnd) {
                                      _viewModel.markAttendance(
                                        student.id,
                                        AttendanceStatus.present,
                                      );
                                    } else if (direction == DismissDirection.endToStart) {
                                      _viewModel.markAttendance(
                                        student.id,
                                        AttendanceStatus.absent,
                                      );
                                    }
                                    return false;
                                  },
                                  child: GlassCard(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AppColors.primarySubtle,
                                          radius: 20,
                                          child: Text(
                                            student.name.isNotEmpty
                                                ? student.name.substring(0, 1)
                                                : '?',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                student.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.titleSmall(textPrimary).copyWith(fontWeight: FontWeight.bold),
                                              ),
                                              if (student.incidentRecord != null &&
                                                  student.incidentRecord!.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    'ملاحظة: ${student.incidentRecord}',
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: AppTypography.bodySmall(AppColors.error),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (student.status != null)
                                          _AttendanceStatusPill(
                                            status: student.status!,
                                          ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.note_alt_outlined),
                                          color: Colors.amber.shade800,
                                          tooltip: 'إضافة ملاحظة',
                                          onPressed: () => _showIncidentDialog(student),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 16),
              if (_viewModel.students.isNotEmpty)
                FilledButton.icon(
                  onPressed: _viewModel.isLoading
                      ? null
                      : () async {
                          await _viewModel.submitAttendance();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم حفظ واعتماد الحضور بنجاح!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            Navigator.pop(context);
                          }
                        },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: _viewModel.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('اعتماد وحفظ الحضور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceStatusPill extends StatelessWidget {
  final AttendanceStatus status;

  const _AttendanceStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPresent = status == AttendanceStatus.present;
    final color = isPresent ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isPresent ? 'حاضر' : 'غائب',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
