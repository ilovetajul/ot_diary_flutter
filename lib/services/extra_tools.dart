import 'dart:convert';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import 'database_service.dart';

class ExtraTools {
  static const _channel = MethodChannel('com.otdiary.app/tools');
  static String get account => FirebaseAuth.instance.currentUser!.uid;
  static String monthKey(int year, int month) => '${year}_${month.toString().padLeft(2, '0')}';
  static String dateKey(int year, int month, int day) => '${monthKey(year, month)}_${day.toString().padLeft(2, '0')}';
  static bool validHours(double? value) => value != null && value.isFinite && value >= 0 && value <= 24;
  static bool validMonth(String key) => RegExp(r'^(19\d{2}|20\d{2}|21\d{2})_(0[1-9]|1[0-2])$').hasMatch(key);
  static int daysIn(String key) {
    final p = key.split('_');
    return DateTime(int.parse(p[0]), int.parse(p[1]) + 1, 0).day;
  }
  static Map<String, double> decodeDays(Object? raw, String month) {
    final result = <String, double>{};
    if (!validMonth(month)) return result;
    void add(Object? k, Object? v) {
      final day = int.tryParse('$k');
      final hours = double.tryParse('$v');
      if (day != null && day >= 1 && day <= daysIn(month) && hours != null && validHours(hours) && hours > 0) {
        result['$day'] = hours;
      }
    }
    if (raw is Map) raw.forEach(add);
    if (raw is List) {
      for (var i = 0; i < raw.length; i++) { add(i, raw[i]); }
    }
    return result;
  }
  static Future<double> target(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('ot_target_${account}_${monthKey(year, month)}') ?? 120;
  }
  static Future<void> setTarget(int year, int month, double hours) async {
    if (!hours.isFinite || hours <= 0 || hours > 744) throw ArgumentError('Invalid target');
    final uid = account;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ot_target_${uid}_${monthKey(year, month)}', hours);
  }
  static Future<Set<String>> holidays() async {
    final uid = account;
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('ot_holidays_$uid') ?? []).toSet();
  }
  static Future<void> toggleHoliday(int year, int month, int day) async {
    final uid = account;
    final prefs = await SharedPreferences.getInstance();
    final values = (prefs.getStringList('ot_holidays_$uid') ?? []).toSet();
    final key = dateKey(year, month, day);
    if (!values.add(key)) values.remove(key);
    await prefs.setStringList('ot_holidays_$uid', values.toList());
  }
  static Future<bool> publishWidget(int year, int month, Map<int, double> data) async {
    final now = DateTime.now();
    if (year != now.year || month != now.month) return false;
    try {
      await _channel.invokeMethod<void>('updateWidget', {
        'month': '$year-${month.toString().padLeft(2, '0')}',
        'hours': data.values.fold<double>(0, (sum, v) => sum + v).toStringAsFixed(1),
        'days': data.values.where((v) => v > 0).length.toString(),
      });
      return true;
    } on PlatformException { return false; }
      on MissingPluginException { return false; }
  }
  static Future<void> clearWidget() async {
    try { await _channel.invokeMethod<void>('clearWidget'); }
    on PlatformException { /* Best effort. */ }
    on MissingPluginException { /* Non-Android platform. */ }
  }
  static Future<bool> saveFile(String name, String mime, String data) async =>
      await _channel.invokeMethod<bool>('saveFile', {'name': name, 'mime': mime, 'data': data}) ?? false;
  static Future<String?> pickBackup() => _channel.invokeMethod<String>('pickBackup');

  // Full online snapshot when the server is reachable; otherwise explicitly partial.
  // Apply durable local pending operations, including deletes, over that snapshot.
  static Future<Map<String, dynamic>> snapshot() async {
    final uid = account;
    final prefs = await SharedPreferences.getInstance();
    final ot = <String, Map<String, double>>{};
    Map<String, dynamic>? profile;
    var complete = false;
    if (DatabaseService.isOnline) {
      try {
        final value = await FirebaseDatabase.instance.ref('users/$uid').get().timeout(const Duration(seconds: 8));
        final raw = value.value;
        if (raw is Map) {
          final months = raw['ot'];
          if (months is Map) {
            for (final entry in months.entries) {
              final key = '${entry.key}';
              if (validMonth(key)) ot[key] = decodeDays(entry.value, key);
            }
          }
          if (raw['profile'] is Map) profile = Map<String, dynamic>.from(raw['profile'] as Map);
        }
        complete = true;
      } catch (_) { /* Offline fallback below. */ }
    }
    if (account != uid) throw StateError('Account changed');
    final prefix = 'ot_${uid}_';
    if (!complete) {
      for (final k in prefs.getKeys().where((k) => k.startsWith(prefix))) {
        final month = k.substring(prefix.length);
        if (validMonth(month)) {
          final value = prefs.getString(k);
          if (value != null) ot[month] = decodeDays(jsonDecode(value), month);
        }
      }
      final cached = prefs.getString('profile_$uid');
      if (cached != null) profile = Map<String, dynamic>.from(jsonDecode(cached) as Map);
    }
    final rawQueue = prefs.getString('ot_pending_sync_$uid');
    if (rawQueue != null) {
      final queue = jsonDecode(rawQueue) as Map;
      final pathPrefix = 'users/$uid/ot/';
      for (final entry in queue.entries) {
        final path = '${entry.key}';
        if (entry.value is! Map) continue;
        final item = entry.value as Map;
        if (path == 'users/$uid/profile' && item['operation'] == 'update' && item['value'] is Map) {
          profile = {...?profile, ...Map<String, dynamic>.from(item['value'] as Map)};
        }
        if (!path.startsWith(pathPrefix)) continue;
        final parts = path.substring(pathPrefix.length).split('/');
        if (!validMonth(parts[0])) continue;
        if (parts.length == 1 && item['operation'] == 'remove') ot.remove(parts[0]);
        if (parts.length == 2) {
          final month = ot.putIfAbsent(parts[0], () => <String, double>{});
          if (item['operation'] == 'remove') { month.remove(parts[1]); }
          else { month.addAll(decodeDays({parts[1]: item['value']}, parts[0])); }
        }
      }
    }
    final targets = <String, double>{};
    final targetPrefix = 'ot_target_${uid}_';
    for (final k in prefs.getKeys().where((k) => k.startsWith(targetPrefix))) {
      final month = k.substring(targetPrefix.length);
      final value = prefs.getDouble(k);
      if (validMonth(month) && value != null && value.isFinite && value > 0 && value <= 744) targets[month] = value;
    }
    return {'format': 'ot-diary-backup-v1', 'uid': uid, 'complete': complete,
      'createdAt': DateTime.now().toIso8601String(), 'profile': profile, 'ot': ot,
      'targets': targets, 'holidays': prefs.getStringList('ot_holidays_$uid') ?? <String>[]};
  }
  static Map<String, Map<String, double>> validatedBackup(Map<String, dynamic> backup, String uid) {
    if (backup['format'] != 'ot-diary-backup-v1' || backup['uid'] != uid || backup['ot'] is! Map) {
      throw const FormatException('Invalid backup or different account');
    }
    final result = <String, Map<String, double>>{};
    final months = backup['ot'] as Map;
    if (months.length > 2412) throw const FormatException('Too many months');
    for (final entry in months.entries) {
      if (entry.key is! String || !validMonth(entry.key as String) || entry.value is! Map) throw const FormatException('Invalid month');
      final days = entry.value as Map;
      final valid = decodeDays(days, entry.key as String);
      if (valid.length != days.length) throw const FormatException('Invalid day or hours');
      result[entry.key as String] = valid;
    }
    return result;
  }
  // Online-only, non-destructive restore: server transactions fill absent days.
  // Profile and avatar remain unchanged; profile metadata in backup is informational.
  static Future<int> restoreMissing(Map<String, dynamic> backup) async {
    final uid = account;
    final data = validatedBackup(backup, uid);
    if (!DatabaseService.isOnline || await DatabaseService.hasPendingChanges()) {
      throw StateError('Connect to the internet and sync pending changes first');
    }
    var restored = 0;
    for (final month in data.entries) {
      for (final day in month.value.entries) {
        if (account != uid || !DatabaseService.isOnline) throw StateError('Connection or account changed; safe to retry');
        final result = await FirebaseDatabase.instance.ref('users/$uid/ot/${month.key}/${day.key}').runTransaction((current) {
          if (current != null) return Transaction.abort();
          return Transaction.success(day.value);
        }, applyLocally: false).timeout(const Duration(seconds: 15));
        if (result.committed) restored++;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    if (account != uid) throw StateError('Account changed');
    final targets = backup['targets'];
    if (targets is Map) {
      for (final e in targets.entries) {
        final month = '${e.key}';
        final hours = double.tryParse('${e.value}');
        final key = 'ot_target_${uid}_$month';
        if (validMonth(month) && hours != null && hours.isFinite && hours > 0 && hours <= 744 && !prefs.containsKey(key)) {
          await prefs.setDouble(key, hours);
        }
      }
    }
    final holidays = backup['holidays'];
    if (holidays is List) {
      final values = (prefs.getStringList('ot_holidays_$uid') ?? []).toSet();
      for (final item in holidays.whereType<String>()) {
        if (RegExp(r'^\d{4}_\d{2}_\d{2}$').hasMatch(item)) {
          final month = item.substring(0, 7);
          final day = int.parse(item.substring(8));
          if (validMonth(month) && day > 0 && day <= daysIn(month)) values.add(item);
        }
      }
      await prefs.setStringList('ot_holidays_$uid', values.toList());
    }
    return restored;
  }
  static String csv(int year, int month, Map<int, double> data, double rate) {
    final b = StringBuffer('\uFEFFDate,OT Hours,Estimated OT BDT\r\n');
    final key = monthKey(year, month).replaceAll('_', '-');
    final days = DateTime(year, month + 1, 0).day;
    for (var d = 1; d <= days; d++) {
      final h = data[d] ?? 0;
      b.write('$key-${d.toString().padLeft(2, '0')},${h.toStringAsFixed(2)},${(h * rate).toStringAsFixed(2)}\r\n');
    }
    return b.toString();
  }
  // Flutter's text engine shapes Bengali text. Render each page into PNG before
  // embedding in PDF (offline, no remote fonts; text is not searchable).
  static Future<void> bengaliPdf(int year, int month, Map<int, double> data, UserProfile profile) async {
    final doc = pw.Document();
    final total = data.values.fold<double>(0, (s, h) => s + h);
    final days = DateTime(year, month + 1, 0).day;
    const width = 1190;
    const height = 1684;
    for (var start = 1; start <= days; start += 16) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1190, 1684), Paint()..color = Colors.white);
      void text(String value, double x, double y, double size, {bool bold = false, double maxWidth = 1060, Color color = const Color(0xFF142C36)}) {
        final painter = TextPainter(text: TextSpan(text: value, style: TextStyle(fontFamily: 'HindSiliguri', fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: color)), textDirection: TextDirection.ltr, maxLines: 2, ellipsis: '…');
        painter.layout(maxWidth: maxWidth);
        painter.paint(canvas, Offset(x, y));
        painter.dispose();
      }
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1190, 200), Paint()..color = const Color(0xFF103E43));
      text('OT DIARY  |  মাসিক ওভারটাইম রিপোর্ট', 64, 48, 44, bold: true, color: Colors.white);
      text('$year-${month.toString().padLeft(2, '0')}', 64, 115, 32, color: Colors.white);
      text('নাম: ${profile.name}   |   আইডি: ${profile.idNo}', 64, 225, 32, bold: true);
      text('মোট OT: ${total.toStringAsFixed(2)} ঘণ্টা   |   দিন: ${data.length}', 64, 315, 32);
      text('আনুমানিক OT আয়: ৳${(total * profile.rate).toStringAsFixed(2)}', 64, 370, 32);
      text('মোট বেতন: ৳${(profile.basic + profile.allowance + total * profile.rate).toStringAsFixed(2)}', 64, 425, 32);
      canvas.drawRect(const Rect.fromLTWH(64, 510, 1062, 58), Paint()..color = const Color(0xFFE0F3EE));
      text('তারিখ', 90, 518, 30, bold: true); text('OT ঘণ্টা', 450, 518, 30, bold: true); text('OT আয় (৳)', 800, 518, 30, bold: true);
      for (var d = start; d <= days && d < start + 16; d++) {
        final y = 572.0 + (d - start) * 59;
        if (d.isEven) canvas.drawRect(Rect.fromLTWH(64, y, 1062, 59), Paint()..color = const Color(0xFFF4F7F8));
        final h = data[d] ?? 0;
        text('$d', 90, y + 8, 29); text(h.toStringAsFixed(2), 450, y + 8, 29); text((h * profile.rate).toStringAsFixed(2), 800, y + 8, 29);
      }
      text('বর্তমান OT রেট অনুযায়ী আনুমানিক হিসাব  |  পৃষ্ঠা ${(start - 1) ~/ 16 + 1}', 64, 1570, 25);
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose(); picture.dispose();
      if (bytes == null) throw StateError('Unable to render PDF');
      final page = pw.MemoryImage(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero, build: (_) => pw.Center(child: pw.Image(page, fit: pw.BoxFit.contain))));
    }
    await Printing.sharePdf(bytes: await doc.save(), filename: 'OT_BN_${monthKey(year, month)}.pdf');
  }
}
