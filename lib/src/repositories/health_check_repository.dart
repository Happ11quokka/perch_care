import 'dart:typed_data';

import '../services/health_check/health_check_service.dart';
import '../services/storage/health_check_storage_service.dart';
import '../services/storage/local_image_storage_service.dart';

/// 건강체크(AI 비전 분석) Repository.
///
/// ViewModel/Screen은 이 인터페이스만 보고 `HealthCheckService` /
/// `HealthCheckStorageService` / `LocalImageStorageService`를 직접 호출하지 않는다.
/// 기존 화면 코드(health_check_history_screen.dart, health_check_result_screen.dart)에
/// 흩어져 있던 "서버우선 조회+로컬 폴백", "로컬+이미지+서버 삭제(best-effort)",
/// "로컬 미러 저장(레코드+이미지)" 오케스트레이션을 캡슐화한다.
abstract class HealthCheckRepository {
  /// 펫 기반 비전 분석 요청 (full_body/part_specific/droppings 등).
  Future<Map<String, dynamic>> analyze({
    required String petId,
    required String mode,
    String? part,
    String? notes,
    String? language,
    required Uint8List imageBytes,
    required String fileName,
  });

  /// 펫 없이 food 모드 분석 요청.
  Future<Map<String, dynamic>> analyzeFood({
    String? notes,
    String? language,
    required Uint8List imageBytes,
    required String fileName,
  });

  /// 서버 우선 조회 + 로컬 캐시 갱신. 서버 실패 시 로컬 캐시로 폴백.
  Future<List<HealthCheckRecord>> loadHistory(String petId);

  /// 로컬 레코드 + 로컬 이미지 삭제 + 서버 삭제(best-effort, 실패해도 무시).
  Future<void> delete(HealthCheckRecord record);

  /// 분석 결과를 로컬에 미러링 저장 (레코드 + 이미지).
  Future<void> saveLocalMirror(
    HealthCheckRecord record,
    Uint8List? imageBytes,
  );
}

class HealthCheckRepositoryImpl implements HealthCheckRepository {
  HealthCheckRepositoryImpl({
    HealthCheckService? service,
    HealthCheckStorageService? storage,
    LocalImageStorageService? imageStorage,
  })  : _service = service ?? HealthCheckService.instance,
        _storage = storage ?? HealthCheckStorageService.instance,
        _imageStorage = imageStorage ?? LocalImageStorageService.instance;

  final HealthCheckService _service;
  final HealthCheckStorageService _storage;
  final LocalImageStorageService _imageStorage;

  @override
  Future<Map<String, dynamic>> analyze({
    required String petId,
    required String mode,
    String? part,
    String? notes,
    String? language,
    required Uint8List imageBytes,
    required String fileName,
  }) {
    return _service.analyzeImage(
      petId: petId,
      mode: mode,
      part: part,
      notes: notes,
      language: language,
      imageBytes: imageBytes,
      fileName: fileName,
    );
  }

  @override
  Future<Map<String, dynamic>> analyzeFood({
    String? notes,
    String? language,
    required Uint8List imageBytes,
    required String fileName,
  }) {
    return _service.analyzeFood(
      notes: notes,
      language: language,
      imageBytes: imageBytes,
      fileName: fileName,
    );
  }

  /// NOTE (서버 GET 1회 vs 2회): 기존 화면(health_check_history_screen.dart L54-74)은
  /// `fetchFromServer`(응답을 그대로 화면에 표시)와 `syncWithServer`(내부적으로
  /// fetchFromServer를 다시 호출해 로컬 캐시를 덮어씀)를 같은 try 블록 안에서 순서대로
  /// 호출한다 — 서버 GET 2회. `syncWithServer`는 "받아온 리스트를 캐시에 반영"하는 게
  /// 아니라 "다시 fetch해서 캐시에 반영"하는 구조라서, 이미 받아온 serverRecords를
  /// 재사용해 1회 GET으로 합치려면 HealthCheckStorageService에 "주어진 리스트로 캐시만
  /// 덮어쓰는" 메서드를 새로 추가해야 한다. 이번 작업은 Repository 레이어 신설이 목적이라
  /// storage 서비스 변경까지 스코프를 넓히지 않고, 화면의 기존 2-GET 시퀀스(및 두 호출이
  /// 같은 catch로 묶여 폴백되는 동작)를 그대로 이전한다. 1-GET 최적화는 후속 작업으로 남긴다.
  @override
  Future<List<HealthCheckRecord>> loadHistory(String petId) async {
    try {
      final serverRecords = await _storage.fetchFromServer(petId);
      await _storage.syncWithServer(petId);
      return serverRecords;
    } catch (_) {
      return _storage.getRecords(petId);
    }
  }

  @override
  Future<void> delete(HealthCheckRecord record) async {
    await _storage.deleteRecord(record.petId, record.id);
    await _imageStorage.deleteImage(
      ownerType: ImageOwnerType.healthCheck,
      ownerId: record.id,
    );
    // 서버 삭제는 best-effort — 실패해도 로컬 삭제는 이미 완료된 상태이므로 무시.
    final petId = record.petId;
    if (petId != null) {
      try {
        await _service.deleteHealthCheck(record.id, petId: petId);
      } catch (_) {
        // 기존 화면(health_check_history_screen.dart L164-171)과 동일하게 무시.
      }
    }
  }

  @override
  Future<void> saveLocalMirror(
    HealthCheckRecord record,
    Uint8List? imageBytes,
  ) async {
    await _storage.saveRecord(record);
    if (imageBytes != null) {
      await _imageStorage.saveImage(
        ownerType: ImageOwnerType.healthCheck,
        ownerId: record.id,
        imageBytes: imageBytes,
      );
    }
  }
}
