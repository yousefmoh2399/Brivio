import 'package:supabase_flutter/supabase_flutter.dart';

class ParentRepository {
  final SupabaseClient _supabaseClient;

  ParentRepository({SupabaseClient? supabaseClient})
    : _supabaseClient = supabaseClient ?? Supabase.instance.client;

  Future<void> linkChildWithId(String studentIdentifier) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('المستخدم غير مسجل الدخول');

    // 1. Resolve parent record ID from profile_id
    final parentRow = await _supabaseClient
        .from('parents')
        .select('id')
        .eq('profile_id', currentUserId)
        .maybeSingle();

    String parentId;
    if (parentRow != null && parentRow['id'] != null) {
      parentId = parentRow['id'] as String;
    } else {
      final newParent = await _supabaseClient
          .from('parents')
          .insert({'profile_id': currentUserId, 'status': 'active'})
          .select('id')
          .single();
      parentId = newParent['id'] as String;
    }

    // 2. Resolve actual student ID if user provided student_code
    final query = studentIdentifier.trim();
    String actualStudentId = query;
    try {
      final stu = await _supabaseClient
          .from('students')
          .select('id')
          .or('id.eq.$query,student_code.eq.$query')
          .maybeSingle();
      if (stu != null && stu['id'] != null) {
        actualStudentId = stu['id'] as String;
      }
    } catch (_) {
      // Fallback to query as-is
    }

    // 3. Link parent to student
    await _supabaseClient.from('parent_students').upsert({
      'parent_id': parentId,
      'student_id': actualStudentId,
      'relationship_type': 'guardian',
      'is_primary': false,
    });
  }

  Future<List<Map<String, dynamic>>> getLinkedChildren() async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('المستخدم غير مسجل الدخول');

    final parentRow = await _supabaseClient
        .from('parents')
        .select('id')
        .eq('profile_id', currentUserId)
        .maybeSingle();

    if (parentRow == null) return [];
    final parentId = parentRow['id'] as String;

    final response = await _supabaseClient
        .from('parent_students')
        .select('*, student:student_id(*, profiles(*))')
        .eq('parent_id', parentId);

    return List<Map<String, dynamic>>.from(response);
  }
}
