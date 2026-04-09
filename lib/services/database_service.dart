import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_profile.dart';

class DatabaseService {
  static final _auth = FirebaseAuth.instance;
  static final _db   = FirebaseDatabase.instance;

  static String get uid => _auth.currentUser!.uid;
  static bool get isLoggedIn => _auth.currentUser != null;
  static String _monthKey(int y, int m) => '${y}_${m.toString().padLeft(2, '0')}';
  static String _cacheKey(String k) => 'ot_${uid}_$k';
  static String _profileKey() => 'profile_$uid';

  static Future<void> saveProfile(UserProfile p) async {
    await _db.ref('users/$uid/profile').set(p.toMap());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey(), jsonEncode(p.toMap()));
  }

  static Future<UserProfile?> getProfile() async {
    if (!isLoggedIn) return null;
    try {
      final snap = await _db.ref('users/$uid/profile').get();
      if (snap.exists) {
        final p = UserProfile.fromMap(snap.value as Map);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_profileKey(), jsonEncode(p.toMap()));
        return p;
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final c = prefs.getString(_profileKey());
      if (c != null) return UserProfile.fromMap(jsonDecode(c));
    }
    return null;
  }

  static Future<Map<int, double>> getMonthData(int year, int month) async {
    if (!isLoggedIn) return {};
    final key = _monthKey(year, month);
    try {
      final snap = await _db.ref('users/$uid/ot/$key').get();
      final Map<int, double> data = {};
      if (snap.exists && snap.value != null) {
        final raw = Map<String, dynamic>.from(snap.value as Map);
        raw.forEach((k, v) {
          final d = int.tryParse(k);
          if (d != null) data[d] = (v as num).toDouble();
        });
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(key),
          jsonEncode(data.map((k, v) => MapEntry(k.toString(), v))));
      return data;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final c = prefs.getString(_cacheKey(key));
      if (c != null) {
        final Map dec = jsonDecode(c);
        return dec.map((k, v) => MapEntry(int.parse(k), (v as num).toDouble()));
      }
      return {};
    }
  }

  static Future<void> saveOTDay(int year, int month, int day, double hours) async {
    if (!isLoggedIn) return;
    final key  = _monthKey(year, month);
    final path = 'users/$uid/ot/$key/$day';
    if (hours <= 0) {
      await _db.ref(path).remove();
    } else {
      await _db.ref(path).set(hours);
    }
    final prefs = await SharedPreferences.getInstance();
    final c = prefs.getString(_cacheKey(key));
    Map<String, dynamic> local = c != null ? Map.from(jsonDecode(c)) : {};
    if (hours <= 0) local.remove(day.toString()); else local[day.toString()] = hours;
    await prefs.setString(_cacheKey(key), jsonEncode(local));
  }

  static Future<void> resetMonth(int year, int month) async {
    if (!isLoggedIn) return;
    final key = _monthKey(year, month);
    await _db.ref('users/$uid/ot/$key').remove();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey(key));
  }

  static Future<void> onLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_session');
  }

  static Future<Map<String, dynamic>> exportAllData() async {
    if (!isLoggedIn) return {};
    final snap = await _db.ref('users/$uid').get();
    return {
      'profile': (await getProfile())?.toMap(),
      'ot': snap.exists ? (Map<String, dynamic>.from(snap.value as Map))['ot'] ?? {} : {},
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  static Future<void> importData(Map<String, dynamic> data) async {
    if (!isLoggedIn) return;
    if (data['ot'] != null) await _db.ref('users/$uid/ot').set(data['ot']);
  }

  static Stream<Map<int, double>> streamMonthData(int year, int month) {
    if (!isLoggedIn) return Stream.value({});
    final key = _monthKey(year, month);
    return _db.ref('users/$uid/ot/$key').onValue.map((event) {
      final Map<int, double> data = {};
      if (event.snapshot.exists && event.snapshot.value != null) {
        final raw = Map<String, dynamic>.from(event.snapshot.value as Map);
        raw.forEach((k, v) {
          final d = int.tryParse(k);
          if (d != null) data[d] = (v as num).toDouble();
        });
      }
      return data;
    });
  }
}
