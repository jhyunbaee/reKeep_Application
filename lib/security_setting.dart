import 'package:flutter/material.dart';
import 'package:flutter_rekeep/password_setup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rekeep/constants/colors.dart';

class SecuritySetting extends StatefulWidget {
  const SecuritySetting({super.key});

  @override
  State<SecuritySetting> createState() => _SecuritySettingPageState();
}

class _SecuritySettingPageState extends State<SecuritySetting> {
  bool _isBiometricEnabled = false;
  bool _isPasswordEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBiometricEnabled = prefs.getBool('is_biometric_enabled') ?? false;
      _isPasswordEnabled = prefs.getBool('is_password_enabled') ?? false;
    });
  }

  Future<void> _togglePassword(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_password_enabled', value);
    setState(() {
      _isPasswordEnabled = value;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_biometric_enabled', value);
    setState(() {
      _isBiometricEnabled = value;
    });
  }

  Future<void> _savePassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_password', password);
  }

  Future<bool> _verifyPassword(String input) async {
    final prefs = await SharedPreferences.getInstance();
    String? savedPassword = prefs.getString('app_password');
    return savedPassword == input;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        title: const Text(
          "인증 및 보안",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(
            height: 10,
          ),
          SwitchListTile.adaptive(
            title: const Text(
              "비밀번호 잠금 사용",
              style: TextStyle(fontSize: 15),
            ),
            value: _isPasswordEnabled,
            onChanged: (value) => _togglePassword(value),
            activeColor: AppColors.primary(context),
          ),
          ListTile(
            title: const Text("비밀번호 설정", style: TextStyle(fontSize: 15)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PasswordSetup(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
