import 'package:flutter/material.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:url_launcher/url_launcher.dart';

class FaqItem {
  final String question;
  final String answer;
  bool isExpanded;

  FaqItem({
    required this.question,
    required this.answer,
    this.isExpanded = false,
  });
}

class Faq extends StatefulWidget {
  const Faq({super.key});

  @override
  State<Faq> createState() => _FaqState();
}

class _FaqState extends State<Faq> {
  final List<FaqItem> _faqItems = [
    FaqItem(
      question: "지출 내역을 수정하거나 삭제할 수 있나요?",
      answer: "네, 가능합니다. 캘린더에서 해당 날짜를 선택한 후 수정하고 싶은 내역을 탭하면 수정 및 삭제 옵션이 나타납니다.",
    ),
    FaqItem(
      question: "고정지출은 무엇인가요?",
      answer:
          "매월, 매주, 매일 정기적으로 발생하는 지출 항목입니다. 설정 > 자산 설정 > 고정지출에서 관리비, 통신비, 구독료 등을 등록할 수 있으며, 설정한 날짜에 알림을 받을 수 있습니다.",
    ),
    FaqItem(
      question: "알림이 오지 않아요. 어떻게 해야 하나요?",
      answer:
          "설정 > 알림 설정에서 알림이 켜져 있는지 확인해주세요. 기기 설정에서 reKeep 앱의 알림 권한도 허용되어 있어야 합니다. 고정지출 당일 알림의 경우 '고정지출 당일 알림' 토글을 다시 껐다 켜면 알림이 재등록됩니다.",
    ),
    FaqItem(
      question: "카드를 등록하는 방법이 궁금해요.",
      answer:
          "설정 > 내 카드 관리에서 카드를 추가할 수 있습니다. 등록한 카드는 지출 내역 입력 시 결제 수단으로 선택할 수 있습니다.",
    ),
    FaqItem(
      question: "데이터를 백업하거나 내보낼 수 있나요?",
      answer:
          "프리미엄 회원의 경우 설정 > 데이터 내보내기 기능을 이용할 수 있습니다. 지출 내역을 CSV 파일로 내보내 다른 앱이나 스프레드시트에서 활용할 수 있습니다.",
    ),
    FaqItem(
      question: "카테고리를 직접 추가하거나 수정할 수 있나요?",
      answer:
          "네, 설정 > 카테고리 관리에서 카테고리를 추가, 수정, 삭제할 수 있습니다. 지출 내역 입력 시 카테고리 선택 화면에서도 카테고리 관리로 바로 이동할 수 있습니다.",
    ),
    FaqItem(
      question: "프리미엄 구독을 해지하면 데이터가 사라지나요?",
      answer:
          "아니요, 데이터는 유지됩니다. 다만 프리미엄 전용 기능(자산 설정, 데이터 내보내기 등)은 구독 해지 후 이용이 제한됩니다.",
    ),
    FaqItem(
      question: "앱을 삭제하면 데이터가 사라지나요?",
      answer:
          "로그인한 상태로 이용하셨다면 서버에 데이터가 저장되어 있어 앱을 재설치해도 복구됩니다. 비로그인 상태로 이용하신 경우 앱 삭제 시 데이터가 삭제될 수 있습니다.",
    ),
    FaqItem(
      question: "테마(다크모드)는 어떻게 변경하나요?",
      answer: "설정 > 화면 테마에서 라이트 모드, 다크 모드, 또는 기기 설정을 따르도록 선택할 수 있습니다.",
    ),
    FaqItem(
      question: "전체 초기화를 하면 어떤 데이터가 삭제되나요?",
      answer:
          "지출 내역, 고정/변동지출 설정, 등록 카드, 카테고리, 예산 설정이 모두 삭제됩니다. 단, 계정 정보(이메일, 닉네임)는 삭제되지 않습니다. 삭제된 데이터는 복구할 수 없으니 주의해 주세요.",
    ),
  ];

  Future<void> _sendFeedbackEmail() async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("메일 앱을 열 수 없습니다.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        surfaceTintColor: AppColors.background(context),
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "고객센터",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            padding: EdgeInsets.only(right: 24),
            icon: Icon(
              Icons.headphones_rounded,
              color: AppColors.textPrimary(context),
            ),
            tooltip: "의견 보내기",
            onPressed: _sendFeedbackEmail,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        children: [
          ..._faqItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildFaqCard(item, index);
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFaqCard(FaqItem item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.divider(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isExpanded
                ? AppColors.primary(context).withOpacity(0.4)
                : AppColors.divider(context),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              item.isExpanded = !item.isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Q",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.question,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: item.isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                if (item.isExpanded) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: AppColors.divider(context),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "A",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.answer,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.secondary,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
