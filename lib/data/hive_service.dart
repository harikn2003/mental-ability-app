import 'package:hive_flutter/hive_flutter.dart';

import 'session_record.dart';

/// HiveService — handles all Hive box operations.
///
/// Call HiveService.init() once in main() before runApp().
/// All other methods are static — no need to instantiate.
class HiveService {
  static const _sessionBox = 'sessions';
  static const _maxRecords = 30; // keep last 30 sessions

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(SessionRecordAdapter());
    await Hive.openBox<SessionRecord>(_sessionBox);
  }

  /// Save a completed session. Trims to _maxRecords oldest entries.
  static Future<void> saveSession(SessionRecord record) async {
    final box = Hive.box<SessionRecord>(_sessionBox);
    await box.add(record);

    // Trim oldest if over limit
    if (box.length > _maxRecords) {
      final excess = box.length - _maxRecords;
      final keys = box.keys.take(excess).toList();
      await box.deleteAll(keys);
    }
  }

  /// Returns sessions newest-first.
  static List<SessionRecord> getSessions() {
    final box = Hive.box<SessionRecord>(_sessionBox);
    return box.values.toList().reversed.toList();
  }

  /// Clears all session history.
  static Future<void> clearHistory() async {
    await Hive.box<SessionRecord>(_sessionBox).clear();
  }
}
