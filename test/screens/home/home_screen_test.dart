import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perch_care/l10n/app_localizations.dart';
import 'package:perch_care/src/models/bhi_result.dart';
import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/providers/service_providers.dart';
import 'package:perch_care/src/repositories/home_repository.dart';
import 'package:perch_care/src/router/route_names.dart';
import 'package:perch_care/src/router/route_paths.dart';
import 'package:perch_care/src/screens/home/home_screen.dart';
import 'package:perch_care/src/services/storage/local_image_storage_service.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';
import 'package:perch_care/src/widgets/empty_state_widget.dart';

class _MockHomeRepository extends Mock implements HomeRepository {}

class _MockImageStorage extends Mock implements LocalImageStorageService {}

class _FakeActivePetViewModel extends ActivePetViewModel {
  _FakeActivePetViewModel(this._value);
  final Pet _value;
  @override
  Future<Pet?> build() => SynchronousFuture<Pet?>(_value);
}

final _pet = Pet(
  id: 'p1',
  userId: 'u',
  name: 'Bori',
  species: 'bird',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final _bhi = BhiResult(
  bhiScore: 72,
  weightScore: 80,
  foodScore: 70,
  waterScore: 60,
  wciLevel: 3,
  targetDate: DateTime(2026, 4, 18),
  hasWeightData: true,
  hasFoodData: true,
  hasWaterData: false,
);

/// HomeScreen 단독 호스팅용 최소 라우터 (코치마크 경로 판별에 GoRouterState 필요).
GoRouter _router() => GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          name: RouteNames.home,
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: '/profile',
          name: RouteNames.profile,
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );

Widget _app(GoRouter router, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('ko'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en'), Locale('zh')],
    ),
  );
}

Future<void> _frames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late _MockHomeRepository repo;
  late _MockImageStorage images;

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'coach_mark_seen_home': true});
    repo = _MockHomeRepository();
    images = _MockImageStorage();
    when(() => images.getImage(
          ownerType: any(named: 'ownerType'),
          ownerId: any(named: 'ownerId'),
        )).thenAnswer((_) async => null);
    when(() => repo.processOfflineQueue()).thenAnswer((_) async {});
    when(() => repo.syncLocalRecordsIfNeeded(any())).thenAnswer((_) async {});
    when(() => repo.loadHealthDerivedData(any()))
        .thenAnswer((_) async => const HomeDerivedData());
    when(() => repo.lastBhiFetchTime).thenReturn(null);
    // 첫 로드 실패
    when(() => repo.loadPetWithBhi(any(), any()))
        .thenThrow(Exception('offline'));
  });

  List<Override> overrides() => [
        homeRepositoryProvider.overrideWithValue(repo),
        localImageStorageServiceProvider.overrideWithValue(images),
        activePetViewModelProvider
            .overrideWith(() => _FakeActivePetViewModel(_pet)),
      ];

  void stubRecovered() {
    when(() => repo.loadPetWithBhi(any(), any()))
        .thenAnswer((_) async => (pet: _pet, bhi: _bhi));
    when(() => repo.loadBhiForDate(any(), any(),
        forceRefresh: any(named: 'forceRefresh'))).thenAnswer((_) async => _bhi);
  }

  Future<GoRouter> pumpHome(WidgetTester tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, overrides()));
    await _frames(tester);
    return router;
  }

  testWidgets('첫 로드 실패 시 빈 홈 대신 에러 + 재시도 UI를 표시한다', (tester) async {
    await pumpHome(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(HomeScreen)));
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    expect(find.text(l10n.error_loadPet), findsOneWidget);
    expect(find.text(l10n.hc_retry), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // 당겨서 새로고침이 가능하도록 스크롤 뷰는 유지된다.
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('재시도 버튼을 누르면 전체 초기 로드를 다시 수행해 복구한다', (tester) async {
    await pumpHome(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(HomeScreen)));
    expect(find.text(l10n.error_loadPet), findsOneWidget);

    stubRecovered();
    await tester.tap(find.text(l10n.hc_retry));
    await _frames(tester);

    expect(find.byType(EmptyStateWidget), findsNothing);
    expect(find.text(l10n.error_loadPet), findsNothing);
    expect(find.text('Bori'), findsWidgets);
    verify(() => repo.loadPetWithBhi('p1', any())).called(2);
  });

  testWidgets('에러 상태에서 당겨서 새로고침해도 복구된다', (tester) async {
    await pumpHome(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(HomeScreen)));
    expect(find.text(l10n.error_loadPet), findsOneWidget);

    stubRecovered();
    await tester.fling(
        find.byType(SingleChildScrollView), const Offset(0, 400), 1000);
    await tester.pump();
    await _frames(tester, 12);

    expect(find.text(l10n.error_loadPet), findsNothing);
    expect(find.text('Bori'), findsWidgets);
    verify(() => repo.loadPetWithBhi('p1', any())).called(2);
  });
}
