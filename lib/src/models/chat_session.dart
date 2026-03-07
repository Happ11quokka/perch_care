/// 채팅 세션 모델 (서버 동기화용)
class ChatSession {
  final String id;
  final String? petId;
  final String title;
  final DateTime startedAt;
  final DateTime lastMessageAt;
  final int messageCount;

  const ChatSession({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.lastMessageAt,
    required this.messageCount,
    this.petId,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      petId: json['pet_id'] as String?,
      title: json['title'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      lastMessageAt: DateTime.parse(json['last_message_at'] as String),
      messageCount: json['message_count'] as int,
    );
  }
}
