import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'ot_daily_reminder';
  static const _channelName = 'OT দৈনিক রিমাইন্ডার';
  static const _channelDesc = 'প্রতিদিন OT এন্ট্রির জন্য রিমাইন্ডার';
  static const _notifId     = 1001;

  // ─────────────────────────────────────────────
  // INIT — main.dart থেকে একবার call করুন
  // ─────────────────────────────────────────────
  static Future<void> init() async {
    // Timezone init
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // notification tap এ কিছু করতে চাইলে এখানে
      },
    );

    // Android notification channel তৈরি করুন
    await _createNotificationChannel();

    // Android 13+ permission request
    await _requestPermissions();
  }

  // ─────────────────────────────────────────────
  // Notification Channel তৈরি
  // ─────────────────────────────────────────────
  static Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ─────────────────────────────────────────────
  // Permission Request (Android 13+)
  // ─────────────────────────────────────────────
  static Future<void> _requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  // ─────────────────────────────────────────────
  // দৈনিক রিমাইন্ডার সেট করুন
  // ─────────────────────────────────────────────
  static Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    try {
      // আগের notification বাতিল করুন
      await _plugin.cancel(_notifId);

      // Dhaka timezone এ time তৈরি করুন
      final now       = tz.TZDateTime.now(tz.local);
      var   scheduled = tz.TZDateTime(
        tz.local,
        now.year, now.month, now.day,
        hour, minute, 0,
      );

      // যদি আজকের সময় পার হয়ে গেছে — কালকে set করুন
      if (scheduled.isBefore(now.add(const Duration(seconds: 5)))) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance:         Importance.max,
        priority:           Priority.high,
        playSound:          true,
        enableVibration:    true,
        fullScreenIntent:   false,
        styleInformation:   BigTextStyleInformation(''),
      );

      const notifDetails = NotificationDetails(android: androidDetails);

      await _plugin.zonedSchedule(
        _notifId,
        title,
        body,
        scheduled,
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_reminder',
      );

      // সেভ করুন SharedPreferences এ
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('reminder_on', true);
      await prefs.setInt('reminder_hour', hour);
      await prefs.setInt('reminder_minute', minute);

      return true;
    } catch (e) {
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // রিমাইন্ডার বাতিল করুন
  // ─────────────────────────────────────────────
  static Future<void> cancelReminder() async {
    await _plugin.cancel(_notifId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_on', false);
    await prefs.remove('reminder_hour');
    await prefs.remove('reminder_minute');
  }

  // ─────────────────────────────────────────────
  // App restart এ reminder পুনরায় set করুন
  // ─────────────────────────────────────────────
  static Future<void> rescheduleOnBoot() async {
    final prefs = await SharedPreferences.getInstance();
    final on    = prefs.getBool('reminder_on') ?? false;
    if (!on) return;

    final hour   = prefs.getInt('reminder_hour');
    final minute = prefs.getInt('reminder_minute');
    if (hour == null || minute == null) return;

    await scheduleDailyReminder(
      hour:   hour,
      minute: minute,
      title:  'OT Diary রিমাইন্ডার',
      body:   'আজকের OT ঘন্টা এন্ট্রি করুন!',
    );
  }

  // ─────────────────────────────────────────────
  // Reminder চালু আছে কিনা চেক করুন
  // ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> getReminderStatus() async {
    final prefs  = await SharedPreferences.getInstance();
    final on     = prefs.getBool('reminder_on') ?? false;
    final hour   = prefs.getInt('reminder_hour') ?? 21;
    final minute = prefs.getInt('reminder_minute') ?? 0;
    return {'on': on, 'hour': hour, 'minute': minute};
  }

  // ─────────────────────────────────────────────
  // Test notification — এখনই দেখান (testing এর জন্য)
  // ─────────────────────────────────────────────
  static Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance:      Importance.max,
      priority:        Priority.high,
      playSound:       true,
      enableVibration: true,
    );
    await _plugin.show(
      9999,
      'OT Diary Test',
      'Notification কাজ করছে! ✅',
      const NotificationDetails(android: androidDetails),
    );
  }
}
