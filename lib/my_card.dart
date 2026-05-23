import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
    final currentUserId = userId ?? 'guest_user';

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
            fontSize: 20,
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
                    fontSize: 14,
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
            .doc(currentUserId)
            .collection('my_cards')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "등록된 카드가 없습니다.\n새로운 카드를 추가해보세요!",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondary, fontSize: 16),
              ),
            );
          }

          final myCards = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
              top: 10,
              bottom: 20,
            ),
            itemCount: myCards.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = myCards[index];
              final data = doc.data() as Map<String, dynamic>;

              return GestureDetector(
                onTap: () {
                  // 💡 변수명이 card인 경우 그 이름 그대로 전달해야 합니다.
                  _showCardDetailDialog(data);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      _buildCardImage(data),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['bankName'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondary,
                              ),
                            ),
                            Text(
                              data['cardName'] ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.fieldColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                data['type'] ?? '신용',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isEditing)
                        GestureDetector(
                          onTap: () =>
                              _showDeleteConfirmDialog(context, doc.reference),
                          child: const Icon(
                            Icons.remove_circle,
                            color: AppColors.pointColor,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isEditing
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 16, right: 8),
              child: FloatingActionButton(
                onPressed: _showAddCardSheet,
                backgroundColor: AppColors.primary,
                shape: const CircleBorder(),
                elevation: 4,
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ),
    );
  }

  // 💡 기존의 _showCardDetailDialog를 이 코드로 통째로 덮어쓰기 하시면 됩니다.
  void _showCardDetailDialog(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true, // 바텀시트 내부 스크롤 및 높이 유연성 확보
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom:
                MediaQuery.of(context).padding.bottom + 24, // 노치 디자인 하단 여백 대응
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 바텀시트 상단 손잡이 바 디자인
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. 좌측: 카드 이미지
                  _buildCardImage(data),
                  const SizedBox(width: 20), // 이미지와 텍스트 사이 간격
                  // 2. 우측: 카드 정보 묶음
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 카드사 | 타입 (왼쪽 정렬 한 줄 배치)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              data['bankName'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          data['cardName'] ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.fieldColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            data['type'] ?? '신용',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // 하단: 주요 혜택 및 상세 내용 구역
              const Text(
                "주요 혜택 및 상세 내용",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: AppColors.fieldColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  (data['benefit'] ?? '').toString().isEmpty
                      ? "등록된 상세 내용이 없습니다."
                      : data['benefit'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 하단 닫기 버튼
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "닫기",
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
    );
  }

  void _showAddCardSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String? selectedBank;
        String? selectedCardType;
        DocumentSnapshot? selectedCardDoc;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('total_cards')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final allCards = snapshot.data!.docs;

            final bankNames = allCards
                .map(
                  (doc) =>
                      (doc.data() as Map<String, dynamic>)['bankName']
                          ?.toString()
                          .trim() ??
                      '',
                )
                .where((name) => name.isNotEmpty)
                .toSet()
                .toList();

            return StatefulBuilder(
              builder: (context, setModalState) {
                List<DocumentSnapshot> filteredCards = [];
                if (selectedBank != null && selectedCardType != null) {
                  filteredCards = allCards.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final docBank = data['bankName']?.toString().trim();
                    final docType = data['type']?.toString().trim();
                    return docBank == selectedBank &&
                        docType == selectedCardType;
                  }).toList();
                }

                return Padding(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "새 카드 추가하기",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close), // 순수 아이콘만 사용
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildInputRow(
                        "카드사",
                        _buildFieldContainer(
                          DropdownButtonFormField<String>(
                            dropdownColor: Colors.white,
                            isExpanded: true,
                            hint: const Text(
                              "카드사를 선택하세요",
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.secondary,
                              ),
                            ),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 0,
                                horizontal: 0,
                              ),
                              border: InputBorder.none,
                            ),
                            value: selectedBank,
                            items: bankNames
                                .map(
                                  (bank) => DropdownMenuItem(
                                    value: bank,
                                    child: Text(
                                      bank,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setModalState(() {
                                selectedBank = val;
                                selectedCardType = null;
                                selectedCardDoc = null;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildInputRow(
                        "카드종류",
                        _buildFieldContainer(
                          DropdownButtonFormField<String>(
                            dropdownColor: Colors.white,
                            isExpanded: true,
                            hint: const Text(
                              "카드 종류를 선택하세요",
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.secondary,
                              ),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            value: selectedCardType,
                            items: const [
                              DropdownMenuItem(
                                value: "신용",
                                child: Text(
                                  "신용카드",
                                  style: TextStyle(fontSize: 15),
                                ),
                              ),
                              DropdownMenuItem(
                                value: "체크",
                                child: Text(
                                  "체크카드",
                                  style: TextStyle(fontSize: 15),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setModalState(() {
                                selectedCardType = val;
                                selectedCardDoc = null;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildInputRow(
                        "카드이름",
                        _buildFieldContainer(
                          DropdownButtonFormField<DocumentSnapshot>(
                            dropdownColor: Colors.white,
                            isExpanded: true,
                            disabledHint: const Text(
                              "상위 조건을 먼저 선택하세요",
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.secondary,
                              ),
                            ),
                            hint: const Text(
                              "카드 상품을 선택하세요",
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.secondary,
                              ),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            value:
                                (selectedBank == null ||
                                    selectedCardType == null ||
                                    !filteredCards.contains(selectedCardDoc))
                                ? null
                                : selectedCardDoc,
                            items:
                                (selectedBank == null ||
                                    selectedCardType == null)
                                ? null
                                : filteredCards.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    return DropdownMenuItem<DocumentSnapshot>(
                                      value: doc,
                                      child: Text(
                                        data['cardName'] ?? '',
                                        style: const TextStyle(fontSize: 15),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    );
                                  }).toList(),
                            onChanged: (doc) {
                              setModalState(() {
                                selectedCardDoc = doc;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: (selectedCardDoc == null)
                            ? null
                            : () async {
                                final cardData =
                                    selectedCardDoc!.data()
                                        as Map<String, dynamic>;
                                final currentUserId = userId ?? 'guest_user';

                                // 💡 [교정 위치] 추가 시 파이어베이스의 rotate와 position(center) 속성도 안전하게 복사 이관
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(currentUserId)
                                    .collection('my_cards')
                                    .add({
                                      'bankName': cardData['bankName'],
                                      'cardName': cardData['cardName'],
                                      'imgUrl': cardData['imgUrl'] ?? '',
                                      'type': cardData['type'],
                                      'benefit':
                                          cardData['benefit'] ??
                                          '할인 및 기본 혜택 제공',
                                      'rotate': cardData['rotate'] ?? 0,
                                      'position':
                                          cardData['position'] ?? 'center',
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });

                                if (!context.mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("내 지갑에 카드가 안전하게 추가되었습니다!"),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: Colors.grey.shade300,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "추가 완료",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
      },
    );
  }

  Widget _buildInputRow(String label, Widget content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.secondary,
            ),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildFieldContainer(Widget child) {
    return SizedBox(
      height: 55,
      child: Container(
        alignment: Alignment.center, // 💡 추가: 컨테이너 내부 자식을 중앙으로
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.fieldColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, DocumentReference ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
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
            child: const Text(
              "삭제",
              style: TextStyle(color: AppColors.pointColor),
            ),
          ),
        ],
      ),
    );
  }

  // 💡 가로/세로 랜덤 카드를 예쁜 세로 카드 틀로 고정해주는 이미지 빌더 함수
  Widget _buildCardImage(Map<String, dynamic> cardData) {
    final String imgUrl = cardData['imgUrl']?.toString().trim() ?? '';
    final int imgRotate = cardData['rotate'] ?? 0;
    final String imgPos = cardData['position'] ?? 'center';

    Alignment imageAlignment = Alignment.center;
    if (imgPos == 'top') imageAlignment = Alignment.topCenter;
    if (imgPos == 'bottom') imageAlignment = Alignment.bottomCenter;

    return Container(
      width: 54,
      height: 85,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.grey.shade100,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imgUrl.isEmpty
          ? const Icon(Icons.credit_card, size: 24, color: AppColors.secondary)
          : RotatedBox(
              quarterTurns: (imgRotate / 90).round(),
              child: Image.network(
                imgUrl,
                alignment: imageAlignment,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.credit_card,
                  size: 24,
                  color: AppColors.secondary,
                ),
              ),
            ),
    );
  }
}
