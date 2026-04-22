import 'dart:typed_data';

import '../health_check/health_check_service.dart';

/// 멀티모달 챗봇 전용 Vision 브릿지.
/// `/ai/vision/analyze` 결과를 사용자 질문과 합쳐 서버 전송용
/// augmented prompt 로 조립한다. 챗 서버에 네이티브 멀티파트가
/// 없을 때의 MVP 경로.
class VisionBridgeService {
  VisionBridgeService._(this._service);

  static final instance = VisionBridgeService._(HealthCheckService.instance);

  /// 테스트용 팩토리 — 임의의 [HealthCheckService] 를 주입한다.
  factory VisionBridgeService.forTest(HealthCheckService service) =>
      VisionBridgeService._(service);

  final HealthCheckService _service;

  /// 이미지를 전송해 분석 요약과 augmented prompt 를 반환한다.
  /// 네트워크·서버 오류는 [VisionBridgeException] 으로 감싸 던진다.
  Future<VisionBridgeResult> analyze({
    required Uint8List imageBytes,
    required String fileName,
    String? userText,
    String? language,
  }) async {
    final trimmedNote =
        (userText != null && userText.trim().isNotEmpty) ? userText.trim() : null;
    try {
      final raw = await _service.analyzeFood(
        imageBytes: imageBytes,
        fileName: fileName,
        notes: trimmedNote,
        language: language,
      );
      final summary = _extractSummary(raw['result']);
      return VisionBridgeResult(
        summary: summary,
        confidence: (raw['confidence_score'] as num?)?.toDouble(),
        status: raw['status'] as String?,
        augmentedPrompt: _compose(
          summary: summary,
          confidence: (raw['confidence_score'] as num?)?.toDouble(),
          status: raw['status'] as String?,
          userText: trimmedNote ?? '',
        ),
      );
    } on VisionBridgeException {
      rethrow;
    } catch (e) {
      throw VisionBridgeException('$e');
    }
  }

  String _compose({
    required String summary,
    required double? confidence,
    required String? status,
    required String userText,
  }) {
    final b = StringBuffer();
    b.writeln('[첨부 이미지 분석]');
    b.writeln(summary);
    if (confidence != null || status != null) {
      final meta = <String>[];
      if (confidence != null) {
        meta.add('confidence ${confidence.toStringAsFixed(2)}');
      }
      if (status != null) meta.add('status $status');
      b.writeln('(${meta.join(', ')})');
    }
    if (userText.isNotEmpty) {
      b.writeln();
      b.writeln('[사용자 질문]');
      b.write(userText);
    }
    return b.toString().trimRight();
  }

  String _extractSummary(dynamic result) {
    if (result is! Map<String, dynamic>) return '분석 결과를 읽을 수 없음';

    final lines = <String>[];

    final overall = result['overall_status'] ?? result['overall_diet_assessment'];
    if (overall is String && overall.trim().isNotEmpty) {
      lines.add(overall.trim());
    }

    final findings = result['findings'];
    if (findings is List && findings.isNotEmpty) {
      for (final f in findings.take(5)) {
        final line = _findingLine(f);
        if (line != null) lines.add('• $line');
      }
    }

    final items = result['identified_items'];
    if (items is List && items.isNotEmpty) {
      final names = items
          .map((i) {
            if (i is String) return i;
            if (i is Map) return i['name'] ?? i['label'];
            return null;
          })
          .whereType<String>()
          .take(5)
          .toList();
      if (names.isNotEmpty) lines.add('식별: ${names.join(', ')}');
    }

    final balance = result['nutrition_balance'];
    if (balance is String && balance.trim().isNotEmpty) {
      lines.add('영양 균형: ${balance.trim()}');
    }

    return lines.isEmpty ? '분석 결과 요약 없음' : lines.join('\n');
  }

  String? _findingLine(dynamic f) {
    if (f is String) return f.trim().isEmpty ? null : f.trim();
    if (f is Map) {
      final desc = f['description'] ?? f['finding'] ?? f['name'] ?? f['label'];
      if (desc is String && desc.trim().isNotEmpty) return desc.trim();
    }
    return null;
  }
}

class VisionBridgeResult {
  const VisionBridgeResult({
    required this.augmentedPrompt,
    required this.summary,
    this.confidence,
    this.status,
  });

  /// 챗 서버로 실제 전송할 최종 프롬프트 (vision 요약 + 사용자 질문).
  final String augmentedPrompt;

  /// Vision 분석 요약만 뽑아낸 문자열 (analytics / 로그용).
  final String summary;

  final double? confidence;
  final String? status;
}

class VisionBridgeException implements Exception {
  const VisionBridgeException(this.message);
  final String message;
  @override
  String toString() => 'VisionBridgeException: $message';
}
