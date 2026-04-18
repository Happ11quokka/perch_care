// Pet 도메인 Provider 파일 — MVVM 리팩터링(2026-04) 이후 ViewModel의 re-export 레이어.
//
// 새 코드는 아래 이름을 직접 사용하는 것을 권장한다:
//   - `petListViewModelProvider`, `PetListViewModel`
//   - `activePetViewModelProvider`, `ActivePetViewModel`
//
// 기존 caller (screens 16개 + auth_actions + bhi_provider)가 `activePetProvider` /
// `petListProvider`라는 이름을 사용하고 있어 일괄 교체 없이 호환성을 유지하기 위한 alias를 둔다.

export '../view_models/pet/active_pet_view_model.dart';
export '../view_models/pet/pet_list_view_model.dart';

import '../view_models/pet/active_pet_view_model.dart';
import '../view_models/pet/pet_list_view_model.dart';

/// @deprecated — `activePetViewModelProvider` 사용 권장.
final activePetProvider = activePetViewModelProvider;

/// @deprecated — `petListViewModelProvider` 사용 권장.
final petListProvider = petListViewModelProvider;
