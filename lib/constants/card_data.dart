class CardInfo {
  final String bankName;
  final String cardName;
  final String cardType;
  final String benefit;
  final String imageUrl;

  CardInfo({
    required this.bankName,
    required this.cardName,
    required this.cardType,
    required this.benefit,
    required this.imageUrl,
  });
}

class CardData {
  // 1. 카드사별 이미지 베이스 URL (예시 주소들입니다)
  static const String _shBase =
      "https://www.shinhancard.com/pconts/images/contents/card/plate/";
  static const String _kbBase =
      "https://img1.kbcard.com/ST/img/cxc/kbcard/upload/product/";
  static const String _kaBase = "https://api.rekeep.co.kr/assets/images/cards/";
  static const String _hdBase = "https://img.hyundaicard.com/img/com/card/";
  static const String _ssBase =
      "https://static11.samsungcard.com/wcms/home/scard/image/personal/";
  static const String _wrBase =
      "https://pc.wooricard.com/webcontent/cdPrdImgFileList/";
  static const String _hnBase =
      "https://www.hanacard.co.kr/ATTACH/NEW_HOMEPAGE/images/cardinfo/card_img/";
  static const String _nhBase = "https://www.hyundaicard.com/img/card/";

  static const String _ltBase =
      "https://image.lottecard.co.kr/UploadFiles/ecenterPath/cdInfo/";
  static const String _bcBase =
      "https://www.bccard.com/images/individual/card/renew/list/";

  // 2. 헬퍼 함수: 마지막 인자에 'type'을 추가하고 기본값을 "체크카드"로 설정합니다.
  // 이렇게 하면 평소에는 안 적어도 되고, 신용카드일 때만 "신용카드"라고 적어주면 됩니다.

  static CardInfo _sh(
    String name,
    String img,
    String benefit, {
    String type = "체크카드",
  }) => CardInfo(
    bankName: "신한카드",
    cardName: name,
    cardType: type,
    benefit: benefit,
    imageUrl: "$_shBase$img",
  );

  static CardInfo _kb(
    String name,
    String img,
    String benefit, {
    String type = "체크카드",
  }) => CardInfo(
    bankName: "KB국민카드",
    cardName: name,
    cardType: type,
    benefit: benefit,
    imageUrl: "$_kbBase$img",
  );

  static CardInfo _ka(
    String name,
    String img,
    String benefit, {
    String type = "체크카드",
  }) => CardInfo(
    bankName: "카카오뱅크",
    cardName: name,
    cardType: type,
    benefit: benefit,
    imageUrl: "$_kaBase$img",
  );

  static CardInfo _hd(
    String name,
    String img,
    String benefit, {
    String type = "체크카드",
  }) => CardInfo(
    bankName: "현대카드",
    cardName: name,
    cardType: type,
    benefit: benefit,
    imageUrl: "$_hdBase$img",
  );

  static CardInfo _ss(
    String name,
    String img,
    String benefit, {
    String type = "체크카드",
  }) => CardInfo(
    bankName: "삼성카드",
    cardName: name,
    cardType: type,
    benefit: benefit,
    imageUrl: "$_ssBase$img",
  );

  static CardInfo _wr(
    String name,
    String img,
    String benefit, {
    String type = "체크카드",
  }) => CardInfo(
    bankName: "우리카드",
    cardName: name,
    cardType: type,
    benefit: benefit,
    imageUrl: "$_wrBase$img",
  );

  static CardInfo _hn(
    String name,
    String img,
    String benefit, {
    String type = "체크카드",
  }) => CardInfo(
    bankName: "하나카드",
    cardName: name,
    cardType: type,
    benefit: benefit,
    imageUrl: "$_hnBase$img",
  );

  static CardInfo _nh(
    String name,
    String img,
    String benefit, {
    String type = "체크카드",
  }) => CardInfo(
    bankName: "NH농협카드",
    cardName: name,
    cardType: type,
    benefit: benefit,
    imageUrl: "$_nhBase$img",
  );

  static CardInfo _lt(
    String name,
    String img,
    String benefit, {
    String type = "체크카드",
  }) => CardInfo(
    bankName: "롯데카드",
    cardName: name,
    cardType: type,
    benefit: benefit,
    imageUrl: "$_ltBase$img",
  );

  static CardInfo _bc(
    String name,
    String img,
    String benefit, {
    String type = "체크카드",
  }) => CardInfo(
    bankName: "비씨카드",
    cardName: name,
    cardType: type,
    benefit: benefit,
    imageUrl: "$_bcBase$img",
  );

