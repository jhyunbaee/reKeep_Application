import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rekeep/category.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:flutter_rekeep/constants/sized.dart';
import 'package:flutter_rekeep/home.dart'; // 본인의 메인 홈(탭바) 클래스 확인
import 'package:flutter_rekeep/login.dart';
import 'package:flutter_rekeep/my_card.dart';
import 'package:flutter_rekeep/profile_detail.dart';

class Setting extends StatelessWidget {
  const Setting({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. 현재 로그인된 유저 정보를 가져옵니다.
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: const Text(
          "설정",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // 2. 프로필 섹션 호출
          _buildProfileSection(context, currentUser),
          _buildFullDivider(),
          _buildMenuItem("자산 설정"),
          _buildMenuItem(
            "내 카드 관리",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyCard()),
              );
            },
          ),
          _buildMenuItem(
            "카테고리 관리",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Category()),
              );
            },
          ),
          _buildFullDivider(),
          _buildMenuItem("알림 설정"),
          _buildMenuItem("인증 및 보안"),
          _buildMenuItem("언어 설정"),
          _buildMenuItem("데이터 및 저장공간"),
          _buildMenuItem("화면 테마"),
          _buildFullDivider(),
          _buildMenuItem("사용방법"),
          _buildMenuItem("앱 공유하기"),
          _buildMenuItem("리뷰 남기기"),
          _buildMenuItem("의견 보내기"),
          _buildFullDivider(),
          _buildMenuItem("앱 버전"),
          _buildMenuItem("공지사항"),
          _buildMenuItem("고객센터"),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  Widget _buildFullDivider() => Column(
    children: [
      Container(
        height: 8,
        width: double.infinity,
        color: AppColors.dividerColor,
      ),
    ],
  );

  Widget _buildProfileSection(BuildContext context, User? user) {
    if (user == null) {
      // 로그아웃 상태일 때
      return _profileRow(
        context,
        "로그인 해주세요",
        "여기를 눌러 로그인하기",
        "!",
        isGuest: true,
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String nickname = "이름 없음";
        String email = user.email ?? "";
        String firstChar = "?";

        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          nickname = data['nickname'] ?? "이름 없음";
          firstChar = nickname.isNotEmpty ? nickname[0] : "?";
        }

        return _profileRow(context, nickname, email, firstChar, isGuest: false);
      },
    );
  }

  Widget _profileRow(
    BuildContext context,
    String title,
    String subtitle,
    String iconChar, {
    required bool isGuest,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            // ProfileDetail()에 빨간줄이 간다면 ProfileDetail 클래스 생성자를 확인해야 합니다.
            // 보통은 인자 없이 ProfileDetail()만 호출하거나, ProfileDetail(user: user) 형태입니다.
            builder: (context) =>
                isGuest ? const Login() : const ProfileDetail(),
          ),
        );
      },
      child: Padding(
        padding: AppLayout.defaultPadding,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                child: Text(
                  iconChar,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: AppColors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    String title, {
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(fontSize: 16, color: textColor ?? Colors.black),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
        color: AppColors.grey,
      ),
      onTap: onTap,
    );
  }
}
