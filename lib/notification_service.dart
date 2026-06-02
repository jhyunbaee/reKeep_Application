import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
  }

  Future<void> requestPermission() async {
    await _notificationsPlugin.resolvePlatformSpecificImplementation;
    IOSFlutterLocalNotificationsPlugin()?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> showNotification(int id, String title, String body) async {
    await _notificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_id',
          'test_name',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> scheduleDailyReminder(int hour, int minute) async {
    await _notificationsPlugin.cancel(0);

    await _notificationsPlugin.zonedSchedule(
      0,
      "reKeep",
      "오늘의 지출을 확인하고 리킵을 관리해보세요!",
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_id',
          'daily_name',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> scheduleMonthlyReminder(
    int dayOfMonth,
    int hour,
    int minute,
  ) async {
    await _notificationsPlugin.cancel(1);

    await _notificationsPlugin.zonedSchedule(
      1,
      "reKeep",
      "이번 달의 예산을 설정 해보세요!",
      _nextInstanceOfMonthly(dayOfMonth, hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails('monthly_id', 'monthly_name'),
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  tz.TZDateTime _nextInstanceOfMonthly(int day, int hour, int minute) {
    final location = tz.getLocation('Asia/Seoul');
    final tz.TZDateTime now = tz.TZDateTime.now(location);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      location,
      now.year,
      now.month,
      day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(
        location,
        now.year,
        now.month + 1,
        day,
        hour,
        minute,
      );
    }
    return scheduledDate;
  }

  Future<List<PendingNotificationRequest>> checkPendingNotifications() async {
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    for (final p in pending) {
      print('예약된 알림 id=${p.id}, title=${p.title}, body=${p.body}');
    }
    print('총 예약 개수: ${pending.length}');
    return pending;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final location = tz.getLocation('Asia/Seoul');
    final tz.TZDateTime now = tz.TZDateTime.now(location);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  void cancelTodayReminder() async {
    await _notificationsPlugin.cancel(0);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> cancelMonthlyNotification() async {
    await _notificationsPlugin.cancel(1); // id 1번 취소
  }

  Future<void> scheduleFixedExpenseReminders(
    List<Map<String, dynamic>> items,
  ) async {
    for (int i = 100; i < 300; i++) {
      await _notificationsPlugin.cancel(i);
    }

    final location = tz.getLocation('Asia/Seoul');
    final now = tz.TZDateTime.now(location);

    const weekdayMap = {
      '월요일': 1,
      '화요일': 2,
      '수요일': 3,
      '목요일': 4,
      '금요일': 5,
      '토요일': 6,
      '일요일': 7,
    };

    int notifId = 100;

    for (final item in items) {
      if (notifId >= 300) break;

      final String name = item['name'] ?? '';
      final int amount = (item['amount'] ?? 0) as int;
      final String period = (item['period'] ?? '매월').toString();
      final String dayData = (item['day'] ?? '1일').toString();

      if (name.isEmpty || amount == 0) continue;

      final String amountStr = "${NumberFormat('#,###').format(amount)}원";
      final String body = "오늘 $name $amountStr 지출 예정입니다.";

      if (period == '매월') {
        final int day =
            int.tryParse(dayData.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        tz.TZDateTime scheduled = tz.TZDateTime(
          location,
          now.year,
          now.month,
          day,
          8,
          0,
        );
        if (scheduled.isBefore(now)) {
          scheduled = tz.TZDateTime(
            location,
            now.year,
            now.month + 1,
            day,
            8,
            0,
          );
        }
        await _notificationsPlugin.zonedSchedule(
          notifId++,
          "reKeep",
          body,
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'fixed_expense_id',
              'fixed_expense_name',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } else if (period == '매주') {
        final int? targetWeekday = weekdayMap[dayData];
        if (targetWeekday == null) continue;
        int daysUntil = (targetWeekday - now.weekday + 7) % 7;
        tz.TZDateTime scheduled = tz.TZDateTime(
          location,
          now.year,
          now.month,
          now.day + daysUntil,
          8,
          0,
        );
        if (scheduled.isBefore(now)) {
          scheduled = scheduled.add(const Duration(days: 7));
        }
        await _notificationsPlugin.zonedSchedule(
          notifId++,
          "reKeep",
          body,
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'fixed_expense_id',
              'fixed_expense_name',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } else if (period == '매일') {
        tz.TZDateTime scheduled = tz.TZDateTime(
          location,
          now.year,
          now.month,
          now.day,
          8,
          0,
        );
        if (scheduled.isBefore(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
        await _notificationsPlugin.zonedSchedule(
          notifId++,
          "reKeep",
          body,
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'fixed_expense_id',
              'fixed_expense_name',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }
  }

  Future<void> cancelById(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}
