import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/arabic_pdf_helper.dart';
import 'report_generator_service.dart';

enum ThermalPaperWidth {
  mm80(80, '80 مم (الافتراضي لنقاط البيع)'),
  mm58(58, '58 مم (الطابعات الصغيرة والمحمولة)');

  final int mm;
  final String label;
  const ThermalPaperWidth(this.mm, this.label);
}

/// Service to handle direct ESC/POS and thermal silent printing
/// for Egyptian educational centers (cash receipts, bookstore POS, attendance slips).
class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  static const String _prefKeyDirectPrint = 'brivio_direct_thermal_print_enabled';
  static const String _prefKeySelectedPrinterName = 'brivio_selected_thermal_printer_name';
  static const String _prefKeyPaperWidth = 'brivio_thermal_paper_width';
  static const String _prefKeyAutoDrawerKick = 'brivio_thermal_auto_drawer_kick';

  final ValueNotifier<bool> directPrintEnabled = ValueNotifier<bool>(false);
  final ValueNotifier<Printer?> selectedPrinter = ValueNotifier<Printer?>(null);
  final ValueNotifier<ThermalPaperWidth> paperWidth = ValueNotifier<ThermalPaperWidth>(ThermalPaperWidth.mm80);
  final ValueNotifier<bool> autoDrawerKick = ValueNotifier<bool>(true);

  bool _isInitialized = false;

  /// Initializes printer settings from SharedPreferences
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      directPrintEnabled.value = prefs.getBool(_prefKeyDirectPrint) ?? false;
      autoDrawerKick.value = prefs.getBool(_prefKeyAutoDrawerKick) ?? true;

      final savedWidthMm = prefs.getInt(_prefKeyPaperWidth) ?? 80;
      paperWidth.value = savedWidthMm == 58 ? ThermalPaperWidth.mm58 : ThermalPaperWidth.mm80;

      final savedPrinterName = prefs.getString(_prefKeySelectedPrinterName);
      if (savedPrinterName != null && savedPrinterName.isNotEmpty) {
        final available = await listPrinters();
        final match = available.where((p) => p.name == savedPrinterName).firstOrNull;
        if (match != null) {
          selectedPrinter.value = match;
        }
      }
      _isInitialized = true;
    } catch (_) {}
  }

  /// Lists all printers discovered on the host system (USB, Bluetooth, Wi-Fi / LAN)
  Future<List<Printer>> listPrinters() async {
    try {
      final printers = await Printing.listPrinters().timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => [],
      );
      return printers;
    } catch (_) {
      return [];
    }
  }

  /// Sets the preferred POS thermal printer
  Future<void> setSelectedPrinter(Printer? printer) async {
    selectedPrinter.value = printer;
    final prefs = await SharedPreferences.getInstance();
    if (printer != null) {
      await prefs.setString(_prefKeySelectedPrinterName, printer.name);
    } else {
      await prefs.remove(_prefKeySelectedPrinterName);
    }
  }

  /// Toggles silent printing (direct print without OS preview dialog)
  Future<void> setDirectPrintEnabled(bool enabled) async {
    directPrintEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyDirectPrint, enabled);
  }

  /// Sets thermal paper width (80mm vs 58mm)
  Future<void> setPaperWidth(ThermalPaperWidth width) async {
    paperWidth.value = width;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyPaperWidth, width.mm);
  }

  /// Sets auto cash drawer kick on cash payment
  Future<void> setAutoDrawerKick(bool enabled) async {
    autoDrawerKick.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyAutoDrawerKick, enabled);
  }

  /// Directly and silently prints a PDF document to the selected thermal printer.
  /// If no printer is selected or direct print is disabled, falls back to layoutPdf.
  Future<bool> printDocument({
    required pw.Document document,
    String documentName = 'Receipt',
    bool forceDirect = false,
  }) async {
    final pdfBytes = await document.save();

    final targetPrinter = selectedPrinter.value;
    final shouldDirect = forceDirect || (directPrintEnabled.value && targetPrinter != null);

    if (shouldDirect && targetPrinter != null) {
      try {
        final success = await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (PdfPageFormat format) => pdfBytes,
          name: documentName,
          format: paperWidth.value == ThermalPaperWidth.mm58
              ? const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm)
              : const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        );
        return success;
      } catch (_) {
        // Fallback to standard print preview if direct print fails
        return await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) => pdfBytes,
          name: documentName,
        );
      }
    } else {
      return await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) => pdfBytes,
        name: documentName,
      );
    }
  }

  /// Generates ESC/POS standard command bytes for physical cash drawer kick:
  /// Standard pulse: ESC p m t1 t2 -> 0x1B, 0x70, 0x00, 0x19, 0xFA
  Uint8List generateCashDrawerKickCommand() {
    return Uint8List.fromList([0x1B, 0x70, 0x00, 0x19, 0xFA]);
  }

  /// Generates ESC/POS full paper cut command:
  /// GS V A n -> 0x1D, 0x56, 0x41, 0x10
  Uint8List generatePaperCutCommand() {
    return Uint8List.fromList([0x1D, 0x56, 0x41, 0x10]);
  }

  /// Sends a test receipt to verify connection, paper feed, and Arabic rendering
  Future<bool> printTestReceipt({
    required String centerName,
    Printer? printer,
  }) async {
    final pdf = await ReportGeneratorService.createDocument();
    final boldFont = await ReportGeneratorService.getBoldFont();
    final regularFont = await ReportGeneratorService.getRegularFont();

    final boldStyle = pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold);
    final regularStyle = pw.TextStyle(font: regularFont);

    final widthMm = paperWidth.value.mm.toDouble();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(widthMm * PdfPageFormat.mm, 120 * PdfPageFormat.mm, marginAll: 3 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  centerName.fixArabic,
                  style: boldStyle.copyWith(fontSize: 13),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'اختبار اتصال الطابعة الحرارية 🖨️'.fixArabic,
                  style: regularStyle.copyWith(fontSize: 9),
                ),
              ),
              pw.Divider(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('الحالة:'.fixArabic, style: boldStyle.copyWith(fontSize: 9)),
                  pw.Text('متصل وجاهز للطباعة ✅'.fixArabic, style: boldStyle.copyWith(fontSize: 9, color: PdfColors.green800)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('عرض الورق:'.fixArabic, style: regularStyle.copyWith(fontSize: 8.5)),
                  pw.Text('${paperWidth.value.mm} مم'.fixArabic, style: regularStyle.copyWith(fontSize: 8.5)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('الطباعة الصامتة:'.fixArabic, style: regularStyle.copyWith(fontSize: 8.5)),
                  pw.Text(directPrintEnabled.value ? 'مفعلة ⚡'.fixArabic : 'معطلة (معاينة)'.fixArabic, style: regularStyle.copyWith(fontSize: 8.5)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('التاريخ والوقت:'.fixArabic, style: regularStyle.copyWith(fontSize: 8)),
                  pw.Text('${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}', style: regularStyle.copyWith(fontSize: 8)),
                ],
              ),
              pw.Divider(height: 12),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: 'BRIVIO-THERMAL-TEST-OK',
                  width: 48,
                  height: 48,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'منظومة Brivio لإدارة السناتر التعليمية'.fixArabic,
                  style: regularStyle.copyWith(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ),
            ],
          );
        },
      ),
    );

    return printDocument(
      document: pdf,
      documentName: 'Thermal_Test_Print',
      forceDirect: printer != null,
    );
  }
}
