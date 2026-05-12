import 'package:flutter/material.dart';

class AppLayout {
  // 앱 전체 공통 좌우 패딩 값
  static const double horizontalPadding = 24.0;

  // 패딩 객체로 만들어두면 더 쓰기 편함
  static const EdgeInsets defaultPadding = EdgeInsets.symmetric(
    horizontal: horizontalPadding,
  );
}
