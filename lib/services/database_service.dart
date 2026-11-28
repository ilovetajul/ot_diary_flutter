import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

/// Local-first data access.
///
/// Existing cloud paths are intentionally preserved:
/// users/{uid}/profile
/// users/{uid}/ot/{yyyy_MM}/{day}
///
/// New profile photo metadata is an additive `photoUrl` field only.
class DatabaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseDatabase _db = FirebaseDatabase.instance;

  static bool _initialized = false;
  static bool _connected = false;
  static bool _syncing = false;
  static int _queueRevision = 0;
  static Future<void> _queueLock = Future<void>.value();

  static String get uid => _auth.currentUser!.uid;
  static bool get isLoggedIn => _auth.currentUser != null;
  static bool get isOnline => _connected;

  static String _monthKey(int year, int month) =>
      '${year}_${month.toString().padLeft(2, '0')}';

  static String _cacheKey(String key, [String? userId]) => 'ot_${userId ?? uid}_$key';
  static String _profileKey([String? userId]) => 'profile_${userId ?? uid}';
  static String _pendingKey(String userId) => 'ot_pending_sync_$userId';
  static String _photoPathKey([String? userId]) => 'ot_profile_photo_path_${userId ?? uid}';
  static String _pendingPhotoKey([String? userId]) => 'ot_pending_profile_photo_${userId ?? uid}';

  static Future<void> initialize() async {
    if (_initialized) return;

    // Realtime Database disk persistence also retains queued writes.
    // This must be enabled before creating user data references.
    try {
      _db.setPersistenceEnabled(true);
    } catch (_) {
      // If the SDK has already initialized persistence, keep going.
    }

    _db.ref('.info/connected').onValue.listen((event) {
      _connected = event.snapshot.value == true;
      if (_connected) {
        unawaited(syncPendingWrites());
      }
    });

    _initialized = true;
  }

  static void _validateOTEntry(int year, int month, int day, double hours) {
    if (year < 1900 || year > 2100 || month < 1 || month > 12) {
      throw ArgumentError('Invalid OT year or month');
    }
    final lastDay = DateTime(year, month + 1, 0).day;
    if (day < 1 || day > lastDay) {
      throw ArgumentError('Invalid OT day for selected month');
    }
    if (!hours.isFinite || hours < 0 || hours > 24) {
      throw ArgumentError.value(hours, 'hours', 'Must be finite and between 0 and 24');
    }
  }

  static Map<int, double> _decodeHours(
    dynamic raw, {
    int? year,
    int? month,
  }) {
    final result = <int, double>{};
    final entries = raw is Map
        ? raw
        : raw is List
            ? raw.asMap()
            : <dynamic, dynamic>{};
    final lastDay = year != null &&
            month != null &&
            year >= 1900 &&
            year <= 2100 &&
            month >= 1 &&
            month <= 12
        ? DateTime(year, month + 1, 0).day
        : 31;
    entries.forEach((key, value) {
      final day = int.tryParse(key.toString());
      final hours = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      if (day != null &&
          day >= 1 &&
          day <= lastDay &&
          hours != null &&
          hours.isFinite &&
          hours > 0 &&
          hours <= 24) {
        result[day] = hours;
      }
    });
    return result;
  }

  static Map<String, dynamic> _encodeHours(Map<int, double> data) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }

  static Future<Map<String, dynamic>> _readQueue(
    SharedPreferences prefs,
    String userId,
  ) async {
    final raw = prefs.getString(_pendingKey(userId));
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Queue root is not a map');
      return Map<String, dynamic>.from(decoded);
    } catch (error) {
      // Never replace malformed pending data with an empty queue.
      throw FormatException(
        'Pending sync queue is malformed and the original data was preserved: $error',
      );
    }
  }

  static Future<void> _writeQueue(
    SharedPreferences prefs,
    Map<String, dynamic> queue,
    String userId,
  ) async {
    if (queue.isEmpty) {
      await prefs.remove(_pendingKey(userId));
    } else {
      final saved = await prefs.setString(_pendingKey(userId), jsonEncode(queue));
      if (!saved) throw StateError('Could not persist pending sync operations');
    }
  }

  static Future<T> _withQueueLock<T>(
    Future<T> Function(
      Map<String, dynamic> queue,
      SharedPreferences prefs,
    ) action, {
    String? userId,
  }) {
    final operationUid = userId ?? _auth.currentUser?.uid;
    if (operationUid == null) {
      return Future<T>.error(StateError('No authenticated account'));
    }
    final completer = Completer<T>();
    _queueLock = _queueLock.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final queue = await _readQueue(prefs, operationUid);
        final result = await action(queue, prefs);
        await _writeQueue(prefs, queue, operationUid);
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static Future<bool> _hasPendingPrefix(
    String prefix, {
    String? userId,
  }) {
    return _withQueueLock<bool>((queue, prefs) async {
      return queue.keys.any(
        (path) => path == prefix || path.startsWith('$prefix/'),
      );
    }, userId: userId);
  }

  static Future<void> syncPendingWrites() async {
    final syncUid = _auth.currentUser?.uid;
    if (syncUid == null || !_connected || _syncing) return;
    _syncing = true;
    final startingRevision = _queueRevision;
    var failed = false;
    try {
      final queueSnapshot = await _withQueueLock<Map<String, dynamic>>(
        (queue, prefs) async => Map<String, dynamic>.from(queue),
        userId: syncUid,
      );
      for (final path in queueSnapshot.keys) {
        if (_auth.currentUser?.uid != syncUid) {
          failed = true;
          break;
        }
        if (!path.startsWith('users/$syncUid/')) {
          failed = true;
          break;
        }
        final item = Map<String, dynamic>.from(queueSnapshot[path] as Map);
        try {
          final reference = _db.ref(path);
          if (item['operation'] == 'remove') {
            await reference.remove().timeout(const Duration(seconds: 12));
          } else if (item['operation'] == 'update') {
            final values = Map<String, Object?>.from(item['value'] as Map);
            await reference.update(values).timeout(const Duration(seconds: 12));
          } else if (item['operation'] == 'set') {
            await reference.set(item['value']).timeout(const Duration(seconds: 12));
          } else {
            throw StateError('Unknown pending operation');
          }
          await _withQueueLock<void>((latestQueue, prefs) async {
            if (jsonEncode(latestQueue[path]) == jsonEncode(item)) {
              latestQueue.remove(path);
            }
          }, userId: syncUid);
        } catch (_) {
          failed = true;
          break;
        }
      }
      if (_auth.currentUser?.uid == syncUid && !failed) {
        final prefs = await SharedPreferences.getInstance();
        await _syncPendingProfilePhoto(prefs, syncUid);
      }
    } finally {
      _syncing = false;
      if (!failed &&
          _auth.currentUser?.uid == syncUid &&
          _connected &&
          _queueRevision > startingRevision) {
        unawaited(syncPendingWrites());
      }
    }
  }

  static Future<void> _syncPendingProfilePhoto(
    SharedPreferences prefs,
    String userId,
  ) async {
    final localPath = prefs.getString(_pendingPhotoKey(userId));
    if (localPath == null || localPath.isEmpty) return;

    try {
      if (_auth.currentUser?.uid != userId) return;
      final file = File(localPath);
      if (!await file.exists()) {
        await prefs.remove(_pendingPhotoKey(userId));
        return;
      }

      final extension = localPath.split('.').last.toLowerCase();
      final safeExtension = ['png', 'webp'].contains(extension)
          ? extension
          : 'jpg';
      final contentType = safeExtension == 'png'
          ? 'image/png'
          : safeExtension == 'webp'
              ? 'image/webp'
              : 'image/jpeg';

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users/$userId/profile/avatar.$safeExtension');

      if (_auth.currentUser?.uid != userId) return;
      final uploaded = await storageRef
          .putFile(
            file,
            SettableMetadata(contentType: contentType),
          )
          .timeout(const Duration(seconds: 30));

      final downloadUrl = await uploaded.ref
          .getDownloadURL()
          .timeout(const Duration(seconds: 15));

      if (_auth.currentUser?.uid != userId) return;
      // Update only the new photoUrl child; do not replace the profile node.
      await _db
          .ref('users/$userId/profile/photoUrl')
          .set(downloadUrl)
          .timeout(const Duration(seconds: 12));

      final cachedProfile = prefs.getString(_profileKey(userId));
      if (cachedProfile != null) {
        try {
          final map = Map<String, dynamic>.from(
            jsonDecode(cachedProfile) as Map,
          );
          map['photoUrl'] = downloadUrl;
          await prefs.setString(_profileKey(userId), jsonEncode(map));
        } catch (_) {
          // Cloud update succeeded; local profile cache can be rebuilt later.
        }
      }

      if (prefs.getString(_pendingPhotoKey(userId)) == localPath) {
        await prefs.remove(_pendingPhotoKey(userId));
      }
    } catch (_) {
      // Storage may not yet be enabled or the device may have gone offline.
      // Keep the local file and pending path; retry on the next connection.
    }
  }

  static Future<bool> hasPendingChanges() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;
    return _withQueueLock<bool>((queue, prefs) async {
      return queue.isNotEmpty ||
          (prefs.getString(_pendingPhotoKey(userId))?.isNotEmpty ?? false);
    }, userId: userId);
  }

  static Future<void> saveProfile(UserProfile profile) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    await _withQueueLock<void>((queue, prefs) async {
      if (_auth.currentUser?.uid != userId) throw StateError('Account changed');
      final cloudProfileMap = profile.toMap()..remove('photoUrl');
      String? cachedPhotoUrl;
      final cached = prefs.getString(_profileKey(userId));
      if (cached != null) {
        try {
          final cachedMap = Map<String, dynamic>.from(jsonDecode(cached) as Map);
          cachedPhotoUrl = cachedMap['photoUrl']?.toString();
        } catch (_) {}
      }
      final localProfileMap = <String, dynamic>{
        ...cloudProfileMap,
        if (cachedPhotoUrl != null && cachedPhotoUrl.isNotEmpty)
          'photoUrl': cachedPhotoUrl
        else if (profile.photoUrl != null)
          'photoUrl': profile.photoUrl,
      };
      final cachedSaved = await prefs.setString(
        _profileKey(userId),
        jsonEncode(localProfileMap),
      );
      if (!cachedSaved) throw StateError('Could not save profile cache');
      queue['users/$userId/profile'] = <String, dynamic>{
        'operation': 'update',
        'value': cloudProfileMap,
      };
      _queueRevision++;
    }, userId: userId);
    if (_connected && _auth.currentUser?.uid == userId) {
      unawaited(syncPendingWrites());
    }
  }

  static Future<UserProfile?> getProfile() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;
    if (_connected) unawaited(syncPendingWrites());
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_profileKey(userId));
    final profileHasPendingWrite =
        await _hasPendingPrefix('users/$userId/profile', userId: userId);
    if (_connected && !profileHasPendingWrite) {
      try {
        final snapshot = await _db
            .ref('users/$userId/profile')
            .get()
            .timeout(const Duration(seconds: 6));
        if (_auth.currentUser?.uid != userId) return null;
        if (snapshot.exists && snapshot.value is Map) {
          final profile = UserProfile.fromMap(snapshot.value as Map);
          await prefs.setString(_profileKey(userId), jsonEncode(profile.toMap()));
          return profile;
        }
      } catch (_) {}
    }
    if (_auth.currentUser?.uid != userId) return null;
    if (cached != null) {
      try {
        return UserProfile.fromMap(jsonDecode(cached) as Map);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<Map<int, double>> getMonthData(
    int year,
    int month,
  ) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return <int, double>{};
    if (year < 1900 || year > 2100 || month < 1 || month > 12) {
      throw ArgumentError('Invalid OT month');
    }
    final key = _monthKey(year, month);
    final prefs = await SharedPreferences.getInstance();
    final cachedRaw = prefs.getString(_cacheKey(key, userId));
    var local = <int, double>{};
    if (cachedRaw != null) {
      try {
        local = _decodeHours(jsonDecode(cachedRaw), year: year, month: month);
      } catch (_) {}
    }
    final path = 'users/$userId/ot/$key';
    final hasPending = await _hasPendingPrefix(path, userId: userId);
    if (_connected && !hasPending) {
      try {
        final snapshot = await _db.ref(path).get().timeout(const Duration(seconds: 6));
        if (_auth.currentUser?.uid != userId) return <int, double>{};
        final cloud = _decodeHours(snapshot.value, year: year, month: month);
        return await _withQueueLock<Map<int, double>>((queue, preferences) async {
          if (queue.keys.any((p) => p == path || p.startsWith('$path/'))) {
            final latest = preferences.getString(_cacheKey(key, userId));
            return latest == null
                ? <int, double>{}
                : _decodeHours(jsonDecode(latest), year: year, month: month);
          }
          final saved = await preferences.setString(
            _cacheKey(key, userId),
            jsonEncode(_encodeHours(cloud)),
          );
          if (!saved) throw StateError('Could not save month cache');
          return cloud;
        }, userId: userId);
      } catch (_) {}
    }
    return _auth.currentUser?.uid == userId ? local : <int, double>{};
  }

  static Future<void> saveOTDay(
    int year,
    int month,
    int day,
    double hours, {
    String? userId,
  }) async {
    final operationUid = userId ?? _auth.currentUser?.uid;
    if (operationUid == null) return;
    if (_auth.currentUser?.uid != operationUid) throw StateError('Account changed');
    _validateOTEntry(year, month, day, hours);
    final key = _monthKey(year, month);
    final cacheKey = _cacheKey(key, operationUid);
    final path = 'users/$operationUid/ot/$key/$day';
    await _withQueueLock<void>((queue, prefs) async {
      if (_auth.currentUser?.uid != operationUid) throw StateError('Account changed');
      final raw = prefs.getString(cacheKey);
      Map<String, dynamic> local = <String, dynamic>{};
      if (raw != null) {
        try {
          local = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        } catch (_) {}
      }
      if (hours == 0) {
        local.remove(day.toString());
      } else {
        local[day.toString()] = hours;
      }
      final cacheSaved = await prefs.setString(cacheKey, jsonEncode(local));
      if (!cacheSaved) throw StateError('Could not save OT cache');
      queue[path] = <String, dynamic>{
        'operation': hours == 0 ? 'remove' : 'set',
        'value': hours > 0 ? hours : null,
      };
      _queueRevision++;
    }, userId: operationUid);
    if (_connected && _auth.currentUser?.uid == operationUid) {
      unawaited(syncPendingWrites());
    }
  }

  static Future<void> resetMonth(int year, int month) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    if (year < 1900 || year > 2100 || month < 1 || month > 12) {
      throw ArgumentError('Invalid OT month');
    }
    final key = _monthKey(year, month);
    final path = 'users/$userId/ot/$key';
    await _withQueueLock<void>((queue, prefs) async {
      if (_auth.currentUser?.uid != userId) throw StateError('Account changed');
      await prefs.remove(_cacheKey(key, userId));
      queue.removeWhere(
        (queuedPath, _) => queuedPath == path || queuedPath.startsWith('$path/'),
      );
      queue[path] = <String, dynamic>{'operation': 'remove', 'value': null};
      _queueRevision++;
    }, userId: userId);
    if (_connected && _auth.currentUser?.uid == userId) {
      unawaited(syncPendingWrites());
    }
  }

  static Future<String> saveProfilePhoto(File source) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw StateError('লগইন ছাড়া ছবি সংরক্ষণ করা যাবে না');
    final appDirectory = await getApplicationDocumentsDirectory();
    final photoDirectory = Directory('${appDirectory.path}/ot_diary/profile_photos');
    await photoDirectory.create(recursive: true);
    final sourceExtension = source.path.split('.').last.toLowerCase();
    final extension = ['png', 'webp'].contains(sourceExtension) ? sourceExtension : 'jpg';
    final destination = File(
      '${photoDirectory.path}/avatar_${userId}_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    if (await destination.exists()) await destination.delete();
    await source.copy(destination.path);
    if (_auth.currentUser?.uid != userId) {
      await destination.delete();
      throw StateError('Account changed before photo could be queued');
    }
    final prefs = await SharedPreferences.getInstance();
    final pathSaved = await prefs.setString(_photoPathKey(userId), destination.path);
    final queueSaved = await prefs.setString(_pendingPhotoKey(userId), destination.path);
    if (!pathSaved || !queueSaved) throw StateError('Could not persist profile photo queue');
    _queueRevision++;
    if (_connected && _auth.currentUser?.uid == userId) unawaited(syncPendingWrites());
    return destination.path;
  }

  static Future<String?> getLocalProfilePhotoPath() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_photoPathKey(userId));
    if (path == null || path.isEmpty || _auth.currentUser?.uid != userId) return null;
    if (!await File(path).exists()) return null;
    return path;
  }

  static Future<void> onLogout() async {
    // Do not clear user-specific offline caches or pending writes on logout.
    await syncPendingWrites();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_session');
  }

  static Future<Map<String, dynamic>> exportAllData() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return <String, dynamic>{};
    final profile = await getProfile();
    if (_auth.currentUser?.uid != userId) throw StateError('Account changed');
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> cloudUser = <String, dynamic>{};
    if (_connected) {
      try {
        final snapshot = await _db
            .ref('users/$userId')
            .get()
            .timeout(const Duration(seconds: 6));
        if (_auth.currentUser?.uid != userId) throw StateError('Account changed');
        if (snapshot.exists && snapshot.value is Map) {
          cloudUser = Map<String, dynamic>.from(snapshot.value as Map);
        }
      } catch (_) {
        if (_auth.currentUser?.uid != userId) throw StateError('Account changed');
      }
    }
    final ot = cloudUser['ot'] ?? <String, dynamic>{};
    return <String, dynamic>{
      'profile': profile?.toMap(),
      'ot': ot,
      'exportedAt': DateTime.now().toIso8601String(),
      'offlineCacheAvailable': prefs.getString(_profileKey(userId)) != null,
    };
  }

  static Future<void> importData(Map<String, dynamic> data) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Merge month/day entries individually; never replace the whole OT node.
    final rawOt = data['ot'];
    if (rawOt is! Map) return;

    for (final monthEntry in rawOt.entries) {
      final monthKey = monthEntry.key.toString();
      if (monthEntry.value is! Map) continue;

      final days = Map<dynamic, dynamic>.from(monthEntry.value as Map);
      for (final dayEntry in days.entries) {
        final day = int.tryParse(dayEntry.key.toString());
        final hours = dayEntry.value is num
            ? (dayEntry.value as num).toDouble()
            : double.tryParse(dayEntry.value.toString());
        if (day == null || hours == null) continue;

        final parts = monthKey.split('_');
        if (parts.length != 2) continue;
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        if (year == null || month == null) continue;

        _validateOTEntry(year, month, day, hours);
        if (_auth.currentUser?.uid != userId) throw StateError('Account changed during import');
        await saveOTDay(year, month, day, hours, userId: userId);
      }
    }
  }

  static Stream<Map<int, double>> streamMonthData(
    int year,
    int month,
  ) {
    if (!isLoggedIn) return Stream.value(<int, double>{});

    final key = _monthKey(year, month);
    return _db.ref('users/$uid/ot/$key').onValue.map(
      (event) => _decodeHours(event.snapshot.value),
    );
  }
}
