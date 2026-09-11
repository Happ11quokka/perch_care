// F09 회귀 가드: 작은 화면(en 320×568, 1.0x)과 접근성 큰 글자(ko 390×844, 2.0x)에서
// 주요 화면이 RenderFlex overflow 없이 레이아웃되는지 확인한다.
//
// 2026-09-09 감사에서 실제로 overflow가 재현된 7개 라우트를 실제 AppRouter 라우트 트리
// (쉘 포함)로 띄운다. 외부 데이터/네이티브 서비스만 mock으로 대체한다.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perch_care/l10n/app_localizations.dart';
import 'package:perch_care/src/models/ai_health_check.dart';
import 'package:perch_care/src/models/bhi_result.dart';
import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/providers/service_providers.dart';
import 'package:perch_care/src/repositories/auth_repository.dart';
import 'package:perch_care/src/repositories/chat_repository.dart';
import 'package:perch_care/src/repositories/food_repository.dart';
import 'package:perch_care/src/repositories/health_check_repository.dart';
import 'package:perch_care/src/repositories/notification_repository.dart';
import 'package:perch_care/src/repositories/pet_repository.dart';
import 'package:perch_care/src/repositories/water_repository.dart';
import 'package:perch_care/src/repositories/weight_repository.dart';
import 'package:perch_care/src/router/app_router.dart';
import 'package:perch_care/src/router/route_paths.dart';
import 'package:perch_care/src/services/api/token_service.dart';
import 'package:perch_care/src/services/firebase/firebase_init.dart';
import 'package:perch_care/src/services/storage/local_image_storage_service.dart';
import 'package:perch_care/src/theme/app_theme.dart';
import 'package:perch_care/src/view_models/home/home_state.dart';
import 'package:perch_care/src/view_models/home/home_view_model.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';
import 'package:perch_care/src/view_models/pet/pet_list_view_model.dart';

class _ImageMock extends Mock implements LocalImageStorageService {}

class _AuthMock extends Mock implements AuthRepository {}

class _PetMock extends Mock implements PetRepository {}

class _FoodMock extends Mock implements FoodRepository {}

class _WaterMock extends Mock implements WaterRepository {}

class _WeightMock extends Mock implements WeightRepository {}

class _ChatMock extends Mock implements ChatRepository {}

class _HealthMock extends Mock implements HealthCheckRepository {}

class _NotificationMock extends Mock implements NotificationRepository {}

