// Temporary scratch — delete after use.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:perch_care/src/router/app_router.dart';
import 'package:perch_care/src/services/api/token_service.dart';
import 'frontend_probe_test.dart' as probe;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(Uint8List(0));
    final fontFile = File('/System/Library/Fonts/AppleSDGothicNeo.ttc');
    final loader = FontLoader('Pretendard')
      ..addFont(Future.value(ByteData.sublistView(await fontFile.readAsBytes())));
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
    SharedPreferences.setMockInitialValues(probe.preferences());
  });
  final targets = <String, List<(String, double, double, double)>>{
    'home': [('en', 320, 568, 1), ('ko', 390, 844, 2)],
    'bhi-detail': [('en', 320, 568, 1)],
    'vet-summary': [('en', 320, 568, 1), ('ko', 390, 844, 2)],
    'profile': [('ko', 390, 844, 2)],
    'pet-add': [('ko', 390, 844, 2)],
    'health-check-capture': [('ko', 390, 844, 2)],
    'email-login': [('ko', 390, 844, 2)],
  };
  testWidgets('scratch overflow details', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final config = AppRouter.router.configuration;
    final all = probe.routes(config.routes).toList();
    for (final entry in targets.entries) {
      final item = all.firstWhere((r) => r.name == entry.key);
      for (final s in entry.value) {
        tester.view.physicalSize = Size(s.$2, s.$3);
        final f = probe.Fixtures();
        final router = GoRouter(
          routes: config.routes,
          initialLocation: item.path,
          initialExtra: probe.extraFor(item.name),
        );
        final previous = FlutterError.onError;
        final out = StringBuffer();
        FlutterError.onError = (details) {
          final text = details.toString();
          final lines = text.split('\n');
          final keep = lines.where((l) =>
              l.contains('overflowed') ||
              l.contains('error-causing widget') ||
              l.contains('file:///') ||
              l.contains('constraints') ||
              l.contains('size:') && l.contains('Size(') ||
              l.contains('direction') ).take(12).join('\n');
          out.writeln('--- ${item.name} ${s.$1} ${s.$2}x${s.$3} x${s.$4}');
          out.writeln(keep);
        };
        try {
          await tester.pumpWidget(probe.app(router, f, language: s.$1, scale: s.$4));
          await probe.frames(tester);
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
          await probe.frames(tester);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
        } finally {
          FlutterError.onError = previous;
          router.dispose();
        }
        debugPrint(out.toString());
      }
    }
  });
}
