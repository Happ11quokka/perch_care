import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perch_care/l10n/app_localizations.dart';
import 'package:perch_care/src/screens/forgot_password/forgot_password_code_screen.dart';

/// F08 (2026-09-09 audit): 인증 코드 6칸이 390px 폰에서 46px, 320px 폰에서
/// 116px 오른쪽으로 넘쳤다. 화면 폭·텍스트 스케일 조합에서 예외 없이
/// 6칸 모두 화면 안에 그려지는지 고정한다.
Widget buildTestScreen({
  String language = 'ko',
  double textScale = 1.0,
}) {
  return ProviderScope(
    child: MaterialApp(
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
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: const ForgotPasswordCodeScreen(
        method: 'email',
        destination: 'audit@example.invalid',
      ),
    ),
  );
}

Future<void> pumpAt(
  WidgetTester tester, {
  required Size size,
  required String language,
  required double textScale,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    buildTestScreen(language: language, textScale: textScale),
  );
  // 첫 프레임 + 포커스 post-frame 콜백까지 반영
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// 화면 dispose → 2분 타이머 정리 (pending timer 로 테스트가 실패하지 않도록)
Future<void> tearDownScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  const scenarios = <({String language, Size size, double scale})>[
    (language: 'ko', size: Size(390, 844), scale: 1.0),
    (language: 'en', size: Size(320, 568), scale: 1.0),
    (language: 'ko', size: Size(390, 844), scale: 2.0),
    (language: 'en', size: Size(320, 568), scale: 2.0),
    (language: 'zh', size: Size(390, 844), scale: 1.0),
  ];

  group('ForgotPasswordCodeScreen 코드 입력 박스 레이아웃 (F08)', () {
    for (final s in scenarios) {
      testWidgets(
        '${s.language} ${s.size.width.toInt()}x${s.size.height.toInt()} '
        'scale ${s.scale}: 예외 없이 6칸이 화면 안에 보인다',
        (tester) async {
          await pumpAt(
            tester,
            size: s.size,
            language: s.language,
            textScale: s.scale,
          );

          expect(tester.takeException(), isNull);

          final boxes = find.byType(TextField);
          expect(boxes, findsNWidgets(6));
          // 작은 화면 + 큰 글자에서는 안내 문구가 길어져 박스가 스크롤 아래에
          // 놓일 수 있다(정상). 스크롤로 노출한 뒤 화면 경계를 검사한다.
          await tester.ensureVisible(boxes.at(0));
          await tester.pump();
          expect(tester.takeException(), isNull);

          final rects = List.generate(6, (i) => tester.getRect(boxes.at(i)));
          for (var i = 0; i < rects.length; i++) {
            final r = rects[i];
            expect(r.left, greaterThanOrEqualTo(0), reason: 'box $i left');
            expect(
              r.right,
              lessThanOrEqualTo(s.size.width),
              reason: 'box $i right edge must stay inside ${s.size.width}',
            );
            expect(r.top, greaterThanOrEqualTo(0), reason: 'box $i top');
            expect(
              r.bottom,
              lessThanOrEqualTo(s.size.height),
              reason: 'box $i bottom',
            );
            // 정사각형 유지
            expect(r.width, moreOrLessEquals(r.height, epsilon: 0.01));
            // 박스는 서로 겹치지 않고 왼쪽→오른쪽 순서
            if (i > 0) {
              expect(
                r.left,
                greaterThanOrEqualTo(rects[i - 1].right),
                reason: 'box $i overlaps box ${i - 1}',
              );
            }
          }

          // 모두 한 줄에 동일 크기
          final first = rects.first;
          for (final r in rects) {
            expect(r.top, moreOrLessEquals(first.top, epsilon: 0.01));
            expect(r.width, moreOrLessEquals(first.width, epsilon: 0.01));
          }

          await tearDownScreen(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('390px: 박스는 52px 상한 이하로 축소되고 간격이 먼저 줄어든다', (
      tester,
    ) async {
      await pumpAt(
        tester,
        size: const Size(390, 844),
        language: 'ko',
        textScale: 1.0,
      );
      final boxes = find.byType(TextField);
      final r0 = tester.getRect(boxes.at(0));
      final r1 = tester.getRect(boxes.at(1));
      expect(r0.width, lessThanOrEqualTo(52));
      expect(r0.width, greaterThan(40));
      final gap = r1.left - r0.right;
      expect(gap, greaterThanOrEqualTo(6));
      expect(gap, lessThan(12));
      await tearDownScreen(tester);
    });

    testWidgets('태블릿(800px): 박스가 52px 상한을 넘지 않는다', (tester) async {
      await pumpAt(
        tester,
        size: const Size(800, 1200),
        language: 'ko',
        textScale: 1.0,
      );
      expect(tester.takeException(), isNull);
      final boxes = find.byType(TextField);
      final r0 = tester.getRect(boxes.at(0));
      final r1 = tester.getRect(boxes.at(1));
      expect(r0.width, moreOrLessEquals(52, epsilon: 0.01));
      expect(r1.left - r0.right, moreOrLessEquals(12, epsilon: 0.01));
      await tearDownScreen(tester);
    });

    testWidgets('입력 시 다음 칸으로 포커스가 이동한다 (기존 동작 유지)', (tester) async {
      await pumpAt(
        tester,
        size: const Size(390, 844),
        language: 'ko',
        textScale: 1.0,
      );
      final boxes = find.byType(TextField);
      expect(tester.widget<TextField>(boxes.at(0)).focusNode!.hasFocus, isTrue);
      await tester.enterText(boxes.at(0), '1');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.widget<TextField>(boxes.at(1)).focusNode!.hasFocus, isTrue);
      expect(tester.widget<TextField>(boxes.at(0)).controller!.text, '1');
      await tearDownScreen(tester);
    });
  });
}
