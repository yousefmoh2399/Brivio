import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Announcement {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String author;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.author,
  });
}

class Message {
  final String id;
  final String sender;
  final String content;
  final DateTime timestamp;
  final bool isFromMe;

  Message({
    required this.id,
    required this.sender,
    required this.content,
    required this.timestamp,
    required this.isFromMe,
  });
}

class ParentCommsViewModel extends ChangeNotifier {
  List<Announcement> _announcements = [];
  List<Announcement> get announcements => _announcements;

  List<Message> _messages = [];
  List<Message> get messages => _messages;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  ParentCommsViewModel() {
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('notifications')
          .select('id, title, message, created_at')
          .order('created_at', ascending: false)
          .limit(20);

      final List<Announcement> list = [];
      for (final item in (res as List)) {
        final dtStr = item['created_at']?.toString();
        final dt = dtStr != null ? DateTime.tryParse(dtStr) ?? DateTime.now() : DateTime.now();
        list.add(
          Announcement(
            id: item['id'] as String,
            title: item['title'] as String? ?? 'إشعار من الإدارة',
            content: item['message'] as String? ?? '',
            date: dt,
            author: 'إدارة السنتر',
          ),
        );
      }
      _announcements = list;
      _messages = [];
    } catch (_) {
      _announcements = [];
      _messages = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;

    _messages.add(
      Message(
        id: DateTime.now().toString(),
        sender: 'ولي الأمر',
        content: text.trim(),
        timestamp: DateTime.now(),
        isFromMe: true,
      ),
    );
    notifyListeners();
  }
}
