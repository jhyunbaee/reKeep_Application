import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system }

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.system;
  Color _primaryColor = const Color(0xFF4F7CFF);

  AppThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;

  // 선택 가능한 브랜드 컬러 목록
  static const List<Map<String, dynamic>> brandColors = [
    {'name': '블루', 'color': Color(0xFF4F7CFF)},
    {'name': '코랄', 'color': Color(0xFFFF6B6B)},
    {'name': '그린', 'color': Color(0xFF34C759)},
    {'name': '오렌지', 'color': Color(0xFFFF9500)},
    {'name': '퍼플', 'color': Color(0xFF9B59B6)},
    {'name': '블랙', 'color': Color(0xFF1C1C1E)},
    {'name': '민트', 'color': Color(0xFF00BFA5)},
    {'name': '핑크', 'color': Color(0xFFE91E8C)},
    {'name': '인디고', 'color': Color(0xFF3F51B5)},
    {'name': '옐로우', 'color': Color(0xFFFFC107)},
    {'name': '브라운', 'color': Color(0xFF795548)},
    {'name': '딥레드', 'color': Color(0xFFC0392B)},
  ];

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_theme') ?? 'system';
    _themeMode = AppThemeMode.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => AppThemeMode.system,
    );
    final colorValue = prefs.getInt('primary_color') ?? 0xFF4F7CFF;
    _primaryColor = Color(colorValue);
    notifyListeners();
  }

  Future<void> setTheme(AppThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', mode.name);
    notifyListeners();
  }

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primary_color', color.value);
    notifyListeners();
  }

  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
