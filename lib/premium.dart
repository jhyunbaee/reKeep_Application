import 'package:flutter/material.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:flutter_rekeep/premium_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class Premium extends StatefulWidget {
  const Premium({super.key});

  @override
  State<Premium> createState() => _PremiumState();
}

class _PremiumState extends State<Premium> {
  String _selectedPlan = 'yearly'; // 기본 선택: 1년
  bool _isPremium = false;
  DateTime? _expiryDate;
  bool _isLoading = true;
  final nf = NumberFormat('#,###');

  // TODO: 실제 약관/개인정보처리방침 URL로 교체
  static const String _termsUrl =
      'https://app.notion.com/p/reKeep-3718f4213537801d9045fa89796f1360?source=copy_link';
  static const String _privacyUrl =
      'https://app.notion.com/p/3718f4213537803796b6cb8f0036e774?source=copy_link';

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("페이지를 열 수 없습니다.")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPremiumStatus();
  }

  Future<void> _loadPremiumStatus() async {
    final isPremium = await PremiumService.isPremium();
    final expiry = await PremiumService.getExpiryDate();
    if (mounted) {
      setState(() {
        _isPremium = isPremium;
        _expiryDate = expiry;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.close,
              color: AppColors.textPrimary(context),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primary(context),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        Text(
                          "기록은 한 줄,\n분석은 리킵이 해드립니다.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isPremium
                              ? "프리미엄 회원이에요 ✨"
                              : "리킵 프리미엄으로 돈 관리를 더 쉽고 똑똑하게",
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 14,
                          ),
                        ),
                        if (_isPremium && _expiryDate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            "만료일: ${_expiryDate!.year}년 ${_expiryDate!.month}월 ${_expiryDate!.day}일",
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const spacing = 10.0;
                            final cardWidth =
                                (constraints.maxWidth - spacing) / 2;
                            final cards = <Widget>[
                              _buildFeatureCard(
                                Icons.wallet_outlined,
                                const Color(0xFF6C8CFF),
                                "자산 설정",
                                "예산·고정지출 관리",
                              ),
                              _buildFeatureCard(
                                Icons.equalizer_rounded,
                                const Color(0xFFFFB048),
                                "지출 분석",
                                "소비 습관 리포트",
                              ),
                              _buildFeatureCard(
                                Icons.history_rounded,
                                const Color(0xFFB079F5),
                                "전체 기간 조회",
                                "3개월 이전도 조회",
                              ),
                              _buildFeatureCard(
                                Icons.credit_card_rounded,
                                const Color(0xFF35D3A0),
                                "카드 무제한 등록",
                                "개수 제한 없이 등록",
                              ),
                              _buildFeatureCard(
                                Icons.download_rounded,
                                const Color(0xFF4FC3F7),
                                "데이터 내보내기",
                                "엑셀·CSV로 백업",
                              ),
                              _buildFeatureCard(
                                Icons.block_rounded,
                                const Color(0xFFFF7B7B),
                                "광고 제거",
                                "광고 없이 깔끔하게",
                              ),
                            ];
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: cards
                                  .map(
                                    (c) => SizedBox(
                                      width: cardWidth,
                                      child: c,
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 40,
                  ),
                  Text(
                    "첫 시작은 할인가로,\n프리미엄 기능을 가볍게 누려보세요",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  if (!_isPremium) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPlanCard(
                            'monthly',
                            '1개월',
                            3500,
                            discountPrice: 2500,
                            discountLabel: '첫 달 할인',
                          ),
                          const SizedBox(height: 10),
                          _buildPlanCard(
                            'halfYearly',
                            '6개월',
                            15000,
                            saveLabel: '월 2,500원',
                          ),
                          const SizedBox(height: 10),
                          _buildPlanCard(
                            'yearly',
                            '1년',
                            25000,
                            discountPrice: 19000,
                            discountLabel: '24% 할인',
                            saveLabel: '월 1,583원',
                            isPercent: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(
                    height: 20,
                  ),
                ],
              ),
            ),
      bottomNavigationBar: (_isLoading || _isPremium)
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(24, 15, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _onSubscribe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _getSubscribeButtonText(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _openUrl(_termsUrl),
                        child: const Text(
                          "구독약관",
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          "·",
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _openUrl(_privacyUrl),
                        child: const Text(
                          "개인정보처리방침",
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFeatureCard(
    IconData icon,
    Color iconColor,
    String title,
    String subtitle,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 150,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.textPrimary(context).withAlpha(5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    String plan,
    String label,
    int price, {
    int? discountPrice,
    String? discountLabel,
    String? saveLabel,
    bool isBest = false,
    bool isPercent = false,
  }) {
    final isSelected = _selectedPlan == plan;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary(context).withOpacity(0.05)
              : AppColors.background(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary(context)
                : AppColors.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // 선택 표시
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary(context)
                      : AppColors.secondary,
                  width: 2,
                ),
                color: isSelected
                    ? AppColors.primary(context)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            // 플랜 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isPercent) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary(context),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            "24%",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // 가격
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (discountPrice != null) ...[
                  Text(
                    "${nf.format(price)}원",
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    "${nf.format(discountPrice)}원",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ] else
                  Text(
                    "${nf.format(price)}원",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (saveLabel != null)
                  Text(
                    saveLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary(context),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getSubscribeButtonText() {
    final months = PremiumService.getMonths(_selectedPlan);
    final price = PremiumService.getPrice(
      _selectedPlan,
      isDiscounted: _selectedPlan == 'monthly' || _selectedPlan == 'yearly',
    );
    return "프리미엄 이용하기";
  }

  Future<void> _onSubscribe() async {
    await PremiumService.activatePremium(
      PremiumService.getMonths(_selectedPlan),
    );
    if (!mounted) return;
    // 활성화 후 프리미엄 페이지를 닫고 이전 화면(설정)으로 돌아간다
    Navigator.of(context).pop();
  }
}