  static final List<CardInfo> allCards = [
    // 체크카드
    _sh("신한카드 SOL트래블 체크", "cdCheckBUBDGOs.gif", ""),
    _sh("신한 후불 기후동행 체크카드", "cdCheckBOADNUs.gif", ""),
    _sh("K-패스 신한카드 체크", "cdCheckBOADG5s.png", ""),
    _sh("신한카드 Pick E 체크", "cdCheckBGND9K_1s.png", ""),
    _sh("신한카드 Pick I 체크", "cdCheckBGOD9L_1s.png", ""),

    _kb("", ".png", ""),
    _kb("", ".png", ""),
    _kb("", ".png", ""),
    _kb("", ".png", ""),
    _kb("", ".png", ""),

    _ka("", ".png", ""),
    _ka("", ".png", ""),
    _ka("", ".png", ""),
    _ka("", ".png", ""),
    _ka("", ".png", ""),

    _hd("체크(포인트형)", "card_CCM_h.png", ""),
    _hd("체크(캐시백형)", "card_CCD_h.png", ""),
    _hd("체크(Apple Pay Rewards)", "card_CCA_h.png", ""),
    _hd("하이브리드(포인트형)", "card_CCMH_h.png", ""),
    _hd("하이브리드(캐시백형)", "card_CCDH_h.png", ""),
    _hd("하이브리드(Apple Pay Rewards)", "card_CCAH_h.png", ""),

    _ss("스타벅스 삼성체크카드", "b_ABP1871_3.png", ""),
    _ss("국민행복 삼성체크카드 V2", "b_ABP1689.png", ""),
    _ss("SC제일은행 삼성체크카드 YOUNG", "b_ABP1457.png", ""),
    _ss("SC제일은행 삼성체크카드 CASHBACK", "b_ABP1459.png", ""),
    _ss("SC제일은행 삼성체크카드 POINT", "b_ABP1460.png", ""),

    _wr(
      "카드의정석2 T-WON 체크",
      "2026/3/25/1293df8d-1e66-4168-b980-4220d441a746.gif",
      "",
    ),
    _wr(
      "카드의정석2 원더라이프 CHECK",
      "2026/3/12/506b809e-a9da-409c-b6e0-c060262bff32.png",
      "",
    ),
    _wr(
      "카드의정석2 ExK 체크",
      "2026/1/20/4c8f8f39-5ade-4cf4-91ba-ec57fd46479c.png",
      "",
    ),
    _wr(
      "위비트래블 J 체크카드",
      "2025/10/10/414037d3-1971-4234-9224-7b63b78414d1.gif",
      "",
    ),
    _wr("위비트래블 체크카드", "2024/6/7/9f336062-21a7-4140-bfef-0c1fc268beed.gif", ""),

    _hn("카카오페이 트래블로그 체크카드", "15172.gif", ""),
    _hn("트래블GO 체크카드", "15105.gif", ""),
    _hn("하나 기후동행체크카드", "15169.png", ""),
    _hn("카카오페이 체크카드", "04652.png", ""),
    _hn("HERO 체크카드", "15449.png", ""),
    _hn("달달 하나 체크카드", "15114.gif", ""),

    _nh("", ".png", ""),
    _nh("", ".png", ""),
    _nh("", ".png", ""),
    _nh("", ".png", ""),
    _nh("", ".png", ""),

    _lt("롯데체크카드", "ecenterCdInfoC00041-A00041_nm1.png", ""),
    _lt("롯데 포인트플러스 체크카드", "ecenterCdInfoC00284-A00284_nm1.png", ""),
    _lt("롯데 비즈니스 체크 카드", "ecenterCdInfoC01261-A01261_nm1.jpg", ""),
    _lt("SUPER PLUS 체크카드", "ecenterCdInfoC01278-A01278_nm1.png", ""),
    _lt("롯데체크카드VISA", "ecenterCdInfoC02577-A02577_nm1.jpg", ""),

    _bc("[BNK경남] 경남은행 K-패스 체크카드", "card_104512.png", ""),
    _bc("[광주] 대한항공 SKYPASS 체크카드", "card_104283.png", ""),
    _bc("[BNK경남] Daily #2 체크카드(국내전용)", "card_104198.png", ""),
    _bc("[하나] 하나 기후동행체크카드", "card_103981.png", ""),
    _bc("[광주] Together체크카드", "card_103955.png", ""),

    // 신용카드
    _sh("신한카드 Simple Plan", "cdCreditPOGDXC_2s.png", "", type: "신용카드"),
    _sh("신한카드 Simple Plan+", "cdCreditPOHDXDs.png", "", type: "신용카드"),
    _sh("신한카드 Discount Plan", "cdCreditPODDR1s.png", "", type: "신용카드"),
    _sh("신한카드 Discount Plan+", "cdCreditPOEDR2s.png", "", type: "신용카드"),
    _sh("신한카드 ECO Plan", "cdCreditAJDDZ3s.png", "", type: "신용카드"),

    _kb("", ".png", "", type: "신용카드"),
    _kb("", ".png", "", type: "신용카드"),
    _kb("", ".png", "", type: "신용카드"),
    _kb("", ".png", "", type: "신용카드"),
    _kb("", ".png", "", type: "신용카드"),

    _ka("", ".png", "", type: "신용카드"),
    _ka("", ".png", "", type: "신용카드"),
    _ka("", ".png", "", type: "신용카드"),
    _ka("", ".png", "", type: "신용카드"),
    _ka("", ".png", "", type: "신용카드"),

    _hd("", ".png", "", type: "신용카드"),
    _hd("", ".png", "", type: "신용카드"),
    _hd("", ".png", "", type: "신용카드"),
    _hd("", ".png", "", type: "신용카드"),
    _hd("", ".png", "", type: "신용카드"),

    _ss("", ".png", "", type: "신용카드"),
    _ss("", ".png", "", type: "신용카드"),
    _ss("", ".png", "", type: "신용카드"),
    _ss("", ".png", "", type: "신용카드"),
    _ss("", ".png", "", type: "신용카드"),

    _wr(
      "카드의정석2 SUPER",
      "2026/4/23/366b88ed-449b-4d86-be6d-d00afb026fb9.gif",
      "",
      type: "신용카드",
    ),
    _wr(
      "카드의정석2 SHOPPER",
      "2026/3/30/5bbf6cdf-7445-4d20-9a0b-27b1f53feaf6.png",
      "",
      type: "신용카드",
    ),
    _wr(
      "우리카드 UniMile",
      "2025/11/17/727a70f8-a9a9-4e52-a15a-366526aed600.png",
      "",
      type: "신용카드",
    ),
    _wr(
      "카드의정석2",
      "2025/10/30/a36c67ec-8057-4571-9ad9-1513de0e50a0.gif",
      "",
      type: "신용카드",
    ),
    _wr(
      "카드의정석2 원더라이프",
      "2026/3/12/77f3f772-545e-405b-8556-5a065dad86a2.png",
      "",
      type: "신용카드",
    ),

    _hn("JADE Classic", "14955.gif", "", type: "신용카드"),
    _hn("트래블로그+(플러스) 신용카드", "15639.png", "", type: "신용카드"),
    _hn("원더카드 2.0 FREE+", "14534.png", "", type: "신용카드"),
    _hn("하나 더 넥스트 멤버스", "15299.png", "", type: "신용카드"),
    _hn("애터미 Any PLUS 카드", "12660.png", "", type: "신용카드"),
    _hn("CLUB SK(클럽 SK)카드", "03496.png", "", type: "신용카드"),
    _hn("하나 더 소호 카드", "15280.png", "", type: "신용카드"),

    _nh("", ".png", "", type: "신용카드"),
    _nh("", ".png", "", type: "신용카드"),
    _nh("", ".png", "", type: "신용카드"),
    _nh("", ".png", "", type: "신용카드"),
    _nh("", ".png", "", type: "신용카드"),

    _lt(
      "롯데마트&MAXX 카드",
      "ecenterCdInfoP14312-A14312_nm1_v.png",
      "",
      type: "신용카드",
    ),
    _lt(
      "디지로카 Las Vegas",
      "ecenterCdInfoP15584-A15584_nm1_v.png",
      "",
      type: "신용카드",
    ),
    _lt(
      "디지로카 London",
      "ecenterCdInfoP14718-A14718_nm1_v.png",
      "",
      type: "신용카드",
    ),
    _lt(
      "디지로카 Travel",
      "ecenterCdInfoP15731-A15731_nm1_v.png",
      "",
      type: "신용카드",
    ),
    _lt("디지로카 Paris", "ecenterCdInfoP14728-A14728_nm1_v.png", "", type: "신용카드"),

    _bc("[BNK경남] 경남은행 K-패스 카드", "card_104511.png", "", type: "신용카드"),
    _bc("[SH수협] 더 아우름 카드", "card_104474.png", "", type: "신용카드"),
    _bc("[BC바로] BC 바로 ZONE 카드", "card_104520.png", "", type: "신용카드"),
    _bc("[BC바로] BC 바로 에어마스터", "card_104452.png", "", type: "신용카드"),
    _bc("[BC바로] BC 바로 에어맥스", "card_104453.png", "", type: "신용카드"),
  ];
}
