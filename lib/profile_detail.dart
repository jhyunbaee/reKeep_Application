import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:flutter_rekeep/home.dart';
import 'package:flutter_rekeep/login.dart';
import 'package:flutter_rekeep/premium_service.dart';
import 'package:intl/intl.dart';

class ProfileDetail extends StatefulWidget {
  final User? user;
  const ProfileDetail({super.key, this.user});

  @override
  State<ProfileDetail> createState() => _ProfileDetailState();
}

class _ProfileDetailState extends State<ProfileDetail> {
  late final User? _currentUser;
  final TextEditingController _nicknameController = TextEditingController();

  String _name = "로딩 중...";
  String _email = "로딩 중...";
  bool _isLoading = true;

  bool _isNicknameChecked = true;
  String _lastCheckedNickname = "";

  bool _isPremium = false;
  DateTime? _premiumExpiry;
  bool _autoRenew = true;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user ?? FirebaseAuth.instance.currentUser;
    _initNickname();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _initNickname() async {
    if (_currentUser == null) return;

    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .get();

    if (doc.exists && mounted) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      DateTime? expiry;
      final premiumUntil = data['premiumUntil'];
      if (premiumUntil != null) {
        expiry = (premiumUntil as Timestamp).toDate();
      }

      // 만료 "당일"까지는 유효한 것으로 본다 (날짜 기준 비교)
      bool isPremium = false;
      if (expiry != null) {
        final today = DateUtils.dateOnly(DateTime.now());
        final expiryDay = DateUtils.dateOnly(expiry);
        isPremium = !expiryDay.isBefore(today); // 만료일 >= 오늘
      }

      setState(() {
        _nicknameController.text = data['nickname'] ?? "";
        _lastCheckedNickname = data['nickname'] ?? "";
        _name = data['name'] ?? "이름 없음";
        _email = _currentUser!.email ?? "이메일 없음";

        _isPremium = isPremium;
        _premiumExpiry = isPremium ? expiry : null;
        _autoRenew = data['autoRenew'] ?? true;

        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          "프로필",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        foregroundColor: AppColors.textPrimary(context),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: GestureDetector(
              onTap: _updateProfile,
              child: Text(
                "저장",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary(context),
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 20,
        ),
        children: [
          _buildLabel("이름"),
          _buildReadOnlyField(_name),
          const SizedBox(height: 20),
          _buildLabel("닉네임"),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: TextField(
                    controller: _nicknameController,
                    // SizedBox 제거하고 TextField 직접
                    onChanged: (value) {
                      setState(() {
                        _isNicknameChecked = (value == _lastCheckedNickname);
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "닉네임을 설정해주세요",
                      filled: true,
                      fillColor: AppColors.divider(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.22,
                  child: ElevatedButton(
                    onPressed: _checkNicknameDuplicate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary(context),
                      foregroundColor: AppColors.background(context),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      "중복확인",
                      style: TextStyle(
                        color: AppColors.background(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_isNicknameChecked)
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 4),
              child: Text(
                "닉네임 중복 확인이 필요합니다.",
                style: TextStyle(color: AppColors.pointColor, fontSize: 12),
              ),
            ),
          const SizedBox(height: 20),
          _buildLabel("이메일"),
          _buildReadOnlyField(_email),
          if (_isPremium && _premiumExpiry != null) ...[
            const SizedBox(height: 20),
            _buildLabel("프리미엄"),
            _buildPremiumField(_premiumExpiry!),
          ],
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _handleSignOut,
                child: const Text(
                  "로그아웃",
                  style: TextStyle(color: AppColors.secondary),
                ),
              ),
              const SizedBox(width: 10),
              const Text("|", style: TextStyle(color: AppColors.borderColor)),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _handleDeleteAccount,
                child: const Text(
                  "회원탈퇴",
                  style: TextStyle(color: AppColors.secondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _checkNicknameDuplicate() async {
    String nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;
    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .get();
    if (result.docs.isEmpty || nickname == _lastCheckedNickname) {
      setState(() {
        _isNicknameChecked = true;
        _lastCheckedNickname = nickname;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("사용 가능한 닉네임입니다.")));
    } else {
      setState(() {
        _isNicknameChecked = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("이미 사용 중인 닉네임입니다.")));
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildPremiumField(DateTime expiry) {
    final today = DateUtils.dateOnly(DateTime.now());
    final expiryDay = DateUtils.dateOnly(expiry);
    final int daysLeft = expiryDay.difference(today).inDays;
    final bool isExpiringToday = daysLeft == 0;

    final String dateText = DateFormat('yyyy년 M월 d일').format(expiry);

    // 자동 갱신 중: 다음 결제 예정일 안내 / 취소됨: 만료일 안내
    final String titleText;
    final String statusText;
    final Color statusColor;
    final FontWeight statusWeight;

    if (_autoRenew) {
      titleText = "프리미엄 사용 중";
      statusText = "다음 결제일 : $dateText";
      statusColor = AppColors.secondary;
      statusWeight = FontWeight.normal;
    } else {
      titleText = isExpiringToday ? "프리미엄 만료 예정" : "프리미엄 사용 중";
      statusText = isExpiringToday ? "오늘 만료" : "혜택 종료 : $dateText";
      statusColor = isExpiringToday
          ? AppColors.primary(context)
          : AppColors.secondary;
      statusWeight = isExpiringToday ? FontWeight.bold : FontWeight.normal;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary(context).withOpacity(0.05),
        border: Border.all(
          color: AppColors.primary(context).withOpacity(0.4),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary(context),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/premium.png',
                  width: 10,
                  height: 10,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: TextStyle(
                        color: AppColors.primary(context),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: statusWeight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 자동 갱신 중: 구독 취소 / 취소됨: 구독 갱신
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _autoRenew ? _cancelSubscription : _resumeSubscription,
              child: Text(
                _autoRenew ? "취소" : "갱신",
                style: TextStyle(
                  color: AppColors.primary(context),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSubscription() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "구독 취소",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "멤버십을 취소하시겠습니까?\n남은 기간(만료일)까지는 이용할 수 있습니다.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "닫기",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "취소",
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

    if (confirmed != true) return;

    try {
      await PremiumService.cancelAutoRenew();
      if (!mounted) return;
      setState(() => _autoRenew = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("자동 갱신이 해지되었어요. 만료일까지 이용할 수 있어요.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("처리 중 오류가 발생했어요. 잠시 후 다시 시도해주세요.")),
      );
    }
  }

  Future<void> _resumeSubscription() async {
    try {
      await PremiumService.resumeAutoRenew();
      if (!mounted) return;
      setState(() => _autoRenew = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("구독이 갱신되었어요. 자동 갱신이 다시 켜졌어요.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("처리 중 오류가 발생했어요. 잠시 후 다시 시도해주세요.")),
      );
    }
  }

  Widget _buildReadOnlyField(String value) {
    return Container(
      width: double.infinity,
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.divider(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        value,
        style: const TextStyle(color: AppColors.secondary, fontSize: 15),
      ),
    );
  }

  void _handleSignOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const Home()),
      (route) => false,
    );
  }

  void _handleDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "회원탈퇴",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "정말 탈퇴하시겠습니까?\n데이터는 복구할 수 없습니다.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "취소",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 확인 다이얼로그 닫기
              _deleteAccount();
            },
            child: Text(
              "확인",
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

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (user == null || uid == null) return;

    try {
      const collections = [
        'records',
        'categories',
        'my_cards',
        'recurring_expenses',
        'settings',
        'budgets',
      ];
      for (final col in collections) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection(col)
            .get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      // 2) Auth 계정 삭제 (평소엔 바로 됨)
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        // 토큰이 오래된 경우에만 재인증 후 다시 시도
        if (e.code == 'requires-recent-login') {
          final reauthed = await _reauthenticate(user);
          if (!reauthed) return; // 사용자가 취소하거나 실패
          await user.delete();
        } else {
          rethrow;
        }
      }

      // 3) 구글 세션 정리 + 로그아웃
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // 4) Home으로 이동 (로그아웃 상태)
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Home()),
        (route) => false,
      );
    } catch (e) {
      print("탈퇴 실패: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("탈퇴 처리 중 문제가 발생했어요. 잠시 후 다시 시도해주세요.")),
      );
    }
  }

  /// 로그인 수단에 맞게 재인증한다. 성공 시 true.
  Future<bool> _reauthenticate(User user) async {
    final providerIds = user.providerData.map((p) => p.providerId).toList();

    try {
      // 구글 로그인 사용자: 자동 재인증
      if (providerIds.contains('google.com')) {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return false; // 사용자가 취소
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
        return true;
      }

      // 이메일/비밀번호 사용자: 비밀번호 입력 받아 재인증
      if (providerIds.contains('password')) {
        final password = await _askPassword();
        if (password == null || password.isEmpty) return false;
        final email = user.email;
        if (email == null) return false;
        final credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        return true;
      }

      // 그 외 provider는 재인증 없이 시도
      return true;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return false;
      final msg = e.code == 'wrong-password'
          ? "비밀번호가 일치하지 않아요."
          : "본인 확인에 실패했어요. 다시 시도해주세요.";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return false;
    }
  }

  /// 비밀번호 입력 다이얼로그
  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "비밀번호 확인",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "비밀번호를 입력해주세요",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "취소",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(
              "확인",
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

  void _updateProfile() async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser?.uid)
        .update({'nickname': _nicknameController.text});
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("프로필이 저장되었습니다.")));
    Navigator.pop(context);
  }
}
