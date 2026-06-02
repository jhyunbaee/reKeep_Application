import 'package:flutter/material.dart';
import 'package:flutter_rekeep/setting_asset.dart';

/// 비프리미엄 사용자에게 보여주는 "자산 설정" 미리보기 화면.
///
/// 실제 화면(SettingAsset)을 isPreview 모드로 그대로 재사용한다.
/// - 상단에 "미리보기 페이지입니다" 배너 표시
/// - 예시(더미) 값이 채워진 상태로 보여줌
/// - 추가/수정/삭제/저장은 동작하지 않음
class SettingAssetPreview extends StatelessWidget {
  const SettingAssetPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingAsset(isPreview: true);
  }
}
