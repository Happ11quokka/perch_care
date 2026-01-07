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
import '../screens/food/food_record_screen.dart';
import '../screens/water/water_record_screen.dart';
import '../screens/forgot_password/forgot_password_method_screen.dart';
import '../screens/forgot_password/forgot_password_code_screen.dart';
import '../screens/forgot_password/forgot_password_reset_screen.dart';
import '../screens/profile_setup/profile_setup_screen.dart';
import '../screens/profile_setup/profile_setup_complete_screen.dart';
import 'route_names.dart';
import 'route_paths.dart';

/// 앱의 라우터 설정
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
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
      GoRoute(
        path: RoutePaths.home,
        name: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.weightDetail,
        name: RouteNames.weightDetail,
        builder: (context, state) => const WeightRecordScreen(),
      ),
      GoRoute(
        path: RoutePaths.weightChart,
        name: RouteNames.weightChart,
        builder: (context, state) => const WeightDetailScreen(),
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
          final dateStr = state.pathParameters['date']!;
          final date = DateTime.parse(dateStr);
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
          final extra = state.extra as Map<String, dynamic>?;
          return PetAddScreen(petId: extra?['petId']);
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
        path: RoutePaths.aiEncyclopedia,
        name: RouteNames.aiEncyclopedia,
        builder: (context, state) => const AIEncyclopediaScreen(),
      ),
      GoRoute(
        path: RoutePaths.wciIndex,
        name: RouteNames.wciIndex,
        builder: (context, state) => const WciIndexScreen(),
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
          final extra = state.extra as Map<String, dynamic>?;
          return ForgotPasswordCodeScreen(
            method: extra?['method'] ?? 'phone',
            destination: extra?['destination'] ?? '',
          );
        },
      ),
      GoRoute(
        path: RoutePaths.forgotPasswordReset,
        name: RouteNames.forgotPasswordReset,
        builder: (context, state) => const ForgotPasswordResetScreen(),
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
          final extra = state.extra as Map<String, dynamic>?;
          return ProfileSetupCompleteScreen(
            petName: extra?['petName'] ?? '점점이',
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
