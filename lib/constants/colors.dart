import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rekeep/theme_provider.dart';

class AppColors {
  // primary는 context에서 가져오는 방식으로 변경
  static Color primary(BuildContext context) =>
      context.watch<ThemeProvider>().primaryColor;

  static const primaryColor = Color(0xFF4F7CFF);
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
      : const Color(0xFFF5F5F5);

  static Color divider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF252932)
      : const Color(0xFFF5F5F5);
}
