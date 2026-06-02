import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'dart:ui' as ui;
import 'package:flutter_rekeep/premium_service.dart';
import 'package:flutter_rekeep/premium_gate.dart';
import 'package:flutter_rekeep/theme_provider.dart';
import 'package:provider/provider.dart';

class Analysis extends StatefulWidget {
  const Analysis({super.key});

  @override
  State<Analysis> createState() => _AnalysisState();
}

class _AnalysisState extends State<Analysis> {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final NumberFormat nf = NumberFormat('#,###');

  bool _isPremium = false;
  bool _isPremiumLoading = true;

  DateTime _selectedMonth = DateTime.now();

  List<Map<String, dynamic>> dailyData = [];
  int fixedBudgetFromSetting = 0;

  Map<String, int> _budgetMap = {};
  bool _isBudgetLoading = true;

  int _paidFixedTotal = 0;
  int _upcomingFixedTotal = 0;
  int _paidVariableTotal = 0;
  int _upcomingVariableTotal = 0;

  List<Map<String, dynamic>> _paidFixedItems = [];
  List<Map<String, dynamic>> _upcomingFixedItems = [];
  List<Map<String, dynamic>> _paidVariableItems = [];
  List<Map<String, dynamic>> _upcomingVariableItems = [];

  bool _showPaidFixed = false;
  bool _showUpcomingFixed = false;
  bool _showPaidVariable = false;
  bool _showUpcomingVariable = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _recurringSubscription?.cancel();
    super.dispose();
  }

  StreamSubscription? _recurringSubscription;

  Future<void> _loadInitialData() async {
    // ✅ 프리미엄 체크 추가
    final premium = await PremiumService.isPremium();
    if (mounted) {
      setState(() {
        _isPremium = premium;
        _isPremiumLoading = false;
      });
    }

    await _loadAllBudgets();
    await _getFixedItemsList();
    _listenToRecurringExpenses();
    setState(() {
      _isBudgetLoading = false;
    });
  }

  void _listenToRecurringExpenses() {
    if (userId == null) return;

    _recurringSubscription?.cancel();

    const weekdayMap = {
      '월요일': 1,
      '화요일': 2,
      '수요일': 3,
      '목요일': 4,
      '금요일': 5,
      '토요일': 6,
      '일요일': 7,
    };

    _recurringSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recurring_expenses')
        .snapshots()
        .listen((snapshot) {
          final now = DateTime.now();
          final int today = now.day;
          final int todayWeekday = now.weekday;
          final int lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;

          int paid = 0, upcoming = 0, paidVar = 0, upcomingVar = 0;
          List<Map<String, dynamic>> paidFixedList = [];
          List<Map<String, dynamic>> upcomingFixedList = [];
          List<Map<String, dynamic>> paidVarList = [];
          List<Map<String, dynamic>> upcomingVarList = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final int amount = (data['amount'] ?? 0) as int;
            final String period = (data['period'] ?? '매월').toString();
            final String expenseType = data['expenseType'] ?? '고정지출';
            final String name = data['name'] ?? '';
            var dayData = data['day'] ?? '1일';

            void addItem(int day, bool isPaid) {
              final item = {
                'name': name,
                'amount': amount,
                'day': day,
                'expenseType': expenseType,
              };
              if (expenseType == '고정지출') {
                if (isPaid) {
                  paid += amount;
                  paidFixedList.add(item);
                } else {
                  upcoming += amount;
                  upcomingFixedList.add(item);
                }
              } else {
                if (isPaid) {
                  paidVar += amount;
                  paidVarList.add(item);
                } else {
                  upcomingVar += amount;
                  upcomingVarList.add(item);
                }
              }
            }

            if (period == '매월') {
              final int day = (dayData is String)
                  ? int.tryParse(dayData.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1
                  : (dayData as int);
              addItem(day, day <= today);
            } else if (period == '매주') {
              // 이번 달에 해당 요일이 몇 번 있는지 계산
              final int targetWeekday = weekdayMap[dayData.toString()] ?? 1;
              for (int d = 1; d <= lastDayOfMonth; d++) {
                final weekday = DateTime(now.year, now.month, d).weekday;
                if (weekday == targetWeekday) {
                  addItem(d, d <= today);
                }
              }
            } else if (period == '매일') {
              // 1일 ~ 말일까지 매일 추가
              for (int d = 1; d <= lastDayOfMonth; d++) {
                addItem(d, d <= today);
              }
            }
          }

          // 날짜순 정렬
          paidFixedList.sort(
            (a, b) => (a['day'] as int).compareTo(b['day'] as int),
          );
          upcomingFixedList.sort(
            (a, b) => (a['day'] as int).compareTo(b['day'] as int),
          );
          paidVarList.sort(
            (a, b) => (a['day'] as int).compareTo(b['day'] as int),
          );
          upcomingVarList.sort(
            (a, b) => (a['day'] as int).compareTo(b['day'] as int),
          );

          if (mounted) {
            setState(() {
              _paidFixedTotal = paid;
              _upcomingFixedTotal = upcoming;
              _paidVariableTotal = paidVar;
              _upcomingVariableTotal = upcomingVar;
              _paidFixedItems = paidFixedList;
              _upcomingFixedItems = upcomingFixedList;
              _paidVariableItems = paidVarList;
              _upcomingVariableItems = upcomingVarList;
            });
          }
        });
  }

  Future<void> _loadAllBudgets() async {
    if (userId == null) return;
    try {
      final now = DateTime.now();
      final int lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;

      const weekdayMap = {
        '월요일': 1,
        '화요일': 2,
        '수요일': 3,
        '목요일': 4,
        '금요일': 5,
        '토요일': 6,
        '일요일': 7,
      };

      // 1) 카테고리 예산 로드
      final budgetSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .get();

      final Map<String, int> tempBudgets = {};
      for (var doc in budgetSnapshot.docs) {
        final displayKey = doc.id.replaceAll('_', '/');
        tempBudgets[displayKey] = (doc.data()['amount'] ?? 0) as int;
      }

      // 2) 고정지출/변동지출 총액을 예산으로 추가
      final recurringSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recurring_expenses')
          .get();

      int fixedTotal = 0;
      int variableTotal = 0;

      for (var doc in recurringSnapshot.docs) {
        final data = doc.data();
        final int amount = (data['amount'] ?? 0) as int;
        final String period = (data['period'] ?? '매월').toString();
        final String expenseType = data['expenseType'] ?? '고정지출';
        final dayData = data['day'] ?? '1일';

        int count = 1;
        if (period == '매월') {
          count = 1;
        } else if (period == '매주') {
          final int targetWeekday = weekdayMap[dayData.toString()] ?? 1;
          count = 0;
          for (int d = 1; d <= lastDayOfMonth; d++) {
            if (DateTime(now.year, now.month, d).weekday == targetWeekday) {
              count++;
            }
          }
        } else if (period == '매일') {
          count = lastDayOfMonth;
        }

        final int total = amount * count;
        if (expenseType == '고정지출') {
          fixedTotal += total;
        } else {
          variableTotal += total;
        }
      }

      if (fixedTotal > 0) tempBudgets['고정지출'] = fixedTotal;
      if (variableTotal > 0) tempBudgets['변동지출'] = variableTotal;

      if (mounted) {
        setState(() {
          _budgetMap = tempBudgets;
          _isBudgetLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBudgetLoading = false);
      }
    }
  }

  int fixedBudgetTotal = 0;

  Future<void> _getFixedItemsList() async {
    if (userId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('settings')
          .get();

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('여기에_위에_찍힌_ID를_넣으세요')
          .get();

      if (doc.exists) {}
    } catch (e) {
      print("에러 발생: $e");
    }
  }

  final List<String> _fixedItems = [
    "관리비",
    "통신비",
    "주거비",
    "인터넷비",
    "연금",
    "세금",
    "구독료",
    "자기계발",
    "보험료",
    "모임비",
  ];

  int _getFixedBudgetTotal() {
    int total = 0;
    _budgetMap.forEach((key, value) {
      if (_fixedItems.contains(key)) {
        total += value;
      }
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final int currentYear = _selectedMonth.year;
    final int currentMonth = _selectedMonth.month;

    final int lastYear = currentMonth == 1 ? currentYear - 1 : currentYear;
    final int lastMonth = currentMonth == 1 ? 12 : currentMonth - 1;

    if (_isBudgetLoading || _isPremiumLoading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary(context),
          ),
        ),
      );
    }

    final int daysInCurrentMonth = DateTime(
      currentYear,
      currentMonth + 1,
      0,
    ).day;
    final int daysInLastMonth = DateTime(lastYear, lastMonth + 1, 0).day;

    if (!_isPremium) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          backgroundColor: AppColors.background(context),
          surfaceTintColor: AppColors.background(context),
          scrolledUnderElevation: 0,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  Icons.chevron_left,
                  color: AppColors.textPrimary(context),
                  size: 28,
                ),
                Text(
                  "$currentMonth월",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                    fontSize: 18,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textPrimary(context),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            // ✅ 상단 미리보기 배너
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              color: AppColors.primary(context).withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "미리보기 페이지입니다",
                    style: TextStyle(
                      color: AppColors.primary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => PremiumGate.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary(context),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        "프리미엄 시작하기",
                        style: TextStyle(
                          color: AppColors.background(context),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ 실제 분석 UI 스크롤 가능
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 터치 불가 섹션들
                    IgnorePointer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _withPadding(_buildSectionTitle("지난달 대비 지출")),
                          _withPadding(
                            _buildCompareSection(
                              500000,
                              1000000,
                              List.filled(31, 30000),
                              List.filled(31, 20000),
                            ),
                          ),
                          _buildFullDivider(),
                          _withPadding(_buildSectionTitle("소비 습관")),
                          _withPadding(_buildHabitSection(5, 800000, 30)),
                          _buildFullDivider(),
                          _withPadding(_buildSectionTitle("카테고리별 지출")),
                          _withPadding(
                            _buildCategoryAnalysis(
                              [
                                const MapEntry("식비", 300000),
                                const MapEntry("교통", 150000),
                                const MapEntry("카페", 100000),
                                const MapEntry("쇼핑", 80000),
                              ],
                              630000,
                            ),
                          ),
                          _buildFullDivider(),
                          _withPadding(_buildSectionTitle("자산 설정")),
                        ],
                      ),
                    ),

                    // 미리보기 더미 데이터
                    _withPadding(
                      _AssetSettingWidget(
                        paidFixedItems: const [
                          {'day': 1, 'name': '관리비', 'amount': 80000},
                          {'day': 5, 'name': '통신비', 'amount': 55000},
                          {'day': 10, 'name': '구독료', 'amount': 30000},
                          {'day': 15, 'name': '보험료', 'amount': 120000},
                        ],
                        upcomingFixedItems: const [
                          {'day': 20, 'name': '주거비', 'amount': 500000},
                          {'day': 25, 'name': '인터넷비', 'amount': 33000},
                        ],
                        paidVariableItems: const [
                          {'day': 3, 'name': '교통비', 'amount': 60000},
                          {'day': 8, 'name': '의료비', 'amount': 25000},
                        ],
                        upcomingVariableItems: const [
                          {'day': 22, 'name': '공과금', 'amount': 45000},
                        ],
                        paidFixedTotal: 285000,
                        upcomingFixedTotal: 533000,
                        paidVariableTotal: 85000,
                        upcomingVariableTotal: 45000,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background(context),
          appBar: AppBar(
            backgroundColor: AppColors.background(context),
            surfaceTintColor: AppColors.background(context),
            scrolledUnderElevation: 0,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => setState(
                      () => _selectedMonth = DateTime(
                        currentYear,
                        currentMonth - 1,
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
                    "$currentMonth월",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                      fontSize: 18,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(
                      () => _selectedMonth = DateTime(
                        currentYear,
                        currentMonth + 1,
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
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId ?? 'guest')
                .collection('records')
                .where(
                  'date',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(
                    DateTime(lastYear, lastMonth, 1),
                  ),
                )
                .where(
                  'date',
                  isLessThan: Timestamp.fromDate(
                    DateTime(
                      currentYear,
                      currentMonth + 1,
                      1,
                    ),
                  ),
                )
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary(context),
                  ),
                );
              }

              Map<String, int> categoryTotals = {};
              List<Map<String, dynamic>> currentMonthExpenses = [];
              int currentMonthTotal = 0;
              int lastMonthTotal = 0;
              Set<int> currentMonthExpenseDays = {};

              List<int> dailyAmounts = List.generate(
                daysInCurrentMonth + 1,
                (_) => 0,
              );
              List<int> lastDailyAmounts = List.generate(
                daysInLastMonth + 1,
                (_) => 0,
              );

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (data['date'] == null) continue;

                  DateTime date = (data['date'] as Timestamp).toDate();
                  int amount = (data['amount'] ?? 0) as int;
                  String category = data['category']?.toString() ?? "기타";
                  String type = data['type']?.toString() ?? "지출";

                  if (type == '지출' || type == '이체(지출)') {
                    if (date.month == currentMonth &&
                        date.year == currentYear) {
                      currentMonthTotal += amount;
                      currentMonthExpenseDays.add(date.day);
                      currentMonthExpenses.add(data);
                      categoryTotals[category] =
                          (categoryTotals[category] ?? 0) + amount;
                      if (date.day <= daysInCurrentMonth) {
                        dailyAmounts[date.day] += amount;
                      }
                    } else if (date.month == lastMonth &&
                        date.year == lastYear) {
                      lastMonthTotal += amount;
                      if (date.day <= daysInLastMonth) {
                        lastDailyAmounts[date.day] += amount;
                      }
                    }
                  }
                }
              }

              // ✅ 이번달에만 고정/변동지출 포함
              final DateTime now = DateTime.now();
              final bool isThisMonth =
                  currentMonth == now.month && currentYear == now.year;

              if (isThisMonth) {
                for (var item in [..._paidFixedItems, ..._paidVariableItems]) {
                  final int amount = (item['amount'] ?? 0) as int;
                  final int day = (item['day'] ?? 1) as int;

                  currentMonthTotal += amount;
                  currentMonthExpenseDays.add(day);

                  if (day <= daysInCurrentMonth) {
                    dailyAmounts[day] += amount;
                  }

                  final String expenseType = item['expenseType'] ?? '고정지출';
                  final String categoryKey = expenseType == '고정지출'
                      ? '고정지출'
                      : '변동지출';
                  categoryTotals[categoryKey] =
                      (categoryTotals[categoryKey] ?? 0) + amount;
                  currentMonthExpenses.add({
                    'amount': amount,
                    'category': categoryKey,
                    'place': item['name'] ?? '',
                  });
                }
              }
              currentMonthExpenses.sort(
                (a, b) => (b['amount'] ?? 0).compareTo(a['amount'] ?? 0),
              );
              var top3 = currentMonthExpenses.take(3).toList();
              var sortedCategories = categoryTotals.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              int lastDay = daysInCurrentMonth;

              Set<int> fixedExpenseDays = {};
              for (var item in [
                ..._paidFixedItems,
                ..._upcomingFixedItems,
                ..._paidVariableItems,
                ..._upcomingVariableItems,
              ]) {
                var dayData = item['day'];
                int day = (dayData is String)
                    ? int.tryParse(
                            dayData.toString().replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            ),
                          ) ??
                          1
                    : (dayData as int? ?? 1);
                fixedExpenseDays.add(day);
              }

              int noExpenseDays = 0;
              for (int d = 1; d <= lastDay; d++) {
                if (!currentMonthExpenseDays.contains(d) &&
                    !fixedExpenseDays.contains(d)) {
                  noExpenseDays++;
                }
              }

              bool isCurrentMonth =
                  (currentMonth == DateTime.now().month &&
                  currentYear == DateTime.now().year);
              int lastDayForGraph = isCurrentMonth
                  ? DateTime.now().day
                  : daysInCurrentMonth;

              List<int> dailyCumulativeSum = [];
              int tempSum = 0;
              for (int d = 1; d <= lastDayForGraph; d++) {
                tempSum += dailyAmounts[d];
                dailyCumulativeSum.add(tempSum);
              }

              List<int> lastMonthCumulativeSum = [];
              int lastTempSum = 0;
              for (int d = 1; d <= daysInLastMonth; d++) {
                lastTempSum += lastDailyAmounts[d];
                lastMonthCumulativeSum.add(lastTempSum);
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _withPadding(_buildSectionTitle("지난달 대비 지출")),
                    _withPadding(
                      _buildCompareSection(
                        lastMonthTotal,
                        currentMonthTotal,
                        dailyCumulativeSum,
                        lastMonthCumulativeSum,
                      ),
                    ),
                    _buildFullDivider(),
                    _withPadding(_buildSectionTitle("소비 습관")),
                    _withPadding(
                      _buildHabitSection(
                        noExpenseDays,
                        currentMonthTotal,
                        daysInCurrentMonth,
                      ),
                    ),
                    _buildFullDivider(),
                    _withPadding(_buildSectionTitle("카테고리별 지출")),
                    _withPadding(
                      _buildCategoryAnalysis(
                        sortedCategories,
                        currentMonthTotal,
                      ),
                    ),
                    _buildFullDivider(),
                    _withPadding(_buildSectionTitle("자산 설정")),
                    _withPadding(
                      _AssetSettingWidget(
                        paidFixedItems: _paidFixedItems,
                        upcomingFixedItems: _upcomingFixedItems,
                        paidVariableItems: _paidVariableItems,
                        upcomingVariableItems: _upcomingVariableItems,
                        paidFixedTotal: _paidFixedTotal,
                        upcomingFixedTotal: _upcomingFixedTotal,
                        paidVariableTotal: _paidVariableTotal,
                        upcomingVariableTotal: _upcomingVariableTotal,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompareSection(
    int last,
    int current,
    List<int> dailyData,
    List<int> lastData,
  ) {
    int baseMax = (last > current ? last : current);
    int maxVal = baseMax < 1000000 ? 1000000 : (baseMax * 1.2).toInt();

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 0, bottom: 5),
                child: Text(
                  "(만원)",
                  style: TextStyle(fontSize: 10, color: AppColors.secondary),
                ),
              ),
              CustomPaint(
                size: Size(double.infinity, 180),
                painter: LineChartPainter(
                  lastMonthTotal: last,
                  currentMonthTotal: current,
                  maxAmount: maxVal,
                  dailyData: dailyData,
                  lastMonthData: lastData,
                  selectedMonth: _selectedMonth,
                  primaryColor: context.read<ThemeProvider>().primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _chartLegend("지난달", AppColors.secondary),
            const SizedBox(width: 20),
            _chartLegend("이번달", context.read<ThemeProvider>().primaryColor),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          current > last
              ? "지난달보다 ${nf.format(current - last)}원 더 썼어요"
              : "지난달보다 ${nf.format(last - current)}원 아꼈어요",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _withPadding(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24.0),
    child: child,
  );

  Widget _buildFullDivider() => Column(
    children: [
      const SizedBox(height: 30),
      Container(
        height: 8,
        width: double.infinity,
        color: AppColors.divider(context),
      ),
      const SizedBox(height: 30),
    ],
  );

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );

  Widget _chartLegend(String label, Color color) => Row(
    children: [
      Container(width: 10, height: 2, color: color),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.secondary),
      ),
    ],
  );

  Widget _buildHabitSection(int noExp, int total, int daysInMonth) {
    int avg = total ~/ (daysInMonth == 0 ? 1 : daysInMonth);
    return Row(
      children: [
        _habitBox("무지출", "$noExp일", "무지출 데이"),
        const SizedBox(width: 12),
        _habitBox("일평균 소비", "${nf.format(avg)}원", "하루 평균"),
      ],
    );
  }

  Widget _habitBox(String t, String v, String s) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textPrimary(context),
            ),
          ),
          Text(
            v,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            s,
            style: const TextStyle(fontSize: 12, color: AppColors.secondary),
          ),
        ],
      ),
    ),
  );

  Widget _buildCategoryAnalysis(List<MapEntry<String, int>> cats, int tot) {
    if (cats.isEmpty) return const Center(child: Text("데이터가 없습니다."));

    return Column(
      children: [
        SizedBox(
          height: 160,
          width: 160,
          child: CustomPaint(
            painter: PieChartPainter(categories: cats, total: tot),
          ),
        ),
        const SizedBox(height: 25),
        ...cats.take(4).map((e) {
          double p = tot > 0 ? (e.value / tot) * 100 : 0;

          String categoryName = e.key;
          if (categoryName.contains('name:')) {
            categoryName =
                RegExp(
                  r'name:\s*([^,}]+)',
                ).firstMatch(categoryName)?.group(1)?.trim() ??
                categoryName;
          }

          int budgetAmount = _budgetMap[categoryName] ?? 0;

          return Padding(
            padding: EdgeInsets.only(
              bottom: cats.indexOf(e) == cats.take(4).length - 1 ? 0 : 10,
            ),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(cats.indexOf(e)),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            "$categoryName ",
                            style: const TextStyle(fontSize: 15),
                          ),
                          Text(
                            "${p.toStringAsFixed(0)}%",
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        budgetAmount > 0
                            ? "예산 ${nf.format(budgetAmount)}원"
                            : "예산 미설정",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  "${nf.format(e.value)}원",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getCategoryColor(int i) {
    List<Color> cs = [
      const Color(0xFFE57373),
      const Color(0xFFF0AD4E),
      const Color(0xFFF4D03F),
      const Color(0xFF82E0AA),
      const Color(0xFF5DADE2),
    ];
    return cs[i % cs.length];
  }

  Widget _buildAssetSetting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "고정지출",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              "${nf.format(_paidFixedTotal + _upcomingFixedTotal)}원",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary(context),
              ),
            ),
          ],
        ),
        Divider(thickness: 1, color: AppColors.divider(context)),
        const SizedBox(height: 4),

        _buildExpenseRow(
          label: "나간 고정지출",
          amount: _paidFixedTotal,
          isExpanded: _showPaidFixed,
          items: _paidFixedItems,
          onToggle: () => setState(() => _showPaidFixed = !_showPaidFixed),
        ),
        const SizedBox(height: 10),

        _buildExpenseRow(
          label: "예정된 고정지출",
          amount: _upcomingFixedTotal,
          isExpanded: _showUpcomingFixed,
          items: _upcomingFixedItems,
          onToggle: () =>
              setState(() => _showUpcomingFixed = !_showUpcomingFixed),
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "변동지출",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              "${nf.format(_paidVariableTotal + _upcomingVariableTotal)}원",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary(context),
              ),
            ),
          ],
        ),
        Divider(thickness: 1, color: AppColors.divider(context)),
        const SizedBox(height: 4),

        _buildExpenseRow(
          label: "나간 변동지출",
          amount: _paidVariableTotal,
          isExpanded: _showPaidVariable,
          items: _paidVariableItems,
          onToggle: () =>
              setState(() => _showPaidVariable = !_showPaidVariable),
        ),
        const SizedBox(height: 10),

        _buildExpenseRow(
          label: "예정된 변동지출",
          amount: _upcomingVariableTotal,
          isExpanded: _showUpcomingVariable,
          items: _upcomingVariableItems,
          onToggle: () =>
              setState(() => _showUpcomingVariable = !_showUpcomingVariable),
        ),
      ],
    );
  }

  Widget _buildExpenseRow({
    required String label,
    required int amount,
    required bool isExpanded,
    required List<Map<String, dynamic>> items,
    required VoidCallback onToggle,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppColors.secondary),
            ),
            Row(
              children: [
                Text(
                  "${nf.format(amount)}원",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: items.isEmpty ? null : onToggle,
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: items.isEmpty
                        ? AppColors.divider(context)
                        : AppColors.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 8),
            child: Column(
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${item['day']}일 · ${item['name']}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondary,
                            ),
                          ),
                          Text(
                            "${nf.format(item['amount'])}원",
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar(String title, int used, int total) {
    double progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title),
              Text("${nf.format(used)} / ${nf.format(total)}원"),
            ],
          ),
          LinearProgressIndicator(
            value: progress,
            color: const Color(0xFF6C63FF),
          ),
        ],
      ),
    );
  }

  int _getUsedAmount(String type) {
    return dailyData
        .where((item) => item['type'] == type)
        .fold(0, (sum, item) => sum + (item['amount'] as int));
  }

  int _getTotalBudget(String type) {
    return _budgetMap.entries
        .where((e) => e.key.contains(type))
        .fold(0, (sum, e) => sum + e.value);
  }
}

