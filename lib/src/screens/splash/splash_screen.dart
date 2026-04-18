import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/pet.dart';
import '../../providers/pet_providers.dart';
import '../../providers/premium_provider.dart';
import '../../services/api/api_client.dart';
import '../../services/api/token_service.dart';
import '../../services/iap/iap_service.dart';
import '../../services/push/push_notification_service.dart';
import '../../services/storage/local_image_storage_service.dart';
import '../../services/sync/sync_service.dart';
import '../../router/route_paths.dart';
import '../../theme/colors.dart';
import '../../theme/durations.dart';

/// 스플래시 스크린
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _innerCircleScale;
  late Animation<double> _middleCircleScale;
  late Animation<double> _outerCircleScale;
  late Animation<double> _logoOpacity;

  bool _animationCompleted = false;
  bool _servicesInitialized = false;
  bool _disposed = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: AppDurations.splash,
      vsync: this,
    );

    // 중앙 원 - 가장 먼저 시작 (0.0 ~ 0.4초)
    _innerCircleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // 중간 원 - 약간 지연 (0.15 ~ 0.6초)
    _middleCircleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.6, curve: Curves.easeOut),
      ),
    );

    // 바깥 원 - 가장 늦게 시작 (0.3 ~ 0.8초)
    _outerCircleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    // 로고 - 원들이 확장된 후 나타남 (0.6 ~ 1.0초)
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    // 애니메이션 완료 후 플래그 설정
    _controller.addStatusListener(_onAnimationStatus);

    _controller.forward();

    // 서비스 초기화 (애니메이션과 병렬로 실행)
    _initializeServices();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _animationCompleted = true;
      _tryNavigate();
    }
  }

  Future<void> _initializeServices() async {
    // 1-3. 독립 서비스 병렬 초기화 (dotenv는 main()에서 이미 로드됨)
    debugPrint('[Splash] 1-3. Parallel initialization...');
    await Future.wait([
      _initTokenService(),
      _initGoogleSignIn(),
      _initLocalImageStorage(),
    ]);

    // 4. API 클라이언트 초기화 (TokenService 의존)
    debugPrint('[Splash] 4. ApiClient initializing...');
    try {
      ApiClient.initialize();
      debugPrint('[Splash] 4. ApiClient initialized');
    } catch (e) {
      debugPrint('[Splash] 4. ApiClient init error: $e');
    }

    // 5. SyncService 큐 로드 (SharedPreferences만 읽음 — 빠름)
    debugPrint('[Splash] 5. SyncService init...');
    try {
      await SyncService.instance.init();
      debugPrint('[Splash] 5. SyncService initialized');
    } catch (e) {
      debugPrint('[Splash] 5. SyncService init error: $e');
    }

    // 6. Riverpod provider 사전 로드 — HomeScreen 즉시 렌더 (네트워크 1회)
    if (TokenService.instance.isLoggedIn) {
      try {
        await ref.read(activePetProvider.notifier).refresh();
        await ref.read(petListProvider.notifier).refresh();
        await ref.read(premiumStatusProvider.notifier).refresh();
        debugPrint('[Splash] Riverpod providers seeded');
      } catch (e) {
        debugPrint('[Splash] Provider seeding error: $e');
      }
    }

    // 백그라운드 동기화용 펫 목록 캡처 — splash dispose 이후에도 안전하게 사용
    final pets = TokenService.instance.isLoggedIn
        ? (ref.read(petListProvider).valueOrNull ?? const <Pet>[])
        : const <Pet>[];

    debugPrint('[Splash] All services initialized, navigating...');
    _servicesInitialized = true;
    _tryNavigate();

    // 오프라인 큐 처리 + 초기 동기화는 백그라운드에서 진행 (splash 블로킹 방지)
    unawaited(_runBackgroundSync(pets));
  }

  /// 백그라운드 동기화: splash 네비게이션을 블로킹하지 않음
  /// - processQueue: 실패했던 항목 재전송 (네트워크)
  /// - syncLocalRecordsIfNeeded: 펫별 최초 1회 로컬 데이터 마이그레이션
  /// pets는 caller에서 미리 read한 값을 받아 dispose 이후에도 안전
  Future<void> _runBackgroundSync(List<Pet> pets) async {
    try {
      await SyncService.instance.processQueue();
      debugPrint('[Splash/bg] SyncService queue processed');

      for (final pet in pets) {
        await SyncService.instance.syncLocalRecordsIfNeeded(pet.id);
        debugPrint('[Splash/bg] Initial sync done: ${pet.id}');
      }
    } catch (e) {
      debugPrint('[Splash/bg] Background sync error: $e');
    }
  }

  Future<void> _initTokenService() async {
    try {
      await TokenService.instance.init();
      debugPrint('[Splash] TokenService initialized');
    } catch (e) {
      debugPrint('[Splash] TokenService init error: $e');
    }
  }

  Future<void> _initGoogleSignIn() async {
    try {
      await GoogleSignIn.instance.initialize(
        clientId:
            '351000470573-9cu20o306ho5jepgee2b474jnd0ah08b.apps.googleusercontent.com',
        serverClientId:
            '351000470573-ivirja6bvfpqk0rsg1shd048erdk1tv4.apps.googleusercontent.com',
      );
      debugPrint('[Splash] GoogleSignIn initialized');
    } catch (e) {
      debugPrint('[Splash] GoogleSignIn init error: $e');
    }
  }

  Future<void> _initLocalImageStorage() async {
    try {
      await LocalImageStorageService.instance.init();
      debugPrint('[Splash] LocalImageStorageService initialized');
    } catch (e) {
      debugPrint('[Splash] LocalImageStorageService init error: $e');
    }
  }

  void _tryNavigate() {
    // 애니메이션과 서비스 초기화가 모두 완료되면 네비게이션
    if (_animationCompleted &&
        _servicesInitialized &&
        mounted &&
        !_disposed &&
        !_isNavigating) {
      _isNavigating = true;
      _navigateToInitialRoute();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  /// 화면 크기 기반 원의 크기 계산
  ({double inner, double middle, double outer}) _calculateCircleSizes(
    Size screenSize,
  ) {
    final width = screenSize.width;

    return (
      inner: width * 0.52, // 기준 원
      middle: width * 0.89, // 내부 원보다 약 1.7배
      outer: width * 1.35, // 중간 원보다 약 1.5배 (화면 밖으로 약간 넘침)
    );
  }

  /// 원형 위젯 생성 헬퍼 메서드
  Widget _buildCircle({
    required double size,
    required double scale,
    required double opacity,
    bool useOverflow = false,
  }) {
    final circle = Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: SvgPicture.asset(
          'assets/images/ellipse-67.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(
            Colors.white.withValues(alpha: opacity),
            BlendMode.srcIn,
          ),
        ),
      ),
    );

    if (useOverflow) {
      return OverflowBox(
        maxWidth: size * 1.5,
        maxHeight: size * 1.5,
        alignment: Alignment.center,
        child: circle,
      );
    }

    return circle;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final sizes = _calculateCircleSizes(screenSize);

    return Scaffold(
      backgroundColor: AppColors.brandPrimary,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 배경 원형 링들 (바깥쪽) - 애니메이션 (화면을 벗어남)
                Center(
                  child: _buildCircle(
                    size: sizes.outer,
                    scale: _outerCircleScale.value,
                    opacity: _outerCircleScale.value * 0.25,
                    useOverflow: true,
                  ),
                ),

                // 중간 원형 링 - 애니메이션
                Center(
                  child: _buildCircle(
                    size: sizes.middle,
                    scale: _middleCircleScale.value,
                    opacity: _middleCircleScale.value * 0.5,
                    useOverflow: true,
                  ),
                ),

                // 중앙 원형 + 브랜드 로고 - 애니메이션
                Center(
                  child: Transform.scale(
                    scale: _innerCircleScale.value,
                    child: SizedBox(
                      width: sizes.inner,
                      height: sizes.inner,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/images/ellipse-67.svg',
                            width: sizes.inner,
                            height: sizes.inner,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                          Opacity(
                            opacity: _logoOpacity.value,
                            child: SvgPicture.asset(
                              'assets/images/brand.svg',
                              width: sizes.inner * 0.92, // 로고는 원의 92% 크기
                              height: sizes.inner * 0.92,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _navigateToInitialRoute() async {
    final isLoggedIn = TokenService.instance.isLoggedIn;

    String targetRoute;
    if (isLoggedIn) {
      targetRoute = RoutePaths.home;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedOnboarding =
          prefs.getBool('has_completed_onboarding') ?? false;
      targetRoute =
          hasCompletedOnboarding ? RoutePaths.login : RoutePaths.onboarding;
    }

    debugPrint(
      '[Splash] Navigating to: $targetRoute (isLoggedIn: $isLoggedIn)',
    );

    // 로그인 상태면 FCM 푸시 토큰 등록 + IAP 초기화
    if (isLoggedIn) {
      unawaited(PushNotificationService.instance.initialize());
      await IapService.instance.initialize();
    }

    if (!mounted || _disposed) return;
    context.go(targetRoute);
    debugPrint('[Splash] Navigation called');
  }
}
