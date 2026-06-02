import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PremiumService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  // 프리미엄 여부 체크
  static Future<bool> isPremium() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final premiumUntil = data['premiumUntil'];

      if (premiumUntil == null) return false;

      final expiry = (premiumUntil as Timestamp).toDate();
      return expiry.isAfter(DateTime.now()); // 만료일 이후면 false
    } catch (e) {
      return false;
    }
    // return true;
  }

  // 프리미엄 활성화 (결제 완료 후 호출)
  static Future<void> activatePremium(int months) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    DateTime expiry;

    // 기존 만료일이 있으면 거기서 연장, 없으면 지금부터
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final existing = data['premiumUntil'];
      if (existing != null) {
        final existingDate = (existing as Timestamp).toDate();
        if (existingDate.isAfter(now)) {
          expiry = DateTime(
            existingDate.year,
            existingDate.month + months,
            existingDate.day,
          );
        } else {
          expiry = DateTime(now.year, now.month + months, now.day);
        }
      } else {
        expiry = DateTime(now.year, now.month + months, now.day);
      }
    } else {
      expiry = DateTime(now.year, now.month + months, now.day);
    }

    await _firestore.collection('users').doc(user.uid).set({
      'premiumUntil': Timestamp.fromDate(expiry),
      'isPremium': true,
      'autoRenew': true,
    }, SetOptions(merge: true));
  }

  // 자동 갱신 해지 (구독 취소): 만료일까지는 사용, 이후 갱신 안 함
  static Future<void> cancelAutoRenew() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set(
      {'autoRenew': false},
      SetOptions(merge: true),
    );
  }

  // 자동 갱신 재개
  static Future<void> resumeAutoRenew() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set(
      {'autoRenew': true},
      SetOptions(merge: true),
    );
  }

  // 자동 갱신 여부 조회 (기본값: true)
  static Future<bool> isAutoRenewOn() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return false;

    final data = doc.data() as Map<String, dynamic>;
    return data['autoRenew'] ?? true;
  }

  // 프리미엄 만료일 반환
  static Future<DateTime?> getExpiryDate() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;
    final premiumUntil = data['premiumUntil'];
    if (premiumUntil == null) return null;

    return (premiumUntil as Timestamp).toDate();
  }

  // 요금제별 개월 수
  static int getMonths(String plan) {
    switch (plan) {
      case 'monthly':
        return 1;
      case 'halfYearly':
        return 6;
      case 'yearly':
        return 12;
      default:
        return 1;
    }
  }

  // 요금제별 가격
  static int getPrice(String plan, {bool isDiscounted = false}) {
    if (isDiscounted) {
      switch (plan) {
        case 'monthly':
          return 2500;
        case 'yearly':
          return 19000;
        default:
          return getPrice(plan);
      }
    }
    switch (plan) {
      case 'monthly':
        return 3500;
      case 'halfYearly':
        return 15000;
      case 'yearly':
        return 25000;
      default:
        return 3500;
    }
  }
}
