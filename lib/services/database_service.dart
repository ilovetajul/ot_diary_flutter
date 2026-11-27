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

  static String _cacheKey(String key) => 'ot_${uid}_$key';
  static String _profileKey() => 'profile_$uid';
  static String _pendingKey() => 'ot_pending_sync_$uid';
  static String _photoPathKey() => 'ot_profile_photo_path_$uid';
  static String _pendingPhotoKey() => 'ot_pending_profile_photo_$uid';

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

  static Map<int, double> _decodeHours(dynamic raw) {
    final result = <int, double>{};
    final entries = raw is Map ? raw : raw is List ? raw.asMap() : <dynamic, dynamic>{};

    entries.forEach((key, value) {
      final day = int.tryParse(key.toString());
      final hours = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      if (day != null && hours != null && hours > 0) {
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
  ) async {
    final raw = prefs.getString(_pendingKey());
    if (raw == null || raw.isEmpty) return <String, dynamic>{};

    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      // Keep the app usable if a local queue record is malformed.
      return <String, dynamic>{};
    }
  }

  static Future<void> _writeQueue(
    SharedPreferences prefs,
    Map<String, dynamic> queue,
  ) async {
    if (queue.isEmpty) {
      await prefs.remove(_pendingKey());
    } else {
      await prefs.setString(_pendingKey(), jsonEncode(queue));
    }
  }

  /// Serializes local queue mutations so a new offline edit cannot be
  /// overwritten by a sync pass that started a moment earlier.
  static Future<T> _withQueueLock<T>(
    Future<T> Function(
      Map<String, dynamic> queue,
      SharedPreferences prefs,
    ) action,
  ) {
    final completer = Completer<T>();
    _queueLock = _queueLock.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final queue = await _readQueue(prefs);
        final result = await action(queue, prefs);
        await _writeQueue(prefs, queue);
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }


  static Future<bool> _hasPendingPrefix(String prefix) {
    return _withQueueLock<bool>((queue, prefs) async {
      return queue.keys.any(
        (path) => path == prefix || path.startsWith('$prefix/'),
      );
    });
  }

  static Future<void> syncPendingWrites() async {
    if (!isLoggedIn || !_connected || _syncing) return;

    _syncing = true;
    final startingRevision = _queueRevision;
    var failed = false;

    try {
      final queueSnapshot = await _withQueueLock<Map<String, dynamic>>(
        (queue, prefs) async => Map<String, dynamic>.from(queue),
      );

      for (final path in queueSnapshot.keys) {
        final item = Map<String, dynamic>.from(
          queueSnapshot[path] as Map,
        );

        try {
          final reference = _db.ref(path);
          if (item['operation'] == 'remove') {
            await reference.remove().timeout(const Duration(seconds: 12));
          } else if (item['operation'] == 'update') {
            final values = Map<String, Object?>.from(
              item['value'] as Map,
            );
            await reference
                .update(values)
                .timeout(const Duration(seconds: 12));
          } else {
            await reference
                .set(item['value'])
                .timeout(const Duration(seconds: 12));
          }

          // Remove only the exact operation that was uploaded. If the user
          // edited this same path while the request was in flight, keep the
          // newer queued value for the next pass.
          await _withQueueLock<void>((latestQueue, prefs) async {
            final latest = latestQueue[path];
            if (jsonEncode(latest) == jsonEncode(item)) {
              latestQueue.remove(path);
            }
          });
        } catch (_) {
          // Leave the failed item in the durable queue for the next
          // connection event or app resume.
          failed = true;
          break;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await _syncPendingProfilePhoto(prefs);
    } finally {
      _syncing = false;

      // If a new edit was queued during this pass, immediately run one more
      // pass. A failed request is not retried in a tight loop.
      if (!failed && _connected && _queueRevision > startingRevision) {
        unawaited(syncPendingWrites());
      }
    }
  }

  static Future<void> _syncPendingProfilePhoto(
    SharedPreferences prefs,
  ) async {
    final localPath = prefs.getString(_pendingPhotoKey());
    if (localPath == null || localPath.isEmpty) return;

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        await prefs.remove(_pendingPhotoKey());
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
          .child('users/$uid/profile/avatar.$safeExtension');

      final uploaded = await storageRef
          .putFile(
            file,
            SettableMetadata(contentType: contentType),
          )
          .timeout(const Duration(seconds: 30));

      final downloadUrl = await uploaded.ref
          .getDownloadURL()
          .timeout(const Duration(seconds: 15));

      // Update only the new photoUrl child; do not replace the profile node.
      await _db
          .ref('users/$uid/profile/photoUrl')
          .set(downloadUrl)
          .timeout(const Duration(seconds: 12));

      final cachedProfile = prefs.getString(_profileKey());
      if (cachedProfile != null) {
        try {
          final map = Map<String, dynamic>.from(
            jsonDecode(cachedProfile) as Map,
          );
          map['photoUrl'] = downloadUrl;
          await prefs.setString(_profileKey(), jsonEncode(map));
        } catch (_) {
          // Cloud update succeeded; local profile cache can be rebuilt later.
        }
      }

      if (prefs.getString(_pendingPhotoKey()) == localPath) {
        await prefs.remove(_pendingPhotoKey());
      }
    } catch (_) {
      // Storage may not yet be enabled or the device may have gone offline.
      // Keep the local file and pending path; retry on the next connection.
    }
  }

  static Future<bool> hasPendingChanges() async {
    if (!isLoggedIn) return false;
    return _withQueueLock<bool>((queue, prefs) async {
      return queue.isNotEmpty ||
          (prefs.getString(_pendingPhotoKey())?.isNotEmpty ?? false);
    });
  }

  static Future<void> saveProfile(UserProfile profile) async {
    if (!isLoggedIn) return;

    await _withQueueLock<void>((queue, prefs) async {
      final cloudProfileMap = profile.toMap()..remove('photoUrl');
      String? cachedPhotoUrl;

      final cached = prefs.getString(_profileKey());
      if (cached != null) {
        try {
          final cachedMap = Map<String, dynamic>.from(
            jsonDecode(cached) as Map,
          );
          cachedPhotoUrl = cachedMap['photoUrl']?.toString();
        } catch (_) {
          // Continue with the profile object if the cache cannot be parsed.
        }
      }

      // Photo URL is managed only by the photo-upload flow. Profile edits
      // must never overwrite it with a stale URL from an older screen object.
      final localProfileMap = <String, dynamic>{
        ...cloudProfileMap,
        if (cachedPhotoUrl != null && cachedPhotoUrl.isNotEmpty)
          'photoUrl': cachedPhotoUrl
        else if (profile.photoUrl != null)
          'photoUrl': profile.photoUrl,
      };

      await prefs.setString(
        _profileKey(),
        jsonEncode(localProfileMap),
      );

      // Update only known editable fields; unknown future profile fields and
      // photoUrl remain untouched in Firebase.
      queue['users/$uid/profile'] = <String, dynamic>{
        'operation': 'update',
        'value': cloudProfileMap,
      };
      _queueRevision++;
    });

    if (_connected) {
      unawaited(syncPendingWrites());
    }
  }

  static Future<UserProfile?> getProfile() async {
    if (!isLoggedIn) return null;
    if (_connected) {
      unawaited(syncPendingWrites());
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_profileKey());
    final profileHasPendingWrite =
        await _hasPendingPrefix('users/$uid/profile');

    if (_connected && !profileHasPendingWrite) {
      try {
        final snapshot = await _db
            .ref('users/$uid/profile')
            .get()
            .timeout(const Duration(seconds: 6));

        if (snapshot.exists && snapshot.value is Map) {
          final profile = UserProfile.fromMap(snapshot.value as Map);
          await prefs.setString(
            _profileKey(),
            jsonEncode(profile.toMap()),
          );
          return profile;
        }
      } catch (_) {
        // Fall back to the local copy below.
      }
    }

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
    if (!isLoggedIn) return <int, double>{};

    final key = _monthKey(year, month);
    final prefs = await SharedPreferences.getInstance();
    final cachedRaw = prefs.getString(_cacheKey(key));
    var local = <int, double>{};

    if (cachedRaw != null) {
      try {
        local = _decodeHours(jsonDecode(cachedRaw));
      } catch (_) {
        local = <int, double>{};
      }
    }

    final path = 'users/$uid/ot/$key';
    final hasPending = await _hasPendingPrefix(path);

    if (_connected && !hasPending) {
      try {
        final snapshot = await _db
            .ref(path)
            .get()
            .timeout(const Duration(seconds: 6));

        final cloud = _decodeHours(snapshot.value);
        // Use server data only when no pending edits appeared while reading.
        if (path.startsWith('users/$uid/')) {
          return await _withQueueLock<Map<int, double>>((queue, preferences) async {
            if (queue.keys.any((p) => p == path || p.startsWith('$path/'))) {
              final latest = preferences.getString(_cacheKey(key));
              return latest == null ? <int, double>{} : _decodeHours(jsonDecode(latest));
            }
            await preferences.setString(_cacheKey(key), jsonEncode(_encodeHours(cloud)));
            return cloud;
          });
        }
      } catch (_) {
        // Offline or timeout: use the local cache.
      }
    }

    return local;
  }

  static Future<void> saveOTDay(
    int year,
    int month,
    int day,
    double hours,
  ) async {
    if (!isLoggedIn) return;

    final key = _monthKey(year, month);
    final cacheKey = _cacheKey(key);
    final path = 'users/$uid/ot/$key/$day';

    await _withQueueLock<void>((queue, prefs) async {
      final raw = prefs.getString(cacheKey);
      Map<String, dynamic> local = <String, dynamic>{};
      if (raw != null) {
        try {
          local = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        } catch (_) {
          local = <String, dynamic>{};
        }
      }

      if (hours <= 0) {
        local.remove(day.toString());
      } else {
        local[day.toString()] = hours;
      }

      // Cache and queue are updated together before any cloud request.
      await prefs.setString(cacheKey, jsonEncode(local));
      queue[path] = <String, dynamic>{
        'operation': hours <= 0 ? 'remove' : 'set',
        'value': hours > 0 ? hours : null,
      };
      _queueRevision++;
    });

    if (_connected) {
      unawaited(syncPendingWrites());
    }
  }

  static Future<void> resetMonth(int year, int month) async {
    if (!isLoggedIn) return;

    final key = _monthKey(year, month);
    final path = 'users/$uid/ot/$key';

    await _withQueueLock<void>((queue, prefs) async {
      await prefs.remove(_cacheKey(key));

      // A reset supersedes queued day-level writes. If a new day is saved
      // afterwards, its child operation will be appended after this removal.
      queue.removeWhere(
        (queuedPath, _) =>
            queuedPath == path || queuedPath.startsWith('$path/'),
      );
      queue[path] = <String, dynamic>{
        'operation': 'remove',
        'value': null,
      };
      _queueRevision++;
    });

    if (_connected) {
      unawaited(syncPendingWrites());
    }
  }

  static Future<String> saveProfilePhoto(File source) async {
    if (!isLoggedIn) {
      throw StateError('লগইন ছাড়া ছবি সংরক্ষণ করা যাবে না');
    }

    final appDirectory = await getApplicationDocumentsDirectory();
    final photoDirectory = Directory(
      '${appDirectory.path}/ot_diary/profile_photos',
    );
    await photoDirectory.create(recursive: true);

    final sourceExtension = source.path.split('.').last.toLowerCase();
    final extension = ['png', 'webp'].contains(sourceExtension)
        ? sourceExtension
        : 'jpg';

    final destination = File(
      '${photoDirectory.path}/avatar_${uid}_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    if (await destination.exists()) {
      await destination.delete();
    }
    await source.copy(destination.path);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_photoPathKey(), destination.path);
    await prefs.setString(_pendingPhotoKey(), destination.path);
    _queueRevision++;

    if (_connected) {
      unawaited(syncPendingWrites());
    }
    return destination.path;
  }

  static Future<String?> getLocalProfilePhotoPath() async {
    if (!isLoggedIn) return null;
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_photoPathKey());
    if (path == null || path.isEmpty) return null;
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
    if (!isLoggedIn) return <String, dynamic>{};

    final profile = await getProfile();
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> cloudUser = <String, dynamic>{};
    if (_connected) {
      try {
        final snapshot = await _db
            .ref('users/$uid')
            .get()
            .timeout(const Duration(seconds: 6));
        if (snapshot.exists && snapshot.value is Map) {
          cloudUser = Map<String, dynamic>.from(snapshot.value as Map);
        }
      } catch (_) {
        // Export still includes the cached profile when offline.
      }
    }

    final ot = cloudUser['ot'] ?? <String, dynamic>{};
    return <String, dynamic>{
      'profile': profile?.toMap(),
      'ot': ot,
      'exportedAt': DateTime.now().toIso8601String(),
      'offlineCacheAvailable': prefs.getString(_profileKey()) != null,
    };
  }

  static Future<void> importData(Map<String, dynamic> data) async {
    if (!isLoggedIn) return;

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

        await saveOTDay(year, month, day, hours);
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
