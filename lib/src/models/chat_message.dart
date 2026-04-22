/// 챗봇 대화 메시지 역할
enum MessageRole { user, assistant }

/// 챗봇 대화 메시지 모델
class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.id,
    this.sessionId,
    this.imagePath,
  });

  final String? id;
  final String? sessionId;
  final MessageRole role;
  final String text;
  final DateTime timestamp;

  /// 첨부 이미지의 로컬 파일 경로 (멀티모달 입력). 세션 동안만 유효.
  final String? imagePath;

  /// JSON에서 ChatMessage 생성
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String?,
      sessionId: json['session_id'] as String?,
      role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      imagePath: json['image_path'] as String?,
    );
  }

  /// ChatMessage를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      if (imagePath != null) 'image_path': imagePath,
    };
  }

  /// 복사본 생성 (필드 업데이트 가능)
  ChatMessage copyWith({
    String? id,
    String? sessionId,
    MessageRole? role,
    String? text,
    DateTime? timestamp,
    String? imagePath,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
