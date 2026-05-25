import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'dart:ui' as ui;

class Analysis extends StatefulWidget {
  const Analysis({super.key});

  @override
  State<Analysis> createState() => _AnalysisState();
}

class _AnalysisState extends State<Analysis> {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final NumberFormat nf = NumberFormat('#,###');
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

  Future<void> _loadInitialData() async {
    await _loadAllBudgets();
    await _getFixedItemsList();
    await _loadRecurringExpenses();
    setState(() {
      _isBudgetLoading = false;
    });
  }

  Future<void> _loadRecurringExpenses() async {
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recurring_expenses')
        .get();

    final int today = DateTime.now().day;
    int paid = 0, upcoming = 0, paidVar = 0, upcomingVar = 0;
    List<Map<String, dynamic>> paidFixedList = [];
    List<Map<String, dynamic>> upcomingFixedList = [];
    List<Map<String, dynamic>> paidVarList = [];
    List<Map<String, dynamic>> upcomingVarList = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final int amount = (data['amount'] ?? 0) as int;
      var dayData = data['day'] ?? '1일';
      final int day = (dayData is String)
          ? int.tryParse(dayData.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1
          : (dayData as int);
      final String expenseType = data['expenseType'] ?? '고정지출';
      final String name = data['name'] ?? '';

      final item = {'name': name, 'amount': amount, 'day': day};

      if (expenseType == '고정지출') {
        if (day <= today) {
          paid += amount;
          paidFixedList.add(item);
        } else {
          upcoming += amount;
          upcomingFixedList.add(item);
        }
      } else {
        if (day <= today) {
          paidVar += amount;
          paidVarList.add(item);
        } else {
          upcomingVar += amount;
          upcomingVarList.add(item);
        }
      }
    }

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
  }

  Future<void> _loadAllBudgets() async {
    if (userId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .get();

      final Map<String, int> tempBudgets = {};
      for (var doc in snapshot.docs) {
        tempBudgets[doc.id] = (doc.data()['amount'] ?? 0) as int;
      }

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

    final int daysInCurrentMonth = DateTime(
      currentYear,
      currentMonth + 1,
      0,
    ).day;
    final int daysInLastMonth = DateTime(lastYear, lastMonth + 1, 0).day;

    if (_isBudgetLoading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

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
              GestureDetector(
                onTap: () => setState(
                  () =>
                      _selectedMonth = DateTime(currentYear, currentMonth - 1),
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
                  fontSize: 20,
                ),
              ),
              GestureDetector(
                onTap: () => setState(
                  () =>
                      _selectedMonth = DateTime(currentYear, currentMonth + 1),
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
              isGreaterThanOrEqualTo: DateTime(lastYear, lastMonth, 1),
            )
            .where(
              'date',
              isLessThanOrEqualTo: DateTime(currentYear, currentMonth + 1, 0),
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
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

              if (type == '지출') {
                if (date.month == currentMonth && date.year == currentYear) {
                  currentMonthTotal += amount;
                  currentMonthExpenseDays.add(date.day);
                  currentMonthExpenses.add(data);
                  categoryTotals[category] =
                      (categoryTotals[category] ?? 0) + amount;

                  if (date.day <= daysInCurrentMonth) {
                    dailyAmounts[date.day] += amount;
                  }
                } else if (date.month == lastMonth && date.year == lastYear) {
                  lastMonthTotal += amount;
                  if (date.day <= daysInLastMonth) {
                    lastDailyAmounts[date.day] += amount;
                  }
                }
              }
            }
          }

          currentMonthExpenses.sort(
            (a, b) => (b['amount'] ?? 0).compareTo(a['amount'] ?? 0),
          );
          var top3 = currentMonthExpenses.take(3).toList();
          var sortedCategories = categoryTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          int noExpenseDays =
              daysInCurrentMonth - currentMonthExpenseDays.length;

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
                  _buildCategoryAnalysis(sortedCategories, currentMonthTotal),
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

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
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
          height: 250,
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
                size: Size(double.infinity, 200),
                painter: LineChartPainter(
                  lastMonthTotal: last,
                  currentMonthTotal: current,
                  maxAmount: maxVal,
                  dailyData: dailyData,
                  lastMonthData: lastData,
                  selectedMonth: _selectedMonth,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _chartLegend("지난달", AppColors.secondary),
            const SizedBox(width: 20),
            _chartLegend("이번달", AppColors.primary),
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
      const SizedBox(height: 20),
      Container(
        height: 8,
        width: double.infinity,
        color: AppColors.divider(context),
      ),
      const SizedBox(height: 20),
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
    int div =
        (_selectedMonth.month == DateTime.now().month &&
            _selectedMonth.year == DateTime.now().year)
        ? DateTime.now().day
        : daysInMonth;
    int avg = total ~/ (div == 0 ? 1 : div);
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
              fontSize: 12,
              color: AppColors.textPrimary(context),
            ),
          ),
          Text(
            v,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
            padding: const EdgeInsets.only(bottom: 0),
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
                              fontSize: 14,
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
                          fontWeight: FontWeight.w500,
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.pointColor,
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
        const SizedBox(height: 8),

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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.pointColor,
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
        const SizedBox(height: 8),

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

  LineChartPainter({
    required this.lastMonthTotal,
    required this.currentMonthTotal,
    required this.maxAmount,
    required this.dailyData,
    required this.lastMonthData,
    required this.selectedMonth,
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
      AppColors.primary,
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
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
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: items
                  .map(
                    (item) => Container(
                      decoration: BoxDecoration(
                        color: AppColors.divider(context),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
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
