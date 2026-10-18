import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/personal_whiteboard_item.dart';

class PersonalWhiteboardsStorage {
  PersonalWhiteboardsStorage._();

  static const String _indexPrefix = 'personal_whiteboards_index_';
  static const String _contentPrefix = 'personal_whiteboard_content_';

  static String _indexKey(String userId) => '$_indexPrefix$userId';
  static String _contentKey(String boardId) => '$_contentPrefix$boardId';

  /// Loads list of board metadata for the user, ordered by updatedAt descending.
  /// Also automatically migrates legacy single board if one exists.
  static Future<List<PersonalWhiteboardItem>> getBoards(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final rawIndex = prefs.getString(_indexKey(userId));
    List<PersonalWhiteboardItem> list = [];

    if (rawIndex != null && rawIndex.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawIndex) as List;
        list = decoded
            .whereType<Map>()
            .map((m) =>
                PersonalWhiteboardItem.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      } catch (_) {}
    }

    // Check for legacy single board migration
    final legacyKey = 'student_personal_board_$userId';
    final legacyRaw = prefs.getString(legacyKey);
    if (legacyRaw != null && legacyRaw.isNotEmpty && list.isEmpty) {
      try {
        final legacyDecoded = jsonDecode(legacyRaw) as Map<String, dynamic>;
        final strokes = legacyDecoded['strokes'] as List? ?? [];
        if (strokes.isNotEmpty) {
          final legacyId =
              'board_legacy_${DateTime.now().millisecondsSinceEpoch}';
          final migratedItem = PersonalWhiteboardItem(
            id: legacyId,
            userId: userId,
            title: 'مسودة المذاكرة السابقة',
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            updatedAt: DateTime.now(),
            bgTheme: legacyDecoded['theme']?.toString() ?? 'gridMath',
            strokeCount: strokes.length,
          );
          await prefs.setString(_contentKey(legacyId), legacyRaw);
          list.add(migratedItem);
          await _saveIndex(prefs, userId, list);
          await prefs.remove(legacyKey);
        }
      } catch (_) {}
    }

    // Sort by updatedAt descending (newest first)
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Saves board metadata and full stroke content.
  static Future<void> saveBoard({
    required PersonalWhiteboardItem metadata,
    required Map<String, dynamic> content,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Save full strokes content
    await prefs.setString(_contentKey(metadata.id), jsonEncode(content));

    // 2. Update index list
    final list = await getBoards(metadata.userId);
    final existingIndex = list.indexWhere((b) => b.id == metadata.id);
    if (existingIndex >= 0) {
      list[existingIndex] = metadata;
    } else {
      list.insert(0, metadata);
    }

    await _saveIndex(prefs, metadata.userId, list);
  }

  /// Loads full board content (strokes and theme)
  static Future<Map<String, dynamic>?> loadBoardContent(String boardId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contentKey(boardId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Renames a board
  static Future<void> renameBoard({
    required String userId,
    required String boardId,
    required String newTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getBoards(userId);
    final idx = list.indexWhere((b) => b.id == boardId);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(
        title: newTitle.trim(),
        updatedAt: DateTime.now(),
      );
      await _saveIndex(prefs, userId, list);
    }
  }

  /// Deletes a board
  static Future<void> deleteBoard({
    required String userId,
    required String boardId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getBoards(userId);
    list.removeWhere((b) => b.id == boardId);
    await _saveIndex(prefs, userId, list);
    await prefs.remove(_contentKey(boardId));
  }

  /// Duplicates a board
  static Future<PersonalWhiteboardItem?> duplicateBoard({
    required String userId,
    required String boardId,
  }) async {
    final list = await getBoards(userId);
    final idx = list.indexWhere((b) => b.id == boardId);
    if (idx < 0) return null;

    final original = list[idx];
    final content = await loadBoardContent(boardId);
    if (content == null) return null;

    final newId = 'board_${DateTime.now().millisecondsSinceEpoch}';
    final newItem = PersonalWhiteboardItem(
      id: newId,
      userId: userId,
      title: '${original.title} (نسخة)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      bgTheme: original.bgTheme,
      strokeCount: original.strokeCount,
    );

    await saveBoard(metadata: newItem, content: content);
    return newItem;
  }

  static Future<void> _saveIndex(
    SharedPreferences prefs,
    String userId,
    List<PersonalWhiteboardItem> list,
  ) async {
    final raw = jsonEncode(list.map((b) => b.toJson()).toList());
    await prefs.setString(_indexKey(userId), raw);
  }
}
