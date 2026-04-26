import 'package:hive_flutter/hive_flutter.dart';

class ChatHistoryService {
  static const String _boxName = 'chat_history';
  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Future<void> saveChat(ChatSession session) async {
    await _box?.put(session.id, session.toJson());
  }

  List<ChatSession> getAllChats() {
    if (_box == null) return [];
    try {
      return _box!.values
          .map((e) {
            try {
              final map = Map<String, dynamic>.from(e as Map);
              return ChatSession.fromJson(map);
            } catch (err) {
              print('Error parsing chat session: $err');
              return null;
            }
          })
          .whereType<ChatSession>()
          .toList()
        ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    } catch (e) {
      print('Error getting all chats: $e');
      return [];
    }
  }

  Future<void> deleteChat(String id) async {
    await _box?.delete(id);
  }

  Future<void> clearAll() async {
    await _box?.clear();
  }
}

class ChatSession {
  final String id;
  final String title;
  final DateTime lastUpdated;
  final List<Map<String, dynamic>> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.lastUpdated,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'lastUpdated': lastUpdated.toIso8601String(),
        'messages': messages,
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    try {
      return ChatSession(
        id: json['id'] as String,
        title: json['title'] as String,
        lastUpdated: DateTime.parse(json['lastUpdated'] as String),
        messages: (json['messages'] as List)
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList(),
      );
    } catch (e) {
      print('Error parsing ChatSession: $e');
      rethrow;
    }
  }
}
