import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/login/email_login_screen.dart';
import '../screens/signup/signup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/weight/weight_detail_screen.dart';
import '../screens/weight/weight_record_screen.dart';
import '../screens/weight/weight_add_screen.dart';
import '../screens/pet/pet_add_screen.dart';
import '../screens/pet/pet_profile_screen.dart';
import '../screens/notification/notification_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/pet_profile_detail_screen.dart';
import '../screens/ai_encyclopedia/ai_encyclopedia_screen.dart';
import '../screens/health_check/health_check_main_screen.dart';
import '../screens/health_check/health_check_capture_screen.dart';
import '../screens/health_check/health_check_analyzing_screen.dart';
import '../screens/health_check/health_check_result_screen.dart';
import '../screens/health_check/health_check_history_screen.dart';
import '../screens/health_check/vet_summary_screen.dart';
import '../models/ai_health_check.dart';
import 'dart:typed_data';
import '../screens/wci/wci_index_screen.dart';
import '../screens/bhi/bhi_detail_screen.dart';
import '../models/bhi_result.dart';
import '../screens/food/food_record_screen.dart';
import '../screens/water/water_record_screen.dart';
import '../screens/forgot_password/forgot_password_method_screen.dart';
import '../screens/forgot_password/forgot_password_code_screen.dart';
import '../screens/forgot_password/forgot_password_reset_screen.dart';
import '../screens/profile_setup/profile_setup_screen.dart';
import '../screens/profile_setup/profile_setup_complete_screen.dart';
import '../screens/terms/terms_detail_screen.dart';
import '../screens/faq/faq_screen.dart';
import '../data/terms_content.dart';
import '../services/api/token_service.dart';
import '../services/analytics/analytics_service.dart';
import '../theme/durations.dart';
import '../widgets/bottom_nav_bar.dart';
import 'route_names.dart';
import 'route_paths.dart';

/// 페이드(+선택적 미세 스케일) 화면 전환 페이지.
/// reduced-motion 설정 시 전환 시간 자체를 0으로 만들어 즉시 표시한다
/// (transitionsBuilder에서 child만 즉시 반환하면 duration 동안 프레임이 얼어붙음).
CustomTransitionPage<void> _fadePage(
  BuildContext context,
  GoRouterState state,
  Widget child, {
  bool withScale = false,
}) {
  final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: reduce ? Duration.zero : AppDurations.pageFade,
    reverseTransitionDuration:
        reduce ? Duration.zero : AppDurations.pageFadeExit,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (reduce) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppCurves.enter,
        reverseCurve: AppCurves.exit,
      );
      if (!withScale) {
        return FadeTransition(opacity: curved, child: child);
      }
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// 인증 없이 접근 가능한 경로 목록
const _publicPaths = {
  RoutePaths.splash,
  RoutePaths.onboarding,
  RoutePaths.login,
  RoutePaths.signup,
  RoutePaths.emailLogin,
  RoutePaths.forgotPasswordMethod,
  RoutePaths.forgotPasswordCode,
  RoutePaths.forgotPasswordReset,
  RoutePaths.termsDetailPublic,
};

