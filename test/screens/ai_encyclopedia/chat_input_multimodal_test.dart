import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perch_care/l10n/app_localizations.dart';
import 'package:perch_care/src/screens/ai_encyclopedia/widgets/chat_input_multimodal.dart';

/// 1×1 transparent PNG bytes — 썸네일 렌더링 테스트용 최소 데이터
final Uint8List _tinyPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ko'), Locale('en'), Locale('zh')],
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('ChatInputMultimodal', () {
    late TextEditingController controller;
    late int attachTaps;
    late int sendTaps;
    late int removeTaps;

    setUp(() {
      controller = TextEditingController();
      attachTaps = 0;
      sendTaps = 0;
      removeTaps = 0;
    });

    tearDown(() => controller.dispose());

    Widget build({
      Uint8List? image,
      bool isSending = false,
      bool isQuotaExhausted = false,
    }) {
      return _wrap(
        ChatInputMultimodal(
          controller: controller,
          isSending: isSending,
          isQuotaExhausted: isQuotaExhausted,
          onSend: () => sendTaps++,
          onAttachPressed: () => attachTaps++,
          onRemoveAttachment: () => removeTaps++,
          attachedImageBytes: image,
        ),
      );
    }

    testWidgets('이미지 없으면 썸네일 렌더링 안 함', (tester) async {
      await tester.pumpWidget(build());
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('이미지 있으면 썸네일과 제거 버튼 렌더링', (tester) async {
      await tester.pumpWidget(build(image: _tinyPng));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('+ 버튼 탭하면 onAttachPressed 호출', (tester) async {
      await tester.pumpWidget(build());
      await tester.tap(find.byIcon(Icons.add));
      expect(attachTaps, 1);
    });

    testWidgets('X 버튼 탭하면 onRemoveAttachment 호출', (tester) async {
      await tester.pumpWidget(build(image: _tinyPng));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close));
      expect(removeTaps, 1);
    });

    testWidgets('텍스트 · 이미지 둘 다 없으면 Send 탭이 onSend 호출하지 않음', (tester) async {
      await tester.pumpWidget(build());
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      expect(sendTaps, 0);
    });

    testWidgets('텍스트만 있으면 Send 탭이 onSend 호출', (tester) async {
      await tester.pumpWidget(build());
      controller.text = '안녕';
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      expect(sendTaps, 1);
    });

    testWidgets('이미지만 있으면 Send 탭이 onSend 호출', (tester) async {
      await tester.pumpWidget(build(image: _tinyPng));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      expect(sendTaps, 1);
    });

    testWidgets('isSending 이면 스피너 표시 + Send 탭 무효', (tester) async {
      await tester.pumpWidget(build(isSending: true));
      controller.text = '안녕';
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
      // 버튼 영역 탭해도 onSend 호출 안 됨
      await tester.tap(find.byType(CircularProgressIndicator));
      expect(sendTaps, 0);
    });

    testWidgets('isQuotaExhausted 이면 TextField 비활성화 + 첨부 버튼 비활성화', (tester) async {
      await tester.pumpWidget(build(isQuotaExhausted: true));
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);

      // 첨부 버튼 탭해도 callback 호출 안 됨 (onTap = null)
      await tester.tap(find.byIcon(Icons.add));
      expect(attachTaps, 0);
    });

    testWidgets('공백만 입력된 경우 Send 비활성 (이미지 없음)', (tester) async {
      await tester.pumpWidget(build());
      controller.text = '   ';
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      expect(sendTaps, 0);
    });
  });
}
