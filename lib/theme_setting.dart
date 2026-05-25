import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rekeep/theme_provider.dart';
import 'package:flutter_rekeep/constants/colors.dart';

class ThemeSetting extends StatelessWidget {
  const ThemeSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    final List<Map<String, dynamic>> themes = [
      {
        'mode': AppThemeMode.system,
        'title': '사용자 설정 모드',
        'subtitle': '기기 설정에 따라 자동으로 변경',
        'icon': Icons.settings_suggest_outlined,
      },
      {
        'mode': AppThemeMode.light,
        'title': '라이트 모드',
        'subtitle': '밝은 화면으로 표시',
        'icon': Icons.light_mode_outlined,
      },
      {
        'mode': AppThemeMode.dark,
        'title': '다크 모드',
        'subtitle': '어두운 화면으로 표시',
        'icon': Icons.dark_mode_outlined,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          "화면 테마",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary(context)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: themes.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 24, endIndent: 24),
        itemBuilder: (context, index) {
          final item = themes[index];
          final isSelected = themeProvider.themeMode == item['mode'];

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.fieldColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                item['icon'] as IconData,
                color: isSelected ? AppColors.primary : AppColors.secondary,
                size: 22,
              ),
            ),
            title: Text(
              item['title'] as String,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textPrimary(context),
              ),
            ),
            subtitle: Text(
              item['subtitle'] as String,
              style: const TextStyle(fontSize: 13, color: AppColors.secondary),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: AppColors.primary, size: 22)
                : const Icon(
                    Icons.radio_button_unchecked,
                    color: AppColors.secondary,
                    size: 22,
                  ),
            onTap: () => themeProvider.setTheme(item['mode'] as AppThemeMode),
          );
        },
      ),
    );
  }
}
