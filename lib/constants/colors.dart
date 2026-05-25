import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF4F7CFF);
  static const primaryLight = Color(0xFFF5F7FF);
  static const secondary = Color(0xFF777C89);
  static const fieldColor = Color(0xFFF2F3F7);
  static const pointColor = Color(0xFFFF6B6B);

  static const borderColor = Color.fromRGBO(119, 124, 137, 0.1);
  static const dividerColor = Color(0xFFF5F5F5);

  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF16171E)
      : Colors.white;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black;

  static Color cardBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF252932)
      : const Color(0xFFF5F5F5); // fieldColor

  static Color divider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF252932)
      : const Color(0xFFF5F5F5); // dividerColor
}
