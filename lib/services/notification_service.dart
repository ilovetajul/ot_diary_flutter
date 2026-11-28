import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'ot_daily_reminder';
  static const String _channelName = 'OT দৈনিক রিমাইন্ডার';
  static const String _channelDescription =
      'প্রতিদিনের OT লিখে রাখার জন্য রিমাইন্ডার';
  static const int _reminderId = 1001;

  static Future<void> init() async {
    timezone_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
  }

  static Future<String> scheduleDailyReminder({
    required int hour,
    required int minute,
    String title = 'আজকের OT লিখেছেন?',
    String body =
        'আজ কত ঘণ্টা OT করেছেন? OT Diary খুলে আজকের হিসাব লিখে রাখুন।',
  }) async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      final permissionGranted =
          await android?.requestNotificationsPermission();
      if (permissionGranted == false) {
        return 'error: notification permission denied';
      }
      await _plugin.cancel(_reminderId);

      final location = tz.getLocation('Asia/Dhaka');
      final now = tz.TZDateTime.now(location);
      var scheduled = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // Inexact scheduling does not require Exact Alarm permission.
      await _plugin.zonedSchedule(
        _reminderId,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_on', true);
      await prefs.setInt('notif_h', hour);
      await prefs.setInt('notif_m', minute);
      return 'ok';
    } catch (error) {
      return 'error: $error';
    }
  }

  static Future<void> cancelReminder() async {
    await _plugin.cancel(_reminderId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_on', false);
    await prefs.remove('notif_h');
    await prefs.remove('notif_m');
  }

  static Future<void> rescheduleOnBoot() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notif_on') ?? false)) return;

    final hour = prefs.getInt('notif_h');
    final minute = prefs.getInt('notif_m');
    if (hour == null || minute == null) return;

    await scheduleDailyReminder(
      hour: hour,
      minute: minute,
    );
  }

  static Future<Map<String, dynamic>> getReminderStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return <String, dynamic>{
      'on': prefs.getBool('notif_on') ?? false,
      'hour': prefs.getInt('notif_h') ?? 21,
      'minute': prefs.getInt('notif_m') ?? 0,
    };
  }

  static Future<String> showTestNotification() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final permissionGranted = await android?.requestNotificationsPermission();
      if (permissionGranted == false) return 'error: notification permission denied';
      await _plugin.show(
        9999,
        'OT Diary পরীক্ষা',
        'নোটিফিকেশন ঠিকভাবে কাজ করছে।',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      return 'ok';
    } catch (error) {
      return 'error: $error';
    }
  }

  static Future<String> scheduleTestNotificationAfterTwoMinutes() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final permissionGranted = await android?.requestNotificationsPermission();
      if (permissionGranted == false) return 'error: notification permission denied';
      final location = tz.getLocation('Asia/Dhaka');
      final scheduled = tz.TZDateTime.now(location).add(const Duration(minutes: 2));
      await _plugin.cancel(9998);
      await _plugin.zonedSchedule(
        9998,
        'OT Diary — Scheduled Test',
        'দুই মিনিট আগে নির্ধারিত পরীক্ষামূলক নোটিফিকেশন।',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return 'ok';
    } catch (error) {
      return 'error: $error';
    }
  }
}

