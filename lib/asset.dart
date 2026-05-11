import 'package:flutter/material.dart';

class Asset extends StatelessWidget {
  const Asset({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("자산"),
        backgroundColor: Colors.white,
      ),
      body: const Center(child: Text("여기에 자산 내역을 구현하세요.")),
    );
  }
}
