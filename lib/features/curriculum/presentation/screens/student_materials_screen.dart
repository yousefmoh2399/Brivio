import 'package:flutter/material.dart';

import '../../../../core/services/offline_sync_service.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';
import '../widgets/watermarked_material_viewer.dart';

class StudentMaterialsScreen extends StatefulWidget {
  final String studentName;
  final String studentCode;
  final String studentPhone;
  final String centerName;

  const StudentMaterialsScreen({
    super.key,
    this.studentName = 'أحمد محمود مصطفى',
    this.studentCode = 'STU-108',
    this.studentPhone = '01011122233',
    this.centerName = 'سنتر الأوائل التعليمي',
  });

  @override
  State<StudentMaterialsScreen> createState() => _StudentMaterialsScreenState();
}

class _StudentMaterialsScreenState extends State<StudentMaterialsScreen> {
  String _selectedSubject = 'الكل';
  Set<String> _downloadedIds = {'mat-1'};

  final List<Map<String, dynamic>> _materials = [
    {
      'id': 'mat-1',
      'title': 'مذكرة قوانين أوم وكيرشوف والشرح التفصيلي',
      'subject': 'فيزياء',
      'teacher': 'أ. محمد عبد الله',
      'pages_count': 24,
      'file_size': '3.8 MB',
      'is_locked': false,
      'is_paid': true,
      'attended': true,
      'date': '2026-10-10',
    },
    {
      'id': 'mat-2',
      'title': 'ملزمة مسائل الديناميكا وقوانين نيوتن (المستوى المتقدم)',
      'subject': 'رياضيات',
      'teacher': 'أ. أحمد الشناوي',
      'pages_count': 32,
      'file_size': '5.1 MB',
      'is_locked': false,
      'is_paid': true,
      'attended': true,
      'date': '2026-10-12',
    },
    {
      'id': 'mat-3',
      'title': 'شيت تدريبات الكيمياء العضوية وتسمية المركبات',
      'subject': 'كيمياء',
      'teacher': 'أ. محمود رضوان',
      'pages_count': 18,
      'file_size': '2.9 MB',
      'is_locked': true,
      'is_paid': false,
      'attended': false,
      'lock_reason': 'تتطلب حضور الحصة وسداد الرسوم كاش عند الاستقبال',
      'date': '2026-10-14',
    },
    {
      'id': 'mat-4',
      'title': 'مذكرة القواعد النحوية الشاملة وبلاغة الثانوية',
      'subject': 'لغة عربية',
      'teacher': 'أ. طارق عبد العزيز',
      'pages_count': 40,
      'file_size': '6.4 MB',
      'is_locked': true,
      'is_paid': false,
      'attended': true,
      'lock_reason': 'تتطلب سداد الرسوم الشهرية بالخزينة',
      'date': '2026-10-15',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDownloadedStatus();
  }

  Future<void> _loadDownloadedStatus() async {
    final offlineService = OfflineSyncService();
    await offlineService.init(startWatcher: false);
    final ids = await offlineService.getDownloadedMaterialIds();
    if (mounted) {
      setState(() {
        if (ids.isNotEmpty) {
          _downloadedIds = ids;
        } else {
          // Default preload demo item for instant offline test
          _downloadedIds = {'mat-1'};
          offlineService.setMaterialDownloaded('mat-1', true);
        }
      });
    }
  }

  Future<void> _toggleDownload(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    final isCurrentlyDownloaded = _downloadedIds.contains(id);
    final offlineService = OfflineSyncService();

    if (isCurrentlyDownloaded) {
      await offlineService.setMaterialDownloaded(id, false);
      if (mounted) {
        setState(() => _downloadedIds.remove(id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف مذكرة "${item['title']}" من ذاكرة الجهاز المحلية.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await offlineService.setMaterialDownloaded(id, true);
      if (mounted) {
        setState(() => _downloadedIds.add(id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تنزيل مذكرة "${item['title']}" بنجاح! أصبحت متاحة للقراءة بدون إنترنت 💾'),
            backgroundColor: Colors.teal.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final subjects = ['الكل', 'المحفوظة أوفلاين 📥', 'فيزياء', 'رياضيات', 'كيمياء', 'لغة عربية'];

    final filtered = _selectedSubject == 'الكل'
        ? _materials
        : (_selectedSubject == 'المحفوظة أوفلاين 📥'
            ? _materials.where((m) => _downloadedIds.contains(m['id'])).toList()
            : _materials.where((m) => m['subject'] == _selectedSubject).toList());

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('مكتبة الملازم والمذكرات 📚'),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.offline_pin_rounded, color: Colors.teal, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${_downloadedIds.length} أوفلاين',
                  style: const TextStyle(color: Colors.teal, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Security Alert Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.blue.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'المذكرات الرقمية محمية بعلامة مائية أمنية وتدعم القراءة بدون إنترنت.',
                    style: TextStyle(fontSize: 11.5, color: textPrimary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Subject filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: subjects.map((subj) {
                final isSelected = _selectedSubject == subj;
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ChoiceChip(
                    label: Text(subj),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedSubject = subj);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // List of Materials
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _selectedSubject == 'المحفوظة أوفلاين 📥'
                          ? 'لم تقم بتنزيل أي مذكرات للقراءة بدون إنترنت بعد'
                          : 'لا توجد مذكرات متاحة حالياً في هذه المادة',
                      style: TextStyle(color: textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      final isLocked = item['is_locked'] == true;
                      final isDownloaded = _downloadedIds.contains(item['id']);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          borderColor: isLocked
                              ? Colors.grey.withValues(alpha: 0.3)
                              : AppColors.primary.withValues(alpha: 0.3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isLocked
                                          ? Colors.grey.withValues(alpha: 0.15)
                                          : (isDownloaded
                                              ? Colors.teal.withValues(alpha: 0.15)
                                              : AppColors.primary.withValues(alpha: 0.12)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isLocked
                                          ? Icons.lock_rounded
                                          : (isDownloaded ? Icons.offline_pin_rounded : Icons.menu_book_rounded),
                                      color: isLocked
                                          ? Colors.grey
                                          : (isDownloaded ? Colors.teal : AppColors.primary),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Wrap(
                                              spacing: 6,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isLocked
                                                        ? Colors.grey.withValues(alpha: 0.2)
                                                        : Colors.green.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    isLocked ? 'مغلقة 🔒' : 'متاحة للقراءة 📖',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: isLocked ? Colors.grey.shade700 : Colors.green.shade800,
                                                    ),
                                                  ),
                                                ),
                                                if (isDownloaded && !isLocked)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.teal.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'محفوظة أوفلاين 💾',
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.teal,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            Text(
                                              '${item['file_size']} • ${item['pages_count']} صفحة',
                                              style: TextStyle(fontSize: 10, color: textSecondary),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item['title'],
                                          style: AppTypography.titleSmall(textPrimary).copyWith(
                                            fontWeight: FontWeight.bold,
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'المادة: ${item['subject']} • الأستاذ: ${item['teacher']}',
                                          style: AppTypography.bodySmall(textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 10),

                              if (isLocked) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item['lock_reason'] ?? 'تتطلب حضور الحصة وسداد الرسوم كاش',
                                          style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Text(
                                      'تاريخ النشر: ${item['date']}',
                                      style: TextStyle(fontSize: 11, color: textSecondary),
                                    ),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (isDownloaded)
                                          IconButton.outlined(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                            tooltip: 'حذف من الذاكرة المحلية',
                                            onPressed: () => _toggleDownload(item),
                                          )
                                        else
                                          OutlinedButton.icon(
                                            onPressed: () => _toggleDownload(item),
                                            icon: const Icon(Icons.download_rounded, size: 16),
                                            label: const Text('تنزيل للأوفلاين ⬇️'),
                                          ),
                                        FilledButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => WatermarkedMaterialViewer(
                                                  title: item['title'],
                                                  subjectName: item['subject'],
                                                  teacherName: item['teacher'],
                                                  studentName: widget.studentName,
                                                  studentCode: widget.studentCode,
                                                  studentPhone: widget.studentPhone,
                                                  centerName: widget.centerName,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.visibility_rounded, size: 16),
                                          label: const Text('فتح وقراءة المذكرة 📖'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
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
