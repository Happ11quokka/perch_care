// 기록 화면(water/food/weight) 위젯 테스트 공용 하네스.
//
// F04 회귀 가드용: 활성 펫 provider가 화면 마운트 *이후*에 확정되거나 전환되는
// 시나리오를 재현하기 위해, build()를 pending Future로 두거나 state를 직접
// 조작할 수 있는 ActivePetViewModel fixture를 제공한다.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perch_care/l10n/app_localizations.dart';
import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';

Pet testPet(String id, {String? breedId}) => Pet(
      id: id,
      userId: 'test-user',
      name: 'Bird $id',
      species: 'bird',
      breedId: breedId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// 제어 가능한 ActivePet fixture.
///
/// - [pending]이 주어지면 build()가 그 Future를 반환 → 완료 전까지 AsyncLoading.
/// - 아니면 [initial]을 동기 반환 (SynchronousFuture) → 첫 프레임부터 AsyncData.
/// - [setPet] / [setError] 로 이후 상태 전이를 흉내낸다.
class ControllableActivePet extends ActivePetViewModel {
  ControllableActivePet({this.initial, Future<Pet?>? pending})
      : _pending = pending;

  final Pet? initial;
  final Future<Pet?>? _pending;

  @override
  Future<Pet?> build() => _pending ?? SynchronousFuture(initial);

  void setPet(Pet? pet) => state = AsyncData(pet);

  void setError(Object error) => state = AsyncError(error, StackTrace.empty);
}

/// 코치마크를 이미 본 것으로 표시 — 오버레이/지연 타이머가 테스트를 오염시키지 않게.
Map<String, Object> coachMarksSeen() => {
      for (final screen in ['food_record', 'water_record', 'weight_record'])
        'coach_mark_seen_$screen': true,
    };

const _localizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const _supportedLocales = [Locale('ko'), Locale('en'), Locale('zh')];

/// [container] 스코프 안에서 [home]을 ko 로케일 MaterialApp으로 감싼다.
Widget recordTestApp({
  required ProviderContainer container,
  required Widget home,
}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: _supportedLocales,
        localizationsDelegates: _localizationsDelegates,
        home: home,
      ),
    );

/// go_router 기반 화면용 (context.pop 을 쓰는 화면).
Widget recordTestRouterApp({
  required ProviderContainer container,
  required RouterConfig<Object> routerConfig,
}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: routerConfig,
        locale: const Locale('ko'),
        supportedLocales: _supportedLocales,
        localizationsDelegates: _localizationsDelegates,
      ),
    );

/// 로딩 스피너(무한 애니메이션) 때문에 pumpAndSettle 을 쓸 수 없으므로 고정 프레임을 돌린다.
Future<void> pumpFrames(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// AppSnackBar 자동 dismiss 타이머(3s)를 소진 — 테스트 종료 시 pending timer 방지.
Future<void> drainSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(seconds: 1));
}
