import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rekeep/notification_service.dart';
import 'package:flutter_rekeep/constants/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationSetting extends StatefulWidget {
  const NotificationSetting({super.key});

  @override
  State<NotificationSetting> createState() => _NotificationSettingPageState();
}

class _NotificationSettingPageState extends State<NotificationSetting> {
  int _hour = 9;
  int _minute = 0;

  bool _isNotificationEnabled = true;
  bool _isMonthlyEnabled = false;
  bool _isFixedExpenseEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadAlarmTime();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotificationEnabled = prefs.getBool('is_notification_enabled') ?? true;
      _isMonthlyEnabled = prefs.getBool('is_monthly_enabled') ?? false;
      _isFixedExpenseEnabled =
          prefs.getBool('is_fixed_expense_enabled') ?? false;
    });
  }

  Future<void> _loadAlarmTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hour = prefs.getInt('alarm_hour') ?? 9;
      _minute = prefs.getInt('alarm_minute') ?? 0;
    });
  }

  Future<void> _handleAlarmTimeSetting() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          height: 250,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 5, top: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
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
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(2026, 1, 1, _hour, _minute),
                  onDateTimeChanged: (DateTime newTime) {
                    _hour = newTime.hour;
                    _minute = newTime.minute;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    await _saveAlarmSetting();

    setState(() {});
  }

  Future<void> _saveAlarmSetting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('alarm_hour', _hour);
    await prefs.setInt('alarm_minute', _minute);

    {
      await NotificationService().scheduleDailyReminder(_hour, _minute);

      await NotificationService().checkPendingNotifications();
    }
  }

  Future<void> _toggleNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_notification_enabled', value);

    if (!value) {
      await NotificationService().cancelAllNotifications();
    }

    setState(() {
      _isNotificationEnabled = value;
    });
  }

  Future<void> _toggleMonthlyNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_monthly_enabled', value);

    if (value) {
      await NotificationService().scheduleMonthlyReminder(1, 9, 0);
    } else {
      await NotificationService().cancelMonthlyNotification();
    }

    setState(() {
      _isMonthlyEnabled = value;
    });
  }

  Future<void> _toggleFixedExpenseNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_fixed_expense_enabled', value);

    if (value) {
      // Firestore에서 고정지출 목록 읽어서 알림 예약
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('recurring_expenses')
            .get();

        final items = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();

        await NotificationService().scheduleFixedExpenseReminders(items);
      }
    } else {
      // 고정지출 알림 전체 취소
      for (int i = 100; i < 300; i++) {
        await NotificationService().cancelById(i);
      }
    }

    setState(() {
      _isFixedExpenseEnabled = value;
    });
  }

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
          "알림 설정",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: ListView(
          children: [
            SwitchListTile.adaptive(
              title: const Text(
                "알림 설정",
                style: TextStyle(fontSize: 15),
              ),
              value: _isNotificationEnabled,
              onChanged: _toggleNotification,
              activeColor: AppColors.primary(context),
            ),
            ListTile(
              title: const Text(
                "리마인더 시간 설정",
                style: TextStyle(fontSize: 15),
              ),
              subtitle: const Text(
                "매일 설정하신 시간에 지출 관리 알림을 드립니다.",
                style: TextStyle(
                  fontSize: 12,
                  height: 1,
                  color: AppColors.secondary,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.secondary,
                  ),
                ],
              ),

              onTap: _handleAlarmTimeSetting,
            ),
            SwitchListTile.adaptive(
              title: const Text(
                "월간 예산 설정 알림",
                style: TextStyle(fontSize: 15),
              ),
              subtitle: const Text(
                "매월 1일 예산 설정을 위한 알림을 받습니다.",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondary,
                ),
              ),
              value: _isMonthlyEnabled,
              onChanged: _toggleMonthlyNotification,
              activeColor: AppColors.primary(context),
            ),
            SwitchListTile.adaptive(
              title: const Text(
                "고정지출 당일 알림",
                style: TextStyle(fontSize: 15),
              ),
              subtitle: const Text(
                "고정지출 설정한 날 오전 9시에 알림을 받습니다.",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondary,
                ),
              ),
              value: _isFixedExpenseEnabled,
              onChanged: _toggleFixedExpenseNotification,
              activeColor: AppColors.primary(context),
            ),
          ],
        ),
      ),
    );
  }
}