class LineChartPainter extends CustomPainter {
  final int lastMonthTotal, currentMonthTotal, maxAmount;
  final List<int> dailyData, lastMonthData;
  final DateTime selectedMonth;
  final Color primaryColor;

  LineChartPainter({
    required this.lastMonthTotal,
    required this.currentMonthTotal,
    required this.maxAmount,
    required this.dailyData,
    required this.lastMonthData,
    required this.selectedMonth,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double lp = 45, bp = 20;
    double w = size.width - lp, h = size.height - bp;
    int days = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    double dW = w / (days - 1);

    final linePaint = Paint()
      ..color = AppColors.borderColor
      ..strokeWidth = 1;

    for (int i = 0; i <= 3; i++) {
      double lineY = h - (i * h / 3);

      canvas.drawLine(
        Offset(lp, lineY),
        Offset(size.width, lineY),
        linePaint,
      );

      String labelText = "${(maxAmount * i / 4 / 10000).toInt()}";

      _drawT(canvas, labelText, Offset(lp - 40, lineY - 5));
    }

    _drawT(canvas, "1일", Offset(lp, h + 5));
    _drawT(canvas, "${days}일", Offset(size.width - 20, h + 5));

    _drawPath(
      canvas,
      h,
      dW,
      lp,
      lastMonthData,
      AppColors.secondary.withOpacity(0.5),
      3,
    );
    _drawPath(
      canvas,
      h,
      dW,
      lp,
      dailyData,
      primaryColor,
      3,
      isCur: true,
    );
  }

  void _drawPath(
    Canvas canvas,
    double h,
    double dW,
    double lp,
    List<int> data,
    Color c,
    double sw, {
    bool isCur = false,
  }) {
    if (data.isEmpty) return;
    final path = Path()..moveTo(lp, h);
    for (int i = 0; i < data.length; i++) {
      double x = lp + (dW * i);
      double y =
          h - (data[i] / (maxAmount == 0 ? 1 : maxAmount) * h).clamp(0.0, h);
      path.lineTo(x, y);
      if (i == data.length - 1) {
        canvas.drawCircle(Offset(x, y), sw + 1, Paint()..color = c);
        if (isCur &&
            selectedMonth.month == DateTime.now().month &&
            selectedMonth.year == DateTime.now().year) {
          _drawT(canvas, "오늘", Offset(x - 10, h + 5), color: Colors.black);
          canvas.drawLine(
            Offset(x, 0),
            Offset(x, h),
            Paint()..color = AppColors.secondary,
          );
        }
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawT(
    Canvas c,
    String text,
    Offset o, {
    Color color = AppColors.secondary,
  }) {
    TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(color: AppColors.secondary, fontSize: 10),
        ),
        textDirection: ui.TextDirection.ltr,
      )
      ..layout()
      ..paint(c, o);
  }

  @override
  bool shouldRepaint(covariant LineChartPainter old) => true;
}

class PieChartPainter extends CustomPainter {
  final List<MapEntry<String, int>> categories;
  final int total;
  PieChartPainter({required this.categories, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0 || categories.isEmpty) return;

    double startAngle = -1.5708;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2,
    );
    for (int i = 0; i < categories.length; i++) {
      final sweepAngle = (categories[i].value / total) * 2 * 3.141592;
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        true,
        Paint()..color = _getPieColor(i),
      );
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        true,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      startAngle += sweepAngle;
    }
  }

