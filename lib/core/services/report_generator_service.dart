import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/arabic_pdf_helper.dart';
import 'thermal_printer_service.dart';

class ReportGeneratorService {
  static pw.ThemeData? _cachedArabicTheme;
  static pw.Font? _cairoRegular;
  static pw.Font? _cairoBold;

  /// Returns a regular Arabic-compatible font (Cairo or bundled Amiri fallback)
  static Future<pw.Font> getRegularFont() async {
    if (_cairoRegular != null) return _cairoRegular!;
    try {
      _cairoRegular = await PdfGoogleFonts.cairoRegular();
      return _cairoRegular!;
    } catch (_) {
      try {
        final data = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
        _cairoRegular = pw.Font.ttf(data);
        return _cairoRegular!;
      } catch (_) {
        try {
          return await PdfGoogleFonts.amiriRegular();
        } catch (_) {
          return pw.Font.helvetica();
        }
      }
    }
  }

  /// Returns a bold Arabic-compatible font (Cairo or bundled Amiri fallback)
  static Future<pw.Font> getBoldFont() async {
    if (_cairoBold != null) return _cairoBold!;
    try {
      _cairoBold = await PdfGoogleFonts.cairoBold();
      return _cairoBold!;
    } catch (_) {
      try {
        final data = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
        _cairoBold = pw.Font.ttf(data);
        return _cairoBold!;
      } catch (_) {
        try {
          return await PdfGoogleFonts.amiriBold();
        } catch (_) {
          return pw.Font.helveticaBold();
        }
      }
    }
  }

  /// Loads Arabic Unicode fonts (Cairo / Amiri / Noto) so Arabic letters render cleanly without Helvetica crash
  static Future<pw.ThemeData> getArabicPdfTheme() async {
    if (_cachedArabicTheme != null) return _cachedArabicTheme!;
    final reg = await getRegularFont();
    final bld = await getBoldFont();
    _cachedArabicTheme = pw.ThemeData.withFont(
      base: reg,
      bold: bld,
    );
    return _cachedArabicTheme!;
  }

  /// Instantiates a new PDF Document pre-configured with Arabic Unicode fonts
  static Future<pw.Document> createDocument() async {
    final theme = await getArabicPdfTheme();
    return pw.Document(theme: theme);
  }

