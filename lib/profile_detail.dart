import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rekeep/login.dart';

class ProfileDetail extends StatefulWidget {
  const ProfileDetail({super.key});

  @override
  State<ProfileDetail> createState() => _ProfileDetailState();
}

class _ProfileDetailState extends State<ProfileDetail> {
  final user = FirebaseAuth.instance.currentUser;
  // 수정 가능한 항목을 위한 컨트롤러
  final TextEditingController _nicknameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("프로필 수정"), centerTitle: true),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .get(),
        // builder 내부 수정
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var userData = snapshot.data!;

          // 수정 포인트: 필드가 없을 경우를 대비해 안전하게 값을 가져옵니다.
          // data()를 사용하여 Map 형태로 변환 후 접근하는 것이 더 안전합니다.
          Map<String, dynamic> data = userData.data() as Map<String, dynamic>;

          if (_nicknameController.text.isEmpty) {
            _nicknameController.text = data.containsKey('nickname')
                ? data['nickname']
                : "";
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildLabel("이름"),
              _buildReadOnlyField(
                data.containsKey('name') ? data['name'] : "이름 없음",
              ),
              const SizedBox(height: 20),

              _buildLabel("이메일"),
              _buildReadOnlyField(
                data.containsKey('email') ? data['email'] : "이메일 없음",
              ),
              const SizedBox(height: 20),

              _buildLabel("닉네임"),
              TextField(
                controller: _nicknameController,
                decoration: InputDecoration(
                  hintText: "닉네임을 설정해주세요", // 필드가 없을 때 보여줄 힌트
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // ... 이하 동일
              const SizedBox(height: 40),

              // 로그아웃 & 회원탈퇴 버튼
              TextButton(
                onPressed: _handleSignOut,
                child: const Text("로그아웃", style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: _handleDeleteAccount,
                child: const Text("회원탈퇴", style: TextStyle(color: Colors.grey)),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ElevatedButton(
          onPressed: _updateProfile,
          child: const Text("저장하기"),
        ),
      ),
    );
  }

  // 수정 불가 전용 필드
  Widget _buildReadOnlyField(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Color(0xFFF5F5F5), // 회색빛 배경
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(value, style: const TextStyle(color: Colors.grey)),
    );
  }

  void _handleSignOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const Login()),
      (route) => false,
    );
  }

  void _handleDeleteAccount() {
    // 회원탈퇴 로직 (정말 탈퇴하시겠습니까? 팝업 후 user.delete() 실행)
  }

  void _updateProfile() async {
    await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
      'nickname': _nicknameController.text,
    });
    if (!mounted) return;
    Navigator.pop(context);
  }

  // 1. 빨간 줄 해결: 라벨 위젯 함수 추가
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}
