import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rekeep/analysis.dart';
import 'package:flutter_rekeep/asset.dart';
import 'package:flutter_rekeep/auth_service.dart';
import 'package:flutter_rekeep/bottom_menu_bar.dart';
import 'package:flutter_rekeep/calendar_view.dart';
import 'package:flutter_rekeep/setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _currentIndex = 0;

  // 2. 텍스트 위젯 대신 실제 클래스들을 리스트에 넣습니다.
  final List<Widget> _pages = [
    const CalendarView(), // 0번
    const Asset(), // 1번: 이제 실제 파일과 연결됨
    const Analysis(), // 2번
    const Setting(), // 3번
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _checkSecurity() async {}

  Future<void> _checkAuth() async {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],

      bottomNavigationBar: BottomMenuBar(
        selectedIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
