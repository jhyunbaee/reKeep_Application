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

  DateTime _selectedMonth = DateTime.now();
  List<Map<String, dynamic>> _recurringItems = [];

  @override
  void initState() {
    super.initState();
    _loadRecurringExpenses();
  }

  Future<void> _loadRecurringExpenses() async {
    if (userId == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recurring_expenses')
        .get();

    setState(() {
      _recurringItems = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        surfaceTintColor: AppColors.background(context),
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(
                  () => _selectedMonth = DateTime(
                    _selectedMonth.year,
                    _selectedMonth.month - 1,
                  ),
                ),
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  Icons.chevron_left,
                  color: AppColors.textPrimary(context),
                  size: 28,
                ),
              ),

              Text(
                "${_selectedMonth.month}월",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                  fontSize: 18,
                ),
              ),

              GestureDetector(
                onTap: () => setState(
                  () => _selectedMonth = DateTime(
                    _selectedMonth.year,
                    _selectedMonth.month + 1,
                  ),
                ),
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  Icons.chevron_right,
                  color: AppColors.textPrimary(context),
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
          int totalTransfer = 0;
          int totalExpense = 0;
          int lastMonthSameDayExp = 0;

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
                if (type == '지출' || type == '이체') {
                  totalExpense += amount;

                  if (type == '이체') {
                    totalTransfer -= amount;
                  } else {
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
                  totalCash + totalCard + totalTransfer,
                  totalExpense,
                  lastMonthSameDayExp,
                ),
                _buildFullDivider(),
                _buildSectionHeader("자산 구성"),
                _buildAssetComposition(
                  totalCash,
                  totalCard,
                  totalTransfer,
                ),
                const SizedBox(height: 10),
                _buildFullDivider(),
                _buildSectionHeader("카드", showMore: true),
                _buildAccountList(monthlyDocs),
                const SizedBox(height: 10),
                _buildFullDivider(),
                _buildSectionHeader("${_selectedMonth.month}월 거래 내역"),
                _buildMonthlyTransactions(monthlyDocs, _recurringItems),
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
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
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5),
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
        color: AppColors.divider(context),
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

  Widget _buildAssetComposition(int cash, int card, int transfer) {
    return Padding(
      padding: AppLayout.defaultPadding,
      child: Column(
        children: [
          Row(
            children: [
              _buildCompItem("현금", cash, AppColors.pointColor),
              const SizedBox(width: 8),
              _buildCompItem("카드", card, AppColors.primary),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildCompItem("이체", transfer, Colors.green),
            ],
          ),
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
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.divider(context),
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
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "${nf.format(amount)}원",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary(context),
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

        for (var doc in monthlyDocs) {
          var data = doc.data() as Map<String, dynamic>;
          int amount = data['amount'] ?? 0;
          String type = data['type'] ?? '지출';
          String recordCardName = (data['paymentMethod'] ?? '')
              .toString()
              .trim();

          String? belongingBank;
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),

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

  Widget _buildMonthlyTransactions(
    List<DocumentSnapshot> monthlyDocs,
    List<Map<String, dynamic>> recurringItems,
  ) {
    final DateTime now = DateTime.now();
    final bool isCurrentMonth =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;

    List<Map<String, dynamic>> recurringAsDocs = [];
    for (var item in recurringItems) {
      var dayData = item['day'] ?? '1일';
      int day = (dayData is String)
          ? int.tryParse(dayData.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1
          : (dayData as int);

      if (isCurrentMonth && day > now.day) continue;

      String expenseType = item['expenseType'] ?? '고정지출';
      String icon = expenseType == '고정지출' ? '🗓️' : '📊';

      recurringAsDocs.add({
        'place': item['name'] ?? '',
        'amount': item['amount'] ?? 0,
        'type': '지출',
        'category': {'name': expenseType, 'icon': icon},
        'bankName': '',
        'date': DateTime(
          _selectedMonth.year,
          _selectedMonth.month,
          day,
        ),
        'isRecurring': true,
      });
    }

    List<Map<String, dynamic>> allItems = [
      ...monthlyDocs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['date'] = (data['date'] as Timestamp).toDate();
        return data;
      }),
      ...recurringAsDocs,
    ];

    if (allItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text("거래 내역이 없습니다."),
        ),
      );
    }

    Map<String, List<Map<String, dynamic>>> groupedItems = {};
    for (var item in allItems) {
      DateTime date = item['date'] as DateTime;
      String dayKey = DateFormat('MM월 dd일').format(date);
      groupedItems[dayKey] ??= [];
      groupedItems[dayKey]!.add(item);
    }

    var sortedKeys = groupedItems.keys.toList()..sort((a, b) => b.compareTo(a));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: sortedKeys.map((dateLabel) {
          int dayIncome = 0;
          int dayExpense = 0;

          for (var item in groupedItems[dateLabel]!) {
            int amount = item['amount'] ?? 0;
            String type = item['type'] ?? '지출';
            if (type == '수입') {
              dayIncome += amount;
            } else if (type == '지출' || type == '이체') {
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
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary(context),
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
                      if (dayExpense > 0)
                        Text(
                          "-${nf.format(dayExpense)}원",
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const Divider(thickness: 0.5),
              ...groupedItems[dateLabel]!.map((item) {
                String type = item['type'] ?? '지출';
                bool isIncome = type == '수입';
                String categoryName = item['category']?['name'] ?? "기타";
                String bankName =
                    item['bankName'] ?? item['paymentMethod'] ?? "";

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
                      item['category']?['icon'] ?? "💰",
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  title: Text(
                    item['place'] ?? "사용처 없음",
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
                    "${isIncome ? '+' : '-'}${nf.format(item['amount'])}원",
                    style: TextStyle(
                      color: isIncome
                          ? AppColors.primary
                          : AppColors.textPrimary(context),
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
