import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rekeep/category.dart';
import 'package:flutter_rekeep/login.dart';
import 'package:image_picker/image_picker.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_rekeep/calendar_seeder.dart';
import 'package:flutter_rekeep/ads/interstitial_ad_manager.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class CategoryItem {
  final String name;
  final String icon;
  CategoryItem({required this.name, required this.icon});
}

const double labelWidth = 80.0;
const double fieldHeight = 45.0;

class _CalendarViewState extends State<CalendarView> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  // ✅ 누적 총자산 계산용 고정/변동지출·수입 원본 목록
  List<Map<String, dynamic>> _recurringRawItems = [];

  @override
  void initState() {
    super.initState();
    _listenToEvents();
    placeController.addListener(_autoAssignCategory);
  }

  void _loadSettings() async {
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('recurring_expenses')
        .doc('itemName')
        .get();
    if (doc.exists) {
      setState(() {
        fixedExpenseDisplayName = doc['fixedExpenseName'] ?? "고정지출";
      });
    }
  }

  StreamSubscription? _eventsSubscription;

  void _listenToEvents() {
    if (currentUserId == null) return;

    _eventsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('recurring_expenses')
        .snapshots()
        .listen((snapshot) async {
          final fixedDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .collection('settings')
              .doc('고정지출_items')
              .get();
          final variableDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .collection('settings')
              .doc('변동지출_items')
              .get();

          final fixedNames = List<String>.from(fixedDoc.data()?['list'] ?? []);
          final variableNames = List<String>.from(
            variableDoc.data()?['list'] ?? [],
          );

          Map<DateTime, List<Map<String, dynamic>>> fetchedEvents = {};

          const weekdayMap = {
            '월요일': 1,
            '화요일': 2,
            '수요일': 3,
            '목요일': 4,
            '금요일': 5,
            '토요일': 6,
            '일요일': 7,
          };

          final now = DateTime.now();

          void addEvent(
            DateTime date,
            String name,
            int amount,
            String expenseType,
          ) {
            fetchedEvents[date] ??= [];
            fetchedEvents[date]!.add({
              'name': name,
              'amount': amount,
              'expenseType': expenseType,
            });
          }

          for (var doc in snapshot.docs) {
            Map<String, dynamic> data = doc.data();
            int amount = (data['amount'] ?? 0) as int;
            String name = data['name'] ?? doc.id;
            String period = (data['period'] ?? '매월').toString();
            String dayData = (data['day'] ?? '1일').toString();
            String expenseType =
                data['expenseType'] ??
                (variableNames.contains(name) ? '변동지출' : '고정지출');

            final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

            if (period == '매월') {
              // ✅ 이번 달 딜레이가 설정돼 있으면 그 날짜로 표시
              int day = _effectiveRecurringDay(data, now);
              if (day <= daysInMonth) {
                addEvent(
                  DateTime(now.year, now.month, day),
                  name,
                  amount,
                  expenseType,
                );
              }
            } else if (period == '매주') {
              final targetWeekday = weekdayMap[dayData];
              if (targetWeekday != null) {
                for (int d = 1; d <= daysInMonth; d++) {
                  final date = DateTime(now.year, now.month, d);
                  if (date.weekday == targetWeekday) {
                    addEvent(date, name, amount, expenseType);
                  }
                }
              }
            } else if (period == '매일') {
              for (int d = 1; d <= daysInMonth; d++) {
                addEvent(
                  DateTime(now.year, now.month, d),
                  name,
                  amount,
                  expenseType,
                );
              }
            }
          }
          if (!mounted) return;
          setState(() {
            _events = fetchedEvents;
            _recurringRawItems = snapshot.docs.map((doc) {
              final m = Map<String, dynamic>.from(doc.data());
              m['_docId'] = doc.id;
              return m;
            }).toList();
          });
          // ✅ 오늘 예정된 고정/변동 항목 확인 팝업 (세션당 1회)
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _checkDueRecurringItems(),
          );
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

  Future<Map<DateTime, List<dynamic>>> _getCalendarEvents() async {
    Map<DateTime, List<dynamic>> events = {};

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('recurring_expenses')
        .get();

    for (var doc in snapshot.docs) {
      int day = doc['day'];
      String name = doc['name'];

      DateTime date = DateTime(DateTime.now().year, DateTime.now().month, day);
      if (events[date] == null) events[date] = [];
      events[date]!.add(name);
    }
    return events;
  }

  Function(String name, String icon)? _onCategoryAutoAssigned;

  DateTime _focusedDay = DateTime.now();
  DateTime tempDate = DateTime.now();
  DateTime? _selectedDay;
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final NumberFormat formatter = NumberFormat('#,###');

  final TextEditingController placeController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController memoController = TextEditingController();

  String category = '식비';
  String fixedExpenseDisplayName = "고정지출";

  bool isOcrLoading = false;
  bool _isMenuOpen = false;

  Map<String, String> selectedCategory = {'name': '미분류', 'icon': '？'};

  bool _isUserTouchedCategory = false;

  File? _receiptImage;

  Stream<QuerySnapshot> _getRecordsStream() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('records')
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime(
              _focusedDay.year,
              _focusedDay.month,
              1,
            ),
          ),
        )
        .where(
          'date',
          isLessThan: Timestamp.fromDate(
            DateTime(
              _focusedDay.year,
              _focusedDay.month + 1,
              1,
            ),
          ),
        )
        .snapshots();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
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

    final Map<String, Map<String, String>> categoryMap = {
      '식비': {'name': '식비', 'icon': '🍴'},
      '카페/간식': {'name': '카페/간식', 'icon': '🥤'},
      '마트/편의점': {'name': '마트/편의점', 'icon': '🛒'},
      '교통': {'name': '교통', 'icon': '🚘'},
      '쇼핑': {'name': '쇼핑', 'icon': '🛍️'},
      '의료': {'name': '의료', 'icon': '🏥'},
      '주거/통신': {'name': '주거/통신', 'icon': '🏠'},
      '문화/여가': {'name': '문화/여가', 'icon': '🎬'},
      '뷰티/미용': {'name': '뷰티/미용', 'icon': '💄'},
      '반려동물': {'name': '반려동물', 'icon': '🐶'},
      '취미': {'name': '취미', 'icon': '🎨'},
      '교육': {'name': '교육', 'icon': '📚'},
      '여행': {'name': '여행', 'icon': '✈️'},
      '술/유흥': {'name': '술/유흥', 'icon': '🍺'},
    };

    final Map<String, List<String>> keywords = {
      '식비': [
        '식당',
        '밥',
        '배달',
        '식료품',
        '고기',
        '국밥',
        '짜장면',
        '짬뽕',
        '치킨',
        '피자',
        '한식',
        '중식',
        '일식',
        '분식',
        '김밥',
        '라면',
        '돈까스',
        '햄버거',
        '맥도날드',
        '버거킹',
        'KFC',
        '롯데리아',
        '맘스터치',
        '배달의민족',
        '한집배달'
            '요기요',
        '쿠팡이츠',
        '도미노',
        '굽네',
        '교촌',
        '네네',
        '서브웨이',
        '이삭',
        '죠스',
        '김치찌개',
        '삼겹살',
        '냉면',
        '우동',
        '순대',
        '떡볶이',
        '포장마차',
        '식사',
        '점심',
        '저녁',
        '아침',
      ],
      '카페/간식': [
        '카페',
        '커피',
        '스타벅스',
        '이디야',
        '빽다방',
        '메가커피',
        '컴포즈',
        '투썸',
        '할리스',
        '폴바셋',
        '블루보틀',
        '던킨',
        '배스킨',
        '베스킨',
        '디저트',
        '빵',
        '베이커리',
        '파리바게트',
        '뚜레쥬르',
        '성심당',
        '아이스크림',
        '케이크',
        '마카롱',
        '도넛',
        '와플',
        '버블티',
        '쥬스',
        '음료',
        '간식',
        '과자',
      ],
      '마트/편의점': [
        'CU',
        'GS25',
        '세븐일레븐',
        '이마트24',
        '미니스톱',
        '편의점',
        '이마트',
        '홈플러스',
        '롯데마트',
        '코스트코',
        '다이소',
        '마트',
        '슈퍼',
        '시장',
        '마켓',
      ],
      '교통': [
        '택시',
        '버스',
        '지하철',
        '주유',
        '주유소',
        'KTX',
        'SRT',
        '기차',
        '대리',
        '주차',
        '톨게이트',
        '고속도로',
        '카카오T',
        '우버',
        'GS칼텍스',
        'SK에너지',
        'S-OIL',
        '오일뱅크',
        '충전',
        '전기차',
        '항공',
        '공항',
      ],
      '쇼핑': [
        '쿠팡',
        '네이버쇼핑',
        '옷',
        '의류',
        '신발',
        '백화점',
        '아울렛',
        '올리브영',
        '무신사',
        '29CM',
        '지그재그',
        '에이블리',
        '유니클로',
        '자라',
        'H&M',
        '나이키',
        '아디다스',
        '뉴발란스',
        '롯데백화점',
        '현대백화점',
        '신세계',
        '갤러리아',
        '가방',
        '악세서리',
        '시계',
      ],
      '의료': [
        '병원',
        '의원',
        '치과',
        '한의원',
        '약국',
        '클리닉',
        '정형외과',
        '내과',
        '피부과',
        '안과',
        '이비인후과',
        '산부인과',
        '소아과',
        '심리',
        '상담',
        '검진',
        '건강',
      ],
      '주거/통신': [
        '통신',
        'SKT',
        'KT',
        'LG U+',
        '알뜰폰',
        '인터넷',
        '관리비',
        '전기세',
        '가스비',
        '수도',
        '월세',
        '렌트',
        '보험',
        '청구',
      ],
      '문화/여가': [
        '영화',
        'CGV',
        '롯데시네마',
        '메가박스',
        '노래방',
        '헬스',
        '운동',
        '게임',
        '책',
        '도서',
        '교보문고',
        '예스24',
        '알라딘',
        '공연',
        '전시',
        '뮤지컬',
        '콘서트',
        '스포츠',
        '수영',
        '요가',
        '필라테스',
        '클라이밍',
        '볼링',
        '당구',
        '골프',
        '테니스',
      ],
      '뷰티/미용': [
        '미용실',
        '헤어',
        '네일',
        '피부',
        '마사지',
        '왁싱',
        '속눈썹',
        '화장품',
        '코스메틱',
        '이니스프리',
        '에뛰드',
        '아리따움',
        '미샤',
      ],
      '반려동물': [
        '동물병원',
        '펫',
        '애견',
        '고양이',
        '강아지',
        '사료',
        '간식',
        '펫샵',
        '반려',
      ],
      '취미': [
        '취미',
        '공방',
        '악기',
        '기타',
        '피아노',
        '그림',
        '사진',
        '낚시',
        '등산',
        '캠핑',
        '여가',
      ],
      '교육': [
        '학원',
        '과외',
        '교육',
        '학습',
        '영어',
        '수학',
        '학교',
        '대학교',
        '어학원',
        '인강',
        '클래스',
        '강의',
        '강좌',
        '수강',
      ],
      '여행': [
        '여행',
        '호텔',
        '숙박',
        '에어비앤비',
        '펜션',
        '리조트',
        '항공권',
        '여행사',
        '투어',
        '면세점',
        '해외',
        '제주',
      ],
      '술/유흥': [
        '술',
        '맥주',
        '소주',
        '막걸리',
        '와인',
        '위스키',
        '바',
        '포차',
        '호프',
        '이자카야',
        '클럽',
        '유흥',
      ],
    };

    for (var entry in keywords.entries) {
      String categoryName = entry.key;
      for (String keyword in entry.value) {
        if (text.toLowerCase().contains(keyword.toLowerCase())) {
          // ✅ 콜백으로 로컬 변수 업데이트
          _onCategoryAutoAssigned?.call(
            categoryName,
            categoryMap[categoryName]!['icon']!,
          );
          return;
        }
      }
    }
  }

  StateSetter? _modalStateSetter;

  void _updateModalCategory(String name, String icon) {
    if (_modalStateSetter != null) {
      _modalStateSetter!(() {
        // selectedCategory = {'name': name, 'icon': icon};
      });
    }
  }

  void _resetForm() {
    _isUserTouchedCategory = false;
    placeController.clear();
    amountController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
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
                  backgroundColor: AppColors.primary(context),
                  shape: const CircleBorder(),
                  onPressed: () {
                    final user = FirebaseAuth.instance.currentUser;

                    if (user == null) {
                      _showLoginRequiredDialog(context);
                    } else {
                      setState(() => _isMenuOpen = true);
                    }
                  },
                  child: Icon(
                    Icons.add,
                    color: AppColors.background(context),
                    size: 28,
                  ),
                ),
              ),
      ),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        surfaceTintColor: AppColors.background(context),
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(
                  () => _focusedDay = DateTime(
                    _focusedDay.year,
                    _focusedDay.month - 1,
                  ),
                ),
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  Icons.chevron_left,
                  color: AppColors.textPrimary(context),
                  size: 28,
                ),
              ),

              Text(
                DateFormat('M월').format(_focusedDay),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                  fontSize: 18,
                ),
              ),

              GestureDetector(
                onTap: () => setState(
                  () => _focusedDay = DateTime(
                    _focusedDay.year,
                    _focusedDay.month + 1,
                  ),
                ),
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  Icons.chevron_right,
                  color: AppColors.textPrimary(context),
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

              // ✅ 상단 수입/지출/총자산 합계는 오늘 날짜까지만 반영
              // (달력 셀과 날짜별 상세에는 오늘 이후 내역도 그대로 표시)
              final DateTime nowForSummary = DateTime.now();
              final DateTime endOfToday = DateTime(
                nowForSummary.year,
                nowForSummary.month,
                nowForSummary.day,
                23,
                59,
                59,
              );

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  data['docId'] = doc.id;

                  DateTime date = (data['date'] as Timestamp).toDate();
                  String dateKey = DateFormat('yyyy-MM-dd').format(date);

                  if (!dailyRecords.containsKey(dateKey)) {
                    dailyRecords[dateKey] = [];
                  }

                  dailyRecords[dateKey]!.add(data);

                  if (date.isAfter(endOfToday)) continue;

                  if (data['type'] == '수입' || data['type'] == '이체(수입)') {
                    totalIncome += (data['amount'] as int);
                  } else if (data['type'] == '지출' || data['type'] == '이체(지출)') {
                    totalExpense += (data['amount'] as int);
                  }
                }
              }

              _events.forEach((date, items) {
                if (date.year == _focusedDay.year &&
                    date.month == _focusedDay.month &&
                    !date.isAfter(endOfToday)) {
                  for (var item in items) {
                    // ✅ 고정/변동수입은 수입으로 합산
                    final String et = (item['expenseType'] ?? '고정지출') as String;
                    if (et.contains('수입')) {
                      totalIncome += (item['amount'] as int);
                    } else {
                      totalExpense += (item['amount'] as int);
                    }
                  }
                }
              });

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
                        left: 12,
                        right: 12,
                        top: 5,
                      ),
                      child: TableCalendar(
                        locale: 'ko_KR',
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        availableGestures: AvailableGestures.horizontalSwipe,
                        onPageChanged: (focusedDay) {
                          setState(() {
                            _focusedDay = focusedDay;
                            _selectedDay = null;
                          });
                        },
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

                          bool hasRecord =
                              (dailyRecords.containsKey(dateKey) &&
                              dailyRecords[dateKey]!.isNotEmpty);
                          bool hasFixed =
                              (_events[normalizedDay]?.isNotEmpty ?? false);

                          _showDetailListSheet();
                        },
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (date.month != _focusedDay.month) return null;

                            DateTime normalizedDay = DateTime(
                              date.year,
                              date.month,
                              date.day,
                            );
                            // ✅ 수입 타입은 무지출 판정에서 제외
                            int fixedAmount = (_events[normalizedDay] ?? [])
                                .fold(
                                  0,
                                  (sum, item) =>
                                      ((item['expenseType'] ?? '고정지출')
                                              as String)
                                          .contains('수입')
                                      ? sum
                                      : sum + (item['amount'] as int),
                                );

                            String dateKey = DateFormat(
                              'yyyy-MM-dd',
                            ).format(date);

                            bool hasExpense = false;
                            if (dailyRecords.containsKey(dateKey)) {
                              for (var record in dailyRecords[dateKey]!) {
                                if (record['type'] == '지출' ||
                                    record['type'] == '이체(지출)') {
                                  hasExpense = true;
                                  break;
                                }
                              }
                            }
                            bool hasNoExpense = !hasExpense && fixedAmount == 0;

                            if (!hasNoExpense && fixedAmount == 0) return null;

                            return Positioned(
                              top: 10,
                              left: 0,
                              right: 0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasNoExpense)
                                    Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.only(bottom: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary(context),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },

                          defaultBuilder: (context, date, _) => _buildDayCell(
                            date,
                            (date.weekday == 7 || date.weekday == 6)
                                ? AppColors.secondary
                                : AppColors.textPrimary(context),
                            dailyRecords,
                            _events,
                            false,
                          ),

                          todayBuilder: (context, date, _) => _buildDayCell(
                            date,
                            AppColors.primary(context),
                            dailyRecords,
                            _events,
                            isSameDay(_selectedDay, date),
                            isToday: true,
                          ),
                          selectedBuilder: (context, date, _) {
                            bool isToday = isSameDay(date, DateTime.now());
                            return _buildDayCell(
                              date,
                              isToday
                                  ? AppColors.primary(context)
                                  : (date.weekday == 7 || date.weekday == 6
                                        ? AppColors.secondary
                                        : AppColors.textPrimary(context)),
                              dailyRecords,
                              _events,
                              false,
                              isToday: isToday,
                            );
                          },
                        ),
                        calendarStyle: CalendarStyle(
                          markersMaxCount: 0,
                          markerDecoration: BoxDecoration(
                            color: AppColors.primary(context),
                            shape: BoxShape.circle,
                          ),
                          outsideDaysVisible: false,
                          selectedDecoration: BoxDecoration(
                            color: AppColors.textPrimary(context),
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: AppColors.textPrimary(context),
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontWeight: FontWeight.normal,
                          ),
                          todayTextStyle: TextStyle(
                            color: AppColors.primary(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        eventLoader: (day) {
                          DateTime normalizedDay = DateTime(
                            day.year,
                            day.month,
                            day.day,
                          );
                          String dateKey = DateFormat('yyyy-MM-dd').format(day);

                          List<dynamic> events = [];

                          if (dailyRecords.containsKey(dateKey) &&
                              dailyRecords[dateKey]!.isNotEmpty) {
                            events.addAll(dailyRecords[dateKey]!);
                          }

                          int fixedAmount = (_events[normalizedDay] ?? []).fold(
                            0,
                            (sum, item) => sum + (item['amount'] as int),
                          );

                          if (fixedAmount > 0) {
                            events.add({
                              'isFixed': true,
                              'amount': fixedAmount,
                            });
                          }

                          return events;
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          if (_isMenuOpen) ...[
            GestureDetector(
              onTap: () => setState(() => _isMenuOpen = false),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: AppColors.background(context).withOpacity(0.9),
              ),
            ),
            Positioned(
              bottom: 24,
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
                      _pickImageFromCamera();
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildSubMenuButton(
                    icon: Icons.image_rounded,
                    label: "갤러리에서 영수증 가져오기",
                    onTap: () {
                      setState(() => _isMenuOpen = false);
                      _pickImageFromGallery();
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildSubMenuButton(
                    icon: Icons.edit_rounded,
                    label: "직접 입력하기",
                    onTap: () {
                      setState(() => _isMenuOpen = false);
                      _showAddRecordSheet();
                    },
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: 55,
                    height: 55,
                    child: FloatingActionButton(
                      backgroundColor: AppColors.primary(context),
                      shape: const CircleBorder(),
                      onPressed: () => setState(() => _isMenuOpen = false),
                      child: Icon(
                        Icons.close,
                        color: AppColors.background(context),
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

  void _showLoginRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "로그인 필요",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "내역을 추가하려면 로그인이 필요합니다.\n로그인 페이지로 이동할까요?",
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
              "확인",
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
  }

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
            // + 버튼 목록
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: AppColors.background(context),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: AppColors.primary(context),
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
        await _analyzeReceipt(pickedFile.path);
      } else {
        print("이미지 선택이 취소되었습니다.");
      }
    } catch (e) {
      print("이미지를 가져오는 도중 에러 발생: $e");
    }
  }

  Future<void> _pickImageFromCamera() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera, // ✅ 갤러리 대신 카메라
      );

      if (pickedFile != null) {
        print("카메라 촬영 성공: ${pickedFile.path}");
        setState(() {
          _receiptImage = File(pickedFile.path);
        });
        await _analyzeReceipt(pickedFile.path);
      } else {
        print("촬영이 취소되었습니다.");
      }
    } catch (e) {
      print("카메라 오류: $e");
    }
  }

  Future<Map<String, dynamic>?> _analyzeReceipt(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.korean);
    final inputImage = InputImage.fromFilePath(imagePath);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      String scannedText = recognizedText.text;

      // OCR이 콤마를 마침표·중간점 등으로 잘못 인식하는 경우 정규화
      // 숫자 1~3자리 뒤에 오는 '.', '·' → ',' 로 변환
      scannedText = scannedText.replaceAllMapped(
        RegExp(r'(\d{1,3})[.·](\d{3})(?=\D|$)'),
        (m) => '\${m.group(1)},\${m.group(2)}',
      );

      List<String> lines = scannedText
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      String compactText = scannedText.replaceAll(' ', '');

      String detectedStore = "";
      final List<Map<String, String>> brandKeywords = [
        {'keyword': 'CU', 'name': 'CU'},
        {'keyword': 'GS25', 'name': 'GS25'},
        {'keyword': 'GS 25', 'name': 'GS25'},
        {'keyword': '세븐일레븐', 'name': '세븐일레븐'},
        {'keyword': '이마트24', 'name': '이마트24'},
        {'keyword': '미니스톱', 'name': '미니스톱'},
        {'keyword': '스타벅스', 'name': '스타벅스'},
        {'keyword': 'STARBUCKS', 'name': '스타벅스'},
        {'keyword': '맥도날드', 'name': '맥도날드'},
        {'keyword': 'McDonald', 'name': '맥도날드'},
        {'keyword': '버거킹', 'name': '버거킹'},
        {'keyword': 'KFC', 'name': 'KFC'},
        {'keyword': '롯데리아', 'name': '롯데리아'},
        {'keyword': '올리브영', 'name': '올리브영'},
        {'keyword': '이마트', 'name': '이마트'},
        {'keyword': '홈플러스', 'name': '홈플러스'},
        {'keyword': '코스트코', 'name': '코스트코'},
        {'keyword': '다이소', 'name': '다이소'},
        {'keyword': '카카오', 'name': '카카오'},
        {'keyword': '배민', 'name': '배달의민족'},
        {'keyword': '배민1', 'name': '배달의민족'},
        {'keyword': '알뜰배달', 'name': '배달의민족'},
        {'keyword': '한집배달', 'name': '배달의민족'},
        {'keyword': '배달의민족', 'name': '배달의민족'},
        {'keyword': '쿠팡', 'name': '쿠팡'},
        {'keyword': '네이버', 'name': '네이버'},
        {'keyword': 'baskin', 'name': '배스킨라빈스'},
        {'keyword': 'robbins', 'name': '배스킨라빈스'},
        {'keyword': 'BASKIN', 'name': '배스킨라빈스'},
        {'keyword': '베스킨', 'name': '배스킨라빈스'},
        {'keyword': '배스킨', 'name': '배스킨라빈스'},
        {'keyword': '파리바게뜨', 'name': '파리바게뜨'},
        {'keyword': '뚜레쥬르', 'name': '뚜레쥬르'},
        {'keyword': '이디야', 'name': '이디야'},
        {'keyword': '메가커피', 'name': '메가커피'},
        {'keyword': '빽다방', 'name': '빽다방'},
      ];
      for (var brand in brandKeywords) {
        if (compactText.toUpperCase().contains(
          brand['keyword']!.toUpperCase(),
        )) {
          detectedStore = brand['name']!;
          break;
        }
      }
      if (detectedStore.isEmpty) {
        final skipPatterns = RegExp(
          r'영수증|매출|승인|사업자|TEL|전화|FAX|\d{3}-\d{4}|\d{9,}|^\d+$',
        );
        for (int i = 0; i < lines.length && i < 8; i++) {
          String line = lines[i];
          if (line.length < 2 || skipPatterns.hasMatch(line)) continue;
          if (RegExp(r'^[\d\s\-\.\:\*\/\\]+$').hasMatch(line)) continue;
          detectedStore = line
              .replaceAll(RegExp(r'\s*(점|지점|매장|store)$'), '')
              .trim();
          if (detectedStore.isNotEmpty) break;
        }
      }
      if (detectedStore.isEmpty) detectedStore = "일반 가맹점";

      int year = DateTime.now().year;
      int month = DateTime.now().month;
      int day = DateTime.now().day;
      int hour = 12, minute = 0;
      bool dateFound = false;

      // 날짜 패턴: YYYY-MM-DD, YYYY/MM/DD, YYYY.MM.DD
      final dateRegex4 = RegExp(r'(\d{4})[-./](\d{1,2})[-./](\d{1,2})');
      // 날짜 패턴: YY-MM-DD, YY/MM/DD
      final dateRegex2 = RegExp(r'(\d{2})[-./](\d{1,2})[-./](\d{1,2})');
      // 한글 날짜: 2026년 05월 31일
      final dateRegexKr = RegExp(r'(\d{4})년\s*(\d{1,2})월\s*(\d{1,2})일');
      // 시간 패턴
      final timeRegex = RegExp(r'(\d{2}):(\d{2})(?::(\d{2}))?');

      for (String line in lines) {
        String clean = line.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim();
        String cleanNoSpace = clean.replaceAll(' ', '');

        // 한글 날짜 먼저 시도
        final dkr = dateRegexKr.firstMatch(clean);
        if (dkr != null) {
          year = int.parse(dkr.group(1)!);
          month = int.parse(dkr.group(2)!);
          day = int.parse(dkr.group(3)!);
          dateFound = true;
        }

        if (!dateFound) {
          final dm4 = dateRegex4.firstMatch(cleanNoSpace);
          if (dm4 != null) {
            int y = int.parse(dm4.group(1)!);
            int m = int.parse(dm4.group(2)!);
            int d = int.parse(dm4.group(3)!);
            if (y >= 2020 && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
              year = y;
              month = m;
              day = d;
              dateFound = true;
            }
          }
        }

        if (!dateFound) {
          final dm2 = dateRegex2.firstMatch(cleanNoSpace);
          if (dm2 != null) {
            int y = 2000 + int.parse(dm2.group(1)!);
            int m = int.parse(dm2.group(2)!);
            int d = int.parse(dm2.group(3)!);
            if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
              year = y;
              month = m;
              day = d;
              dateFound = true;
            }
          }
        }

        // 시간 파싱 (날짜와 같은 줄 또는 별도 줄)
        final tm = timeRegex.firstMatch(cleanNoSpace);
        if (tm != null) {
          int h = int.parse(tm.group(1)!);
          if (h >= 0 && h <= 23) {
            hour = h;
            minute = int.parse(tm.group(2)!);
          }
        }

        if (dateFound && hour != 12) break;
      }
      DateTime detectedDate = DateTime(year, month, day, hour, minute);

      int? detectedAmount;

      final amountKeywords = [
        '결제금액',
        '청구금액',
        '사용금액',
        '합계금액',
        '총구매액',
        '총구매',
        '받을금액',
        '받은금액',
        '총매출액',
        '총결제금액',
        '합계',
        '총합계',
        'TOTAL',
        'Total',
        'total',
        '승인금액',
        '거래금액',
      ];

      // 결제금액이 아닌 금액(기프티콘 잔액 등)을 제외하기 위한 키워드
      final excludeKeywords = [
        '잔액',
        '잔여',
        '잔여금액',
        '잔여액',
        '남은금액',
        '충전',
        '충전금액',
        '포인트',
        '적립',
        '상품금액', // 기프티콘 원가(사용금액과 다를 수 있음)
        '액면',
        '액면가',
      ];

      // 1차: 키워드 포함 라인에서 금액 추출 (역순으로 - 합계가 보통 하단)
      for (String line in lines.reversed.toList()) {
        String clean = line.replaceAll(' ', '');
        // 잔액/포인트 등 결제금액이 아닌 줄은 건너뜀
        if (excludeKeywords.any((kw) => clean.contains(kw))) continue;
        bool hasKeyword = amountKeywords.any((kw) => clean.contains(kw));
        if (hasKeyword) {
          // 음수(할인) 제외
          if (clean.contains('-')) continue;
          final match = RegExp(
            r'(\d{1,3}(?:,\d{3})+|\d{3,7})',
          ).firstMatch(clean);
          if (match != null) {
            int? val = int.tryParse(match.group(0)!.replaceAll(',', ''));
            if (val != null && val >= 100) {
              detectedAmount = val;
              break;
            }
          }
        }
      }

      // 2차: 키워드 없으면 콤마 있는 금액 중 가장 큰 값
      //      (단, 잔액/포인트 등 제외 키워드가 있는 줄은 제외)
      if (detectedAmount == null) {
        List<int> candidates = [];
        for (String line in lines) {
          String clean = line.replaceAll(' ', '');
          if (excludeKeywords.any((kw) => clean.contains(kw))) continue;
          final lineMatches = RegExp(r'\d{1,3}(?:,\d{3})+').allMatches(clean);
          for (var m in lineMatches) {
            int? val = int.tryParse(m.group(0)!.replaceAll(',', ''));
            if (val != null && val >= 1000 && val <= 1000000) {
              candidates.add(val);
            }
          }
        }
        if (candidates.isNotEmpty) {
          candidates.sort();
          detectedAmount = candidates.last;
        }
      }

      // 3차: 콤마 없는 4~6자리 숫자 (예: 15000)
      if (detectedAmount == null) {
        for (String line in lines.reversed.toList()) {
          String clean = line.replaceAll(' ', '').replaceAll(',', '');
          if (excludeKeywords.any((kw) => clean.contains(kw))) continue;
          bool hasKeyword = amountKeywords.any((kw) => line.contains(kw));
          if (hasKeyword) {
            final match = RegExp(
              r'(\d{4,7})',
            ).firstMatch(clean.replaceAll(RegExp(r'[^\d]'), ' ').trim());
            if (match != null) {
              int? val = int.tryParse(match.group(0)!);
              if (val != null && val >= 1000 && val <= 1000000) {
                detectedAmount = val;
                break;
              }
            }
          }
        }
      }

      Map<String, String> categoryMap = {'name': '기타', 'icon': '✨'};
      final categoryRules = [
        {
          'keywords': ['CU', 'GS25', '세븐일레븐', '이마트24', '미니스톱', '편의점'],
          'name': '마트/편의점',
          'icon': '🛒',
        },

        {
          'keywords': ['배스킨', '베스킨', 'baskin', 'robbins', '아이스크림', '빙수'],
          'name': '카페/간식',
          'icon': '🥤',
        },

        {
          'keywords': ['스타벅스', '카페', '커피', '베이커리', '빵', '디저트', '파리바게뜨', '뚜레쥬르'],
          'name': '카페/간식',
          'icon': '🥤',
        },
        {
          'keywords': [
            '맥도날드',
            '버거킹',
            'KFC',
            '롯데리아',
            '식당',
            '음식점',
            '한식',
            '중식',
            '일식',
            '치킨',
            '피자',
            '분식',
            '고기',
            '삼겹',
            '돈까스',
            '김밥',
            '배민'
                '배민1'
                '배달의민족',
          ],
          'name': '식비',
          'icon': '🍴',
        },
        {
          'keywords': ['이마트', '홈플러스', '롯데마트', '코스트코', '마트'],
          'name': '마트/편의점',
          'icon': '🛒',
        },
        {
          'keywords': ['올리브영', '다이소', '쇼핑', '패션', '옷', '신발', '가방'],
          'name': '쇼핑',
          'icon': '🛍️',
        },
        {
          'keywords': ['지하철', '버스', '택시', '카카오T', 'T머니', '교통'],
          'name': '교통',
          'icon': '🚘',
        },
        {
          'keywords': ['병원', '약국', '의원', '치과', '한의원', '클리닉'],
          'name': '의료',
          'icon': '🏥',
        },
        {
          'keywords': ['술', '맥주', '소주', '막걸리', '와인', '바', '포차'],
          'name': '술/유흥',
          'icon': '🍺',
        },
      ];
      for (var rule in categoryRules) {
        final keywords = rule['keywords'] as List<String>;
        bool matched = keywords.any(
          (kw) =>
              detectedStore.contains(kw) ||
              compactText.toUpperCase().contains(kw.toUpperCase()),
        );
        if (matched) {
          categoryMap = {
            'name': rule['name'] as String,
            'icon': rule['icon'] as String,
          };
          break;
        }
      }

      String detectedPayment = "";
      if (currentUserId != null) {
        final cardSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('my_cards')
            .get();
        for (var doc in cardSnapshot.docs) {
          final data = doc.data();
          final cardNumber = (data['cardNumber'] ?? '').toString().trim();
          if (cardNumber.isEmpty) continue;

          final cardPatterns = [
            RegExp(r'\*+[\s\-]*' + cardNumber, caseSensitive: false),
            RegExp(r'\*[\s\-]*' + cardNumber),
            RegExp(r'[\-\s]' + cardNumber + r'(?:\s|$)', multiLine: true),
            RegExp(cardNumber + r'$', multiLine: true),
          ];

          bool matched =
              cardPatterns.any((p) => p.hasMatch(scannedText)) ||
              RegExp(
                r'[^\d]' + cardNumber + r'$',
                multiLine: true,
              ).hasMatch(compactText);

          if (matched) {
            String cardName = data['cardName'] ?? '';
            detectedPayment = '$cardName($cardNumber)';
            break;
          }
        }
      }
      if (detectedPayment.isEmpty) {
        if (compactText.contains('카카오페이') || compactText.contains('카카오Pay'))
          detectedPayment = '카카오페이';
        else if (compactText.contains('네이버페이'))
          detectedPayment = '네이버페이';
        else if (compactText.contains('삼성페이'))
          detectedPayment = '삼성페이';
        else if (compactText.contains('애플페이'))
          detectedPayment = '애플페이';
        else if (compactText.contains('토스'))
          detectedPayment = '토스';
      }

      final bool isCash =
          compactText.contains('현금영수증') || compactText.contains('현금');

      Map<String, dynamic> receiptData = {
        'place': detectedStore,
        'amount': detectedAmount ?? 0,
        'memo': '',
        'category': categoryMap,
        'type': '지출',
        'date': Timestamp.fromDate(detectedDate),
        'paymentMethod': isCash ? '현금' : detectedPayment,
        'bankName': isCash ? '현금' : detectedPayment,
      };

      if (isOcrLoading) {
        return receiptData;
      } else {
        _showAddRecordSheet(initialData: receiptData);
        return receiptData;
      }
    } catch (e) {
      print("OCR 분석 중 에러 발생: $e");
      _showAddRecordSheet();
      return null;
    } finally {
      textRecognizer.close();
    }
  }

  Widget _buildDayCell(
    DateTime date,
    Color textColor,
    Map dailyRecords,
    Map<DateTime, List<Map<String, dynamic>>> fixedExpenses,
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
        if (r['type'] == '수입' || r['type'] == '이체(수입)') {
          income += (r['amount'] as int);
        } else if (r['type'] == '지출' || r['type'] == '이체(지출)') {
          expense += (r['amount'] as int);
        }
      }
    }

    DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    // ✅ 고정 항목을 수입/지출로 분리
    int fixedAmount = 0;
    int fixedIncomeAmount = 0;
    for (var item in (fixedExpenses[normalizedDate] ?? [])) {
      final String et = (item['expenseType'] ?? '고정지출') as String;
      if (et.contains('수입')) {
        fixedIncomeAmount += (item['amount'] as int);
      } else {
        fixedAmount += (item['amount'] as int);
      }
    }

    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          '${date.day}',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: isToday
                ? FontWeight.bold
                : (isSelected ? FontWeight.bold : FontWeight.normal),
          ),
        ),
        SizedBox(
          height: 26,
          child: Builder(
            builder: (context) {
              List<({String text, Color color})> items = [];

              if (income + fixedIncomeAmount > 0) {
                items.add((
                  text:
                      "+${NumberFormat('#,###').format(income + fixedIncomeAmount)}",
                  color: AppColors.primary(context),
                ));
              }
              if (expense + fixedAmount > 0) {
                items.add((
                  text:
                      "-${NumberFormat('#,###').format(expense + fixedAmount)}",
                  color: AppColors.secondary,
                ));
              }

              const int maxVisible = 2;
              final visibleItems = items.take(maxVisible).toList();

              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  children: [
                    ...visibleItems.map(
                      (item) => Text(
                        item.text,
                        style: TextStyle(
                          fontSize: 8,
                          color: item.color,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
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
        color: AppColors.background(context),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.1),
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
              _amountRow("수입", income, AppColors.primary(context)),
              _amountRow("지출", expense, AppColors.secondary),
            ],
          ),
          Divider(
            height: 30,
            thickness: 1,
            color: AppColors.divider(context),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "총 자산",
                style: TextStyle(fontSize: 12, color: AppColors.secondary),
              ),
              _buildCumulativeAssetText(),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ 누적 총자산 (오늘 날짜 기준)
  // - 첫 기록 ~ 오늘까지의 records 합산 (오늘 이후 날짜 제외)
  // - 미래 달은 0원 (그 달이 실제로 되면 이전 달 자산이 자동 반영)
  // - 고정/변동지출·수입은 현재 달을 볼 때만, 결제일이 오늘 이전인 항목만 반영
  Widget _buildCumulativeAssetText() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('records')
          .where(
            'date',
            isLessThan: DateTime(_focusedDay.year, _focusedDay.month + 1, 1),
          )
          .snapshots(),
      builder: (context, snapshot) {
        final DateTime now = DateTime.now();
        final DateTime currentMonthStart = DateTime(now.year, now.month, 1);
        final DateTime focusedMonthStart = DateTime(
          _focusedDay.year,
          _focusedDay.month,
          1,
        );
        // ✅ 미래 달은 아직 시작 전이므로 0원
        // (그 달이 실제로 되면 이전 달까지의 자산이 자동 반영됨)
        if (focusedMonthStart.isAfter(currentMonthStart)) {
          return const Text(
            "0원",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          );
        }
        final bool isCurrentMonthView = focusedMonthStart.isAtSameMomentAs(
          currentMonthStart,
        );
        final DateTime endOfToday = DateTime(
          now.year,
          now.month,
          now.day,
          23,
          59,
          59,
        );

        int total = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['date'];
            if (ts is! Timestamp) continue;
            // ✅ 오늘 이후 날짜의 기록은 제외
            if (ts.toDate().isAfter(endOfToday)) continue;
            final int amount = (data['amount'] ?? 0) as int;
            final String type = (data['type'] ?? '지출').toString();
            if (type == '수입' || type == '이체(수입)') {
              total += amount;
            } else if (type == '지출' || type == '이체(지출)') {
              total -= amount;
            }
          }
        }

        // ✅ 고정/변동지출·수입은 현재 달을 볼 때만,
        // 결제일(딜레이 반영)이 오늘 이전인 항목만 반영
        if (isCurrentMonthView) {
          for (var item in _recurringRawItems) {
            final int amount = (item['amount'] ?? 0) as int;
            final int day = _effectiveRecurringDay(item, now);
            if (day > now.day) continue;

            final String et = (item['expenseType'] ?? '고정지출').toString();
            total += et.contains('수입') ? amount : -amount;
          }
        }

        return Text(
          "${NumberFormat('#,###').format(total)}원",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }

  // ✅ 이번 달 딜레이가 설정된 매월 항목은 딜레이된 날짜를 결제일로 사용
  int _effectiveRecurringDay(Map<String, dynamic> item, DateTime now) {
    var dayData = item['day'] ?? '1';
    int day = (dayData is String)
        ? int.tryParse(dayData.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1
        : (dayData as int);
    final String period = (item['period'] ?? '매월').toString();
    if (period != '매월') return day;
    final String delayedMonth = (item['delayedMonth'] ?? '').toString();
    final String nowKey = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    final dd = item['delayedDay'];
    if (delayedMonth == nowKey && dd is int && dd >= 1 && dd <= 31) {
      return dd;
    }
    return day;
  }

  // ✅ 오늘 예정된 고정/변동지출·수입 확인 팝업
  bool _didCheckDueItems = false;

  Future<void> _checkDueRecurringItems() async {
    if (_didCheckDueItems) return;
    if (currentUserId == null) return;

    // ✅ 알림 설정에서 당일 확인창을 꺼둔 경우 띄우지 않음 (기본: 켜짐)
    final prefs = await SharedPreferences.getInstance();
    final bool dueCheckEnabled = prefs.getBool('is_due_check_enabled') ?? true;
    if (!dueCheckEnabled) return;

    _didCheckDueItems = true;

    final DateTime now = DateTime.now();
    final String todayKey = DateFormat('yyyy-MM-dd').format(now);

    const weekdayMap = {
      '월요일': 1,
      '화요일': 2,
      '수요일': 3,
      '목요일': 4,
      '금요일': 5,
      '토요일': 6,
      '일요일': 7,
    };

    final items = List<Map<String, dynamic>>.from(_recurringRawItems);
    for (final item in items) {
      final String docId = (item['_docId'] ?? '').toString();
      final String name = (item['name'] ?? '').toString();
      final int amount = (item['amount'] ?? 0) as int;
      if (docId.isEmpty || name.isEmpty || amount == 0) continue;
      // 오늘 이미 확인(또는 딜레이 처리)한 항목은 다시 묻지 않음
      if ((item['confirmedFor'] ?? '') == todayKey) continue;

      final String period = (item['period'] ?? '매월').toString();
      bool dueToday = false;
      if (period == '매월') {
        dueToday = _effectiveRecurringDay(item, now) == now.day;
      } else if (period == '매주') {
        dueToday = weekdayMap[(item['day'] ?? '').toString()] == now.weekday;
      } else if (period == '매일') {
        dueToday = true;
      }
      if (!dueToday) continue;

      if (!mounted) return;
      await _showRecurringCheckDialog(docId, item, now, todayKey);
    }
  }

  Future<void> _showRecurringCheckDialog(
    String docId,
    Map<String, dynamic> item,
    DateTime now,
    String todayKey,
  ) async {
    final String expenseType = (item['expenseType'] ?? '고정지출').toString();
    final bool isIncome = expenseType.contains('수입');
    final String name = (item['name'] ?? '').toString();
    final String amountStr = NumberFormat(
      '#,###',
    ).format((item['amount'] ?? 0) as int);

    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background(context),
        title: Text(
          "$expenseType 확인",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          isIncome
              ? "오늘 $name($expenseType)\n$amountStr원이 들어왔나요?"
              : "오늘 $name($expenseType)\n$amountStr원이 빠져나갔나요?",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "아니요",
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "네",
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

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('recurring_expenses')
        .doc(docId);

    if (answer == true) {
      // 잘 처리됨 → 오늘은 다시 묻지 않음
      await ref.set({'confirmedFor': todayKey}, SetOptions(merge: true));
    } else if (answer == false) {
      // 딜레이 → 날짜 선택
      if (!mounted) return;
      final DateTime? picked = await _showDelayDatePicker(name, now);
      if (picked != null) {
        await ref.set({
          'confirmedFor': todayKey,
          'delayedDay': picked.day,
          'delayedMonth': "${now.year}-${now.month.toString().padLeft(2, '0')}",
        }, SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$name 예정일이 ${picked.day}일로 변경되었습니다.")),
          );
        }
      }
      // 날짜 선택을 취소하면 저장하지 않음 → 다음 진입 시 다시 물어봄
    }
    // 팝업 바깥을 탭해서 닫으면 다음 진입 시 다고시 물어봄
  }

  Future<DateTime?> _showDelayDatePicker(String name, DateTime now) {
    final DateTime minDate = DateTime(now.year, now.month, now.day);
    final DateTime maxDate = DateTime(now.year, now.month + 1, 0);
    DateTime tempDate = minDate;

    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppColors.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => SizedBox(
        height: 320,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 10, top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$name 예정일 변경",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, tempDate),
                    child: Text(
                      "완료",
                      style: TextStyle(
                        color: AppColors.primary(context),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                minimumDate: minDate,
                maximumDate: maxDate,
                initialDateTime: minDate,
                onDateTimeChanged: (d) => tempDate = d,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(String title, int amount, Color color) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(color: AppColors.secondary, fontSize: 12),
        ),
        const SizedBox(width: 20),
        Text(
          "${NumberFormat('#,###').format(amount)}원",
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNoSpendHighlight(Map dailyRecords) {
    int noSpendCount = 0;
    int daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    int lastDay = daysInMonth;

    for (int i = 1; i <= lastDay; i++) {
      String dateKey = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(_focusedDay.year, _focusedDay.month, i));

      bool hasExpenseOnDay = false;
      // 일반 지출 확인
      if (dailyRecords.containsKey(dateKey)) {
        for (var record in dailyRecords[dateKey]!) {
          if (record['type'] == '지출' || record['type'] == '이체(지출)') {
            hasExpenseOnDay = true;
            break;
          }
        }
      }
      // 고정지출 확인
      DateTime normalizedDate = DateTime(
        _focusedDay.year,
        _focusedDay.month,
        i,
      );
      // ✅ 수입 타입은 무지출 판정에서 제외
      int fixed = (_events[normalizedDate] ?? []).fold(
        0,
        (sum, item) =>
            ((item['expenseType'] ?? '고정지출') as String).contains('수입')
            ? sum
            : sum + (item['amount'] as int),
      );
      if (fixed > 0) hasExpenseOnDay = true;

      if (!hasExpenseOnDay) noSpendCount++;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.primary(context).withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 6, color: AppColors.primary(context)),
              const SizedBox(width: 5),
              const Text(
                "무지출 일수",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          Text(
            "총 $noSpendCount일",
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showAddRecordSheet({String? docId, Map<String, dynamic>? initialData}) {
    final NumberFormat nf = NumberFormat('#,###');

    if (docId != null && docId.isNotEmpty) {
      if (initialData != null && initialData['receiptImage'] != null) {
        String path = initialData['receiptImage'].toString();
        _receiptImage = path.isNotEmpty ? File(path) : null;
      } else {
        _receiptImage = null;
      }
    } else {
      if (isOcrLoading) {
      } else if (initialData != null && initialData.containsKey('place')) {
      } else {
        _receiptImage = null;
      }
    }

    int originalAmount = 0;

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

    if (initialData != null) {
      originalAmount = initialData['amount'] ?? 0;
    } else {
      originalAmount = 0;
    }

    String selectedType = () {
      final t = initialData?['type'] ?? '지출';
      if (t == '이체') return '이체(지출)'; // 기존 데이터 호환
      return t;
    }();

    DateTime tempDate;

    if (initialData != null && initialData['date'] != null) {
      tempDate = (initialData['date'] as Timestamp).toDate();
    } else {
      tempDate = _selectedDay ?? DateTime.now();
    }

    Map<String, String> selectedCategory = initialData?['category'] != null
        ? Map<String, String>.from(initialData?['category'])
        : {'name': '미분류', 'icon': '？'};

    if (initialData == null) {
      selectedCategory = {'name': '미분류', 'icon': '？'};
    }

    // ✅ 추가 - 바텀시트 안에서 직접 placeController 감지
    void autoAssign() {
      if (_isUserTouchedCategory) return;
      if (selectedType != '지출' && selectedType != '이체(지출)') return;
      String text = placeController.text.trim();
      if (text.isEmpty) return;

      final Map<String, Map<String, String>> cMap = {
        '식비': {'name': '식비', 'icon': '🍴'},
        '카페/간식': {'name': '카페/간식', 'icon': '🥤'},
        '마트/편의점': {'name': '마트/편의점', 'icon': '🛒'},
        '교통': {'name': '교통', 'icon': '🚘'},
        '쇼핑': {'name': '쇼핑', 'icon': '🛍️'},
        '의료': {'name': '의료', 'icon': '🏥'},
        '주거/통신': {'name': '주거/통신', 'icon': '🏠'},
        '문화/여가': {'name': '문화/여가', 'icon': '🎬'},
        '뷰티/미용': {'name': '뷰티/미용', 'icon': '💄'},
        '반려동물': {'name': '반려동물', 'icon': '🐶'},
        '취미': {'name': '취미', 'icon': '🎨'},
        '교육': {'name': '교육', 'icon': '📚'},
        '여행': {'name': '여행', 'icon': '✈️'},
        '술/유흥': {'name': '술/유흥', 'icon': '🍺'},
      };

      final Map<String, List<String>> kw = {
        '식비': [
          '식당',
          '밥',
          '배달',
          '고기',
          '국밥',
          '치킨',
          '피자',
          '한식',
          '중식',
          '일식',
          '분식',
          '김밥',
          '라면',
          '돈까스',
          '햄버거',
          '맥도날드',
          '버거킹',
          'KFC',
          '롯데리아',
          '배달의민족',
          '요기요',
          '쿠팡이츠',
          '교촌',
          '굽네',
          '서브웨이',
          '삼겹살',
          '냉면',
          '우동',
          '떡볶이',
          '식사',
          '점심',
          '저녁',
          '아침',
        ],
        '카페/간식': [
          '카페',
          '커피',
          '스타벅스',
          '이디야',
          '빽다방',
          '메가커피',
          '컴포즈',
          '투썸',
          '할리스',
          '던킨',
          '배스킨',
          '베스킨',
          '디저트',
          '빵',
          '베이커리',
          '파리바게트',
          '뚜레쥬르',
          '아이스크림',
          '케이크',
          '음료',
          '간식',
        ],
        '마트/편의점': [
          'CU',
          'GS25',
          '세븐일레븐',
          '이마트24',
          '미니스톱',
          '편의점',
          '이마트',
          '홈플러스',
          '롯데마트',
          '코스트코',
          '다이소',
          '마트',
          '슈퍼',
        ],
        '교통': [
          '택시',
          '버스',
          '지하철',
          '주유',
          'KTX',
          'SRT',
          '기차',
          '대리',
          '주차',
          '카카오T',
          '충전',
          '항공',
        ],
        '쇼핑': [
          '쿠팡',
          '옷',
          '의류',
          '신발',
          '백화점',
          '아울렛',
          '올리브영',
          '무신사',
          '29CM',
          '유니클로',
          '자라',
          '나이키',
          '아디다스',
          '롯데백화점',
          '현대백화점',
          '신세계',
          '가방',
        ],
        '의료': [
          '병원',
          '의원',
          '치과',
          '한의원',
          '약국',
          '클리닉',
          '정형외과',
          '내과',
          '피부과',
          '안과',
          '검진',
        ],
        '주거/통신': [
          '통신',
          'SKT',
          'KT',
          'LG',
          '인터넷',
          '관리비',
          '전기세',
          '가스비',
          '수도',
          '월세',
          '보험',
        ],
        '문화/여가': [
          '영화',
          'CGV',
          '롯데시네마',
          '메가박스',
          '노래방',
          '헬스',
          '운동',
          '게임',
          '도서',
          '교보문고',
          '공연',
          '전시',
          '뮤지컬',
          '콘서트',
          '수영',
          '요가',
          '필라테스',
          '클라이밍',
          '볼링',
          '골프',
          '테니스',
        ],
        '뷰티/미용': ['미용실', '헤어', '네일', '피부', '마사지', '왁싱', '화장품', '이니스프리', '에뛰드'],
        '반려동물': ['동물병원', '펫', '애견', '고양이', '강아지', '사료', '펫샵', '반려'],
        '취미': ['공방', '악기', '기타', '피아노', '그림', '사진', '낚시', '등산', '캠핑'],
        '교육': ['학원', '과외', '교육', '영어', '수학', '어학원', '인강', '클래스', '강의', '수강'],
        '여행': [
          '여행',
          '호텔',
          '숙박',
          '에어비앤비',
          '펜션',
          '리조트',
          '항공권',
          '여행사',
          '면세점',
          '제주',
        ],
        '술/유흥': [
          '술',
          '맥주',
          '소주',
          '막걸리',
          '와인',
          '위스키',
          '바',
          '포차',
          '호프',
          '이자카야',
          '클럽',
        ],
      };

      for (var entry in kw.entries) {
        for (String keyword in entry.value) {
          if (text.toLowerCase().contains(keyword.toLowerCase())) {
            if (!_isUserTouchedCategory) {
              _modalStateSetter?.call(() {
                selectedCategory = cMap[entry.key]!;
              });
            }
            return;
          }
        }
      }
    }

    placeController.removeListener(_autoAssignCategory);
    placeController.addListener(autoAssign);

    String selectedPayment = initialData?['paymentMethod'] ?? "";
    String selectedBankName = initialData?['bankName'] ?? "";

    int settlementPeople = initialData?['settlement']?['people'] ?? 2;
    List<String> selectedFriends = List<String>.from(
      initialData?['settlement']?['friends'] ?? [],
    );
    bool isSettlementActive = initialData?['settlement'] != null;
    bool isRoundingEnabled = initialData?['settlement']?['rounding'] ?? false;
    int roundingUnit = initialData?['settlement']?['roundingUnit'] ?? 100;

    // ✅ 1인당 정산 금액 계산
    // 올림 켜져 있으면 선택한 단위로 올림 — 돈이 줄어들지 않음
    // (100원 단위: 6,150 → 6,200 / 1,000원 단위: 15,600 → 16,000)
    int calcSettlementAmount() {
      int divided = (originalAmount / settlementPeople).round();
      if (isRoundingEnabled && roundingUnit > 0) {
        divided = ((divided + roundingUnit - 1) ~/ roundingUnit) * roundingUnit;
      }
      return divided;
    }

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
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    // 결제수단 관리
                    fontSize: 15,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? AppColors.primary(context)
                        : AppColors.textPrimary(context),
                  ),
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              if (isSelected)
                Icon(Icons.check, color: AppColors.primary(context), size: 18),
            ],
          ),
        ),
      );
    }

    amountController.addListener(() {
      String text = amountController.text
          .replaceAll(',', '')
          .replaceAll('원', '')
          .trim();
      if (text.isEmpty) return;
      double? value = double.tryParse(text);
      if (value != null) {
        String newText = "${nf.format(value)}원";
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

    void showPaymentPicker(StateSetter setModalState) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.background(context),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
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
                        child: const Icon(Icons.close),
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
                          fontSize: 12,
                        ),
                      ),
                      const Divider(thickness: 0.5),
                      buildPaymentItem("현금", "현금", setModalState),
                      const SizedBox(height: 15),

                      const Text(
                        "카드",
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 12,
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
                              String actualBankName =
                                  cardData['bankName'] ?? '미지정';
                              String cardName = cardData['cardName'] ?? '';
                              String cardNumber = (cardData['cardNumber'] ?? '')
                                  .toString()
                                  .trim();
                              String displayName = cardNumber.isNotEmpty
                                  ? '$cardName($cardNumber)'
                                  : cardName;

                              return buildPaymentItem(
                                displayName,
                                actualBankName,
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

    void showSettlementPicker(StateSetter setModalState) async {
      // ✅ 저장 없이 닫으면(X·바깥 탭) 원래 상태로 되돌리기 위한 스냅샷
      final String prevAmountText = amountController.text;
      final int prevPeople = settlementPeople;
      final List<String> prevFriends = List<String>.from(selectedFriends);
      final bool prevActive = isSettlementActive;
      final bool prevRounding = isRoundingEnabled;
      final int prevUnit = roundingUnit;
      bool savedByButton = false;

      await showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.background(context),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (context) => StatefulBuilder(
          builder: (context, setPickerState) {
            List<String> friendsList = List<String>.from(selectedFriends);
            final TextEditingController friendInputController =
                TextEditingController();

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
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
                    const SizedBox(height: 20),
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
                      menuMaxHeight: 200,
                      dropdownColor: AppColors.background(context),
                      borderRadius: BorderRadius.circular(10),
                      isExpanded: true,

                      value: settlementPeople,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.divider(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
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
                            settlementPeople = val;
                            if (originalAmount > 0) {
                              int divided = calcSettlementAmount();
                              amountController.text = "${nf.format(divided)}원";
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "친구 추가",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      height: 55,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.divider(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    // 태그들
                                    ...friendsList.map(
                                      (friend) => Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary(context)
                                              .withOpacity(
                                                0.15,
                                              ),
                                          borderRadius: BorderRadius.circular(
                                            25,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              friend,
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: AppColors.primary(
                                                  context,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            GestureDetector(
                                              onTap: () {
                                                setPickerState(() {
                                                  friendsList.remove(friend);
                                                  selectedFriends.remove(
                                                    friend,
                                                  );
                                                });
                                              },
                                              child: Icon(
                                                Icons.close,
                                                size: 14,
                                                color: AppColors.primary(
                                                  context,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // 입력창
                                    SizedBox(
                                      width: 100,
                                      child: TextField(
                                        controller: friendInputController,
                                        style: const TextStyle(fontSize: 15),
                                        decoration: const InputDecoration(
                                          hintText: "이름 입력",
                                          hintStyle: TextStyle(
                                            color: AppColors.secondary,
                                            fontSize: 15,
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onSubmitted: (value) {
                                          final name = value.trim();
                                          if (name.isNotEmpty &&
                                              !friendsList.contains(name)) {
                                            setPickerState(() {
                                              friendsList.add(name);
                                              selectedFriends.add(name);
                                            });
                                            friendInputController.clear();
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "금액 설정",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "1인당 금액을 깔끔한 단위로 올려요.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: isRoundingEnabled,
                          activeColor: AppColors.primary(context),
                          onChanged: (val) {
                            setPickerState(() => isRoundingEnabled = val);
                            if (originalAmount > 0) {
                              setModalState(() {
                                amountController.text =
                                    "${nf.format(calcSettlementAmount())}원";
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    if (isRoundingEnabled) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [100, 1000].map((unit) {
                          final bool isSelected = roundingUnit == unit;
                          final String label = unit == 100
                              ? "100원 단위"
                              : "1,000원 단위";
                          return GestureDetector(
                            onTap: () {
                              setPickerState(() => roundingUnit = unit);
                              if (originalAmount > 0) {
                                setModalState(() {
                                  amountController.text =
                                      "${nf.format(calcSettlementAmount())}원";
                                });
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary(
                                        context,
                                      ).withOpacity(0.15)
                                    : AppColors.divider(context),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary(context)
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? AppColors.primary(context)
                                      : AppColors.secondary,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      // const SizedBox(height: 5),
                      // Text(
                      //   roundingUnit == 100
                      //       ? "예) 6,150원 → 6,200원"
                      //       : "예) 15,600원 → 16,000원",
                      //   style: const TextStyle(
                      //     fontSize: 12,
                      //     color: AppColors.secondary,
                      //   ),
                      // ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          savedByButton = true;
                          setModalState(() {
                            isSettlementActive = true;

                            if (originalAmount > 0) {
                              int nPrice = calcSettlementAmount();

                              amountController.text = "${nf.format(nPrice)}원";
                            }
                          });
                          Navigator.pop(context);
                        },
                        child: Text(
                          "저장",
                          style: TextStyle(
                            color: AppColors.background(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      );

      // ✅ 저장 버튼 없이 닫혔으면 미리보기 전 상태로 복구
      if (!savedByButton) {
        settlementPeople = prevPeople;
        selectedFriends = prevFriends;
        isSettlementActive = prevActive;
        isRoundingEnabled = prevRounding;
        roundingUnit = prevUnit;
        setModalState(() {
          amountController.text = prevAmountText;
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          _modalStateSetter = setModalState;
          _onCategoryAutoAssigned = (name, icon) {
            setModalState(() {
              selectedCategory = {'name': name, 'icon': icon};
            });
          };
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: AppColors.background(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
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
                          _receiptImage = null;
                        });
                        Navigator.pop(context);
                      },
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_receiptImage != null) ...[
                          Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                height: 180,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.secondary,
                                  ),
                                  image: isOcrLoading
                                      ? null
                                      : DecorationImage(
                                          image: FileImage(_receiptImage!),
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                child: isOcrLoading
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              color: AppColors.primary(context),
                                            ),
                                            const SizedBox(height: 10),
                                            const Text(
                                              "영수증 재분석 중...",
                                              style: TextStyle(
                                                color: AppColors.secondary,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : null,
                              ),
                              if (!isOcrLoading)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Row(
                                    children: [
                                      // 카메라로 변경
                                      GestureDetector(
                                        onTap: () async {
                                          final ImagePicker picker =
                                              ImagePicker();
                                          final XFile? image = await picker
                                              .pickImage(
                                                source: ImageSource.camera,
                                              );
                                          if (image != null) {
                                            setModalState(
                                              () => isOcrLoading = true,
                                            );
                                            setState(
                                              () => _receiptImage = File(
                                                image.path,
                                              ),
                                            );
                                            final newData =
                                                await _analyzeReceipt(
                                                  image.path,
                                                );
                                            if (newData != null) {
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
                                            setModalState(
                                              () => isOcrLoading = false,
                                            );
                                          }
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.textPrimary(
                                              context,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.camera_alt,
                                            color: AppColors.background(
                                              context,
                                            ),
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                      // 갤러리로 변경
                                      GestureDetector(
                                        onTap: () async {
                                          final ImagePicker picker =
                                              ImagePicker();
                                          final XFile? image = await picker
                                              .pickImage(
                                                source: ImageSource.gallery,
                                              );

                                          if (image != null) {
                                            setModalState(() {
                                              isOcrLoading = true;
                                            });

                                            setState(() {
                                              _receiptImage = File(image.path);
                                            });

                                            final newData =
                                                await _analyzeReceipt(
                                                  image.path,
                                                );

                                            if (newData != null) {
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
                                          decoration: BoxDecoration(
                                            color: AppColors.textPrimary(
                                              context,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.photo_library,
                                            color: AppColors.background(
                                              context,
                                            ),
                                            size: 16,
                                          ),
                                        ),
                                      ),

                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _receiptImage = null;
                                          });
                                          setModalState(() {
                                            placeController.clear();
                                            amountController.clear();
                                            memoController.clear();
                                            selectedCategory = {
                                              'name': '미분류',
                                              'icon': '？',
                                            };
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.textPrimary(
                                              context,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            color: AppColors.background(
                                              context,
                                            ),
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
                            Expanded(
                              child: TextField(
                                controller: amountController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) =>
                                    FocusScope.of(context).unfocus(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  hintText: "0원",
                                  border: InputBorder.none,
                                  helperText: isSettlementActive
                                      ? "1인당 정산 금액"
                                      : null,
                                  helperStyle: TextStyle(
                                    color: AppColors.primary(context),
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

                                  int? parsed = int.tryParse(
                                    val
                                        .replaceAll(',', '')
                                        .replaceAll('원', '')
                                        .trim(),
                                  );

                                  if (parsed != null) {
                                    originalAmount = parsed;

                                    int displayAmount = isSettlementActive
                                        ? calcSettlementAmount()
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

                            if (isSettlementActive) ...[
                              Builder(
                                builder: (context) {
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
                                    onTap: () {
                                      final TextEditingController
                                      totalEditController =
                                          TextEditingController(
                                            text: formatter.format(totalAmount),
                                          );

                                      showDialog(
                                        context: context,
                                        builder: (dialogContext) {
                                          return AlertDialog(
                                            backgroundColor:
                                                AppColors.background(context),
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
                                              autofocus: true,
                                              decoration: InputDecoration(
                                                suffixText: "원",
                                                hintText: "전체 금액 입력",
                                                hintStyle: const TextStyle(
                                                  color: AppColors.secondary,
                                                ),
                                                filled: true,
                                                fillColor: AppColors.divider(
                                                  context,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  borderSide: BorderSide.none,
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 12,
                                                    ),
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
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  int? newTotal = int.tryParse(
                                                    totalEditController.text
                                                        .replaceAll(',', '')
                                                        .trim(),
                                                  );
                                                  if (newTotal != null &&
                                                      newTotal > 0) {
                                                    setModalState(() {
                                                      originalAmount = newTotal;

                                                      int nPrice =
                                                          calcSettlementAmount();

                                                      amountController.text =
                                                          "${formatter.format(nPrice)}원";
                                                    });
                                                  }
                                                  Navigator.pop(
                                                    dialogContext,
                                                  );
                                                },
                                                child: Text(
                                                  "확인",
                                                  style: TextStyle(
                                                    color: AppColors.primary(
                                                      context,
                                                    ),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary(context)
                                              .withOpacity(
                                                0.1,
                                              ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: AppColors.primary(context)
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
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: AppColors.primary(
                                                  context,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Icon(
                                              Icons.edit,
                                              size: 14,
                                              color: AppColors.primary(context),
                                            ),
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
                        Divider(height: 1, color: AppColors.divider(context)),
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
                                  selectedCategory = {
                                    'name': '미분류',
                                    'icon': '？',
                                  };
                                }),
                              ),
                              const SizedBox(width: 10),
                              _buildTypeButton(
                                "수입",
                                selectedType == '수입',
                                () => setModalState(() {
                                  selectedType = '수입';
                                  selectedCategory = {
                                    'name': '미분류',
                                    'icon': '？',
                                  };
                                }),
                              ),
                              const SizedBox(width: 10),
                              _buildTypeButton(
                                "이체\n(지출)",
                                selectedType == '이체(지출)',
                                () => setModalState(() {
                                  selectedType = '이체(지출)';
                                  selectedCategory = {
                                    'name': '미분류',
                                    'icon': '？',
                                  };
                                }),
                              ),
                              const SizedBox(width: 10),
                              _buildTypeButton(
                                "이체\n(수입)",
                                selectedType == '이체(수입)',
                                () => setModalState(() {
                                  selectedType = '이체(수입)';
                                  selectedCategory = {
                                    'name': '미분류',
                                    'icon': '？',
                                  };
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        Divider(height: 1, color: AppColors.divider(context)),
                        const SizedBox(height: 15),
                        _buildInputRow(
                          "사용처",
                          TextField(
                            controller: placeController,
                            decoration: _inputFieldDecoration("입력하세요"),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Divider(height: 1, color: AppColors.divider(context)),
                        const SizedBox(height: 15),
                        _buildInputRow(
                          "카테고리",
                          _buildSelectableBox(
                            "${selectedCategory['icon']} ${selectedCategory['name']}",
                            () async {
                              FocusScope.of(context).unfocus();
                              final result = await _showCategoryPicker(
                                (selectedType == '이체(지출)' ||
                                        selectedType == '이체(수입)')
                                    ? '지출'
                                    : selectedType,
                              );
                              if (result != null) {
                                setModalState(() => selectedCategory = result);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 15),
                        Divider(height: 1, color: AppColors.divider(context)),
                        const SizedBox(height: 15),
                        _buildInputRow(
                          "결제수단",
                          GestureDetector(
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              showPaymentPicker(setModalState);
                            },
                            child: Container(
                              height: fieldHeight,
                              decoration: BoxDecoration(
                                color: AppColors.background(context),
                                borderRadius: BorderRadius.circular(10),
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
                                              : AppColors.textPrimary(context),
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
                        Divider(height: 1, color: AppColors.divider(context)),
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
                        Divider(height: 1, color: AppColors.divider(context)),
                        const SizedBox(height: 15),
                        _buildInputRow(
                          "날짜",
                          _buildSelectableBox(
                            DateFormat(
                              'yyyy. MM. dd',
                            ).format(tempDate), // ✅ 시간 제거
                            () async {
                              // ✅ showDatePicker 대신 iOS 스타일 CupertinoDatePicker 사용
                              await showModalBottomSheet(
                                context: context,
                                backgroundColor: AppColors.background(context),
                                builder: (context) {
                                  return SizedBox(
                                    height: 300,
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 10,
                                                  top: 10,
                                                ),
                                                child: Text(
                                                  "완료",
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: AppColors.primary(
                                                      context,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Expanded(
                                          child: CupertinoDatePicker(
                                            backgroundColor:
                                                AppColors.background(context),
                                            mode: CupertinoDatePickerMode
                                                .date, // ✅ 날짜만
                                            initialDateTime: tempDate,
                                            minimumDate: DateTime(2020),
                                            maximumDate: DateTime(2030),
                                            onDateTimeChanged:
                                                (DateTime newDate) {
                                                  setModalState(() {
                                                    tempDate = DateTime(
                                                      newDate.year,
                                                      newDate.month,
                                                      newDate.day,
                                                    );
                                                  });
                                                },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 15),
                        Divider(height: 1, color: AppColors.divider(context)),
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
                            if (docId != null)
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  height: 55,
                                  child: OutlinedButton(
                                    onPressed: () => _saveRecord(
                                      docId: docId,
                                      isDelete: true,
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
                                      side: BorderSide(
                                        color: AppColors.divider(context),
                                      ),
                                      backgroundColor: AppColors.divider(
                                        context,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      "삭제",
                                      style: TextStyle(
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: SizedBox(
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: () => _saveRecord(
                                    docId: docId,
                                    type: selectedType,
                                    amount: amountController.text,
                                    place: placeController.text,
                                    category: selectedCategory,
                                    payment: selectedPayment,
                                    bankName: selectedBankName,
                                    date: tempDate,
                                    memo: memoController.text,
                                    isDelete: false,
                                    isSettlement: isSettlementActive,
                                    sPeople: settlementPeople,
                                    sFriends: selectedFriends,
                                    sRounding: isRoundingEnabled,
                                    sRoundingUnit: roundingUnit,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary(context),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    docId == null ? "저장" : "수정",
                                    style: TextStyle(
                                      color: AppColors.background(context),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      placeController.removeListener(autoAssign);
      placeController.addListener(_autoAssignCategory);
      _modalStateSetter = null;
      _onCategoryAutoAssigned = null;
    });
  }

  void _showDetailListSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: _getRecordsStream(),
        builder: (context, snapshot) {
          List<Map<String, dynamic>> currentRecords = [];
          int income = 0;
          int expense = 0;

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              data['docId'] = doc.id;
              DateTime date = (data['date'] as Timestamp).toDate();

              if (isSameDay(date, _selectedDay)) {
                currentRecords.add(data);
                if (data['type'] == '수입' || data['type'] == '이체(수입)') {
                  income += (data['amount'] as int);
                } else if (data['type'] == '지출' || data['type'] == '이체(지출)') {
                  expense += (data['amount'] as int);
                }
              }
            }
          }

          List<Map<String, dynamic>> fixedRecordList = [];
          int dailyFixedTotal = 0;

          if (_selectedDay != null) {
            DateTime normalizedDate = DateTime(
              _selectedDay!.year,
              _selectedDay!.month,
              _selectedDay!.day,
            );

            List<Map<String, dynamic>> fixedItems =
                _events[normalizedDate] ?? [];

            for (var item in fixedItems) {
              int itemAmount = item['amount'] as int;
              String itemName = item['name'] as String;
              String expenseType = item['expenseType'] ?? '고정지출';
              // ✅ 고정/변동수입은 수입으로 표시
              final bool isIncomeItem = expenseType.contains('수입');
              String icon;
              if (expenseType == '고정지출') {
                icon = '🗓️';
              } else if (expenseType == '변동지출') {
                icon = '📊';
              } else if (expenseType == '고정수입') {
                icon = '💰';
              } else {
                icon = '💵';
              }

              Map<String, dynamic> fixedData = {
                'docId':
                    'fixed_${normalizedDate.millisecondsSinceEpoch}_$itemName',
                'place': itemName,
                'amount': itemAmount,
                'category': {'name': expenseType, 'icon': icon},
                'type': isIncomeItem ? '수입' : '지출',
                'isFixed': true,
              };
              currentRecords.add(fixedData);
              if (isIncomeItem) {
                income += itemAmount;
              } else {
                expense += itemAmount;
              }
            }
          }

          if (snapshot.hasData && currentRecords.isEmpty) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.background(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
              ),
              padding: const EdgeInsets.only(
                top: 24,
                bottom: 40,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ 기존과 동일한 헤더
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('M월 d일').format(_selectedDay!),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text(
                        "총 0건",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _isMenuOpen = true);
                      },

                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.divider(context),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.add,
                              size: 24,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "내역 추가",
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: AppColors.background(context),
                        elevation: 0,
                      ),
                      child: const Text(
                        "확인",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return Container(
            decoration: BoxDecoration(
              color: AppColors.background(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
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
                    Text(
                      DateFormat('M월 d일').format(_selectedDay!),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
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
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primary(context),
                        ),
                      ),

                    if (income > 0 && expense > 0) const SizedBox(width: 10),

                    if (expense > 0)
                      Text(
                        "-${NumberFormat('#,###').format(expense)}원",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                  ],
                ),
                Divider(
                  height: 30,
                  thickness: 1,
                  color: AppColors.divider(context),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: currentRecords.length,
                    itemBuilder: (context, index) {
                      final item = currentRecords[index];
                      final bool isFixedItem = item['isFixed'] ?? false;
                      final isIncome =
                          item['type'] == '수입' || item['type'] == '이체(수입)';

                      final icon = (item['category'] is Map)
                          ? item['category']['icon']
                          : '💰';
                      final catName = (item['category'] is Map)
                          ? item['category']['name']
                          : '미분류';

                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,

                          onTap: () {
                            if (isFixedItem) {
                            } else {
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
                              color: AppColors.divider(context),
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
                                  fontSize: 15,
                                  color: AppColors.textPrimary(context),
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
                              fontSize: 15,
                              color: isIncome
                                  ? AppColors.primary(context)
                                  : AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _isMenuOpen = true);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.divider(context),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.add,
                            size: 24,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "내역 추가",
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      foregroundColor: AppColors.background(context),
                      elevation: 0,
                    ),
                    child: const Text(
                      "확인",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputRow(String label, Widget field) => Row(
    children: [
      SizedBox(
        width: labelWidth,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
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

  InputDecoration _inputFieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 0),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
  );

  Widget _buildSelectableBox(String value, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary(context),
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.secondary,
          ),
        ],
      ),
    ),
  );

  Widget _buildTypeButton(String title, bool isSelected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 55,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.background(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary(context)
                  : AppColors.secondary.withAlpha(80),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1,
              color: isSelected
                  ? AppColors.primary(context)
                  : AppColors.secondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );

  Future<Map<String, String>?> _showCategoryPicker(String type) async {
    if (userId != null) {
      await seedDefaultCategoriesIfEmpty(userId!);
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('categories')
        .where('type', isEqualTo: type)
        .orderBy('index', descending: false)
        .get();

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
        decoration: BoxDecoration(
          color: AppColors.background(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
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
                    child: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  childAspectRatio: 0.9,
                ),
                itemCount: currentCategories.length + 1,
                itemBuilder: (context, i) {
                  if (i == currentCategories.length) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Category(),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.divider(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.background(context),
                          ),
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

                  return GestureDetector(
                    onTap: () => Navigator.pop(context, currentCategories[i]),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background(context),
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
                          const SizedBox(height: 5),
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
    bool isDelete = false,
    bool isSettlement = false,
    int sPeople = 0,
    List<String> sFriends = const [],
    bool sRounding = false,
    int sRoundingUnit = 100,
  }) async {
    try {
      if (isDelete && docId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('records')
            .doc(docId)
            .delete();

        if (!mounted) return;
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
          'rounding': sRounding,
          'roundingUnit': sRoundingUnit,
        };
      }

      if (docId != null && docId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('records')
            .doc(docId)
            .update(data);

        if (!mounted) return;
        Navigator.of(context).pop();
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('records')
            .add(data);

        if (!mounted) return;
        Navigator.of(context).pop();

        // 내역 추가 완료 후 일정 횟수마다 전면 광고 (프리미엄 제외)
        InterstitialAdManager.instance.maybeShowOnRecordAdded();
      }
    } catch (e) {
      print("Error saving/deleting record: $e");
    }
  }
}
