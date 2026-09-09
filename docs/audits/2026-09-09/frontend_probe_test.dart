// This diagnostic test is deliberately outside test/ so known failures do not run in the default suite.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// Diagnostic probes for the 2026-09-09 review. These assert desired behavior;
// failures are recorded in the audit, not hidden or added to the default suite.
// Run: flutter test docs/audits/2026-09-09/frontend_probe_test.dart --reporter expanded
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:country_picker/country_picker.dart';
import 'package:perch_care/l10n/app_localizations.dart';
import 'package:perch_care/src/router/app_router.dart';
import 'package:perch_care/src/providers/service_providers.dart';
import 'package:perch_care/src/services/storage/local_image_storage_service.dart';
import 'package:perch_care/src/theme/app_theme.dart';
import 'package:perch_care/src/widgets/coach_mark_overlay.dart';
import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/models/bhi_result.dart';
import 'package:perch_care/src/models/ai_health_check.dart';
import 'package:perch_care/src/screens/water/water_record_screen.dart';
import 'package:perch_care/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/auth_repository.dart';
import 'package:perch_care/src/repositories/home_repository.dart';
import 'package:perch_care/src/repositories/pet_repository.dart';
import 'package:perch_care/src/repositories/food_repository.dart';
import 'package:perch_care/src/repositories/water_repository.dart';
import 'package:perch_care/src/repositories/weight_repository.dart';
import 'package:perch_care/src/repositories/chat_repository.dart';
import 'package:perch_care/src/repositories/health_check_repository.dart';
import 'package:perch_care/src/repositories/notification_repository.dart';
import 'package:perch_care/src/services/api/api_client.dart';
import 'package:perch_care/src/services/api/token_service.dart';
import 'package:perch_care/src/view_models/auth/auth_view_model.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';
import 'package:perch_care/src/view_models/pet/pet_list_view_model.dart';
import 'package:perch_care/src/view_models/home/home_view_model.dart';
import 'package:perch_care/src/view_models/home/home_state.dart';
import 'package:perch_care/src/view_models/weight/weight_detail_view_model.dart';
import 'package:perch_care/src/view_models/weight/weight_detail_state.dart';

final captureKey = GlobalKey();

class ImageMock extends Mock implements LocalImageStorageService {}

class HomeMock extends Mock implements HomeRepository {}

class AuthMock extends Mock implements AuthRepository {}

class PetMock extends Mock implements PetRepository {}

class FoodMock extends Mock implements FoodRepository {}

class WaterMock extends Mock implements WaterRepository {}

class WeightMock extends Mock implements WeightRepository {}

class ChatMock extends Mock implements ChatRepository {}

class HealthMock extends Mock implements HealthCheckRepository {}

class NotificationMock extends Mock implements NotificationRepository {}

