import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xml/xml.dart';

import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/widgets/portal_components.dart';
import '../../../../core/services/user_provisioning_service.dart';

class DataImportScreen extends StatefulWidget {
  const DataImportScreen({super.key});

  @override
  State<DataImportScreen> createState() => _DataImportScreenState();
}

class _DataImportScreenState extends State<DataImportScreen> {
  _ImportEntity _entity = _ImportEntity.students;
  bool _isReading = false;
  bool _isImporting = false;
  String? _errorMessage;
  String? _fileName;
  List<_ImportRow> _rows = [];

  // Search & Status filter
  final TextEditingController _searchController = TextEditingController();
  _ImportStatus? _filterStatus;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickImportFile() async {
    setState(() {
      _isReading = true;
      _errorMessage = null;
      _rows = [];
      _fileName = null;
      _filterStatus = null;
      _searchController.clear();
      _searchQuery = '';
    });

    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Spreadsheet',
            extensions: ['csv', 'tsv', 'txt', 'xlsx'],
            mimeTypes: [
              'text/csv',
              'text/plain',
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
          ),
        ],
      );
      if (file == null) {
        if (mounted) setState(() => _isReading = false);
        return;
      }

      final bytes = await file.readAsBytes();
      final extension = file.name.split('.').last.toLowerCase();
      final rows = extension == 'xlsx'
          ? _parseXlsx(bytes)
          : _parseDelimited(utf8.decode(bytes, allowMalformed: true));
      if (rows.isEmpty) {
        throw const FormatException('الملف المحدد فارغ تماماً.');
      }

      final headers = rows.first.map(_normalizeHeader).toList();
      final parsed = <_ImportRow>[];
      for (var i = 1; i < rows.length; i++) {
        final raw = rows[i];
        if (raw.every((cell) => cell.trim().isEmpty)) continue;
        final data = <String, String>{};
        for (var c = 0; c < headers.length; c++) {
          data[headers[c]] = c < raw.length ? raw[c].trim() : '';
        }
        parsed.add(_ImportRow(rowNumber: i + 1, data: data));
      }

      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _rows = parsed.map((row) => row.validate(_entity)).toList();
        _isReading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isReading = false;
      });
    }
  }

  Future<void> _runImport() async {
    final validRows = _rows.where((row) => row.isValid).toList();
    if (validRows.isEmpty) return;

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    final client = Supabase.instance.client;
    String? centerId;
    final curUser = client.auth.currentUser;
    if (curUser != null) {
      try {
        final prof = await client
            .from('profiles')
            .select('center_id')
            .eq('id', curUser.id)
            .maybeSingle();
        centerId = prof?['center_id'] as String?;
      } catch (_) {}
    }

    final nextRows = [..._rows];
    const chunkSize = 5;
    for (var i = 0; i < validRows.length; i += chunkSize) {
      final chunk = validRows.sublist(
        i,
        i + chunkSize > validRows.length ? validRows.length : i + chunkSize,
      );

      await Future.wait(
        chunk.map((row) async {
          final index = nextRows.indexWhere(
            (item) => item.rowNumber == row.rowNumber,
          );
          try {
            await UserProvisioningService.provisionUser(
              email: row.email,
              fullName: row.fullName,
              role: _entity.role,
              branchId: row.branchId,
              centerId: centerId,
              phoneNumber: row.phoneNumber,
              gradeLevel: _entity == _ImportEntity.students ? row.gradeLevel : null,
              specialization: _entity == _ImportEntity.teachers ? row.specialization : null,
            );
            if (index != -1) {
              nextRows[index] = row.copyWith(
                status: _ImportStatus.success,
                resultMessage: 'تم الاستيراد بنجاح',
              );
            }
          } catch (e) {
            if (index != -1) {
              nextRows[index] = row.copyWith(
                status: _ImportStatus.failed,
                resultMessage: e.toString(),
              );
            }
          }
        }),
      );

      if (mounted) setState(() => _rows = [...nextRows]);
    }

    if (mounted) setState(() => _isImporting = false);
  }

  void _downloadTemplate() {
    final template = _entity.template;
    Clipboard.setData(ClipboardData(text: template));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ القالب النموذجي (${_entity.label}) إلى الحافظة:\n$template'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<_ImportRow> get _filteredRows {
    return _rows.where((row) {
      if (_filterStatus != null && row.status != _filterStatus) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = row.fullName.toLowerCase().contains(q);
        final matchEmail = row.email.toLowerCase().contains(q);
        final matchPhone = (row.phoneNumber ?? '').toLowerCase().contains(q);
        if (!matchName && !matchEmail && !matchPhone) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _rows.where((row) => row.isValid).length;
    final successCount = _rows
        .where((row) => row.status == _ImportStatus.success)
        .length;
    final failedCount = _rows
        .where(
          (row) =>
              row.status == _ImportStatus.failed ||
              row.status == _ImportStatus.invalid,
        )
        .length;
    final filtered = _filteredRows;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PortalPageShell(
      title: 'معالج استيراد البيانات (Excel / CSV)',
      subtitle: 'إضافة الطلاب والمعلمين وأولياء الأمور دفعة واحدة من ملف إكسيل أو CSV بدقة وسرعة.',
      icon: Icons.upload_file_rounded,
      accentColor: AppColors.adminRole,
      actions: [
        PortalAction(
          icon: Icons.copy_rounded,
          label: 'نسخ القالب',
          onPressed: _downloadTemplate,
        ),
        PortalAction(
          icon: Icons.folder_open_rounded,
          label: 'اختيار ملف',
          onPressed: _isReading || _isImporting ? () {} : _pickImportFile,
          primary: true,
        ),
      ],
      headerWidgets: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Responsive KPI summary strip
                _buildKpiStrip(
                  isMobile: isMobile,
                  total: _rows.length,
                  valid: validCount,
                  success: successCount,
                  failed: failedCount,
                  isDark: isDark,
                ),

                const SizedBox(height: 12),

                // Control & Action Toolbar Card
                _buildToolbar(
                  isMobile: isMobile,
                  validCount: validCount,
                  isDark: isDark,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  PortalErrorBanner(
                    message: _errorMessage!,
                    onRetry: _pickImportFile,
                  ),
                ],

                if (_isReading) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],

                // Search & filter row if rows are loaded
                if (_rows.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildSearchAndFilters(isMobile: isMobile, isDark: isDark),
                ],
              ],
            );
          },
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          return _rows.isEmpty
              ? _ImportEmptyState(
                  entity: _entity,
                  onPickFile: _pickImportFile,
                  onCopyTemplate: _downloadTemplate,
                )
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            'لا توجد صفوف تطابق معايير البحث والفلترة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    )
                  : isMobile || constraints.maxWidth < 750
                      ? _ImportMobileCardList(rows: filtered)
                      : _ImportPreviewTable(rows: filtered);
        },
      ),
    );
  }

  Widget _buildKpiStrip({
    required bool isMobile,
    required int total,
    required int valid,
    required int success,
    required int failed,
    required bool isDark,
  }) {
    final cards = [
      _ImportStatCard(
        label: 'إجمالي الصفوف',
        value: '$total',
        icon: Icons.receipt_long_rounded,
        accentColor: Colors.blueGrey,
        isSelected: _filterStatus == null && _rows.isNotEmpty,
        onTap: _rows.isNotEmpty ? () => setState(() => _filterStatus = null) : null,
      ),
      _ImportStatCard(
        label: 'جاهز للاستيراد',
        value: '$valid',
        icon: Icons.check_circle_outline_rounded,
        accentColor: AppColors.success,
        isSelected: _filterStatus == _ImportStatus.ready,
        onTap: _rows.isNotEmpty ? () => setState(() => _filterStatus = _ImportStatus.ready) : null,
      ),
      _ImportStatCard(
        label: 'تم استيراده',
        value: '$success',
        icon: Icons.done_all_rounded,
        accentColor: Colors.teal,
        isSelected: _filterStatus == _ImportStatus.success,
        onTap: _rows.isNotEmpty ? () => setState(() => _filterStatus = _ImportStatus.success) : null,
      ),
      _ImportStatCard(
        label: 'أخطاء / بحاجة لتصحيح',
        value: '$failed',
        icon: Icons.warning_amber_rounded,
        accentColor: AppColors.error,
        isSelected: _filterStatus == _ImportStatus.invalid || _filterStatus == _ImportStatus.failed,
        onTap: _rows.isNotEmpty ? () => setState(() => _filterStatus = _ImportStatus.invalid) : null,
      ),
    ];

    if (isMobile) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 72,
        children: cards,
      );
    }

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _buildToolbar({
    required bool isMobile,
    required int validCount,
    required bool isDark,
  }) {
    final entityDropdown = DropdownButtonFormField<_ImportEntity>(
      initialValue: _entity,
      decoration: InputDecoration(
        labelText: 'نوع البيانات المطلوب استيرادها',
        prefixIcon: const Icon(Icons.category_outlined, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      items: _ImportEntity.values
          .map(
            (entity) => DropdownMenuItem(
              value: entity,
              child: Text(entity.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          )
          .toList(),
      onChanged: _isImporting
          ? null
          : (value) {
              if (value == null) return;
              setState(() {
                _entity = value;
                _rows = _rows.map((row) => row.validate(value)).toList();
              });
            },
    );

    final filePill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _fileName != null
              ? AppColors.primary.withValues(alpha: 0.4)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(
            _fileName != null ? Icons.description_rounded : Icons.folder_open_outlined,
            size: 18,
            color: _fileName != null ? AppColors.primary : Colors.grey,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _fileName ?? 'لم يتم اختيار ملف بعد',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: _fileName != null ? FontWeight.bold : FontWeight.normal,
                color: _fileName != null
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
          ),
          if (_fileName != null && !_isImporting) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: _pickImportFile,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );

    final importButton = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onPressed: _isImporting || validCount == 0 ? null : _runImport,
      icon: _isImporting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.cloud_upload_rounded, size: 20),
      label: Text(
        _isImporting
            ? 'جارٍ الاستيراد...'
            : isMobile
                ? 'استيراد $validCount صالحة'
                : 'بدء استيراد الصفوف الصالحة ($validCount)',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                entityDropdown,
                const SizedBox(height: 10),
                filePill,
                const SizedBox(height: 10),
                importButton,
              ],
            )
          : Row(
              children: [
                SizedBox(
                  width: 250,
                  child: entityDropdown,
                ),
                const SizedBox(width: 12),
                Expanded(child: filePill),
                const SizedBox(width: 12),
                importButton,
              ],
            ),
    );
  }

  Widget _buildSearchAndFilters({required bool isMobile, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface.withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'بحث بالاسم، البريد الإلكتروني، أو الهاتف...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            InkWell(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
            ),
          if (_filterStatus != null) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: Icon(_filterStatus!.icon, size: 14, color: _filterStatus!.color),
              label: Text(_filterStatus!.label, style: const TextStyle(fontSize: 11)),
              onPressed: () => setState(() => _filterStatus = null),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImportStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ImportStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: isDark ? 0.2 : 0.1)
                : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: isSelected ? 1.5 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? accentColor : (isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportEmptyState extends StatelessWidget {
  final _ImportEntity entity;
  final VoidCallback onPickFile;
  final VoidCallback onCopyTemplate;

  const _ImportEmptyState({
    required this.entity,
    required this.onPickFile,
    required this.onCopyTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    size: 32,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'استيراد ${entity.label} دفعة واحدة',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'قم باختيار ملف إكسيل (.xlsx) أو ملف نصي مفصول بفواصل (.csv) لمعاينة البيانات والتحقق من صحتها تلقائياً قبل الاستيراد.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Template preview box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'تنسيق الأعمدة المطلوب:',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          InkWell(
                            onTap: onCopyTemplate,
                            child: const Row(
                              children: [
                                Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'نسخ النموذج',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        entity.template,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: onCopyTemplate,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('نسخ نموذج القالب'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: onPickFile,
                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                        label: const Text('اختيار ملف البيانات'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mobile Card List View for screens < 750px
class _ImportMobileCardList extends StatelessWidget {
  final List<_ImportRow> rows;

  const _ImportMobileCardList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ImportRowCard(row: rows[index]),
    );
  }
}

class _ImportRowCard extends StatelessWidget {
  final _ImportRow row;

  const _ImportRowCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: row.status == _ImportStatus.invalid || row.status == _ImportStatus.failed
              ? AppColors.error.withValues(alpha: 0.35)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: row.status == _ImportStatus.invalid || row.status == _ImportStatus.failed ? 1.2 : 0.8,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Row number & Status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'صف #${row.rowNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: row.status.backgroundColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: row.status.color.withValues(alpha: 0.3), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(row.status.icon, size: 14, color: row.status.color),
                    const SizedBox(width: 4),
                    Text(
                      row.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: row.status.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Name & Email
          Text(
            row.fullName.isNotEmpty ? row.fullName : '— بدون اسم —',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  row.email.isNotEmpty ? row.email : '— بدون بريد —',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),

          // Extra details chips if available
          if (row.phoneNumber != null ||
              row.branchId != null ||
              row.gradeLevel != null ||
              row.specialization != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (row.phoneNumber != null && row.phoneNumber!.isNotEmpty)
                  _buildDetailTag(Icons.phone_outlined, row.phoneNumber!, isDark),
                if (row.branchId != null && row.branchId!.isNotEmpty)
                  _buildDetailTag(Icons.business_outlined, 'الفرع: ${row.branchId!}', isDark),
                if (row.gradeLevel != null && row.gradeLevel!.isNotEmpty)
                  _buildDetailTag(Icons.school_outlined, row.gradeLevel!, isDark),
                if (row.specialization != null && row.specialization!.isNotEmpty)
                  _buildDetailTag(Icons.menu_book_outlined, row.specialization!, isDark),
              ],
            ),
          ],

          // Error or success result banner
          if (row.resultMessage.isNotEmpty && row.resultMessage != 'جاهز') ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: row.status.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: row.status.color.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(row.status.icon, size: 16, color: row.status.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      row.resultMessage,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: row.status.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailTag(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// Desktop / Tablet Wide Preview Table (>= 750px)
class _ImportPreviewTable extends StatelessWidget {
  final List<_ImportRow> rows;

  const _ImportPreviewTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            ),
            columns: const [
              DataColumn(label: Text('رقم الصف', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('الاسم بالكامل', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('البريد الإلكتروني', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('معرف الفرع / الهاتف', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('التفاصيل / النتيجة', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: rows
                .map(
                  (row) => DataRow(
                    color: WidgetStatePropertyAll(row.status.backgroundColor),
                    cells: [
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${row.rowNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.fullName.isNotEmpty ? row.fullName : '—',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(row.email.isNotEmpty ? row.email : '—')),
                      DataCell(
                        Text(
                          [
                            if (row.branchId != null) 'فرع: ${row.branchId}',
                            if (row.phoneNumber != null) 'هاتف: ${row.phoneNumber}',
                          ].join(' • '),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: row.status.backgroundColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: row.status.color.withValues(alpha: 0.3), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                row.status.icon,
                                size: 16,
                                color: row.status.color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                row.status.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: row.status.color,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: Text(
                            row.resultMessage,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: row.status == _ImportStatus.invalid || row.status == _ImportStatus.failed
                                  ? AppColors.error
                                  : null,
                              fontWeight: row.status == _ImportStatus.invalid ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

enum _ImportEntity {
  students('الطلاب', 'student'),
  parents('أولياء الأمور', 'parent'),
  teachers('المعلمون', 'teacher');

  final String label;
  final String role;

  const _ImportEntity(this.label, this.role);

  String get template {
    switch (this) {
      case _ImportEntity.students:
        return 'full_name,email,branch_id,phone_number,grade_level\nأحمد محمد,student@example.com,<معرف-الفرع>,01012345678,الثالث الثانوي';
      case _ImportEntity.parents:
        return 'full_name,email,phone_number\nولي الأمر,parent@example.com,01012345678';
      case _ImportEntity.teachers:
        return 'full_name,email,branch_id,phone_number,specialization\nأستاذ أحمد,teacher@example.com,<معرف-الفرع>,01012345678,فيزياء';
    }
  }
}

enum _ImportStatus {
  ready('جاهز', Icons.check_circle_outline, AppColors.success),
  invalid('غير صالح', Icons.error_outline, AppColors.error),
  success('تم الاستيراد', Icons.done_all, AppColors.success),
  failed('فشل', Icons.warning_amber, AppColors.warning);

  final String label;
  final IconData icon;
  final Color color;

  const _ImportStatus(this.label, this.icon, this.color);

  Color get backgroundColor => color.withValues(alpha: .08);
}

class _ImportRow {
  final int rowNumber;
  final Map<String, String> data;
  final _ImportStatus status;
  final String resultMessage;

  const _ImportRow({
    required this.rowNumber,
    required this.data,
    this.status = _ImportStatus.ready,
    this.resultMessage = 'جاهز',
  });

  String get fullName =>
      data['full_name'] ??
      data['name'] ??
      data['الاسم'] ??
      data['full name'] ??
      data['fullname'] ??
      '';
  String get email => data['email'] ?? data['البريد'] ?? data['email_address'] ?? '';
  String? get branchId {
    final value = data['branch_id'] ?? data['branchid'] ?? data['الفرع'];
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
  String? get phoneNumber {
    final value = data['phone'] ??
        data['phone_number'] ??
        data['الهاتف'] ??
        data['الموبايل'] ??
        data['mobile'];
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
  String? get gradeLevel {
    final value = data['grade'] ??
        data['grade_level'] ??
        data['الصف'] ??
        data['المرحلة'];
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
  String? get specialization {
    final value = data['spec'] ??
        data['specialization'] ??
        data['التخصص'] ??
        data['المادة'];
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  bool get isValid => status == _ImportStatus.ready;

  _ImportRow validate(_ImportEntity entity) {
    final errors = <String>[];
    if (fullName.trim().isEmpty) errors.add('الاسم مطلوب');
    if (email.trim().isEmpty || !email.contains('@')) {
      errors.add('بريد إلكتروني غير صالح');
    }
    if (entity != _ImportEntity.parents && branchId != null) {
      final uuidLike = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      if (!uuidLike.hasMatch(branchId!)) {
        errors.add('معرف الفرع غير صالح');
      }
    }
    return copyWith(
      status: errors.isEmpty ? _ImportStatus.ready : _ImportStatus.invalid,
      resultMessage: errors.isEmpty ? 'جاهز للاستيراد' : errors.join('، '),
    );
  }

  _ImportRow copyWith({_ImportStatus? status, String? resultMessage}) {
    return _ImportRow(
      rowNumber: rowNumber,
      data: data,
      status: status ?? this.status,
      resultMessage: resultMessage ?? this.resultMessage,
    );
  }
}

String _normalizeHeader(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
}

List<List<String>> _parseDelimited(String source) {
  final delimiter = source.contains('\t') && !source.contains(',') ? '\t' : ',';
  final rows = <List<String>>[];
  final currentRow = <String>[];
  final current = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (char == '"') {
      if (inQuotes && next == '"') {
        current.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == delimiter && !inQuotes) {
      currentRow.add(current.toString());
      current.clear();
    } else if ((char == '\n' || char == '\r') && !inQuotes) {
      if (char == '\r' && next == '\n') i++;
      currentRow.add(current.toString());
      current.clear();
      rows.add([...currentRow]);
      currentRow.clear();
    } else {
      current.write(char);
    }
  }

  if (current.isNotEmpty || currentRow.isNotEmpty) {
    currentRow.add(current.toString());
    rows.add([...currentRow]);
  }
  return rows;
}

List<List<String>> _parseXlsx(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final files = {
    for (final file in archive.files)
      if (file.isFile) file.name: file.content as List<int>,
  };

  final workbookXml = _xlsxText(files, 'xl/workbook.xml');
  final workbookRelsXml = _xlsxText(files, 'xl/_rels/workbook.xml.rels');
  final sheetPath = _firstWorksheetPath(workbookXml, workbookRelsXml);
  final sharedStrings = _readSharedStrings(files);
  final sheetXml = _xlsxText(files, sheetPath);
  final document = XmlDocument.parse(sheetXml);
  final sparseRows = <int, Map<int, String>>{};

  for (final row in document.findAllElements('row')) {
    final rowIndex = int.tryParse(row.getAttribute('r') ?? '') ?? 0;
    if (rowIndex <= 0) continue;

    final values = <int, String>{};
    for (final cell in row.findElements('c')) {
      final ref = cell.getAttribute('r') ?? '';
      final colIndex = _xlsxColumnIndex(ref);
      if (colIndex < 0) continue;
      values[colIndex] = _xlsxCellValue(cell, sharedStrings);
    }
    sparseRows[rowIndex - 1] = values;
  }

  if (sparseRows.isEmpty) return const [];
  final maxRow = sparseRows.keys.reduce((a, b) => a > b ? a : b);
  final maxCol = sparseRows.values
      .expand((row) => row.keys)
      .fold<int>(0, (max, col) => col > max ? col : max);

  final rows = <List<String>>[];
  for (var r = 0; r <= maxRow; r++) {
    final sparse = sparseRows[r] ?? const <int, String>{};
    rows.add([for (var c = 0; c <= maxCol; c++) sparse[c] ?? '']);
  }

  return rows
      .where((row) => row.any((cell) => cell.trim().isNotEmpty))
      .toList();
}

String _xlsxText(Map<String, List<int>> files, String path) {
  final bytes = files[path];
  if (bytes == null) {
    throw FormatException('Missing XLSX part: $path');
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _firstWorksheetPath(String workbookXml, String relsXml) {
  final workbook = XmlDocument.parse(workbookXml);
  final rels = XmlDocument.parse(relsXml);
  final firstSheet = workbook.findAllElements('sheet').firstOrNull;
  if (firstSheet == null) {
    throw const FormatException('The Excel workbook has no worksheets.');
  }

  final relationId =
      firstSheet.getAttribute('r:id') ?? firstSheet.getAttribute('id');
  if (relationId == null || relationId.isEmpty) {
    throw const FormatException('The first worksheet is missing its relation.');
  }

  final relationship = rels
      .findAllElements('Relationship')
      .firstWhere(
        (rel) => rel.getAttribute('Id') == relationId,
        orElse: () => throw const FormatException(
          'Could not resolve the first worksheet relation.',
        ),
      );
  final target = relationship.getAttribute('Target');
  if (target == null || target.isEmpty) {
    throw const FormatException('The first worksheet relation has no target.');
  }
  return target.startsWith('xl/') ? target : 'xl/$target';
}

List<String> _readSharedStrings(Map<String, List<int>> files) {
  final bytes = files['xl/sharedStrings.xml'];
  if (bytes == null) return const [];
  final document = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true));
  return document
      .findAllElements('si')
      .map(
        (item) =>
            item.findAllElements('t').map((node) => node.innerText).join(),
      )
      .toList();
}

String _xlsxCellValue(XmlElement cell, List<String> sharedStrings) {
  final type = cell.getAttribute('t');
  final valueNode = cell.findElements('v').firstOrNull;
  final inlineText = cell.findElements('is').firstOrNull;

  if (type == 'inlineStr' && inlineText != null) {
    return inlineText.findAllElements('t').map((node) => node.innerText).join();
  }
  if (valueNode == null) return '';

  final raw = valueNode.innerText;
  if (type == 's') {
    final index = int.tryParse(raw);
    if (index == null || index < 0 || index >= sharedStrings.length) return '';
    return sharedStrings[index];
  }
  if (type == 'b') return raw == '1' ? 'true' : 'false';
  return raw;
}

int _xlsxColumnIndex(String cellRef) {
  final letters = RegExp(
    r'^[A-Z]+',
    caseSensitive: false,
  ).stringMatch(cellRef)?.toUpperCase();
  if (letters == null || letters.isEmpty) return -1;

  var value = 0;
  for (final codeUnit in letters.codeUnits) {
    value = value * 26 + (codeUnit - 64);
  }
  return value - 1;
}
