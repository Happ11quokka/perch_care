import 'package:flutter/material.dart';
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
import '../services/api/token_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'route_names.dart';
import 'route_paths.dart';

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
};

/// 앱의 라우터 설정
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = TokenService.instance.isLoggedIn;
      final currentPath = state.uri.path;
      final isPublicRoute = _publicPaths.contains(currentPath);

      // 스플래시는 항상 접근 가능 (초기 진입점)
      if (currentPath == RoutePaths.splash) return null;

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
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.signup,
        name: RouteNames.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      StatefulShellRoute.indexedStack(
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
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                name: RouteNames.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.weightDetail,
                name: RouteNames.weightDetail,
                builder: (context, state) => const WeightDetailScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.aiEncyclopedia,
                name: RouteNames.aiEncyclopedia,
                builder: (context, state) => const AIEncyclopediaScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.weightRecord,
        name: RouteNames.weightRecord,
        builder: (context, state) => const WeightRecordScreen(),
      ),
      GoRoute(
        path: RoutePaths.weightAddToday,
        name: RouteNames.weightAddToday,
        builder: (context, state) => WeightAddScreen(date: DateTime.now()),
      ),
      GoRoute(
        path: RoutePaths.weightAdd,
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
      GoRoute(
        path: RoutePaths.foodRecord,
        name: RouteNames.foodRecord,
        builder: (context, state) => const FoodRecordScreen(),
      ),
      GoRoute(
        path: RoutePaths.waterRecord,
        name: RouteNames.waterRecord,
        builder: (context, state) => const WaterRecordScreen(),
      ),
      GoRoute(
        path: RoutePaths.petAdd,
        name: RouteNames.petAdd,
        builder: (context, state) {
          final extra = state.extra;
          final map = extra is Map<String, dynamic> ? extra : null;
          return PetAddScreen(petId: map?['petId']);
        },
      ),
      GoRoute(
        path: RoutePaths.petProfile,
        name: RouteNames.petProfile,
        builder: (context, state) => const PetProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.notification,
        name: RouteNames.notification,
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: RoutePaths.profile,
        name: RouteNames.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.petProfileDetail,
        name: RouteNames.petProfileDetail,
        builder: (context, state) => const PetProfileDetailScreen(),
      ),
      GoRoute(
        path: RoutePaths.wciIndex,
        name: RouteNames.wciIndex,
        builder: (context, state) => const WciIndexScreen(),
      ),
      GoRoute(
        path: RoutePaths.bhiDetail,
        name: RouteNames.bhiDetail,
        builder: (context, state) {
          final extra = state.extra;
          final bhiResult = extra is BhiResult ? extra : null;
          return BhiDetailScreen(bhiResult: bhiResult);
        },
      ),
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
      GoRoute(
        path: RoutePaths.profileSetup,
        name: RouteNames.profileSetup,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: RoutePaths.profileSetupComplete,
        name: RouteNames.profileSetupComplete,
        builder: (context, state) {
          final extra = state.extra;
          final map = extra is Map<String, dynamic> ? extra : null;
          return ProfileSetupCompleteScreen(
            petName: map?['petName'] ?? '점점이',
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
