# 챗봇 대화 내역 로컬 저장 기능 구현

**날짜**: 2026-02-11
**관련 파일**:
- [lib/src/models/chat_message.dart](../../lib/src/models/chat_message.dart) (신규)
- [lib/src/services/storage/chat_storage_service.dart](../../lib/src/services/storage/chat_storage_service.dart) (신규)
- [lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart](../../lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart) (수정)

## 문제

AI Encyclopedia(챗봇) 화면에서 대화 내용이 메모리에만 저장되어 있어서:
1. 앱을 종료하면 모든 대화 내역이 사라짐
2. 화면을 나갔다 들어와도 대화가 초기화됨
3. 사용자가 이전 대화를 참조할 수 없음

## 해결 방안

SharedPreferences를 사용하여 대화 내역을 JSON으로 직렬화하여 로컬에 저장.

### 구현 특징

| 기능 | 설명 |
|------|------|
| 펫별 대화 분리 | 각 펫마다 독립적인 대화 내역 저장 (`chat_history_<petId>`) |
| 자동 저장 | AI 응답 성공 시 자동으로 저장 |
| 자동 로드 | 화면 진입 시 저장된 대화 자동 로드 |
| 삭제 기능 | AppBar 메뉴에서 대화 내역 삭제 가능 |
| 메시지 제한 | 최대 100개 메시지 저장 (50 왕복 대화) |

## 구현 내용

### 1. ChatMessage 모델 생성

기존 `_Message` 클래스를 공개 모델로 분리하고 JSON 직렬화 지원 추가.

```dart
// lib/src/models/chat_message.dart
enum MessageRole { user, assistant }

class ChatMessage {
  final MessageRole role;
  final String text;
  final DateTime timestamp;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'text': text,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
```

### 2. ChatStorageService 생성

SharedPreferences 기반 싱글톤 서비스로 대화 저장/로드/삭제 기능 제공.

```dart
// lib/src/services/storage/chat_storage_service.dart
class ChatStorageService {
  static final ChatStorageService instance = ChatStorageService._();

  static const _keyPrefix = 'chat_history_';
  static const _globalKey = '${_keyPrefix}global';
  static const _maxMessages = 100;

  String _getKey(String? petId) {
    if (petId == null || petId.isEmpty) {
      return _globalKey;
    }
    return '$_keyPrefix$petId';
  }

  Future<List<ChatMessage>> loadMessages(String? petId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_getKey(petId));
    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((item) => ChatMessage.fromJson(item)).toList();
  }

  Future<void> saveMessages(String? petId, List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    // 최대 메시지 수 제한
    final trimmed = messages.length > _maxMessages
        ? messages.sublist(messages.length - _maxMessages)
        : messages;

    await prefs.setString(_getKey(petId), json.encode(trimmed.map((m) => m.toJson()).toList()));
  }

  Future<void> clearMessages(String? petId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getKey(petId));
  }
}
```

### 3. AI Encyclopedia 화면 수정

#### 주요 변경사항

1. **모델 교체**: `_Message` → `ChatMessage`
2. **서비스 연동**: `ChatStorageService` 사용
3. **초기화 로직**: 화면 진입 시 펫 로드 후 대화 로드
4. **자동 저장**: AI 응답 성공 시 `_saveMessages()` 호출
5. **삭제 UI**: AppBar에 PopupMenuButton 추가

```dart
// 초기화
Future<void> _initializeChat() async {
  await _loadActivePet();
  await _loadMessages();
}

// AI 응답 성공 시 저장
try {
  final answer = await _aiService.ask(...);
  setState(() {
    _messages[_messages.length - 1] = _messages.last.copyWith(text: answer);
  });
  await _saveMessages(); // 자동 저장
} catch (e) {
  // 에러 처리
}

// AppBar 삭제 메뉴
actions: [
  PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert),
    onSelected: (value) {
      if (value == 'clear') _clearMessages();
    },
    itemBuilder: (context) => [
      const PopupMenuItem(
        value: 'clear',
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 20),
            SizedBox(width: 8),
            Text('대화 내역 삭제'),
          ],
        ),
      ),
    ],
  ),
],
```

## 저장 구조

```
SharedPreferences
├── chat_history_global          # 펫 미선택 시 대화
├── chat_history_<pet1_id>       # 펫1의 대화
├── chat_history_<pet2_id>       # 펫2의 대화
└── ...
```

각 키의 값은 JSON 배열:
```json
[
  {
    "role": "user",
    "text": "앵무새 털갈이 시기는?",
    "timestamp": "2026-02-11T14:30:00.000"
  },
  {
    "role": "assistant",
    "text": "앵무새의 털갈이는 보통 1년에 1~2회...",
    "timestamp": "2026-02-11T14:30:05.000"
  }
]
```

## 사용자 흐름

```
앱 실행 → 챗봇 진입 → 저장된 대화 자동 로드
                ↓
         대화 진행 → AI 응답 성공 시 자동 저장
                ↓
         앱 종료 후 재실행 → 대화 유지됨 ✅
                ↓
         (선택) 점 3개 메뉴 → 대화 내역 삭제
```

## 검증 방법

1. 앱 실행 → 챗봇에서 대화 진행
2. 앱 완전 종료 (슬라이드 종료)
3. 앱 재실행 → 챗봇 진입
4. **이전 대화가 유지되는지 확인** ✅
5. 점 3개 메뉴 → "대화 내역 삭제" 클릭
6. **대화가 초기화되는지 확인** ✅

## 향후 개선 가능 사항

- [ ] 펫 전환 시 실시간으로 해당 펫의 대화 로드 (현재는 화면 재진입 필요)
- [ ] 대화 내역 내보내기/공유 기능
- [ ] 대화 검색 기능
- [ ] 서버 동기화 (클라우드 백업)

## 핵심 포인트

- **로컬 저장**: SharedPreferences 사용으로 간단하고 안정적
- **펫별 분리**: 여러 펫을 키우는 사용자도 각 펫에 맞는 대화 유지
- **자동 처리**: 사용자가 저장 버튼을 누를 필요 없이 자동 저장/로드
- **용량 관리**: 최대 100개 메시지 제한으로 저장 공간 관리
