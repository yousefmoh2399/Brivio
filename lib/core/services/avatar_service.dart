import 'dart:convert';
import 'dart:typed_data';
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
  /// Robust ImageProvider supporting web URLs, Base64 Data URIs, and raw Base64 strings.
  static ImageProvider? getImageProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.trim().isEmpty) return null;
    final trimmed = avatarUrl.trim();

    // 1. Local App Asset (e.g. assets/avatars/...)
    if (trimmed.startsWith('assets/')) {
      return AssetImage(trimmed);
    }

    // 2. Data URI with base64 (e.g. data:image/png;base64,...)
    if (trimmed.startsWith('data:image') || trimmed.startsWith('data:application')) {
      try {
        final commaIdx = trimmed.indexOf(',');
        final base64String = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
        final cleanBase64 = base64String.replaceAll(RegExp(r'\s+'), '');
        return MemoryImage(base64Decode(cleanBase64));
      } catch (e) {
        AppLogger.warning('Failed to decode data URI avatar: $e');
        return null;
      }
    }

    // 2. HTTP / HTTPS Web URL (must have a valid host)
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      try {
        final uri = Uri.tryParse(trimmed);
        if (uri != null && uri.hasAuthority && uri.host.isNotEmpty) {
          return NetworkImage(trimmed);
        }
      } catch (_) {}
      return null;
    }

    // 3. Raw Base64 string fallback (e.g. AAIAB..., iVBOR..., etc.)
    try {
      final cleanBase64 = trimmed.replaceAll(RegExp(r'\s+'), '');
      if (cleanBase64.length > 20) {
        final bytes = base64Decode(cleanBase64);
        if (bytes.isNotEmpty) {
          return MemoryImage(bytes);
        }
      }
    } catch (_) {
      // Not a valid base64 payload, safely return null
    }

    return null;
  }

  /// List of ultra-high-resolution 3D Pixar / Snapchat Bitmoji character preset avatars.
  static const List<PresetAvatar> educationalPresets = [
    PresetAvatar(
      id: 'snap_boy_curly',
      titleArabic: 'طالب عصري كيرلي 👦',
      category: 'طالب',
      url: 'assets/avatars/snap_boy_curly.png',
    ),
    PresetAvatar(
      id: 'snap_girl_hijab',
      titleArabic: 'طالبة متألقة بالحجاب 🧕',
      category: 'طالب',
      url: 'assets/avatars/snap_girl_hijab.png',
    ),
    PresetAvatar(
      id: 'snap_student_star',
      titleArabic: 'خريج متفوق بالمرتبة الأولى 🎓',
      category: 'طالب',
      url: 'assets/avatars/snap_student_star.png',
    ),
    PresetAvatar(
      id: 'snap_girl_stylish',
      titleArabic: 'طالبة مبدعة وذكية 🎧',
      category: 'طالب',
      url: 'assets/avatars/snap_girl_stylish.png',
    ),
    PresetAvatar(
      id: 'snap_boy_glasses',
      titleArabic: 'طالب متفوق ونظارات 👓',
      category: 'طالب',
      url: 'assets/avatars/snap_boy_glasses.png',
    ),
    PresetAvatar(
      id: 'snap_teacher_male',
      titleArabic: 'أستاذ وموجه قدير 👨‍🏫',
      category: 'معلم',
      url: 'assets/avatars/snap_teacher_male.png',
    ),
    PresetAvatar(
      id: 'snap_teacher_female',
      titleArabic: 'أستاذة ومشرفة أكاديمية 👩‍🏫',
      category: 'معلم',
      url: 'assets/avatars/snap_teacher_female.png',
    ),
    PresetAvatar(
      id: 'snap_executive_leader',
      titleArabic: 'مدير المنظومة الأكاديمية 👨‍💼',
      category: 'إدارة',
      url: 'assets/avatars/snap_executive_leader.png',
    ),
    PresetAvatar(
      id: 'snap_doctor_scientist',
      titleArabic: 'باحث ومستكشف علمي 🔬',
      category: 'علوم',
      url: 'assets/avatars/snap_doctor_scientist.png',
    ),
    PresetAvatar(
      id: 'snap_artist_creative',
      titleArabic: 'فنان ومصمم مبدع 🎨',
      category: 'فنون',
      url: 'assets/avatars/snap_artist_creative.png',
    ),
    PresetAvatar(
      id: 'snap_athlete_sports',
      titleArabic: 'بطل رياضي وأنشطة 🏆',
      category: 'رياضة',
      url: 'assets/avatars/snap_athlete_sports.png',
    ),
    PresetAvatar(
      id: 'snap_cyber_hacker',
      titleArabic: 'مبرمج وخبير تكنولوجيا 💻',
      category: 'تكنولوجيا',
      url: 'assets/avatars/snap_cyber_hacker.png',
    ),
    PresetAvatar(
      id: 'snap_counselor_female',
      titleArabic: 'أخصائية إرشاد وتوجيه 📚',
      category: 'إرشاد',
      url: 'assets/avatars/snap_counselor_female.png',
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

  /// Uploads binary avatar bytes (e.g. from Canvas snapshot) to Supabase Storage
  /// or falls back to a base64 Data URI.
  static Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String filename,
    String? userId,
  }) async {
    if (bytes.isEmpty) return null;
    const mimeType = 'image/png';

    // Attempt 1: Upload to Supabase Storage 'avatars' bucket
    try {
      final client = Supabase.instance.client;
      final storagePath = 'profiles/${userId ?? "guest"}/$filename';

      await client.storage.from('avatars').uploadBinary(
        storagePath,
        bytes,
        fileOptions: const FileOptions(contentType: mimeType, upsert: true),
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
