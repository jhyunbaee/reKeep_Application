import 'package:flutter/material.dart';
import 'auth_service.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  _SignUpState createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  void _handleSignUp() async {
    print("회원가입 시도 시작...");

    AuthService authService = AuthService();

    try {
      String result = await authService.signUpUser(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
      );

      print("결과: $result");

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

          ElevatedButton(
            onPressed: _handleSignUp,
            child: Text("회원가입하기"),
          ),
        ],
      ),
    );
  }
}
