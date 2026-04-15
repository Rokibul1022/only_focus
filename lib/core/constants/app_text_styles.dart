import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  // UI font - Inter for all UI elements
  static TextStyle get uiH1 => GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF0F1117),
      );
  
  static TextStyle get uiH2 => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF0F1117),
      );
  
  static TextStyle get uiH3 => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF0F1117),
      );
  
  static TextStyle get uiBody => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: const Color(0xFF1F2937),
      );
  
  static TextStyle get uiButton => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF0F1117),
      );
  
  static TextStyle get uiCaption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF4B5563),
      );
  
  // Reading fonts - default Merriweather
  static TextStyle readerBody({
    String fontFamily = 'Merriweather',
    double fontSize = 17,
    double lineHeight = 1.7,
  }) {
    switch (fontFamily) {
      case 'Lora':
        return GoogleFonts.lora(
          fontSize: fontSize,
          height: lineHeight,
        );
      case 'Inter':
        return GoogleFonts.inter(
          fontSize: fontSize,
          height: lineHeight,
        );
      case 'Merriweather':
      default:
        return GoogleFonts.merriweather(
          fontSize: fontSize,
          height: lineHeight,
        );
    }
  }
  
  static TextStyle get readerTitle => GoogleFonts.merriweather(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.3,
      );
}
