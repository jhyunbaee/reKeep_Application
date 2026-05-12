import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rekeep/category.dart';
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
  DateTime _focusedDay = DateTime.now();
  DateTime tempDate = DateTime.now();
  DateTime? _selectedDay;
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final NumberFormat formatter = NumberFormat('#,###');

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false, // 기본 뒤로가기 버튼 공간 제거
        // 💡 핵심: titleSpacing을 0으로 하고 title에 Row를 꽉 채웁니다.
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
      body: StreamBuilder<QuerySnapshot>(
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
              } else {
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
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              children: [
                _buildSummaryCard(totalIncome, totalExpense),
                _buildNoSpendHighlight(dailyRecords),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 20,
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
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });

                      String dateKey = DateFormat(
                        'yyyy-MM-dd',
                      ).format(selectedDay);

                      if (dailyRecords.containsKey(dateKey) &&
                          dailyRecords[dateKey]!.isNotEmpty) {
                        _showDetailListSheet(); // 괄호 안이 비어있음 (OK)
                      }
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        String dateKey = DateFormat('yyyy-MM-dd').format(date);
                        if (date.month != _focusedDay.month) return null;
                        if (!dailyRecords.containsKey(dateKey) ||
                            dailyRecords[dateKey]!.isEmpty) {
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
                      defaultBuilder: (context, date, _) => _buildDayCell(
                        date,
                        (date.weekday == 7 || date.weekday == 6)
                            ? AppColors.secondary
                            : Colors.black,
                        dailyRecords,
                        false,
                      ),
                      // 2. 오늘 날짜 빌더
                      todayBuilder: (context, date, _) => _buildDayCell(
                        date,
                        AppColors.primary,
                        dailyRecords,
                        isSameDay(_selectedDay, date),
                        isToday: true,
                      ),
                      // 3. 선택된 날짜 빌더 (이 부분을 추가하여 간격 틀어짐 방지)
                      selectedBuilder: (context, date, _) {
                        bool isToday = isSameDay(date, DateTime.now());
                        Color textColor;

                        if (isToday) {
                          textColor = AppColors.primary;
                        } else if (date.weekday == DateTime.sunday ||
                            date.weekday == DateTime.saturday) {
                          textColor = AppColors.secondary;
                        } else {
                          textColor = Colors.black;
                        }

                        return _buildDayCell(
                          date,
                          textColor,
                          dailyRecords,
                          // 다른 날을 선택했을 때 Bold가 되는 게 싫다면 여기서 false를 줍니다.
                          false,
                          isToday: isToday, // 오늘 날짜면 true가 전달되어 Bold가 유지됩니다.
                        );
                      },
                    ),
                    calendarStyle: const CalendarStyle(
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
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        // 인자 없이 호출하도록 괄호를 붙여줍니다. (새 내역 추가 모드)
        onPressed: () => _showAddRecordSheet(),
        backgroundColor: AppColors.primary,
        label: const Text(
          "+",
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }

  // --- 2. UI 구성 요소 ---
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
    int income = 0, expense = 0;
    int totalBalance = income - expense;
    if (records != null) {
      for (var r in records) {
        if (r['type'] == '수입')
          income += (r['amount'] as int);
        else
          expense += (r['amount'] as int);
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
        const SizedBox(height: 4),
        SizedBox(
          height: 26,
          child: Column(
            children: [
              if (income > 0)
                Text(
                  "+${NumberFormat('#,###').format(income)}",
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.primary,
                    height: 1.1,
                  ),
                ),
              if (expense > 0)
                Text(
                  "-${NumberFormat('#,###').format(expense)}",
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.grey,
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
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryLight,
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
          const Divider(
            height: 30,
            thickness: 1,
            color: AppColors.secondaryLight,
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
      if (!dailyRecords.containsKey(dateKey) || dailyRecords[dateKey]!.isEmpty)
        noSpendCount++;
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.primaryLightv2,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryLight,
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

  // 1. 함수 선언부에 initialData와 docId를 추가합니다.
  void _showAddRecordSheet({Map<String, dynamic>? initialData, String? docId}) {
    // initialData가 있으면 수정 모드, 없으면 추가 모드가 됩니다.

    // 2. 초기값 세팅: 데이터가 있으면 기존 값 사용, 없으면 기본값 사용
    String selectedType = initialData?['type'] ?? '지출';

    // 날짜 처리 (Timestamp 타입인 경우를 고려)
    DateTime tempDate;
    if (initialData != null && initialData['date'] != null) {
      tempDate = (initialData['date'] as Timestamp).toDate();
    } else {
      tempDate = _selectedDay ?? DateTime.now();
    }

    // 금액 포맷팅 (수정 시 "10,000원" 형태로 바로 보이게)
    final NumberFormat formatter = NumberFormat('#,###');
    String initialAmount = "";
    if (initialData != null && initialData['amount'] != null) {
      initialAmount = "${formatter.format(initialData['amount'])}원";
    }

    final TextEditingController amountController = TextEditingController(
      text: initialAmount,
    );
    final TextEditingController placeController = TextEditingController(
      text: initialData?['place'] ?? "",
    );
    final TextEditingController memoController = TextEditingController(
      text: initialData?['memo'] ?? "",
    );

    Map<String, String> selectedCategory = initialData?['category'] != null
        ? Map<String, String>.from(initialData?['category'])
        : {'name': '미분류', 'icon': '❓'};

    String selectedPayment = initialData?['paymentMethod'] ?? '카드';

    // --- 금액 입력 리스너 (원, 콤마 추가 로직) ---
    amountController.addListener(() {
      String text = amountController.text
          .replaceAll(',', '')
          .replaceAll('원', '')
          .trim();
      if (text.isEmpty) return;
      double? value = double.tryParse(text);
      if (value != null) {
        String newText = "${formatter.format(value)}원";
        if (newText != amountController.text) {
          amountController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length - 1),
          );
        }
      }
    });

    Stream<QuerySnapshot> _getMyCards() {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('my_cards')
          .snapshots();
    }

    Future<String?> _showPaymentPicker(List<String> options) async {
      return await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "결제수단 선택",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height * 0.4, // 최대 높이 제한
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                        options[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      onTap: () => Navigator.pop(context, options[index]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close), // 순수 아이콘만 사용
                    ),
                  ],
                ),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    hintText: "0원",
                    border: InputBorder.none,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
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
                          selectedCategory = {'name': '미분류', 'icon': '❓'};
                        }),
                      ),
                      const SizedBox(width: 10),
                      _buildTypeButton(
                        "수입",
                        selectedType == '수입',
                        () => setModalState(() {
                          selectedType = '수입';
                          // 타입을 바꿀 때 카테고리를 기본값으로 초기화하고 싶다면:
                          selectedCategory = {'name': '미분류', 'icon': '❓'};
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
                      final result = await _showCategoryPicker(selectedType);
                      if (result != null) {
                        setModalState(() => selectedCategory = result);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 15),
                const Divider(height: 1, color: AppColors.dividerColor),
                const SizedBox(height: 15),
                _buildInputRow(
                  "결제수단",
                  _buildSelectableBox(
                    selectedPayment, // 현재 선택된 값 변수
                    () async {
                      // 1. 내 카드 목록 가져오기
                      final cardSnapshot = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('my_cards')
                          .get();

                      // 2. 기본 옵션 '현금'에 DB에서 가져온 카드 이름들 추가
                      List<String> options = ['현금'];
                      options.addAll(
                        cardSnapshot.docs.map(
                          (doc) => doc['cardName'].toString(),
                        ),
                      );

                      // 3. 만들어둔 피커 함수 호출
                      final selected = await _showPaymentPicker(options);

                      if (selected != null) {
                        // Modal 내부에 state를 변경해야 하므로 setModalState 사용
                        setModalState(() {
                          selectedPayment = selected;
                        });
                      }
                    },
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
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(tempDate),
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
                    if (docId != null) // 수정 시에만 삭제 버튼 노출
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          height: 55,
                          child: OutlinedButton(
                            onPressed: () => _saveRecord(
                              docId: docId,
                              isDelete: true, // 삭제 실행
                              type: '',
                              amount: '',
                              place: '',
                              category: {},
                              payment: '',
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
                            date: tempDate,
                            memo: memoController.text,
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
                } else {
                  expense += (data['amount'] as int);
                }
              }
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
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, // 💡 전체 왼쪽 정렬
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
                        color: AppColors.grey,
                      ),
                    ),

                    // 💡 Spacer가 남는 공간을 다 차지해서 다음 위젯들을 오른쪽으로 밀어냅니다.
                    const Spacer(),

                    if (income > 0)
                      Text(
                        "+${NumberFormat('#,###').format(income)}원",
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),

                    // 2. 수입과 지출이 모두 0원보다 클 때만 중간 간격(12px) 추가
                    if (income > 0 && expense > 0) const SizedBox(width: 12),

                    // 3. 지출이 0원보다 클 때만 표시
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
                  color: AppColors.secondaryLight,
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: currentRecords.length,
                    itemBuilder: (context, index) {
                      // 1. 현재 순서의 데이터 가져오기 (이미 Map 형태입니다)
                      final item = currentRecords[index];

                      // 2. [수정] 이미 item 자체가 Map이므로 .data()를 호출할 필요가 없습니다.
                      final data = item;

                      // 3. [수정] 이전에 data['docId']에 ID를 저장했으므로 맵에서 꺼내옵니다.
                      final docId = item['docId'];

                      final isIncome = data['type'] == '수입';
                      final icon = (data['category'] is Map)
                          ? data['category']['icon']
                          : '💰';
                      final catName = (data['category'] is Map)
                          ? data['category']['name']
                          : '미분류';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          _showAddRecordSheet(
                            initialData: data,
                            docId: docId,
                          );
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              catName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.grey,
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          "${isIncome ? '' : '-'}${NumberFormat('#,###').format(item['amount'])}원",
                          style: TextStyle(
                            fontSize: 16,
                            color: isIncome ? AppColors.primary : Colors.black,
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
            color: AppColors.grey,
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
            color: Colors.grey,
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
          width: 70, // 2. 원하는 너비값을 직접 지정합니다.
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.grey,
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
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
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
                        border: Border.all(color: AppColors.borderColor),
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
    required DateTime date,
    required String memo,
    bool isDelete = false, // 삭제 플래그
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
        'date': Timestamp.fromDate(date),
        'memo': memo,
      };

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
