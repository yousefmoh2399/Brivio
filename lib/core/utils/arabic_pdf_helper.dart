import 'package:bidi/bidi.dart' as bidi;
import 'package:arabic_reshaper/arabic_reshaper.dart';

/// Helper utility to reshape and order Arabic and bidirectional text
/// so that it renders with fully connected glyphs and correct right-to-left
/// sequence in PDF documents (ReportGeneratorService and ThermalPrinterService).
class ArabicPdfHelper {
  static final RegExp _arabicRegex = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );

  static final ArabicReshaper _fallbackReshaper = ArabicReshaper();

  /// Fixes disconnected, reversed, or scrambled Arabic text for PDF rendering.
  /// If the text contains no Arabic characters, it is returned untouched.
  /// If Arabic is present, Unicode BiDi algorithm is applied with character shaping.
  static String fix(String? input) {
    if (input == null || input.isEmpty) return input ?? '';
    if (!_arabicRegex.hasMatch(input)) return input;

    try {
      final buffer = StringBuffer();
      final paragraphs = bidi.BidiString.fromLogical(input).paragraphs;
      for (var i = 0; i < paragraphs.length; i++) {
        final p = paragraphs[i];
        final endsWithNewLine = p.separator == 10;
        final endIndex = p.bidiText.length - (endsWithNewLine ? 1 : 0);
        buffer.write(String.fromCharCodes(p.bidiText, 0, endIndex));
        if (endsWithNewLine || i < paragraphs.length - 1) {
          buffer.writeln();
        }
      }
      return buffer.toString();
    } catch (_) {
      try {
        return _fallbackReshaper.reshape(input);
      } catch (_) {
        return input;
      }
    }
  }

  /// Convenience alias for [fix]
  static String format(String? input) => fix(input);

  /// Fixes a list of table headers
  static List<String> fixHeaders(List<String> headers) {
    return headers.map(fix).toList();
  }

  /// Fixes a 2D table data matrix (all string cells)
  static List<List<dynamic>> fixData(List<List<dynamic>> rows) {
    return rows.map((row) {
      return row.map((cell) {
        if (cell is String) {
          return fix(cell);
        }
        return cell;
      }).toList();
    }).toList();
  }
}

/// Extension on [String] for effortless Arabic PDF text conversion
extension ArabicPdfStringExtension on String {
  String get fixArabic => ArabicPdfHelper.fix(this);
}

/// Extension on nullable [String] for effortless Arabic PDF text conversion
extension ArabicPdfNullableStringExtension on String? {
  String get fixArabic => ArabicPdfHelper.fix(this);
}
