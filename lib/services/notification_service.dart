import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _chId   = 'ot_daily_reminder';
  static const _chName = 'OT দৈনিক রিমাইন্ডার';
  static const _chDesc = 'প্রতিদিন OT এন্ট্রির জন্য রিমাইন্ডার';
  static const _id     = 1001;

  // ══════════════════════════════════════
  // INIT
  // ══════════════════════════════════════
  static Future<void> init() async {
    tz.initializeTimeZones();
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
            _chId, _chName,
            description:     _chDesc,
            importance:      Importance.max,
            playSound:       true,
            enableVibration: true,
            showBadge:       true,
          ),
        );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  // ══════════════════════════════════════
  // দৈনিক রিমাইন্ডার
  // ══════════════════════════════════════
  static Future<String> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.cancel(_id);

      final location = tz.getLocation('Asia/Dhaka');
      final now      = tz.TZDateTime.now(location);
      var   sched    = tz.TZDateTime(
          location, now.year, now.month, now.day, hour, minute, 0);

      if (sched.isBefore(now.add(const Duration(seconds: 10)))) {
        sched = sched.add(const Duration(days: 1));
      }

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _chId, _chName,
          channelDescription: _chDesc,
          importance:         Importance.max,
          priority:           Priority.high,
          playSound:          true,
          enableVibration:    true,
        ),
      );

      // Android 11 — inexact সরাসরি ব্যবহার করুন
      await _plugin.zonedSchedule(
        _id, title, body, sched, details,
        androidScheduleMode:
            AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_on', true);
      await prefs.setInt('notif_h',   hour);
      await prefs.setInt('notif_m',   minute);
      return 'ok:inexact';
    } catch (e) {
      return 'error: $e';
    }
  }

  // ══════════════════════════════════════
  // বাতিল
  // ══════════════════════════════════════
  static Future<void> cancelReminder() async {
    await _plugin.cancel(_id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_on', false);
    await prefs.remove('notif_h');
    await prefs.remove('notif_m');
  }

  // ══════════════════════════════════════
  // Reboot এ reschedule
  // ══════════════════════════════════════
  static Future<void> rescheduleOnBoot() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notif_on') ?? false)) return;
    final h = prefs.getInt('notif_h');
    final m = prefs.getInt('notif_m');
    if (h == null || m == null) return;
    await scheduleDailyReminder(
      hour:  h,
      minute: m,
      title: 'OT Diary রিমাইন্ডার ⚡',
      body:  'আজকের OT ঘন্টা এন্ট্রি করুন!',
    );
  }

  // ══════════════════════════════════════
  // Status
  // ══════════════════════════════════════
  static Future<Map<String, dynamic>> getReminderStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'on':     prefs.getBool('notif_on') ?? false,
      'hour':   prefs.getInt('notif_h')   ?? 21,
      'minute': prefs.getInt('notif_m')   ?? 0,
    };
  }

  // ══════════════════════════════════════
  // তাৎক্ষণিক Test
  // ══════════════════════════════════════
  static Future<void> showTestNotification() async {
    await _plugin.show(
      9999,
      'OT Diary Test ⚡',
      'Notification কাজ করছে! ✅',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _chId, _chName,
          importance:      Importance.max,
          priority:        Priority.high,
          playSound:       true,
          enableVibration: true,
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // ২ মিনিট পরে scheduled test
  // ══════════════════════════════════════
  static Future<String> scheduleTestIn2Minutes() async {
    try {
      final location = tz.getLocation('Asia/Dhaka');
      final sched    = tz.TZDateTime.now(location)
          .add(const Duration(minutes: 2));

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _chId, _chName,
          importance:      Importance.max,
          priority:        Priority.high,
          playSound:       true,
          enableVibration: true,
        ),
      );

      // Android 11 — inexact সরাসরি ব্যবহার করুন
      await _plugin.zonedSchedule(
        8888,
        'Scheduled Test ✅',
        '২ মিনিট আগে সেট করা! Scheduled notification কাজ করছে।',
        sched,
        details,
        androidScheduleMode:
            AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      return 'ok:inexact';
    } catch (e) {
      return 'error: $e';
    }
  }
}
