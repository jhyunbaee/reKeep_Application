import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:flutter_rekeep/login.dart';
import 'package:flutter_rekeep/profile_detail.dart';

class Setting extends StatelessWidget {
  const Setting({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("더보기", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // 1. 프로필 영역 (로그인 유도)
          _buildProfileSection(context, user),
          const Divider(thickness: 8, color: Color(0xFFF5F5F5)),

          // 2. 메뉴 리스트
          _buildMenuItem(Icons.notifications_none, "공지사항"),
          _buildMenuItem(Icons.settings_outlined, "설정"),
          _buildMenuItem(Icons.help_outline, "고객센터"),
        ],
      ),
    );
  }

  // Firestore에서 정보를 가져오기 위해 FutureBuilder 사용 추천
  Widget _buildProfileSection(BuildContext context, User? user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String nickname = "로그인 해주세요";
        String email = user?.email ?? "";
        String firstChar = "!";

        if (snapshot.hasData && snapshot.data!.exists) {
          nickname = snapshot.data!['nickname'] ?? "이름 없음";
          email = snapshot.data!['email'] ?? "";
          firstChar = nickname.isNotEmpty ? nickname[0] : "?";
        }

        return InkWell(
          onTap: () {
            if (user != null) {
              // 상세 프로필 페이지로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileDetail(),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Login()),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                // 아이폰 연락처 스타일 아바타
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    firstChar,
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
                      nickname,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap ?? () {},
    );
  }
}
