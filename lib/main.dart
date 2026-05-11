import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:flutter_rekeep/firebase_options.dart';
import 'package:flutter_rekeep/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const RekeepApp());
}

class RekeepApp extends StatelessWidget {
  const RekeepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'rekeep',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        // 1. 전체 기본 폰트 지정 (pubspec.yaml에 등록된 이름)
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
      ],
      locale: const Locale('ko', 'KR'),
      // 앱을 켰을 때 처음 보여줄 페이지
      home: const Home(),
    );
  }
}
