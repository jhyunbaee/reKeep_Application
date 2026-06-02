import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rekeep/category.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:flutter_rekeep/constants/sized.dart';
import 'package:flutter_rekeep/login.dart';
import 'package:flutter_rekeep/my_card.dart';
import 'package:flutter_rekeep/notification_service.dart';
import 'package:flutter_rekeep/notification_setting.dart';
import 'package:flutter_rekeep/premium.dart';
import 'package:flutter_rekeep/profile_detail.dart';
import 'package:flutter_rekeep/security_setting.dart';
import 'package:flutter_rekeep/setting_asset.dart';
import 'package:flutter_rekeep/setting_asset_preview.dart';
import 'package:flutter_rekeep/theme_setting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_rekeep/premium_service.dart';
import 'package:flutter_rekeep/premium_gate.dart';
import 'package:flutter_rekeep/export.dart';
import 'package:flutter_rekeep/faq.dart';

Future<void> uploadCardsFromCsv(BuildContext context) async {
  try {
    final rawData = await rootBundle.loadString("assets/total_cards.csv");
    if (rawData.trim().isEmpty) {
      return;
    }

    final cleanedData = rawData.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    List<List<dynamic>> csvTable = CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(cleanedData);

    final firestore = FirebaseFirestore.instance;
    final collectionRef = firestore.collection('total_cards');

    if (csvTable.length <= 1) {
      return;
    }

    final existingDocs = await collectionRef.get();
    for (var doc in existingDocs.docs) {
      await doc.reference.delete();
    }

    for (int i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];

      if (row.isEmpty || row[0].toString().trim().isEmpty) continue;

      String bankName = row[0].toString().trim();
      String cardName = row[1].toString().trim();
      String imgUrl = row[2].toString().trim();
      String benefit = row[3].toString().trim();
      String type = row[4].toString().trim();

      int rotate = 0;
      if (row.length > 5 && row[5].toString().trim().isNotEmpty) {
        rotate = int.tryParse(row[5].toString().trim()) ?? 0;
      }

      String position = 'center';
      if (row.length > 6 && row[6].toString().trim().isNotEmpty) {
        position = row[6].toString().trim();
      }

      await collectionRef.add({
        'bankName': bankName,
        'cardName': cardName,
        'imgUrl': imgUrl,
        'type': type,
        'benefit': benefit,
        'rotate': rotate,
        'position': position,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (!context.mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(
    //   const SnackBar(content: Text("CSV 카드 도감 동기화 완벽 완료!")),
    // );
  } catch (e) {}
}

class Setting extends StatefulWidget {
  const Setting({super.key});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  bool _isBiometricEnabled = false;
  String _appVersion = '';
  bool _isPremium = false;

  // TODO: 출시 시 App Store Connect에서 발급된 실제 앱 ID(숫자)로 교체
  static const String _appStoreId = '0000000000';

  Future<void> _openReview() async {
    final uri = Uri.parse(
      'https://apps.apple.com/app/id$_appStoreId?action=write-review',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("App Store를 열 수 없습니다.")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _loadAppVersion();
    _loadPremiumStatus();
  }

  Future<void> _loadPremiumStatus() async {
    final isPremium = await PremiumService.isPremium();
    if (mounted) setState(() => _isPremium = isPremium);
  }

  Future<void> _loadBiometricSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBiometricEnabled = prefs.getBool('is_biometric_enabled') ?? false;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_biometric_enabled', value);
    setState(() {
      _isBiometricEnabled = value;
    });
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        surfaceTintColor: AppColors.background(context),
        scrolledUnderElevation: 0,
        elevation: 0,
        title: const Text(
          "설정",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),

      body: ListView(
        children: [
          _buildProfileSection(context, currentUser),
          _buildFullDivider(),
          _isPremium
              ? ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.primary(context),
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          'assets/premium.png',
                          width: 10,
                          height: 10,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "프리미엄 사용 중",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildMenuItem(
                  "프리미엄 혜택받기",
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Premium()),
                    );
                    // 프리미엄 페이지에서 돌아오면 상태 새로고침
                    _loadPremiumStatus();
                  },
                ),
          _buildFullDivider(),
          _buildMenuItem(
            "자산 설정",
            isPremium: !_isPremium,
            onTap: _requireLogin(context, () async {
              final isPremium = await PremiumService.isPremium();
              if (!context.mounted) return;
              if (isPremium) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingAsset()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingAssetPreview(),
                  ),
                );
              }
            }),
          ),
          _buildMenuItem(
            "내 카드 관리",
            onTap: _requireLogin(context, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyCard()),
              );
            }),
          ),
          _buildMenuItem(
            "카테고리 관리",
            onTap: _requireLogin(context, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Category()),
              );
            }),
          ),
          _buildFullDivider(),
          _buildMenuItem(
            "알림 설정",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSetting(),
                ),
              );
            },
          ),
          // _buildMenuItem("위젯 설정"),
          _buildMenuItem(
            "인증 및 보안",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SecuritySetting(),
                ),
              );
            },
          ),
          _buildMenuItem(
            "화면 테마",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ThemeSetting()),
              );
            },
          ),
          _buildMenuItem(
            "데이터 내보내기",
            isPremium: !_isPremium,
            onTap: _requireLogin(context, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Export()),
              );
            }),
          ),

          _buildFullDivider(),
          _buildMenuItem(
            "의견 보내기",
            onTap: () async {
              final Uri emailUri = Uri(
                scheme: 'mailto',
                path: 'ggonuuu@naver.com',
                queryParameters: {
                  'subject': '[reKeep] 의견 보내기',
                  'body': '앱 버전: 1.0.0\n\n의견을 작성해주세요:\n',
                },
              );

              if (await canLaunchUrl(emailUri)) {
                await launchUrl(emailUri);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("메일 앱을 열 수 없습니다.")),
                  );
                }
              }
            },
          ),
          _buildMenuItem("평점 남기기", onTap: _openReview),
          _buildMenuItem(
            "앱 공유하기",
            onTap: () {
              final box = context.findRenderObject() as RenderBox?;
              Share.share(
                '가계부 앱 reKeep으로 지출을 쉽게 관리해보세요!',
                subject: 'reKeep - 더 나은 내일을 만드는 기록 습관',
                sharePositionOrigin: box == null
                    ? Rect.fromLTWH(0, 0, 400, 900)
                    : box.localToGlobal(Offset.zero) & box.size,
              );
            },
          ),
          _buildFullDivider(),
          ListTile(
            title: const Text(
              "앱 버전",
              style: TextStyle(fontSize: 15),
            ),
            trailing: Text(
              _appVersion,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
              ),
            ),
          ),

          _buildMenuItem(
            "고객센터",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Faq()),
              );
            },
          ),
          _buildFullDivider(),
          _buildMenuItem(
            "전체 초기화",
            isDestructive: true,
            onTap: _requireLogin(context, () => _showResetConfirmDialog()),
          ),

          const SizedBox(height: 15),

          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 24.0),
          //   child: ElevatedButton(
          //     onPressed: () async {
          //       await uploadCardsFromCsv(context);
          //     },
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: AppColors.primary(context),
          //       foregroundColor: AppColors.background(context),
          //       padding: const EdgeInsets.symmetric(
          //         horizontal: 20,
          //         vertical: 15,
          //       ),
          //       shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(10),
          //       ),
          //     ),
          //     child: const Text("Firestore에 엑셀(CSV) 카드 데이터 밀어넣기"),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildFullDivider() => Column(
    children: [
      Container(
        height: 8,
        width: double.infinity,
        color: AppColors.divider(context),
      ),
    ],
  );

  Widget _buildProfileSection(BuildContext context, User? user) {
    if (user == null) {
      return _profileRow(
        context,
        "로그인 해주세요",
        "여기를 눌러 로그인하기",
        "!",
        isGuest: true,
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String nickname = "이름 없음";
        String email = user.email ?? "";
        String firstChar = "?";

        String? profileImageUrl;

        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          nickname = data['nickname'] ?? "이름 없음";
          firstChar = nickname.isNotEmpty ? nickname[0] : "?";
          profileImageUrl = data['profileImageUrl'];
        }

        return _profileRow(
          context,
          nickname,
          email,
          firstChar,
          isGuest: false,
          profileImageUrl: profileImageUrl,
        );
      },
    );
  }

  Widget _profileRow(
    BuildContext context,
    String title,
    String subtitle,
    String iconChar, {
    required bool isGuest,
    String? profileImageUrl,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                isGuest ? const Login() : const ProfileDetail(),
          ),
        );
      },

      child: Padding(
        padding: AppLayout.defaultPadding,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary(context).withOpacity(0.2),
                backgroundImage:
                    (!isGuest &&
                        profileImageUrl != null &&
                        profileImageUrl.isNotEmpty)
                    ? NetworkImage(profileImageUrl) as ImageProvider
                    : null,
                child:
                    (!isGuest &&
                        profileImageUrl != null &&
                        profileImageUrl.isNotEmpty)
                    ? null
                    : Text(
                        iconChar,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary(context),
                        ),
                      ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 14,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: AppColors.secondary),
            ],
          ),
        ),
      ),
    );
  }

  // 로그인 필요 메뉴용 가드 - 비로그인 시 다이얼로그 표시
  VoidCallback? _requireLogin(BuildContext context, VoidCallback action) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return action;
    return () {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            "로그인 필요",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "로그인 후 이용할 수 있는 기능이에요.\n로그인 페이지로 이동할까요?",
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "취소",
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Login()),
                );
              },
              child: Text(
                "로그인",
                style: TextStyle(
                  color: AppColors.primary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    };
  }

  Widget _buildMenuItem(
    String title, {
    VoidCallback? onTap,
    bool isPremium = false,
    bool isDestructive = false,
  }) {
    return ListTile(
      title: Row(
        children: [
          if (isPremium) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary(context),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/premium.png',
                  width: 10,
                  height: 10,
                ),
              ),
            ),
          ],
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: isDestructive
          ? null
          : const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.secondary,
            ),
      onTap: () async {
        if (onTap != null) onTap();
      },
    );
  }

  Future<void> _resetAllData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    // 삭제할 서브컬렉션 목록
    final collections = [
      'records',
      'recurring_expenses',
      'my_cards',
      'categories',
      'budgets',
      'settings',
    ];

    for (final col in collections) {
      final snap = await userRef.collection(col).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }
  }

  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "전체 초기화",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: const Text(
          "이 기록을 모두 초기화 하시겠습니까?",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "취소",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _resetAllData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("전체 초기화가 완료되었습니다.")),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("초기화 중 오류가 발생했습니다.")),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary(context),
            ),
            child: Text(
              "확인",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
