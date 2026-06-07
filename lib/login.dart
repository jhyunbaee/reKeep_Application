import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rekeep/auth_service.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:flutter_rekeep/home.dart';
import 'package:image_picker/image_picker.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

final TextEditingController _emailController = TextEditingController();
final TextEditingController _passwordController = TextEditingController();
final TextEditingController _nameController = TextEditingController();
final TextEditingController _nicknameController = TextEditingController();
final TextEditingController _phoneController = TextEditingController();

class _LoginState extends State<Login> {
  bool isLogin = true;

  bool _isNicknameChecked = true;
  String _lastCheckedNickname = "";

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  void _handleSignUp() async {
    AuthService authService = AuthService();

    String result = await authService.signUpUser(
      email: _emailController.text,
      password: _passwordController.text,
      name: _nameController.text,
      nickname: _nicknameController.text,
    );

    if (result.startsWith("success:")) {
      // uid를 result에서 직접 파싱 — currentUser에 의존하지 않음
      final uid = result.split(":")[1];

      if (_selectedImage != null) {
        try {
          final ref = FirebaseStorage.instance.ref().child(
            'profile_images/$uid.jpg',
          );
          await ref.putFile(_selectedImage!);
          final url = await ref.getDownloadURL();
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'profileImageUrl': url,
          });
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        isLogin = true;
        _selectedImage = null;
        _nameController.clear();
        _nicknameController.clear();
        _phoneController.clear();
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  Future<void> _initializeFields() async {
    _emailController.clear();
    _passwordController.clear();
    _nameController.clear();
    _nicknameController.clear();
    _phoneController.clear();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            isLogin ? Icons.close : Icons.arrow_back,
            color: AppColors.textPrimary(context),
          ),
          onPressed: () {
            if (isLogin) {
              Navigator.pop(context);
            } else {
              setState(() => isLogin = true);
            }
          },
        ),
        title: Text(
          isLogin ? "로그인" : "회원가입",
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 로고 (로그인 화면에서만 표시)
            if (isLogin)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 30),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  height: 120,
                ),
              ),

            if (isLogin) ..._buildLoginFields() else ..._buildSignUpFields(),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  if (isLogin) {
                    String result = await AuthService().loginUser(
                      email: _emailController.text.trim(),
                      password: _passwordController.text.trim(),
                    );

                    if (result == "success") {
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const Home()),
                        (route) => false,
                      );
                    } else {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result)),
                      );
                    }
                  } else {
                    _handleSignUp();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: AppColors.background(context),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  isLogin ? "로그인" : "가입하기",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 아이디 찾기 | 비밀번호 찾기 | 회원가입(로그인 화면일 때만)
            if (isLogin)
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _showFindIdDialog,
                      child: Text(
                        "아이디 찾기",
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _buildAuthDivider(),
                    GestureDetector(
                      onTap: _handleFindPassword,
                      child: Text(
                        "비밀번호 찾기",
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _buildAuthDivider(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isLogin = false;
                          _emailController.clear();
                          _passwordController.clear();
                          _nameController.clear();
                          _nicknameController.clear();
                          _phoneController.clear();
                        });
                      },
                      child: Text(
                        "회원가입",
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      isLogin = true;
                      _emailController.clear();
                      _passwordController.clear();
                      _nameController.clear();
                      _nicknameController.clear();
                      _phoneController.clear();
                    });
                  },
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 14,
                      ),
                      children: [
                        const TextSpan(text: "이미 계정이 있으신가요? "),
                        TextSpan(
                          text: "로그인",
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),

            if (isLogin) ...[
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: Divider(color: AppColors.secondary.withOpacity(0.2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "SNS 계정으로 로그인",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: AppColors.secondary.withOpacity(0.2)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // SNS 로그인 (원형 아이콘)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 구글
                  GestureDetector(
                    onTap: _handleGoogleSignIn,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: AppColors.divider(context)),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/google_logo.png',
                          width: 24,
                          height: 24,
                        ),
                      ),
                    ),
                  ),
                  // 애플
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _handleAppleSignIn,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.apple,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLoginFields() {
    return [
      _buildCustomTextField(
        hint: "이메일을 입력해주세요",
        controller: _emailController,
      ),
      const SizedBox(height: 10),
      _buildCustomTextField(
        hint: "비밀번호를 입력해주세요",
        isPassword: true,
        controller: _passwordController,
      ),
    ];
  }

  List<Widget> _buildSignUpFields() {
    return [
      _buildLabel("이름"),
      _buildCustomTextField(
        hint: "이름을 입력해주세요",
        controller: _nameController,
      ),
      const SizedBox(height: 20),

      _buildLabel("닉네임"),
      Row(
        children: [
          Expanded(
            child: _buildCustomTextField(
              hint: "닉네임을 입력해주세요",
              controller: _nicknameController,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.22,
            height: 55,
            child: ElevatedButton(
              onPressed: _checkNicknameDuplicate,
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
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
                ),
              ),
            ),
          ),
        ],
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

      _buildLabel("휴대전화"),
      _buildCustomTextField(
        hint: "'-' 없이 입력해주세요",
        controller: _phoneController,
      ),
      const SizedBox(height: 20),

      _buildLabel("이메일"),
      _buildCustomTextField(
        hint: "이메일을 입력해주세요",
        controller: _emailController,
      ),
      const SizedBox(height: 20),

      _buildLabel("비밀번호"),
      _buildCustomTextField(
        hint: "비밀번호를 입력해주세요",
        isPassword: true,
        controller: _passwordController,
      ),
    ];
  }

  Widget _buildAuthDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        "|",
        style: TextStyle(color: AppColors.secondary, fontSize: 13),
      ),
    );
  }

  // 아이디 찾기: 소셜/이메일 혼용이라 문의 안내로 처리
  void _showFindIdDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "아이디 찾기",
          style: TextStyle(fontSize: 16),
        ),
        content: const Text(
          "가입하신 이메일이 기억나지 않으시면,\n아래 이메일로 문의해 주세요.\n\nggonuuu@naver.com\n\n가입 정보를 확인해 도와드리겠습니다.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "확인",
              style: TextStyle(color: AppColors.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // 비밀번호 찾기: 이메일 입력받아 재설정 메일 발송
  Future<void> _handleFindPassword() async {
    final TextEditingController emailCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("비밀번호 찾기"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "가입하신 이메일을 입력하시면\n비밀번호 재설정 메일을 보내드립니다.",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              height: 55,
              decoration: BoxDecoration(
                color: AppColors.divider(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "이메일 입력",
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 15,
                  ),
                ),
              ),
            ),
          ],
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "취소",
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("이메일을 입력해주세요.")),
                );
                return;
              }
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: email,
                );
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("입력하신 이메일로 비밀번호 재설정 메일을 보냈습니다."),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("오류: ${e.toString()}")),
                );
              }
            },
            child: Text(
              "메일 보내기",
              style: TextStyle(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    final result = await AuthService().signInWithGoogle();
    if (!mounted) return;
    if (result == "success") {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
        (route) => false,
      );
    } else if (result != "cancelled") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("구글 로그인 실패: $result")),
      );
    }
  }

  Future<void> _handleAppleSignIn() async {
    final result = await AuthService().signInWithApple();
    if (!mounted) return;
    if (result == "success") {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
        (route) => false,
      );
    } else if (result != "cancelled") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("애플 로그인 실패: $result")),
      );
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("사용 가능한 닉네임입니다.")),
      );
    } else {
      setState(() {
        _isNicknameChecked = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이미 사용 중인 닉네임입니다.")),
      );
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildCustomTextField({
    required String hint,
    TextEditingController? controller,
    IconData? icon,
    bool isPassword = false,
  }) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: AppColors.divider(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        autofillHints: isPassword
            ? [AutofillHints.password]
            : [AutofillHints.email],
        enableSuggestions: !isPassword,
        decoration: InputDecoration(
          prefixIcon: isLogin && icon != null
              ? Icon(icon, color: AppColors.secondary, size: 20)
              : null,
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.secondary,
            fontSize: 15,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 15,
          ),
        ),
      ),
    );
  }
}