  /// Generates a PDF report for Student Grades and Missing Homeworks.
  Future<void> generateGradesReport({
    required String className,
    required List<Map<String, dynamic>> studentsData,
  }) async {
    final pdf = await createDocument();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Student Grades Report - $className'.fixArabic,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            data: ArabicPdfHelper.fixData([
              [
                'Student Name',
                'Exam Score',
                'Homework Score',
                'Missing Assignments',
              ],
              ...studentsData.map(
                (student) => [
                  student['name']?.toString() ?? '',
                  student['exam_score']?.toString() ?? '0',
                  student['homework_score']?.toString() ?? '0',
                  student['missing_assignments']?.toString() ?? '0',
                ],
              ),
            ]),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
            ),
          ),
        ],
      ),
    );

    await _saveAndSharePdf(pdf, 'Grades_Report_$className.pdf');
  }

  /// Generates a PDF report for Student Attendance records.
  Future<void> generateAttendanceReport({
    required String className,
    required List<Map<String, dynamic>> attendanceData,
    String personType = 'Student',
  }) async {
    final pdf = await createDocument();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Attendance Report - $className'.fixArabic,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            data: ArabicPdfHelper.fixData([
              [
                '$personType Name',
                'Total Present',
                'Total Absent',
                'Absence Dates',
              ],
              ...attendanceData.map(
                (record) => [
                  record['name']?.toString() ?? '',
                  record['present']?.toString() ?? '0',
                  record['absent']?.toString() ?? '0',
                  record['absence_dates']?.toString() ?? '',
                ],
              ),
            ]),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
            ),
          ),
        ],
      ),
    );

    await _saveAndSharePdf(pdf, 'Attendance_Report_$className.pdf');
  }

  /// Generates a PDF report for Financial Tracking (Admin only).
  Future<void> generateFinancialReport({
    required List<Map<String, dynamic>> financialData,
  }) async {
    final pdf = await createDocument();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Financial Report'.fixArabic,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            data: ArabicPdfHelper.fixData([
              ['Date', 'Description', 'Type', 'Amount', 'Notes'],
              ...financialData.map(
                (record) => [
                  record['date']?.toString() ?? '',
                  record['description']?.toString() ?? '',
                  record['type']?.toString() ?? '',
                  record['amount']?.toString() ?? '0',
                  record['notes']?.toString() ?? '',
                ],
              ),
            ]),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.orange),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
            ),
          ),
        ],
      ),
    );

    await _saveAndSharePdf(pdf, 'Financial_Report.pdf');
  }

  /// Generates a PDF report for Teacher Metrics
  Future<void> generateTeacherMetricsReport({
    required List<Map<String, dynamic>> teacherData,
  }) async {
    final pdf = await createDocument();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Teacher Metrics Report'.fixArabic,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            data: ArabicPdfHelper.fixData([
              ['Teacher Name', 'Classes Taught', 'Average Attendance (%)'],
              ...teacherData.map(
                (record) => [
                  record['name']?.toString() ?? '',
                  record['classes_taught']?.toString() ?? '0',
                  record['avg_attendance']?.toString() ?? '0',
                ],
              ),
            ]),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.purple),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
            ),
          ),
        ],
      ),
    );

    await _saveAndSharePdf(pdf, 'Teacher_Metrics_Report.pdf');
  }

  Future<void> _saveAndSharePdf(pw.Document pdf, String fileName) async {
    try {
      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      if (e.toString().contains('MissingPluginException') ||
          e.toString().contains('channel-error') ||
          e.toString().contains('No implementation found')) {
        return;
      }
      throw Exception('Could not save the PDF report: $e');
    }
  }

  /// Generates a PDF report for Student Roster
  Future<void> generateStudentRosterReport({
    required List<Map<String, dynamic>> studentsData,
  }) async {
    final pdf = await createDocument();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Student Roster Report'.fixArabic,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            data: ArabicPdfHelper.fixData([
              ['Student Name', 'Student Code', 'Email', 'Status'],
              ...studentsData.map(
                (record) => [
                  record['name']?.toString() ?? '',
                  record['code']?.toString() ?? '',
                  record['email']?.toString() ?? '',
                  record['status']?.toString() ?? '',
                ],
              ),
            ]),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
            ),
          ),
        ],
      ),
    );

    await _saveAndSharePdf(pdf, 'Student_Roster_Report.pdf');
  }

  /// Generates a PDF report for Teacher Roster
  Future<void> generateTeacherRosterReport({
    required List<Map<String, dynamic>> teachersData,
  }) async {
    final pdf = await createDocument();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Teacher Roster Report'.fixArabic,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            data: ArabicPdfHelper.fixData([
              ['Teacher Name', 'Email', 'Specialization', 'Status'],
              ...teachersData.map(
                (record) => [
                  record['name']?.toString() ?? '',
                  record['email']?.toString() ?? '',
                  record['specialization']?.toString() ?? '',
                  record['status']?.toString() ?? '',
                ],
              ),
            ]),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
            ),
          ),
        ],
      ),
    );

    await _saveAndSharePdf(pdf, 'Teacher_Roster_Report.pdf');
  }

  /// Generates a PDF report for Exam Details
  Future<void> generateExamReport({
    required String groupName,
    required List<Map<String, dynamic>> examData,
  }) async {
    final pdf = await createDocument();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Exam Report - $groupName'.fixArabic,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            data: ArabicPdfHelper.fixData([
              ['Exam Title', 'Duration (mins)', 'Pass Score', 'Status'],
              ...examData.map(
                (record) => [
                  record['title']?.toString() ?? '',
                  record['duration']?.toString() ?? '',
                  record['pass_score']?.toString() ?? '',
                  record['status']?.toString() ?? '',
                ],
              ),
            ]),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
            ),
          ),
        ],
      ),
    );

    await _saveAndSharePdf(pdf, 'Exam_Report_$groupName.pdf');
  }

  /// Generates a PDF report for Groups & Schedules
  Future<void> generateGroupsSchedulesReport({
    required List<Map<String, dynamic>> groupsData,
  }) async {
    final pdf = await createDocument();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Groups & Schedules Report'.fixArabic,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            data: ArabicPdfHelper.fixData([
              ['Group Name', 'Timing', 'Teacher', 'Active'],
              ...groupsData.map(
                (record) => [
                  record['group_name']?.toString() ?? '',
                  record['timing']?.toString() ?? '',
                  record['teacher']?.toString() ?? '',
                  (record['is_active'] == true) ? 'Yes' : 'No',
                ],
              ),
            ]),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
            ),
          ),
        ],
      ),
    );

    await _saveAndSharePdf(pdf, 'Groups_Schedules_Report.pdf');
  }

  /// Generates a PDF report for Linked Parents Stats
  Future<void> generateParentsReport({
    required List<Map<String, dynamic>> parentsData,
  }) async {
    final pdf = await createDocument();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Linked Parents Report'.fixArabic,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            data: ArabicPdfHelper.fixData([
              ['Parent Name', 'Linked Students', 'Email', 'Active Status'],
              ...parentsData.map(
                (record) => [
                  record['name']?.toString() ?? '',
                  record['students']?.toString() ?? '',
                  record['email']?.toString() ?? '',
                  record['status']?.toString() ?? '',
                ],
              ),
            ]),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.deepPurple,
            ),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
            ),
          ),
        ],
      ),
    );

    await _saveAndSharePdf(pdf, 'Parents_Report.pdf');
  }

  /// Generates a PDF report for Homework Completion Rates
  Future<void> generateHomeworkReport({
    required List<Map<String, dynamic>> homeworkData,
  }) async {
    final pdf = await createDocument();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Homework Completion Report'.fixArabic,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            data: ArabicPdfHelper.fixData([
              [
                'Class/Group',
                'Total Assignments',
                'Completion Rate',
                'Average Score',
              ],
              ...homeworkData.map(
                (record) => [
                  record['group']?.toString() ?? '',
                  record['total']?.toString() ?? '0',
                  record['completion_rate']?.toString() ?? '0%',
                  record['avg_score']?.toString() ?? '0',
                ],
              ),
            ]),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.brown),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
            ),
          ),
        ],
      ),
    );

    await _saveAndSharePdf(pdf, 'Homework_Completion_Report.pdf');
  }

  /// Generates a PDF report for Curriculum Progress
  Future<void> generateCurriculumReport({
    required List<Map<String, dynamic>> curriculumData,
  }) async {
    final pdf = await createDocument();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Curriculum Progress Report'.fixArabic,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            data: ArabicPdfHelper.fixData([
              [
                'Subject/Course',
                'Total Modules',
                'Completed Modules',
                'Progress (%)',
              ],
              ...curriculumData.map(
                (record) => [
                  record['subject']?.toString() ?? '',
                  record['total_modules']?.toString() ?? '0',
                  record['completed_modules']?.toString() ?? '0',
                  record['progress']?.toString() ?? '0%',
                ],
              ),
            ]),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
            ),
          ),
        ],
      ),
    );

    await _saveAndSharePdf(pdf, 'Curriculum_Progress_Report.pdf');
  }

  /// Prints or shares an official Teacher Settlement Receipt PDF
  Future<void> generateTeacherSettlementReceiptPdf({
    required String centerName,
    required String receiptNumber,
    required String teacherName,
    required String groupName,
    required String dateStr,
    required int studentCount,
    required double sessionPrice,
    required double totalRevenue,
    required double teacherPercent,
    required double teacherShare,
    required double centerShare,
    required double deductions,
    required String deductionReason,
    required double netPayout,
    bool printDirectly = false,
  }) async {
    final pdf = await createDocument();
    final boldFont = await getBoldFont();
    final regularFont = await getRegularFont();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey900,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        centerName.fixArabic,
                        style: pw.TextStyle(
                          font: boldFont,
                          color: PdfColors.white,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Teacher Settlement Voucher - Brivio Center Suite'.fixArabic,
                        style: pw.TextStyle(
                          font: regularFont,
                          color: PdfColors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Receipt #: $receiptNumber'.fixArabic,
                        style: pw.TextStyle(
                          font: boldFont,
                          color: PdfColors.amber,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      pw.Text(
                        'Date: $dateStr'.fixArabic,
                        style: pw.TextStyle(
                          font: regularFont,
                          color: PdfColors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Teacher Info Card
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Teacher / Educator:'.fixArabic, style: pw.TextStyle(font: regularFont, color: PdfColors.grey700, fontSize: 10)),
                      pw.Text(teacherName.fixArabic, style: pw.TextStyle(font: boldFont, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Group / Class Session:'.fixArabic, style: pw.TextStyle(font: regularFont, color: PdfColors.grey700, fontSize: 10)),
                      pw.Text(groupName.fixArabic, style: pw.TextStyle(font: boldFont, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Payment Type:'.fixArabic, style: pw.TextStyle(font: regularFont, color: PdfColors.grey700, fontSize: 10)),
                      pw.Text('CASH (نقداً بالخزينة)'.fixArabic, style: pw.TextStyle(font: boldFont, color: PdfColors.green800, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Financial Breakdown Table
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ArabicPdfHelper.fixHeaders(['Item / Description', 'Calculation / Rate', 'Amount (EGP / ج.م)']),
              data: ArabicPdfHelper.fixData([
                ['Total Attending Students', '$studentCount students', '${studentCount}x'],
                ['Session Price per Student', '$sessionPrice EGP / student', '$sessionPrice EGP'],
                ['Total Gross Revenue', '$studentCount x $sessionPrice EGP', '${totalRevenue.toStringAsFixed(1)} EGP'],
                ['Teacher Agreed Share', '$teacherPercent%', '${(totalRevenue * (teacherPercent / 100)).toStringAsFixed(1)} EGP'],
                ['Center Agreed Share', '${(100 - teacherPercent).toStringAsFixed(0)}%', '${centerShare.toStringAsFixed(1)} EGP'],
                ['Deductions / Expenses ($deductionReason)', 'Photocopies / Hall fee', '- ${deductions.toStringAsFixed(1)} EGP'],
              ]),
              headerStyle: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              cellStyle: pw.TextStyle(font: regularFont),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
              ),
            ),
            pw.SizedBox(height: 16),

            // Payout Summary Banner
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                border: pw.Border.all(color: PdfColors.green700, width: 1.5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'NET CASH PAID TO TEACHER / الصافي المنصرف نقداً:'.fixArabic,
                    style: pw.TextStyle(font: boldFont, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                  ),
                  pw.Text(
                    '${netPayout.toStringAsFixed(1)} EGP (ج.م)'.fixArabic,
                    style: pw.TextStyle(font: boldFont, fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 36),

            // Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Center Cashier / مسؤول الخزينة:'.fixArabic, style: pw.TextStyle(font: regularFont, fontSize: 10)),
                    pw.SizedBox(height: 30),
                    pw.Container(width: 160, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('Authorized Signature'.fixArabic, style: pw.TextStyle(font: regularFont, fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Teacher Signature / توقيع المدرس بالاستلام:'.fixArabic, style: pw.TextStyle(font: regularFont, fontSize: 10)),
                    pw.SizedBox(height: 30),
                    pw.Container(width: 160, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text(teacherName.fixArabic, style: pw.TextStyle(font: regularFont, fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.Spacer(),

            // Footer
            pw.Center(
              child: pw.Text(
                'Brivio Educational Platform • Official Cash Settlement Document'.fixArabic,
                style: pw.TextStyle(font: regularFont, color: PdfColors.grey500, fontSize: 8),
              ),
            ),
          ],
        ),
      ),
    );

    if (printDirectly) {
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } else {
      await _saveAndSharePdf(pdf, 'Teacher_Settlement_$receiptNumber.pdf');
    }
  }

  /// Prints or shares an official Student Cash Payment Receipt PDF
  Future<void> generateStudentCashReceiptPdf({
    required String centerName,
    required String receiptNumber,
    required String studentName,
    required String studentCode,
    required String groupName,
    required double amount,
    required String purpose,
    required String dateStr,
    String cashierName = 'خزينة السنتر',
    bool printDirectly = false,
  }) async {
    final pdf = await createDocument();
    final boldFont = await getBoldFont();
    final regularFont = await getRegularFont();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue800,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        centerName.fixArabic,
                        style: pw.TextStyle(
                          font: boldFont,
                          color: PdfColors.white,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Cash Payment Receipt / إيصال استلام نقدية'.fixArabic,
                        style: pw.TextStyle(font: regularFont, color: PdfColors.white, fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Receipt: $receiptNumber'.fixArabic,
                        style: pw.TextStyle(font: boldFont, color: PdfColors.amberAccent, fontWeight: pw.FontWeight.bold, fontSize: 11),
                      ),
                      pw.Text(
                        dateStr.fixArabic,
                        style: pw.TextStyle(font: regularFont, color: PdfColors.white, fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Details Table
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ArabicPdfHelper.fixHeaders(['Detail / البيان', 'Information / القيمة']),
              data: ArabicPdfHelper.fixData([
                ['Student Name / اسم الطالب', studentName],
                ['Student Code / كود الطالب', studentCode],
                ['Group / المجموعة', groupName],
                ['Payment Method / طريقة الدفع', 'CASH ONLY (نقداً بالخزينة)'],
                ['Payment Purpose / الغرض', purpose],
                ['Cashier / المستلم', cashierName],
              ]),
              headerStyle: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              cellStyle: pw.TextStyle(font: regularFont),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
              ),
            ),
            pw.SizedBox(height: 16),

            // Amount Box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                border: pw.Border.all(color: PdfColors.green700, width: 1.5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL AMOUNT RECEIVED / المبلغ المستلم:'.fixArabic,
                    style: pw.TextStyle(font: boldFont, fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                  ),
                  pw.Text(
                    '${amount.toStringAsFixed(1)} EGP (ج.م)'.fixArabic,
                    style: pw.TextStyle(font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Stamp
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.green700, width: 2),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'PAID IN CASH • خالص السداد نقداً'.fixArabic,
                    style: pw.TextStyle(font: boldFont, color: PdfColors.green700, fontWeight: pw.FontWeight.bold, fontSize: 10),
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Cashier Stamp / ختم الخزينة'.fixArabic, style: pw.TextStyle(font: regularFont, fontSize: 9, color: PdfColors.grey600)),
                    pw.SizedBox(height: 16),
                    pw.Container(width: 100, height: 1, color: PdfColors.grey400),
                  ],
                ),
              ],
            ),
            pw.Spacer(),

            pw.Center(
              child: pw.Text(
                'Brivio Educational Platform • Thank you for your payment'.fixArabic,
                style: pw.TextStyle(font: regularFont, color: PdfColors.grey500, fontSize: 8),
              ),
            ),
          ],
        ),
      ),
    );

    if (printDirectly) {
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } else {
      await _saveAndSharePdf(pdf, 'Receipt_$receiptNumber.pdf');
    }
  }

  /// Generates a Bulk Student ID Cards A4 Sheet PDF (8 cards per page with cutting dashed lines)
  /// ready for printing, cutting, and thermal lamination in educational centers.
  Future<void> generateBulkStudentIdCardsPdf({
    required List<Map<String, dynamic>> students,
    required String centerName,
    String? groupName,
    String academicYear = '2025 / 2026',
    bool printDirectly = false,
  }) async {
    final pdf = await createDocument();
    final boldFont = await getBoldFont();
    final regularFont = await getRegularFont();

    final boldStyle = pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold);
    final regularStyle = pw.TextStyle(font: regularFont);

    // 8 cards per A4 page (2 columns x 4 rows)
    const int cardsPerPage = 8;
    for (int i = 0; i < students.length; i += cardsPerPage) {
      final chunk = students.sublist(
        i,
        i + cardsPerPage > students.length ? students.length : i + cardsPerPage,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          build: (context) {
            return pw.Column(
              children: [
                // Sheet Header
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '$centerName • كروت هوية الطلاب المعتمدة'.fixArabic,
                            style: boldStyle.copyWith(fontSize: 12, color: PdfColors.blueGrey900),
                          ),
                          pw.Text(
                            'Bulk Student ID Passes - Group: ${groupName ?? "All Students"}'.fixArabic,
                            style: regularStyle.copyWith(fontSize: 8, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'العام الدراسي: $academicYear'.fixArabic,
                            style: boldStyle.copyWith(fontSize: 9, color: PdfColors.blue800),
                          ),
                          pw.Text(
                            'مجهزة للقص والتغليف الحراري (8 بطاقات / صفحة)'.fixArabic,
                            style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Cards Grid (2 cols x 4 rows)
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: 2,
                    childAspectRatio: 1.55,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    children: chunk.map((stu) {
                      final name = stu['name']?.toString() ?? 'طالب معتمد';
                      final code = stu['code']?.toString() ?? 'STU-000';
                      final phone = stu['phone']?.toString() ?? '';
                      final grade = stu['grade']?.toString() ?? (groupName ?? 'طالب بالسنتر');

                      return pw.Container(
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(
                            color: PdfColors.grey400,
                            width: 1,
                            style: pw.BorderStyle.dashed,
                          ),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 8,
                          verticalRadius: 8,
                          child: pw.Column(
                            children: [
                              // Top Header Bar
                              pw.Container(
                                width: double.infinity,
                                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                color: PdfColors.indigo900,
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      centerName.fixArabic,
                                      style: boldStyle.copyWith(color: PdfColors.white, fontSize: 8),
                                    ),
                                    pw.Text(
                                      'بطاقة سنتر معتمدة'.fixArabic,
                                      style: boldStyle.copyWith(color: PdfColors.amberAccent, fontSize: 7),
                                    ),
                                  ],
                                ),
                              ),

                              // Body
                              pw.Expanded(
                                child: pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Row(
                                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                                    children: [
                                      // QR Code Column
                                      pw.Column(
                                        mainAxisAlignment: pw.MainAxisAlignment.center,
                                        children: [
                                          pw.Container(
                                            padding: const pw.EdgeInsets.all(3),
                                            decoration: pw.BoxDecoration(
                                              border: pw.Border.all(color: PdfColors.grey300),
                                              borderRadius: pw.BorderRadius.circular(4),
                                            ),
                                            child: pw.BarcodeWidget(
                                              barcode: pw.Barcode.qrCode(),
                                              data: code,
                                              width: 58,
                                              height: 58,
                                            ),
                                          ),
                                          pw.SizedBox(height: 3),
                                          pw.Text(
                                            'مسح البوابة'.fixArabic,
                                            style: regularStyle.copyWith(fontSize: 6, color: PdfColors.grey700),
                                          ),
                                        ],
                                      ),
                                      pw.SizedBox(width: 8),

                                      // Student Details Column
                                      pw.Expanded(
                                        child: pw.Column(
                                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                                          mainAxisAlignment: pw.MainAxisAlignment.center,
                                          children: [
                                            pw.Text(
                                              name.fixArabic,
                                              maxLines: 1,
                                              style: boldStyle.copyWith(
                                                fontSize: 10,
                                                color: PdfColors.black,
                                              ),
                                            ),
                                            pw.SizedBox(height: 4),
                                            pw.Container(
                                              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: pw.BoxDecoration(
                                                color: PdfColors.grey100,
                                                borderRadius: pw.BorderRadius.circular(3),
                                              ),
                                              child: pw.Text(
                                                'الكود: $code'.fixArabic,
                                                style: boldStyle.copyWith(
                                                  fontSize: 8,
                                                  color: PdfColors.indigo800,
                                                ),
                                              ),
                                            ),
                                            pw.SizedBox(height: 3),
                                            pw.Text(
                                              'المرحلة: $grade'.fixArabic,
                                              maxLines: 1,
                                              style: regularStyle.copyWith(
                                                fontSize: 7,
                                                color: PdfColors.grey800,
                                              ),
                                            ),
                                            if (phone.isNotEmpty) ...[
                                              pw.SizedBox(height: 2),
                                              pw.Text(
                                                'هاتف ولي الأمر: $phone'.fixArabic,
                                                style: regularStyle.copyWith(
                                                  fontSize: 6.5,
                                                  color: PdfColors.grey700,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Card Footer Strip
                              pw.Container(
                                width: double.infinity,
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                color: PdfColors.grey100,
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      'صالحة للعام: $academicYear'.fixArabic,
                                      style: regularStyle.copyWith(fontSize: 6, color: PdfColors.grey700),
                                    ),
                                    pw.Text(
                                      'Brivio Center Pass'.fixArabic,
                                      style: regularStyle.copyWith(fontSize: 6, color: PdfColors.grey600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    if (printDirectly) {
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } else {
      await _saveAndSharePdf(pdf, 'Bulk_Student_ID_Cards_${groupName ?? "Center"}.pdf');
    }
  }

  /// Generates the Official Daily Cash Register & Shift Closing Statement PDF (محضر جرد وتقفيل الخزينة اليومية)
  /// Reconciles cash drawer contents against system recorded receipts and teacher payouts.
  Future<void> generateDailyCashRegisterClosingPdf({
    required String centerName,
    required String shiftName,
    required String cashierName,
    required String dateStr,
    required int receiptsCount,
    required double totalGrossCashInflow,
    required double totalTeacherPayouts,
    required double netExpectedCash,
    required double actualCountedCash,
    required double discrepancy,
    required String notes,
    required Map<String, int> denominationsCount,
    required List<Map<String, dynamic>> transactionLog,
    bool printDirectly = false,
  }) async {
    final pdf = await createDocument();
    final boldFont = await getBoldFont();
    final regularFont = await getRegularFont();

    final boldStyle = pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold);
    final regularStyle = pw.TextStyle(font: regularFont);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          final isDiscrepancyZero = discrepancy.abs() < 0.01;
          final isSurplus = discrepancy > 0;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey900,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          centerName.fixArabic,
                          style: boldStyle.copyWith(color: PdfColors.white, fontSize: 18),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'محضر جرد وتقفيل الخزينة النقدية اليومية (Daily Shift Closing Voucher)'.fixArabic,
                          style: regularStyle.copyWith(color: PdfColors.amberAccent, fontSize: 9),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'الوردية: $shiftName'.fixArabic,
                          style: boldStyle.copyWith(color: PdfColors.white, fontSize: 10),
                        ),
                        pw.Text(
                          'التاريخ: $dateStr'.fixArabic,
                          style: regularStyle.copyWith(color: PdfColors.grey300, fontSize: 9),
                        ),
                        pw.Text(
                          'مسؤول الخزينة: $cashierName'.fixArabic,
                          style: regularStyle.copyWith(color: PdfColors.grey300, fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // KPI Summary Cards in Row
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildMetricBox(
                      title: 'إجمالي المقبوضات ($receiptsCount عملية)',
                      value: '${totalGrossCashInflow.toStringAsFixed(1)} ج.م',
                      color: PdfColors.green800,
                      bgColor: PdfColors.green50,
                      boldStyle: boldStyle,
                      regularStyle: regularStyle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _buildMetricBox(
                      title: 'منصرفات وتصفيات المدرسين',
                      value: '${totalTeacherPayouts.toStringAsFixed(1)} ج.م',
                      color: PdfColors.orange800,
                      bgColor: PdfColors.orange50,
                      boldStyle: boldStyle,
                      regularStyle: regularStyle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _buildMetricBox(
                      title: 'الصافي المتوقع بالدرج',
                      value: '${netExpectedCash.toStringAsFixed(1)} ج.م',
                      color: PdfColors.blue800,
                      bgColor: PdfColors.blue50,
                      boldStyle: boldStyle,
                      regularStyle: regularStyle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _buildMetricBox(
                      title: 'النقدية المحصية فعلياً',
                      value: '${actualCountedCash.toStringAsFixed(1)} ج.م',
                      color: isDiscrepancyZero
                          ? PdfColors.teal800
                          : (isSurplus ? PdfColors.blue800 : PdfColors.red800),
                      bgColor: isDiscrepancyZero ? PdfColors.teal50 : PdfColors.red50,
                      boldStyle: boldStyle,
                      regularStyle: regularStyle,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // Reconciliation Status Banner
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: isDiscrepancyZero
                      ? PdfColors.green50
                      : (isSurplus ? PdfColors.blue50 : PdfColors.red50),
                  border: pw.Border.all(
                    color: isDiscrepancyZero
                        ? PdfColors.green700
                        : (isSurplus ? PdfColors.blue700 : PdfColors.red700),
                    width: 1,
                  ),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      (isDiscrepancyZero
                          ? 'حالة الجرد: الدرج مطابق تماماً لسجلات النظام الإلكتروني (مطابقة تامة 100%)'
                          : (isSurplus
                              ? 'حالة الجرد: يوجد فائض/زيادة نقدية بالدرج بمقدار: +${discrepancy.toStringAsFixed(1)} ج.م'
                              : 'حالة الجرد: يوجد عجز نقدي بالدرج بمقدار: -${discrepancy.abs().toStringAsFixed(1)} ج.م')).fixArabic,
                      style: boldStyle.copyWith(
                        fontSize: 9.5,
                        color: isDiscrepancyZero
                            ? PdfColors.green900
                            : (isSurplus ? PdfColors.blue900 : PdfColors.red900),
                      ),
                    ),
                    pw.Text(
                      'الفارق: ${discrepancy.toStringAsFixed(1)} EGP'.fixArabic,
                      style: boldStyle.copyWith(
                        fontSize: 10,
                        color: isDiscrepancyZero ? PdfColors.green900 : PdfColors.red900,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Banknotes Denominations Breakdown
              pw.Text(
                'تفصيل فئات النقدية المعدودة بالدرج (Banknote Denomination Breakdown):'.fixArabic,
                style: boldStyle.copyWith(fontSize: 9, color: PdfColors.blueGrey800),
              ),
              pw.SizedBox(height: 4),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ArabicPdfHelper.fixHeaders(['الفئة النقدية', 'عدد الأوراق', 'المبلغ الإجمالي (ج.م)']),
                data: ArabicPdfHelper.fixData([
                  ['فئة 200 ج.م', '${denominationsCount['200'] ?? 0} ورقة', '${((denominationsCount['200'] ?? 0) * 200).toStringAsFixed(1)} ج.م'],
                  ['فئة 100 ج.م', '${denominationsCount['100'] ?? 0} ورقة', '${((denominationsCount['100'] ?? 0) * 100).toStringAsFixed(1)} ج.م'],
                  ['فئة 50 ج.م', '${denominationsCount['50'] ?? 0} ورقة', '${((denominationsCount['50'] ?? 0) * 50).toStringAsFixed(1)} ج.م'],
                  ['فئة 20 ج.م', '${denominationsCount['20'] ?? 0} ورقة', '${((denominationsCount['20'] ?? 0) * 20).toStringAsFixed(1)} ج.م'],
                  ['فئة 10 ج.م', '${denominationsCount['10'] ?? 0} ورقة', '${((denominationsCount['10'] ?? 0) * 10).toStringAsFixed(1)} ج.م'],
                  ['فئات معدنية / أخرى', '-', '${(denominationsCount['coins'] ?? 0).toStringAsFixed(1)} ج.م'],
                ]),
                headerStyle: boldStyle.copyWith(color: PdfColors.white, fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: regularStyle.copyWith(fontSize: 8),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
                ),
              ),
              pw.SizedBox(height: 8),

              if (notes.isNotEmpty) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'ملاحظات مسؤول الوردية: $notes'.fixArabic,
                    style: regularStyle.copyWith(fontSize: 8, color: PdfColors.grey800),
                  ),
                ),
                pw.SizedBox(height: 8),
              ],

              // Signatures
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('توقيع مسؤول الخزينة (الكاشير)'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                      pw.SizedBox(height: 25),
                      pw.Container(width: 140, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text(cashierName.fixArabic, style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('توقيع المشرف المالي / المحاسب'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                      pw.SizedBox(height: 25),
                      pw.Container(width: 140, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text('المراجعة والاعتماد'.fixArabic, style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('اعتماد الإدارة العامة للسنتر'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                      pw.SizedBox(height: 25),
                      pw.Container(width: 140, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text('ختم السنتر الرسمي'.fixArabic, style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Brivio Educational Platform • وثيقة تقفيل وردية رسمية معتمدة'.fixArabic,
                  style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey500),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (printDirectly) {
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } else {
      await _saveAndSharePdf(pdf, 'Daily_Shift_Closing_${dateStr.replaceAll('/', '_')}.pdf');
    }
  }

  pw.Widget _buildMetricBox({
    required String title,
    required String value,
    required PdfColor color,
    required PdfColor bgColor,
    required pw.TextStyle boldStyle,
    required pw.TextStyle regularStyle,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: color, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            title.fixArabic,
            style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey800),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value.fixArabic,
            style: boldStyle.copyWith(fontSize: 10.5, color: color),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Generates a Printable Exam Paper with Answer Key PDF (شيت امتحان ورقي مطبوع مع نموذج إجابة للمساعدين)
  Future<void> generatePrintableExamSheet({
    required String centerName,
    required String examTitle,
    required String subjectName,
    required String teacherName,
    required int durationMinutes,
    required double passScore,
    required List<Map<String, dynamic>> questions,
    String? groupName,
    String academicYear = '2025 / 2026',
    String instructions = 'أجب عن جميع الأسئلة الآتية - ممنوع استخدام الهاتف المحمول - زمن الاختبار محدد بالأعلى',
    bool includeBubbleSheet = true,
    bool printDirectly = false,
  }) async {
    final pdf = await createDocument();

    final boldFont = await getBoldFont();
    final regularFont = await getRegularFont();

    final boldStyle = pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold);
    final regularStyle = pw.TextStyle(font: regularFont);

    double totalPoints = 0;
    for (final q in questions) {
      totalPoints += (q['points'] as num? ?? 1.0).toDouble();
    }

    // Page 1: Student Exam Paper
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        header: (context) {
          return pw.Column(
            children: [
              // Exam Top Banner
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blueGrey800, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              centerName.fixArabic,
                              style: boldStyle.copyWith(fontSize: 14, color: PdfColors.blueGrey900),
                            ),
                            pw.Text(
                              'المادة: $subjectName • الأستاذ: $teacherName'.fixArabic,
                              style: regularStyle.copyWith(fontSize: 9, color: PdfColors.grey800),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.blueGrey800,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                examTitle.fixArabic,
                                style: boldStyle.copyWith(fontSize: 12, color: PdfColors.white),
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              (groupName != null ? 'المجموعة: $groupName' : 'العام الدراسي: $academicYear').fixArabic,
                              style: regularStyle.copyWith(fontSize: 8, color: PdfColors.grey700),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'الزمن: $durationMinutes دقيقة'.fixArabic,
                              style: boldStyle.copyWith(fontSize: 9, color: PdfColors.blueGrey900),
                            ),
                            pw.Text(
                              'الدرجة الكلية: ${totalPoints.toStringAsFixed(0)} درجة'.fixArabic,
                              style: boldStyle.copyWith(fontSize: 9, color: PdfColors.blue800),
                            ),
                            pw.Text(
                              'درجة النجاح: ${passScore.toStringAsFixed(0)}'.fixArabic,
                              style: regularStyle.copyWith(fontSize: 8, color: PdfColors.grey700),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    // Student fillable info
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'اسم الطالب: .............................................................'.fixArabic,
                            style: regularStyle.copyWith(fontSize: 8.5, color: PdfColors.black),
                          ),
                          pw.Text(
                            'رقم الجلوس / الكود: ...................'.fixArabic,
                            style: regularStyle.copyWith(fontSize: 8.5, color: PdfColors.black),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey400),
                              color: PdfColors.white,
                            ),
                            child: pw.Text(
                              'الدرجة المستحقة: [     / ${totalPoints.toStringAsFixed(0)} ]'.fixArabic,
                              style: boldStyle.copyWith(fontSize: 8.5, color: PdfColors.blue900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                color: PdfColors.grey200,
                child: pw.Text(
                  'تعليمات: $instructions'.fixArabic,
                  style: regularStyle.copyWith(fontSize: 7.5, color: PdfColors.grey800),
                ),
              ),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Brivio Educational Platform • ورقة اختبار رسمي'.fixArabic,
                style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey600),
              ),
              pw.Text(
                'صفحة ${context.pageNumber} من ${context.pagesCount}'.fixArabic,
                style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          );
        },
        build: (context) {
          return [
            ...questions.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final q = entry.value;
              final prompt = q['prompt']?.toString() ?? '';
              final points = (q['points'] as num? ?? 1.0).toDouble();
              final type = q['type']?.toString() ?? 'multiple_choice';
              final options = (q['options'] as List<dynamic>?) ?? [];

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 14),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Question Header & Prompt
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blueGrey800,
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                          child: pw.Text(
                            'س $idx'.fixArabic,
                            style: boldStyle.copyWith(color: PdfColors.white, fontSize: 8),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Text(
                            prompt.fixArabic,
                            style: boldStyle.copyWith(fontSize: 9.5, color: PdfColors.black),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          '(${points.toStringAsFixed(0)} درجات)'.fixArabic,
                          style: regularStyle.copyWith(fontSize: 8, color: PdfColors.blue800),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),

                    // Options or Answer space based on type
                    if (type == 'multiple_choice' || type == 'mcq') ...[
                      pw.Column(
                        children: options.asMap().entries.map((optEntry) {
                          final optIdx = optEntry.key;
                          final optText = optEntry.value is Map
                              ? (optEntry.value['text']?.toString() ?? '')
                              : optEntry.value.toString();
                          final letters = ['أ', 'ب', 'ج', 'د', 'هـ'];
                          final letter = optIdx < letters.length ? letters[optIdx] : '${optIdx + 1}';

                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 4),
                            child: pw.Row(
                              children: [
                                pw.Container(
                                  width: 14,
                                  height: 14,
                                  decoration: pw.BoxDecoration(
                                    shape: pw.BoxShape.circle,
                                    border: pw.Border.all(color: PdfColors.grey500),
                                  ),
                                  child: pw.Center(
                                    child: pw.Text(
                                      letter.fixArabic,
                                      style: boldStyle.copyWith(fontSize: 7),
                                    ),
                                  ),
                                ),
                                pw.SizedBox(width: 6),
                                pw.Expanded(
                                  child: pw.Text(
                                    optText.fixArabic,
                                    style: regularStyle.copyWith(fontSize: 8.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ] else if (type == 'true_false') ...[
                      pw.Row(
                        children: [
                          pw.SizedBox(width: 20),
                          pw.Text('[      ]  صواب (True)'.fixArabic, style: regularStyle.copyWith(fontSize: 8.5)),
                          pw.SizedBox(width: 40),
                          pw.Text('[      ]  خطأ (False)'.fixArabic, style: regularStyle.copyWith(fontSize: 8.5)),
                        ],
                      ),
                    ] else ...[
                      // Lined answer area for short/essay
                      pw.Container(
                        height: 35,
                        margin: const pw.EdgeInsets.only(top: 4),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColors.grey400, style: pw.BorderStyle.dashed),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    // Final Page: Official Answer Key for Teaching Assistants (نموذج الإجابة المعتمد)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Answer Key Header
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal900,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '$centerName • نموذج الإجابة الرسمي وتوزيع الدرجات'.fixArabic,
                          style: boldStyle.copyWith(color: PdfColors.white, fontSize: 13),
                        ),
                        pw.Text(
                          'مخصص لمساعدي المدرس والسكرتارية لتصحيح الاختبار'.fixArabic,
                          style: regularStyle.copyWith(color: PdfColors.amberAccent, fontSize: 8),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'اختبار: $examTitle'.fixArabic,
                          style: boldStyle.copyWith(color: PdfColors.white, fontSize: 10),
                        ),
                        pw.Text(
                          'المدرس: $teacherName'.fixArabic,
                          style: regularStyle.copyWith(color: PdfColors.grey300, fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Answer Table
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ArabicPdfHelper.fixHeaders(['رقم السؤال', 'نوع السؤال', 'الإجابة النموذجية الصحيحة', 'الدرجة']),
                data: ArabicPdfHelper.fixData(questions.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final q = entry.value;
                  final type = q['type']?.toString() ?? 'multiple_choice';
                  final points = (q['points'] as num? ?? 1.0).toDouble();
                  final options = (q['options'] as List<dynamic>?) ?? [];

                  String answerStr = q['answer']?.toString() ?? '';
                  if (answerStr.isEmpty && options.isNotEmpty) {
                    final correctOpt = options
                        .where((o) => o is Map && (o['is_correct'] == true))
                        .firstOrNull;
                    if (correctOpt != null && correctOpt is Map) {
                      answerStr = correctOpt['text']?.toString() ?? '';
                    } else {
                      answerStr = 'راجع الشرح';
                    }
                  }

                  String typeLabel = 'اختيار متعدد';
                  if (type == 'true_false') typeLabel = 'صواب / خطأ';
                  if (type == 'short_answer') typeLabel = 'سؤال مقالي';

                  return [
                    'س $idx',
                    typeLabel,
                    answerStr.isNotEmpty ? answerStr : 'حسب تقدير المساعد',
                    '${points.toStringAsFixed(0)} درجات',
                  ];
                }).toList()),
                headerStyle: boldStyle.copyWith(color: PdfColors.white, fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
                cellStyle: regularStyle.copyWith(fontSize: 8),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
                ),
              ),
              pw.SizedBox(height: 16),

              // Total Calculation Banner
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal50,
                  border: pw.Border.all(color: PdfColors.teal800),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'إجمالي درجات الامتحان: ${totalPoints.toStringAsFixed(0)} درجة • درجة الاجتياز والنجاح: ${passScore.toStringAsFixed(0)} درجة'.fixArabic,
                      style: boldStyle.copyWith(fontSize: 9, color: PdfColors.teal900),
                    ),
                    pw.Text(
                      'Total: ${totalPoints.toStringAsFixed(0)} Marks'.fixArabic,
                      style: boldStyle.copyWith(fontSize: 9, color: PdfColors.teal900),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('توقيع المدرس المعتمد'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                      pw.SizedBox(height: 25),
                      pw.Container(width: 130, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text(teacherName.fixArabic, style: regularStyle.copyWith(fontSize: 7)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('توقيع مساعد التصحيح'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                      pw.SizedBox(height: 25),
                      pw.Container(width: 130, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text('مساعد المادة'.fixArabic, style: regularStyle.copyWith(fontSize: 7)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('ختم السنتر الرسمي'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                      pw.SizedBox(height: 25),
                      pw.Container(width: 130, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text(centerName.fixArabic, style: regularStyle.copyWith(fontSize: 7)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    // Page: Printable Bubble Sheet (ورقة إجابة البابل شيت القياسية للسنتر وتصحيح الـ OMR)
    if (includeBubbleSheet) {
      pdf.addPage(
        _buildBubbleSheetPage(
          centerName: centerName,
          examTitle: examTitle,
          subjectName: subjectName,
          teacherName: teacherName,
          groupName: groupName,
          questionCount: questions.isNotEmpty ? questions.length : 30,
          boldStyle: boldStyle,
          regularStyle: regularStyle,
          questions: questions,
        ),
      );
    }

    if (printDirectly) {
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } else {
      await _saveAndSharePdf(pdf, 'Printable_Exam_${examTitle.replaceAll(' ', '_')}.pdf');
    }
  }

  /// Generates a standalone high-precision Bubble Sheet (OMR) PDF for printing in Egyptian Educational Centers
  Future<void> generateStandaloneBubbleSheetPdf({
    required String centerName,
    required String teacherName,
    required String examTitle,
    String? groupName,
    String? subjectName,
    int questionCount = 30,
    bool printDirectly = false,
  }) async {
    final pdf = await createDocument();
    final boldFont = await getBoldFont();
    final regularFont = await getRegularFont();

    final boldStyle = pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold);
    final regularStyle = pw.TextStyle(font: regularFont);

    pdf.addPage(
      _buildBubbleSheetPage(
        centerName: centerName,
        examTitle: examTitle,
        subjectName: subjectName ?? 'المادة الدراسية',
        teacherName: teacherName,
        groupName: groupName,
        questionCount: questionCount,
        boldStyle: boldStyle,
        regularStyle: regularStyle,
      ),
    );

    if (printDirectly) {
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } else {
      await _saveAndSharePdf(pdf, 'Bubble_Sheet_${examTitle.replaceAll(' ', '_')}.pdf');
    }
  }

  pw.Page _buildBubbleSheetPage({
    required String centerName,
    required String examTitle,
    required String subjectName,
    required String teacherName,
    String? groupName,
    required int questionCount,
    required pw.TextStyle boldStyle,
    required pw.TextStyle regularStyle,
    List<Map<String, dynamic>>? questions,
    bool isAnswerKey = false,
  }) {
    final effectiveCount = questionCount.clamp(10, 45);
    final columnsCount = effectiveCount > 30 ? 3 : 2;
    final questionsPerCol = (effectiveCount / columnsCount).ceil();

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      build: (context) {
        return pw.Column(
          children: [
            // Top OMR Alignment Marks (solid black squares)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(width: 14, height: 14, color: PdfColors.black),
                pw.Text(
                  'نظام التصحيح الإلكتروني والماسح الضوئي (OMR) • معتمد لدى السنتر'.fixArabic,
                  style: regularStyle.copyWith(fontSize: 7.5, color: PdfColors.grey700),
                ),
                pw.Container(width: 14, height: 14, color: PdfColors.black),
              ],
            ),
            pw.SizedBox(height: 6),

            // Top Header: Center & Exam Info
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.2),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        centerName.fixArabic,
                        style: boldStyle.copyWith(fontSize: 12, color: PdfColors.black),
                      ),
                      pw.Text(
                        'المادة: $subjectName • الأستاذ: $teacherName'.fixArabic,
                        style: regularStyle.copyWith(fontSize: 8, color: PdfColors.grey900),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.black,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Text(
                      'ورقة إجابة البابل شيت (Bubble Sheet)'.fixArabic,
                      style: boldStyle.copyWith(fontSize: 10, color: PdfColors.white),
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'اختبار: $examTitle'.fixArabic,
                        style: boldStyle.copyWith(fontSize: 9, color: PdfColors.black),
                      ),
                      pw.Text(
                        (groupName != null && groupName.isNotEmpty ? 'المجموعة: $groupName' : 'العام: 2025/2026').fixArabic,
                        style: regularStyle.copyWith(fontSize: 8, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 6),

            // Mid Row: Student Details + Form Selector + Student Code Matrix
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Student Text Details Box
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.black, width: 0.8),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('اسم الطالب: ..............................................................'.fixArabic, style: regularStyle.copyWith(fontSize: 8.5)),
                        pw.SizedBox(height: 6),
                        pw.Text('المدرسة / الإدارة: .....................................................'.fixArabic, style: regularStyle.copyWith(fontSize: 8.5)),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('رقم القاعة: ...........'.fixArabic, style: regularStyle.copyWith(fontSize: 8.5)),
                            pw.Text('رقم المقعد: ...........'.fixArabic, style: regularStyle.copyWith(fontSize: 8.5)),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        // Exam Form Selector (A B C D)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: pw.BorderRadius.circular(3),
                            border: pw.Border.all(color: PdfColors.grey400),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Text('نموذج الاختبار:'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                              pw.SizedBox(width: 8),
                              ...['أ', 'ب', 'ج', 'د'].map((formLetter) {
                                return pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Row(
                                    children: [
                                      pw.Container(
                                        width: 11,
                                        height: 11,
                                        decoration: pw.BoxDecoration(
                                          shape: pw.BoxShape.circle,
                                          border: pw.Border.all(color: PdfColors.black, width: 0.8),
                                        ),
                                        child: pw.Center(
                                          child: pw.Text(formLetter.fixArabic, style: boldStyle.copyWith(fontSize: 6.5)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),

                // Student Code Shading Grid (5 Digits x 0..9)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text('رقم الجلوس / كود الطالب'.fixArabic, style: boldStyle.copyWith(fontSize: 7.5)),
                      pw.SizedBox(height: 3),
                      // Top Row: Digits Write Boxes
                      pw.Row(
                        children: List.generate(5, (_) => pw.Container(
                          width: 14,
                          height: 14,
                          margin: const pw.EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.black, width: 0.8),
                          ),
                        )),
                      ),
                      pw.SizedBox(height: 3),
                      // 0..9 Circles Grid
                      ...List.generate(10, (digit) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
                          child: pw.Row(
                            children: List.generate(5, (_) => pw.Container(
                              width: 12,
                              height: 11,
                              margin: const pw.EdgeInsets.symmetric(horizontal: 2.5),
                              decoration: pw.BoxDecoration(
                                shape: pw.BoxShape.circle,
                                border: pw.Border.all(color: PdfColors.grey800, width: 0.6),
                              ),
                              child: pw.Center(
                                child: pw.Text('$digit', style: regularStyle.copyWith(fontSize: 6)),
                              ),
                            )),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            // Instructions Bar
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              child: pw.Text(
                'تعليمات التظليل: استخدم قلم جاف أزرق أو أسود • ظلل الدائرة بالكامل هكذا • تجنب علامات (X) والتظليل الجزئي • ممنوع استخدام الكوريكتور'.fixArabic,
                textAlign: pw.TextAlign.center,
                style: boldStyle.copyWith(fontSize: 7, color: PdfColors.black),
              ),
            ),
            pw.SizedBox(height: 8),

            // Main Answer Matrix (Columns of Questions)
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: List.generate(columnsCount, (colIdx) {
                  final startQ = (colIdx * questionsPerCol) + 1;
                  final endQ = (startQ + questionsPerCol - 1) < effectiveCount
                      ? (startQ + questionsPerCol - 1)
                      : effectiveCount;

                  return pw.Expanded(
                    child: pw.Container(
                      margin: pw.EdgeInsets.only(left: colIdx == 0 ? 0 : 6),
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 0.8),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        children: [
                          // Col Header
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2),
                            color: PdfColors.grey100,
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                              children: [
                                pw.Text('رقم'.fixArabic, style: boldStyle.copyWith(fontSize: 7)),
                                pw.Text('أ'.fixArabic, style: boldStyle.copyWith(fontSize: 7)),
                                pw.Text('ب'.fixArabic, style: boldStyle.copyWith(fontSize: 7)),
                                pw.Text('ج'.fixArabic, style: boldStyle.copyWith(fontSize: 7)),
                                pw.Text('د'.fixArabic, style: boldStyle.copyWith(fontSize: 7)),
                              ],
                            ),
                          ),
                          pw.Divider(thickness: 0.5, height: 4, color: PdfColors.grey400),
                          // Question Rows
                          ...List.generate(endQ - startQ + 1, (rowIdx) {
                            final qNum = startQ + rowIdx;
                            final qData = (questions != null && qNum - 1 < questions.length)
                                ? questions[qNum - 1]
                                : null;
                            final opts = (qData?['options'] as List<dynamic>?) ?? [];
                            int? correctIdx;
                            if (opts.isNotEmpty) {
                              for (int oi = 0; oi < opts.length; oi++) {
                                final opt = opts[oi];
                                if (opt is Map && (opt['is_correct'] == true || opt['isCorrect'] == true)) {
                                  correctIdx = oi;
                                  break;
                                }
                              }
                            }

                            return pw.Container(
                              height: 17,
                              margin: const pw.EdgeInsets.symmetric(vertical: 1.5),
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                              decoration: pw.BoxDecoration(
                                color: (rowIdx % 2 == 1) ? PdfColors.grey50 : PdfColors.white,
                                borderRadius: pw.BorderRadius.circular(2),
                              ),
                              child: pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  // Q Number box
                                  pw.Container(
                                    width: 18,
                                    height: 14,
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.grey200,
                                      borderRadius: pw.BorderRadius.circular(2),
                                    ),
                                    child: pw.Center(
                                      child: pw.Text(
                                        qNum.toString().padLeft(2, '0'),
                                        style: boldStyle.copyWith(fontSize: 6.5),
                                      ),
                                    ),
                                  ),
                                  // 4 Option Bubbles: أ ب ج د
                                  ...List.generate(4, (optIdx) {
                                    final isThisCorrect = isAnswerKey && (correctIdx == optIdx);
                                    final letters = ['أ', 'ب', 'ج', 'د'];
                                    return pw.Container(
                                      width: 14,
                                      height: 14,
                                      decoration: pw.BoxDecoration(
                                        shape: pw.BoxShape.circle,
                                        color: isThisCorrect ? PdfColors.black : PdfColors.white,
                                        border: pw.Border.all(
                                          color: isThisCorrect ? PdfColors.black : PdfColors.grey700,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: pw.Center(
                                        child: pw.Text(
                                          letters[optIdx].fixArabic,
                                          style: boldStyle.copyWith(
                                            fontSize: 6.5,
                                            color: isThisCorrect ? PdfColors.white : PdfColors.black,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            pw.SizedBox(height: 8),

            // Bottom OMR Score Summary & Stamp Box
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.0),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('خاص بلجنة التصحيح والكنترول:'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                  pw.Text('الإجابات الصحيحة: [       ]'.fixArabic, style: regularStyle.copyWith(fontSize: 7.5)),
                  pw.Text('الخاطئة: [       ]'.fixArabic, style: regularStyle.copyWith(fontSize: 7.5)),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.black, width: 0.8),
                    ),
                    child: pw.Text('الدرجة النهائية: [       / $effectiveCount ]'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                  ),
                  pw.Text('توقيع المصحح: ...................'.fixArabic, style: regularStyle.copyWith(fontSize: 7.5)),
                ],
              ),
            ),
            pw.SizedBox(height: 6),

            // Bottom Alignment Marks
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(width: 14, height: 14, color: PdfColors.black),
                pw.Text(
                  'Brivio Assessment Engine • كود النموذج: B-OMR-${effectiveCount}Q'.fixArabic,
                  style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey600),
                ),
                pw.Container(width: 14, height: 14, color: PdfColors.black),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Generates a Homework Submissions & Grade Roster PDF (كشف تسليمات ودرجات الواجب الرسمي للسنتر)
  Future<void> generateHomeworkSubmissionsRosterPdf({
    required String centerName,
    required String homeworkTitle,
    required String subjectName,
    required String teacherName,
    required String groupName,
    required DateTime dueAt,
    required double maxScore,
    required List<Map<String, dynamic>> submissionsData,
    bool printDirectly = false,
  }) async {
    final pdf = await createDocument();

    final boldFont = await getBoldFont();
    final regularFont = await getRegularFont();

    final boldStyle = pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold);
    final regularStyle = pw.TextStyle(font: regularFont);

    final totalStudents = submissionsData.length;
    final submittedCount = submissionsData.where((s) => s['is_submitted'] == true).length;
    final missingCount = totalStudents - submittedCount;
    final submissionRate = totalStudents > 0 ? (submittedCount / totalStudents) * 100 : 0.0;
    
    double totalGrades = 0;
    int gradedCount = 0;
    for (final s in submissionsData) {
      if (s['score'] != null) {
        totalGrades += (s['score'] as num).toDouble();
        gradedCount++;
      }
    }
    final avgScore = gradedCount > 0 ? totalGrades / gradedCount : 0.0;

    final formattedDue = '${dueAt.year}-${dueAt.month.toString().padLeft(2, '0')}-${dueAt.day.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        header: (context) {
          return pw.Column(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo900,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '$centerName • كشف تسليمات وتصحيح الواجب'.fixArabic,
                          style: boldStyle.copyWith(color: PdfColors.white, fontSize: 13),
                        ),
                        pw.Text(
                          'المادة: $subjectName • الأستاذ: $teacherName • المجموعة: $groupName'.fixArabic,
                          style: regularStyle.copyWith(color: PdfColors.amberAccent, fontSize: 8),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'واجب: $homeworkTitle'.fixArabic,
                          style: boldStyle.copyWith(color: PdfColors.white, fontSize: 10),
                        ),
                        pw.Text(
                          'موعد التسليم: $formattedDue • الدرجة: ${maxScore.toStringAsFixed(0)}'.fixArabic,
                          style: regularStyle.copyWith(color: PdfColors.grey300, fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              // Metrics Row
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildMetricBox(
                      title: 'إجمالي طلاب المجموعة',
                      value: '$totalStudents طالب',
                      color: PdfColors.blueGrey800,
                      bgColor: PdfColors.blueGrey50,
                      boldStyle: boldStyle,
                      regularStyle: regularStyle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _buildMetricBox(
                      title: 'تم تسليم الواجب',
                      value: '$submittedCount طالب (${submissionRate.toStringAsFixed(0)}%)',
                      color: PdfColors.green800,
                      bgColor: PdfColors.green50,
                      boldStyle: boldStyle,
                      regularStyle: regularStyle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _buildMetricBox(
                      title: 'لم يسلّم (غائب/متأخر)',
                      value: '$missingCount طالب',
                      color: missingCount > 0 ? PdfColors.red800 : PdfColors.grey700,
                      bgColor: missingCount > 0 ? PdfColors.red50 : PdfColors.grey100,
                      boldStyle: boldStyle,
                      regularStyle: regularStyle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _buildMetricBox(
                      title: 'متوسط درجات الطلاب',
                      value: '${avgScore.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(0)}',
                      color: PdfColors.purple800,
                      bgColor: PdfColors.purple50,
                      boldStyle: boldStyle,
                      regularStyle: regularStyle,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Brivio Educational Platform • تقرير رسمي معتمد'.fixArabic,
                style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey600),
              ),
              pw.Text(
                'صفحة ${context.pageNumber} من ${context.pagesCount}'.fixArabic,
                style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          );
        },
        build: (context) {
          return [
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ArabicPdfHelper.fixHeaders(['م', 'كود الطالب', 'اسم الطالب', 'حالة التسليم', 'تاريخ التسليم', 'الدرجة', 'ملاحظات المعلم']),
              data: ArabicPdfHelper.fixData(submissionsData.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final s = entry.value;
                final isSubmitted = s['is_submitted'] == true;
                final isLate = s['is_late'] == true;
                final statusStr = !isSubmitted
                    ? 'لم يسلّم بعد ❌'
                    : (isLate ? 'مسلّم متأخر ⚠️' : 'مسلّم في الموعد ✔️');
                final scoreVal = s['score'] != null ? '${s['score']} / ${maxScore.toStringAsFixed(0)}' : (isSubmitted ? 'قيد التصحيح' : '-');
                final subDate = s['submitted_at']?.toString() ?? '-';
                final feedback = s['feedback']?.toString() ?? '-';

                return [
                  '$idx',
                  s['student_code']?.toString() ?? '-',
                  s['student_name']?.toString() ?? 'طالب',
                  statusStr,
                  subDate,
                  scoreVal,
                  feedback,
                ];
              }).toList()),
              headerStyle: boldStyle.copyWith(color: PdfColors.white, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
              cellStyle: regularStyle.copyWith(fontSize: 7.5),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
              ),
            ),
            pw.SizedBox(height: 24),
            // Signatures block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text('توقيع المدرس المعتمد'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                    pw.SizedBox(height: 25),
                    pw.Container(width: 130, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 2),
                    pw.Text(teacherName.fixArabic, style: regularStyle.copyWith(fontSize: 7)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('توقيع المشرف التعليمي'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                    pw.SizedBox(height: 25),
                    pw.Container(width: 130, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 2),
                    pw.Text('إدارة المتابعة والتنسيق'.fixArabic, style: regularStyle.copyWith(fontSize: 7)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('ختم السنتر الرسمي'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                    pw.SizedBox(height: 25),
                    pw.Container(width: 130, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 2),
                    pw.Text(centerName.fixArabic, style: regularStyle.copyWith(fontSize: 7)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    if (printDirectly) {
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } else {
      await _saveAndSharePdf(pdf, 'Homework_Roster_${homeworkTitle.replaceAll(' ', '_')}.pdf');
    }
  }

  /// Generates a Printable Homework Worksheet PDF (شيت واجب ورقي مطبوع للطلاب)
  Future<void> generatePrintableHomeworkSheet({
    required String centerName,
    required String homeworkTitle,
    required String subjectName,
    required String teacherName,
    required double maxScore,
    required List<Map<String, dynamic>> questions,
    DateTime? dueAt,
    String? groupName,
    String academicYear = '2025 / 2026',
    bool printDirectly = false,
  }) async {
    final pdf = await createDocument();
    final boldFont = await getBoldFont();
    final regularFont = await getRegularFont();

    final boldStyle = pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold);
    final regularStyle = pw.TextStyle(font: regularFont);

    final formattedDue = dueAt != null ? '${dueAt.year}-${dueAt.month.toString().padLeft(2, '0')}-${dueAt.day.toString().padLeft(2, '0')}' : 'الحصة القادمة';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        header: (context) {
          return pw.Column(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.deepPurple800, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              centerName.fixArabic,
                              style: boldStyle.copyWith(fontSize: 13, color: PdfColors.deepPurple900),
                            ),
                            pw.Text(
                              'المادة: $subjectName • الأستاذ: $teacherName'.fixArabic,
                              style: regularStyle.copyWith(fontSize: 9, color: PdfColors.grey800),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.deepPurple800,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                homeworkTitle.fixArabic,
                                style: boldStyle.copyWith(fontSize: 11, color: PdfColors.white),
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              (groupName != null ? 'المجموعة: $groupName' : 'العام الدراسي: $academicYear').fixArabic,
                              style: regularStyle.copyWith(fontSize: 8, color: PdfColors.grey700),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'الدرجة الكلية: ${maxScore.toStringAsFixed(0)} درجة'.fixArabic,
                              style: boldStyle.copyWith(fontSize: 9, color: PdfColors.deepPurple900),
                            ),
                            pw.Text(
                              'تسليم حتى: $formattedDue'.fixArabic,
                              style: regularStyle.copyWith(fontSize: 8, color: PdfColors.grey700),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    // Student fillable info
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'اسم الطالب: .............................................................'.fixArabic,
                            style: regularStyle.copyWith(fontSize: 8.5, color: PdfColors.black),
                          ),
                          pw.Text(
                            'كود الطالب: ...................'.fixArabic,
                            style: regularStyle.copyWith(fontSize: 8.5, color: PdfColors.black),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey400),
                              color: PdfColors.white,
                            ),
                            child: pw.Text(
                              'الدرجة: [     / ${maxScore.toStringAsFixed(0)} ]'.fixArabic,
                              style: boldStyle.copyWith(fontSize: 8.5, color: PdfColors.deepPurple900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Brivio Educational Platform • شيت واجب منزلي'.fixArabic,
                style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey600),
              ),
              pw.Text(
                'صفحة ${context.pageNumber} من ${context.pagesCount}'.fixArabic,
                style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          );
        },
        build: (context) {
          return [
            ...questions.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final q = entry.value;
              final prompt = q['prompt']?.toString() ?? '';
              final points = (q['points'] as num? ?? 1.0).toDouble();
              final type = q['type']?.toString() ?? 'multiple_choice';
              final options = (q['options'] as List<dynamic>?) ?? [];

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 14),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.deepPurple800,
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                          child: pw.Text(
                            'س $idx'.fixArabic,
                            style: boldStyle.copyWith(color: PdfColors.white, fontSize: 8),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Text(
                            prompt.fixArabic,
                            style: boldStyle.copyWith(fontSize: 9.5, color: PdfColors.black),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          '(${points.toStringAsFixed(0)} درجات)'.fixArabic,
                          style: regularStyle.copyWith(fontSize: 8, color: PdfColors.deepPurple800),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    if (type == 'multiple_choice' || type == 'mcq') ...[
                      pw.Column(
                        children: options.asMap().entries.map((optEntry) {
                          final optIdx = optEntry.key;
                          final optText = optEntry.value is Map
                              ? (optEntry.value['text']?.toString() ?? '')
                              : optEntry.value.toString();
                          final letters = ['أ', 'ب', 'ج', 'د', 'هـ'];
                          final letter = optIdx < letters.length ? letters[optIdx] : '${optIdx + 1}';

                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 4),
                            child: pw.Row(
                              children: [
                                pw.Container(
                                  width: 14,
                                  height: 14,
                                  decoration: pw.BoxDecoration(
                                    shape: pw.BoxShape.circle,
                                    border: pw.Border.all(color: PdfColors.grey500),
                                  ),
                                  child: pw.Center(
                                    child: pw.Text(
                                      letter.fixArabic,
                                      style: boldStyle.copyWith(fontSize: 7),
                                    ),
                                  ),
                                ),
                                pw.SizedBox(width: 6),
                                pw.Expanded(
                                  child: pw.Text(
                                    optText.fixArabic,
                                    style: regularStyle.copyWith(fontSize: 8.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ] else if (type == 'true_false') ...[
                      pw.Row(
                        children: [
                          pw.SizedBox(width: 20),
                          pw.Text('[      ]  صواب (True)'.fixArabic, style: regularStyle.copyWith(fontSize: 8.5)),
                          pw.SizedBox(width: 40),
                          pw.Text('[      ]  خطأ (False)'.fixArabic, style: regularStyle.copyWith(fontSize: 8.5)),
                        ],
                      ),
                    ] else ...[
                      pw.Container(
                        height: 45,
                        margin: const pw.EdgeInsets.only(top: 4),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColors.grey400, style: pw.BorderStyle.dashed),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    if (printDirectly) {
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } else {
      await _saveAndSharePdf(pdf, 'Printable_Homework_${homeworkTitle.replaceAll(' ', '_')}.pdf');
    }
  }

  /// Generates a Parent Financial Ledger PDF (كشف حساب مالي رسمي للطالب لولي الأمر)
  Future<void> generateParentFinancialLedgerPdf({
    required String centerName,
    required String studentName,
    required String studentCode,
    required String parentName,
    required String parentPhone,
    required String groupName,
    required double totalPaid,
    required double totalRemaining,
    required List<Map<String, dynamic>> records,
    String academicYear = '2025 / 2026',
    bool printDirectly = false,
  }) async {
    final pdf = await createDocument();
    final boldFont = await getBoldFont();
    final regularFont = await getRegularFont();

    final boldStyle = pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold);
    final regularStyle = pw.TextStyle(font: regularFont);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        header: (context) {
          return pw.Column(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal900,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '$centerName • كشف الحساب المالي لولي الأمر'.fixArabic,
                          style: boldStyle.copyWith(color: PdfColors.white, fontSize: 13),
                        ),
                        pw.Text(
                          'الطالب: $studentName ($studentCode) • المجموعة: $groupName'.fixArabic,
                          style: regularStyle.copyWith(color: PdfColors.amberAccent, fontSize: 8),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'كشف رسمي معتمد'.fixArabic,
                          style: boldStyle.copyWith(color: PdfColors.white, fontSize: 10),
                        ),
                        pw.Text(
                          'العام الدراسي: $academicYear'.fixArabic,
                          style: regularStyle.copyWith(color: PdfColors.grey300, fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              // Metrics summary
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildMetricBox(
                      title: 'إجمالي المسدد نقداً',
                      value: '${totalPaid.toStringAsFixed(1)} ج.م',
                      color: PdfColors.green800,
                      bgColor: PdfColors.green50,
                      boldStyle: boldStyle,
                      regularStyle: regularStyle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _buildMetricBox(
                      title: 'المتأخرات / المستحق',
                      value: '${totalRemaining.toStringAsFixed(1)} ج.م',
                      color: totalRemaining > 0 ? PdfColors.red800 : PdfColors.teal800,
                      bgColor: totalRemaining > 0 ? PdfColors.red50 : PdfColors.teal50,
                      boldStyle: boldStyle,
                      regularStyle: regularStyle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _buildMetricBox(
                      title: 'عدد العمليات والإيصالات',
                      value: '${records.length} إيصال',
                      color: PdfColors.blueGrey800,
                      bgColor: PdfColors.blueGrey50,
                      boldStyle: boldStyle,
                      regularStyle: regularStyle,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Brivio Educational Platform • كشف حساب مالي معتمد'.fixArabic,
                style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey600),
              ),
              pw.Text(
                'صفحة ${context.pageNumber} من ${context.pagesCount}'.fixArabic,
                style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          );
        },
        build: (context) {
          return [
            pw.TableHelper.fromTextArray(
              headers: ArabicPdfHelper.fixHeaders(['رقم الإيصال', 'تاريخ السداد', 'البيان والتفاصيل', 'المبلغ المدفوع', 'المستلم كاش', 'الحالة']),
              data: ArabicPdfHelper.fixData(records.map((r) {
                return [
                  r['receipt_number']?.toString() ?? '-',
                  r['date']?.toString() ?? '-',
                  r['description']?.toString() ?? 'سداد حصة / شهر',
                  '${(r['amount'] as num?)?.toStringAsFixed(1) ?? '0.0'} ج.م',
                  r['collector_name']?.toString() ?? 'الاستقبال',
                  'مدفوع كاش ✔️',
                ];
              }).toList()),
              headerStyle: boldStyle.copyWith(color: PdfColors.white, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
              cellStyle: regularStyle.copyWith(fontSize: 7.5),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
              ),
            ),
            pw.SizedBox(height: 24),
            // Signatures block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text('توقيع مسؤول الخزينة'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                    pw.SizedBox(height: 25),
                    pw.Container(width: 130, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 2),
                    pw.Text('حسابات ومراجعة الخزينة'.fixArabic, style: regularStyle.copyWith(fontSize: 7)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('ختم السنتر المعتمد'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                    pw.SizedBox(height: 25),
                    pw.Container(width: 130, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 2),
                    pw.Text(centerName.fixArabic, style: regularStyle.copyWith(fontSize: 7)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    if (printDirectly) {
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } else {
      await _saveAndSharePdf(pdf, 'Parent_Financial_Ledger_$studentCode.pdf');
    }
  }

  /// Generates a Monthly Performance Report Card PDF (بطاقة التقرير الشهري الشامل لمستوى الطالب لولي الأمر)
  Future<void> generateMonthlyReportCardPdf({
    required String centerName,
    required String monthName,
    required String studentName,
    required String studentCode,
    required String groupName,
    required String teacherName,
    required double attendanceRate,
    required int attendedSessions,
    required int totalSessions,
    required double examAverage,
    required double homeworkAverage,
    required String conductEvaluation,
    String? teacherNotes,
    bool printDirectly = false,
  }) async {
    final pdf = await createDocument();
    final boldFont = await getBoldFont();
    final regularFont = await getRegularFont();

    final boldStyle = pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold);
    final regularStyle = pw.TextStyle(font: regularFont);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey900,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '$centerName • التقرير الشهري لمستوى الطالب'.fixArabic,
                          style: boldStyle.copyWith(color: PdfColors.white, fontSize: 15),
                        ),
                        pw.Text(
                          'تقرير شهر: $monthName • الأستاذ: $teacherName'.fixArabic,
                          style: regularStyle.copyWith(color: PdfColors.amberAccent, fontSize: 10),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.amber700,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'كارت المتابعة الشهري'.fixArabic,
                        style: boldStyle.copyWith(color: PdfColors.white, fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Student Info Banner
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الطالب: $studentName'.fixArabic, style: boldStyle.copyWith(fontSize: 10)),
                    pw.Text('الكود: $studentCode'.fixArabic, style: boldStyle.copyWith(fontSize: 10)),
                    pw.Text('المجموعة: $groupName'.fixArabic, style: boldStyle.copyWith(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Academic & Attendance Metrics
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildMetricBox(
                      title: 'نسبة الحضور والالتزام',
                      value: '${attendanceRate.toStringAsFixed(0)}% ($attendedSessions من $totalSessions حصص)',
                      color: attendanceRate >= 85 ? PdfColors.green800 : PdfColors.red800,
                      bgColor: attendanceRate >= 85 ? PdfColors.green50 : PdfColors.red50,
                      boldStyle: boldStyle,
                      regularStyle: regularStyle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _buildMetricBox(
                      title: 'متوسط درجات الامتحانات',
                      value: '${examAverage.toStringAsFixed(1)} / 20.0',
                      color: PdfColors.purple800,
                      bgColor: PdfColors.purple50,
                      boldStyle: boldStyle,
                      regularStyle: regularStyle,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _buildMetricBox(
                      title: 'تقييم الواجبات والأنشطة',
                      value: '${homeworkAverage.toStringAsFixed(1)} / 20.0',
                      color: PdfColors.indigo800,
                      bgColor: PdfColors.indigo50,
                      boldStyle: boldStyle,
                      regularStyle: regularStyle,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Conduct and Teacher Notes
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.blueGrey200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text('التقييم السلوكي والتفاعل داخل الحصة: '.fixArabic, style: boldStyle.copyWith(fontSize: 10)),
                        pw.Text(conductEvaluation.fixArabic, style: boldStyle.copyWith(fontSize: 10, color: PdfColors.green900)),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text('ملاحظات وتوجيهات الأستاذ لولي الأمر:'.fixArabic, style: boldStyle.copyWith(fontSize: 9)),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey50,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        (teacherNotes ?? 'الطالب يظهر التزاماً متميزاً ومتابعة مستمرة. نوصي باستمرار حل الواجبات والمراجعة الأسبوعية.').fixArabic,
                        style: regularStyle.copyWith(fontSize: 8.5),
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('توقيع الأستاذ'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                      pw.SizedBox(height: 25),
                      pw.Container(width: 120, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text(teacherName.fixArabic, style: regularStyle.copyWith(fontSize: 7)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('توقيع الإدارة والتنسيق'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                      pw.SizedBox(height: 25),
                      pw.Container(width: 120, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text('إدارة شؤون الطلاب'.fixArabic, style: regularStyle.copyWith(fontSize: 7)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('ختم السنتر الرسمي'.fixArabic, style: boldStyle.copyWith(fontSize: 8)),
                      pw.SizedBox(height: 25),
                      pw.Container(width: 120, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text(centerName.fixArabic, style: regularStyle.copyWith(fontSize: 7)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    if (printDirectly) {
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } else {
      await _saveAndSharePdf(pdf, 'Monthly_Report_${studentCode}_$monthName.pdf');
    }
  }

  /// Generates a Bookstore Receipt PDF (إيصال بيع مذكرات وكتب نقداً من المخزن)
  Future<void> generateBookstoreReceiptPdf({
    required String centerName,
    required String receiptNumber,
    required String studentName,
    required String studentCode,
    required String cashierName,
    required DateTime saleDate,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    bool printDirectly = false,
  }) async {
    final pdf = await createDocument();
    final boldFont = await getBoldFont();
    final regularFont = await getRegularFont();

    final boldStyle = pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold);
    final regularStyle = pw.TextStyle(font: regularFont);

    final dateStr = '${saleDate.year}-${saleDate.month.toString().padLeft(2, '0')}-${saleDate.day.toString().padLeft(2, '0')} ${saleDate.hour.toString().padLeft(2, '0')}:${saleDate.minute.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, 150 * PdfPageFormat.mm, marginAll: 5 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  centerName.fixArabic,
                  style: boldStyle.copyWith(fontSize: 12),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'إيصال مبيعات مذكرات وكتب (كاش)'.fixArabic,
                  style: regularStyle.copyWith(fontSize: 8, color: PdfColors.grey700),
                ),
              ),
              pw.Divider(thickness: 0.8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('الإيصال: #$receiptNumber'.fixArabic, style: boldStyle.copyWith(fontSize: 7.5)),
                  pw.Text(dateStr.fixArabic, style: regularStyle.copyWith(fontSize: 6.5)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text('الطالب: $studentName ($studentCode)'.fixArabic, style: boldStyle.copyWith(fontSize: 7)),
              pw.Text('أمين المخزن: $cashierName'.fixArabic, style: regularStyle.copyWith(fontSize: 6.5)),
              pw.Divider(thickness: 0.5),

              // Items table
              ...items.map((it) {
                final title = it['title']?.toString() ?? 'مذكرة دراسية';
                final qty = it['quantity'] as int? ?? 1;
                final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                final subtotal = price * qty;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '$title (×$qty)'.fixArabic,
                          style: regularStyle.copyWith(fontSize: 7),
                        ),
                      ),
                      pw.Text('${subtotal.toStringAsFixed(1)} ج.م'.fixArabic, style: boldStyle.copyWith(fontSize: 7)),
                    ],
                  ),
                );
              }),

              pw.Divider(thickness: 0.8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('الإجمالي المدفوع نقداً:'.fixArabic, style: boldStyle.copyWith(fontSize: 8.5)),
                  pw.Text('${totalAmount.toStringAsFixed(1)} ج.م'.fixArabic, style: boldStyle.copyWith(fontSize: 9, color: PdfColors.green900)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'الدفع كاش فقط • لا تُرد المذكرات بعد استلامها'.fixArabic,
                  style: regularStyle.copyWith(fontSize: 5.5, color: PdfColors.grey700),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'شكراً لتعاملكم مع سنتر $centerName 🌟'.fixArabic,
                  style: boldStyle.copyWith(fontSize: 6),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (printDirectly) {
      await ThermalPrinterService().printDocument(
        document: pdf,
        documentName: 'Bookstore_Receipt_$receiptNumber',
      );
    } else {
      await _saveAndSharePdf(pdf, 'Bookstore_Receipt_$receiptNumber.pdf');
    }
  }

  /// Generates a printable A4 sheet of Seat Desk Labels (بطاقات أرقام مقاعد وديسكات الطلاب بالقاعات)
  Future<void> generateSeatDeskLabelsPdf({
    required String centerName,
    required String hallName,
    required String groupName,
    String? teacherName,
    required List<Map<String, dynamic>> seatAllocations,
    String sessionDateStr = '',
    bool printDirectly = false,
  }) async {
    final pdf = await createDocument();
    final boldFont = await getBoldFont();
    final regularFont = await getRegularFont();

    final boldStyle = pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold);
    final regularStyle = pw.TextStyle(font: regularFont);

    // Chunk into pages of 8 labels per A4 page (4 rows x 2 columns)
    const labelsPerPage = 8;
    for (int i = 0; i < seatAllocations.length; i += labelsPerPage) {
      final pageItems = seatAllocations.sublist(
        i,
        (i + labelsPerPage > seatAllocations.length) ? seatAllocations.length : i + labelsPerPage,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Sheet header banner
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: PdfColors.blueGrey800,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'كروت تسكين مقاعد الطلاب (Desk Labels) • قص والصق على ديسك الطالب ✂️'.fixArabic,
                        style: boldStyle.copyWith(color: PdfColors.white, fontSize: 8.5),
                      ),
                      pw.Text(
                        '$centerName • $hallName • $groupName'.fixArabic,
                        style: regularStyle.copyWith(color: PdfColors.amberAccent, fontSize: 8),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),

                // 2-Column Grid
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: 2,
                    childAspectRatio: 1.85,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: pageItems.map((item) {
                      final seatNumber = item['seatNumber']?.toString() ?? '1';
                      final studentName = item['studentName']?.toString() ?? 'طالب';
                      final studentCode = item['studentCode']?.toString() ?? 'STU-000';
                      final notes = item['notes']?.toString() ?? '';

                      return pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey500, width: 1, style: pw.BorderStyle.dashed),
                          borderRadius: pw.BorderRadius.circular(6),
                          color: PdfColors.white,
                        ),
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Row(
                          children: [
                            // Big Seat Number Badge & QR
                            pw.Container(
                              width: 60,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.indigo900,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              child: pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text(
                                    'مقعد'.fixArabic,
                                    style: regularStyle.copyWith(color: PdfColors.amberAccent, fontSize: 7),
                                  ),
                                  pw.Text(
                                    '#$seatNumber',
                                    style: boldStyle.copyWith(color: PdfColors.white, fontSize: 18),
                                  ),
                                  pw.SizedBox(height: 4),
                                  pw.BarcodeWidget(
                                    barcode: pw.Barcode.qrCode(),
                                    data: studentCode,
                                    width: 38,
                                    height: 38,
                                    color: PdfColors.white,
                                  ),
                                ],
                              ),
                            ),
                            pw.SizedBox(width: 8),

                            // Student & Hall Details
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text(
                                    studentName.fixArabic,
                                    maxLines: 1,
                                    style: boldStyle.copyWith(fontSize: 10, color: PdfColors.black),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    'كود: $studentCode'.fixArabic,
                                    style: boldStyle.copyWith(fontSize: 8, color: PdfColors.indigo800),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    '$hallName • $groupName'.fixArabic,
                                    maxLines: 1,
                                    style: regularStyle.copyWith(fontSize: 6.5, color: PdfColors.grey700),
                                  ),
                                  if (teacherName != null && teacherName.isNotEmpty) ...[
                                    pw.Text(
                                      'المدرس: $teacherName'.fixArabic,
                                      maxLines: 1,
                                      style: regularStyle.copyWith(fontSize: 6.5, color: PdfColors.grey700),
                                    ),
                                  ],
                                  if (notes.isNotEmpty) ...[
                                    pw.SizedBox(height: 2),
                                    pw.Text(
                                      notes.fixArabic,
                                      maxLines: 1,
                                      style: regularStyle.copyWith(fontSize: 6, color: PdfColors.deepOrange800),
                                    ),
                                  ],
                                  pw.Spacer(),
                                  pw.Text(
                                    'يرجى الالتزام برقم المقعد المحدد 📌'.fixArabic,
                                    style: regularStyle.copyWith(fontSize: 6, color: PdfColors.grey600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    if (printDirectly) {
      await ThermalPrinterService().printDocument(
        document: pdf,
        documentName: 'Seat_Desk_Labels_${hallName.replaceAll(' ', '_')}',
      );
    } else {
      await _saveAndSharePdf(pdf, 'Seat_Desk_Labels_${hallName.replaceAll(' ', '_')}.pdf');
    }
  }

  /// Generates a Printable Exam Sheet PDF (نسخة ورقية A4 جاهزة للتصوير والطباعة وتوزيعها على الطلاب بالقاعة)
  Future<void> generatePrintableExamSheetPdf({
    required String centerName,
    required String teacherName,
    required String examTitle,
    required String groupName,
    required int durationMinutes,
    required int totalMarks,
    required List<Map<String, dynamic>> questions,
    bool includeAnswerKey = false,
    bool printDirectly = false,
  }) async {
    final pdf = await createDocument();
    final boldFont = await getBoldFont();
    final regularFont = await getRegularFont();

    final boldStyle = pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold);
    final regularStyle = pw.TextStyle(font: regularFont);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        header: (context) {
          return pw.Column(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.blueGrey800, width: 1.5),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(centerName.fixArabic, style: boldStyle.copyWith(fontSize: 14, color: PdfColors.blueGrey900)),
                            pw.Text('المدرس: $teacherName'.fixArabic, style: regularStyle.copyWith(fontSize: 11, color: PdfColors.grey800)),
                          ],
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blueGrey900,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Text(
                            examTitle.fixArabic,
                            style: boldStyle.copyWith(fontSize: 12, color: PdfColors.white),
                          ),
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('المجموعة: $groupName'.fixArabic, style: boldStyle.copyWith(fontSize: 11)),
                            pw.Text('الزمن: $durationMinutes دقيقة | الدرجة: $totalMarks'.fixArabic, style: regularStyle.copyWith(fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                    pw.Divider(thickness: 0.8, color: PdfColors.grey400, height: 12),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text('اسم الطالب: ................................................................'.fixArabic, style: regularStyle.copyWith(fontSize: 10)),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text('رقم الجلوس / الكود: ....................'.fixArabic, style: regularStyle.copyWith(fontSize: 10)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
            ],
          );
        },
        footer: (context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('مع أطيب تمنياتنا بالتفوق والنجاح • $teacherName'.fixArabic, style: regularStyle.copyWith(fontSize: 8, color: PdfColors.grey600)),
                  pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}'.fixArabic, style: regularStyle.copyWith(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
        build: (context) {
          final List<pw.Widget> items = [];

          for (int i = 0; i < questions.length; i++) {
            final q = questions[i];
            final prompt = q['prompt']?.toString() ?? 'سؤال رقم ${i + 1}';
            final points = q['points'] ?? 1;
            final options = (q['options'] as List<dynamic>?) ?? [];
            final isMcq = options.isNotEmpty;

            items.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Question header
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            '(${i + 1}) $prompt'.fixArabic,
                            style: boldStyle.copyWith(fontSize: 11, color: PdfColors.black),
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text('[$points درجة]'.fixArabic, style: regularStyle.copyWith(fontSize: 9)),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),

                    if (isMcq) ...[
                      // MCQ Options in 2 cols
                      pw.Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: options.asMap().entries.map((entry) {
                          final optIndex = entry.key;
                          final opt = entry.value is Map ? entry.value : {'text': entry.value.toString()};
                          final optText = opt['text']?.toString() ?? opt['title']?.toString() ?? '';
                          final isCorrect = opt['is_correct'] == true || opt['isCorrect'] == true;
                          final letter = String.fromCharCode(0x0623 + optIndex); // أ, ب, ج, د

                          return pw.Container(
                            width: 220,
                            child: pw.Row(
                              children: [
                                pw.Container(
                                  width: 14,
                                  height: 14,
                                  decoration: pw.BoxDecoration(
                                    shape: pw.BoxShape.circle,
                                    border: pw.Border.all(color: (includeAnswerKey && isCorrect) ? PdfColors.green700 : PdfColors.grey700),
                                    color: (includeAnswerKey && isCorrect) ? PdfColors.green100 : PdfColors.white,
                                  ),
                                  child: pw.Center(
                                    child: pw.Text(
                                      letter.fixArabic,
                                      style: boldStyle.copyWith(fontSize: 8, color: (includeAnswerKey && isCorrect) ? PdfColors.green800 : PdfColors.black),
                                    ),
                                  ),
                                ),
                                pw.SizedBox(width: 6),
                                pw.Expanded(
                                  child: pw.Text(
                                    optText.fixArabic,
                                    style: (includeAnswerKey && isCorrect)
                                        ? boldStyle.copyWith(fontSize: 9.5, color: PdfColors.green900)
                                        : regularStyle.copyWith(fontSize: 9.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      // Essay lines for student answer
                      pw.SizedBox(height: 4),
                      pw.Container(
                        height: 44,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColors.grey300, style: pw.BorderStyle.dashed),
                          ),
                        ),
                        child: pw.Align(
                          alignment: pw.Alignment.topRight,
                          child: pw.Text('الإجابة: ....................................................................................................................................................................'.fixArabic, style: regularStyle.copyWith(color: PdfColors.grey400, fontSize: 8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          if (includeAnswerKey) {
            items.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 16),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.green400),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('📌 نموذج الإجابة الرسمي الخاص بالمدرس والمساعدين:'.fixArabic, style: boldStyle.copyWith(fontSize: 11, color: PdfColors.green900)),
                    pw.SizedBox(height: 6),
                    pw.Text('هذه النسخة مخصصة لطاقم التصحيح والمساعدين (TAs) لمراجعة أوراق إجابات الطلاب بدقة.'.fixArabic, style: regularStyle.copyWith(fontSize: 9)),
                  ],
                ),
              ),
            );
          }

          return items;
        },
      ),
    );

    final cleanFileName = 'Exam_${examTitle.replaceAll(' ', '_')}_${groupName.replaceAll(' ', '_')}.pdf';
    if (printDirectly) {
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } else {
      await _saveAndSharePdf(pdf, cleanFileName);
    }
  }

  /// Generates Printable Barcode Stickers for Booklets & Books (ملصقات باركود حرارية للملازم والكتب لطباعتها ولصقها)
  Future<void> generateBookletBarcodeLabelsPdf({
    required String centerName,
    required List<Map<String, dynamic>> items,
    int copiesPerItem = 1,
    bool printDirectly = false,
  }) async {
    final pdf = await createDocument();
    final boldFont = await getBoldFont();
    final regularFont = await getRegularFont();

    final boldStyle = pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold);
    final regularStyle = pw.TextStyle(font: regularFont);

    final expandedList = <Map<String, dynamic>>[];
    for (final it in items) {
      for (int c = 0; c < copiesPerItem; c++) {
        expandedList.add(it);
      }
    }

    // Grid of barcode labels formatted for thermal sticker rolls or A4 sticker sheets
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          return [
            pw.Wrap(
              spacing: 12,
              runSpacing: 12,
              children: expandedList.map((item) {
                final title = item['title']?.toString() ?? 'مذكرة دراسية';
                final teacher = item['teacher']?.toString() ?? 'معلم المادة';
                final price = item['price'] != null ? '${item['price']} ج.م' : '';
                final sku = item['sku']?.toString() ?? item['id']?.toString() ?? 'BK-1001';

                return pw.Container(
                  width: 175,
                  height: 105,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            centerName.fixArabic,
                            style: boldStyle.copyWith(fontSize: 7, color: PdfColors.blueGrey900),
                          ),
                          if (price.isNotEmpty)
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.black,
                                borderRadius: pw.BorderRadius.circular(2),
                              ),
                              child: pw.Text(
                                price.fixArabic,
                                style: boldStyle.copyWith(fontSize: 7.5, color: PdfColors.white),
                              ),
                            ),
                        ],
                      ),
                      pw.Text(
                        title.fixArabic,
                        style: boldStyle.copyWith(fontSize: 8.5),
                        textAlign: pw.TextAlign.center,
                        maxLines: 1,
                      ),
                      pw.Text(
                        teacher.fixArabic,
                        style: regularStyle.copyWith(fontSize: 7, color: PdfColors.grey800),
                        textAlign: pw.TextAlign.center,
                        maxLines: 1,
                      ),
                      pw.Container(
                        height: 34,
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.code128(),
                          data: sku,
                          drawText: true,
                          textStyle: regularStyle.copyWith(fontSize: 7),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ];
        },
      ),
    );

    if (printDirectly) {
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } else {
      await _saveAndSharePdf(pdf, 'Booklet_Barcode_Labels_${DateTime.now().millisecondsSinceEpoch}.pdf');
    }
  }

  /// Generates an Executive Security Audit & Compliance Log PDF.
  Future<void> generateSecurityAuditLogPdf({
    required List<Map<String, dynamic>> auditItems,
    String centerName = 'منظومة بريفيو التعليمية',
    String branchName = 'الفرع الرئيسي',
    String filterName = 'جميع العمليات',
    bool printDirectly = false,
  }) async {
    final pdf = await createDocument();
    final boldFont = await getBoldFont();
    final regularFont = await getRegularFont();
    final boldStyle = pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold);
    final regularStyle = pw.TextStyle(font: regularFont);

    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final totalCount = auditItems.length;
    final criticalCount = auditItems.where((i) {
      final risk = (i['riskLevel']?.toString().toLowerCase() ?? '');
      final action = (i['action']?.toString().toLowerCase() ?? '');
      return risk == 'critical' || risk == 'حرج 🚨' || action == 'delete' || action == 'حذف';
    }).length;
    final financialCount = auditItems.where((i) {
      final category = (i['category']?.toString().toLowerCase() ?? '');
      final table = (i['tableName']?.toString().toLowerCase() ?? i['table']?.toString().toLowerCase() ?? '');
      return category.contains('finan') || table.contains('invoice') || table.contains('payment') || table.contains('sale');
    }).length;
    final gradeCount = auditItems.where((i) {
      final category = (i['category']?.toString().toLowerCase() ?? '');
      final table = (i['tableName']?.toString().toLowerCase() ?? i['table']?.toString().toLowerCase() ?? '');
      return category.contains('grade') || table.contains('exam') || table.contains('score');
    }).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey900,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '🛡️ تقرير التدقيق والرقابة الأمنية والمعاملات الحساسة'.fixArabic,
                        style: boldStyle.copyWith(color: PdfColors.white, fontSize: 16),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '$centerName • $branchName | تصنيف العرض: $filterName'.fixArabic,
                        style: regularStyle.copyWith(color: PdfColors.grey300, fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'تاريخ التصدير: $dateStr'.fixArabic,
                        style: regularStyle.copyWith(color: PdfColors.white, fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'وثيقة إدارية مشفرة وسرية للغاية 🔒'.fixArabic,
                        style: boldStyle.copyWith(color: PdfColors.amber300, fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // KPI Summary Cards Row
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('إجمالي العمليات الموثقة'.fixArabic, style: regularStyle.copyWith(fontSize: 9)),
                        pw.SizedBox(height: 2),
                        pw.Text('$totalCount', style: boldStyle.copyWith(fontSize: 14, color: PdfColors.blueGrey800)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.red50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.red200),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('عمليات حرجة / حذف 🚨'.fixArabic, style: regularStyle.copyWith(fontSize: 9, color: PdfColors.red900)),
                        pw.SizedBox(height: 2),
                        pw.Text('$criticalCount', style: boldStyle.copyWith(fontSize: 14, color: PdfColors.red700)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.green200),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('حركات مالية واسترداد 💸'.fixArabic, style: regularStyle.copyWith(fontSize: 9, color: PdfColors.green900)),
                        pw.SizedBox(height: 2),
                        pw.Text('$financialCount', style: boldStyle.copyWith(fontSize: 14, color: PdfColors.green700)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.purple50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.purple200),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('تعديلات درجات وامتحانات 📝'.fixArabic, style: regularStyle.copyWith(fontSize: 9, color: PdfColors.purple900)),
                        pw.SizedBox(height: 2),
                        pw.Text('$gradeCount', style: boldStyle.copyWith(fontSize: 14, color: PdfColors.purple700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // Audit Table
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ArabicPdfHelper.fixHeaders(['التفاصيل والبيانات', 'مستوى الخطورة', 'المنفّذ (المستخدم)', 'الكيان / الجدول', 'نوع العملية', 'التاريخ والوقت']),
              headerStyle: boldStyle.copyWith(color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              headerAlignment: pw.Alignment.center,
              cellAlignment: pw.Alignment.centerRight,
              cellStyle: regularStyle.copyWith(fontSize: 8),
              data: ArabicPdfHelper.fixData(auditItems.map((item) {
                final date = item['createdAt']?.toString() ?? item['createdLabel']?.toString() ?? '-';
                final action = item['actionLabel']?.toString() ?? item['action']?.toString() ?? '-';
                final table = item['tableName']?.toString() ?? item['table']?.toString() ?? '-';
                final actor = item['actorUserId']?.toString() ?? item['actor']?.toString() ?? 'النظام التلقائي';
                final risk = item['riskLabel']?.toString() ?? item['riskLevel']?.toString() ?? 'عادي';
                final desc = item['humanDescription']?.toString() ?? item['recordId']?.toString() ?? '-';

                return [
                  desc,
                  risk,
                  actor,
                  table,
                  action,
                  date,
                ];
              }).toList()),
              columnWidths: {
                0: const pw.FlexColumnWidth(3.0),
                1: const pw.FlexColumnWidth(1.0),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1.0),
                5: const pw.FlexColumnWidth(1.5),
              },
            ),
            pw.SizedBox(height: 16),

            // Footer Digital Seal
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Brivio Security Shield • ISO/IEC 27001 Audit Compliance Trail',
                  style: regularStyle.copyWith(color: PdfColors.grey600, fontSize: 8),
                ),
                pw.Text(
                  'ختم الاعتماد الرقمي للمنظومة: #BRV-SEC-${now.millisecondsSinceEpoch}'.fixArabic,
                  style: boldStyle.copyWith(color: PdfColors.grey700, fontSize: 8),
                ),
              ],
            ),
          ];
        },
      ),
    );

    if (printDirectly) {
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } else {
      await _saveAndSharePdf(pdf, 'Security_Audit_Log_${now.millisecondsSinceEpoch}.pdf');
    }
  }
}


