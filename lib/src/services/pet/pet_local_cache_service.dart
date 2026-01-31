import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PetLocalCacheService {
  PetLocalCacheService._();
  static final instance = PetLocalCacheService._();

  static const String _petsKey = 'local_pet_profiles';
  static const String _activePetIdKey = 'local_active_pet_id';

  Future<List<PetProfileCache>> getPets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_petsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => PetProfileCache.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<PetProfileCache?> getActivePet() async {
    final pets = await getPets();
    if (pets.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activePetIdKey);
    if (activeId == null) return pets.first;
    for (final pet in pets) {
      if (pet.id == activeId) {
        return pet;
      }
    }
    return pets.first;
  }

  Future<bool> hasPets() async {
    final pets = await getPets();
    return pets.isNotEmpty;
  }

  Future<void> setActivePetId(String petId) async {
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
    await _savePets(pets);
    if (setActive) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activePetIdKey, pet.id);
    }
  }

  /// 모든 로컬 캐시 삭제
  Future<void> clearAll() async {
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
