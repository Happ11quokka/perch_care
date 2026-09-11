import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perch_care/src/theme/app_theme.dart';
import 'package:perch_care/src/theme/typography.dart';

/// AppTheme이 지정하는 Pretendard가 실제로 번들에 들어있어야 한다 — 감사 F17.
///
/// 등록 없이 fontFamily만 지정하면 조용히 시스템 서체로 대체되어 시안과 자간·
/// 굵기가 달라진다. pubspec의 fonts 항목이 사라지면 이 테스트가 실패한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const weights = {
    'Regular': FontWeight.w400,
    'Medium': FontWeight.w500,
    'SemiBold': FontWeight.w600,
    'Bold': FontWeight.w700,
  };

  test('테마의 fontFamily는 Pretendard다', () {
    expect(AppTypography.fontFamily, 'Pretendard');
    expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, 'Pretendard');
    expect(AppTheme.dark.textTheme.bodyMedium?.fontFamily, 'Pretendard');
  });

  group('번들에 폰트 자산이 존재한다', () {
    for (final entry in weights.entries) {
      test('Pretendard-${entry.key}.otf', () async {
        final data =
            await rootBundle.load('assets/fonts/Pretendard-${entry.key}.otf');
        // OTF(CFF) 시그니처: 'OTTO'
        expect(data.lengthInBytes, greaterThan(100000));
        final tag = String.fromCharCodes(
          data.buffer.asUint8List(data.offsetInBytes, 4),
        );
        expect(tag, 'OTTO');
      });
    }
  });

  testWidgets('앱에서 쓰는 4개 굵기를 모두 렌더할 수 있다', (tester) async {
    final loader = FontLoader('Pretendard');
    for (final name in weights.keys) {
      loader.addFont(rootBundle.load('assets/fonts/Pretendard-$name.otf'));
    }
    await loader.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              for (final w in weights.values)
                Text('가나다 ABC 123', style: TextStyle(fontWeight: w)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('가나다 ABC 123'), findsNWidgets(weights.length));
    // 굵기별로 폭이 달라야 실제 서체가 적용된 것이다(단일 폴백이면 동일해진다).
    final widths = tester
        .widgetList<Text>(find.text('가나다 ABC 123'))
        .map((t) => tester.getSize(find.byWidget(t)).width)
        .toSet();
    expect(widths.length, greaterThan(1));
  });

  test('OFL 라이선스 파일을 함께 배포한다', () async {
    final license =
        await rootBundle.loadString('assets/fonts/LICENSE-Pretendard.txt');
    expect(license, contains('SIL Open Font License'));
    expect(license, contains('Pretendard'));
  });
}
