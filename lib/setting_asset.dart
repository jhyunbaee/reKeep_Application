import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
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

  Future<List<String>> _loadCustomItems(String type) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('settings')
        .doc('${type}_items')
        .get();

    if (doc.exists) {
      return List<String>.from(doc.data()?['list'] ?? []);
    } else {
      // 💡 실제 항목을 모두 나열하세요
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
  }

  Future<void> _saveCustomItems(String type, List<String> items) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('settings')
        .doc('${type}_items')
        .set({'list': items});
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
                  // _showAssetSheet 함수 내부
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
                      Row(
                        // 💡 Row로 감싸서 버튼 2개를 나란히 배치
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            onPressed: () async {
                              // 1. 확인창 띄우기
                              bool? confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(
                                    "$title 초기화",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  content: const Text("정말 0원으로 초기화하시겠습니까?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text(
                                        "취소",
                                        style: TextStyle(
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text(
                                        "확인",
                                        style: TextStyle(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              // 2. 확인 시 로직 실행
                              if (confirm == true) {
                                onSave(0);
                                Navigator.pop(context); // 바텀시트 닫기
                              }
                            },
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close),
                          ),
                        ],
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

  void _showRecurringExpenseSheet(String type) {
    Key listKey = UniqueKey();

    final List<String> items = type == "고정지출"
        ? ["관리비", "통신비", "주거비", "인터넷비", "연금", "세금", "구독료", "자기계발", "보험료", "모임비"]
        : ["공과금", "교통비", "차량유지비", "의료비", "데이트"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,

      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return FutureBuilder<List<String>>(
            future: _loadCustomItems(type),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              List<String> items = snapshot.data!; // DB에서 불러온 리스트
              // 2. 바텀시트 전체를 StatefulBuilder로 감싸세요!
              return StatefulBuilder(
                builder: (context, setModalState) {
                  return Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(25),
                      ),
                    ), // 데이터 로드
                    child: FutureBuilder<QuerySnapshot>(
                      key: listKey, // 💡 여기서 listKey를 사용
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUserId)
                          .collection('recurring_expenses')
                          .get(),
                      builder: (context, snapshot) {
                        final Map<String, Map<String, dynamic>> expenseData =
                            {};
                        if (snapshot.hasData) {
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
                                    // 💡 버튼들을 담을 Row 추가
                                    children: [
                                      // 초기화 버튼
                                      IconButton(
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 20,
                                        ),
                                        onPressed: () => _resetToDefault(
                                          type,
                                          setModalState,
                                        ), // 💡 아래 함수 호출
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: AppColors.borderColor,
                                            width: 1,
                                          ),
                                        ),
                                        child: ListTile(
                                          leading: const Icon(
                                            Icons.add,
                                            color: AppColors.secondary,
                                          ),
                                          title: const Text(
                                            "항목 추가하기",
                                            style: TextStyle(
                                              color: AppColors.secondary,
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
                                              // 💡 2번 로직: UI 변경 후 즉시 DB에 저장
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
                                  final String period = data?['period'] ?? "매월";
                                  final String day = data?['day'] ?? "1일";
                                  bool isSet = amount > 0;

                                  return Dismissible(
                                    key: Key(itemName), // 고유한 키
                                    direction: DismissDirection
                                        .endToStart, // 왼쪽으로 밀 때 삭제
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(
                                          10,
                                        ), // Container와 둥근 모서리 맞춤
                                      ),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onDismissed: (direction) async {
                                      String itemName = items[index];

                                      // 1. UI 반영
                                      setModalState(() {
                                        items.removeAt(index);
                                      });

                                      // 💡 2번 로직: UI 변경 후 즉시 DB에 저장
                                      await _saveCustomItems(type, items);

                                      // (선택) 상세 데이터도 지우려면 여기서 delete() 호출
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ), // 여기야?
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: AppColors.borderColor,
                                            width: 1,
                                          ),
                                        ),
                                        child: ListTile(
                                          title: Text(itemName),
                                          trailing: isSet
                                              ? Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .center, // 세로 중앙 정렬
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .end, // 오른쪽 정렬
                                                  children: [
                                                    // 금액
                                                    Text(
                                                      "${formatter.format(amount)}원",
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppColors.primary,
                                                        fontSize: 15,
                                                        height: 1.2,
                                                      ),
                                                    ),
                                                    // 주기 (period와 day를 합쳐서 표시)
                                                    Text(
                                                      "$period · $day",
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            AppColors.secondary,
                                                        height: 1.2,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : const Icon(
                                                  Icons.add_circle_outline,
                                                  color: AppColors.primary,
                                                ),
                                          onTap: () async {
                                            // 💡 설정 창에서 수정 후 돌아왔을 때 새로고침을 위해 await 추가
                                            _showDetailConfigSheet(
                                              itemName,
                                              amount,
                                              period,
                                              day,
                                            );

                                            // 상세창 닫힌 후 데이터 새로고침
                                            setModalState(() {
                                              // FutureBuilder를 재실행하기 위해 키를 갱신
                                              // (이 코드가 작동하려면 _listKey가 StatefulBuilder 범위 내에 있어야 합니다)
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _resetAllData() async {
    // 1. 확인 팝업
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "전체 초기화",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text("정말 모든 항목을\n0원으로 초기화하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("확인"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (currentUserId == null) return;

      // 2. 각 컬렉션별 데이터 삭제
      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection('users').doc(currentUserId);

      // 자산 삭제
      await userRef.collection('assets').doc('management').delete();

      // 예산 삭제 (total_budget 및 카테고리별)
      final budgetSnapshot = await userRef.collection('budgets').get();
      for (var doc in budgetSnapshot.docs) await doc.reference.delete();

      // 고정/변동지출 리스트 설정 삭제
      await userRef.collection('settings').doc('고정지출_items').delete();
      await userRef.collection('settings').doc('변동지출_items').delete();

      // 상세 지출 데이터 삭제
      final expenseSnapshot = await userRef
          .collection('recurring_expenses')
          .get();
      for (var doc in expenseSnapshot.docs) await doc.reference.delete();

      // 3. UI 갱신 (데이터 다시 로드)
      _loadAssetData();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("모든 데이터가 초기화되었습니다.")));
      }
    }
  }

  Future<void> _resetToDefault(String type, StateSetter setModalState) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "전체 초기화",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text("정말 모든 항목을\n0원으로 초기화하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "취소",
              style: TextStyle(color: AppColors.secondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "확인",
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 1. 리스트 설정 문서 삭제
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('settings')
          .doc('${type}_items')
          .delete();

      // 2. 💡 상세 데이터(금액, 주기) 모두 삭제 (이 부분이 빠져있던 핵심입니다!)
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('recurring_expenses')
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      // 3. 바텀시트 닫기 (새로고침이 까다로우니 닫아버리는 방식 적용)
      Navigator.pop(context);
    }
  }

  Future<String?> _showAddItemDialog(BuildContext context) {
    TextEditingController nameController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("항목 추가"),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "항목 이름을 입력하세요"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text("추가"),
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
  ) {
    final TextEditingController amountController = TextEditingController(
      text: initialAmount > 0 ? formatter.format(initialAmount) : "",
    );

    amountController.addListener(() {
      String text = amountController.text
          .replaceAll(',', '')
          .replaceAll('원', '')
          .trim();
      if (text.isEmpty) return;

      // 숫자로 변환 후 다시 포맷팅
      double? value = double.tryParse(text);
      if (value != null) {
        String newText = formatter.format(value); // int 포맷팅

        // 커서 위치가 꼬이지 않게 방지하면서 텍스트 업데이트
        if (newText != amountController.text) {
          amountController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
        }
      }
    });
    // 상태 변수들
    String selectedPeriod = initialPeriod.isEmpty ? "매월" : initialPeriod;
    String selectedDayOrDayOfWeek = initialDay.isEmpty ? "1일" : initialDay;

    final List<String> periods = ["매월", "매주", "매일"];
    final Map<String, List<String>> periodOptions = {
      "매월": List.generate(31, (i) => "${i + 1}일"),
      "매주": ["월요일", "화요일", "수요일", "목요일", "금요일", "토요일", "일요일"],
      "매일": ["매일"],
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    child: const Icon(Icons.close), // 순수 아이콘만 사용
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
                        fontSize: 15,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Material(
                      color: AppColors.fieldColor,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: InkWell(
                          // 💡 InkWell 사용으로 클릭 효과 제공
                          onTap: () async {
                            // String에서 숫자 부분만 추출하여 int로 변환 (예: "19일" -> 19)
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
                                // 결과를 받아와서 다시 String으로 저장
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
                                    "$selectedPeriod / $selectedDayOrDayOfWeek",
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    size: 20,
                                    color: Colors.grey,
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

              // 2. 금액 필드 (가로 배치)
              Row(
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text(
                      "금액",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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
                          fillColor: AppColors.fieldColor,
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
              ), // _showDetailConfigSheet 함수 내의 완료 버튼 부분
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    // 1. 텍스트 필드에서 금액 추출
                    String cleanText = amountController.text
                        .replaceAll(',', '')
                        .trim();
                    int parsedAmount = int.tryParse(cleanText) ?? 0;
                    // 2. Firestore에 데이터 저장 (핵심!)
                    if (currentUserId != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUserId)
                          .collection('recurring_expenses')
                          .doc(itemName) // 항목 이름을 문서ID로 사용
                          .set({
                            'amount': parsedAmount,
                            'period': selectedPeriod,
                            'day': selectedDayOrDayOfWeek,
                            'updatedAt':
                                FieldValue.serverTimestamp(), // 수정 시간 기록
                          }, SetOptions(merge: true));
                    }

                    // 3. 창 닫기
                    Navigator.pop(context); // 상세 설정창 닫기
                    Navigator.pop(context); // 고정/변동지출 관리 목록창 닫기
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "저장",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
        // 💡 StatefulBuilder 추가
        builder: (context, setModalState) => Container(
          height: 300,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // 왼쪽: 주기 선택
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 40,
                        scrollController: FixedExtentScrollController(
                          initialItem: periods.indexOf(tempPeriod),
                        ),
                        onSelectedItemChanged: (i) {
                          setModalState(() {
                            tempPeriod = periods[i];
                            tempDay = periodOptions[tempPeriod]!
                                .first; // 주기 변경 시 우측 초기값 설정
                          });
                        },
                        children: periods
                            .map((p) => Center(child: Text(p)))
                            .toList(),
                      ),
                    ),
                    // 오른쪽: 동적 선택 (주기에 따라 변경)
                    Expanded(
                      child: CupertinoPicker(
                        key: ValueKey(
                          tempPeriod,
                        ), // 💡 Key를 통해 주기 바뀔 때 Picker 갱신
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
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context, {
                    'period': tempPeriod,
                    'day': tempDay,
                  }),
                  child: const Text(
                    "확인",
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

    Key _listKey = UniqueKey();

    int lastMonthExpense = 845000;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<QuerySnapshot>(
          key: _listKey,
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
                        child: // _showBudgetSheet 함수 내부 헤더 Row
                        Row(
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
                                // _showBudgetSheet 함수 내부 초기화 IconButton
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 20),
                                  onPressed: () async {
                                    // 1. 확인 팝업 (선택 사항: 실수 방지)
                                    bool? confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text(
                                          "예산 초기화",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        content: const Text(
                                          "정말 모든 항목을\n0원으로 초기화하시겠습니까?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text("취소"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text(
                                              "확인",
                                              style: TextStyle(
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      // 2. Firestore에 0으로 저장 (DB 즉시 반영)
                                      final firestore = FirebaseFirestore
                                          .instance
                                          .collection('users')
                                          .doc(currentUserId);

                                      // 전체 예산 0으로
                                      await firestore
                                          .collection('budgets')
                                          .doc('total_budget')
                                          .set({
                                            'amount': 0,
                                          }, SetOptions(merge: true));

                                      // 각 카테고리별 예산 0으로
                                      for (var cat in categories) {
                                        await firestore
                                            .collection('budgets')
                                            .doc(cat['name'])
                                            .set({
                                              'amount': 0,
                                            }, SetOptions(merge: true));
                                      }

                                      // 3. UI 상태 갱신 (부모 위젯의 budget 변수도 0으로)
                                      onSave(0);

                                      // 4. 바텀시트 닫기
                                      Navigator.pop(context);
                                    }
                                  },
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
