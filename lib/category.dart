import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rekeep/constants/colors.dart';

class Category extends StatefulWidget {
  const Category({super.key});

  @override
  State<Category> createState() => _CategoryManagementState();
}

class _CategoryManagementState extends State<Category>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final userId = FirebaseAuth.instance.currentUser?.uid;

  bool _isEditMode = false;
  final Set<String> _selectedDocIds = {};

  // 기본값 리스트 (기존과 동일)
  final List<Map<String, String>> defaultExpenses = [
    {'name': '식비', 'icon': '🍴'},
    {'name': '카페/간식', 'icon': '☕'},
    {'name': '마트/편의점', 'icon': '🛒'},
    {'name': '술/유흥', 'icon': '🍺'},
    {'name': '생활', 'icon': '🏠'},
    {'name': '교통', 'icon': '🚌'},
    {'name': '쇼핑', 'icon': '🛍️'},
    {'name': '의료', 'icon': '🏥'},
    {'name': '주거/통신', 'icon': '📱'},
    {'name': '문화/여가', 'icon': '🎬'},
    {'name': '뷰티/미용', 'icon': '💄'},
    {'name': '반려동물', 'icon': '🐶'},
    {'name': '취미', 'icon': '🎨'},
    {'name': '교육', 'icon': '📚'},
    {'name': '여행', 'icon': '✈️'},
    {'name': '고정지출', 'icon': '📅'},
    {'name': '기타', 'icon': '✨'},
  ];
  final List<Map<String, String>> defaultIncomes = [
    {'name': '급여', 'icon': '💰'},
    {'name': '상여금', 'icon': '🎉'},
    {'name': '사업/수입', 'icon': '📈'},
    {'name': '장학금', 'icon': '🧑‍💼'},
    {'name': '용돈', 'icon': '🎁'},
    {'name': '정산하기', 'icon': '📊'},
    {'name': '이월', 'icon': '📅'},
    {'name': '기타', 'icon': '✨'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    String currentType = _tabController.index == 0 ? "지출" : "수입";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        // 1. 왼쪽 여백을 위해 자동 뒤로가기 버튼 대신 커스텀 배치 (필요시)
        leadingWidth: 64, // 뒤로가기 버튼 + 여백 고려
        centerTitle: true,
        title: const Text(
          "카테고리 관리",
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            padding: EdgeInsets.only(right: 24),
            onPressed: _seedDefaultCategories,
            icon: const Icon(Icons.data_saver_on, size: 20),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.secondary,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),

          indicatorSize:
              TabBarIndicatorSize.tab, // 강조선(밑줄)을 텍스트 길이가 아닌 탭 전체 너비(1/2)에 맞춤
          isScrollable:
              false, // 탭을 스크롤하지 않고 화면 전체 너비에 맞춰 균등 분할 (기본값이 false지만 명시)

          tabs: const [
            Tab(text: "지출"),
            Tab(text: "수입"),
          ],
          onTap: (index) => setState(() => _selectedDocIds.clear()),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildCategoryList("지출"), _buildCategoryList("수입")],
      ),
      // 💡 하단 편집/추가 버튼 바
      bottomNavigationBar: _buildBottomActions(currentType),
    );
  }

  Widget _buildBottomActions(String currentType) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).padding.bottom + 10,
        top: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: _isEditMode
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _isEditMode = false;
                      _selectedDocIds.clear();
                    }),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: BorderSide(color: AppColors.fieldColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: AppColors.fieldColor,
                    ),
                    child: const Text(
                      "취소",
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _deleteSelected,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pointColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      "삭제 (${_selectedDocIds.length})",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isEditMode = true),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(color: AppColors.primaryLightv2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: AppColors.primaryLightv2,
                    ),
                    child: const Text(
                      "편집",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showCategoryDialog(currentType),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "추가",
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
  }

  Widget _buildCategoryList(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('categories')
          .where('type', isEqualTo: type)
          .orderBy('index', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("오류: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("등록된 카테고리가 없습니다."));

        // 💡 GridView 스타일의 Reorderable 리스트를 만들기 위해 Wrap이나 Grid를 사용합니다.
        // 여기서는 위치 변경 기능을 유지하기 위해 ReorderableListView의 프록시를 활용하거나
        // 간단하게 ReorderableListView에 그리드 스타일 패딩을 줍니다.
        return ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          // 격자 느낌을 주기 위해 리스트 빌더 내부 디자인을 카드형으로 변경
          itemCount: docs.length,
          onReorder: (oldIndex, newIndex) =>
              _onReorder(docs, oldIndex, newIndex),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final isSelected = _selectedDocIds.contains(doc.id);

            return Container(
              key: ValueKey(doc.id),
              margin: const EdgeInsets.only(bottom: 13), // 항목 간 간격
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.borderColor,
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 3,
                ),
                // 💡 편집 모드일 때 체크박스, 아닐 때는 아이콘
                leading: _isEditMode
                    ? Checkbox(
                        value: isSelected,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() {
                            if (isSelected) {
                              _selectedDocIds.remove(doc.id);
                            } else {
                              _selectedDocIds.add(doc.id);
                            }
                          });
                        },
                      )
                    : Text(doc['icon'], style: const TextStyle(fontSize: 24)),
                title: Text(
                  doc['name'],
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
                trailing: _isEditMode
                    ? const Icon(
                        Icons.drag_indicator,
                        color: AppColors.borderColor,
                      ) // 편집 모드일 때 드래그 핸들
                    : IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _showCategoryDialog(type, doc: doc),
                      ),
                onTap: _isEditMode
                    ? () => setState(() {
                        if (isSelected) {
                          _selectedDocIds.remove(doc.id);
                        } else {
                          _selectedDocIds.add(doc.id);
                        }
                      })
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  // 💡 3. 순서 변경 시 DB 업데이트 로직
  Future<void> _onReorder(
    List<QueryDocumentSnapshot> docs,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // 리스트 순서 변경
    final List<QueryDocumentSnapshot> items = List.from(docs);
    final QueryDocumentSnapshot movedItem = items.removeAt(oldIndex);
    items.insert(newIndex, movedItem);

    // Firestore Batch 업데이트 (모든 아이템의 index를 재정렬된 순서대로 저장)
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < items.length; i++) {
      batch.update(items[i].reference, {'index': i});
    }
    await batch.commit();
  } // --- 기존 로직 (데이터 처리) ---

  Future<void> _deleteSelected() async {
    if (_selectedDocIds.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (var id in _selectedDocIds) {
      batch.delete(
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('categories')
            .doc(id),
      );
    }
    await batch.commit();
    setState(() {
      _selectedDocIds.clear();
      _isEditMode = false;
    });
  }

  Future<void> _seedDefaultCategories() async {
    final categoriesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('categories');

    // 1. 현재 DB에 있는 모든 데이터를 가져옵니다.
    final snapshot = await categoriesRef.get();

    final batch = FirebaseFirestore.instance.batch();

    // 💡 [해결책] 기존에 데이터가 있다면, 묻지도 따지지도 않고 다 지웁니다.
    // 그래야 중복 문제도 해결되고 index가 포함된 새 데이터가 들어갈 자리가 생깁니다.
    if (snapshot.docs.isNotEmpty) {
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      // 일단 한 번 비웁니다.
      await batch.commit();
    }

    // 2. 이제 깨끗해진 DB에 index를 포함한 기본 데이터를 새로 넣습니다.
    final newBatch = FirebaseFirestore.instance.batch();
    int addedCount = 0;

    // 지출 데이터 삽입
    for (int i = 0; i < defaultExpenses.length; i++) {
      newBatch.set(categoriesRef.doc(), {
        ...defaultExpenses[i],
        'type': '지출',
        'index': i,
      });
      addedCount++;
    }

    // 수입 데이터 삽입
    for (int i = 0; i < defaultIncomes.length; i++) {
      newBatch.set(categoriesRef.doc(), {
        ...defaultIncomes[i],
        'type': '수입',
        'index': i + defaultExpenses.length, // 지출 다음 번호부터 시작
      });
      addedCount++;
    }

    await newBatch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("데이터를 초기화하고 $addedCount개의 카테고리를 새로 생성했습니다.")),
    );
  }

  void _showCategoryDialog(String type, {DocumentSnapshot? doc}) {
    final TextEditingController nameController = TextEditingController(
      text: doc?['name'] ?? '',
    );
    final TextEditingController iconController = TextEditingController(
      text: doc?['icon'] ?? '',
    );

    // 💡 showDialog 대신 showModalBottomSheet 사용
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 💡 키보드가 올라올 때 레이아웃이 밀려 올라오도록 설정
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        // 키보드에 가려지지 않게 여백 추가
        padding: EdgeInsets.only(
          bottom: 20,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 💡 내용물만큼만 높이 차지
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  doc == null ? "카테고리 추가" : "카테고리 수정",
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

            // 아이콘 필드
            Row(
              children: [
                const SizedBox(
                  width: 80,
                  child: Text(
                    "아이콘",
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: TextField(
                      controller: iconController,
                      decoration: InputDecoration(
                        hintText: "예: 🍴",
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
            const SizedBox(height: 15),

            // 카테고리 필드
            Row(
              children: [
                const SizedBox(
                  width: 80,
                  child: Text(
                    "카테고리",
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: "예: 식비",
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
            const SizedBox(height: 30),

            // 저장 버튼
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
                onPressed: () async {
                  final data = {
                    'name': nameController.text,
                    'icon': iconController.text,
                    'type': type,
                  };
                  if (doc == null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('categories')
                        .add(data);
                  } else {
                    await doc.reference.update(data);
                  }
                  if (!mounted) return;
                  Navigator.pop(context);
                },
                child: const Text(
                  "저장",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
