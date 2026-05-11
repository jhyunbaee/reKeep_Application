import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rekeep/constants/colors.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final userId = FirebaseAuth.instance.currentUser?.uid;

  Stream<QuerySnapshot> _getRecordsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId ?? 'guest')
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(
            () =>
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1),
          ),
        ),
        title: Text(
          DateFormat('M월').format(_focusedDay),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(
              () => _focusedDay = DateTime(
                _focusedDay.year,
                _focusedDay.month + 1,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getRecordsStream(),
        builder: (context, snapshot) {
          Map<String, List<Map<String, dynamic>>> dailyRecords = {};
          int totalIncome = 0;
          int totalExpense = 0;

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              DateTime date = (data['date'] as Timestamp).toDate();
              String dateKey = DateFormat('yyyy-MM-dd').format(date);
              if (!dailyRecords.containsKey(dateKey))
                dailyRecords[dateKey] = [];
              dailyRecords[dateKey]!.add(data);
              if (data['type'] == '수입')
                totalIncome += (data['amount'] as int);
              else
                totalExpense += (data['amount'] as int);
            }
          }

          return SingleChildScrollView(
            // 하단에 바텀 바 높이만큼 여백을 추가합니다 (약 80~100 정도)
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              children: [
                _buildSummaryCard(totalIncome, totalExpense),
                _buildNoSpendHighlight(dailyRecords),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TableCalendar(
                    locale: 'ko_KR',
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    availableGestures: AvailableGestures.none,
                    daysOfWeekHeight: 20,
                    headerVisible: false,
                    rowHeight: 80,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });

                      // 해당 날짜의 데이터 키 생성
                      String dateKey = DateFormat(
                        'yyyy-MM-dd',
                      ).format(selectedDay);

                      // 내역이 있는 경우에만 상세 보기 바텀 시트 열기
                      if (dailyRecords.containsKey(dateKey) &&
                          dailyRecords[dateKey]!.isNotEmpty) {
                        _showDetailListSheet(dailyRecords[dateKey]!);
                      }
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        String dateKey = DateFormat('yyyy-MM-dd').format(date);
                        if (!dailyRecords.containsKey(dateKey) &&
                            date.isBefore(
                              DateTime.now().add(const Duration(days: 1)),
                            )) {
                          return Positioned(
                            top: 10,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: AppColors.pointColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          );
                        }
                        return null;
                      },
                      defaultBuilder: (context, date, _) {
                        Color dateColor = Colors.black;
                        if (date.weekday == DateTime.sunday ||
                            date.weekday == DateTime.saturday) {
                          dateColor = AppColors.secondary;
                        }
                        return _buildDayCell(
                          date,
                          dateColor,
                          dailyRecords,
                          false,
                          isToday: false,
                        );
                      },
                      todayBuilder: (context, date, _) => _buildDayCell(
                        date,
                        AppColors.primary, // 오늘 날짜 텍스트 색상
                        dailyRecords,
                        isSameDay(_selectedDay, date), // 오늘이면서 선택되었는지 확인
                        isToday: true, // 오늘임을 알려줌
                      ),
                      selectedBuilder: (context, date, _) {
                        Color dateColor = Colors.black;
                        if (date.weekday == DateTime.sunday ||
                            date.weekday == DateTime.saturday) {
                          dateColor = AppColors.secondary;
                        }
                        return _buildDayCell(
                          date,
                          dateColor,
                          dailyRecords,
                          false,
                          isToday: false,
                        );
                      },
                    ),
                    calendarStyle: const CalendarStyle(
                      outsideDaysVisible: false,
                      todayDecoration: BoxDecoration(color: Colors.transparent),
                      defaultTextStyle: TextStyle(color: Colors.black),
                      weekendTextStyle: TextStyle(
                        color: AppColors.secondary,
                      ), // 주말은 빨간색으로
                    ),
                    weekendDays: const [DateTime.saturday, DateTime.sunday],
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(color: Colors.black), // 평일 검정
                      weekendStyle: TextStyle(
                        color: AppColors.secondary,
                      ), // 일요일 기본 빨강
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRecordSheet, // 바텀 시트 호출
        backgroundColor: AppColors.primary,
        label: const Text(
          "+",
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }

  Widget _buildDayCell(
    DateTime date,
    Color textColor,
    Map dailyRecords,
    bool isSelected, {
    bool isToday = false,
  }) {
    String dateKey = DateFormat('yyyy-MM-dd').format(date);
    List<Map<String, dynamic>>? records = dailyRecords[dateKey]
        ?.cast<Map<String, dynamic>>();

    // --- 합계 계산 로직 추가 ---
    int dayTotalIncome = 0;
    int dayTotalExpense = 0;

    if (records != null) {
      for (var item in records) {
        if (item['type'] == '수입') {
          dayTotalIncome += (item['amount'] as int);
        } else {
          dayTotalExpense += (item['amount'] as int);
        }
      }
    }

    return Column(
      children: [
        const SizedBox(height: 18),
        SizedBox(
          height: 32,
          width: 32,
          child: Center(
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: isToday
                    ? FontWeight.bold
                    : (isSelected ? FontWeight.bold : FontWeight.normal),
                height: 1.0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // --- 요약 영역 (수입 우선, 총액 표시) ---
        SizedBox(
          height: 26,
          child: Column(
            children: [
              // 1. 수입 총액 (0원보다 클 때만 표시)
              if (dayTotalIncome > 0)
                Text(
                  "+${NumberFormat('#,###').format(dayTotalIncome)}",
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.primary,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              // 2. 지출 총액 (0원보다 클 때만 표시)
              if (dayTotalExpense > 0)
                Text(
                  "-${NumberFormat('#,###').format(dayTotalExpense)}",
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.secondary,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(int income, int expense) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(Colors.white),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _amountRow("수입", income, AppColors.primary),
              _amountRow("지출", expense, AppColors.pointColor),
            ],
          ),
          const Divider(
            height: 30,
            thickness: 1,
            color: AppColors.secondaryLight,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // RichText를 사용하여 부분별로 스타일을 다르게 설정
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "현 자산",
                      style: TextStyle(
                        fontSize: 14, // 크기 변경
                        color: AppColors.secondary, // 색상 변경 (예: 회색)
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const TextSpan(
                      text: "  ", // 공백 유지
                    ),
                  ],
                ),
              ),
              Text(
                "${NumberFormat('#,###').format(income - expense)}원",
                style: const TextStyle(
                  fontSize: 20,
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(color: AppColors.secondary, fontSize: 14),
        ),
        const SizedBox(width: 30),
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
    int currentMonth = _focusedDay.month;
    int daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    for (int i = 1; i <= daysInMonth; i++) {
      DateTime day = DateTime(_focusedDay.year, _focusedDay.month, i);
      if (day.isAfter(DateTime.now())) break;
      if (!dailyRecords.containsKey(DateFormat('yyyy-MM-dd').format(day)))
        noSpendCount++;
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryLightv2, // 배경은 흰색이어야 그림자가 잘 보여요!
        borderRadius: BorderRadius.circular(12), // 모서리를 둥글게
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // 아주 연한 그림자
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4), // 아래 방향으로 살짝 그림자 추가
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // 1. 작은 점(Icon) 추가
              const Icon(
                Icons.circle,
                size: 6, // 점의 크기
                color: AppColors.pointColor, // 점의 색상
              ),
              const SizedBox(width: 6), // 점과 텍스트 사이 간격
              Text(
                "$currentMonth월 무지출",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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

  BoxDecoration _cardDecoration(Color color) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  void _showDetailListSheet(List<Map<String, dynamic>> records) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단 핸들러
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "${DateFormat('M월 d일').format(_selectedDay!)} 내역",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              // 내역 리스트
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final item = records[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: item['type'] == '수입'
                            ? Colors.blue[50]
                            : Colors.red[50],
                        child: Icon(
                          item['type'] == '수입' ? Icons.add : Icons.remove,
                          color: item['type'] == '수입'
                              ? AppColors.primary
                              : AppColors.pointColor,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        item['memo'].isEmpty ? "내역 없음" : item['memo'],
                      ),
                      trailing: Text(
                        "${NumberFormat('#,###').format(item['amount'])}원",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: item['type'] == '수입'
                              ? AppColors.primary
                              : AppColors.pointColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // date 인자 추가
  void _saveRecord(
    String type,
    String amountStr,
    String memo,
    DateTime date,
  ) async {
    if (amountStr.isEmpty) return;
    int amount = int.parse(amountStr);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('records')
        .add({
          'type': type,
          'amount': amount,
          'memo': memo,
          'date': Timestamp.fromDate(date), // 선택한 날짜로 저장
          'createdAt': FieldValue.serverTimestamp(),
        });

    if (!mounted) return;
    Navigator.pop(context);
  }

  // 내역 추가 바텀 시트 (iOS 스타일)
  void _showAddRecordSheet() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController memoController = TextEditingController();
    String selectedType = '지출'; // 기본값
    DateTime tempDate = _selectedDay ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 화면 절반 이상 높이 조절 가능하게
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          // 바텀 시트 내에서 상태 변경(수입/지출 전환)을 위해 필요
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, // 키보드 높이만큼 패딩
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildTypeButton(
                          "지출",
                          selectedType == '지출',
                          () => setModalState(() => selectedType = '지출'),
                        ),
                        const SizedBox(width: 10),
                        _buildTypeButton(
                          "수입",
                          selectedType == '수입',
                          () => setModalState(() => selectedType = '수입'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "금액",
                        hintText: "0",
                        suffixText: "원",
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: memoController,
                      decoration: const InputDecoration(
                        labelText: "메모",
                        hintText: "어디에 쓰셨나요?",
                      ),
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: tempDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setModalState(() => tempDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "날짜",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(DateFormat('yyyy년 M월 d일').format(tempDate)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () => _saveRecord(
                          selectedType,
                          amountController.text,
                          memoController.text,
                          tempDate,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          "저장하기",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 타입 선택 버튼 (수입/지출)
  Widget _buildTypeButton(String title, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 45,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
