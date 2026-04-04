import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (details) {},
    );
    // Request permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Daily reminder at specified time
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await _plugin.zonedSchedule(
      1,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ot_reminder',
          'OT রিমাইন্ডার',
          channelDescription: 'প্রতিদিনের OT এন্ট্রি রিমাইন্ডার',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF00E5C0),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Month end salary notification
  static Future<void> showSalaryNotification({
    required double total,
    required double otHours,
  }) async {
    await _plugin.show(
      2,
      '💰 মাসের বেতন হিসাব',
      'মোট OT: ${otHours}ঘন্টা | মোট বেতন: ৳${total.toStringAsFixed(0)}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ot_salary',
          'বেতন নোটিফিকেশন',
          channelDescription: 'মাসিক বেতন হিসাব',
          importance: Importance.defaultImportance,
        ),
      ),
    );
  }

  static Future<void> cancelReminder() async {
    await _plugin.cancel(1);
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

// ignore: avoid_classes_with_only_static_members
class Color {
  const Color(int value);
}