final _pet = Pet(
  id: 'layout-pet',
  userId: 'layout-user',
  name: 'Bird layout-pet',
  species: 'bird',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _bhi = BhiResult(
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

class _ActiveFixture extends ActivePetViewModel {
  @override
  Future<Pet?> build() => SynchronousFuture(_pet);
}

class _ListFixture extends PetListViewModel {
  @override
  Future<List<Pet>> build() => SynchronousFuture([_pet]);
}

class _HomeFixture extends HomeViewModel {
  @override
  Future<HomeState> build() =>
      SynchronousFuture(HomeState(activePet: _pet, bhi: _bhi, wciLevel: 3));
  @override
  Future<void> processOfflineQueue() async {}
}

List<Override> _overrides() {
  final images = _ImageMock();
  final auth = _AuthMock();
  final pets = _PetMock();
  final food = _FoodMock();
  final water = _WaterMock();
  final weight = _WeightMock();
  final chat = _ChatMock();
  final health = _HealthMock();
  final notifications = _NotificationMock();
  when(() => images.getImage(
        ownerType: any(named: 'ownerType'),
        ownerId: any(named: 'ownerId'),
      )).thenAnswer((_) async => null);
  when(() => auth.getProfile())
      .thenAnswer((_) async => {'nickname': 'Layout user'});
  when(() => auth.getSocialAccounts()).thenAnswer((_) async => []);
  when(() => pets.getActivePetFromLocalCache()).thenAnswer((_) async => null);
  when(() => pets.getLocalPets()).thenAnswer((_) async => []);
  when(() => food.loadEntriesByDate(
        petId: any(named: 'petId'),
        date: any(named: 'date'),
      )).thenAnswer((_) async => []);
  when(() => water.loadByDate(
        petId: any(named: 'petId'),
        date: any(named: 'date'),
      )).thenAnswer((_) async => null);
  when(() => weight.fetchLocal(petId: any(named: 'petId')))
      .thenAnswer((_) async => []);
  when(() => weight.fetchAll(petId: any(named: 'petId')))
      .thenAnswer((_) async => []);
  when(() => chat.loadConversation(any()))
      .thenAnswer((_) async => const ConversationLoad(messages: []));
  when(() => health.loadHistory(any())).thenAnswer((_) async => []);
  when(() => notifications.fetch()).thenAnswer((_) async => []);
  when(() => notifications.subscribe())
      .thenAnswer((_) => const Stream.empty());
  return [
    localImageStorageServiceProvider.overrideWithValue(images),
    authRepositoryProvider.overrideWithValue(auth),
    petRepositoryProvider.overrideWithValue(pets),
    foodRepositoryProvider.overrideWithValue(food),
    waterRepositoryProvider.overrideWithValue(water),
    weightRepositoryProvider.overrideWithValue(weight),
    chatRepositoryProvider.overrideWithValue(chat),
    healthCheckRepositoryProvider.overrideWithValue(health),
    notificationRepositoryProvider.overrideWithValue(notifications),
    activePetViewModelProvider.overrideWith(_ActiveFixture.new),
    petListViewModelProvider.overrideWith(_ListFixture.new),
    homeViewModelProvider.overrideWith(_HomeFixture.new),
  ];
}

Map<String, Object> _coachMarksSeen() => {
      for (final screen in [
        'home',
        'records',
        'chatbot',
        'health_check_main',
        'bhi_detail',
        'profile',
        'pet_profile_detail',
      ])
        'coach_mark_seen_$screen': true,
    };

Widget _app(GoRouter router, {required String language, required double scale}) {
  return ProviderScope(
    overrides: _overrides(),
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      locale: Locale(language),
      supportedLocales: const [Locale('ko'), Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
    ),
  );
}

Future<void> _frames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

typedef _Scenario = ({String label, String language, Size size, double scale});

const _scenarios = <_Scenario>[
  (label: 'en 320x568 @1.0x', language: 'en', size: Size(320, 568), scale: 1.0),
  (label: 'ko 390x844 @2.0x', language: 'ko', size: Size(390, 844), scale: 2.0),
];

typedef _Route = ({String path, Object? extra});

final _routes = <String, _Route>{
  'home': (path: RoutePaths.home, extra: null),
  'bhi-detail': (path: RoutePaths.bhiDetail, extra: _bhi),
  'vet-summary': (path: RoutePaths.vetSummary, extra: null),
  'profile': (path: RoutePaths.profile, extra: null),
  'pet-add': (path: RoutePaths.petAdd, extra: null),
  'health-check-capture': (
    path: RoutePaths.healthCheckCapture,
    extra: {'mode': VisionMode.partSpecific},
  ),
  'email-login': (path: RoutePaths.emailLogin, extra: null),
};

/// 앱은 폰트를 번들하지 않고 플랫폼 폰트('Pretendard' 폴백)를 쓴다. flutter_test 기본 Ahem
/// 폰트는 모든 글리프가 1em 정사각형이라 실제보다 훨씬 넓게 측정되므로, 감사 프로브와
/// 동일하게 macOS 시스템 폰트를 앱 폰트 패밀리 이름으로 등록해 실기기에 가까운 폭으로 잰다.
const _systemFontCandidates = [
  '/System/Library/Fonts/AppleSDGothicNeo.ttc',
  '/System/Library/Fonts/Supplemental/AppleGothic.ttf',
];

bool _realFontLoaded = false;

Future<void> _loadRealFont() async {
  for (final path in _systemFontCandidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = await file.readAsBytes();
    final loader = FontLoader('Pretendard')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    _realFontLoaded = true;
    return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    registerFallbackValue(DateTime(2026));
    await _loadRealFont();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    // AppRouter는 Firebase를 쓸 수 있을 때만 FirebaseAnalyticsObserver를 등록한다.
    // 실제 앱과 같은 구성(관찰자 포함)으로 검사하기 위해 core mock을 초기화한다.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_analytics'),
      (_) async => null,
    );
    FirebaseInit.setAvailableForTest(value: true);
    FlutterSecureStorage.setMockInitialValues({});
    await TokenService.instance.init();
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://layout.invalid/api/v1');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(_coachMarksSeen());
  });

  for (final scenario in _scenarios) {
    group(scenario.label, () {
      for (final entry in _routes.entries) {
        testWidgets('${entry.key} lays out without overflow', (tester) async {
          if (!_realFontLoaded) {
            markTestSkipped('실측 폭 검증에 필요한 시스템 폰트를 찾지 못했습니다 (macOS 전용).');
            return;
          }
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = scenario.size;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final router = GoRouter(
            routes: AppRouter.router.configuration.routes,
            initialLocation: entry.value.path,
            initialExtra: entry.value.extra,
          );
          addTearDown(router.dispose);

          // 한 프레임에 여러 overflow가 나도 전부 모아서 보고한다.
          final layoutErrors = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            if (details.exceptionAsString().contains('overflowed')) {
              // "The relevant error-causing widget was:" 다음 줄들 중
              // "Row:file:///...:line:col" 형태의 생성 위치를 찾는다.
              final lines = details.toString().split('\n');
              final index = lines.indexWhere(
                (line) => line.contains('error-causing widget'),
              );
              final widget = index < 0
                  ? ''
                  : lines
                      .skip(index + 1)
                      .take(3)
                      .firstWhere(
                        (line) => line.contains(':file:///'),
                        orElse: () => index + 1 < lines.length
                            ? lines[index + 1]
                            : '',
                      )
                      .trim();
              layoutErrors.add(
                '${details.exceptionAsString()} | ${details.context ?? ''} | $widget',
              );
            } else {
              previous?.call(details);
            }
          };
          try {
            await tester.pumpWidget(_app(
              router,
              language: scenario.language,
              scale: scenario.scale,
            ));
            await _frames(tester);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(seconds: 1));
          } finally {
            FlutterError.onError = previous;
          }

          expect(layoutErrors, isEmpty, reason: layoutErrors.join('\n'));
          expect(tester.takeException(), isNull);
        });
      }
    });
  }
}