Pet pet(String id) => Pet(
  id: id,
  userId: 'audit-user',
  name: 'Bird $id',
  species: 'bird',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
final samplePet = pet('a');
final sampleBhi = BhiResult(
  bhiScore: 72,
  weightScore: 45,
  foodScore: 17,
  waterScore: 10,
  wciLevel: 3,
  targetDate: DateTime(2026),
  hasWeightData: true,
  hasFoodData: true,
  hasWaterData: true,
);

class ActiveFixture extends ActivePetViewModel {
  @override
  Future<Pet?> build() => SynchronousFuture(samplePet);
  void setPet(Pet value) => state = AsyncData(value);
}

class PendingActive extends ActivePetViewModel {
  PendingActive(this.result);
  final Future<Pet?> result;
  @override
  Future<Pet?> build() => result;
}

class ListFixture extends PetListViewModel {
  @override
  Future<List<Pet>> build() => SynchronousFuture([samplePet]);
}

class HomeFixture extends HomeViewModel {
  @override
  Future<HomeState> build() => SynchronousFuture(
    HomeState(activePet: samplePet, bhi: sampleBhi, wciLevel: 3),
  );
  @override
  Future<void> processOfflineQueue() async {}
}

class WeightFixture extends WeightDetailViewModel {
  @override
  Future<WeightDetailState> build() => SynchronousFuture(
    WeightDetailState(
      activePetId: samplePet.id,
      petName: samplePet.name,
      petList: [samplePet],
    ),
  );
}

class Fixtures {
  final images = ImageMock();
  final auth = AuthMock();
  final pets = PetMock();
  final food = FoodMock();
  final water = WaterMock();
  final weight = WeightMock();
  final chat = ChatMock();
  final health = HealthMock();
  final notifications = NotificationMock();
  final ActivePetViewModel Function() activeFactory;
  Fixtures({this.activeFactory = ActiveFixture.new}) {
    when(
      () => images.getImage(
        ownerType: any(named: 'ownerType'),
        ownerId: any(named: 'ownerId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => auth.getProfile(),
    ).thenAnswer((_) async => {'nickname': 'Audit user'});
    when(() => auth.getSocialAccounts()).thenAnswer((_) async => []);
    when(() => pets.getActivePetFromLocalCache()).thenAnswer((_) async => null);
    when(() => pets.getLocalPets()).thenAnswer((_) async => []);
    when(
      () => food.loadEntriesByDate(
        petId: any(named: 'petId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => water.loadByDate(
        petId: any(named: 'petId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => weight.fetchLocal(petId: any(named: 'petId')),
    ).thenAnswer((_) async => []);
    when(
      () => weight.fetchAll(petId: any(named: 'petId')),
    ).thenAnswer((_) async => []);
    when(
      () => chat.loadConversation(any()),
    ).thenAnswer((_) async => const ConversationLoad(messages: []));
    when(
      () => health.analyze(
        petId: any(named: 'petId'),
        mode: any(named: 'mode'),
        part: any(named: 'part'),
        notes: any(named: 'notes'),
        language: any(named: 'language'),
        imageBytes: any(named: 'imageBytes'),
        fileName: any(named: 'fileName'),
      ),
    ).thenThrow(
      ApiException(message: 'Audit simulated server failure', statusCode: 503),
    );
    when(() => health.loadHistory(any())).thenAnswer((_) async => []);
    when(() => notifications.fetch()).thenAnswer((_) async => []);
    when(
      () => notifications.subscribe(),
    ).thenAnswer((_) => const Stream.empty());
  }
  List<Override> get overrides => [
    localImageStorageServiceProvider.overrideWithValue(images),
    authRepositoryProvider.overrideWithValue(auth),
    petRepositoryProvider.overrideWithValue(pets),
    foodRepositoryProvider.overrideWithValue(food),
    waterRepositoryProvider.overrideWithValue(water),
    weightRepositoryProvider.overrideWithValue(weight),
    chatRepositoryProvider.overrideWithValue(chat),
    healthCheckRepositoryProvider.overrideWithValue(health),
    notificationRepositoryProvider.overrideWithValue(notifications),
    activePetViewModelProvider.overrideWith(activeFactory),
    petListViewModelProvider.overrideWith(ListFixture.new),
    homeViewModelProvider.overrideWith(HomeFixture.new),
    weightDetailViewModelProvider.overrideWith(WeightFixture.new),
  ];
}

Map<String, Object> preferences() => {
  for (final screen in [
    'home',
    'records',
    'chatbot',
    'food_record',
    'water_record',
    'weight_record',
    'health_check_main',
    'health_check_history',
    'health_check_result',
    'bhi_detail',
    'profile',
    'pet_profile_detail',
  ])
    'coach_mark_seen_$screen': true,
};
Widget app(
  GoRouter router,
  Fixtures f, {
  String language = 'ko',
  double scale = 1,
  ProviderContainer? container,
}) {
  final material = MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light,
    locale: Locale(language),
    supportedLocales: const [Locale('ko'), Locale('en'), Locale('zh')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      CountryLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: RepaintBoundary(key: captureKey, child: child!),
    ),
  );
  return container == null
      ? ProviderScope(overrides: f.overrides, child: material)
      : UncontrolledProviderScope(container: container, child: material);
}

Iterable<({String path, String name})> routes(
  List<RouteBase> list, [
  String parent = '',
]) sync* {
  for (final route in list) {
    if (route is GoRoute) {
      final path = route.path.startsWith('/')
          ? route.path
          : '$parent/${route.path}';
      yield (path: path, name: route.name!);
      yield* routes(route.routes, path);
    } else if (route is StatefulShellRoute) {
      for (final branch in route.branches) {
        yield* routes(branch.routes, parent);
      }
    }
  }
}

Object? extraFor(String name) => switch (name) {
  'health-check-capture' => {'mode': VisionMode.partSpecific},
  'health-check-analyzing' => {
    'mode': VisionMode.food,
    'imageBytes': Uint8List(0),
    'fileName': 'audit.jpg',
  },
  'health-check-result' => {
    'mode': VisionMode.fullBody,
    'result': <String, dynamic>{
      'overall_status': 'normal',
      'findings': <dynamic>[],
    },
    'isFromHistory': true,
  },
  'forgot-password-code' || 'forgot-password-reset' => {
    'method': 'email',
    'destination': 'audit@example.invalid',
    'identifier': 'audit@example.invalid',
    'code': '123456',
  },
  'bhi-detail' => sampleBhi,
  _ => null,
};
Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(Uint8List(0));
    final fontFile = File('/System/Library/Fonts/AppleSDGothicNeo.ttc');
    final loader = FontLoader('Pretendard')
      ..addFont(
        Future.value(ByteData.sublistView(await fontFile.readAsBytes())),
      );
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_analytics'),
          (_) async => null,
        );
    FlutterSecureStorage.setMockInitialValues({});
    await TokenService.instance.init();
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://audit.invalid/api/v1');
  });
  setUp(() {
    SharedPreferences.setMockInitialValues(preferences());
  });
  test('API POST retries with the refreshed token', () async {
    await TokenService.instance.saveTokens(
      accessToken: 'old',
      refreshToken: 'refresh',
    );
    final seen = <String?>[];
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        return http.Response(
          jsonEncode({'access_token': 'new', 'refresh_token': 'next'}),
          200,
        );
      }
      seen.add(request.headers['Authorization']);
      return request.headers['Authorization'] == 'Bearer new'
          ? http.Response('{}', 200)
          : http.Response('{"detail":"expired"}', 401);
    });
    http.runWithClient(ApiClient.initialize, () => mock);
    Object? failure;
    try {
      await ApiClient.instance.post('/pets/', body: {'name': 'test'});
    } catch (e) {
      failure = e;
    }
    expect(
      seen,
      ['Bearer old', 'Bearer new'],
      reason:
          'Saved token=${TokenService.instance.accessToken}; request failure=$failure',
    );
  });
  test('login reloads pet state populated before authentication', () async {
    final a = AuthMock();
    final p = PetMock();
    bool signedIn = false;
    when(
      () => p.getActivePet(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async => signedIn ? samplePet : null);
    when(
      () => a.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {
      signedIn = true;
      return LoginAuthenticated(true);
    });
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(a),
        petRepositoryProvider.overrideWithValue(p),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(activePetViewModelProvider, (_, __) {});
    addTearDown(sub.close);
    expect(await c.read(activePetViewModelProvider.future), isNull);
    await c.read(authViewModelProvider.future);
    await c
        .read(authViewModelProvider.notifier)
        .signInWithEmail(email: 'audit@example.invalid', password: 'test');
    await c.pump();
    expect(c.read(activePetViewModelProvider).valueOrNull?.id, samplePet.id);
  });
  test('temporary refresh network failure keeps the saved session', () async {
    await TokenService.instance.saveTokens(
      accessToken: 'old',
      refreshToken: 'refresh',
    );
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        throw http.ClientException('offline');
      }
      return http.Response('{"detail":"expired"}', 401);
    });
    http.runWithClient(ApiClient.initialize, () => mock);
    try {
      await ApiClient.instance.get('/pets/');
    } catch (_) {}
    expect(TokenService.instance.refreshToken, 'refresh');
  });
  testWidgets(
    'water record loads the pet when initial provider loading finishes',
    (tester) async {
      final pending = Completer<Pet?>();
      final f = Fixtures(activeFactory: () => PendingActive(pending.future));
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const WaterRecordScreen()),
        ],
      );
      await tester.pumpWidget(app(router, f));
      await frames(tester);
      pending.complete(samplePet);
      await frames(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      verify(
        () => f.water.loadByDate(
          petId: samplePet.id,
          date: any(named: 'date'),
        ),
      ).called(1);
    },
  );
  testWidgets('AI conversation reloads after switching the active pet', (
    tester,
  ) async {
    final f = Fixtures();
    final c = ProviderContainer(overrides: f.overrides);
    addTearDown(c.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const AIEncyclopediaScreen()),
      ],
    );
    await tester.pumpWidget(app(router, f, container: c));
    await frames(tester);
    (c.read(activePetViewModelProvider.notifier) as ActiveFixture).setPet(
      pet('b'),
    );
    await frames(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    verify(() => f.chat.loadConversation('b')).called(1);
  });
  testWidgets('all protected routes redirect signed-out users to login', (
    tester,
  ) async {
    await TokenService.instance.clearTokens();
    final f = Fixtures();
    final config = AppRouter.router.configuration;
    final router = GoRouter(
      routes: config.routes,
      initialLocation: '/login',
      redirect: config.topRedirect,
    );
    await tester.pumpWidget(app(router, f));
    await frames(tester);
    final public = {
      'splash',
      'onboarding',
      'login',
      'signup',
      'email-login',
      'forgot-password-method',
      'forgot-password-code',
      'forgot-password-reset',
      'terms-detail-public',
    };
    final protected = routes(
      config.routes,
    ).where((r) => !public.contains(r.name)).toList();
    for (final item in protected) {
      router.go(item.path.replaceAll(':date', '2026-09-09'));
      await frames(tester);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/login',
        reason: item.name,
      );
    }
    debugPrint('AUDIT_GUARD protected routes: ${protected.length}');
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
  testWidgets('coach marks from an inactive AI tab do not cover home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ...preferences(),
      'coach_mark_seen_chatbot': false,
    });
    final f = Fixtures();
    final config = AppRouter.router.configuration;
    final router = GoRouter(
      routes: config.routes,
      initialLocation: '/ai-encyclopedia',
    );
    await tester.pumpWidget(app(router, f));
    await tester.pump();
    router.go('/home');
    await frames(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    );
    final ghost =
        find.text(l10n.coach_chatInput_title).evaluate().isNotEmpty ||
        find.text(l10n.coach_chatSuggestion_title).evaluate().isNotEmpty;
    CoachMarkOverlay.dismiss();
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    expect(ghost, isFalse);
  });
  test(
    'home pull-to-refresh recovers from the first data load failure',
    () async {
      final repo = HomeMock();
      when(
        () => repo.loadPetWithBhi(any(), any()),
      ).thenThrow(Exception('offline'));
      when(
        () => repo.loadHealthDerivedData(any()),
      ).thenAnswer((_) async => const HomeDerivedData());
      when(() => repo.lastBhiFetchTime).thenReturn(null);
      final c = ProviderContainer(
        overrides: [
          homeRepositoryProvider.overrideWithValue(repo),
          activePetViewModelProvider.overrideWith(ActiveFixture.new),
        ],
      );
      addTearDown(c.dispose);
      await expectLater(c.read(homeViewModelProvider.future), throwsException);
      when(
        () => repo.loadPetWithBhi(any(), any()),
      ).thenAnswer((_) async => (pet: samplePet, bhi: sampleBhi));
      when(
        () => repo.loadBhiForDate(any(), any(), forceRefresh: true),
      ).thenAnswer((_) async => sampleBhi);
      await c
          .read(homeViewModelProvider.notifier)
          .pullToRefresh(DateTime(2026));
      expect(c.read(homeViewModelProvider).hasError, isFalse);
    },
  );
  testWidgets('direct public signup route has a working back action', (
    tester,
  ) async {
    final f = Fixtures();
    final config = AppRouter.router.configuration;
    final router = GoRouter(routes: config.routes, initialLocation: '/signup');
    await tester.pumpWidget(app(router, f));
    await frames(tester);
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pump();
    final error = tester.takeException();
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    expect(error, isNull);
  });
  // Test every registered route with its real builders and real shell. Only
  // external data/native services are substituted; splash requires native boot.
  for (final scenario in [
    (language: 'ko', width: 390.0, height: 844.0, scale: 1.0),
    (language: 'en', width: 320.0, height: 568.0, scale: 1.0),
    (language: 'ko', width: 390.0, height: 844.0, scale: 2.0),
    (language: 'zh', width: 390.0, height: 844.0, scale: 1.0),
  ]) {
    // Router is lazy and requires Firebase: enumerate at runtime inside a test.
    testWidgets(
      'route matrix ${scenario.language} ${scenario.width} scale ${scenario.scale}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(scenario.width, scenario.height);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final results = <String, List<String>>{};
        final config = AppRouter.router.configuration;
        for (final item in routes(config.routes).where((r) => r.path != '/')) {
          final f = Fixtures();
          final path = item.path.replaceAll(':date', '2026-09-09');
          final router = GoRouter(
            routes: config.routes,
            initialLocation: path,
            initialExtra: extraFor(item.name),
          );
          final errors = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(
            '${details.exceptionAsString()} | ${details.context ?? ''}',
          );
          try {
            await tester.pumpWidget(
              app(
                router,
                f,
                language: scenario.language,
                scale: scenario.scale,
              ),
            );
            await frames(tester);
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 40)),
            );
            await frames(tester);
            if ((item.name == 'forgot-password-code' &&
                    scenario.language == 'ko' &&
                    scenario.scale == 1) ||
                (item.name == 'vet-summary' && scenario.language == 'en')) {
              await tester.runAsync(() async {
                final boundary =
                    captureKey.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final img = await boundary.toImage();
                final bytes = await img.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final dir = Directory('docs/audits/2026-09-09/screenshots')
                  ..createSync(recursive: true);
                File(
                  '${dir.path}/${item.name}-${scenario.language}.png',
                ).writeAsBytesSync(bytes!.buffer.asUint8List());
                img.dispose();
              });
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(seconds: 1));
          } finally {
            FlutterError.onError = previous;
            router.dispose();
          }
          results[item.name] = errors;
          debugPrint(
            'AUDIT_ROUTE ${jsonEncode({'name': item.name, 'path': path, 'scenario': scenario.toString(), 'errors': errors})}',
          );
        }
        expect(
          results.values.where((errors) => errors.isNotEmpty),
          isEmpty,
          reason: jsonEncode(
            results.entries
                .where((e) => e.value.isNotEmpty)
                .map((e) => {'route': e.key, 'errors': e.value})
                .toList(),
          ),
        );
      },
    );
  }
}
