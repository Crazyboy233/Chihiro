import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ========== 通用色（亮暗通用） ==========
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  static const Color secondary = Color(0xFF10B981);
  static const Color secondaryLight = Color(0xFF34D399);

  static const Color expense = Color(0xFFF97316);
  static const Color income = Color(0xFF10B981);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ========== 亮色模式 ==========
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // ========== 暗色模式 ==========
  static const Color darkBackground = Color(0xFF0F0F1A);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF222240);

  static const Color darkTextPrimary = Color(0xFFE8E8EE);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkTextTertiary = Color(0xFF6B7280);

  static const Color darkBorder = Color(0xFF2D2D45);
  static const Color darkDivider = Color(0xFF252540);

  // ========== 根据亮度获取颜色 ==========
  static Color bg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBackground : background;

  static Color sf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : surface;

  static Color cd(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCard : card;

  static Color tp(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : textPrimary;

  static Color ts(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : textSecondary;

  static Color tt(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextTertiary : textTertiary;

  static Color bd(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorder : border;

  static Color dv(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkDivider : divider;
}
