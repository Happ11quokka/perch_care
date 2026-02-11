import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/chat_message.dart';

/// 챗봇 대화 내용 로컬 저장 서비스
class ChatStorageService {
  static final ChatStorageService instance = ChatStorageService._();

  ChatStorageService._();

  static const _keyPrefix = 'chat_history_';
  static const _globalKey = '${_keyPrefix}global';
  static const _maxMessages = 100; // 최대 저장 메시지 수

  SharedPreferences? _prefs;

  /// SharedPreferences 초기화 (lazy)
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 저장 키 생성
  String _getKey(String? petId) {
    if (petId == null || petId.isEmpty) {
      return _globalKey;
    }
    return '$_keyPrefix$petId';
  }

  /// 대화 내용 불러오기
  Future<List<ChatMessage>> loadMessages(String? petId) async {
    try {
      final prefs = await _getPrefs();
      final key = _getKey(petId);
      final jsonString = prefs.getString(key);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // 파싱 실패 시 빈 리스트 반환
      return [];
    }
  }

  /// 대화 내용 저장
  Future<void> saveMessages(String? petId, List<ChatMessage> messages) async {
    try {
      final prefs = await _getPrefs();
      final key = _getKey(petId);

      // 최대 메시지 수 제한
      final trimmedMessages = messages.length > _maxMessages
          ? messages.sublist(messages.length - _maxMessages)
          : messages;

      final jsonList = trimmedMessages.map((m) => m.toJson()).toList();
      final jsonString = json.encode(jsonList);

      await prefs.setString(key, jsonString);
    } catch (e) {
      // 저장 실패 시 무시 (앱 동작에 영향 없음)
    }
  }

  /// 특정 펫의 대화 내용 삭제
  Future<void> clearMessages(String? petId) async {
    try {
      final prefs = await _getPrefs();
      final key = _getKey(petId);
      await prefs.remove(key);
    } catch (e) {
      // 삭제 실패 시 무시
    }
  }

  /// 모든 대화 내용 삭제 (디버깅/설정용)
  Future<void> clearAllMessages() async {
    try {
      final prefs = await _getPrefs();
      final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      // 삭제 실패 시 무시
    }
  }
}
