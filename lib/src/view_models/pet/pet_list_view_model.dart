import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pet.dart';
import '../../providers/repository_providers.dart';
import '../../repositories/pet_repository.dart';
import '../base/async_view_model.dart';

/// 내 펫 목록 ViewModel.
///
/// View: `PetProfileScreen` (펫 목록 화면)
/// Repository: `PetRepository`
class PetListViewModel extends AsyncViewModel<List<Pet>> {
  PetRepository get _repo => ref.read(petRepositoryProvider);

  @override
  Future<List<Pet>> build() => _repo.getMyPets();

  /// 서버에서 강제 재조회.
  Future<void> refresh() => runLoad(() => _repo.getMyPets(forceRefresh: true));
}

final petListViewModelProvider =
    AsyncNotifierProvider<PetListViewModel, List<Pet>>(PetListViewModel.new);
