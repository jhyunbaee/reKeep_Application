import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rekeep/calendar_seeder.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _autoSeedIfEmpty();
  }

  Future<void> _autoSeedIfEmpty() async {
    if (userId == null) return;
    await seedDefaultCategoriesIfEmpty(userId!);
  }

  Future<void> _seedDefaultCategories() async {
    if (userId == null) return;
    await seedDefaultCategories(userId!); // IfEmpty 없는 버전으로 (강제 초기화)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("카테고리를 초기화했습니다.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentType = _tabController.index == 0 ? "지출" : "수입";

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 64,
        centerTitle: true,
        title: Text(
          "카테고리 관리",
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        surfaceTintColor: AppColors.background(context),
        iconTheme: IconThemeData(color: AppColors.textPrimary(context)),
        actions: [
          IconButton(
            padding: EdgeInsets.only(right: 24),
            onPressed: _seedDefaultCategories,
            icon: const Icon(Icons.data_saver_on, size: 20),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary(context),
          labelColor: AppColors.primary(context),
          unselectedLabelColor: AppColors.secondary,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),

          indicatorSize: TabBarIndicatorSize.tab,
          isScrollable: false,

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
        color: AppColors.background(context),
        border: Border(top: BorderSide(color: AppColors.borderColor)),
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
                      side: BorderSide(color: AppColors.divider(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: AppColors.divider(context),
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
                        color: AppColors.background(context),
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
                      side: BorderSide(color: AppColors.divider(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: AppColors.divider(context),
                    ),
                    child: const Text(
                      "편집",
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
                    onPressed: () => _showCategoryDialog(currentType),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary(context),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      "추가",
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

        return ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          itemCount: docs.length,
          onReorder: (oldIndex, newIndex) =>
              _onReorder(docs, oldIndex, newIndex),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final isSelected = _selectedDocIds.contains(doc.id);

            return Material(
              key: ValueKey(doc.id),
              color: isSelected
                  ? AppColors.primary(context).withOpacity(0.1)
                  : AppColors.background(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 3,
                  ),
                  leading: _isEditMode
                      ? Checkbox(
                          value: isSelected,
                          activeColor: AppColors.primary(context),
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
                      fontSize: 15,
                    ),
                  ),
                  trailing: _isEditMode
                      ? const Icon(
                          Icons.drag_indicator,
                          color: AppColors.secondary,
                        )
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onReorder(
    List<QueryDocumentSnapshot> docs,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final List<QueryDocumentSnapshot> items = List.from(docs);
    final QueryDocumentSnapshot movedItem = items.removeAt(oldIndex);
    items.insert(newIndex, movedItem);

    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < items.length; i++) {
      batch.update(items[i].reference, {'index': i});
    }
    await batch.commit();
  }

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

  void _showCategoryDialog(String type, {DocumentSnapshot? doc}) {
    final TextEditingController nameController = TextEditingController(
      text: doc?['name'] ?? '',
    );
    final TextEditingController iconController = TextEditingController(
      text: doc?['icon'] ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: 20,
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
                  doc == null ? "카테고리 추가" : "카테고리 수정",
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
                    "아이콘",
                    style: TextStyle(
                      fontSize: 14,
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
            const SizedBox(height: 15),

            Row(
              children: [
                const SizedBox(
                  width: 80,
                  child: Text(
                    "카테고리",
                    style: TextStyle(
                      fontSize: 14,
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
            const SizedBox(height: 30),

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
                onPressed: () async {
                  final existingDocs = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('categories')
                      .where('type', isEqualTo: type)
                      .get();

                  final data = {
                    'name': nameController.text,
                    'icon': iconController.text,
                    'type': type,
                    'index': existingDocs.docs.length,
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
