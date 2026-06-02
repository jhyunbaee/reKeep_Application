import 'package:flutter/material.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PasswordSetup extends StatefulWidget {
  const PasswordSetup({super.key});

  @override
  State<PasswordSetup> createState() => _PasswordSetupState();
}

class _PasswordSetupState extends State<PasswordSetup> {
  final TextEditingController _controller = TextEditingController();

  void _onNumberTap(String number) {
    if (_controller.text.length < 4) {
      setState(() {
        _controller.text += number;
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        title: Center(
          child: const Text(
            "비밀번호 설정",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (_controller.text.length == 4) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('app_password', _controller.text);
                if (mounted) Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("4자리 숫자를 모두 입력해주세요.")),
                );
              }
            },
            child: Text(
              "저장",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary(context),
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 160),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              bool isFilled = index < _controller.text.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled
                      ? AppColors.primary(context)
                      : AppColors.divider(context),
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
