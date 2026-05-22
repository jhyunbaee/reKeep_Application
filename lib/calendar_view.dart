import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rekeep/category.dart';
import 'package:image_picker/image_picker.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

// 데이터 모델 클래스
class CategoryItem {
  final String name;
  final String icon;
  CategoryItem({required this.name, required this.icon});
}

// 상수는 클래스 밖에서 정의해도 무관
const double labelWidth = 80.0;
const double fieldHeight = 45.0;

class _CalendarViewState extends State<CalendarView> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // 💡 기존의 List<dynamic> 포함된 선언을 모두 지우고 이것만 남기세요.
  Map<DateTime, int> _events = {};

  @override
  void initState() {
    super.initState();
    _loadEvents(); // 달력 데이터를 불러오는 함수 호출
    placeController.addListener(_autoAssignCategory);
  }

  Future<void> _loadEvents() async {
    if (currentUserId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('recurring_expenses')
        .get();

    // 💡 여기도 Map<DateTime, int> 입니다.
    Map<DateTime, int> fetchedEvents = {};

    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data();
      int amount = (data['amount'] ?? 0) as int;

      var dayData = data['day'] ?? 1;
      int day = 1;
      if (dayData is String) {
        day = int.tryParse(dayData.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      } else if (dayData is int) {
        day = dayData;
      }

      DateTime date = DateTime(DateTime.now().year, DateTime.now().month, day);
      DateTime normalizedDate = DateTime(date.year, date.month, date.day);

      // 💡 합산 로직
      fetchedEvents[normalizedDate] =
          (fetchedEvents[normalizedDate] ?? 0) + amount;
    }

    setState(() {
      _events = fetchedEvents; // 💡 타입이 Map<DateTime, int>로 일치!
    });
  }

  int actualExpense = 0;

  Future<int> _getMonthlyFixedExpense() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    int totalFixed = 0;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('recurring_expenses')
        .get();

    for (var doc in snapshot.docs) {
      totalFixed += (doc['amount'] as num).toInt();
    }
    return totalFixed;
  }

  // 💡 CalendarView 내부에 추가할 함수
  Future<Map<DateTime, List<dynamic>>> _getCalendarEvents() async {
    Map<DateTime, List<dynamic>> events = {};

    // 1. Firestore에서 고정지출 목록을 가져옴
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('recurring_expenses')
        .get();

    // 2. 각 항목을 달력 날짜에 매핑
    for (var doc in snapshot.docs) {
      int day = doc['day']; // 예: 10
      String name = doc['name'];

      // 이번 달의 해당 날짜를 찾아서 이벤트 리스트에 추가
      DateTime date = DateTime(DateTime.now().year, DateTime.now().month, day);
      if (events[date] == null) events[date] = [];
      events[date]!.add(name);
    }
    return events;
  }

  DateTime _focusedDay = DateTime.now();
  DateTime tempDate = DateTime.now();
  DateTime? _selectedDay;
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final NumberFormat formatter = NumberFormat('#,###');

  final TextEditingController placeController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController memoController = TextEditingController();

  String category = '식비';

  bool isOcrLoading = false;
  // 카테고리 선택 메뉴가 열려있는지 여부를 추적하는 플래그
  bool _isMenuOpen = false;

  Map<String, String> selectedCategory = {'name': '미분류', 'icon': '❓'};

  bool _isUserTouchedCategory = false;

  File? _receiptImage;

  // --- 데이터 로직 ---
  Stream<QuerySnapshot> _getRecordsStream() {
    // 현재 로그인된 사용자의 ID를 실시간으로 가져옵니다.
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // 만약 로그아웃 상태라면 쿼리를 실행하지 않고 빈 스트림을 반환합니다. (에러 방지)
    if (currentUserId == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId) // userId 변수 대신 currentUserId 사용 권장
        .collection('records')
        .where(
          'date',
          isGreaterThanOrEqualTo: DateTime(
            _focusedDay.year,
            _focusedDay.month,
            1,
          ),
        )
        .where(
          'date',
          isLessThanOrEqualTo: DateTime(
            _focusedDay.year,
            _focusedDay.month + 1,
            0,
          ),
        )
        .snapshots();
  }

  @override
  void dispose() {
    // 위젯이 꺼질 때 리스너를 지워주어 메모리 누수를 방지합니다.
    placeController.removeListener(_autoAssignCategory);
    placeController.dispose();
    amountController.dispose();
    memoController.dispose();
    super.dispose();
  }

  void _autoAssignCategory() {
    if (_isUserTouchedCategory) return;

    String text = placeController.text.trim();
    if (text.isEmpty) return;

    // 카테고리 이름과 아이콘 세트 정의
    Map<String, Map<String, String>> keywordMap = {
      '식비': {'name': '식비', 'icon': '🍔'}, // 💡 앱에서 쓰시는 실제 아이콘으로 바꿔주세요!
      '카페/간식': {'name': '카페/간식', 'icon': '☕'},
      '교통': {'name': '교통', 'icon': '🚗'},
      '쇼핑': {'name': '쇼핑', 'icon': '🛍️'},
      '문화/여가': {'name': '문화/여가', 'icon': '🎬'},
    };

    // 키워드 단어 리스트 정의
    Map<String, List<String>> keywords = {
      '식비': [
        '식당',
        '밥',
        '배달',
        '마트',
        '식료품',
        '고기',
        '국밥',
        '짜장면',
        '치킨',
        '피자',
        '한식',
        '중식',
        '일식',
      ],
      '카페/간식': [
        '카페',
        '커피',
        '스타벅스',
        '디저트',
        '빵',
        '베이커리',
        '편의점',
        'CU',
        'GS25',
        '세븐일레븐',
        '아이스크림',
      ],
      '교통': ['택시', '버스', '지하철', '주유', '충전', 'KTX', '기차', '대리', '주차'],
      '쇼핑': ['쿠팡', '네이버쇼핑', '옷', '의류', '신발', '백화점', '올리브영'],
      '문화/여가': ['영화', 'CGV', '넷플릭스', '유튜브', '노래방', '헬스', '운동', '게임'],
    };

    for (var entry in keywords.entries) {
      String categoryName = entry.key;
      List<String> wordList = entry.value;

      for (String keyword in wordList) {
        if (text.contains(keyword)) {
          if (selectedCategory['name'] != categoryName) {
            // 🚨 핵심: 바텀시트 내부의 화면도 새로고침하기 위해 이 리스너 안에서는
            // 아래의 3단계 팝업 띄우는 곳에서 처리하거나 공통으로 갱신되도록 유도합니다.
            // 바텀시트 전용 state 변경이 필요하므로, 이 함수를 바텀시트 내부 세터와 연동시킵니다.
            _updateModalCategory(
              categoryName,
              keywordMap[categoryName]!['icon']!,
            );
          }
          return;
        }
      }
    }
  }

  // 모달 내부의 State Setter를 보관할 변수
  StateSetter? _modalStateSetter;

  void _updateModalCategory(String name, String icon) {
    if (_modalStateSetter != null) {
      _modalStateSetter!(() {
        selectedCategory = {'name': name, 'icon': icon};
      });
    }
  }

  void _resetForm() {
    // 새 입력을 받을 때는 수동 터치 플래그를 다시 false로 리셋해줍니다.
    _isUserTouchedCategory = false;
    placeController.clear();
    amountController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: 8,
          right: 8,
        ),
        child: _isMenuOpen
            ? null
            : SizedBox(
                width: 55,
                height: 55,
                child: FloatingActionButton(
                  backgroundColor: AppColors.primary,
                  shape: const CircleBorder(),
                  onPressed: () => setState(() => _isMenuOpen = true),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false, // 기본 뒤로가기 버튼 공간 제거
        // titleSpacing을 0으로 하고 title에 Row를 꽉 채웁니다.
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24.0,
          ), // 좌우 여백 24px 고정
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. 왼쪽 버튼 (이전 달)
              GestureDetector(
                onTap: () => setState(
                  () => _focusedDay = DateTime(
                    _focusedDay.year,
                    _focusedDay.month - 1,
                  ),
                ),
                behavior: HitTestBehavior.opaque,
                child: const Icon(
                  Icons.chevron_left,
                  color: Colors.black,
                  size: 28,
                ),
              ),

              // 2. 중앙 월 표시
              Text(
                DateFormat('M월').format(_focusedDay),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 20,
                ),
              ),

              // 3. 오른쪽 버튼 (다음 달)
              GestureDetector(
                onTap: () => setState(
                  () => _focusedDay = DateTime(
                    _focusedDay.year,
                    _focusedDay.month + 1,
                  ),
                ),
                behavior: HitTestBehavior.opaque,
                child: const Icon(
                  Icons.chevron_right,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _getRecordsStream(),
            builder: (context, snapshot) {
              Map<String, List<Map<String, dynamic>>> dailyRecords = {};
              int totalIncome = 0;
              int totalExpense = 0;

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  data['docId'] = doc.id;

                  DateTime date = (data['date'] as Timestamp).toDate();
                  String dateKey = DateFormat('yyyy-MM-dd').format(date);

                  if (!dailyRecords.containsKey(dateKey)) {
                    dailyRecords[dateKey] = [];
                  }

                  // 2. docId가 포함된 data를 리스트에 추가
                  dailyRecords[dateKey]!.add(data);

                  // 3. 총계 계산
                  if (data['type'] == '수입') {
                    totalIncome += (data['amount'] as int);
                  } else if (data['type'] == '지출' || data['type'] == '이체') {
                    // ✅ 이체도 지출 합계에 포함
                    totalExpense += (data['amount'] as int);
                  }
                }
              }

              // 선택된 날짜에 해당하는 내역들 가져오기
              final selectedDateKey = DateFormat(
                'yyyy-MM-dd',
              ).format(_selectedDay ?? DateTime.now());
              final records = dailyRecords[selectedDateKey] ?? [];

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    _buildSummaryCard(totalIncome, totalExpense),
                    _buildNoSpendHighlight(dailyRecords),
                    Padding(
                      padding: const EdgeInsets.only(
                        // 달력
                        left: 12,
                        right: 12,
                        top: 5,
                      ),
                      child: TableCalendar(
                        locale: 'ko_KR',
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        availableGestures: AvailableGestures.none,
                        daysOfWeekHeight: 20,
                        headerVisible: false,
                        rowHeight: 75,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });

                          String dateKey = DateFormat(
                            'yyyy-MM-dd',
                          ).format(selectedDay);
                          DateTime normalizedDay = DateTime(
                            selectedDay.year,
                            selectedDay.month,
                            selectedDay.day,
                          );

                          // 💡 일반 지출이 있거나, 고정지출이 있는 경우 모두 상세창을 띄움
                          bool hasRecord =
                              (dailyRecords.containsKey(dateKey) &&
                              dailyRecords[dateKey]!.isNotEmpty);
                          bool hasFixed = (_events[normalizedDay] ?? 0) > 0;

                          if (hasRecord || hasFixed) {
                            _showDetailListSheet();
                          }
                        },
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (date.month != _focusedDay.month) return null;

                            // 1. 데이터 준비
                            DateTime normalizedDay = DateTime(
                              date.year,
                              date.month,
                              date.day,
                            );
                            int fixedAmount = _events[normalizedDay] ?? 0;

                            // 2. 무지출 여부 확인 (고정지출이 있어도 무지출 점을 안 찍음)
                            String dateKey = DateFormat(
                              'yyyy-MM-dd',
                            ).format(date);

                            // 💡 조건 변경: dailyRecords가 비어있고 + 고정지출도 0일 때만 점 표시
                            bool hasNoExpense =
                                (!dailyRecords.containsKey(dateKey) ||
                                    dailyRecords[dateKey]!.isEmpty) &&
                                fixedAmount == 0;

                            // 3. 아무것도 없으면 패스
                            if (!hasNoExpense && fixedAmount == 0) return null;

                            return Positioned(
                              top: 10,
                              left: 0,
                              right: 0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 무지출 점 (고정지출이 있으면 이 if문이 false가 되어 안 나옴)
                                  if (hasNoExpense)
                                    Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.only(bottom: 2),
                                      decoration: const BoxDecoration(
                                        color: AppColors.pointColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },

                          // 2. 기본 날짜 빌더
                          defaultBuilder: (context, date, _) => _buildDayCell(
                            date,
                            (date.weekday == 7 || date.weekday == 6)
                                ? AppColors.secondary
                                : Colors.black,
                            dailyRecords,
                            _events, // 💡 추가: 고정지출 데이터 넘김
                            false,
                          ),

                          // 3. 오늘 날짜 빌더
                          todayBuilder: (context, date, _) => _buildDayCell(
                            date,
                            AppColors.primary,
                            dailyRecords,
                            _events, // 💡 추가: 고정지출 데이터 넘김
                            isSameDay(_selectedDay, date),
                            isToday: true,
                          ),
                          // 4. 선택된 날짜 빌더
                          selectedBuilder: (context, date, _) {
                            bool isToday = isSameDay(date, DateTime.now());
                            return _buildDayCell(
                              date,
                              isToday
                                  ? AppColors.primary
                                  : (date.weekday == 7 || date.weekday == 6
                                        ? AppColors.secondary
                                        : Colors.black),
                              dailyRecords,
                              _events, // 💡 추가: 고정지출 데이터 넘김
                              false, // 선택 시 Bold 처리 여부
                              isToday: isToday,
                            );
                          },
                        ),
                        calendarStyle: const CalendarStyle(
                          markersMaxCount: 0,
                          markerDecoration: BoxDecoration(
                            color: Colors.red, // 점 색상
                            shape: BoxShape.circle,
                          ),
                          outsideDaysVisible: false,
                          // 선택된 날짜의 동그라미 배경을 투명하게 만듭니다.
                          selectedDecoration: BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          // 오늘 날짜의 배경도 투명하게 설정 (필요 시)
                          todayDecoration: BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          // 배경이 투명해지면 글자가 안 보일 수 있으니 텍스트 스타일을 지정합니다.
                          selectedTextStyle: TextStyle(
                            color: Colors.black, // 선택된 날짜의 글자색 강조
                            fontWeight: FontWeight.normal,
                          ),
                          todayTextStyle: TextStyle(
                            color: AppColors.primary, // 오늘 날짜의 글자색 강조
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        eventLoader: (day) {
                          // 1. 날짜 정규화
                          DateTime normalizedDay = DateTime(
                            day.year,
                            day.month,
                            day.day,
                          );
                          String dateKey = DateFormat('yyyy-MM-dd').format(day);

                          List<dynamic> events = [];

                          // 2. 일반 지출/수입 데이터 추가
                          if (dailyRecords.containsKey(dateKey) &&
                              dailyRecords[dateKey]!.isNotEmpty) {
                            events.addAll(dailyRecords[dateKey]!);
                          }

                          // 3. 고정지출 데이터 추가
                          int fixedAmount = _events[normalizedDay] ?? 0;
                          if (fixedAmount > 0) {
                            events.add({
                              'isFixed': true,
                              'amount': fixedAmount,
                            }); // 임시 데이터 추가
                          }

                          return events; // 이제 리스트가 비어있지 않으므로 클릭이 됩니다!
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          if (_isMenuOpen) ...[
            // 반투명 배경
            GestureDetector(
              onTap: () => setState(() => _isMenuOpen = false),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            // 3종 메뉴 및 메인 버튼 정렬 Column
            Positioned(
              bottom: 24, // 💡 위치 조절: 여기서 bottom, right를 키우면 버튼이 안쪽으로 이동합니다.
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildSubMenuButton(
                    icon: Icons.camera_alt_rounded,
                    label: "영수증 촬영하기",
                    onTap: () {
                      setState(() => _isMenuOpen = false);
                      //_pickImageFromCamera();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSubMenuButton(
                    icon: Icons.image_rounded,
                    label: "갤러리에서 영수증 가져오기",
                    onTap: () {
                      setState(() => _isMenuOpen = false);
                      _pickImageFromGallery();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSubMenuButton(
                    icon: Icons.edit_rounded,
                    label: "직접 입력하기",
                    onTap: () {
                      setState(() => _isMenuOpen = false);
                      _showAddRecordSheet();
                    },
                  ),
                  const SizedBox(height: 16),
                  // 닫기용 X 버튼
                  SizedBox(
                    width: 55, // 버튼 가로 크기
                    height: 55, // 버튼 세로 크기
                    child: FloatingActionButton(
                      backgroundColor: AppColors.primary,
                      shape: const CircleBorder(),
                      onPressed: () => setState(() => _isMenuOpen = false),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 💡 이미지와 동일한 레이아웃을 생성하는 서브 메뉴 스타일 위젯 빌더
  Widget _buildSubMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 아이콘 동그라미 버튼
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        print("이미지 가져오기 성공: ${pickedFile.path}");

        setState(() {
          _receiptImage = File(pickedFile.path);
        });

        // 🚀 [수정] 이미지를 단순 로드하는 것에 그치지 않고, 인공지능 OCR 엔진으로 분석을 시작합니다!
        await _analyzeReceipt(pickedFile.path);
      } else {
        print("이미지 선택이 취소되었습니다.");
      }
    } catch (e) {
      print("이미지를 가져오는 도중 에러 발생: $e");
    }
  }

  // 🤖 구글 AI ML Kit를 이용해 영수증을 분석하고 데이터를 리턴하는 형태로 수정
  Future<Map<String, dynamic>?> _analyzeReceipt(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.korean);
    final inputImage = InputImage.fromFilePath(imagePath);

    try {
      // 💡 [수정] 굳이 화면을 방해하는 기존 SnackBar 코드는 과감히 삭제합니다!

      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      String scannedText = recognizedText.text;
      print("=== [OCR 추출 원본 텍스트] ===");
      print(scannedText);
      print("===============================");

      List<String> lines = scannedText
          .split('\n')
          .map((e) => e.trim())
          .toList();
      String compactText = scannedText.replaceAll(' ', '');

      String detectedStore = "";
      int? detectedAmount;
      String detectedMemo = "";

      int year = DateTime.now().year;
      int month = DateTime.now().month;
      int day = DateTime.now().day;
      int hour = 12;
      int minute = 0;

      // 1️⃣ 사용처/상호명 정밀 필터링
      for (String line in lines) {
        String upperLine = line.toUpperCase().replaceAll(' ', '');
        if ((upperLine.contains("CU") ||
                upperLine.contains("GS25") ||
                upperLine.contains("세븐")) &&
            upperLine.contains("점")) {
          detectedStore = line;
          break;
        }
      }
      if (detectedStore.isEmpty) {
        for (String line in lines) {
          if (line.endsWith("점") && line.length >= 4 && !line.contains("방문")) {
            detectedStore = line;
            break;
          }
        }
      }
      if (detectedStore.isEmpty) {
        for (int i = 0; i < lines.length && i < 6; i++) {
          String line = lines[i];
          if (line.isEmpty ||
              line.contains("영수증") ||
              line.contains("매출") ||
              line.contains("승인") ||
              RegExp(r'^\d+:\d+$').hasMatch(line.replaceAll(' ', '')) ||
              line.length < 2) {
            continue;
          }
          detectedStore = line;
          break;
        }
      }
      if (detectedStore.isEmpty) detectedStore = "일반 가맹점";

      // 2️⃣ 날짜 및 시간 파싱
      final RegExp dateRegex = RegExp(r'(\d{2,4})[-./](\d{2})[-./](\d{2})');
      final RegExp timeRegex = RegExp(r'(\d{2}):(\d{2})(?::(\d{2}))?');

      for (String line in lines) {
        String cleanLine = line.replaceAll(' ', '');
        final dateMatch = dateRegex.firstMatch(cleanLine);
        if (dateMatch != null) {
          int parsedYear = int.parse(dateMatch.group(1)!);
          if (parsedYear < 100) parsedYear += 2000;
          year = parsedYear;
          month = int.parse(dateMatch.group(2)!);
          day = int.parse(dateMatch.group(3)!);
        }
        if (cleanLine.contains("-") ||
            cleanLine.contains("/") ||
            cleanLine.contains("POS")) {
          final timeMatch = timeRegex.firstMatch(cleanLine);
          if (timeMatch != null) {
            hour = int.parse(timeMatch.group(1)!);
            minute = int.parse(timeMatch.group(2)!);
          }
        }
      }
      if (hour == 12 && minute == 0) {
        final fallbackTimeMatch = timeRegex.firstMatch(compactText);
        if (fallbackTimeMatch != null) {
          hour = int.parse(fallbackTimeMatch.group(1)!);
          minute = int.parse(fallbackTimeMatch.group(2)!);
        }
      }
      DateTime detectedDate = DateTime(year, month, day, hour, minute);

      // 3️⃣ 결제금액 찾기
      final RegExp moneyRegex = RegExp(
        r'\b\d{1,3}(?:,\d{3})+(?!\d)|\b\d{4,6}\b',
      );
      final allMatches = moneyRegex.allMatches(scannedText);
      Map<int, int> amountFrequency = {};
      List<int> priceCandidates = [];

      for (var m in allMatches) {
        String cleanNum = m.group(0)!.replaceAll(',', '');
        int? parsed = int.tryParse(cleanNum);
        if (parsed != null &&
            parsed >= 1000 &&
            parsed <= 500000 &&
            parsed != 3094013922 &&
            parsed != 114448625 &&
            !cleanNum.startsWith("30940")) {
          priceCandidates.add(parsed);
          amountFrequency[parsed] = (amountFrequency[parsed] ?? 0) + 1;
        }
      }

      int mostFrequentAmount = 0;
      int maxCount = 0;
      amountFrequency.forEach((amt, count) {
        if (count > maxCount) {
          maxCount = count;
          mostFrequentAmount = amt;
        } else if (count == maxCount && amt > mostFrequentAmount) {
          mostFrequentAmount = amt;
        }
      });

      if (maxCount >= 2 && mostFrequentAmount >= 1000) {
        detectedAmount = mostFrequentAmount;
      } else if (priceCandidates.isNotEmpty) {
        priceCandidates.sort();
        detectedAmount = priceCandidates.last;
      }

      // 4️⃣ 메모 필드용 상품 내역 추출
      int itemStartIndex = -1;
      int itemEndIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        String line = lines[i].replaceAll(' ', '');
        if (line.contains("사업자") ||
            line.contains("TEL:") ||
            line.contains("2026-") ||
            line.contains("26/") ||
            line.contains("POS-")) {
          itemStartIndex = i + 1;
        }
        if (line.contains("총구매액") ||
            line.contains("결제금액") ||
            line.contains("사용금액") ||
            line.contains("상품할인") ||
            line.contains("부가세") ||
            line.contains("합계")) {
          if (itemEndIndex == -1) itemEndIndex = i;
          break;
        }
      }

      if (itemStartIndex != -1 &&
          itemEndIndex != -1 &&
          itemStartIndex < itemEndIndex) {
        List<String> items = [];
        for (int i = itemStartIndex; i < itemEndIndex; i++) {
          String itemLine = lines[i].trim();
          if (itemLine.isEmpty ||
              itemLine == "X" ||
              itemLine == "*" ||
              itemLine == "H" ||
              RegExp(r'^\d+$').hasMatch(itemLine) ||
              RegExp(r'^[\d,]+$').hasMatch(itemLine)) {
            continue;
          }
          items.add(itemLine);
        }
        detectedMemo = items.join(', ');
      }

      Map<String, String> categoryMap = {'name': '미분류', 'icon': '❓'};
      final List<String> foodKeywords = [
        "CU",
        "GS25",
        "편의점",
        "마트",
        "식당",
        "카페",
        "배달",
        "푸드",
      ];
      for (String keyword in foodKeywords) {
        if (detectedStore.toUpperCase().contains(keyword) ||
            scannedText.toUpperCase().contains(keyword)) {
          categoryMap = {'name': '식비', 'icon': '🍔'};
          break;
        }
      }

      Map<String, dynamic> receiptData = {
        'place': detectedStore,
        'amount': detectedAmount ?? 0,
        'memo': detectedMemo,
        'category': categoryMap,
        'type': '지출',
        'date': Timestamp.fromDate(detectedDate),
      };

      // 💡 [핵심 교정 1] 이미 바텀시트가 열려있는 상태(로딩 중)라면 데이터를 맵으로 리턴만 하고,
      // 최초로 갤러리에서 가져오는 상태라면 직접 바텀시트를 열어 화면에 띄우도록 완전 지능화합니다.
      if (isOcrLoading) {
        return receiptData;
      } else {
        _showAddRecordSheet(initialData: receiptData);
        return receiptData;
      }
    } catch (e) {
      print("OCR 분석 중 에러 발생: $e");
      return null;
    } finally {
      textRecognizer.close();
    }
  }

  // --- 2. UI 구성 요소 ---
  Widget _buildDayCell(
    DateTime date,
    Color textColor,
    Map dailyRecords,
    Map<DateTime, int> fixedExpenses,
    bool isSelected, {
    bool isToday = false,
  }) {
    String dateKey = DateFormat('yyyy-MM-dd').format(date);
    List<Map<String, dynamic>>? records = dailyRecords[dateKey]
        ?.cast<Map<String, dynamic>>();
    int income = 0, expense = 0;
    int totalBalance = income - expense;
    if (records != null) {
      for (var r in records) {
        if (r['type'] == '수입') {
          income += (r['amount'] as int);
        } else if (r['type'] == '지출' || r['type'] == '이체') {
          // ✅ 이체도 일별 지출에 포함
          expense += (r['amount'] as int);
        }
      }
    }

    // 💡 고정지출 금액 가져오기
    DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    int fixedAmount = fixedExpenses[normalizedDate] ?? 0;

    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          '${date.day}',
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: isToday
                ? FontWeight.bold
                : (isSelected ? FontWeight.bold : FontWeight.normal),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 26,
          child: Column(
            children: [
              if (income > 0)
                Text(
                  "+${NumberFormat('#,###').format(income)}",
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppColors.primary,
                    height: 1.1,
                  ),
                ),
              if (expense > 0)
                Text(
                  "-${NumberFormat('#,###').format(expense)}",
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppColors.secondary,
                    height: 1.1,
                  ),
                ),
              // 💡 고정지출 금액 표시 (일반 지출과 동일한 스타일, 색상만 보라색)
              if (fixedAmount > 0)
                Text(
                  "-${NumberFormat('#,###').format(fixedAmount)}",
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.purple, // 고정지출용 색상
                    fontWeight: FontWeight.bold, // 고정지출은 Bold 처리
                    height: 1.1,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(int income, int expense) {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _amountRow("수입", income, AppColors.primary),
              _amountRow("지출", expense, AppColors.pointColor),
            ],
          ),
          Divider(
            height: 30,
            thickness: 1,
            color: AppColors.dividerColor,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "현 자산",
                style: TextStyle(fontSize: 14, color: AppColors.secondary),
              ),
              Text(
                "${NumberFormat('#,###').format(income - expense)}원",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String title, int amount, Color color) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(color: AppColors.secondary, fontSize: 14),
        ),
        const SizedBox(width: 10),
        Text(
          "${NumberFormat('#,###').format(amount)}원",
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNoSpendHighlight(Map dailyRecords) {
    int noSpendCount = 0;
    int daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    for (int i = 1; i <= daysInMonth; i++) {
      String dateKey = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(_focusedDay.year, _focusedDay.month, i));
      if (!dailyRecords.containsKey(dateKey) ||
          dailyRecords[dateKey]!.isEmpty) {
        noSpendCount++;
      }
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.circle, size: 6, color: AppColors.pointColor),
              SizedBox(width: 6),
              Text(
                "무지출 일수",
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          Text(
            "총 $noSpendCount일",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showAddRecordSheet({String? docId, Map<String, dynamic>? initialData}) {
    final NumberFormat nf = NumberFormat('#,###');

    if (docId != null && docId.isNotEmpty) {
      if (initialData != null && initialData['receiptImage'] != null) {
        // 내역에 저장된 이미지 경로가 있다면 복원합니다.
        String path = initialData['receiptImage'].toString();
        _receiptImage = path.isNotEmpty ? File(path) : null;
      } else {
        // 이미지 없이 저장되었던 일반 내역 수정이라면 잔상을 지웁니다.
        _receiptImage = null;
      }
    } else {
      // 2. [새로 추가 모드] (docId가 없는 경우)
      if (isOcrLoading) {
        // 외부에서 이미지를 강제로 null 초기화하지 않고 그대로 유지합니다.
      } else if (initialData != null && initialData.containsKey('place')) {
        // 이때는 이미 메인 버튼 리스너에서 _receiptImage를 세팅했으므로 절대로 건드리지 않고 유지합니다!
      } else {
        // ➕ [+] 버튼 -> [직접 입력]을 눌러 들어온 순수 추가 모드일 때만 잔상을 깨끗이 비워줍니다.
        _receiptImage = null;
      }
    }

    int originalAmount = 0;

    // 💡 [완벽 매핑] initialData에 담겨온 영수증 데이터 혹은 파이어베이스 데이터를 컨트롤러 초기값으로 꽂아줍니다!
    final TextEditingController amountController = TextEditingController(
      text: initialData?['amount'] != null
          ? "${nf.format(initialData!['amount'])}원"
          : "",
    );
    final TextEditingController placeController = TextEditingController(
      text: initialData?['place'] ?? "",
    );
    final TextEditingController memoController = TextEditingController(
      text: initialData?['memo'] ?? "",
    );

    // [위치 정확함] 수정 모드 및 영수증 모드일 때 originalAmount 세팅
    if (initialData != null) {
      originalAmount = initialData['amount'] ?? 0;
    } else {
      originalAmount = 0;
    }

    String selectedType = initialData?['type'] ?? '지출';

    DateTime tempDate;

    if (initialData != null && initialData['date'] != null) {
      tempDate = (initialData['date'] as Timestamp).toDate();
    } else {
      tempDate = _selectedDay ?? DateTime.now();
    }

    // 💡 카테고리 초기값 설정 대응
    Map<String, String> selectedCategory = initialData?['category'] != null
        ? Map<String, String>.from(initialData?['category'])
        : {
            'name': '식비',
            'icon': '🍔',
          }; // 영수증일 땐 식비가 기본, 아닐 땐 미분류 처리는 아래서 유연하게 대응 가능

    // 만약 영수증이 아니고 진짜 일반 추가 모드라면 '미분류'로 세팅되게 안전장치 추가
    if (initialData == null) {
      selectedCategory = {'name': '미분류', 'icon': '❓'};
    }

    String selectedPayment = initialData?['paymentMethod'] ?? "";
    String selectedBankName = initialData?['bankName'] ?? "";

    int settlementPeople = initialData?['settlement']?['people'] ?? 2;
    List<String> selectedFriends = List<String>.from(
      initialData?['settlement']?['friends'] ?? [],
    );
    bool isSettlementActive = initialData?['settlement'] != null;

    Widget buildPaymentItem(
      String name,
      String bName,
      StateSetter setModalState,
    ) {
      final bool isSelected = selectedPayment == name;

      return InkWell(
        onTap: () {
          setModalState(() {
            selectedPayment = name;
            selectedBankName = bName;
          });
          Navigator.pop(context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14), //결제수단
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? AppColors.primary : Colors.black,
                  ),
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              if (isSelected)
                const Icon(Icons.check, color: AppColors.primary, size: 18),
            ],
          ),
        ),
      );
    }

    // --- 금액 입력 리스너 (원, 콤마 추가 로직) ---
    amountController.addListener(() {
      String text = amountController.text
          .replaceAll(',', '')
          .replaceAll('원', '')
          .trim();
      if (text.isEmpty) return;
      double? value = double.tryParse(text);
      if (value != null) {
        String newText = "${nf.format(value)}원"; // 💡 nf 사용
        if (newText != amountController.text) {
          amountController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length - 1),
          );
        }
      }
    });

    Stream<QuerySnapshot> getMyCards() {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('my_cards')
          .snapshots();
    }

    // _showAddRecordSheet 내부에서 정의된 부분을 이렇게 수정하세요.
    void showPaymentPicker(StateSetter setModalState) {
      // 💡 setModalState 인자 추가
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "결제수단 선택",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close), // 순수 아이콘만 사용
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 20,
                    ),
                    children: [
                      const Text(
                        "현금",
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 14,
                        ),
                      ),
                      const Divider(thickness: 0.5),
                      buildPaymentItem("현금", "현금", setModalState),
                      const SizedBox(height: 20),

                      const Text(
                        "카드",
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 14,
                        ),
                      ),
                      const Divider(thickness: 0.5),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .collection('my_cards')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          final cards = snapshot.data!.docs;

                          return Column(
                            children: cards.map((doc) {
                              final cardData =
                                  doc.data() as Map<String, dynamic>;
                              // 💡 카드 관리 페이지에서 저장했던 실제 은행명(예: 카카오뱅크)을 가져옵니다.
                              String actualBankName =
                                  cardData['bankName'] ?? '미지정';
                              String cardName = cardData['cardName'] ?? '';

                              return buildPaymentItem(
                                cardName,
                                actualBankName, // 💡 이 값을 반드시 넘겨줘야 합니다.
                                setModalState,
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    void showSettlementPicker(StateSetter setModalState) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (context) => StatefulBuilder(
          builder: (context, setPickerState) {
            // 친구 목록 더미 데이터
            List<String> friendsList = [
              "김철수",
              "이영희",
              "박지민",
              "최유나",
              "정재현",
              "강민경",
            ];

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "정산하기",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    "정산 인원",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: settlementPeople,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.fieldColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: List.generate(9, (index) => index + 2)
                        .map(
                          (val) => DropdownMenuItem(
                            value: val,
                            child: Text("$val명"),
                          ),
                        )
                        .toList(),

                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          settlementPeople = val; // 인원수 변경 (예: 5명)

                          if (originalAmount > 0) {
                            // 철저하게 보존된 originalAmount(50,000)에서 정직originalAmount하게 나눕니다.
                            int divided = (originalAmount / settlementPeople)
                                .round();
                            amountController.text = "${nf.format(divided)}원";
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    "친구 선택",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.fieldColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      itemCount: friendsList.length,
                      itemBuilder: (context, index) {
                        final friend = friendsList[index];
                        final isSelected = selectedFriends.contains(friend);
                        return CheckboxListTile(
                          title: Text(
                            friend,
                            style: const TextStyle(fontSize: 15),
                          ),
                          value: isSelected,
                          activeColor: AppColors.primary,
                          onChanged: (bool? value) {
                            setPickerState(() {
                              if (value == true) {
                                selectedFriends.add(friend);
                              } else {
                                selectedFriends.remove(friend);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        setModalState(() {
                          isSettlementActive = true;

                          // 💡 [버그 완전 해결 핵심 로직]
                          // 기존의 amountController.text를 그대로 가져와서 계산하면 쪼개진 금액을 또 쪼개게 됩니다.
                          // 그렇기 때문에 이미 굳건하게 보존되고 있는 원래 전체 금액 'originalAmount'를 기준으로 정직하게 나눕니다.
                          if (originalAmount > 0) {
                            int nPrice = (originalAmount / settlementPeople)
                                .round();

                            // 1인당 정산 금액(예: 10,000원)을 정확하게 부모 텍스트 필드에 주입합니다.
                            amountController.text = "${nf.format(nPrice)}원";
                          }
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "설정 완료",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        isSettlementActive = false;
                        selectedFriends.clear();
                        settlementPeople = 2;
                      });
                      Navigator.pop(context);
                    },
                    child: const Center(
                      child: Text(
                        "정산 취소",
                        style: TextStyle(color: AppColors.pointColor),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _receiptImage = null; // 창 닫을 때 영수증 사진 상태도 함께 클리어!
                        });
                        Navigator.pop(context);
                      },
                      child: const Icon(Icons.close), // 순수 아이콘만 사용
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 📸 [요구사항] 영수증 이미지 표시 및 우측 상단 기능 버튼들 (X, 편집)
                        if (_receiptImage != null) ...[
                          Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                height: 180,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  image: isOcrLoading
                                      ? null // 로딩 중일 때는 이미지를 임시 숨김 처리
                                      : DecorationImage(
                                          image: FileImage(_receiptImage!),
                                          fit: BoxFit.cover,
                                        ),
                                ), // 💡 이미지 분석 중일 때 제자리에서 도는 이쁜 로딩 인디케이터 표시
                                child: isOcrLoading
                                    ? const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              color: AppColors.pointColor,
                                            ),
                                            SizedBox(height: 10),
                                            Text(
                                              "영수증 재분석 중...",
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : null,
                              ),
                              // 로딩 중이 아닐 때만 우측 상단 기능 버튼들 노출
                              if (!isOcrLoading)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Row(
                                    children: [
                                      // ✏️ 제자리 이미지&텍스트 변환 편집 버튼
                                      GestureDetector(
                                        onTap: () async {
                                          final ImagePicker picker =
                                              ImagePicker();
                                          final XFile? image = await picker
                                              .pickImage(
                                                source: ImageSource.gallery,
                                              );

                                          if (image != null) {
                                            // 1. 클래스 상태 변수 및 바텀시트 새로고침을 통해 즉시 로딩 인디케이터 구동
                                            setModalState(() {
                                              isOcrLoading = true;
                                            });

                                            // 2. 메인 파일 상태 동기화
                                            setState(() {
                                              _receiptImage = File(image.path);
                                            });

                                            // 3. 백그라운드 재인식 프로세스 가동 (창이 유지됨)
                                            final newData =
                                                await _analyzeReceipt(
                                                  image.path,
                                                );

                                            if (newData != null) {
                                              // 4. 추출 완료 즉시 기존 텍스트 필드 값들만 실시간으로 갈아끼우기
                                              setModalState(() {
                                                placeController.text =
                                                    newData['place'] ?? '';
                                                amountController.text =
                                                    formatter.format(
                                                      newData['amount'] ?? 0,
                                                    );
                                                memoController.text =
                                                    newData['memo'] ?? '';

                                                if (newData['date'] != null) {
                                                  tempDate =
                                                      (newData['date']
                                                              as Timestamp)
                                                          .toDate();
                                                }
                                                if (newData['category'] !=
                                                    null) {
                                                  category =
                                                      newData['category']['name'] ??
                                                      '식비';
                                                }
                                              });
                                            }

                                            // 5. 로딩 변수 해제 후 이미지 원상복구
                                            setModalState(() {
                                              isOcrLoading = false;
                                            });
                                          }
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.edit,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),

                                      // ❌ 기존 이미지 삭제 버튼
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _receiptImage = null;
                                          });
                                          setModalState(() {
                                            placeController.clear();
                                            amountController.clear();
                                            memoController.clear();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 1. 실제 저장될 금액 입력 칸 (정산 시 1인당 금액이 됨)
                            Expanded(
                              child: TextField(
                                controller: amountController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  hintText: "0원",
                                  border: InputBorder.none,
                                  // 💡 정산하기가 켜져 있으면 텍스트 필드 밑에 안내 문구 표시
                                  helperText: isSettlementActive
                                      ? "1인당 정산 금액"
                                      : null,
                                  helperStyle: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],

                                onChanged: (val) {
                                  if (val.isEmpty) {
                                    originalAmount = 0;
                                    return;
                                  }

                                  // 사용자가 입력한 값에서 콤마와 '원'을 지우고 순수 숫자로 파싱
                                  int? parsed = int.tryParse(
                                    val
                                        .replaceAll(',', '')
                                        .replaceAll('원', '')
                                        .trim(),
                                  );

                                  if (parsed != null) {
                                    // 💡 사용자가 키보드로 치는 값은 무조건 원래 전체 금액(originalAmount)으로 고정!
                                    originalAmount = parsed;

                                    // 화면에는 정산 인원수에 맞게 나눠서 보여줌
                                    int displayAmount = isSettlementActive
                                        ? (originalAmount / settlementPeople)
                                              .round()
                                        : originalAmount;

                                    amountController.text =
                                        "${nf.format(displayAmount)}원";
                                    amountController
                                        .selection = TextSelection.fromPosition(
                                      TextPosition(
                                        offset:
                                            amountController.text.length - 1,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),

                            // 💡 [핵심 추가] 정산 중일 때 나누기 전 원래 전체 금액을 옆에 띄워주는 레이아웃
                            if (isSettlementActive) ...[
                              Builder(
                                builder: (context) {
                                  // 원래 전체 총액 계산
                                  int totalAmount = isSettlementActive
                                      ? originalAmount
                                      : (int.tryParse(
                                              amountController.text
                                                  .replaceAll(',', '')
                                                  .replaceAll('원', '')
                                                  .trim(),
                                            ) ??
                                            0);

                                  return GestureDetector(
                                    // ✨ 전체 금액 박스를 클릭했을 때 실행할 액션
                                    onTap: () {
                                      // 전체 금액을 새로 입력받을 임시 컨트롤러 (기존 금액을 초기값으로 세팅)
                                      final TextEditingController
                                      totalEditController =
                                          TextEditingController(
                                            text: formatter.format(totalAmount),
                                          );

                                      showDialog(
                                        context: context,
                                        builder: (dialogContext) {
                                          return AlertDialog(
                                            title: const Text(
                                              "전체 금액",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            content: TextField(
                                              controller: totalEditController,
                                              keyboardType:
                                                  TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              autofocus:
                                                  true, // 팝업 열리자마자 키보드 활성화
                                              decoration: const InputDecoration(
                                                suffixText: "원",
                                                hintText: "새로운 전체 금액 입력",
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  dialogContext,
                                                ),
                                                child: const Text(
                                                  "취소",
                                                  style: TextStyle(
                                                    color: AppColors.secondary,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  // 입력된 문자열에서 숫자만 파싱
                                                  int? newTotal = int.tryParse(
                                                    totalEditController.text
                                                        .replaceAll(',', '')
                                                        .trim(),
                                                  );
                                                  if (newTotal != null &&
                                                      newTotal > 0) {
                                                    // 1️⃣ 바텀시트의 상태를 변경합니다.
                                                    setModalState(() {
                                                      // 전체 원본 금액을 새로 입력한 값으로 변경!
                                                      originalAmount = newTotal;

                                                      // 2️⃣ 바뀐 전체 금액 기준으로 1인당 정산 금액 재계산
                                                      int nPrice =
                                                          (originalAmount /
                                                                  settlementPeople)
                                                              .round();

                                                      // 3️⃣ 왼쪽 금액 필드란 텍스트 갱신
                                                      amountController.text =
                                                          "${formatter.format(nPrice)}원";
                                                    });
                                                  }
                                                  Navigator.pop(
                                                    dialogContext,
                                                  ); // 팝업 닫기
                                                },
                                                child: const Text(
                                                  "확인",
                                                  style: TextStyle(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors
                                          .click, // 마우스 커서 변경 효과
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(
                                            0.1,
                                          ), // 클릭 가능한 느낌을 주도록 옅은 포인트 컬러 부여
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppColors.primary
                                                .withOpacity(
                                                  0.2,
                                                ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              "전체 ${formatter.format(totalAmount)}원",
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: AppColors
                                                    .primary, // 텍스트 컬러도 포인트 컬러로 변경해 강조
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.edit,
                                              size: 14,
                                              color: AppColors.primary,
                                            ), // 수정 가능하다는 아이콘 표시
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 15),
                        const Divider(height: 1, color: AppColors.dividerColor),
                        const SizedBox(height: 15),
                        _buildInputRow(
                          "분류",
                          Row(
                            children: [
                              _buildTypeButton(
                                "지출",
                                selectedType == '지출',
                                () => setModalState(() {
                                  selectedType = '지출';
                                  // 타입을 바꿀 때 카테고리를 기본값으로 초기화하고 싶다면:
                                  selectedCategory = {
                                    'name': '미분류',
                                    'icon': '❓',
                                  };
                                }),
                              ),
                              const SizedBox(width: 10),
                              _buildTypeButton(
                                "수입",
                                selectedType == '수입',
                                () => setModalState(() {
                                  selectedType = '수입';
                                  // 타입을 바꿀 때 카테고리를 기본값으로 초기화하고 싶다면:
                                  selectedCategory = {
                                    'name': '미분류',
                                    'icon': '❓',
                                  };
                                }),
                              ),
                              const SizedBox(width: 10),
                              _buildTypeButton(
                                "이체",
                                selectedType == '이체',
                                () => setModalState(() {
                                  selectedType = '이체';
                                  // 타입을 바꿀 때 카테고리를 기본값으로 초기화하고 싶다면:
                                  selectedCategory = {
                                    'name': '미분류',
                                    'icon': '❓',
                                  };
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Divider(height: 1, color: AppColors.dividerColor),
                        const SizedBox(height: 15),
                        _buildInputRow(
                          "사용처",
                          TextField(
                            controller: placeController,
                            decoration: _inputFieldDecoration("입력하세요"),
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Divider(height: 1, color: AppColors.dividerColor),
                        const SizedBox(height: 15),
                        _buildInputRow(
                          "카테고리",
                          _buildSelectableBox(
                            "${selectedCategory['icon']} ${selectedCategory['name']}",
                            () async {
                              // 💡 현재 선택된 타입(selectedType)을 넘겨줍니다.
                              final result = await _showCategoryPicker(
                                selectedType == '이체' ? '지출' : selectedType,
                              );
                              if (result != null) {
                                setModalState(() => selectedCategory = result);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Divider(height: 1, color: AppColors.dividerColor),
                        const SizedBox(height: 15),
                        // 580라인 부근의 _buildInputRow 부분을 이렇게 수정하세요.
                        _buildInputRow(
                          "결제수단",
                          GestureDetector(
                            onTap: () => showPaymentPicker(setModalState),
                            child: Container(
                              height: fieldHeight,
                              decoration: BoxDecoration(
                                color: Colors.white, // 배경색 유지
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: Text(
                                        selectedPayment.isEmpty
                                            ? "결제수단 선택"
                                            : selectedPayment,
                                        style: TextStyle(
                                          color: selectedPayment.isEmpty
                                              ? AppColors.secondary
                                              : Colors.black,
                                          fontSize: 15,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.secondary,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Divider(height: 1, color: AppColors.dividerColor),
                        const SizedBox(height: 15),
                        _buildInputRow(
                          "정산하기",
                          _buildSelectableBox(
                            isSettlementActive
                                ? "$settlementPeople명 (${selectedFriends.length}명 선택됨)"
                                : "정산 안 함",
                            () => showSettlementPicker(setModalState),
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Divider(height: 1, color: AppColors.dividerColor),
                        const SizedBox(height: 15),
                        _buildInputRow(
                          "날짜",
                          _buildSelectableBox(
                            // 1. 표시 형식: yyyy. MM. dd HH:mm (예: 2023. 10. 25 14:30)
                            DateFormat('yyyy. MM. dd HH:mm').format(tempDate),
                            () async {
                              // 2. 먼저 날짜를 선택합니다.
                              final DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: tempDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                                locale: const Locale('ko', 'KR'),
                              );

                              if (pickedDate != null) {
                                // 3. 날짜 선택이 완료되면 바로 시간을 선택하는 창을 띄웁니다.
                                final TimeOfDay? pickedTime =
                                    await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(
                                        tempDate,
                                      ),
                                      // 한국어 설정이 되어 있다면 오전/오후로 표시됩니다.
                                    );

                                if (pickedTime != null) {
                                  // 4. 선택된 날짜와 시간을 합쳐서 tempDate를 업데이트합니다.
                                  setModalState(() {
                                    tempDate = DateTime(
                                      pickedDate.year,
                                      pickedDate.month,
                                      pickedDate.day,
                                      pickedTime.hour,
                                      pickedTime.minute,
                                    );
                                  });
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Divider(height: 1, color: AppColors.dividerColor),
                        const SizedBox(height: 15),
                        _buildInputRow(
                          "메모",
                          TextField(
                            controller: memoController,
                            decoration: _inputFieldDecoration("입력하세요"),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            if (docId != null) // 1. 수정 시에만 노출되는 [삭제] 버튼
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  height: 55,
                                  child: OutlinedButton(
                                    onPressed: () => _saveRecord(
                                      docId: docId,
                                      isDelete: true, // ✅ 삭제 버튼이므로 true가 맞습니다!
                                      type: '',
                                      amount: '',
                                      place: '',
                                      category: {},
                                      payment: '',
                                      bankName: '',
                                      date: DateTime.now(),
                                      memo: '',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: AppColors.fieldColor,
                                      ),
                                      backgroundColor: AppColors.fieldColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      "삭제",
                                      style: TextStyle(
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              // 2. 진짜 [저장 / 수정] 버튼
                              child: SizedBox(
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: () => _saveRecord(
                                    docId: docId,
                                    type: selectedType,
                                    amount: amountController.text,
                                    place: placeController.text,
                                    category: selectedCategory,
                                    payment: selectedPayment, // 카드 이름 전달
                                    bankName: selectedBankName, // 💡 은행 이름 전달
                                    date: tempDate,
                                    memo: memoController.text,
                                    isDelete: false, // ✅ 저장 버튼이므로 false가 맞습니다!
                                    isSettlement: isSettlementActive,
                                    sPeople: settlementPeople,
                                    sFriends: selectedFriends,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    docId == null ? "저장" : "수정",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDetailListSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: _getRecordsStream(), // 부모와 동일한 스트림 구독
        builder: (context, snapshot) {
          // 1. 실시간으로 현재 선택된 날짜의 데이터를 다시 계산합니다.
          List<Map<String, dynamic>> currentRecords = [];
          int income = 0;
          int expense = 0;

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              data['docId'] = doc.id;
              DateTime date = (data['date'] as Timestamp).toDate();

              // 🔥 현재 선택된 날짜와 같은 데이터만 실시간으로 모음
              if (isSameDay(date, _selectedDay)) {
                currentRecords.add(data);
                if (data['type'] == '수입') {
                  income += (data['amount'] as int);
                } else if (data['type'] == '지출' || data['type'] == '이체') {
                  // ✅ 이체도 상세창 지출 합산에 포함
                  expense += (data['amount'] as int);
                }
              }
            }
          }

          // 2. 💡 고정지출 내역 가져오기 (이 날짜에 해당하는 항목들만)
          List<Map<String, dynamic>> fixedRecordList = [];
          int dailyFixedTotal = 0;

          if (_selectedDay != null) {
            DateTime normalizedDate = DateTime(
              _selectedDay!.year,
              _selectedDay!.month,
              _selectedDay!.day,
            );
            int fixedTotal = _events[normalizedDate] ?? 0;

            // 💡 고정지출을 리스트에 추가하는 부분
            if (fixedTotal > 0) {
              Map<String, dynamic> fixedData = {
                'docId': 'fixed_${normalizedDate.millisecondsSinceEpoch}',
                'place': '고정지출',
                'amount': fixedTotal,
                'category': {'name': '고정지출', 'icon': '🗓️'},
                'type': '지출',
                'isFixed': true, // 💡 상세창에서 구분용 플래그
              };
              currentRecords.add(fixedData);
              expense += fixedTotal;
            }
          }

          // 만약 모든 내역이 삭제되어 비었다면 자동으로 팝업을 닫습니다.
          if (snapshot.hasData && currentRecords.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(context)) Navigator.pop(context);
            });
            return const SizedBox.shrink();
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            padding: const EdgeInsets.only(
              top: 24,
              bottom: 20,
              left: 24,
              right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 1. 상단 날짜 표시
                    Text(
                      DateFormat('M월 d일').format(_selectedDay!),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close), // 순수 아이콘만 사용
                    ),
                  ],
                ),
                const SizedBox(height: 20), // 날짜와 통계 사이 간격
                Row(
                  children: [
                    // 왼쪽 끝에 고정
                    Text(
                      "총 ${currentRecords.length}건",
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.secondary,
                      ),
                    ),

                    const Spacer(),

                    if (income > 0)
                      Text(
                        "+${NumberFormat('#,###').format(income)}원",
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),

                    if (income > 0 && expense > 0) const SizedBox(width: 10),

                    if (expense > 0)
                      Text(
                        "-${NumberFormat('#,###').format(expense)}원",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                  ],
                ),
                const Divider(
                  height: 30,
                  thickness: 1,
                  color: AppColors.dividerColor,
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: currentRecords.length,
                    itemBuilder: (context, index) {
                      final item = currentRecords[index];
                      final bool isFixedItem = item['isFixed'] ?? false;
                      final isIncome = item['type'] == '수입';

                      final icon = (item['category'] is Map)
                          ? item['category']['icon']
                          : '💰';
                      final catName = (item['category'] is Map)
                          ? item['category']['name']
                          : '미분류';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          if (isFixedItem) {
                            // 💡 고정지출 클릭 시 동작 (예: 상세 정보 팝업)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("고정지출 상세 내역입니다.")),
                            );
                          } else {
                            // 일반 지출/수입 상세 수정
                            _showAddRecordSheet(
                              initialData: item,
                              docId: item['docId'],
                            );
                          }
                        },
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.fieldColor,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['place'] ?? '사용처 없음',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                // 💡 디자인은 그대로, 고정지출만 보라색
                                color: isFixedItem
                                    ? Colors.purple
                                    : Colors.black,
                              ),
                            ),
                            Text(
                              catName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          "${isIncome ? '' : '-'}${NumberFormat('#,###').format(item['amount'])}원",
                          style: TextStyle(
                            fontSize: 16,
                            // 💡 금액 색상도 디자인 규칙에 맞게
                            color: isIncome
                                ? AppColors.primary
                                : (isFixedItem ? Colors.purple : Colors.black),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: const Text(
                      "확인",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 4. 기타 도우미 함수들 ---
  Widget _buildInputRow(String label, Widget field) => Row(
    children: [
      SizedBox(
        width: labelWidth,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
      ),
      Expanded(
        child: SizedBox(height: fieldHeight, child: field),
      ),
    ],
  );

  // InputDecoration과 선택 박스, 타입 버튼은 바텀시트에서 사용되는 UI 요소들로, 별도의 함수로 분리하여 재사용성을 높였습니다.
  InputDecoration _inputFieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: false, // 배경색 제거
    contentPadding: const EdgeInsets.symmetric(horizontal: 0), // 왼쪽 여백 제거
    border: InputBorder.none, // 테두리 제거
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
  );

  Widget _buildSelectableBox(String value, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 0), // 통일감을 위해 여백 제거
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 15, color: Colors.black),
          ),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.secondary,
          ), // 오른쪽 화살표
        ],
      ),
    ),
  );

  Widget _buildTypeButton(String title, bool isSelected, VoidCallback onTap) =>
      GestureDetector(
        // 1. Expanded를 삭제합니다.
        onTap: onTap,
        child: Container(
          width: 60, // 2. 원하는 너비값을 직접 지정합니다.
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.secondary.withAlpha(80),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: isSelected ? AppColors.primary : AppColors.secondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );

  Future<Map<String, String>?> _showCategoryPicker(String type) async {
    // 1. Firestore에서 해당 타입의 카테고리 가져오기
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('categories')
        .where('type', isEqualTo: type)
        .orderBy('index', descending: false) // 순서대로 정렬 추가
        .get();

    // 2. DB 데이터를 리스트로 변환
    List<Map<String, String>> currentCategories = snapshot.docs
        .map(
          (doc) => {
            'name': doc['name'].toString(),
            'icon': doc['icon'].toString(),
          },
        )
        .toList();

    return await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$type 카테고리 선택",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close), // 순수 아이콘만 사용
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 💡 격자 리스트 구성
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  childAspectRatio: 0.9,
                ),
                // 💡 마지막 칸에 '편집' 버튼을 넣기 위해 길이를 +1 합니다.
                itemCount: currentCategories.length + 1,
                itemBuilder: (context, i) {
                  // 💡 마지막 인덱스인 경우 '편집(설정)' 버튼 렌더링
                  if (i == currentCategories.length) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context); // 선택창 닫기
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Category(),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.fieldColor, // 설정 버튼 배경색 (회색톤)
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              "카테고리\n관리",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // 💡 일반 카테고리 아이템
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, currentCategories[i]),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.secondary.withAlpha(80),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            currentCategories[i]['icon']!,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentCategories[i]['name']!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("새 카테고리"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "카테고리 이름"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("추가"),
          ),
        ],
      ),
    );
  }

  void _saveRecord({
    String? docId,
    required String type,
    required String amount,
    required String place,
    required Map<String, dynamic> category,
    required String payment,
    required String bankName,
    required DateTime date,
    required String memo,
    bool isDelete = false, // 삭제 플래그
    bool isSettlement = false, // 추가
    int sPeople = 0, // 추가
    List<String> sFriends = const [], // 추가
  }) async {
    try {
      if (isDelete && docId != null) {
        // [삭제 로직]
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('records')
            .doc(docId)
            .delete();

        if (!mounted) return;
        // 수정창과 상세 팝업을 안전하게 닫음
        Navigator.of(context).pop();
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return;
      }

      if (amount.isEmpty || amount == "0원") return;

      String cleanAmount = amount
          .replaceAll(',', '')
          .replaceAll('원', '')
          .trim();
      int parsedAmount = int.tryParse(cleanAmount) ?? 0;

      final data = {
        'type': type,
        'amount': parsedAmount,
        'place': place,
        'category': category,
        'paymentMethod': payment,
        'bankName': bankName,
        'date': Timestamp.fromDate(date),
        'memo': memo,
        'receiptImage': _receiptImage?.path,
      };

      if (isSettlement) {
        data['settlement'] = {
          'people': sPeople,
          'friends': sFriends,
        };
      }

      if (docId != null && docId.isNotEmpty) {
        // [수정 로직]
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('records')
            .doc(docId)
            .update(data);

        if (!mounted) return;
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      } else {
        // [추가 로직]
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('records')
            .add(data);

        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("Error saving/deleting record: $e");
      // 에러 발생 시 사용자에게 알림을 주거나 안전하게 팝업 닫기
    }
  }
}
