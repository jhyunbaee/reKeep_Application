import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rekeep/constants/colors.dart';

class SettingAsset extends StatefulWidget {
  const SettingAsset({super.key});

  @override
  State<SettingAsset> createState() => _SettingAssetState();
}

class _SettingAssetState extends State<SettingAsset> {
  final NumberFormat formatter = NumberFormat('#,###');
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // 실제 앱에서는 이 값들을 Firestore에서 불러와서 보여주거나 저장하게 됩니다.
  int startingAsset = 0;
  int targetAsset = 0;
  int budget = 0;
  bool isLoading = true; // 로딩 상태 추가

  @override
  void initState() {
    super.initState();
    _loadAssetData(); // 페이지 진입 시 Firestore 데이터 로드
  }

  Future<void> _loadAssetData() async {
    if (currentUserId == null) return;
    try {
      // 시작 자산, 목표 자산 불러오기
      final assetDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('assets')
          .doc('management')
          .get();

      // 전체 총 예산 금액 불러오기
      final budgetDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('budgets')
          .doc('total_budget') // 전체 예산을 저장하는 문서ID 고정
          .get();

      if (mounted) {
        setState(() {
          if (assetDoc.exists) {
            final data = assetDoc.data() as Map<String, dynamic>;
            startingAsset = data['startingAsset'] ?? 0;
            targetAsset = data['targetAsset'] ?? 0;
          }
          if (budgetDoc.exists) {
            final data = budgetDoc.data() as Map<String, dynamic>;
            budget = data['amount'] ?? 0;
          }
          isLoading = false;
        });
      }
    } catch (e) {
      print("자산 데이터 로드 실패: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _updateAssetData(String field, int value) async {
    if (currentUserId == null) return;
    try {
      if (field == 'budget') {
        // 예산 저장: budgets/total_budget 문서에 저장
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('budgets')
            .doc('total_budget')
            .set({'amount': value}, SetOptions(merge: true));
      } else {
        // 시작자산 / 목표자산 저장
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('assets')
            .doc('management')
            .set({field: value}, SetOptions(merge: true));
      }
    } catch (e) {
      print("Firestore 저장 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          "자산 설정",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: ListView(
          children: [
            _buildAssetItem(
              // 저축 시작
              "시작 자산",
              "${formatter.format(startingAsset)}원",
              () => _showAssetSheet("시작 자산", startingAsset, (val) {
                setState(() => startingAsset = val);
                _updateAssetData('startingAsset', val);
              }),
            ),
            _buildAssetItem(
              "목표 자산",
              "${formatter.format(targetAsset)}원",
              () => _showAssetSheet("목표 자산", targetAsset, (val) {
                setState(() => targetAsset = val);
                _updateAssetData('targetAsset', val);
              }),
            ),
            _buildAssetItem(
              "예산 설정",
              "${formatter.format(budget)}원",
              () => _showBudgetSheet(budget, (val) {
                setState(() => budget = val);
                _updateAssetData('budget', val);
              }),
            ),
            _buildAssetItem(
              "고정지출",
              "매달 고정적인 지출 관리",
              () => _showComingSoonSheet("고정지출"),
            ),
            _buildAssetItem(
              "변동지출",
              "유연한 지출 항목 관리",
              () => _showComingSoonSheet("변동지출"),
            ),
          ],
        ),
      ),
    );
  }

  // 리스트 타일 빌더
  Widget _buildAssetItem(
    String title,
    String trailingText,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            trailingText,
            style: const TextStyle(fontSize: 15, color: AppColors.secondary),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.secondary),
        ],
      ),
      onTap: onTap,
    );
  }

  // 자산 입력 바텀시트
  void _showAssetSheet(String title, int currentValue, Function(int) onSave) {
    final TextEditingController controller = TextEditingController(
      text: currentValue > 0 ? "${formatter.format(currentValue)}원" : "",
    );

    controller.addListener(() {
      String text = controller.text
          .replaceAll(',', '')
          .replaceAll('원', '')
          .trim();
      if (text.isEmpty) return;
      double? value = double.tryParse(text);
      if (value != null) {
        String newText = "${formatter.format(value)}원";
        if (newText != controller.text) {
          controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length - 1),
          );
        }
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 20,
                    ),
                    decoration: InputDecoration(
                      hintText: "금액을 입력하세요 (예: 10,000원)",
                      hintStyle: const TextStyle(
                        fontSize: 20,
                        color: AppColors.secondary,
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.dividerColor),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        String cleanText = controller.text
                            .replaceAll(',', '')
                            .replaceAll('원', '')
                            .trim();
                        int parsedValue = int.tryParse(cleanText) ?? 0;
                        onSave(parsedValue);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "완료",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showComingSoonSheet(String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              "$title 등록 및 관리 폼이 여기에 들어옵니다.",
              style: const TextStyle(color: AppColors.secondary),
            ),
            const SizedBox(height: 20),
          ],
        ),
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

  void _showBudgetSheet(int currentBudget, Function(int) onSave) {
    final TextEditingController totalBudgetController = TextEditingController(
      text: currentBudget > 0 ? "${formatter.format(currentBudget)}원" : "",
    );

    final List<Map<String, dynamic>> categories = [
      {'name': '식비', 'icon': '🍔', 'budget': 0},
      {'name': '교통', 'icon': '🚗', 'budget': 0},
      {'name': '쇼핑', 'icon': '🛍️', 'budget': 0},
      {'name': '취미', 'icon': '🎨', 'budget': 0},
      {'name': '생활', 'icon': '🏠', 'budget': 0},
    ];

    final Map<String, TextEditingController> categoryControllers = {};
    for (var cat in categories) {
      categoryControllers[cat['name']] = TextEditingController();
    }

    int lastMonthExpense = 845000;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId ?? 'guest')
              .collection('budgets')
              .get(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              for (var doc in snapshot.data!.docs) {
                String cName = doc.id;
                if (cName == 'total_budget')
                  continue; // total_budget 문서는 카테고리 매핑에서 제외

                int amt = (doc.data() as Map<String, dynamic>)['amount'] ?? 0;
                int idx = categories.indexWhere((c) => c['name'] == cName);
                if (idx != -1 && categories[idx]['budget'] == 0 && amt > 0) {
                  categories[idx]['budget'] = amt;
                  categoryControllers[cName]!.text =
                      "${formatter.format(amt)}원";
                }
              }
            }

            return StatefulBuilder(
              builder: (context, setModalState) {
                int getTotalBudget() {
                  String txt = totalBudgetController.text
                      .replaceAll(',', '')
                      .replaceAll('원', '')
                      .trim();
                  return int.tryParse(txt) ?? 0;
                }

                int getCategoryTotal() {
                  int total = 0;
                  for (var cat in categories) {
                    String txt = categoryControllers[cat['name']]!.text
                        .replaceAll(',', '')
                        .replaceAll('원', '')
                        .trim();
                    total += int.tryParse(txt) ?? 0;
                  }
                  return total;
                }

                void setupAmountListener(TextEditingController controller) {
                  controller.addListener(() {
                    String text = controller.text
                        .replaceAll(',', '')
                        .replaceAll('원', '')
                        .trim();
                    if (text.isEmpty) return;
                    double? value = double.tryParse(text);
                    if (value != null) {
                      String newText = "${formatter.format(value)}원";
                      if (newText != controller.text) {
                        controller.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(
                            offset: newText.length - 1,
                          ),
                        );
                        setModalState(() {});
                      }
                    }
                  });
                }

                if (!totalBudgetController.hasListeners) {
                  setupAmountListener(totalBudgetController);
                  for (var controller in categoryControllers.values) {
                    setupAmountListener(controller);
                  }
                }

                int totalBudget = getTotalBudget();
                int categoryTotal = getCategoryTotal();
                int remaining = totalBudget - categoryTotal;

                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(25),
                    ),
                  ),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "예산 설정",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: const Text(
                                  "한 달 예산",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: TextField(
                                  controller: totalBudgetController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: "0원",
                                    hintStyle: TextStyle(
                                      fontSize: 24,
                                      color: AppColors.secondary,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 0,
                                    ),
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "지난달 지출",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      "${formatter.format(lastMonthExpense)}원",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),
                              _buildFullDivider(),
                              const SizedBox(height: 30),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: const Text(
                                      "카테고리별 예산",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: Text(
                                      remaining >= 0
                                          ? "${formatter.format(remaining)}원 남음"
                                          : "${formatter.format(remaining.abs())}원 초과",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: remaining >= 0
                                            ? AppColors.primary
                                            : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        "한 달 예산 ",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                      Text(
                                        totalBudget > 0
                                            ? "${formatter.format(totalBudget)}원"
                                            : "0원",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: categories.length,
                                  itemBuilder: (context, index) {
                                    final cat = categories[index];
                                    final controller =
                                        categoryControllers[cat['name']];

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor:
                                                AppColors.fieldColor,
                                            child: Text(
                                              cat['icon'],
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              cat['name'],
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: SizedBox(
                                              height: 40,
                                              child: TextField(
                                                controller: controller,
                                                keyboardType:
                                                    TextInputType.number,
                                                textAlign: TextAlign.end,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                decoration: const InputDecoration(
                                                  hintText: "0원",
                                                  hintStyle: TextStyle(
                                                    fontSize: 16,
                                                    color: AppColors.secondary,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                  ),
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                        vertical: 10,
                                                        horizontal: 4,
                                                      ),
                                                  enabledBorder:
                                                      UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                          color: AppColors
                                                              .dividerColor,
                                                        ),
                                                      ),
                                                  focusedBorder:
                                                      UnderlineInputBorder(
                                                        borderSide: BorderSide(
                                                          color:
                                                              AppColors.primary,
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                ),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                ],
                                                onChanged: (val) {
                                                  String clean = val
                                                      .replaceAll(',', '')
                                                      .replaceAll('원', '')
                                                      .trim();
                                                  categories[index]['budget'] =
                                                      int.tryParse(clean) ?? 0;
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),

                      // 하단 완료 버튼
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                          left: 24,
                          right: 24,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () async {
                              // 💡 [수정 및 버그 해결] 한 달 예산 총액(total_budget)도 명시적으로 Firestore에 저장합니다.
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(currentUserId)
                                  .collection('budgets')
                                  .doc('total_budget')
                                  .set({
                                    'amount': totalBudget,
                                  }, SetOptions(merge: true));

                              // 카테고리별 예산 일괄 업로드
                              for (var cat in categories) {
                                String clean = categoryControllers[cat['name']]!
                                    .text
                                    .replaceAll(',', '')
                                    .replaceAll('원', '')
                                    .trim();
                                int parsedAmt = int.tryParse(clean) ?? 0;

                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(currentUserId)
                                    .collection('budgets')
                                    .doc(cat['name'])
                                    .set({
                                      'amount': parsedAmt,
                                    }, SetOptions(merge: true));
                              }

                              onSave(totalBudget); // 부모 State 변경 및 상위 위젯 데이터 전달
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "완료",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AmountFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final int? value = int.tryParse(newValue.text.replaceAll(',', ''));
    if (value == null) return oldValue;
    final String newText = NumberFormat('#,###').format(value);
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
