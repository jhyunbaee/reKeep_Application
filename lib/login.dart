import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rekeep/auth_service.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:flutter_rekeep/home.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool isRememberId = false;

  bool _isNicknameChecked = true;
  String _lastCheckedNickname = "";

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _loadSavedId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isRememberId = prefs.getBool('isRememberId') ?? false;
      if (isRememberId) {
        _emailController.text = prefs.getString('savedEmail') ?? "";
      }
    });
  }

  void _handleSignUp() async {
    AuthService authService = AuthService();

    String result = await authService.signUpUser(
      email: _emailController.text,
      password: _passwordController.text,
      name: _nameController.text,
    );

    if (!mounted) return;

    if (result == "success") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("회원가입 성공! 로그인해주세요.")),
      );

      setState(() {
        isLogin = true;
        _nameController.clear();
        _nicknameController.clear();
        _phoneController.clear();
      });
    } else {
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
    await _loadSavedId();

    if (!isRememberId) {
      _emailController.clear();
      _passwordController.clear();
      _nameController.clear();
      _nicknameController.clear();
      _phoneController.clear();
    }
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
          isLogin ? "reKeep" : "회원가입",
          style: TextStyle(
            color: isLogin ? AppColors.primary : AppColors.textPrimary(context),
            fontWeight: FontWeight.bold,
            fontSize: isLogin ? 22 : 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLogin) ..._buildLoginFields() else ..._buildSignUpFields(),

            const SizedBox(height: 30),

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
                  backgroundColor: AppColors.primary,
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
            const SizedBox(height: 30),

            Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isLogin = !isLogin;
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
                      TextSpan(
                        text: isLogin ? "아직 계정이 없으신가요? " : "이미 계정이 있으신가요? ",
                      ),
                      TextSpan(
                        text: isLogin ? "회원가입" : "로그인",
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLoginFields() {
    return [
      _buildLabel("이메일"),
      _buildCustomTextField(
        hint: "이메일을 입력해주세요",
        icon: Icons.email_outlined,
        controller: _emailController,
      ),
      const SizedBox(height: 20),
      _buildLabel("비밀번호"),
      _buildCustomTextField(
        hint: "비밀번호를 입력해주세요",
        icon: Icons.lock_outline,
        isPassword: true,
        controller: _passwordController,
      ),

      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isRememberId,
                  onChanged: (bool? val) async {
                    final prefs = await SharedPreferences.getInstance();

                    setState(() {
                      isRememberId = val ?? false;
                    });

                    if (isRememberId) {
                      if (_emailController.text.isNotEmpty) {
                        await prefs.setString(
                          'savedEmail',
                          _emailController.text,
                        );
                        await prefs.setBool('isRememberId', true);
                      } else {
                        setState(() => isRememberId = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("이메일을 먼저 입력해주세요.")),
                        );
                      }
                    } else {
                      await prefs.remove('savedEmail');
                      await prefs.setBool('isRememberId', false);
                    }
                  },
                  activeColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 5),
              const Text("아이디 저장", style: TextStyle(fontSize: 13)),
            ],
          ),

          TextButton(
            onPressed: () async {
              if (_emailController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("아이디 찾기/비밀번호 재설정을 위해 이메일을 입력해주세요."),
                  ),
                );
                return;
              }

              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: _emailController.text,
                );
                if (!mounted) return;
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
            child: const Text(
              "아이디/비밀번호 찾기",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
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
                backgroundColor: AppColors.primary,
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
