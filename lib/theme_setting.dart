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
      {'mode': AppThemeMode.light, 'title': '라이트 모드'},
      {'mode': AppThemeMode.dark, 'title': '다크 모드'},
      {'mode': AppThemeMode.system, 'title': '사용자 설정 모드'},
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
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
            child: Text(
              "화면 모드",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ),
          ...themes.map((item) {
            final isSelected = themeProvider.themeMode == item['mode'];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(
                item['title'] as String,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? themeProvider.primaryColor
                      : AppColors.textPrimary(context),
                ),
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check_circle,
                      color: themeProvider.primaryColor,
                      size: 25,
                    )
                  : const Icon(
                      Icons.radio_button_unchecked,
                      color: AppColors.secondary,
                      size: 25,
                    ),
              onTap: () => themeProvider.setTheme(item['mode'] as AppThemeMode),
            );
          }),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text(
              "테마",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ThemeProvider.brandColors.sublist(0, 6).map((item) {
                    return _buildColorItem(context, item, themeProvider);
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ThemeProvider.brandColors.sublist(6).map((item) {
                    return _buildColorItem(context, item, themeProvider);
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildColorItem(
    BuildContext context,
    Map<String, dynamic> item,
    ThemeProvider themeProvider,
  ) {
    final color = item['color'] as Color;
    final isSelected = themeProvider.primaryColor.value == color.value;
    return GestureDetector(
      onTap: () => themeProvider.setPrimaryColor(color),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: AppColors.textPrimary(context), width: 2.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
