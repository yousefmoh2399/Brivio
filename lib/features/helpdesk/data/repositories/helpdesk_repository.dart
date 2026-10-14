import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/support_ticket.dart';
import '../models/ticket_reply.dart';

class HelpdeskGroupOption {
  final String id;
  final String name;

  const HelpdeskGroupOption({required this.id, required this.name});

  factory HelpdeskGroupOption.fromGroup(Map<String, dynamic> group) {
    final name = [
      group['name']?.toString(),
      group['code']?.toString(),
    ].where((v) => v != null && v.trim().isNotEmpty).join(' - ');
    return HelpdeskGroupOption(
      id: group['id'].toString(),
      name: name.isEmpty ? 'Group' : name,
    );
  }
}

class HelpdeskRepository {
  final SupabaseClient _client;

  HelpdeskRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<List<SupportTicket>> getTickets() async {
    try {
      final response = await _client
          .from('support_tickets')
          .select()
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => SupportTicket.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      debugPrint('Helpdesk getTickets error: $e');
      return [];
    }
  }

  Future<List<HelpdeskGroupOption>> getAvailableGroups() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return const [];

      final groups = <String, HelpdeskGroupOption>{};

      Future<void> addGroupRows(List<dynamic> rows) async {
        for (final row in rows) {
          try {
            final map = Map<String, dynamic>.from(row as Map);
            final groupRaw = map['groups'] ?? map['group'];
            if (groupRaw is Map) {
              final option = HelpdeskGroupOption.fromGroup(
                Map<String, dynamic>.from(groupRaw),
              );
              groups[option.id] = option;
            }
          } catch (_) {}
        }
      }

      try {
        final student = await _client
            .from('students')
            .select('id')
            .eq('profile_id', user.id)
            .maybeSingle();
        if (student != null) {
          final rows = await _client
              .from('enrollments')
              .select('groups(id, name, code)')
              .eq('student_id', student['id'])
              .eq('status', 'active');
          await addGroupRows(rows as List<dynamic>);
        }
      } catch (_) {}

      try {
        final parent = await _client
            .from('parents')
            .select('id')
            .eq('profile_id', user.id)
            .maybeSingle();
        if (parent != null) {
          final links = await _client
              .from('parent_students')
              .select('student_id')
              .eq('parent_id', parent['id']);
          final studentIds = (links as List<dynamic>)
              .map((row) => (row as Map)['student_id']?.toString())
              .whereType<String>()
              .toList();
          if (studentIds.isNotEmpty) {
            final rows = await _client
                .from('enrollments')
                .select('groups(id, name, code)')
                .inFilter('student_id', studentIds)
                .eq('status', 'active');
            await addGroupRows(rows as List<dynamic>);
          }
        }
      } catch (_) {}

      try {
        final teacher = await _client
            .from('teachers')
            .select('id')
            .eq('profile_id', user.id)
            .maybeSingle();
        if (teacher != null) {
          final rows = await _client
              .from('group_teachers')
              .select('groups(id, name, code)')
              .eq('teacher_id', teacher['id']);
          await addGroupRows(rows as List<dynamic>);
        }
      } catch (_) {}

      return groups.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (_) {
      return const [];
    }
  }

  Future<SupportTicket> createTicket({
    required String subject,
    required String description,
    required String priority,
    String? groupId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final validGroupId = (groupId != null &&
            groupId.isNotEmpty &&
            RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(groupId))
        ? groupId
        : null;

    try {
      final response = await _client.rpc(
        'create_support_ticket',
        params: {
          'p_subject': subject,
          'p_description': description,
          'p_priority': priority,
          'p_group_id': validGroupId,
        },
      );

      return SupportTicket.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      debugPrint('create_support_ticket RPC failed, falling back to table: $e');
      final insertData = <String, dynamic>{
        'user_id': user.id,
        'subject': subject,
        'description': description,
        'priority': priority,
        'status': 'open',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (validGroupId != null) {
        insertData['group_id'] = validGroupId;
      }
      final response = await _client
          .from('support_tickets')
          .insert(insertData)
          .select()
          .single();
      return SupportTicket.fromJson(Map<String, dynamic>.from(response));
    }
  }

  Future<void> updateTicketStatus(String ticketId, String status) async {
    try {
      await _client.rpc(
        'update_support_ticket_status',
        params: {'p_ticket_id': ticketId, 'p_status': status},
      );
    } catch (e) {
      debugPrint('update_support_ticket_status RPC failed, falling back to table: $e');
      await _client
          .from('support_tickets')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', ticketId);
    }
  }

  Future<List<TicketReply>> getReplies(String ticketId) async {
    try {
      final response = await _client
          .from('ticket_replies')
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);
      return (response as List)
          .map((json) => TicketReply.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      debugPrint('Helpdesk getReplies error: $e');
      return [];
    }
  }

  Future<TicketReply> addReply(String ticketId, String message) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final response = await _client.rpc(
        'add_ticket_reply',
        params: {'p_ticket_id': ticketId, 'p_message': message},
      );

      return TicketReply.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      debugPrint('add_ticket_reply RPC failed, falling back to table: $e');
      final response = await _client
          .from('ticket_replies')
          .insert({
            'ticket_id': ticketId,
            'user_id': user.id,
            'message': message,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return TicketReply.fromJson(Map<String, dynamic>.from(response));
    }
  }
}
