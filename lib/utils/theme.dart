import 'package:flutter/material.dart';
import 'package:helplink/utils/app_theme.dart';

class HelpLinkTheme {
  static const Color error = AppTheme.errorRed;
  static const Color success = AppTheme.successGreen;
  static const Color textPrimary = AppTheme.textDark;
  static const Color textSecondary = AppTheme.textMuted;
  static const Color donorPrimary = AppTheme.donorPrimary;
  static const Color beneficiaryPrimary = AppTheme.beneficiaryPrimary;
  static const Color divider = Color(0xFFE2E8F0);
  static const Color beneficiaryGradientStart = AppTheme.beneficiaryGradientStart;
  static const Color beneficiaryGradientEnd = AppTheme.beneficiaryGradientEnd;

  static ThemeData get lightTheme => AppTheme.lightTheme;
}