  Color _getPieColor(int i) {
    List<Color> cs = [
      const Color(0xFFE57373),
      const Color(0xFFF0AD4E),
      const Color(0xFFF4D03F),
      const Color(0xFF82E0AA),
      const Color(0xFF5DADE2),
    ];
    return cs[i % cs.length];
  }

  @override
  bool shouldRepaint(covariant PieChartPainter old) => true;
}

class _AssetSettingWidget extends StatefulWidget {
  final List<Map<String, dynamic>> paidFixedItems;
  final List<Map<String, dynamic>> upcomingFixedItems;
  final List<Map<String, dynamic>> paidVariableItems;
  final List<Map<String, dynamic>> upcomingVariableItems;
  final int paidFixedTotal;
  final int upcomingFixedTotal;
  final int paidVariableTotal;
  final int upcomingVariableTotal;

  const _AssetSettingWidget({
    required this.paidFixedItems,
    required this.upcomingFixedItems,
    required this.paidVariableItems,
    required this.upcomingVariableItems,
    required this.paidFixedTotal,
    required this.upcomingFixedTotal,
    required this.paidVariableTotal,
    required this.upcomingVariableTotal,
  });

  @override
  State<_AssetSettingWidget> createState() => _AssetSettingWidgetState();
}

class _AssetSettingWidgetState extends State<_AssetSettingWidget> {
  final NumberFormat nf = NumberFormat('#,###');
  bool _showPaidFixed = false;
  bool _showUpcomingFixed = false;
  bool _showPaidVariable = false;
  bool _showUpcomingVariable = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "고정지출",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              "${nf.format(widget.paidFixedTotal + widget.upcomingFixedTotal)}원",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary(context),
              ),
            ),
          ],
        ),
        Divider(
          thickness: 1,
          color: AppColors.divider(context),
        ),
        const SizedBox(height: 4),
        _buildExpenseRow(
          label: "나간 고정지출",
          amount: widget.paidFixedTotal,
          isExpanded: _showPaidFixed,
          items: widget.paidFixedItems,
          onToggle: () => setState(() => _showPaidFixed = !_showPaidFixed),
        ),
        const SizedBox(height: 8),
        _buildExpenseRow(
          label: "예정된 고정지출",
          amount: widget.upcomingFixedTotal,
          isExpanded: _showUpcomingFixed,
          items: widget.upcomingFixedItems,
          onToggle: () =>
              setState(() => _showUpcomingFixed = !_showUpcomingFixed),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "변동지출",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              "${nf.format(widget.paidVariableTotal + widget.upcomingVariableTotal)}원",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary(context),
              ),
            ),
          ],
        ),
        Divider(thickness: 1, color: AppColors.divider(context)),
        const SizedBox(height: 4),
        _buildExpenseRow(
          label: "나간 변동지출",
          amount: widget.paidVariableTotal,
          isExpanded: _showPaidVariable,
          items: widget.paidVariableItems,
          onToggle: () =>
              setState(() => _showPaidVariable = !_showPaidVariable),
        ),
        const SizedBox(height: 8),
        _buildExpenseRow(
          label: "예정된 변동지출",
          amount: widget.upcomingVariableTotal,
          isExpanded: _showUpcomingVariable,
          items: widget.upcomingVariableItems,
          onToggle: () =>
              setState(() => _showUpcomingVariable = !_showUpcomingVariable),
        ),
      ],
    );
  }

  Widget _buildExpenseRow({
    required String label,
    required int amount,
    required bool isExpanded,
    required List<Map<String, dynamic>> items,
    required VoidCallback onToggle,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Text(
                  "${nf.format(amount)}원",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: items.isEmpty ? null : onToggle,
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: items.isEmpty
                        ? AppColors.divider(context)
                        : AppColors.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (isExpanded)
          Container(
            margin: EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(
              left: 15,
              right: 15,
              top: 15,
              bottom: 5,
            ),
            decoration: BoxDecoration(
              color: AppColors.divider(context),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              children: items
                  .map(
                    (item) => Container(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondary,
                                ),
                                children: [
                                  TextSpan(text: "${item['day']}일 · "),
                                  TextSpan(
                                    text: "${item['name']}",
                                    style: TextStyle(
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Text(
                              "${nf.format(item['amount'])}원",
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
