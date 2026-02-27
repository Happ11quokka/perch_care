import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:perch_care/l10n/app_localizations.dart';
import 'package:perch_care/src/screens/faq/faq_screen.dart';

/// FaqScreen을 테스트 가능한 환경으로 감싸는 헬퍼
Widget buildTestFaqScreen({Locale locale = const Locale('ko')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ko'), Locale('en'), Locale('zh')],
    home: const FaqScreen(),
  );
}

void main() {
  group('Feature 7: FAQ 화면 테스트', () {
    testWidgets('7.1 FAQ 제목 렌더링', (tester) async {
      await tester.pumpWidget(buildTestFaqScreen());
      await tester.pumpAndSettle();

      // 한국어 기준 FAQ 제목
      expect(find.text('자주 묻는 질문'), findsOneWidget);
    });

    testWidgets('7.2 처음 보이는 카테고리 헤더 렌더링', (tester) async {
      await tester.pumpWidget(buildTestFaqScreen());
      await tester.pumpAndSettle();

      // ListView.builder는 화면에 보이는 항목만 렌더링하므로
      // 처음 보이는 카테고리들만 확인
      expect(find.text('일반'), findsOneWidget);
      expect(find.text('기능 사용법'), findsOneWidget);
    });

    testWidgets('7.2b 스크롤 후 나머지 카테고리 헤더 렌더링', (tester) async {
      await tester.pumpWidget(buildTestFaqScreen());
      await tester.pumpAndSettle();

      // 아래로 스크롤하여 나머지 카테고리 확인
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // 스크롤 후 보이는 카테고리 확인
      expect(
        find.text('계정 관리'),
        findsOneWidget,
        reason: '스크롤 후 계정 관리 카테고리가 보여야 함',
      );
    });

    testWidgets('7.3 화면에 보이는 ExpansionTile 존재 확인', (tester) async {
      await tester.pumpWidget(buildTestFaqScreen());
      await tester.pumpAndSettle();

      // ListView.builder는 화면에 보이는 항목만 렌더링
      // 최소 첫 번째 카테고리의 3개 + 두 번째 카테고리 일부가 보여야 함
      final tiles = find.byType(ExpansionTile);
      expect(tiles, findsAtLeast(3));
    });

    testWidgets('7.5 ExpansionTile 탭 → 답변 텍스트 표시', (tester) async {
      await tester.pumpWidget(buildTestFaqScreen());
      await tester.pumpAndSettle();

      // 첫 번째 질문 찾기 - ExpansionTile의 첫 번째 항목
      final firstTile = find.byType(ExpansionTile).first;

      // 탭하여 펼치기
      await tester.tap(firstTile);
      await tester.pumpAndSettle();

      // 펼침 후 답변 텍스트가 보여야 함 (위젯 트리에 존재)
      // 답변은 ExpansionTile의 children에 포함됨
      // 최소 하나의 답변 텍스트가 존재하는지 확인
      final expandedContent = find.descendant(
        of: firstTile,
        matching: find.byType(Text),
      );
      // 질문(title) + 답변(children) = 최소 2개 Text
      expect(expandedContent, findsAtLeast(2));
    });

    testWidgets('7.6 영어 로캘로 FAQ 렌더링', (tester) async {
      await tester.pumpWidget(buildTestFaqScreen(locale: const Locale('en')));
      await tester.pumpAndSettle();

      // 영어 FAQ 제목
      expect(find.text('FAQ'), findsOneWidget);
    });

    testWidgets('7.7 중국어 로캘로 FAQ 렌더링', (tester) async {
      await tester.pumpWidget(buildTestFaqScreen(locale: const Locale('zh')));
      await tester.pumpAndSettle();

      // 중국어 FAQ 제목
      expect(find.text('常见问题'), findsOneWidget);
    });
  });
}
