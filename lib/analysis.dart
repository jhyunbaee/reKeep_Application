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

  // 💡 성능 보존 및 비동기 폭사 방지를 위해 예산 데이터를 한 번에 담아둘 맵
  Map<String, int> _budgetMap = {};
  bool _isBudgetLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllBudgets(); // 💡 위젯 진입 시 예산 데이터를 단 딱 한 번만 일괄 로드합니다.
  }

  // 💡 카테고리 내부에서 무한 FutureBuilder를 돌리는 대신, 이 함수로 전체 예산을 한방에 긁어옵니다.
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

    // 예산 로딩 중일 때는 에뮬레이터 먹통 방지를 위해 인디케이터 표시
    if (_isBudgetLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
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
                child: const Icon(
                  Icons.chevron_left,
                  color: Colors.black,
                  size: 28,
                ),
              ),
              Text(
                "$currentMonth월",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 20,
                ),
              ),
              GestureDetector(
                onTap: () => setState(
                  () =>
                      _selectedMonth = DateTime(currentYear, currentMonth + 1),
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
                _withPadding(_buildTop3List(top3)),
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
          height: 200,
          width: double.infinity,
          child: CustomPaint(
            painter: LineChartPainter(
              lastMonthTotal: last,
              currentMonthTotal: current,
              maxAmount: maxVal,
              dailyData: dailyData,
              lastMonthData: lastData,
              selectedMonth: _selectedMonth,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _chartLegend("지난달", Colors.grey),
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
        color: AppColors.dividerColor,
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
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.grey)),
    ],
  );

  // 소비 습관
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

  // 소비 습관
  Widget _habitBox(String t, String v, String s) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: const TextStyle(fontSize: 12, color: Colors.black)),
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

  // 카테고리별 지출
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

          // initState 단계에서 미리 긁어온 _budgetMap을 즉시 메모리에서 조회(O(1))합니다.
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
                          color: Colors.grey.shade500,
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

  Widget _buildTop3List(List<Map<String, dynamic>> top3) {
    if (top3.isEmpty) return const Center(child: Text("지출 내역이 없습니다."));
    return Column(
      children: top3.asMap().entries.map((entry) {
        var data = entry.value;
        String title =
            data['place']?.toString() ?? data['title']?.toString() ?? "항목 없음";
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Text(
                "${entry.key + 1}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15),
                ),
              ),
              Text(
                "${nf.format(data['amount'] ?? 0)}원",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
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

    final p = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;
    for (int i = 0; i <= 2; i++) {
      double y = h - (h / 2 * i);
      canvas.drawLine(Offset(lp, y), Offset(size.width, y), p);
      _drawT(
        canvas,
        '${((maxAmount / 2 * i) / 10000).toInt()}만',
        Offset(0, y - 6),
      );
    }
    _drawT(canvas, "1일", Offset(lp, h + 5));
    _drawT(canvas, "${days}일", Offset(size.width - 25, h + 5));

    _drawPath(
      canvas,
      h,
      dW,
      lp,
      lastMonthData,
      Colors.grey.withOpacity(0.4),
      2,
    );
    _drawPath(
      canvas,
      h,
      dW,
      lp,
      dailyData,
      const Color(0xFF6C63FF),
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
            Paint()..color = AppColors.primaryLight,
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

  void _drawT(Canvas c, String t, Offset o, {Color color = AppColors.grey}) {
    TextPainter(
        text: TextSpan(
          text: t,
          style: TextStyle(color: color, fontSize: 10),
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
