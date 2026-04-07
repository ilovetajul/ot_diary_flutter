import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_profile.dart';

class DatabaseService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseDatabase.instance;

  static String get uid => _auth.currentUser?.uid ?? '';
  static bool get isLoggedIn => _auth.currentUser != null;
  static String _monthKey(int y, int m) => '${y}_${m.toString().padLeft(2, '0')}';

  // ===== PROFILE =====
  static Future<void> saveProfile(UserProfile p) async {
    await _db.ref('users/$uid/profile').set(p.toMap());
    // Also cache locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile', jsonEncode(p.toMap()));
  }

  static Future<UserProfile?> getProfile() async {
    // Try local cache first
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('profile');

    try {
      final snap = await _db.ref('users/$uid/profile').get();
      if (snap.exists) {
        final profile = UserProfile.fromMap(snap.value as Map);
        await prefs.setString('profile', jsonEncode(profile.toMap()));
        return profile;
      }
    } catch (_) {
      // Offline: use cache
      if (cached != null) return UserProfile.fromMap(jsonDecode(cached));
    }
    if (cached != null) return UserProfile.fromMap(jsonDecode(cached));
    return null;
  }

  // ===== OT DATA =====
  static Future<Map<int, double>> getMonthData(int year, int month) async {
    if (!isLoggedIn) return {};
  final key = _monthKey(year, month);
  final prefs = await SharedPreferences.getInstance();
  final localKey = 'ot_${uid}_$key';
    
    try {
      final snap = await _db.ref('users/$uid/ot/$key').get();
      final Map<int, double> data = {};
      if (snap.exists) {
        final raw = snap.value as Map;
        raw.forEach((k, v) => data[int.parse(k.toString())] = (v as num).toDouble());
      }
      // Save locally
      await prefs.setString(localKey, jsonEncode(data.map((k, v) => MapEntry(k.toString(), v))));
      return data;
    } catch (_) {
      // Offline fallback
      final cached = prefs.getString(localKey);
      if (cached != null) {
        final Map decoded = jsonDecode(cached);
        return decoded.map((k, v) => MapEntry(int.parse(k), (v as num).toDouble()));
      }
      return {};
    }
  }

  static Stream<Map<int, double>> streamMonthData(int year, int month) {
    final key = _monthKey(year, month);
    return _db.ref('users/$uid/ot/$key').onValue.map((event) {
      final Map<int, double> data = {};
      if (event.snapshot.exists) {
        final raw = event.snapshot.value as Map;
        raw.forEach((k, v) => data[int.parse(k.toString())] = (v as num).toDouble());
      }
      return data;
    });
  }

  static Future<void> saveOTDay(int year, int month, int day, double hours) async {
    if (!isLoggedIn) return;
    final key = _monthKey(year, month);
    if (hours == 0) {
      await _db.ref('users/$uid/ot/$key/$day').remove();
    } else {
      await _db.ref('users/$uid/ot/$key/$day').set(hours);
    }
    // Update local cache
    final prefs = await SharedPreferences.getInstance();
    final localKey = 'ot_${uid}_$key';
    final cached = prefs.getString(localKey);
    Map<String, dynamic> local = cached != null ? jsonDecode(cached) : {};
    if (hours == 0) local.remove(day.toString()); else local[day.toString()] = hours;
    await prefs.setString(localKey, jsonEncode(local));
  }

  static Future<void> resetMonth(int year, int month) async {
    final key = _monthKey(year, month);
    await _db.ref('users/$uid/ot/$key').remove();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ot_${uid}_$key');
  }

  // ===== BACKUP =====
  static Future<Map<String, dynamic>> exportAllData() async {
    final snap = await _db.ref('users/$uid').get();
    return {
      'profile': (await getProfile())?.toMap(),
      'ot': snap.exists ? (snap.value as Map)['ot'] : {},
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  static Future<void> importData(Map<String, dynamic> data) async {
    if (data['ot'] != null) {
      await _db.ref('users/$uid/ot').set(data['ot']);
    }
  }
}
