import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rekeep/constants/card_data.dart'; // CardInfo 클래스가 포함된 파일
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:flutter_rekeep/constants/sized.dart';

class MyCard extends StatefulWidget {
  const MyCard({super.key});

  @override
  State<MyCard> createState() => _MyCardState();
}

class _MyCardState extends State<MyCard> {
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  bool isEditing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          "내 카드 관리",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() => isEditing = !isEditing),
                child: Text(
                  isEditing ? "완료" : "편집",
                  style: TextStyle(
                    color: isEditing ? AppColors.pointColor : AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('my_cards')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("등록된 카드가 없습니다."));
          }

          final cards = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: 30,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final cardData = cards[index].data() as Map<String, dynamic>;

              // 💡 수정된 부분: 리스트에서 해당 카드 객체를 찾음
              final cardInfo = CardData.allCards.firstWhere(
                (c) => c.cardName == cardData['cardName'],
                orElse: () => CardInfo(
                  bankName: cardData['bankName'] ?? "",
                  cardName: cardData['cardName'] ?? "",
                  cardType: cardData['cardType'] ?? "",
                  benefit: cardData['benefit'] ?? "",
                  imageUrl: "",
                ),
              );

              return InkWell(
                onTap: () =>
                    _showCardDetailSheet(context, cardData, cardInfo.imageUrl),
                borderRadius: BorderRadius.circular(10),
                child: Card(
                  color: Colors.white,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppColors.borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${cardData['bankName']} | ${cardData['cardType']}",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cardData['cardName'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cardData['benefit'] ?? "",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 40,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.fieldColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          clipBehavior: Clip.antiAlias,
                          // 💡 RotatedBox로 이미지를 90도 회전시킵니다.
                          child: cardInfo.imageUrl.isNotEmpty
                              ? RotatedBox(
                                  quarterTurns: 1, // 90도 회전 (2는 180도, 3은 270도)
                                  child: Image.network(
                                    cardInfo.imageUrl,
                                    fit: BoxFit.contain, // 자르지 않고 전체가 다 보이도록 설정
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.credit_card,
                                              color: Colors.grey,
                                            ),
                                  ),
                                )
                              : const Icon(
                                  Icons.credit_card,
                                  color: Colors.grey,
                                ),
                        ),
                        if (isEditing)
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle,
                              color: AppColors.pointColor,
                            ),
                            onPressed: () => _showDeleteConfirmDialog(
                              context,
                              cards[index].reference,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCardSheet(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showCardDetailSheet(
    BuildContext context,
    Map<String, dynamic> card,
    String? imageUrl,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 바
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 카드 정보 헤더
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 카드 이미지
                Container(
                  width: 60,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.fieldColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  // 💡 여기도 RotatedBox를 추가합니다.
                  child: imageUrl != null
                      ? RotatedBox(
                          quarterTurns: 1,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit
                                .contain, // 이미지가 꽉 차게 보이고 싶다면 BoxFit.cover로 변경 가능
                          ),
                        )
                      : const Icon(Icons.credit_card, color: Colors.grey),
                ),
                const SizedBox(width: 20),

                // 카드 이름 및 제조사
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card['bankName'] ?? "",
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card['cardName'] ?? "",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          card['cardType'] ?? "",
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            const Text(
              "주요 혜택",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 혜택 상세 내용 박스
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.fieldColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                card['benefit'] ?? "등록된 혜택 정보가 없습니다.",
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // 닫기 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
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
          ],
        ),
      ),
    );
  }

  void _showAddCardSheet(BuildContext context) {
    final TextEditingController benefitController = TextEditingController();
    List<String> bankList = CardData.allCards
        .map((c) => c.bankName)
        .toSet()
        .toList();
    String selectedBank = bankList.isNotEmpty ? bankList[0] : "신한카드";
    String selectedType = "체크카드";
    String? selectedName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 키보드 대응
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          List<String> availableNames = CardData.allCards
              .where(
                (c) => c.bankName == selectedBank && c.cardType == selectedType,
              )
              .map((c) => c.cardName)
              .toList();

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 30, // 키보드 위 여백
              left: 24,
              right: 24,
              top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 상단 핸들 바 (디자인 포인트)
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "새 카드 등록",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // 2. 카드사 선택 (입력창 스타일 적용)
                _buildHorizontalRow(
                  label: "카드사",
                  content: _buildFieldContainer(
                    DropdownButton<String>(
                      value: selectedBank,
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.secondary,
                      ),
                      items: bankList
                          .map(
                            (bank) => DropdownMenuItem(
                              value: bank,
                              child: Text(bank),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setModalState(() {
                        selectedBank = val!;
                        selectedName = null;
                        benefitController.clear();
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. 카드 종류 (ChoiceChip 스타일)
                _buildHorizontalRow(
                  label: "종류",
                  content: Row(
                    children: ["체크카드", "신용카드"]
                        .map(
                          (type) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(type),
                              selected: selectedType == type,
                              showCheckmark: false,
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.fieldColor,
                              side: BorderSide.none,
                              labelStyle: TextStyle(
                                color: selectedType == type
                                    ? Colors.white
                                    : AppColors.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              onSelected: (val) => setModalState(() {
                                selectedType = type;
                                selectedName = null;
                                benefitController.clear();
                              }),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // 4. 카드 이름 선택
                _buildHorizontalRow(
                  label: "카드 종류",
                  content: _buildFieldContainer(
                    DropdownButton<String>(
                      hint: const Text("카드 선택", style: TextStyle(fontSize: 15)),
                      value: selectedName,
                      isExpanded: true,
                      underline: const SizedBox(),
                      menuMaxHeight: 300,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.secondary,
                      ),
                      items: availableNames
                          .map(
                            (name) => DropdownMenuItem(
                              value: name,
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setModalState(() {
                        selectedName = val;
                        benefitController.text = CardData.allCards
                            .firstWhere((c) => c.cardName == val)
                            .benefit;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 5. 주요 혜택 (TextField 스타일 통합)
                _buildHorizontalRow(
                  label: "혜택",
                  content: _buildFieldContainer(
                    TextField(
                      controller: benefitController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: "자동 입력됩니다.",
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 6. 등록 버튼
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (selectedName == null) return;
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('my_cards')
                          .add({
                            'bankName': selectedBank,
                            'cardName': selectedName,
                            'cardType': selectedType,
                            'benefit': benefitController.text,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "등록",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 💡 메인 화면과 디자인을 맞추기 위한 헬퍼 위젯 1: 레이블
  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: AppColors.secondary,
        ),
      ),
    );
  }

  Widget _buildHorizontalRow({required String label, required Widget content}) {
    return Row(
      // 💡 부모 Row에서 세로 중앙 정렬을 유지합니다.
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. 레이블 영역
        SizedBox(
          width: 80, // 너비는 고정하여 세로 줄을 맞춥니다.
          child: Align(
            alignment: Alignment.centerLeft, // 왼쪽 정렬이면서 세로로는 중앙
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.secondary,
              ),
            ),
          ),
        ), // 입력 필드 영역
        Expanded(
          child: content,
        ),
      ],
    );
  }

  // 💡 메인 화면과 디자인을 맞추기 위한 헬퍼 위젯 2: 입력 박스 컨테이너
  Widget _buildFieldContainer(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, DocumentReference ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("카드 삭제"),
        content: const Text("정말 이 카드를 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () {
              ref.delete();
              Navigator.pop(context);
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
