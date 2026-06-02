import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rekeep/calendar_seeder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rekeep/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:flutter_rekeep/premium_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingAsset extends StatefulWidget {
  final bool isPreview;
  const SettingAsset({super.key, this.isPreview = false});

  @override
  State<SettingAsset> createState() => _SettingAssetState();
}

class _SettingAssetState extends State<SettingAsset> {
  final NumberFormat formatter = NumberFormat('#,###');
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  int startingAsset = 0;
  int targetAsset = 0;
  int budget = 0;
  bool isLoading = true;
  Key _recurringFutureKey = UniqueKey();
  Key _recurringListKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    if (widget.isPreview) {
      // 미리보기: Firestore 로드 없이 예시값만 표시
      budget = 1000000;
      lastMonthExpense = 850000;
      isLoading = false;
      return;
    }
    _loadAssetData();
    _loadExpenseData();
    _checkMonthlyReset();
  }

  int lastMonthExpense = 0;

  Future<void> _loadExpenseData() async {
    if (currentUserId == null) return;

    DateTime now = DateTime.now();
    DateTime firstDayOfLastMonth = DateTime(now.year, now.month - 1, 1);
    DateTime lastDayOfLastMonth = DateTime(
      now.year,
      now.month,
      0,
      23,
      59,
      59,
    );

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('records')
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfLastMonth),
        )
        .where(
          'date',
          isLessThanOrEqualTo: Timestamp.fromDate(lastDayOfLastMonth),
        )
        .where('type', isEqualTo: '지출')
        .get();

    int total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.get('amount') as num).toInt();
    }

    setState(() {
      lastMonthExpense = total;
      isLoading = false;
    });
  }

  Future<void> _loadAssetData() async {
    if (currentUserId == null) return;
    try {
      final assetDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('assets')
          .doc('management')
          .get();

      final budgetDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('budgets')
          .doc('total_budget')
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

  Future<List<String>> _loadCustomItems(String type) async {
    if (!widget.isPreview) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('settings')
          .doc('${type}_items')
          .get();

      if (doc.exists) {
        return List<String>.from(doc.data()?['list'] ?? []);
      }
    }
    if (type == "고정지출") {
      return [
        "관리비",
        "통신비",
        "주거비",
        "인터넷비",
        "연금",
        "세금",
        "구독료",
        "자기계발",
        "보험료",
        "모임비",
      ];
    } else {
      return ["공과금", "교통비", "차량유지비", "의료비", "데이트"];
    }
  }

  Future<void> _saveCustomItems(String type, List<String> items) async {
    if (widget.isPreview) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('settings')
        .doc('${type}_items')
        .set({'list': items});
  }

  Future<void> _updateAssetData(String field, int value) async {
    if (widget.isPreview) return;
    if (currentUserId == null) return;
    try {
      if (field == 'budget') {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('budgets')
            .doc('total_budget')
            .set({'amount': value}, SetOptions(merge: true));
      } else {
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

  Future<void> _checkMonthlyReset() async {
    if (currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastResetMonth = prefs.getString('last_reset_month') ?? '';
    final thisMonth = '${now.year}-${now.month}';

    if (now.day == 1 && lastResetMonth != thisMonth) {
      await prefs.setString('last_reset_month', thisMonth);
      _showMonthlyResetDialog();
    }
  }

  void _showMonthlyResetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "자산 설정",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close),
            ),
          ],
        ),
        content: const Text(
          "지난달과 동일하게 설정하시겠습니까?",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resetAllForNewMonth();
            },
            child: Text(
              "취소",
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _copyLastMonthSettings();
            },
            child: Text(
              "확인",
              style: TextStyle(
                color: AppColors.primary(context),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyLastMonthSettings() async {
    if (currentUserId == null) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("저번달 설정이 이번달에도 적용됩니다.")),
      );
    }
  }

  Future<void> _resetAllForNewMonth() async {
    if (currentUserId == null) return;
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId);

    final budgetSnapshot = await userRef.collection('budgets').get();
    for (var doc in budgetSnapshot.docs) {
      await doc.reference.update({'amount': 0});
    }

    final recurringSnapshot = await userRef
        .collection('recurring_expenses')
        .get();
    for (var doc in recurringSnapshot.docs) {
      await doc.reference.delete();
    }

    await userRef.collection('settings').doc('고정지출_items').delete();
    await userRef.collection('settings').doc('변동지출_items').delete();

    setState(() {
      budget = 0;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("새달 설정이 초기화되었습니다.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary(context)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          "자산 설정",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
      body: Column(
        children: [
          if (widget.isPreview)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              color: AppColors.primary(context).withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "미리보기 페이지입니다",
                    style: TextStyle(
                      color: AppColors.primary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => PremiumGate.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary(context),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        "프리미엄 시작하기",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ListView(
                children: [
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
                    "관리비, 통신비 등",
                    () => _showRecurringExpenseSheet("고정지출"),
                  ),
                  _buildAssetItem(
                    "변동지출",
                    "공과금, 교통비 등",
                    () => _showRecurringExpenseSheet("변동지출"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetItem(
    String title,
    String trailingText,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            trailingText,
            style: const TextStyle(fontSize: 14, color: AppColors.secondary),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.secondary),
        ],
      ),
      onTap: onTap,
    );
  }

  /// 미리보기용 고정/변동지출 예시 데이터
  Map<String, Map<String, dynamic>> _previewExpenseData(String type) {
    if (type == "고정지출") {
      return {
        "관리비": {"name": "관리비", "amount": 120000, "period": "매월", "day": "5일"},
        "통신비": {"name": "통신비", "amount": 55000, "period": "매월", "day": "15일"},
        "구독료": {"name": "구독료", "amount": 13900, "period": "매월", "day": "1일"},
        "보험료": {"name": "보험료", "amount": 88000, "period": "매월", "day": "25일"},
      };
    } else {
      return {
        "공과금": {"name": "공과금", "amount": 60000, "period": "매월", "day": "10일"},
        "교통비": {"name": "교통비", "amount": 70000, "period": "매월", "day": "1일"},
        "데이트": {"name": "데이트", "amount": 50000, "period": "매주", "day": "토요일"},
      };
    }
  }

  void _showRecurringExpenseSheet(String type) {
    // 목록은 FutureBuilder(_loadCustomItems)에서 받아 _sheetItems로 관리
    List<String>? sheetItems;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background(context),

      builder: (context) {
        return StatefulBuilder(
          builder: (context, setOuterState) {
            // ✅ 바깥 setter
            return FutureBuilder<List<String>>(
              key: _recurringFutureKey,
              future: _loadCustomItems(type),
              builder: (context, listSnapshot) {
                // 로딩 중에는 스피너 (아직 sheetItems 미초기화)
                if (listSnapshot.connectionState == ConnectionState.waiting &&
                    sheetItems == null) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                // 데이터가 도착하면 최초 1회만 mutable 리스트로 보관
                if (sheetItems == null && listSnapshot.hasData) {
                  sheetItems = List<String>.from(listSnapshot.data!);
                }
                // 혹시라도 비어있으면 안전장치로 빈 리스트
                sheetItems ??= <String>[];
                final List<String> items = sheetItems!;
                return StatefulBuilder(
                  builder: (context, setModalState) {
                    return Material(
                      color: AppColors.background(context),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(25),
                      ),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: FutureBuilder<QuerySnapshot>(
                          key: _recurringListKey,
                          future: widget.isPreview
                              ? null
                              : FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(currentUserId)
                                    .collection('recurring_expenses')
                                    .where('expenseType', isEqualTo: type)
                                    .get(),
                          builder: (context, snapshot) {
                            final Map<String, Map<String, dynamic>>
                            expenseData = {};
                            if (widget.isPreview) {
                              expenseData.addAll(_previewExpenseData(type));
                            } else if (snapshot.hasData) {
                              for (var doc in snapshot.data!.docs) {
                                expenseData[doc.id] =
                                    doc.data() as Map<String, dynamic>;
                              }
                            }
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 24,
                                    right: 24,
                                    top: 24,
                                    bottom: 20,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "$type 관리",
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.refresh,
                                              size: 20,
                                            ),
                                            onPressed: () => _resetToDefault(
                                              type,
                                              setOuterState, // ✅ 바깥 setter 전달
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => Navigator.pop(context),
                                            child: const Icon(Icons.close),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    itemCount: items.length + 1,
                                    itemBuilder: (context, index) {
                                      if (index == items.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    10,
                                                  ),
                                              border: Border.all(
                                                color: AppColors.divider(
                                                  context,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: ListTile(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      10,
                                                    ),
                                              ),

                                              leading: const Icon(
                                                Icons.add,
                                                color: AppColors.secondary,
                                              ),
                                              title: const Text(
                                                "항목 추가하기",
                                                style: TextStyle(
                                                  color: AppColors.secondary,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              onTap: () async {
                                                final newName =
                                                    await _showAddItemDialog(
                                                      context,
                                                    );
                                                if (newName != null &&
                                                    newName.isNotEmpty) {
                                                  setModalState(() {
                                                    items.add(newName);
                                                  });
                                                  await _saveCustomItems(
                                                    type,
                                                    items,
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        );
                                      }

                                      final itemName = items[index];
                                      final data = expenseData[itemName];
                                      final int amount = data?['amount'] ?? 0;
                                      final String period =
                                          data?['period'] ?? "매월";
                                      final String day = data?['day'] ?? "1일";
                                      bool isSet = amount > 0;

                                      return Dismissible(
                                        key: Key(itemName),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.pointColor,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.delete,
                                            color: AppColors.background(
                                              context,
                                            ),
                                          ),
                                        ),
                                        onDismissed: (direction) async {
                                          setModalState(() {
                                            items.remove(itemName);
                                          });
                                          await _saveCustomItems(type, items);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      10,
                                                    ),
                                                border: Border.all(
                                                  color: AppColors.divider(
                                                    context,
                                                  ),
                                                  width: 1,
                                                ),
                                              ),
                                              child: ListTile(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),

                                                title: Text(itemName),
                                                trailing: isSet
                                                    ? Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .end,
                                                        children: [
                                                          Text(
                                                            "${formatter.format(amount)}원",
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  AppColors.primary(
                                                                    context,
                                                                  ),
                                                              fontSize: 15,
                                                              height: 1.2,
                                                            ),
                                                          ),
                                                          Text(
                                                            "$period · $day",
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              color: AppColors
                                                                  .secondary,
                                                              height: 1.2,
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    : Icon(
                                                        Icons
                                                            .add_circle_outline,
                                                        color:
                                                            AppColors.primary(
                                                              context,
                                                            ),
                                                      ),
                                                onTap: () {
                                                  _showDetailConfigSheet(
                                                    itemName,
                                                    amount,
                                                    period,
                                                    day,
                                                    type,
                                                    onSaved: () {
                                                      setState(() {
                                                        _recurringListKey =
                                                            UniqueKey();
                                                      });
                                                      setModalState(() {});
                                                    },
                                                    initialCardName:
                                                        data?['cardName'] ?? '',
                                                    initialCardBankName:
                                                        data?['bankName'] ?? '',
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // const SizedBox(height: 30),

                                // Padding(
                                //   padding: const EdgeInsets.symmetric(
                                //     horizontal: 24.0,
                                //   ),
                                //   child: ElevatedButton(
                                //     onPressed: () => _showMonthlyResetDialog(),
                                //     style: ElevatedButton.styleFrom(
                                //       backgroundColor: AppColors.secondary,
                                //     ),
                                //     child: const Text(
                                //       "월 초기화 다이얼로그 테스트",
                                //       style: TextStyle(color: Colors.white),
                                //     ),
                                //   ),
                                // ),
                                const SizedBox(height: 30),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _resetToDefault(String type, StateSetter setOuterState) async {
    if (widget.isPreview) return;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background(context),
        title: const Text(
          "지출 초기화",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: const Text(
          "정말 모든 항목을\n0원으로 초기화하시겠습니까?",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "취소",
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "확인",
              style: TextStyle(
                color: AppColors.primary(context),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('settings')
          .doc('${type}_items')
          .get();
      final itemNames = List<String>.from(settingsDoc.data()?['list'] ?? []);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('settings')
          .doc('${type}_items')
          .delete();

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('recurring_expenses')
          .get();

      for (var doc in snapshot.docs) {
        final docType = doc.data()['expenseType'];
        final docName = doc.data()['name'] ?? doc.id;
        if (docType == type ||
            (docType == null && itemNames.contains(docName))) {
          await doc.reference.delete();
        }
      }

      setState(() {
        _recurringFutureKey = UniqueKey();
        _recurringListKey = UniqueKey(); // ✅ 추가
      });
      setOuterState(() {});
    }
  }

  Future<String?> _showAddItemDialog(BuildContext context) {
    TextEditingController nameController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background(context),
        title: const Text(
          "항목 추가",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "항목 이름을 입력하세요",
            hintStyle: const TextStyle(
              color: AppColors.secondary,
              fontSize: 15,
            ),
            filled: true,
            fillColor: AppColors.divider(
              context,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "취소",
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: Text(
              "추가",
              style: TextStyle(
                color: AppColors.primary(context),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailConfigSheet(
    String itemName,
    int initialAmount,
    String initialPeriod,
    String initialDay,
    String expenseType, {
    required VoidCallback onSaved,
    String initialCardName = '',
    String initialCardBankName = '',
  }) {
    final TextEditingController amountController = TextEditingController(
      text: initialAmount > 0 ? formatter.format(initialAmount) : "",
    );

    amountController.addListener(() {
      String text = amountController.text
          .replaceAll(',', '')
          .replaceAll('원', '')
          .trim();
      if (text.isEmpty) return;

      double? value = double.tryParse(text);
      if (value != null) {
        String newText = formatter.format(value);

        if (newText != amountController.text) {
          amountController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
        }
      }
    });

    String selectedPeriod = initialPeriod.isEmpty ? "매월" : initialPeriod;
    String selectedDayOrDayOfWeek = initialDay.isEmpty ? "1일" : initialDay;
    String selectedCardName = initialCardName;
    String selectedCardBankName = initialCardBankName;

    final List<String> periods = ["매월", "매주", "매일"];
    final Map<String, List<String>> periodOptions = {
      "매월": List.generate(31, (i) => "${i + 1}일"),
      "매주": ["월요일", "화요일", "수요일", "목요일", "금요일", "토요일", "일요일"],
      "매일": ["매일"],
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$itemName 설정",
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

              Row(
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text(
                      "주기 선택",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Material(
                      color: AppColors.divider(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: InkWell(
                          onTap: () async {
                            int currentDay =
                                int.tryParse(
                                  selectedDayOrDayOfWeek.replaceAll(
                                    RegExp(r'[^0-9]'),
                                    '',
                                  ),
                                ) ??
                                1;

                            final result = await _showPeriodPickerSheet(
                              selectedPeriod,
                              currentDay,
                            );

                            if (result != null) {
                              setModalState(() {
                                selectedPeriod = result['period'];
                                selectedDayOrDayOfWeek =
                                    "${result['day']}${selectedPeriod == "매월" ? "" : (selectedPeriod == "매주" ? "" : "")}";
                              });
                            }
                          },
                          child: SizedBox(
                            height: 55,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "$selectedPeriod · $selectedDayOrDayOfWeek",
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    size: 20,
                                    color: AppColors.secondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              Row(
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text(
                      "금액",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: "금액 입력",
                          filled: true,
                          fillColor: AppColors.divider(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text(
                      "카드 선택",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUserId)
                            .collection('my_cards')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Container(
                              height: 55,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.divider(context),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.centerLeft,
                              child: const Text(
                                "등록된 카드 없음",
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 15,
                                ),
                              ),
                            );
                          }

                          final cards = snapshot.data!.docs;
                          final cardItems = [
                            {'cardName': '없음', 'bankName': ''},
                            ...cards.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return {
                                'cardName': data['cardName'] ?? '',
                                'bankName': data['bankName'] ?? '',
                              };
                            }),
                          ];

                          return DropdownButtonFormField<String>(
                            menuMaxHeight: 200,
                            dropdownColor: AppColors.background(context),
                            borderRadius: BorderRadius.circular(10),
                            isExpanded: true,

                            value: selectedCardName.isEmpty
                                ? '없음'
                                : selectedCardName,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.divider(context),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                            ),
                            items: cardItems.map((card) {
                              return DropdownMenuItem<String>(
                                value: card['cardName'],
                                child: Text(
                                  card['cardName']!,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setModalState(() {
                                selectedCardName = value ?? '';
                                selectedCardBankName =
                                    cardItems.firstWhere(
                                      (c) => c['cardName'] == value,
                                      orElse: () => {'bankName': ''},
                                    )['bankName'] ??
                                    '';
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    String cleanText = amountController.text
                        .replaceAll(',', '')
                        .trim();
                    int parsedAmount = int.tryParse(cleanText) ?? 0;

                    if (!widget.isPreview && currentUserId != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUserId)
                          .collection('recurring_expenses')
                          .doc(itemName)
                          .set({
                            'name': itemName,
                            'amount': parsedAmount,
                            'period': selectedPeriod,
                            'day': selectedDayOrDayOfWeek,
                            'expenseType': expenseType,
                            'cardName': selectedCardName == '없음'
                                ? ''
                                : selectedCardName,
                            'bankName': selectedCardBankName,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                      // ✅ 저장 후 알림 재스케줄
                      final prefs = await SharedPreferences.getInstance();
                      final isEnabled =
                          prefs.getBool('is_fixed_expense_enabled') ?? false;

                      if (isEnabled) {
                        final snapshot = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUserId)
                            .collection('recurring_expenses')
                            .get();

                        final items = snapshot.docs
                            .map((doc) => doc.data() as Map<String, dynamic>)
                            .toList();

                        await NotificationService()
                            .scheduleFixedExpenseReminders(items);
                      }
                    }

                    Navigator.pop(context);
                    onSaved();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "저장",
                    style: TextStyle(
                      color: AppColors.background(context),
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
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showPeriodPickerSheet(
    String currentP,
    int currentD,
  ) async {
    final List<String> periods = ["매월", "매주", "매일"];
    final Map<String, List<String>> periodOptions = {
      "매월": List.generate(31, (i) => "${i + 1}일"),
      "매주": ["월요일", "화요일", "수요일", "목요일", "금요일", "토요일", "일요일"],
      "매일": ["매일"],
    };

    String tempPeriod = currentP;
    String tempDay = (currentP == "매월"
        ? "$currentD일"
        : (currentP == "매주" ? "월요일" : "매일"));

    return await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: 300,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController: FixedExtentScrollController(
                          initialItem: periods.indexOf(tempPeriod),
                        ),
                        onSelectedItemChanged: (i) {
                          setModalState(() {
                            tempPeriod = periods[i];
                            tempDay = periodOptions[tempPeriod]!.first;
                          });
                        },
                        children: periods
                            .map((p) => Center(child: Text(p)))
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        key: ValueKey(
                          tempPeriod,
                        ),
                        itemExtent: 40,
                        onSelectedItemChanged: (i) =>
                            tempDay = periodOptions[tempPeriod]![i],
                        children: periodOptions[tempPeriod]!
                            .map((item) => Center(child: Text(item)))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 15,
              ),
              SizedBox(
                height: 55,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context, {
                    'period': tempPeriod,
                    'day': tempDay,
                  }),
                  child: Text(
                    "확인",
                    style: TextStyle(
                      color: AppColors.background(context),
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
        ),
      ),
    );
  }

  Widget _buildFullDivider() => Column(
    children: [
      Container(
        height: 8,
        width: double.infinity,
        color: AppColors.divider(context),
      ),
    ],
  );

  Future<void> _resetBudget(
    Function(int) onSave,
    StateSetter setSheetState,
    TextEditingController totalBudgetController,
    Map<String, TextEditingController> categoryControllers,
  ) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background(context),
        title: const Text(
          "예산 설정 초기화",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: const Text(
          "정말 모든 항목을\n0원으로 초기화하시겠습니까?",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "취소",
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "확인",
              style: TextStyle(
                color: AppColors.primary(context),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final firestore = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId);

      await firestore.collection('budgets').doc('total_budget').set({
        'amount': 0,
      }, SetOptions(merge: true));

      final catSnapshot = await firestore.collection('budgets').get();
      for (var doc in catSnapshot.docs) {
        await doc.reference.set({'amount': 0}, SetOptions(merge: true));
      }

      setSheetState(() {
        totalBudgetController.text = '';
        for (var ctrl in categoryControllers.values) {
          ctrl.text = '';
        }
      });

      onSave(0);
    }
  }

  Future<void> _saveBudget(
    TextEditingController totalBudgetController,
    Map<String, TextEditingController> categoryControllers,
    List<Map<String, dynamic>> categories,
    Function(int) onSave,
    StateSetter setSheetState, // ✅ 추가
  ) async {
    // ✅ 먼저 값 읽기
    String rawTotal = totalBudgetController.text
        .replaceAll(',', '')
        .replaceAll('원', '')
        .trim();
    int totalBudget = int.tryParse(rawTotal) ?? 0;

    Map<String, int> catAmounts = {};
    for (var cat in categories) {
      final controller = categoryControllers[cat['name']];
      if (controller == null) continue;
      String clean = controller.text
          .replaceAll(',', '')
          .replaceAll('원', '')
          .trim();
      catAmounts[cat['name']] = int.tryParse(clean) ?? 0;
    }

    // ✅ 미리보기는 저장하지 않고 닫기만
    if (widget.isPreview) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // ✅ 값 다 읽은 후 바로 닫기 (리스너 발동 전에)
    onSave(totalBudget);

    // ✅ 바텀시트 닫힌 후 Firestore 저장 (리스너 걱정 없음)
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('budgets')
        .doc('total_budget')
        .set({'amount': totalBudget}, SetOptions(merge: true));

    for (var entry in catAmounts.entries) {
      final safeKey = entry.key.replaceAll('/', '_');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('budgets')
          .doc(safeKey)
          .set({'amount': entry.value}, SetOptions(merge: true));
    }
  }

  Future<void> _showBudgetSheet(int currentBudget, Function(int) onSave) async {
    // 카테고리가 없으면 기본 카테고리 자동 생성 후 바텀시트 열기
    if (!widget.isPreview && currentUserId != null) {
      await seedDefaultCategoriesIfEmpty(currentUserId!);
    }

    final TextEditingController totalBudgetController = TextEditingController(
      text: currentBudget > 0 ? "${formatter.format(currentBudget)}원" : "",
    );

    final List<Map<String, dynamic>> categories = [];
    final Map<String, TextEditingController> categoryControllers = {};

    // 바텀시트 열기 전에 데이터 미리 로드
    if (widget.isPreview) {
      final previewCategories = [
        {'name': '식비', 'icon': '🍚', 'budget': 300000},
        {'name': '교통', 'icon': '🚌', 'budget': 100000},
        {'name': '쇼핑', 'icon': '🛍️', 'budget': 200000},
        {'name': '문화생활', 'icon': '🎬', 'budget': 150000},
        {'name': '카페/간식', 'icon': '☕', 'budget': 80000},
      ];
      for (var c in previewCategories) {
        final name = c['name'] as String;
        categories.add({
          'name': name,
          'icon': c['icon'],
          'budget': c['budget'],
        });
        categoryControllers[name] = TextEditingController(
          text: "${formatter.format(c['budget'])}원",
        );
      }
    } else if (currentUserId != null) {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId!)
            .collection('categories')
            .where('type', isEqualTo: '지출')
            .orderBy('index')
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId!)
            .collection('budgets')
            .get(),
      ]);
      final catDocs = results[0].docs;
      final budgetDocs = results[1].docs;

      for (var doc in catDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] as String;
        categories.add({
          'name': name,
          'icon': data['icon'] ?? '✨',
          'budget': 0,
        });
        categoryControllers[name] = TextEditingController();
      }
      for (var doc in budgetDocs) {
        final cName = doc.id;
        if (cName == 'total_budget') continue;
        final displayName = cName.replaceAll('_', '/');
        final amt = (doc.data() as Map<String, dynamic>)['amount'] ?? 0;
        final idx = categories.indexWhere((c) => c['name'] == displayName);
        if (idx != -1 && amt > 0) {
          categories[idx]['budget'] = amt;
          categoryControllers[displayName]?.text = "${formatter.format(amt)}원";
        }
      }
    }

    if (!mounted) return;

    Key _listKey = UniqueKey();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (sheetCtx, setModalState) {
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
                final controller = categoryControllers[cat['name']];
                if (controller == null) continue;
                String txt = controller.text
                    .replaceAll(',', '')
                    .replaceAll('원', '')
                    .trim();
                total += int.tryParse(txt) ?? 0;
              }
              return total;
            }

            int totalBudget = getTotalBudget();
            int categoryTotal = getCategoryTotal();
            int remaining = totalBudget - categoryTotal;

            return Container(
              decoration: BoxDecoration(
                color: AppColors.background(sheetCtx),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
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
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              onPressed: () => _resetBudget(
                                onSave,
                                setModalState,
                                totalBudgetController,
                                categoryControllers,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(sheetCtx),
                              child: const Icon(Icons.close),
                            ),
                          ],
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
                                fontSize: 12,
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
                              onChanged: (_) => setModalState(() {}),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary(context),
                              ),
                              decoration: const InputDecoration(
                                hintText: "0원",
                                hintStyle: TextStyle(
                                  fontSize: 22,
                                  color: AppColors.secondary,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 0,
                                ),
                              ),
                              inputFormatters: [
                                _AmountFormatter(),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "지난달 지출",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "${formatter.format(lastMonthExpense)}원",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          _buildFullDivider(),
                          const SizedBox(height: 30),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                        ? AppColors.primary(context)
                                        : AppColors.pointColor,
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
                                        backgroundColor: AppColors.divider(
                                          context,
                                        ),
                                        child: Text(
                                          cat['icon'],
                                          style: const TextStyle(
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          cat['name'],
                                          style: const TextStyle(
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: SizedBox(
                                          height: 40,
                                          child: TextField(
                                            controller: controller,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.end,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: "0원",
                                              hintStyle: const TextStyle(
                                                fontSize: 15,
                                                color: AppColors.secondary,
                                                fontWeight: FontWeight.normal,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 4,
                                                  ),
                                              enabledBorder:
                                                  UnderlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: AppColors.divider(
                                                        context,
                                                      ),
                                                    ),
                                                  ),
                                              focusedBorder:
                                                  UnderlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: AppColors.primary(
                                                        context,
                                                      ),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                            ),
                                            inputFormatters: [
                                              _AmountFormatter(),
                                            ],
                                            onChanged: (val) {
                                              String clean = val
                                                  .replaceAll(',', '')
                                                  .replaceAll('원', '')
                                                  .trim();
                                              if (clean.isEmpty) {
                                                categories[index]['budget'] = 0;
                                                return;
                                              }
                                              double? value = double.tryParse(
                                                clean,
                                              );
                                              if (value != null) {
                                                categories[index]['budget'] =
                                                    value.toInt();
                                                String formatted =
                                                    "${formatter.format(value.toInt())}원";
                                                if (controller != null &&
                                                    controller.text !=
                                                        formatted) {
                                                  controller.text = formatted;
                                                  controller.selection =
                                                      TextSelection.collapsed(
                                                        offset:
                                                            formatted.length,
                                                      );
                                                }
                                              }
                                              setModalState(() {});
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
                          const SizedBox(height: 0),
                        ],
                      ),
                    ),
                  ),

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
                          if (widget.isPreview) {
                            Navigator.of(context).pop();
                            return;
                          }
                          String rawTotal = totalBudgetController.text
                              .replaceAll(',', '')
                              .replaceAll('원', '')
                              .trim();
                          int totalBudget = int.tryParse(rawTotal) ?? 0;

                          Map<String, int> catAmounts = {};
                          for (var cat in categories) {
                            final ctrl = categoryControllers[cat['name']];
                            if (ctrl == null) continue;
                            String clean = ctrl.text
                                .replaceAll(',', '')
                                .replaceAll('원', '')
                                .trim();
                            catAmounts[cat['name']] = int.tryParse(clean) ?? 0;
                          }

                          // ✅ 바텀시트 닫지 않고 저장
                          onSave(totalBudget);

                          if (currentUserId != null) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUserId)
                                .collection('budgets')
                                .doc('total_budget')
                                .set({
                                  'amount': totalBudget,
                                }, SetOptions(merge: true));

                            for (var entry in catAmounts.entries) {
                              final safeKey = entry.key.replaceAll(
                                '/',
                                '_',
                              );
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(currentUserId)
                                  .collection('budgets')
                                  .doc(safeKey)
                                  .set({
                                    'amount': entry.value,
                                  }, SetOptions(merge: true));
                            }
                          }

                          // ✅ 저장 완료 스낵바
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("예산이 저장되었습니다.")),
                            );
                          }
                        },

                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "저장",
                          style: TextStyle(
                            color: AppColors.background(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
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
    // 숫자만 추출
    final String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // 숫자가 없으면(전부 지웠으면) 빈 값 허용
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final int? value = int.tryParse(digitsOnly);
    if (value == null) return oldValue;

    final String newText = '${NumberFormat('#,###').format(value)}원';
    // 커서는 '원' 바로 앞에 위치
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length - 1),
    );
  }
}
