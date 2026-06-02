import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:flutter_rekeep/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _controller = TextEditingController();

  void _onBackspace() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _controller.text = _controller.text.substring(
          0,
          _controller.text.length - 1,
        );
      });
    }
  }

  void _onNumberTap(String number) async {
    if (_controller.text.length < 4) {
      if (!mounted) return;

      setState(() {
        _controller.text += number;
      });

      if (_controller.text.length == 4) {
        final prefs = await SharedPreferences.getInstance();
        String? savedPassword = prefs.getString(
          'app_password',
        );

        if (_controller.text == savedPassword) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("비밀번호가 틀렸습니다.")),
          );
          setState(() {
            _controller.clear();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 160),
            const Text(
              "비밀번호를 입력하세요",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(
              height: 20,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                bool isFilled = index < _controller.text.length;
                return Container(
                  margin: const EdgeInsets.all(8),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? AppColors.primary(context)
                        : AppColors.borderColor,
                  ),
                );
              }),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: SizedBox(
                height: 350,
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    if (index == 9) return const SizedBox();
                    if (index == 10) return _buildKeypadButton("0");
                    if (index == 11) {
                      return IconButton(
                        onPressed: _onBackspace,
                        icon: Icon(
                          Icons.arrow_back,
                          color: AppColors.textPrimary(context),
                        ),
                      );
                    }
                    return _buildKeypadButton("${index + 1}");
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String label) {
    return TextButton(
      onPressed: () => _onNumberTap(label),
      child: Text(
        label,
        style: TextStyle(fontSize: 26, color: AppColors.textPrimary(context)),
      ),
    );
  }
}