/// 앱의 라우터 설정
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    observers: [AnalyticsService.instance.observer],
    redirect: (context, state) {
      final currentPath = state.uri.path;
      final isPublicRoute = _publicPaths.contains(currentPath);

      // 스플래시는 항상 접근 가능 (초기 진입점)
      if (currentPath == RoutePaths.splash) return null;

      // TokenService가 초기화되지 않았으면 스플래시로 리다이렉트
      if (!TokenService.instance.isInitialized) {
        return RoutePaths.splash;
      }

      final isLoggedIn = TokenService.instance.isLoggedIn;

      // 비로그인 사용자가 보호된 라우트에 접근 시 로그인으로 리다이렉트
      if (!isLoggedIn && !isPublicRoute) {
        return RoutePaths.login;
      }

      // 로그인된 사용자가 인증 화면에 접근 시 홈으로 리다이렉트
      if (isLoggedIn && (currentPath == RoutePaths.login ||
          currentPath == RoutePaths.signup ||
          currentPath == RoutePaths.emailLogin ||
          currentPath == RoutePaths.onboarding)) {
        return RoutePaths.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        name: RouteNames.onboarding,
        // 스플래시 브랜드 연출이 온보딩으로 자연스럽게 디졸브되도록 페이드 전환
        pageBuilder: (context, state) =>
            _fadePage(context, state, const OnboardingScreen()),
      ),
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        // 스플래시 → 로그인 하드컷 대신 페이드 디졸브
        pageBuilder: (context, state) =>
            _fadePage(context, state, const LoginScreen()),
      ),
      GoRoute(
        path: RoutePaths.signup,
        name: RouteNames.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      StatefulShellRoute(
        builder: (context, state, navigationShell) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: BottomNavBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
            ),
          );
        },
        navigatorContainerBuilder: (context, navigationShell, children) =>
            _AnimatedBranchContainer(
          currentIndex: navigationShell.currentIndex,
          children: children,
        ),
        branches: [
          // Branch 0: 홈 탭 및 홈에서 접근하는 상세 화면들
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                name: RouteNames.home,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'notification',
                    name: RouteNames.notification,
                    builder: (context, state) => const NotificationScreen(),
                  ),
                  GoRoute(
                    path: 'profile',
                    name: RouteNames.profile,
                    builder: (context, state) => const ProfileScreen(),
                  ),
                  GoRoute(
                    path: 'pet/profile/detail',
                    name: RouteNames.petProfileDetail,
                    builder: (context, state) =>
                        const PetProfileDetailScreen(),
                  ),
                  GoRoute(
                    path: 'pet/add',
                    name: RouteNames.petAdd,
                    builder: (context, state) {
                      final extra = state.extra;
                      final map =
                          extra is Map<String, dynamic> ? extra : null;
                      return PetAddScreen(
                        petId: map?['petId'],
                        isInitialSetup: map?['isInitialSetup'] == true,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'pet/profile',
                    name: RouteNames.petProfile,
                    builder: (context, state) => const PetProfileScreen(),
                  ),
                  GoRoute(
                    path: 'food/record',
                    name: RouteNames.foodRecord,
                    builder: (context, state) => const FoodRecordScreen(),
                  ),
                  GoRoute(
                    path: 'water/record',
                    name: RouteNames.waterRecord,
                    builder: (context, state) => const WaterRecordScreen(),
                  ),
                  GoRoute(
                    path: 'wci/index',
                    name: RouteNames.wciIndex,
                    builder: (context, state) => const WciIndexScreen(),
                  ),
                  GoRoute(
                    path: 'bhi/detail',
                    name: RouteNames.bhiDetail,
                    builder: (context, state) {
                      final extra = state.extra;
                      final bhiResult =
                          extra is BhiResult ? extra : null;
                      return BhiDetailScreen(bhiResult: bhiResult);
                    },
                  ),
                  GoRoute(
                    path: 'terms/detail',
                    name: RouteNames.termsDetail,
                    builder: (context, state) {
                      final termsType = state.extra is TermsType
                          ? state.extra as TermsType
                          : TermsType.termsOfService;
                      return TermsDetailScreen(termsType: termsType);
                    },
                  ),
                  GoRoute(
                    path: 'faq',
                    name: RouteNames.faq,
                    builder: (context, state) => const FaqScreen(),
                  ),
                  GoRoute(
                    path: 'profile/setup',
                    name: RouteNames.profileSetup,
                    builder: (context, state) {
                      final extra = state.extra;
                      final map =
                          extra is Map<String, dynamic> ? extra : null;
                      return ProfileSetupScreen(
                        isInitialSetup:
                            map?['isInitialSetup'] as bool? ?? true,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'profile/setup/complete',
                    name: RouteNames.profileSetupComplete,
                    builder: (context, state) {
                      final extra = state.extra;
                      final map =
                          extra is Map<String, dynamic> ? extra : null;
                      return ProfileSetupCompleteScreen(
                        petName: map?['petName'] ?? AppLocalizations.of(context).common_defaultPetName,
                      );
                    },
                  ),
                  // 건강체크 라우트
                  GoRoute(
                    path: 'health-check',
                    name: RouteNames.healthCheck,
                    builder: (context, state) =>
                        const HealthCheckMainScreen(),
                    routes: [
                      GoRoute(
                        path: 'capture',
                        name: RouteNames.healthCheckCapture,
                        builder: (context, state) {
                          final extra = state.extra;
                          final map =
                              extra is Map<String, dynamic> ? extra : null;
                          if (map == null || map['mode'] is! VisionMode) {
                            return const HealthCheckMainScreen();
                          }
                          return HealthCheckCaptureScreen(
                            mode: map['mode'] as VisionMode,
                          );
                        },
                      ),
                      GoRoute(
                        path: 'analyzing',
                        name: RouteNames.healthCheckAnalyzing,
                        // capture → analyzing: 같은 태스크의 상태 진행이므로 페이드
                        pageBuilder: (context, state) {
                          final extra = state.extra;
                          final map =
                              extra is Map<String, dynamic> ? extra : null;
                          if (map == null ||
                              map['mode'] is! VisionMode ||
                              map['imageBytes'] is! Uint8List ||
                              map['fileName'] is! String) {
                            return _fadePage(
                                context, state, const HealthCheckMainScreen());
                          }
                          return _fadePage(
                            context,
                            state,
                            HealthCheckAnalyzingScreen(
                              mode: map['mode'] as VisionMode,
                              part: map['part'] as BodyPart?,
                              imageBytes: map['imageBytes'] as Uint8List,
                              fileName: map['fileName'] as String,
                              notes: map['notes'] as String?,
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'result',
                        name: RouteNames.healthCheckResult,
                        // analyzing → result: 이 앱의 hero moment. fade + 미세 scale로 극적 reveal
                        pageBuilder: (context, state) {
                          final extra = state.extra;
                          final map =
                              extra is Map<String, dynamic> ? extra : null;
                          if (map == null ||
                              map['mode'] is! VisionMode ||
                              map['result'] is! Map<String, dynamic>) {
                            return _fadePage(
                                context, state, const HealthCheckMainScreen());
                          }
                          return _fadePage(
                            context,
                            state,
                            HealthCheckResultScreen(
                            mode: map['mode'] as VisionMode,
                            result:
                                map['result'] as Map<String, dynamic>,
                            imageBytes:
                                map['imageBytes'] as Uint8List?,
                            imageUrl:
                                map['imageUrl'] as String?,
                            isFromHistory:
                                map['isFromHistory'] as bool? ?? false,
                            serverId:
                                map['serverId'] as String?,
                            serverConfidence:
                                map['serverConfidence'] as double?,
                            serverStatus:
                                map['serverStatus'] as String?,
                            serverCheckedAt:
                                map['serverCheckedAt'] as String?,
                            ),
                            withScale: true,
                          );
                        },
                      ),
                      GoRoute(
                        path: 'history',
                        name: RouteNames.healthCheckHistory,
                        builder: (context, state) =>
                            const HealthCheckHistoryScreen(),
                      ),
                      GoRoute(
                        path: 'vet-summary',
                        name: RouteNames.vetSummary,
                        builder: (context, state) =>
                            const VetSummaryScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Branch 1: 체중 탭 및 체중 관련 상세 화면들
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.weightDetail,
                name: RouteNames.weightDetail,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: WeightDetailScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'record',
                    name: RouteNames.weightRecord,
                    builder: (context, state) =>
                        const WeightRecordScreen(),
                  ),
                  GoRoute(
                    path: 'add/today',
                    name: RouteNames.weightAddToday,
                    builder: (context, state) =>
                        WeightAddScreen(date: DateTime.now()),
                  ),
                  GoRoute(
                    path: 'add/:date',
                    name: RouteNames.weightAdd,
                    builder: (context, state) {
                      final dateStr = state.pathParameters['date'];
                      DateTime date;
                      try {
                        date = DateTime.parse(dateStr ?? '');
                      } catch (_) {
                        date = DateTime.now();
                      }
                      return WeightAddScreen(date: date);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Branch 2: AI 백과사전 탭
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.aiEncyclopedia,
                name: RouteNames.aiEncyclopedia,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AIEncyclopediaScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      // 약관 상세 (Shell 바깥 - 회원가입에서 접근, 비로그인 허용)
      GoRoute(
        path: RoutePaths.termsDetailPublic,
        name: RouteNames.termsDetailPublic,
        builder: (context, state) {
          final termsType = state.extra is TermsType
              ? state.extra as TermsType
              : TermsType.termsOfService;
          return TermsDetailScreen(termsType: termsType);
        },
      ),
      // 인증 관련 라우트 (Shell 바깥 - 하단 네비게이션 없음)
      GoRoute(
        path: RoutePaths.emailLogin,
        name: RouteNames.emailLogin,
        builder: (context, state) => const EmailLoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPasswordMethod,
        name: RouteNames.forgotPasswordMethod,
        builder: (context, state) => const ForgotPasswordMethodScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPasswordCode,
        name: RouteNames.forgotPasswordCode,
        builder: (context, state) {
          final extra = state.extra;
          final map = extra is Map<String, dynamic> ? extra : null;
          return ForgotPasswordCodeScreen(
            method: map?['method'] ?? 'phone',
            destination: map?['destination'] ?? '',
          );
        },
      ),
      GoRoute(
        path: RoutePaths.forgotPasswordReset,
        name: RouteNames.forgotPasswordReset,
        builder: (context, state) {
          final extra = state.extra;
          final map = extra is Map<String, dynamic> ? extra : null;
          return ForgotPasswordResetScreen(
            identifier: map?['identifier'] ?? '',
            code: map?['code'] ?? '',
            method: map?['method'] ?? 'email',
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri.path}'),
      ),
    ),
  );
}

/// StatefulShellRoute의 브랜치(탭) 컨테이너.
///
/// IndexedStack처럼 모든 브랜치의 상태를 유지하되, 탭 전환 시 0ms 하드컷 대신
/// [AnimatedOpacity] 크로스페이드로 전환한다. 비활성 브랜치는 [IgnorePointer]로
/// 입력을 막고 [TickerMode]로 애니메이션을 멈춰 IndexedStack과 동일하게 동작한다.
/// reduced-motion 설정 시 전환 시간이 0이 되어 즉시 교체된다.
class _AnimatedBranchContainer extends StatelessWidget {
  const _AnimatedBranchContainer({
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (int i = 0; i < children.length; i++)
          _branch(context, i, children[i]),
      ],
    );
  }

  Widget _branch(BuildContext context, int index, Widget navigator) {
    final bool active = index == currentIndex;
    return AnimatedOpacity(
      opacity: active ? 1 : 0,
      duration: AppDurations.of(context, AppDurations.branchCrossfade),
      curve: AppCurves.enter,
      child: IgnorePointer(
        ignoring: !active,
        child: TickerMode(
          enabled: active,
          child: navigator,
        ),
      ),
    );
  }
}
