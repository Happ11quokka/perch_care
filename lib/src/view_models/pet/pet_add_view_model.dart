import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pet.dart';
import '../../models/weight_record.dart';
import '../../providers/repository_providers.dart';
import '../../repositories/pet_repository.dart';
import '../../services/analytics/analytics_service.dart';
import '../../services/breed/breed_service.dart';
import '../../services/storage/local_image_storage_service.dart';
import '../../services/sync/sync_service.dart';
import '../../services/weight/weight_service.dart';
import 'pet_list_view_model.dart';
import 'active_pet_view_model.dart';

/// 수정 진입 시 화면이 필요한 기존 펫 데이터.
class PetEditData {
  final Pet pet;
  final String? breedDisplayName;
  final Uint8List? imageBytes;

  const PetEditData({
    required this.pet,
    this.breedDisplayName,
    this.imageBytes,
  });
}

/// 저장 시 화면이 ViewModel에 전달하는 폼 입력 DTO.
class PetFormInput {
  final String name;
  final String? species; // 품종 미선택 시 "기타" 텍스트
  final String? breedId;
  final String? breedDisplayName;
  final String? gender;
  final String? growthStage;
  final double? weight; // grams
  final DateTime? birthDate;
  final DateTime? adoptionDate;

  const PetFormInput({
    required this.name,
    this.species,
    this.breedId,
    this.breedDisplayName,
    this.gender,
    this.growthStage,
    this.weight,
    this.birthDate,
    this.adoptionDate,
  });
}

/// PetAddScreen의 로드/저장 흐름 ViewModel.
///
/// Form input(TextEditingController 등)은 View가 관리하고, ViewModel은 비동기
/// 비즈니스 로직(서버 CRUD, 초기 체중 기록 + SyncService enqueue, 로컬 이미지
/// 저장, 로컬 캐시 upsert)만 담당한다.
class PetAddViewModel extends AsyncNotifier<void> {
  PetRepository get _repo => ref.read(petRepositoryProvider);

  @override
  Future<void> build() async {}

  /// 기존 펫 로드 (수정 모드 진입 시 호출).
  /// - pet 엔티티, breed 표시명, 로컬 저장 이미지 바이트를 함께 반환.
  Future<PetEditData?> loadExistingPet(String petId) async {
    final pet = await _repo.getPetById(petId);
    if (pet == null) return null;

    String? breedDisplay = pet.breed;
    if (pet.breedId != null) {
      final breed = await BreedService.instance.fetchBreedById(pet.breedId!);
      if (breed != null) breedDisplay = breed.displayName;
    }

    final imageBytes = await LocalImageStorageService.instance.getImage(
      ownerType: ImageOwnerType.petProfile,
      ownerId: pet.id,
    );

    return PetEditData(
      pet: pet,
      breedDisplayName: breedDisplay,
      imageBytes: imageBytes,
    );
  }

  /// 폼 저장 — 생성/수정 분기 + (신규에 한해) 초기 체중 저장 + 이미지 저장 + 로컬 캐시.
  ///
  /// 관련 ViewModel(`petListViewModelProvider`, `activePetViewModelProvider`)은
  /// 자동 invalidate되어 다음 watch 시 새로 로드된다.
  ///
  /// Returns: 저장된 Pet 엔티티 (서버 응답 기준).
  Future<Pet> save({
    required PetFormInput input,
    File? newImage,
    Pet? existingPet,
  }) async {
    state = const AsyncLoading<void>();

    try {
      // 품종 선택 여부에 따라 species/breed 값 결정
      final effectiveSpecies = input.breedId != null
          ? 'bird'
          : (input.species?.isNotEmpty == true
              ? input.species!
              : 'default');
      final effectiveBreed = input.breedId != null
          ? input.breedDisplayName
          : (input.species?.isNotEmpty == true ? input.species : null);

      final Pet savedPet;
      if (existingPet != null) {
        savedPet = await _repo.updatePet(
          petId: existingPet.id,
          name: input.name,
          species: effectiveSpecies,
          breed: effectiveBreed,
          breedId: input.breedId,
          updateBreedFields: true,
          birthDate: input.birthDate,
          gender: input.gender,
          growthStage: input.growthStage,
          weight: input.weight,
          adoptionDate: input.adoptionDate,
        );
      } else {
        savedPet = await _repo.createPet(
          name: input.name,
          species: effectiveSpecies,
          breed: effectiveBreed,
          breedId: input.breedId,
          birthDate: input.birthDate,
          gender: input.gender,
          growthStage: input.growthStage,
          weight: input.weight,
          adoptionDate: input.adoptionDate,
        );
      }

      // 신규 펫이고 초기 체중이 제공된 경우 WeightRecord 생성
      // TODO(Phase 3): WeightRepository로 이관 예정 — 지금은 기존 WeightService 직접 사용.
      if (existingPet == null && input.weight != null) {
        await _saveInitialWeight(savedPet.id, input.weight!);
      }

      // 이미지 저장 (SQLite)
      if (newImage != null) {
        final bytes = await newImage.readAsBytes();
        await LocalImageStorageService.instance.saveImage(
          ownerType: ImageOwnerType.petProfile,
          ownerId: savedPet.id,
          imageBytes: bytes,
        );
      }

      // 로컬 캐시 upsert (+ 활성 펫 지정)
      await _repo.upsertLocalCache(savedPet, setActive: true);

      // 신규 등록 analytics
      if (existingPet == null) {
        AnalyticsService.instance.logPetRegistered(
          input.species ?? input.breedDisplayName ?? '',
        );
      }

      // 연관 ViewModel refresh → 다음 watch 시 새로 로드
      ref.invalidate(petListViewModelProvider);
      ref.invalidate(activePetViewModelProvider);

      state = const AsyncData(null);
      return savedPet;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      rethrow;
    }
  }

  Future<void> _saveInitialWeight(String petId, double weight) async {
    try {
      final weightService = WeightService.instance;
      final now = DateTime.now();
      final dateKey = SyncService.dateKey(now);
      final entityId = SyncService.weightEntityId(
        recordedHour: now.hour,
        recordedMinute: now.minute,
      );
      final record = WeightRecord(
        petId: petId,
        date: now,
        weight: weight,
        recordedHour: now.hour,
        recordedMinute: now.minute,
      );
      final localRecord = await weightService.saveLocalWeightRecord(record);
      try {
        await weightService.saveWeightRecord(localRecord);
        await SyncService.instance.markMutationSynced(
          type: 'weight',
          petId: petId,
          date: dateKey,
          entityId: entityId,
        );
        await SyncService.instance.drainAfterSuccess();
      } catch (e) {
        debugPrint('[PetAddViewModel] Backend weight save failed: $e');
        await SyncService.instance.enqueue(
          SyncItem(
            type: 'weight',
            petId: petId,
            date: dateKey,
            entityId: entityId,
            payload: {
              'localId': localRecord.id,
              'weight': weight,
              'recordedHour': now.hour,
              'recordedMinute': now.minute,
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('[PetAddViewModel] Initial weight record failed: $e');
    }
  }
}

final petAddViewModelProvider =
    AsyncNotifierProvider<PetAddViewModel, void>(PetAddViewModel.new);
