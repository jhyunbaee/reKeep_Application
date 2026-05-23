import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart'; // 💡 CSV 파싱 라이브러리
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // 💡 rootBundle 사용을 위한 임포트
import 'package:flutter_rekeep/category.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:flutter_rekeep/constants/sized.dart';
// 본인의 메인 홈(탭바) 클래스 확인
import 'package:flutter_rekeep/login.dart';
import 'package:flutter_rekeep/my_card.dart';
import 'package:flutter_rekeep/profile_detail.dart';
import 'package:flutter_rekeep/setting_asset.dart';

Future<void> uploadCardsFromCsv(BuildContext context) async {
  try {
    print("CSV 파일 로드 시작...");
    final rawData = await rootBundle.loadString("assets/total_cards.csv");
    if (rawData.trim().isEmpty) {
      print("[경고] total_cards.csv 파일이 텅 비어있거나 읽어오지 못했습니다.");
      return;
    }

    // 💡 줄바꿈 기호 정제
    final cleanedData = rawData.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    List<List<dynamic>> csvTable = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(cleanedData);

    final firestore = FirebaseFirestore.instance;
    final collectionRef = firestore.collection('total_cards');

    print("파일 내부 전체 행 수: ${csvTable.length}개");
    print("실제 업로드 대상 카드 데이터 수: ${csvTable.length - 1}개");

    if (csvTable.length <= 1) {
      print("[경고] 헤더 외에 업로드할 데이터 행이 존재하지 않습니다.");
      return;
    }

    // 기존 데이터 청소
    final existingDocs = await collectionRef.get();
    for (var doc in existingDocs.docs) {
      await doc.reference.delete();
    }
    print("기존 total_cards 도감 컬렉션 청소 완료");

    for (int i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];

      if (row.isEmpty || row[0].toString().trim().isEmpty) continue;

      String bankName = row[0].toString().trim();
      String cardName = row[1].toString().trim();
      String imgUrl = row[2].toString().trim();
      String benefit = row[3].toString().trim();
      String type = row[4].toString().trim();

      // 💡 [핵심 보정] 눈에 보이지 않는 \r 공백 제거 및 필드 파싱 안전화
      int rotate = 0;
      if (row.length > 5 && row[5].toString().trim().isNotEmpty) {
        rotate = int.tryParse(row[5].toString().trim()) ?? 0;
      }

      String position = 'center';
      if (row.length > 6 && row[6].toString().trim().isNotEmpty) {
        position = row[6].toString().trim();
      }

      // 파이어베이스 업로드
      await collectionRef.add({
        'bankName': bankName,
        'cardName': cardName,
        'imgUrl': imgUrl,
        'type': type,
        'benefit': benefit,
        'rotate': rotate, // 🔥 드디어 정상 저장
        'position': position, // 🔥 드디어 정상 저장
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    print("✅ 회전/정렬 제어 값이 포함된 모든 데이터가 파이어베이스에 업로드되었습니다!");
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🎉 CSV 카드 도감 동기화 완벽 완료!")),
    );
  } catch (e) {
    print("❌ CSV 업로드 중 에러 발생: $e");
  }
}

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

      // ⭐️ 원래 원본 메뉴의 순서와 구성을 단 하나도 빠짐없이 100% 유지한 본문 리스트
      body: ListView(
        children: [
          // 2. 프로필 섹션 호출
          _buildProfileSection(context, currentUser),
          _buildFullDivider(),
          _buildMenuItem("프리미엄 혜택받기"),
          _buildFullDivider(),
          _buildMenuItem(
            "자산 설정",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingAsset()),
              );
            },
          ),
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
          _buildMenuItem("위젯 설정"),
          _buildMenuItem("인증 및 보안"),
          _buildMenuItem("화면 테마"),
          _buildFullDivider(),
          _buildMenuItem("사용방법"),
          _buildMenuItem("리뷰 남기기"),
          _buildMenuItem("자주 묻는 질문"),
          _buildMenuItem("앱 공유하기"),
          _buildFullDivider(),
          _buildMenuItem("앱 버전"),
          _buildMenuItem("고객센터"),
          const SizedBox(height: 15),

          // 💡 하단 버튼을 누르면 위에서 선언한 CSV 파일 파싱 업로드 함수가 돌도록 연동
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ElevatedButton(
              onPressed: () async {
                await uploadCardsFromCsv(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Firestore에 엑셀(CSV) 카드 데이터 밀어넣기"),
            ),
          ),
          const SizedBox(height: 30),
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
            builder: (context) =>
                isGuest ? const Login() : const ProfileDetail(),
          ),
        );
      },
      child: Padding(
        padding: AppLayout.defaultPadding,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
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
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 14,
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
