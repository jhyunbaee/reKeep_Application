import 'package:cloud_firestore/cloud_firestore.dart';

const List<Map<String, String>> defaultExpenses = [
  {'name': '식비', 'icon': '🍴'},
  {'name': '카페/간식', 'icon': '🥤'},
  {'name': '마트/편의점', 'icon': '🛒'},
  {'name': '술/유흥', 'icon': '🍺'},
  {'name': '생활', 'icon': '🧵'},
  {'name': '교통', 'icon': '🚘'},
  {'name': '쇼핑', 'icon': '🛍️'},
  {'name': '의료', 'icon': '🏥'},
  {'name': '주거/통신', 'icon': '🏠'},
  {'name': '문화/여가', 'icon': '🎬'},
  {'name': '뷰티/미용', 'icon': '💄'},
  {'name': '반려동물', 'icon': '🐶'},
  {'name': '취미', 'icon': '🎨'},
  {'name': '교육', 'icon': '📚'},
  {'name': '여행', 'icon': '✈️'},
  {'name': '기타', 'icon': '✨'},
];

const List<Map<String, String>> defaultIncomes = [
  {'name': '급여', 'icon': '💰'},
  {'name': '상여금', 'icon': '🎉'},
  {'name': '부수입', 'icon': '💵'},
  {'name': '장학금', 'icon': '🧑‍🎓'},
  {'name': '용돈', 'icon': '💌'},
  {'name': '정산하기', 'icon': '👥'},
  {'name': '이월', 'icon': '📅'},
  {'name': '기타', 'icon': '✨'},
];

// 비어있을 때만 기본 카테고리 심기 (최초 실행용)
Future<void> seedDefaultCategoriesIfEmpty(String userId) async {
  final categoriesRef = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('categories');

  final check = await categoriesRef.limit(1).get();
  if (check.docs.isNotEmpty) return; // 이미 있으면 스킵

  await seedDefaultCategories(userId);
}

// 강제 초기화 (아이콘 버튼용 - 기존 데이터 삭제 후 새로 심기)
Future<void> seedDefaultCategories(String userId) async {
  final categoriesRef = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('categories');

  // 기존 데이터 전체 삭제
  final snapshot = await categoriesRef.get();
  if (snapshot.docs.isNotEmpty) {
    final deleteBatch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      deleteBatch.delete(doc.reference);
    }
    await deleteBatch.commit();
  }

  // 새로 심기
  final batch = FirebaseFirestore.instance.batch();
  for (int i = 0; i < defaultExpenses.length; i++) {
    batch.set(categoriesRef.doc(), {
      ...defaultExpenses[i],
      'type': '지출',
      'index': i,
    });
  }
  for (int i = 0; i < defaultIncomes.length; i++) {
    batch.set(categoriesRef.doc(), {
      ...defaultIncomes[i],
      'type': '수입',
      'index': i + defaultExpenses.length,
    });
  }
  await batch.commit();
}
