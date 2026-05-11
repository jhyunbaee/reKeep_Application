import 'package:flutter/material.dart';

class Analysis extends StatelessWidget {
  const Analysis({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text("분석"),
        backgroundColor: Colors.white,
      ),
      body: const Center(child: Text("여기에 분석 내용을 구현하세요.")),
    );
  }
}
