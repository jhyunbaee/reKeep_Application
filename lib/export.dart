import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Border;
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:flutter_rekeep/premium_gate.dart';
import 'package:flutter_rekeep/premium_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:flutter/painting.dart' show Border;

class Export extends StatefulWidget {
  const Export({super.key});

  @override
  State<Export> createState() => _ExportState();
}

class _ExportState extends State<Export> {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final nf = NumberFormat('#,###');

  bool _isExporting = false;
  String _exportType = 'xlsx';

  late int _selectedYear;
  late int _selectedMonthNum;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonthNum = now.month;
  }

  DateTime get _selectedMonth => DateTime(_selectedYear, _selectedMonthNum);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          "데이터 내보내기",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "기간 선택",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider(context)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        menuMaxHeight: 200,
                        dropdownColor: AppColors.background(context),
                        borderRadius: BorderRadius.circular(10),
                        value: _selectedYear,
                        isExpanded: true,
                        items: List.generate(5, (i) {
                          final year = DateTime.now().year - i;
                          return DropdownMenuItem(
                            value: year,
                            child: Text('${year}년'),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedYear = val);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider(context)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        menuMaxHeight: 200,
                        dropdownColor: AppColors.background(context),
                        borderRadius: BorderRadius.circular(10),
                        value: _selectedMonthNum,
                        isExpanded: true,
                        items: List.generate(12, (i) {
                          return DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1}월'),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null)
                            setState(() => _selectedMonthNum = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 파일 형식
            const Text(
              "파일 형식",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider(context)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  menuMaxHeight: 200,
                  dropdownColor: AppColors.background(context),
                  borderRadius: BorderRadius.circular(10),
                  value: _exportType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'xlsx', child: Text('엑셀 (.xlsx)')),
                    DropdownMenuItem(value: 'csv', child: Text('CSV (.csv)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _exportType = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "내보낼 수 있는 데이터",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.divider(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(context, "날짜, 사용처, 금액, 카테고리"),
                  _buildInfoRow(context, "수입/지출/이체 구분"),
                  _buildInfoRow(context, "결제 수단"),
                  _buildInfoRow(context, "메모"),
                ],
              ),
            ),
            const Spacer(),

            // 내보내기 버튼
            SizedBox(
              height: 55,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isExporting ? null : _onExport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  disabledBackgroundColor: AppColors.divider(context),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "${_selectedYear}년 ${_selectedMonthNum}월 내보내기",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(Icons.check, size: 14, color: AppColors.primary(context)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _onExport() async {
    // 프리미엄 보류 - 데이터 내보내기 무료 공개
    // (프리미엄 부활 시 아래 주석 블록 복원)
    // final isPremium = await PremiumService.isPremium();
    // if (!isPremium) {
    //   if (!mounted) return;
    //   await PremiumGate.show(context, message: "데이터 내보내기는 프리미엄 회원만 사용할 수 있어요.");
    //   return;
    // }

    setState(() => _isExporting = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('records')
          .where(
            'date',
            isGreaterThanOrEqualTo: DateTime(
              _selectedYear,
              _selectedMonthNum,
              1,
            ),
          )
          .where(
            'date',
            isLessThan: DateTime(_selectedYear, _selectedMonthNum + 1, 1),
          )
          .orderBy('date', descending: false)
          .get();

      if (snapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("해당 월의 데이터가 없어요.")),
        );
        setState(() => _isExporting = false);
        return;
      }

      if (_exportType == 'xlsx') {
        await _exportExcel(snapshot.docs);
      } else {
        await _exportCsv(snapshot.docs);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("내보내기 실패: $e")),
      );
    }

    if (mounted) setState(() => _isExporting = false);
  }

  Future<void> _exportExcel(List<QueryDocumentSnapshot> docs) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel['거래내역'];

    final headers = ['날짜', '사용처', '금액', '카테고리', '유형', '결제수단', '메모'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(headers[i])
        ..cellStyle = CellStyle(bold: true);
    }

    for (int i = 0; i < docs.length; i++) {
      final data = docs[i].data() as Map<String, dynamic>;
      final date = (data['date'] as Timestamp).toDate();
      final category = data['category'];
      final categoryName = category is Map
          ? category['name'] ?? ''
          : category?.toString() ?? '';

      final row = [
        DateFormat('yyyy-MM-dd').format(date),
        data['place'] ?? '',
        data['amount']?.toString() ?? '0',
        categoryName,
        data['type'] ?? '',
        data['paymentMethod'] ?? '',
        data['memo'] ?? '',
      ];

      for (int j = 0; j < row.length; j++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1))
            .value = TextCellValue(
          row[j],
        );
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'rekeep_${_selectedYear}-${_selectedMonthNum.toString().padLeft(2, "0")}.xlsx';
    final file = File('${dir.path}/$fileName');
    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("파일 생성에 실패했어요.")),
        );
      }
      return;
    }
    await file.writeAsBytes(bytes, flush: true);
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(file.path)],
      sharePositionOrigin: box == null
          ? Rect.fromLTWH(0, 0, 400, 900)
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _exportCsv(List<QueryDocumentSnapshot> docs) async {
    final headers = '날짜,사용처,금액,카테고리,유형,결제수단,메모\n';
    final rows = docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final date = (data['date'] as Timestamp).toDate();
          final category = data['category'];
          final categoryName = category is Map
              ? category['name'] ?? ''
              : category?.toString() ?? '';

          return [
            DateFormat('yyyy-MM-dd').format(date),
            data['place'] ?? '',
            data['amount']?.toString() ?? '0',
            categoryName,
            data['type'] ?? '',
            data['paymentMethod'] ?? '',
            (data['memo'] ?? '').toString().replaceAll(',', ' '),
          ].join(',');
        })
        .join('\n');

    final csvContent = headers + rows;
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'rekeep_${_selectedYear}-${_selectedMonthNum.toString().padLeft(2, "0")}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(
      csvContent,
      encoding: const Utf8Codec(),
      flush: true,
    );
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(file.path)],
      sharePositionOrigin: box == null
          ? Rect.fromLTWH(0, 0, 400, 900)
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }
}
