import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enterprise Offline-First Engine for Egyptian Educational Centers.
///
/// Features:
/// 1. Cold-boot offline snapshots for groups and sessions (runs with 0 network).
/// 2. Offline Student Directory with arrears & parent phone resolution.
/// 3. Offline attendance queuing with instant deduplication.
/// 4. Zero-Click silent background auto-synchronization on reconnect.
/// 5. Offline materials cache & local download tracker.
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _attendanceQueueKey = 'brivio_offline_attendance_queue';
  static const String _studentsDirectoryKey = 'brivio_offline_students_directory';
  static const String _cachedGroupsKey = 'brivio_offline_cached_groups';
  static const String _cachedSessionsKey = 'brivio_offline_cached_sessions';
  static const String _offlineMaterialsCacheKey = 'brivio_offline_materials_cache';
  static const String _downloadedMaterialsKey = 'brivio_downloaded_materials_ids';

  final ValueNotifier<int> pendingSyncCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  Timer? _autoSyncTimer;
  bool _isWatcherStarted = false;

  /// Initializes the service, loads pending count, and starts background auto-sync watcher
  Future<void> init({bool startWatcher = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_attendanceQueueKey) ?? [];
      pendingSyncCount.value = list.length;

      if (startWatcher && !_isWatcherStarted) {
        startAutoSyncWatcher();
      }
    } catch (_) {}
  }

  // ==========================================
  // 1. COLD-BOOT GROUPS & SESSIONS SNAPSHOTS
  // ==========================================

  /// Caches the active groups and daily sessions snapshot for offline startup
  Future<void> cacheGroupsAndSessions({
    required List<Map<String, dynamic>> groups,
    required List<Map<String, dynamic>> sessions,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedGroupsKey, jsonEncode(groups));
    await prefs.setString(_cachedSessionsKey, jsonEncode(sessions));
  }

  /// Retrieves cached groups if the app opens while network is down
  Future<List<Map<String, dynamic>>> getCachedGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedGroupsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Retrieves cached class sessions for a specific group
  Future<List<Map<String, dynamic>>> getCachedSessions(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedSessionsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final all = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return all.where((s) => s['group_id'] == groupId).toList();
    } catch (_) {
      return [];
    }
  }

  // ==========================================
  // 2. OFFLINE STUDENT DIRECTORY & ARREARS RESOLVER
  // ==========================================

  /// Stores or updates local student profiles directory with active arrears
  Future<void> cacheStudentsDirectory(List<Map<String, dynamic>> students) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getCachedStudentsDirectory();
    final map = <String, Map<String, dynamic>>{};

    for (final s in existing) {
      final key = (s['student_code'] ?? s['id'] ?? '').toString().trim();
      if (key.isNotEmpty) map[key] = s;
    }
    for (final s in students) {
      final key = (s['student_code'] ?? s['id'] ?? '').toString().trim();
      if (key.isNotEmpty) map[key] = s;
    }

    await prefs.setString(_studentsDirectoryKey, jsonEncode(map.values.toList()));
  }

  /// Returns all students cached locally
  Future<List<Map<String, dynamic>>> getCachedStudentsDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_studentsDirectoryKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Resolves student name, parent phone, and arrears offline by barcode or student code
  Future<Map<String, dynamic>?> resolveStudentOffline(String barcode) async {
    final query = barcode.trim();
    if (query.isEmpty) return null;

    final directory = await getCachedStudentsDirectory();
    for (final s in directory) {
      final code = (s['student_code'] ?? '').toString().trim();
      final id = (s['id'] ?? '').toString().trim();
      if (code == query || id == query) {
        return s;
      }
    }
    return null;
  }

  /// Updates student arrears locally after collecting cash in offline mode
  Future<void> updateStudentArrearsLocally({
    required String studentIdOrCode,
    required num amountDeducted,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final directory = await getCachedStudentsDirectory();

    for (final s in directory) {
      final code = (s['student_code'] ?? '').toString().trim();
      final id = (s['id'] ?? '').toString().trim();
      if (code == studentIdOrCode || id == studentIdOrCode) {
        final currentDue = (s['arrears_amount'] as num? ?? 0);
        final newDue = (currentDue - amountDeducted).clamp(0, double.infinity);
        s['arrears_amount'] = newDue;
        s['has_due'] = newDue > 0;
        if (newDue == 0) {
          s['pending_invoice_id'] = null;
        }
        break;
      }
    }

    await prefs.setString(_studentsDirectoryKey, jsonEncode(directory));
  }

  // ==========================================
  // 3. OFFLINE ATTENDANCE QUEUE WITH DEDUPLICATION
  // ==========================================

  /// Queues an attendance check-in locally with automatic duplicate prevention
  Future<AttendanceQueueResult> queueAttendanceCheckIn({
    required String studentId,
    required String groupId,
    required String sessionId,
    required String studentName,
    required String studentCode,
    String? centerId,
    String status = 'present',
    String? notes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_attendanceQueueKey) ?? [];

    // Check for duplicate check-in within the same session
    for (final raw in list) {
      try {
        final existing = jsonDecode(raw) as Map<String, dynamic>;
        final existingSession = existing['session_id'];
        final existingStudent = existing['student_id'];
        final existingCode = existing['student_code'];

        if (existingSession == sessionId && (existingStudent == studentId || existingCode == studentCode)) {
          return AttendanceQueueResult(
            isDuplicate: true,
            message: 'الطالب $studentName مسجل حضور بالفعل في هذه الحصة محلياً! ⚠️',
          );
        }
      } catch (_) {}
    }

    final item = {
      'id': 'offline_${DateTime.now().millisecondsSinceEpoch}_$studentId',
      'student_id': studentId,
      'group_id': groupId,
      'session_id': sessionId,
      'student_name': studentName,
      'student_code': studentCode,
      'center_id': centerId,
      'status': status,
      'notes': notes ?? 'تم التسجيل في وضع عدم الاتصال (Offline Mode)',
      'timestamp': DateTime.now().toIso8601String(),
    };

    list.add(jsonEncode(item));
    await prefs.setStringList(_attendanceQueueKey, list);
    pendingSyncCount.value = list.length;

    return AttendanceQueueResult(
      isDuplicate: false,
      message: 'تم تسجيل حضور الطالب $studentName محلياً بأمان 🟢',
    );
  }

  /// Returns all currently queued attendance records
  Future<List<Map<String, dynamic>>> getQueuedAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_attendanceQueueKey) ?? [];
    return list.map((str) {
      try {
        return jsonDecode(str) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((item) => item.isNotEmpty).toList();
  }

  /// Synchronizes all offline attendance records to Supabase
  Future<SyncResult> syncQueuedAttendance() async {
    if (isSyncing.value) {
      return SyncResult(success: false, message: 'المزامنة جارية بالفعل...');
    }

    isSyncing.value = true;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_attendanceQueueKey) ?? [];

    if (list.isEmpty) {
      isSyncing.value = false;
      pendingSyncCount.value = 0;
      return SyncResult(success: true, syncedCount: 0, message: 'لا توجد سجلات معلقة للمزامنة.');
    }

    int synced = 0;
    final remainingList = <String>[];

    for (final rawItem in list) {
      try {
        final item = jsonDecode(rawItem) as Map<String, dynamic>;

        // Push record to Supabase attendance_records (primary) or fallback session_attendance
        try {
          await Supabase.instance.client.from('attendance_records').upsert({
            'class_session_id': item['session_id'],
            'student_id': item['student_id'],
            'attendance_status': item['status'] ?? 'present',
            'marked_at': item['timestamp'],
            'arrival_at': item['timestamp'],
          }, onConflict: 'class_session_id,student_id');
        } catch (_) {
          await Supabase.instance.client.from('session_attendance').upsert({
            'session_id': item['session_id'],
            'student_id': item['student_id'],
            'status': item['status'] ?? 'present',
            'checked_in_at': item['timestamp'],
            'notes': item['notes'],
          });
        }

        synced++;
      } catch (e) {
        remainingList.add(rawItem);
      }
    }

    await prefs.setStringList(_attendanceQueueKey, remainingList);
    pendingSyncCount.value = remainingList.length;
    isSyncing.value = false;

    if (remainingList.isEmpty) {
      return SyncResult(
        success: true,
        syncedCount: synced,
        message: 'تمت مزامنة كافة سجلات الحضور ($synced طالب) بنجاح مع السيرفر! 🚀',
      );
    } else {
      return SyncResult(
        success: false,
        syncedCount: synced,
        message: 'تمت مزامنة $synced سجل، وتبقت ${remainingList.length} سجلات للمزامنة لاحقاً.',
      );
    }
  }

  /// Clears queued records manually if needed
  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_attendanceQueueKey);
    pendingSyncCount.value = 0;
  }

  // ==========================================
  // 4. ZERO-CLICK BACKGROUND AUTO-SYNC WATCHER
  // ==========================================

  /// Starts heartbeat to automatically detect connectivity and sync without user clicking
  void startAutoSyncWatcher({Duration interval = const Duration(seconds: 15)}) {
    _autoSyncTimer?.cancel();
    _isWatcherStarted = true;
    _autoSyncTimer = Timer.periodic(interval, (_) async {
      await _checkAndAutoSync();
    });
  }

  /// Stops background watcher
  void stopAutoSyncWatcher() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    _isWatcherStarted = false;
  }

  /// Internal heartbeat check
  Future<void> _checkAndAutoSync() async {
    if (isSyncing.value) return;

    // Check if network is responsive
    bool reachable = false;
    try {
      // Lightweight test query to Supabase or network ping
      await Supabase.instance.client.from('groups').select('id').limit(1);
      reachable = true;
    } catch (_) {
      reachable = false;
    }

    isOnline.value = reachable;

    if (reachable && pendingSyncCount.value > 0) {
      await syncQueuedAttendance();
    }
  }

  // ==========================================
  // 5. OFFLINE STUDY MATERIALS & DOWNLOAD TRACKER
  // ==========================================

  /// Caches material or study metadata locally for offline viewing
  Future<void> cacheStudyMaterials(String courseId, List<Map<String, dynamic>> materials) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_offlineMaterialsCacheKey}_$courseId', jsonEncode(materials));
  }

  /// Retrieves cached study materials
  Future<List<Map<String, dynamic>>?> getCachedStudyMaterials(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_offlineMaterialsCacheKey}_$courseId');
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  /// Marks a study material as downloaded locally on the student device
  Future<void> setMaterialDownloaded(String materialId, bool isDownloaded) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_downloadedMaterialsKey) ?? [];
    if (isDownloaded) {
      if (!list.contains(materialId)) list.add(materialId);
    } else {
      list.remove(materialId);
    }
    await prefs.setStringList(_downloadedMaterialsKey, list);
  }

  /// Checks if a material is available for offline reading
  Future<bool> isMaterialDownloaded(String materialId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_downloadedMaterialsKey) ?? [];
    return list.contains(materialId);
  }

  /// Returns all material IDs available offline
  Future<Set<String>> getDownloadedMaterialIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_downloadedMaterialsKey) ?? [];
    return list.toSet();
  }
}

class AttendanceQueueResult {
  final bool isDuplicate;
  final String message;

  AttendanceQueueResult({
    required this.isDuplicate,
    required this.message,
  });
}

class SyncResult {
  final bool success;
  final int syncedCount;
  final String message;

  SyncResult({
    required this.success,
    this.syncedCount = 0,
    required this.message,
  });
}
