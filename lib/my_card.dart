import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:flutter_rekeep/constants/sized.dart';
import 'package:flutter_rekeep/premium_service.dart';
import 'package:flutter_rekeep/premium_gate.dart';

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
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          "내 카드 관리",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimary(context),
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
                    color: isEditing
                        ? AppColors.pointColor
                        : AppColors.primary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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
                style: TextStyle(color: AppColors.secondary, fontSize: 15),
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
                  if (isEditing) {
                    _showEditCardSheet(doc);
                  } else {
                    _showCardDetailDialog(data);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderColor),
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
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.divider(context),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    data['type'] ?? '신용',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 5,
                                ),
                                if ((data['cardNumber'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: AppColors.divider(context),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      "${data['cardNumber']}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  ),
                              ],
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
              padding: const EdgeInsets.only(bottom: 20, right: 8),
              child: FloatingActionButton(
                onPressed: () async {
                  // 현재 카드 수 확인
                  final snapshot = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .collection('my_cards')
                      .get();

                  if (snapshot.docs.length >= 3) {
                    final isPremium = await PremiumService.isPremium();
                    if (!isPremium) {
                      if (!context.mounted) return;
                      await PremiumGate.show(
                        context,
                        message:
                            "카드는 최대 3개까지 무료로 등록할 수 있어요.\n더 많은 카드를 등록하려면 프리미엄이 필요해요.",
                      );
                      return;
                    }
                  }
                  _showAddCardSheet();
                },
                backgroundColor: AppColors.primary(context),
                shape: const CircleBorder(),
                elevation: 4,
                child: Icon(
                  Icons.add,
                  color: AppColors.background(context),
                  size: 24,
                ),
              ),
            ),
    );
  }

  void _showCardDetailDialog(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildCardImage(data),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              data['bankName'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          data['cardName'] ?? '',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.divider(context),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                data['type'] ?? '신용',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 5,
                            ),
                            if ((data['cardNumber'] ?? '')
                                .toString()
                                .isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: AppColors.divider(context),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  "${data['cardNumber']}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              Text(
                "주요 혜택 및 상세 내용",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
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
                  color: AppColors.divider(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  (data['benefit'] ?? '').toString().isEmpty
                      ? "등록된 상세 내용이 없습니다."
                      : data['benefit'],
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary(context),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
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
            ],
          ),
        );
      },
    );
  }

  void _showAddCardSheet() async {
    // 카드 목록을 한 번만 불러와 고정 (입력 중 재빌드로 선택값이 날아가지 않도록)
    final cardsSnapshot = await FirebaseFirestore.instance
        .collection('total_cards')
        .get();
    if (!mounted) return;
    final List<QueryDocumentSnapshot> allCards = cardsSnapshot.docs;

    // 상태/컨트롤러를 builder 바깥에 두어 재빌드에도 초기화되지 않게 함
    String? selectedBank;
    String? selectedCardType;
    DocumentSnapshot? selectedCardDoc;
    bool isManualInput = false;
    final TextEditingController cardNumberController = TextEditingController();
    final TextEditingController manualBankController = TextEditingController();
    final TextEditingController manualCardNameController =
        TextEditingController();
    final TextEditingController manualMemoController = TextEditingController();
    final TextEditingController benefitController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            {
              {
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
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "새 카드 추가하기",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.divider(context),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setSheetState(() {
                                        isManualInput = false;
                                        selectedBank = null;
                                        selectedCardType = null;
                                        selectedCardDoc = null;
                                      }),
                                      child: Container(
                                        height: 38,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: !isManualInput
                                              ? AppColors.background(context)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          boxShadow: !isManualInput
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.08),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Text(
                                          "목록에서 선택",
                                          style: TextStyle(
                                            color: !isManualInput
                                                ? AppColors.primary(context)
                                                : AppColors.secondary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setSheetState(() {
                                        isManualInput = true;
                                        selectedBank = null;
                                        selectedCardType = null;
                                        selectedCardDoc = null;
                                      }),
                                      child: Container(
                                        height: 38,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isManualInput
                                              ? AppColors.background(context)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          boxShadow: isManualInput
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.08),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Text(
                                          "직접 입력",
                                          style: TextStyle(
                                            color: isManualInput
                                                ? AppColors.primary(context)
                                                : AppColors.secondary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            if (!isManualInput) ...[
                              _buildInputRow(
                                "카드사",
                                _buildFieldContainer(
                                  DropdownButtonFormField<String>(
                                    menuMaxHeight: 200,
                                    dropdownColor: AppColors.background(
                                      context,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
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
                                              style: const TextStyle(
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) => setModalState(() {
                                      selectedBank = val;
                                      selectedCardType = null;
                                      selectedCardDoc = null;
                                    }),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              _buildInputRow(
                                "카드종류",
                                _buildFieldContainer(
                                  DropdownButtonFormField<String>(
                                    menuMaxHeight: 200,
                                    dropdownColor: AppColors.background(
                                      context,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
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
                                    onChanged: (val) => setModalState(() {
                                      selectedCardType = val;
                                      selectedCardDoc = null;
                                    }),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              _buildInputRow(
                                "카드이름",
                                _buildFieldContainer(
                                  DropdownButtonFormField<DocumentSnapshot>(
                                    menuMaxHeight: 200,
                                    dropdownColor: AppColors.background(
                                      context,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
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
                                            !filteredCards.contains(
                                              selectedCardDoc,
                                            ))
                                        ? null
                                        : selectedCardDoc,
                                    items:
                                        (selectedBank == null ||
                                            selectedCardType == null)
                                        ? null
                                        : filteredCards.map((doc) {
                                            final data =
                                                doc.data()
                                                    as Map<String, dynamic>;
                                            return DropdownMenuItem<
                                              DocumentSnapshot
                                            >(
                                              value: doc,
                                              child: Text(
                                                data['cardName'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            );
                                          }).toList(),
                                    onChanged: (doc) => setModalState(
                                      () => selectedCardDoc = doc,
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              _buildInputRow(
                                "카드사",
                                _buildFieldContainer(
                                  DropdownButtonFormField<String>(
                                    menuMaxHeight: 200,
                                    dropdownColor: AppColors.background(
                                      context,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
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
                                              style: const TextStyle(
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) => setModalState(() {
                                      selectedBank = val;
                                    }),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              _buildInputRow(
                                "카드종류",
                                _buildFieldContainer(
                                  DropdownButtonFormField<String>(
                                    menuMaxHeight: 200,
                                    dropdownColor: AppColors.background(
                                      context,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
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
                                    onChanged: (val) => setModalState(
                                      () => selectedCardType = val,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              _buildInputRow(
                                "카드이름",
                                _buildFieldContainer(
                                  TextField(
                                    controller: manualCardNameController,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: "카드 이름을 직접 입력하세요",
                                      hintStyle: TextStyle(
                                        color: AppColors.secondary,
                                        fontSize: 15,
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 15),
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              _buildInputRow(
                                "메모",
                                _buildFieldContainer(
                                  TextField(
                                    controller: manualMemoController,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: "메모를 입력하세요 (선택)",
                                      hintStyle: TextStyle(
                                        color: AppColors.secondary,
                                        fontSize: 15,
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 15),
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                ),
                              ),
                            ],
                            // ✅ if/else 블록 바깥 - 항상 표시
                            const SizedBox(height: 15),
                            _buildInputRow(
                              "카드번호",
                              _buildFieldContainer(
                                Row(
                                  children: [
                                    const Text(
                                      "**** **** **** ",
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: cardNumberController,
                                        keyboardType: TextInputType.number,
                                        maxLength: 4,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          hintText: "0000",
                                          hintStyle: TextStyle(
                                            color: AppColors.secondary,
                                          ),
                                          counterText: "",
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              onPressed:
                                  (!isManualInput && selectedCardDoc == null) ||
                                      (isManualInput &&
                                          (selectedBank == null ||
                                              manualCardNameController.text
                                                  .trim()
                                                  .isEmpty))
                                  ? null
                                  : () async {
                                      final currentUserId =
                                          userId ?? 'guest_user';
                                      if (isManualInput) {
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(currentUserId)
                                            .collection('my_cards')
                                            .add({
                                              'bankName': selectedBank ?? '',
                                              'cardName':
                                                  manualCardNameController.text
                                                      .trim(),
                                              'cardNumber': cardNumberController
                                                  .text
                                                  .trim(),
                                              'imgUrl': '',
                                              'type': selectedCardType ?? '신용',
                                              'benefit': manualMemoController
                                                  .text
                                                  .trim(),
                                              'isManual': true,
                                              'rotate': 0,
                                              'position': 'center',
                                              'createdAt':
                                                  FieldValue.serverTimestamp(),
                                            });
                                      } else {
                                        final cardData =
                                            selectedCardDoc!.data()
                                                as Map<String, dynamic>;
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(currentUserId)
                                            .collection('my_cards')
                                            .add({
                                              'bankName': cardData['bankName'],
                                              'cardName': cardData['cardName'],
                                              'cardNumber': cardNumberController
                                                  .text
                                                  .trim(),
                                              'imgUrl':
                                                  cardData['imgUrl'] ?? '',
                                              'type': cardData['type'],
                                              'benefit':
                                                  cardData['benefit'] ??
                                                  '할인 및 기본 혜택 제공',
                                              'isManual': false,
                                              'sourceCardId':
                                                  selectedCardDoc!.id,
                                              'rotate': cardData['rotate'] ?? 0,
                                              'position':
                                                  cardData['position'] ??
                                                  'center',
                                              'createdAt':
                                                  FieldValue.serverTimestamp(),
                                            });
                                      }
                                      if (!context.mounted) return;
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "카드가 추가되었습니다",
                                          ),
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary(context),
                                disabledBackgroundColor: AppColors.divider(
                                  context,
                                ),
                                disabledForegroundColor: AppColors.secondary,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                "저장",
                                style: TextStyle(
                                  color:
                                      (!isManualInput &&
                                              selectedCardDoc == null) ||
                                          (isManualInput &&
                                              (selectedBank == null ||
                                                  manualCardNameController.text
                                                      .trim()
                                                      .isEmpty))
                                      ? AppColors.secondary
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
            }
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
              fontSize: 14,
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
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.divider(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }

  void _showEditCardSheet(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    // 직접 입력 카드인지 여부 (없으면 imgUrl 비어있음으로 추정)
    final bool isManual =
        data['isManual'] ?? (data['imgUrl']?.toString().trim().isEmpty ?? true);

    final TextEditingController cardNumberController = TextEditingController(
      text: data['cardNumber']?.toString() ?? '',
    );
    final TextEditingController benefitController = TextEditingController(
      text: data['benefit']?.toString() ?? '',
    );
    // 직접 입력용
    final TextEditingController bankController = TextEditingController(
      text: data['bankName']?.toString() ?? '',
    );
    final TextEditingController cardNameController = TextEditingController(
      text: data['cardName']?.toString() ?? '',
    );
    String selectedType = data['type']?.toString() ?? '신용';

    // 목록 선택용 - 카드 목록 미리 로드
    List<QueryDocumentSnapshot> allCards = [];
    String? selectedBank = data['bankName']?.toString();
    String? selectedCardType = data['type']?.toString();
    DocumentSnapshot? selectedCardDoc;
    if (!isManual) {
      final snap = await FirebaseFirestore.instance
          .collection('total_cards')
          .get();
      if (!mounted) return;
      allCards = snap.docs;
      // 기존 카드와 일치하는 문서를 초기 선택값으로
      for (var d in allCards) {
        final m = d.data() as Map<String, dynamic>;
        if (m['bankName'] == selectedBank &&
            m['cardName'] == data['cardName']) {
          selectedCardDoc = d;
          break;
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // 목록 선택 모드의 드롭다운 데이터
            final bankNames = allCards
                .map(
                  (d) =>
                      (d.data() as Map<String, dynamic>)['bankName']
                          ?.toString()
                          .trim() ??
                      '',
                )
                .where((n) => n.isNotEmpty)
                .toSet()
                .toList();
            final cardTypes = allCards
                .where(
                  (d) =>
                      (d.data() as Map<String, dynamic>)['bankName'] ==
                      selectedBank,
                )
                .map(
                  (d) =>
                      (d.data() as Map<String, dynamic>)['type']?.toString() ??
                      '',
                )
                .where((t) => t.isNotEmpty)
                .toSet()
                .toList();
            final filteredCards = allCards.where((d) {
              final m = d.data() as Map<String, dynamic>;
              return m['bankName'] == selectedBank &&
                  m['type'] == selectedCardType;
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "카드 편집",
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
                    const SizedBox(height: 20),

                    if (!isManual) ...[
                      // 목록 선택 카드: 드롭다운으로 수정
                      _buildInputRow(
                        "카드사",
                        _buildFieldContainer(
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedBank,
                              hint: const Text("카드사 선택"),
                              items: bankNames
                                  .map(
                                    (b) => DropdownMenuItem(
                                      value: b,
                                      child: Text(b),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) => setSheetState(() {
                                selectedBank = val;
                                selectedCardType = null;
                                selectedCardDoc = null;
                              }),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildInputRow(
                        "카드종류",
                        _buildFieldContainer(
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedCardType,
                              hint: const Text("카드종류 선택"),
                              items: cardTypes
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) => setSheetState(() {
                                selectedCardType = val;
                                selectedCardDoc = null;
                              }),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildInputRow(
                        "카드이름",
                        _buildFieldContainer(
                          DropdownButtonHideUnderline(
                            child: DropdownButton<DocumentSnapshot>(
                              isExpanded: true,
                              value: selectedCardDoc,
                              hint: const Text("카드 선택"),
                              items: filteredCards
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(
                                        (d.data()
                                                    as Map<
                                                      String,
                                                      dynamic
                                                    >)['cardName']
                                                ?.toString() ??
                                            '',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) => setSheetState(() {
                                selectedCardDoc = val;
                                // 선택한 카드의 혜택으로 메모 갱신
                                if (val != null) {
                                  final m = val.data() as Map<String, dynamic>;
                                  benefitController.text =
                                      (m['benefit']?.toString() ??
                                              '할인 및 기본 혜택 제공')
                                          .trim();
                                }
                              }),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // 직접 입력 카드: 텍스트로 수정
                      _buildInputRow(
                        "카드사",
                        _buildFieldContainer(
                          TextField(
                            controller: bankController,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "카드사",
                              counterText: "",
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildInputRow(
                        "카드종류",
                        Row(
                          children: [
                            _buildTypeChip("신용", selectedType, (v) {
                              setSheetState(() => selectedType = v);
                            }),
                            const SizedBox(width: 8),
                            _buildTypeChip("체크", selectedType, (v) {
                              setSheetState(() => selectedType = v);
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildInputRow(
                        "카드이름",
                        _buildFieldContainer(
                          TextField(
                            controller: cardNameController,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "카드이름",
                              counterText: "",
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 15),
                    _buildInputRow(
                      "카드번호",
                      _buildFieldContainer(
                        Row(
                          children: [
                            const Text(
                              "**** **** **** ",
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.secondary,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: cardNumberController,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "0000",
                                  counterText: "",
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildInputRow(
                      "혜택",
                      _buildFieldContainer(
                        isManual
                            ? TextField(
                                controller: benefitController,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "혜택 메모",
                                  counterText: "",
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: const TextStyle(fontSize: 15),
                              )
                            : Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  benefitController.text.isEmpty
                                      ? "카드를 선택하면 혜택이 표시됩니다"
                                      : benefitController.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () async {
                        final Map<String, dynamic> updateData = {
                          'cardNumber': cardNumberController.text.trim(),
                          'benefit': benefitController.text.trim(),
                        };
                        if (!isManual) {
                          if (selectedCardDoc == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("카드를 선택해주세요.")),
                            );
                            return;
                          }
                          final cd =
                              selectedCardDoc!.data() as Map<String, dynamic>;
                          updateData['bankName'] = cd['bankName'];
                          updateData['cardName'] = cd['cardName'];
                          updateData['type'] = cd['type'];
                          updateData['imgUrl'] = cd['imgUrl'] ?? '';
                          updateData['benefit'] =
                              cd['benefit'] ?? '할인 및 기본 혜택 제공';
                          updateData['sourceCardId'] = selectedCardDoc!.id;
                        } else {
                          updateData['bankName'] = bankController.text.trim();
                          updateData['cardName'] = cardNameController.text
                              .trim();
                          updateData['type'] = selectedType;
                        }
                        await doc.reference.update(updateData);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("카드가 수정되었습니다")),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary(context),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "저장",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTypeChip(
    String label,
    String selected,
    ValueChanged<String> onTap,
  ) {
    final bool isSel = selected == label;
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSel
              ? AppColors.primary(context)
              : AppColors.divider(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isSel ? Colors.white : AppColors.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, DocumentReference ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background(context),
        title: const Text(
          "카드 삭제",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "정말 이 카드를 삭제하시겠습니까?",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "취소",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.delete();
              Navigator.pop(context);
            },
            child: Text(
              "삭제",
              style: TextStyle(
                color: AppColors.primary(context),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
        borderRadius: BorderRadius.circular(5),
        color: AppColors.secondary,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary(context).withOpacity(0.05),
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
