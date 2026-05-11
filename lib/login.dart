import 'package:flutter/material.dart';
import 'package:flutter_rekeep/auth_service.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:flutter_rekeep/home.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

// _LoginScreenState 클래스 상단에 추가
final TextEditingController _emailController = TextEditingController();
final TextEditingController _passwordController = TextEditingController();
final TextEditingController _nameController = TextEditingController();
final TextEditingController _nicknameController = TextEditingController();
final TextEditingController _phoneController = TextEditingController();

class _LoginState extends State<Login> {
  bool isLogin = true; // 로그인/회원가입 상태 전환

  void _handleSignUp() async {
    AuthService authService = AuthService();

    String result = await authService.signUpUser(
      email: _emailController.text,
      password: _passwordController.text,
      name: _nameController.text,
    );

    if (!mounted) return;

    if (result == "success") {
      // 1. 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("회원가입 성공! 로그인해주세요.")),
      );

      // 2. 로그인 모드로 전환 및 불필요한 필드(이름 등) 초기화
      setState(() {
        isLogin = true;
        // 여기서 _emailController.text는 회원가입 때 쓴 값이 그대로 남아있어야 합니다.
        // 만약 이름이 뜬다면, _buildLoginFields에서 컨트롤러를 잘못 연결했을 확률이 커요.
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

  // login.dart 내의 _LoginState 클래스
  @override
  void initState() {
    super.initState();
    // 페이지가 로드될 때마다 컨트롤러 비우기
    _emailController.clear();
    _passwordController.clear();
    _nameController.clear();
    _nicknameController.clear();
    _phoneController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // 1. 앱바 조건부 렌더링 (로그인: X버튼+reKeep / 회원가입: 뒤로가기+텍스트)
        leading: IconButton(
          icon: Icon(
            isLogin ? Icons.close : Icons.arrow_back,
            color: Colors.black,
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
            color: isLogin ? AppColors.primary : Colors.black,
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

            const SizedBox(height: 40),

            // 4. 버튼 (둥글게 10px)
            ElevatedButton(
              // login.dart의 ElevatedButton 내부
              onPressed: () async {
                if (isLogin) {
                  // 1. AuthService 인스턴스를 통해 로그인 함수 호출
                  String result = await AuthService().loginUser(
                    email: _emailController.text.trim(),
                    password: _passwordController.text.trim(),
                  );

                  if (result == "success") {
                    // 2. 로그인 성공 시 홈으로 이동
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const Home()),
                      (route) => false,
                    );
                  } else {
                    // 3. 실패 시 에러 메시지 팝업
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
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isLogin ? "로그인" : "회원가입 완료",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 5. 하단 전환 문구
            Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isLogin = !isLogin;
                    // 모드를 바꿀 때 입력했던 내용들을 싹 지워줌
                    _emailController.clear();
                    _passwordController.clear();
                    _nameController.clear();
                    _nicknameController.clear();
                    _phoneController.clear();
                  });
                },
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
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

  // --- 로그인 입력폼 ---
  List<Widget> _buildLoginFields() {
    return [
      _buildLabel("이메일"),
      _buildCustomTextField(
        hint: "이메일을 입력해주세요",
        icon: Icons.email_outlined,
        controller: _emailController, // 반드시 _emailController 연결!
      ),
      const SizedBox(height: 24),
      _buildLabel("비밀번호"),
      _buildCustomTextField(
        hint: "비밀번호를 입력해주세요",
        icon: Icons.lock_outline,
        isPassword: true,
        controller: _passwordController, // 반드시 _passwordController 연결!
      ),
    ];
  }

  // --- 2. 회원가입 입력폼 (순서: 이름, 닉네임, 휴대전화, 이메일, 비밀번호) ---
  List<Widget> _buildSignUpFields() {
    return [
      _buildLabel("이름"),
      _buildCustomTextField(
        hint: "이름을 입력해주세요",
        controller: _nameController,
      ), // 연결
      const SizedBox(height: 20),

      _buildLabel("닉네임"),
      Row(
        children: [
          Expanded(
            child: _buildCustomTextField(
              hint: "닉네임을 입력해주세요",
              controller: _nicknameController,
            ),
          ), // 연결
          const SizedBox(width: 8), // 4. 중복확인 버튼 (가로 20%, 색상 primary, 높이 동일)
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.22,
            height: 50, // 입력폼과 동일한 높이
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                "중복확인",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),

      _buildLabel("휴대전화"),
      _buildCustomTextField(
        hint: "'-' 없이 입력해주세요",
        controller: _phoneController,
      ), // 연결
      const SizedBox(height: 20),

      _buildLabel("이메일"),
      _buildCustomTextField(
        hint: "이메일을 입력해주세요",
        controller: _emailController,
      ), // 연결
      const SizedBox(height: 20),

      _buildLabel("비밀번호"),
      _buildCustomTextField(
        hint: "비밀번호를 입력해주세요",
        isPassword: true,
        controller: _passwordController,
      ), // 연결
    ];
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

  // 3. 입력폼 수정 (아이콘 조건부 삭제, 테두리 없음, 회색 배경)
  Widget _buildCustomTextField({
    required String hint,
    TextEditingController? controller, // 1. 컨트롤러 매개변수 추가
    IconData? icon,
    bool isPassword = false,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.fieldColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextFormField(
        controller: controller, // 2. 여기에 컨트롤러를 연결!!
        obscureText: isPassword,
        decoration: InputDecoration(
          // ... 기존 코드 동일 ...
          prefixIcon: isLogin && icon != null
              ? Icon(icon, color: AppColors.fieldTextColor, size: 20)
              : null,
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.fieldTextColor,
            fontSize: 14,
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
