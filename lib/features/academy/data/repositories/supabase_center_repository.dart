import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client_wrapper.dart';
import '../../domain/models/educational_center.dart';

class SupabaseCenterRepository {
  final SupabaseClientWrapper _clientWrapper;

  SupabaseCenterRepository(this._clientWrapper);

  SupabaseClient get _client => _clientWrapper.client;

  /// Register a brand new Educational Center (Self-Service Onboarding)
  Future<Map<String, dynamic>> registerCenter({
    required String centerName,
    required String adminName,
    required String phoneNumber,
    required String governorate,
    String? userId,
  }) async {
    final response = await _client.rpc('register_educational_center', params: {
      'p_center_name': centerName,
      'p_admin_name': adminName,
      'p_phone_number': phoneNumber,
      'p_governorate': governorate,
      if (userId != null && userId.isNotEmpty) 'p_user_id': userId,
    });

    if (response == null) {
      throw Exception('Failed to register educational center.');
    }

    return Map<String, dynamic>.from(response as Map);
  }

  /// Fetch all centers the current authenticated user belongs to
  Future<List<UserCenterMembership>> fetchUserCenters() async {
    final response = await _client.rpc('get_user_centers');
    if (response == null) return [];

    final list = List<dynamic>.from(response as List);
    return list
        .map((item) => UserCenterMembership.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Switch the active center for users with memberships in multiple centers
  Future<Map<String, dynamic>> switchActiveCenter(String centerId) async {
    final response = await _client.rpc('switch_active_center', params: {
      'p_center_id': centerId,
    });

    if (response == null) {
      throw Exception('Failed to switch center.');
    }

    return Map<String, dynamic>.from(response as Map);
  }

  /// Link two centers together via code (Federation / Partnership)
  Future<Map<String, dynamic>> linkCentersByCode({
    required String targetCenterCode,
    String? notes,
  }) async {
    final response = await _client.rpc('link_centers_by_code', params: {
      'p_target_center_code': targetCenterCode,
      if (notes != null) 'p_notes': notes,
    });

    if (response == null) {
      throw Exception('Failed to link centers.');
    }

    return Map<String, dynamic>.from(response as Map);
  }

  /// Fetch all active and pending partnerships for the current center
  Future<List<CenterPartnership>> fetchPartnerships() async {
    final response = await _client.rpc('get_center_partnerships');
    if (response == null) return [];

    final list = List<dynamic>.from(response as List);
    return list
        .map(
          (item) => CenterPartnership.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  /// Respond to a partnership request (approved, rejected, terminated)
  Future<Map<String, dynamic>> respondToPartnership({
    required String partnershipId,
    required String action, // 'approved', 'rejected', 'terminated'
  }) async {
    final response = await _client.rpc('respond_to_center_partnership', params: {
      'p_partnership_id': partnershipId,
      'p_action': action,
    });

    if (response == null) {
      throw Exception('Failed to respond to partnership.');
    }

    return Map<String, dynamic>.from(response as Map);
  }

  /// Join a center as a student or teacher using the center's unique code
  Future<Map<String, dynamic>> joinCenterByCode(String centerCode) async {
    final response = await _client.rpc('join_center_by_code', params: {
      'p_center_code': centerCode,
    });

    if (response == null) {
      throw Exception('Failed to join center.');
    }

    return Map<String, dynamic>.from(response as Map);
  }

  /// Fetch current active center statistics and overview
  Future<CenterStats> fetchCenterStats() async {
    final response = await _client.rpc('get_current_center_stats');
    if (response == null) {
      throw Exception('Failed to load center statistics.');
    }

    return CenterStats.fromJson(Map<String, dynamic>.from(response as Map));
  }
}
