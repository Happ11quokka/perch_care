import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PetLocalCacheService {
  PetLocalCacheService._();
  static final instance = PetLocalCacheService._();

  static const String _petsKey = 'local_pet_profiles';
  static const String _activePetIdKey = 'local_active_pet_id';

  // 인메모리 캐시 — SharedPreferences 접근 최소화
  List<PetProfileCache>? _cachedPets;
  String? _cachedActivePetId;
  bool _activePetIdLoaded = false;

  Future<List<PetProfileCache>> getPets() async {
    if (_cachedPets != null) return List.of(_cachedPets!);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_petsKey);
    if (raw == null || raw.isEmpty) {
      _cachedPets = [];
      return [];
    }
    final list = jsonDecode(raw) as List<dynamic>;
    _cachedPets = list
        .map((item) => PetProfileCache.fromJson(item as Map<String, dynamic>))
        .toList();
    return List.of(_cachedPets!);
  }

  Future<PetProfileCache?> getActivePet() async {
    final pets = await getPets();
    if (pets.isEmpty) return null;
    if (!_activePetIdLoaded) {
      final prefs = await SharedPreferences.getInstance();
      _cachedActivePetId = prefs.getString(_activePetIdKey);
      _activePetIdLoaded = true;
    }
    if (_cachedActivePetId == null) return pets.first;
    for (final pet in pets) {
      if (pet.id == _cachedActivePetId) return pet;
    }
    return pets.first;
  }

  Future<bool> hasPets() async {
    final pets = await getPets();
    return pets.isNotEmpty;
  }

  Future<void> setActivePetId(String petId) async {
    _cachedActivePetId = petId;
    _activePetIdLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activePetIdKey, petId);
  }

  Future<void> upsertPet(
    PetProfileCache pet, {
    bool setActive = true,
  }) async {
    final pets = await getPets();
    final existingIndex = pets.indexWhere((item) => item.id == pet.id);
    if (existingIndex == -1) {
      pets.add(pet);
    } else {
      pets[existingIndex] = pet;
    }
    _cachedPets = pets;
    await _savePets(pets);
    if (setActive) {
      await setActivePetId(pet.id);
    }
  }

  /// 특정 펫 삭제
  Future<void> removePet(String petId) async {
    final pets = await getPets();
    pets.removeWhere((pet) => pet.id == petId);
    _cachedPets = pets;
    await _savePets(pets);

    // 활성 펫 ID 확인 (캐시 또는 SharedPreferences)
    if (!_activePetIdLoaded) {
      final prefs = await SharedPreferences.getInstance();
      _cachedActivePetId = prefs.getString(_activePetIdKey);
      _activePetIdLoaded = true;
    }

    if (_cachedActivePetId == petId) {
      if (pets.isNotEmpty) {
        await setActivePetId(pets.first.id);
      } else {
        _cachedActivePetId = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_activePetIdKey);
      }
    }
  }

  /// 모든 로컬 캐시 삭제
  Future<void> clearAll() async {
    _cachedPets = null;
    _cachedActivePetId = null;
    _activePetIdLoaded = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_petsKey);
    await prefs.remove(_activePetIdKey);
  }

  Future<void> _savePets(List<PetProfileCache> pets) async {
    final prefs = await SharedPreferences.getInstance();
    final data = pets.map((pet) => pet.toJson()).toList();
    await prefs.setString(_petsKey, jsonEncode(data));
  }
}

class PetProfileCache {
  final String id;
  final String name;
  final String? species;
  final String? gender;
  final DateTime? birthDate;

  const PetProfileCache({
    required this.id,
    required this.name,
    this.species,
    this.gender,
    this.birthDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (species != null) 'species': species,
      if (gender != null) 'gender': gender,
      if (birthDate != null)
        'birthDate': birthDate!.toIso8601String().split('T').first,
    };
  }

  factory PetProfileCache.fromJson(Map<String, dynamic> json) {
    return PetProfileCache(
      id: json['id'] as String,
      name: json['name'] as String,
      species: json['species'] as String?,
      gender: json['gender'] as String?,
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'] as String)
          : null,
    );
  }
}
