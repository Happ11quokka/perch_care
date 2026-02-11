/// 챗봇 대화 메시지 역할
enum MessageRole { user, assistant }

/// 챗봇 대화 메시지 모델
class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });

  final MessageRole role;
  final String text;
  final DateTime timestamp;

  /// JSON에서 ChatMessage 생성
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// ChatMessage를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'text': text,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// 복사본 생성 (필드 업데이트 가능)
  ChatMessage copyWith({
    MessageRole? role,
    String? text,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
