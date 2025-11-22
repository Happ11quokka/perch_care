import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/pet.dart';

/// 반려동물 CRUD 서비스
class PetService {
  PetService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// 내 반려동물 목록 조회
  Future<List<Pet>> getMyPets() async {
    if (_userId == null) throw Exception('User not logged in');

    final response = await _client
        .from('pets')
        .select()
        .eq('user_id', _userId!)
        .order('created_at', ascending: false);

    return (response as List).map((json) => Pet.fromJson(json)).toList();
  }

  /// 활성화된 반려동물 조회
  Future<Pet?> getActivePet() async {
    if (_userId == null) throw Exception('User not logged in');

    final response = await _client
        .from('pets')
        .select()
        .eq('user_id', _userId!)
        .eq('is_active', true)
        .maybeSingle();

    return response != null ? Pet.fromJson(response) : null;
  }

  /// 특정 반려동물 조회
  Future<Pet?> getPetById(String petId) async {
    final response =
        await _client.from('pets').select().eq('id', petId).maybeSingle();

    return response != null ? Pet.fromJson(response) : null;
  }

  /// 반려동물 생성
  Future<Pet> createPet({
    required String name,
    required String species,
    String? breed,
    DateTime? birthDate,
    String? gender,
    String? profileImageUrl,
  }) async {
    if (_userId == null) throw Exception('User not logged in');

    // 기존 활성 펫들 비활성화
    await _client
        .from('pets')
        .update({'is_active': false})
        .eq('user_id', _userId!);

    final response = await _client
        .from('pets')
        .insert({
          'user_id': _userId,
          'name': name,
          'species': species,
          if (breed != null) 'breed': breed,
          if (birthDate != null)
            'birth_date': birthDate.toIso8601String().split('T').first,
          if (gender != null) 'gender': gender,
          if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
          'is_active': true,
        })
        .select()
        .single();

    return Pet.fromJson(response);
  }

  /// 반려동물 수정
  Future<Pet> updatePet({
    required String petId,
    String? name,
    String? species,
    String? breed,
    DateTime? birthDate,
    String? gender,
    String? profileImageUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (species != null) updates['species'] = species;
    if (breed != null) updates['breed'] = breed;
    if (birthDate != null) {
      updates['birth_date'] = birthDate.toIso8601String().split('T').first;
    }
    if (gender != null) updates['gender'] = gender;
    if (profileImageUrl != null) updates['profile_image_url'] = profileImageUrl;

    final response = await _client
        .from('pets')
        .update(updates)
        .eq('id', petId)
        .select()
        .single();

    return Pet.fromJson(response);
  }

  /// 반려동물 삭제
  Future<void> deletePet(String petId) async {
    await _client.from('pets').delete().eq('id', petId);
  }

  /// 활성 펫 변경
  Future<void> setActivePet(String petId) async {
    if (_userId == null) throw Exception('User not logged in');

    // 모든 펫 비활성화
    await _client
        .from('pets')
        .update({'is_active': false})
        .eq('user_id', _userId!);

    // 선택한 펫 활성화
    await _client.from('pets').update({'is_active': true}).eq('id', petId);
  }
}
