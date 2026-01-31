import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'src/services/api/api_client.dart';
import 'src/services/api/token_service.dart';
import 'src/services/storage/local_image_storage_service.dart';
import 'src/router/app_router.dart';
import 'src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  KakaoSdk.init(nativeAppKey: '23f9d1f1b79cea8566c54a44ba33b463');
  await GoogleSignIn.instance.initialize(
    clientId: '351000470573-9cu20o306ho5jepgee2b474jnd0ah08b.apps.googleusercontent.com',
  );
  await TokenService.instance.init();
  await LocalImageStorageService.instance.init();
  ApiClient.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Perch Care',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: AppRouter.router,
    );
  }
}
