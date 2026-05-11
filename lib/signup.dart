import 'package:flutter/material.dart';
import 'auth_service.dart'; // 방금 만든 파일을 불러옵니다.

class SignUp extends StatefulWidget {
  @override
  _SignUpState createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  // 1. 입력값을 받아올 컨트롤러들
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  // 2. 버튼을 눌렀을 때 실행될 로직을 여기에 넣습니다.
  void _handleSignUp() async {
    print("회원가입 시도 시작..."); // 1. 함수가 실행되는지 확인

    AuthService authService = AuthService();

    try {
      String result = await authService.signUpUser(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
      );

      print("결과: $result"); // 2. 서비스로부터 받은 결과 출력

      // 3. 화면에 팝업 띄우기
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result == "success" ? "회원가입 성공!" : result)),
      );
    } catch (e) {
      print("UI 단 에러 발생: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: '이름'),
          ),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(labelText: '이메일'),
          ),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(labelText: '비밀번호'),
            obscureText: true,
          ),

          // 3. 실제 버튼 위젯의 onPressed에 연결합니다.
          ElevatedButton(
            onPressed: _handleSignUp, // 위에서 만든 함수를 연결!
            child: Text("회원가입하기"),
          ),
        ],
      ),
    );
  }
}
