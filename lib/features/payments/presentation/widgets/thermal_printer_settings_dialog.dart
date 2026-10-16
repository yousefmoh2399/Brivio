import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../core/services/thermal_printer_service.dart';
import '../../../../design_system/tokens/colors.dart';
import '../../../../design_system/tokens/typography.dart';

class ThermalPrinterSettingsDialog extends StatefulWidget {
  final String centerName;

  const ThermalPrinterSettingsDialog({
    super.key,
    this.centerName = 'السنتر التعليمي',
  });

  static Future<void> show(BuildContext context, {String centerName = 'السنتر التعليمي'}) {
    return showDialog(
      context: context,
      builder: (_) => ThermalPrinterSettingsDialog(centerName: centerName),
    );
  }

  @override
  State<ThermalPrinterSettingsDialog> createState() => _ThermalPrinterSettingsDialogState();
}

class _ThermalPrinterSettingsDialogState extends State<ThermalPrinterSettingsDialog> {
  final _printerService = ThermalPrinterService();
  List<Printer> _printers = [];
  bool _isLoading = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() => _isLoading = true);
    try {
      await _printerService.init();
      final list = await _printerService.listPrinters();
      if (mounted) {
        setState(() {
          _printers = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _runTestPrint() async {
    setState(() => _isTesting = true);
    try {
      final success = await _printerService.printTestReceipt(centerName: widget.centerName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'تم إرسال أمر الطباعة التجريبية بنجاح 🖨️' : 'فشل إرسال أمر الطباعة، تأكد من تشغيل الطابعة'),
            backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.print_rounded, color: Colors.teal, size: 24),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'إعدادات الطابعة الحرارية للكاشير (ESC/POS) 🖨️',
                              style: AppTypography.titleMedium(textPrimary).copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Silent Print Direct Toggle
                ValueListenableBuilder<bool>(
                  valueListenable: _printerService.directPrintEnabled,
                  builder: (context, directEnabled, _) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: directEnabled ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: directEnabled ? Colors.green.shade400 : Colors.grey.shade400,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'الطباعة السريعة المباشرة (Silent Direct Print) ⚡',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'إرسال إيصال الدفع كاش فوراً للطابعة دون فتح شاشة المعاينة',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: directEnabled,
                          activeThumbColor: Colors.green,
                          onChanged: (val) => _printerService.setDirectPrintEnabled(val),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Paper Width Selector
                ValueListenableBuilder<ThermalPaperWidth>(
                  valueListenable: _printerService.paperWidth,
                  builder: (context, width, _) {
                    return Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const Text('عرض الورق الحراري:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ChoiceChip(
                          label: const Text('80 مم (POS كاشير)'),
                          selected: width == ThermalPaperWidth.mm80,
                          onSelected: (sel) {
                            if (sel) _printerService.setPaperWidth(ThermalPaperWidth.mm80);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('58 مم (محمولة)'),
                          selected: width == ThermalPaperWidth.mm58,
                          onSelected: (sel) {
                            if (sel) _printerService.setPaperWidth(ThermalPaperWidth.mm58);
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Cash Drawer Kick toggle
                ValueListenableBuilder<bool>(
                  valueListenable: _printerService.autoDrawerKick,
                  builder: (context, kickEnabled, _) {
                    return Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'فتح درج النقدية آلياً (Auto Drawer Kick) 💵',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        subtitle: const Text(
                          'إرسال إشارة فتح الدرج عند تسجيل أي عملية تحصيل كاش',
                          style: TextStyle(fontSize: 11),
                        ),
                        value: kickEnabled,
                        activeThumbColor: Colors.teal,
                        onChanged: (val) => _printerService.setAutoDrawerKick(val),
                      ),
                    );
                  },
                ),
                const Divider(height: 20),

                // Printer Selection List
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'الطابعات المتصلة بالنظام (USB / Bluetooth / LAN):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textSecondary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: 'إعادة البحث عن الطابعات',
                      onPressed: _loadPrinters,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                else if (_printers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Text(
                      'لم يتم العثور على أي طابعات متصلة حالياً. تأكد من توصيل الطابعة الحرارية وتثبيت تعريفها.',
                      style: TextStyle(fontSize: 11.5, color: Colors.brown),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ValueListenableBuilder<Printer?>(
                    valueListenable: _printerService.selectedPrinter,
                    builder: (context, activePrinter, _) {
                      return Column(
                        children: _printers.map((p) {
                          final isSelected = activePrinter?.name == p.name;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.teal.withValues(alpha: 0.12) : (isDark ? Colors.black26 : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? Colors.teal : Colors.grey.shade300,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.print_rounded,
                                  color: isSelected ? Colors.teal : Colors.grey,
                                ),
                                title: Text(
                                  p.name,
                                  style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13),
                                ),
                              subtitle: Text(
                                p.model ?? (p.isDefault ? 'طابعة النظام الافتراضية' : 'USB / Local Thermal'),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              trailing: isSelected
                                  ? const Chip(
                                      label: Text('المعتمدة ✅', style: TextStyle(fontSize: 10, color: Colors.teal)),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    )
                                  : OutlinedButton(
                                      onPressed: () => _printerService.setSelectedPrinter(p),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: const Text('اختيار', style: TextStyle(fontSize: 11)),
                                    ),
                                ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                const SizedBox(height: 16),

                // Test Print & Done Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: _isTesting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.receipt_long_rounded, size: 16),
                        label: const Text('طباعة تجريبية'),
                        onPressed: _isTesting ? null : _runTestPrint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('تم الحفظ'),
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
