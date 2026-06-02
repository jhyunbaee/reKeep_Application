import 'package:flutter/material.dart';
import 'package:flutter_rekeep/constants/colors.dart';

class BottomMenuBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const BottomMenuBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: AppColors.background(context),
        border: Border(
          top: BorderSide(color: AppColors.borderColor),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMenuItem(context, Icons.home_rounded, "홈", 0),
            _buildMenuItem(context, Icons.wallet, "자산", 1),
            _buildMenuItem(context, Icons.equalizer_rounded, "분석", 2),
            _buildMenuItem(context, Icons.more_horiz_rounded, "더보기", 3),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
  ) {
    final bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 5),
          Icon(
            icon,
            size: 22,
            color: isSelected
                ? AppColors.primary(context)
                : AppColors.secondary,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? AppColors.primary(context)
                  : AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
