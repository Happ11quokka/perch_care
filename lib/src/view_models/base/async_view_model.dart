import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// MVVM의 ViewModel 베이스 클래스.
///
/// - Riverpod `AsyncNotifier<T>`를 상속하여 View가 `ref.watch(xxxViewModelProvider)`로 구독.
/// - ViewModel은 **Repository 인터페이스만 의존**하고 Service/LocalDataSource를 직접 다루지 않는다.
/// - 공통 비동기 작업 패턴(`runLoad`, `runAction`)을 헬퍼로 제공해
///   화면마다 `AsyncValue.guard + copyWithPrevious` 보일러플레이트를 반복하지 않게 한다.
///
/// 사용 예:
/// ```dart
/// class PetListViewModel extends AsyncViewModel<List<Pet>> {
///   late final PetRepository _repo = ref.read(petRepositoryProvider);
///
///   @override
///   Future<List<Pet>> build() => _repo.getMyPets();
///
///   Future<void> refresh() => runLoad(() => _repo.getMyPets(forceRefresh: true));
/// }
/// ```
abstract class AsyncViewModel<T> extends AsyncNotifier<T> {
  /// `AsyncLoading`(+ previous) → `AsyncValue.guard(loader)` 흐름을 캡슐화한다.
  ///
  /// 하위 클래스의 refresh 류 메서드에서 호출: 이전 값을 유지한 채 로딩 플래그를
  /// 올리고, 에러가 나면 `AsyncError`로 안전하게 상태를 갱신한다.
  @protected
  Future<void> runLoad(Future<T> Function() loader) async {
    state = AsyncValue<T>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(loader);
  }
}
