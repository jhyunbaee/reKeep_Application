import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rekeep/constants/card_data.dart';
import 'package:flutter_rekeep/constants/sized.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rekeep/constants/colors.dart';

class Asset extends StatefulWidget {
  const Asset({super.key});

  @override
  State<Asset> createState() => _AssetState();
}

class _AssetState extends State<Asset> {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final NumberFormat nf = NumberFormat('#,###');

  // 현재 보고 있는 기준 날짜 (월 이동 기능용)
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    // Primary 색상의 10% 투명도 버전

    return Scaffold(
      backgroundColor: Colors.white, // 전체 배경 흰색
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false, // 기본 뒤로가기 버튼 공간 제거
        // 💡 핵심: title 영역에 Row를 꽉 채워서 커스텀 배치합니다.
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0), // 전체 24px 여백
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. 왼쪽 버튼
              GestureDetector(
                onTap: () => setState(
                  () => _selectedMonth = DateTime(
                    _selectedMonth.year,
                    _selectedMonth.month - 1,
                  ),
                ),
                behavior: HitTestBehavior.opaque, // 아이콘 주변 빈 공간도 터치 가능하게
                child: const Icon(
                  Icons.chevron_left,
                  color: Colors.black,
                  size: 28,
                ),
              ),

              // 2. 중앙 월 표시
              Text(
                "${_selectedMonth.month}월",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 20,
                ),
              ),

              // 3. 오른쪽 버튼
              GestureDetector(
                onTap: () => setState(
                  () => _selectedMonth = DateTime(
                    _selectedMonth.year,
                    _selectedMonth.month + 1,
                  ),
                ),
                behavior: HitTestBehavior.opaque,
                child: const Icon(
                  Icons.chevron_right,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId ?? 'guest')
            .collection('records')
            .where(
              'date',
              isGreaterThanOrEqualTo: DateTime(
                _selectedMonth.year,
                _selectedMonth.month,
                1,
              ),
            )
            .where(
              'date',
              isLessThan: DateTime(
                _selectedMonth.year,
                _selectedMonth.month + 1,
                1,
              ),
            )
            .snapshots(),
        // 1. build 메서드 내의 StreamBuilder 부분
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          int totalCash = 0;
          int totalCard = 0;
          int totalExpense = 0; // 이번 달 총 지출
          int lastMonthSameDayExp = 0; // 지난달 오늘까지의 지출

          List<DocumentSnapshot> monthlyDocs = [];
          DateTime now = DateTime.now();

          if (snapshot.hasData) {
            monthlyDocs = snapshot.data!.docs;

            if (snapshot.hasData) {
              monthlyDocs = snapshot.data!.docs;

              for (var doc in monthlyDocs) {
                var data = doc.data() as Map<String, dynamic>;
                int amount = data['amount'] ?? 0;
                String type = data['type'] ?? '지출';
                String paymentMethod = (data['paymentMethod'] ?? '현금')
                    .toString()
                    .trim();

                Timestamp ts = data['date'];
                DateTime date = ts.toDate();

                if (date.year == _selectedMonth.year &&
                    date.month == _selectedMonth.month) {
                  if (type == '지출') {
                    totalExpense += amount;
                    // 지출: 현금이면 현금에서, 아니면 카드에서 차감
                    if (paymentMethod == '현금') {
                      totalCash -= amount;
                    } else {
                      totalCard -= amount;
                    }
                  } else if (type == '수입') {
                    // 💡 이 부분을 수정합니다: 수입도 결제수단에 따라 분류
                    if (paymentMethod == '현금') {
                      totalCash += amount;
                    } else {
                      totalCard +=
                          amount; // 카드(계좌) 수입이면 카드 자산에 더함                    }
                    }
                  }
                }

                // 지난달 데이터 비교 로직 (기존 유지)
                DateTime lastMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
                if (date.year == lastMonth.year &&
                    date.month == lastMonth.month) {
                  if (type == '지출' && date.day <= now.day) {
                    lastMonthSameDayExp += amount;
                  }
                }
              }
            }
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAssetHeader(
                  userId,
                  totalCash + totalCard,
                  totalExpense,
                  lastMonthSameDayExp,
                ),
                _buildFullDivider(),
                _buildSectionHeader("자산 구성"),
                _buildAssetComposition(totalCash, totalCard),
                const SizedBox(height: 10),
                _buildFullDivider(),
                _buildSectionHeader("카드", showMore: true),
                // 💡 합산된 내역(monthlyDocs)을 전달합니다.
                _buildAccountList(monthlyDocs),
                const SizedBox(height: 10),
                _buildFullDivider(),
                _buildSectionHeader("${_selectedMonth.month}월 거래 내역"),
                _buildMonthlyTransactions(monthlyDocs),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAssetHeader(
    String? userId,
    int totalAsset,
    int currentMonthExpense,
    int lastMonthSameDayExp,
  ) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, userSnapshot) {
        String nickname = "사용자";
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          nickname = userSnapshot.data!['nickname'] ?? "사용자";
        }

        int nowDay = DateTime.now().day;
        int diff = lastMonthSameDayExp - currentMonthExpense;

        // 문구와 이모티콘 분리
        String message = diff >= 0
            ? "지난달 ${nowDay}일보다 ${nf.format(diff)}원 덜 쓰고 있어요 "
            : "지난달 ${nowDay}일보다 ${nf.format(diff.abs())}원 더 쓰고 있어요 ";
        String emoji = diff >= 0 ? "☺️" : "🥲";

        Color statusColor = diff >= 0
            ? AppColors.primary
            : AppColors.pointColor;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.only(left: 24, right: 24, top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$nickname님의 총 자산",
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${nf.format(totalAsset)}원",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              // 💡 배경색 100% + 이모티콘만 튀는 영역
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    BouncingText(
                      text: emoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFullDivider() => Column(
    children: [
      const SizedBox(height: 20),
      Container(
        height: 8,
        width: double.infinity,
        color: AppColors.dividerColor,
      ),
      const SizedBox(height: 20),
    ],
  );

  // 총 자산 카드
  Widget _buildTotalAssetCard(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 24, right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "000님의 총 자산",
            style: TextStyle(color: Colors.black, fontSize: 14),
          ),
          const SizedBox(height: 5),
          Text(
            "${nf.format(total)}원",
            style: const TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 섹션 타이틀 (더보기 버튼 추가 가능)
  Widget _buildSectionHeader(String title, {bool showMore = false}) {
    return Padding(
      padding: AppLayout.defaultPadding.copyWith(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (showMore)
            const Icon(
              Icons.chevron_right,
              color: AppColors.grey,
            ), // 타이틀 오른쪽 화살표
        ],
      ),
    );
  }

  // 자산 구성
  Widget _buildAssetComposition(int cash, int card) {
    return Padding(
      padding: AppLayout.defaultPadding,
      child: Row(
        children: [
          _buildCompItem("현금", cash, AppColors.pointColor),
          _buildCompItem("카드", card, AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildCompItem(
    String title,
    int amount,
    Color dotColor,
  ) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 4, backgroundColor: dotColor),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "${nf.format(amount)}원",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountList(List<DocumentSnapshot> monthlyDocs) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId ?? 'guest')
          .collection('my_cards')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("등록된 카드가 없습니다."));
        }

        // 1. 등록된 카드사(은행명) 리스트 준비
        final registeredBanks = snapshot.data!.docs
            .map(
              (doc) =>
                  (doc.data() as Map<String, dynamic>)['bankName'] as String,
            )
            .toSet()
            .toList();

        // 2. 카드사별 잔액 맵 초기화 (0원)
        Map<String, int> bankAmounts = {
          for (var bank in registeredBanks) bank: 0,
        };

        // asset.dart의 _buildAccountList 내부 수정

        for (var doc in monthlyDocs) {
          var data = doc.data() as Map<String, dynamic>;
          int amount = data['amount'] ?? 0;
          String type = data['type'] ?? '지출';

          // 1. 내역에 저장된 카드의 '이름'(cardName)을 가져옵니다. (예: "체크(포인트형)")
          String recordCardName = (data['paymentMethod'] ?? '')
              .toString()
              .trim();

          // 2. CardData에서 이 카드가 어느 카드사(bankName) 소속인지 찾아냅니다.
          String? belongingBank;
          try {
            belongingBank = CardData.allCards
                .firstWhere((card) => card.cardName.trim() == recordCardName)
                .bankName;
          } catch (e) {
            // 만약 카드 데이터에서 못 찾으면, 이름에 카드사명이 포함되어 있는지 한 번 더 체크 (신한카드 케이스 대비)
            for (var bank in registeredBanks) {
              if (recordCardName.contains(bank.replaceAll('카드', ''))) {
                belongingBank = bank;
                break;
              }
            }
          }

          // 3. 찾아낸 카드사(belongingBank)가 내 자산 목록(registeredBanks)에 있다면 합산!
          if (belongingBank != null &&
              registeredBanks.contains(belongingBank)) {
            if (type == '수입') {
              bankAmounts[belongingBank] =
                  (bankAmounts[belongingBank] ?? 0) + amount;
            } else {
              bankAmounts[belongingBank] =
                  (bankAmounts[belongingBank] ?? 0) - amount;
            }
          }
        }

        return Padding(
          padding: AppLayout.defaultPadding,
          child: Column(
            children: bankAmounts.keys.map((bankName) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAccountTile(
                  bankName,
                  "${nf.format(bankAmounts[bankName])}원",
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildAccountTile(String name, String balance) {
    // 1. 카드사별 대표 색상 지정
    Color getBankColor(String bankName) {
      if (bankName.contains("신한")) return const Color(0xFF0046FF);
      if (bankName.contains("카카오")) return const Color(0xFFfbe201);
      if (bankName.contains("국민")) return const Color(0xFF766c62);
      if (bankName.contains("현대")) return Colors.black;
      if (bankName.contains("삼성")) return const Color(0xFF1428a0);
      if (bankName.contains("우리")) return const Color(0xFF0083cb);
      if (bankName.contains("비씨")) return const Color(0xFFfa3151);
      if (bankName.contains("하나")) return const Color(0xFF009178);
      if (bankName.contains("롯데")) return const Color(0xFF54565a);
      if (bankName.contains("농협")) return const Color(0xFF01a94e);
      return AppColors.secondary; // 기본 색상
    }

    // 카드사별 로고 맵 (기존 동일)
    final Map<String, String> bankLogos = {
      "신한카드":
          "https://logo-resources.thevc.kr/organizations/200x200/2710b0de00c920458508fce39ea93adc8ebe4c35705c946ab487ca4069bd5188_1666320283266265.jpg",
      "국민카드":
          "https://logo-resources.thevc.kr/organizations/200x200/9722fbb9c8b0ca1eff7d72a15be6eca7e09884a207e7d7707660faecd04d86ae_1646662511432117.jpg",
      "카카오뱅크":
          "https://upload.wikimedia.org/wikipedia/commons/5/52/Kakao_Bank_of_Korea_Logo.jpg",
      "현대카드":
          "https://play-lh.googleusercontent.com/qH_9WhKM7uT2Ru7w29q_qXqHn0rK0PMd7f1KrdJM3JUtyvxtkCJlCnsGnmTg6kYbXp0",
      "삼성카드":
          "https://logo-resources.thevc.kr/organizations/200x200/bd4dd5dd2e42ebb15490840c66957e4c42bb2348448ed636ebe08528f22773d2_1646618385259179.jpg",
      "우리카드":
          "https://wiki1.kr/images/thumb/7/72/%EC%9A%B0%EB%A6%AC%EA%B8%88%EC%9C%B5%EC%BA%90%ED%94%BC%ED%83%88%E3%88%9C_%EB%A1%9C%EA%B3%A0.png/200px-%EC%9A%B0%EB%A6%AC%EA%B8%88%EC%9C%B5%EC%BA%90%ED%94%BC%ED%83%88%E3%88%9C_%EB%A1%9C%EA%B3%A0.png",
      "하나카드":
          "https://m.hanacard.co.kr/ATTACH/MKA/images/event/event_list/sum_hanapay_m.png",
      "농협카드":
          "https://logo-resources.thevc.kr/organizations/200x200/040da1961c1a9b7f7e3d83b079d17fc8a95ad780ab85ff6c35dc17cb44d859ab_1646665315137844.jpg",
      "롯데카드":
          "https://financial.pstatic.net/pie/common-bi/2.11.0/images/CD_LOTTE_Profile.png",
      "비씨카드":
          "https://yt3.googleusercontent.com/Z2i9r_YqFxv7WnzIV9--b2MX3RwJx1iM99aNt9NrgAnwYQMc7mw38pwAZUybu3cyN23_03P_=s900-c-k-c0x00ffffff-no-rj",
    };

    String? logoUrl = bankLogos[name];
    Color bankColor = getBankColor(name);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // 배경색이 바뀌는 부분입니다.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              // 카드사 색상의 10% 정도 투명도를 주면 부드러운 배경색이 됩니다.
              // 만약 꽉 찬 색을 원하시면 그냥 bankColor만 쓰셔도 됩니다.
              color: bankColor,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: logoUrl != null
                    ? Image.network(
                        logoUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.credit_card, size: 18, color: bankColor),
                      )
                    : Icon(Icons.credit_card, size: 18, color: bankColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            balance,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // 이번 달 거래 내역
  Widget _buildMonthlyTransactions(List<DocumentSnapshot> docs) {
    if (docs.isEmpty)
      return const Center(
        child: Padding(padding: EdgeInsets.all(30), child: Text("내역이 없습니다.")),
      );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: docs.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: AppColors.dividerColor),
        itemBuilder: (context, index) {
          var data = docs[index].data() as Map<String, dynamic>;
          bool isIncome = data['type'] == '수입';
          return ListTile(
            title: Text(
              data['place'] ?? '항목 없음',
              style: const TextStyle(fontSize: 16),
            ),
            trailing: Text(
              "${isIncome ? '+' : '-'}${nf.format(data['amount'])}원",
              style: TextStyle(
                color: isIncome ? AppColors.primary : AppColors.pointColor,
                fontSize: 14,
              ),
            ),
          );
        },
      ),
    );
  }
}

class BouncingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const BouncingText({super.key, required this.text, required this.style});

  @override
  State<BouncingText> createState() => _BouncingTextState();
}

class _BouncingTextState extends State<BouncingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: -5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Text(widget.text, style: widget.style),
        );
      },
    );
  }
}
