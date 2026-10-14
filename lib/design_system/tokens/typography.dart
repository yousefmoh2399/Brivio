import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium Arabic & Global Typography system powered by GoogleFonts.cairo.
/// Delivers native, ultra-crisp legibility for Egyptian tutoring centers.
class AppTypography {
  AppTypography._();

  // ─── Hero / Display ───────────────────────────────────────────────────────

  /// Massive hero number or greeting — 48px bold
  static TextStyle hero(Color color) => GoogleFonts.cairo(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    color: color,
    height: 1.15,
    letterSpacing: -1.0,
  );

  /// Display Large — page titles, splash text — 32px
  static TextStyle displayLarge(Color color) => GoogleFonts.cairo(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.2,
    letterSpacing: -0.5,
  );

  /// Display Medium — section hero cards — 26px
  static TextStyle displayMedium(Color color) => GoogleFonts.cairo(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.25,
    letterSpacing: -0.3,
  );

  /// Display Small — prominent card headings — 22px
  static TextStyle displaySmall(Color color) => GoogleFonts.cairo(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.3,
    letterSpacing: -0.2,
  );

  // ─── Title ────────────────────────────────────────────────────────────────

  /// Title Large — section headers — 20px semibold
  static TextStyle titleLarge(Color color) => GoogleFonts.cairo(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1.35,
  );

  /// Title Medium — card headers — 16px semibold
  static TextStyle titleMedium(Color color) => GoogleFonts.cairo(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1.35,
  );

  /// Title Small — labels, chips — 14px semibold
  static TextStyle titleSmall(Color color) => GoogleFonts.cairo(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1.35,
  );

  // ─── Body ────────────────────────────────────────────────────────────────

  /// Body Large — primary readable text — 16px regular
  static TextStyle bodyLarge(Color color) => GoogleFonts.cairo(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.5,
  );

  /// Body Medium — secondary text — 14px regular
  static TextStyle bodyMedium(Color color) => GoogleFonts.cairo(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.45,
  );

  /// Body Small — tertiary, descriptions — 12px regular
  static TextStyle bodySmall(Color color) => GoogleFonts.cairo(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.4,
  );

  // ─── Label ────────────────────────────────────────────────────────────────

  /// Label Large — button text, CTAs — 15px bold
  static TextStyle labelLarge(Color color) => GoogleFonts.cairo(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.3,
  );

  /// Label Medium — tags, pills — 13px medium
  static TextStyle labelMedium(Color color) => GoogleFonts.cairo(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1.3,
  );

  /// Label Small — badges, overlines — 11px medium
  static TextStyle labelSmall(Color color) => GoogleFonts.cairo(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1.3,
  );

  // ─── Caption ─────────────────────────────────────────────────────────────

  /// Caption — timestamps, hints — 12px regular
  static TextStyle caption(Color color) => GoogleFonts.cairo(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.35,
  );

  /// Caption Semibold — section overlines — 11px semibold
  static TextStyle overline(Color color) => GoogleFonts.cairo(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1.35,
  );

  // ─── Numeric / Mono ───────────────────────────────────────────────────────

  /// Big numeric display — scores, balances
  static TextStyle numericDisplay(Color color) => GoogleFonts.cairo(
    fontSize: 38,
    fontWeight: FontWeight.w800,
    color: color,
    height: 1.1,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Tabular number — for stats/tables
  static TextStyle numericMedium(Color color) => GoogleFonts.cairo(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.2,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
