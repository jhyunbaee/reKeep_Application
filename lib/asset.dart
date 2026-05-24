import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    return Scaffold(
      backgroundColor: Colors.white, // 전체 배경 흰색
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false, // 기본 뒤로가기 버튼 공간 제거
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
                behavior: HitTestBehavior.opaque,
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
                  fontSize: 18,
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
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          int totalCash = 0;
          int totalCard = 0;
          int totalTransfer = 0; // 💡 이체 누적 자산 상태 관리를 위한 변수 추가
          int totalExpense = 0; // 이번 달 총 지출 (지출 + 이체)
          int lastMonthSameDayExp = 0; // 지난달 오늘까지의 지출

          List<DocumentSnapshot> monthlyDocs = [];
          DateTime now = DateTime.now();

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
                // 💡 1. 자산 연산 로직에 '이체' 조건 통합 반영
                if (type == '지출' || type == '이체') {
                  totalExpense += amount; // 총 지출 풀에 이체도 포함시킴

                  if (type == '이체') {
                    // 이체 타입이면 이체 자산에서 누적 차감 형태 기록
                    totalTransfer -= amount;
                  } else {
                    // 일반 지출인 경우 결제 수단 분류
                    if (paymentMethod == '현금') {
                      totalCash -= amount;
                    } else {
                      totalCard -= amount;
                    }
                  }
                } else if (type == '수입') {
                  if (paymentMethod == '현금') {
                    totalCash += amount;
                  } else {
                    totalCard += amount;
                  }
                }
              }

              // 지난달 데이터 비교 로직 (이체도 지출 성격이므로 함께 비교군에 포함)
              DateTime lastMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month - 1,
              );
              if (date.year == lastMonth.year &&
                  date.month == lastMonth.month) {
                if ((type == '지출' || type == '이체') && date.day <= now.day) {
                  lastMonthSameDayExp += amount;
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
                  totalCash + totalCard + totalTransfer, // 💡 총 자산에 이체분도 결합
                  totalExpense,
                  lastMonthSameDayExp,
                ),
                _buildFullDivider(),
                _buildSectionHeader("자산 구성"),
                _buildAssetComposition(
                  totalCash,
                  totalCard,
                  totalTransfer,
                ), // 💡 파라미터 전달 확장
                const SizedBox(height: 10),
                _buildFullDivider(),
                _buildSectionHeader("카드", showMore: true),
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

        String message = diff >= 0
            ? "지난달 $nowDay일보다 ${nf.format(diff)}원 덜 쓰고 있어요 "
            : "지난달 $nowDay일보다 ${nf.format(diff.abs())}원 더 쓰고 있어요 ";
        String emoji = diff >= 0 ? "☺️" : "🥲";

        Color statusColor = diff >= 0
            ? AppColors.primary
            : AppColors.pointColor;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.only(left: 24, right: 24, top: 24),
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
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  // 💡 만약 전체 컨테이너 안에서 좌측 정렬을 유지하고 싶다면 추가
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // ✨ Expanded를 지우고 Text만 남깁니다.
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5), // 💡 텍스트와 이모지 사이의 적당한 간격 지정
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
              color: AppColors.secondary,
            ),
        ],
      ),
    );
  }

  // 💡 자산 구성 두 줄 레이아웃 (현금·카드: 50%씩 / 이체: 100% 꽉 채움)
  Widget _buildAssetComposition(int cash, int card, int transfer) {
    return Padding(
      padding: AppLayout.defaultPadding,
      child: Column(
        children: [
          // 첫 번째 줄: 현금 & 카드 (각각 50%씩 반반 분할)
          Row(
            children: [
              _buildCompItem("현금", cash, AppColors.pointColor),
              const SizedBox(width: 8),
              _buildCompItem("카드", card, AppColors.primary),
            ],
          ),
          const SizedBox(height: 10), // 줄 사이 간격
          // 두 번째 줄: 이체 (가로 100% 꽉 채우기 💡)
          Row(
            children: [
              _buildCompItem("이체", transfer, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  // 💡 테두리와 내부 여백이 추가된 아이템 빌더
  Widget _buildCompItem(
    String title,
    int amount,
    Color dotColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 15,
        ), // 내부 여백 추가
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          // 깔끔한 연한 회색 테두리 추가 💡
          border: Border.all(
            color: AppColors.borderColor,
            width: 1,
          ),
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
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "${nf.format(amount)}원",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16, // 금액을 좀 더 인지하기 쉽게 16으로 살짝 키웠습니다.
                color: Colors.black,
              ),
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

        final registeredBanks = snapshot.data!.docs
            .map(
              (doc) =>
                  (doc.data() as Map<String, dynamic>)['bankName'] as String,
            )
            .toSet()
            .toList();

        Map<String, int> bankAmounts = {
          for (var bank in registeredBanks) bank: 0,
        };

        // 💡 [문법 오류 전면 수정] 루프 내부에 잘못 고립되어 있던 onPressed 제거 및 데이터 파싱 정형화
        for (var doc in monthlyDocs) {
          var data = doc.data() as Map<String, dynamic>;
          int amount = data['amount'] ?? 0;
          String type = data['type'] ?? '지출';
          String recordCardName = (data['paymentMethod'] ?? '')
              .toString()
              .trim();

          String? belongingBank;
          // registeredBanks 목록 중 결제수단 이름에 카드사명이 포함되어 있는지 1차 검증 (로컬 백업 매칭)
          for (var bank in registeredBanks) {
            if (recordCardName.contains(bank.replaceAll('카드', ''))) {
              belongingBank = bank;
              break;
            }
          }

          if (belongingBank != null &&
              registeredBanks.contains(belongingBank)) {
            if (type == '수입') {
              bankAmounts[belongingBank] =
                  (bankAmounts[belongingBank] ?? 0) + amount;
            } else if (type == '지출' || type == '이체') {
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
                padding: const EdgeInsets.only(bottom: 10),
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
    Color getBankColor(String bankName) {
      if (bankName.contains("신한")) return const Color(0xFF0046FF);
      if (bankName.contains("카카오")) return const Color(0xFFfbe201);
      if (bankName.contains("국민")) return const Color(0xFF766c62);
      if (bankName.contains("현대")) return Colors.black;
      if (bankName.contains("삼성")) return const Color(0xFF1428a0);
      if (bankName.contains("우리")) return const Color(0xFF0083cb);
      if (bankName.contains("BC")) return const Color(0xFFfa3151);
      if (bankName.contains("하나")) return const Color(0xFF009178);
      if (bankName.contains("롯데")) return const Color(0xFF54565a);
      if (bankName.contains("농협")) return const Color(0xFF01a94e);
      if (bankName.contains("엔에")) return const Color(0xFFff2233);
      if (bankName.contains("농협")) return const Color(0xFF01a94e);
      if (bankName.contains("네이버")) return const Color(0xFF00de5a);
      if (bankName.contains("MG")) return const Color(0xFF01316c);
      if (bankName.contains("케이")) return const Color(0xFF0114a7);
      if (bankName.contains("트래블")) return const Color(0xFFffffff);
      if (bankName.contains("우체국")) return const Color(0xFFffffff);
      if (bankName.contains("토스")) return const Color(0xFF000000);
      if (bankName.contains("기업")) return const Color(0xFF014898);
      if (bankName.contains("수협")) return const Color(0xFF0169b3);
      return AppColors.secondary;
    }

    final Map<String, String> bankLogos = {
      "신한카드":
          "https://logo-resources.thevc.kr/organizations/200x200/2710b0de00c920458508fce39ea93adc8ebe4c35705c946ab487ca4069bd5188_1666320283266265.jpg",
      "KB국민카드":
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
      "NH농협카드":
          "https://logo-resources.thevc.kr/organizations/200x200/040da1961c1a9b7f7e3d83b079d17fc8a95ad780ab85ff6c35dc17cb44d859ab_1646665315137844.jpg",
      "롯데카드":
          "https://financial.pstatic.net/pie/common-bi/2.11.0/images/CD_LOTTE_Profile.png",
      "BC 바로카드":
          "https://yt3.googleusercontent.com/Z2i9r_YqFxv7WnzIV9--b2MX3RwJx1iM99aNt9NrgAnwYQMc7mw38pwAZUybu3cyN23_03P_=s900-c-k-c0x00ffffff-no-rj",
      "엔에이치엔페이코":
          "https://s3.ap-northeast-2.amazonaws.com/inno.bucket.live/product/logo/PD00016385.png",
      "네이버페이":
          "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTzBopobxYh9OfOnj1tSPxi-o3YwcXmd9_ivw&s",
      "MG새마을금고":
          "https://www.dynews1.com/news/thumbnail/202402/579480_246338_459_v150.jpg",
      "케이뱅크":
          "https://play-lh.googleusercontent.com/T33DsbrsIyfRADqaa9zpIMXtJcKPLNKOap-r_COcOupbXkoZOL5q8oyJ6R9clrKxtw",
      "트래블월렛":
          "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSKazf6ZdOWp2ytHAZqHc1aOppsPHMEQQG0iw&s",
      "우체국":
          "https://e7.pngegg.com/pngimages/416/732/png-clipart-south-korea-mail-korea-post-logo-post-office-post-angle-freight-transport-thumbnail.png",
      "토스뱅크":
          "https://meta-q.cdn.bubble.io/f1740744318413x761672384496382000/%E1%84%90%E1%85%A9%E1%84%89%E1%85%B3_%E1%84%89%E1%85%B5%E1%86%B7%E1%84%87%E1%85%A9%E1%86%AF_pr.webp",
      "IBK기업은행":
          "https://file.alphasquare.co.kr/media/images/stock_logo/kr/024110.png",
      "SH수협은행":
          "https://logo-resources.thevc.kr/organizations/200x200/c4b0bbeb28ef8e55edf3988b591e11b393e2a49e16fc5bbaa905c08b5519688b_1628492710039189.jpg",
    };

    String? logoUrl = bankLogos[name];
    Color bankColor = getBankColor(name);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bankColor,
              borderRadius: BorderRadius.circular(50),
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

  Widget _buildMonthlyTransactions(List<DocumentSnapshot> monthlyDocs) {
    if (monthlyDocs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text("거래 내역이 없습니다."),
        ),
      );
    }

    Map<String, List<DocumentSnapshot>> groupedDocs = {};
    for (var doc in monthlyDocs) {
      DateTime date = (doc['date'] as Timestamp).toDate();
      String dayKey = DateFormat('MM월 dd일').format(date);

      if (!groupedDocs.containsKey(dayKey)) {
        groupedDocs[dayKey] = [];
      }
      groupedDocs[dayKey]!.add(doc);
    }

    var sortedKeys = groupedDocs.keys.toList()..sort((a, b) => b.compareTo(a));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: sortedKeys.map((dateLabel) {
          int dayIncome = 0;
          int dayExpense = 0;

          for (var doc in groupedDocs[dateLabel]!) {
            final data = doc.data() as Map<String, dynamic>;
            int amount = data['amount'] ?? 0;
            String type = data['type'] ?? '지출';

            if (type == '수입') {
              dayIncome += amount;
            } else if (type == '지출' || type == '이체') {
              // 💡 하단 일별 요약 정보에도 이체액 병합
              dayExpense += amount;
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                  Row(
                    children: [
                      if (dayIncome > 0)
                        Text(
                          "+${nf.format(dayIncome)}원 ",
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      if (dayIncome > 0 && dayExpense > 0)
                        const SizedBox(width: 4),
                      if (dayExpense > 0)
                        Text(
                          "-${nf.format(dayExpense)}원",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const Divider(thickness: 0.5),

              ...groupedDocs[dateLabel]!.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                String type = data['type'] ?? '지출';
                bool isIncome = type == '수입';

                String categoryName = data['category']?['name'] ?? "기타";
                String bankName =
                    data['bankName'] ?? data['paymentMethod'] ?? "";

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.fieldColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      data['category']?['icon'] ?? "💰",
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  title: Text(
                    data['place'] ?? "사용처 없음",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    categoryName == bankName || bankName.isEmpty
                        ? categoryName
                        : "$categoryName | $bankName",
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary,
                    ),
                  ),
                  trailing: Text(
                    "${isIncome ? '+' : '-'}${nf.format(data['amount'])}원",
                    style: TextStyle(
                      color: isIncome ? AppColors.primary : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          );
        }).toList(),
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

// BouncingText 위젯 소스코드는 변동 사항 없이 하단 유지됩니다.
