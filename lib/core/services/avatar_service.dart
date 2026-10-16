import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../logging/app_logger.dart';
import 'saved_accounts_service.dart';

/// Preset avatar option model for instant 1-tap avatar selection.
class PresetAvatar {
  final String id;
  final String titleArabic;
  final String category;
  final String url;

  const PresetAvatar({
    required this.id,
    required this.titleArabic,
    required this.category,
    required this.url,
  });
}

/// Unified Avatar Service handling picking, uploading to Supabase Storage,
/// fallback data URI encoding, presets, and profile persistence.
class AvatarService {
  /// Robust ImageProvider supporting both web URLs and Base64 Data URIs.
  static ImageProvider? getImageProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.trim().isEmpty) return null;
    final trimmed = avatarUrl.trim();
    if (trimmed.startsWith('data:image')) {
      try {
        final commaIdx = trimmed.indexOf(',');
        final base64String = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
        return MemoryImage(base64Decode(base64String));
      } catch (e) {
        AppLogger.warning('Failed to decode base64 avatar: $e');
        return null;
      }
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }
    return null;
  }

  /// List of high quality educational preset avatars.
  static const List<PresetAvatar> educationalPresets = [
    PresetAvatar(
      id: 'student_boy_1',
      titleArabic: 'طالب مجتهد 🎓',
      category: 'طالب',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Zack',
    ),
    PresetAvatar(
      id: 'student_girl_1',
      titleArabic: 'طالبة متفوقة 🎓',
      category: 'طالب',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Aria',
    ),
    PresetAvatar(
      id: 'student_scholar',
      titleArabic: 'باحث علمي 📚',
      category: 'طالب',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Felix',
    ),
    PresetAvatar(
      id: 'student_scientist',
      titleArabic: 'عالمة المستقبل 🔬',
      category: 'طالب',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Luna',
    ),
    PresetAvatar(
      id: 'teacher_male',
      titleArabic: 'أستاذ خبير 👨‍🏫',
      category: 'معلم',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Oliver',
    ),
    PresetAvatar(
      id: 'teacher_female',
      titleArabic: 'أستاذة قديرة 👩‍🏫',
      category: 'معلم',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Sophie',
    ),
    PresetAvatar(
      id: 'admin_director',
      titleArabic: 'مدير المنظومة 👨‍💼',
      category: 'إدارة',
      url: 'https://api.dicebear.com/7.x/bottts/png?seed=Commander',
    ),
    PresetAvatar(
      id: 'admin_leader',
      titleArabic: 'مديرة تنفيذية 👩‍💼',
      category: 'إدارة',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Clara',
    ),
    PresetAvatar(
      id: 'parent_father',
      titleArabic: 'ولي أمر (أب) 👨‍👩‍👦',
      category: 'ولي أمر',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Alexander',
    ),
    PresetAvatar(
      id: 'parent_mother',
      titleArabic: 'ولي أمر (أم) 👨‍👩‍👧',
      category: 'ولي أمر',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Victoria',
    ),
    PresetAvatar(
      id: 'brivio_bot',
      titleArabic: 'المساعد الذكي 🤖',
      category: 'منظومة',
      url: 'https://api.dicebear.com/7.x/bottts/png?seed=BrivioBot',
    ),
    PresetAvatar(
      id: 'star_achiever',
      titleArabic: 'نجم أكاديمي ⭐',
      category: 'طالب',
      url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Jasper',
    ),
  ];

  /// Opens file selector to pick an image from device and uploads or encodes it.
  static Future<String?> pickAndUploadAvatar({required String userId}) async {
    try {
      const typeGroup = XTypeGroup(
        label: 'images',
        extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return null;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      final extension = file.name.split('.').last.toLowerCase();
      final mimeType = extension == 'png'
          ? 'image/png'
          : (extension == 'webp' ? 'image/webp' : 'image/jpeg');

      // Attempt 1: Upload to Supabase Storage 'avatars' bucket
      try {
        final client = Supabase.instance.client;
        final storagePath = 'profiles/$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';

        await client.storage.from('avatars').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );

        final publicUrl = client.storage.from('avatars').getPublicUrl(storagePath);
        if (publicUrl.isNotEmpty) {
          return publicUrl;
        }
      } catch (storageError) {
        AppLogger.warning('Supabase storage upload failed, falling back to base64: $storageError');
      }

      // Attempt 2: Fallback to high-quality Data URI
      final base64Data = base64Encode(bytes);
      return 'data:$mimeType;base64,$base64Data';
    } catch (e) {
      AppLogger.error('pickAndUploadAvatar failed', e);
      return null;
    }
  }

  /// Updates the user's avatar_url in the Supabase 'profiles' table
  /// and synchronizes with local saved accounts.
  static Future<bool> updateUserAvatar({
    required String userId,
    required String? newAvatarUrl,
    String? userEmail,
  }) async {
    try {
      final client = Supabase.instance.client;

      // 1. Update in Supabase
      await client.from('profiles').update({
        'avatar_url': newAvatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      // 2. Sync to local SavedAccountsService
      try {
        final accounts = await SavedAccountsService.getSavedAccounts();
        final matchIdx = accounts.indexWhere(
          (a) => a.id == userId || (userEmail != null && a.email.toLowerCase() == userEmail.toLowerCase()),
        );
        if (matchIdx != -1) {
          final matched = accounts[matchIdx];
          await SavedAccountsService.saveAccount(
            matched.copyWith(avatarUrl: newAvatarUrl),
          );
        }
      } catch (_) {}

      return true;
    } catch (e) {
      AppLogger.error('updateUserAvatar failed', e);
      return false;
    }
  }
}
