import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_rekeep/constants/colors.dart'; // 본인 프로젝트 경로 확인

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
      height: 85, // 높이를 넉넉하게 수정
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.borderColor),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMenuItem(FontAwesomeIcons.houseChimney, "홈", 0),
            _buildMenuItem(FontAwesomeIcons.sackDollar, "자산", 1),
            _buildMenuItem(FontAwesomeIcons.chartSimple, "분석", 2),
            _buildMenuItem(FontAwesomeIcons.ellipsis, "더보기", 3),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, int index) {
    final bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onTap(index), // 여기서 index를 넘겨줍니다.
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 5),
          FaIcon(
            icon,
            size: 18,
            color: isSelected ? AppColors.primary : AppColors.secondary,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
