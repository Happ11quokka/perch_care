import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/signup/signup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/weight/weight_detail_screen.dart';
import '../screens/weight/weight_add_screen.dart';
import '../screens/pet/pet_add_screen.dart';
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
        path: RoutePaths.petAdd,
        name: RouteNames.petAdd,
        builder: (context, state) => const PetAddScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri.path}'),
      ),
    ),
  );
}
