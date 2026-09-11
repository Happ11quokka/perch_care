// F05 회귀 테스트 — 코치마크는 호출한 화면이 실제로 보일 때만 뜨고, 탭/라우트가
// 바뀌면 전체 화면 배리어를 즉시 걷어내야 한다 (비활성 탭의 지연 콜백이 현재
// 화면을 덮고 터치를 삼키던 버그).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:perch_care/src/widgets/coach_mark_overlay.dart';

const _titleA = 'Coach title A';
const _bodyA = 'Coach body A';
const _tabBButton = 'Tab B button';
const _detailTitle = 'Detail A';

/// 탭 A 화면 — 코치마크 타겟을 가진 위젯. 테스트가 [key]의 context로 show()를 호출한다.
class _TabA extends StatelessWidget {
  const _TabA({required this.targetKey});
  final GlobalKey targetKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Target A', key: targetKey),
      ),
    );
  }
}

class _Harness {
  _Harness() {
    router = GoRouter(
      initialLocation: '/a',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/a',
                  builder: (_, __) => _TabA(targetKey: targetKey),
                  routes: [
                    GoRoute(
                      path: 'detail',
                      builder: (_, __) =>
                          const Scaffold(body: Center(child: Text(_detailTitle))),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/b',
                  builder: (_, __) => Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        onPressed: () => tapsOnB++,
                        child: const Text(_tabBButton),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  final targetKey = GlobalKey();
  late final GoRouter router;
  int tapsOnB = 0;
  int completed = 0;

  Widget get app => MaterialApp.router(routerConfig: router);

  /// 탭 A 서브트리의 context로 코치마크를 띄운다 (실제 화면 코드와 같은 호출 형태).
  /// 비활성 탭은 offstage라 finder로 찾을 수 없으므로 GlobalKey의 context를 쓴다.
  void show(WidgetTester tester) {
    CoachMarkOverlay.show(
      targetKey.currentContext!,
      steps: [
        CoachMarkStep(targetKey: targetKey, title: _titleA, body: _bodyA),
      ],
      nextLabel: 'Next',
      gotItLabel: 'Got it',
      skipLabel: 'Skip',
      onComplete: () => completed++,
    );
  }

  Future<void> dispose(WidgetTester tester) async {
    CoachMarkOverlay.dismiss();
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

bool _semanticsLabel(Widget w, String label) =>
    w is Semantics && w.properties.label == label;

void main() {
  // F17 회귀 — 배경 탭 영역의 접근성 라벨은 하드코딩 'Next' 가 아니라 호출자가
  // 넘긴 l10n 라벨(마지막 단계면 gotItLabel, 아니면 nextLabel)을 써야 한다.
  testWidgets('background tap area uses the localized next/got-it label', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.app);
    await _settle(tester);

    h.show(tester); // 단일 단계 → 마지막 단계
    await _settle(tester);

    // 배경 영역 + 버튼 모두 gotItLabel 을 쓴다.
    expect(
      find.byWidgetPredicate((w) => _semanticsLabel(w, 'Got it')),
      findsNWidgets(2),
    );
    expect(
      find.byWidgetPredicate((w) => _semanticsLabel(w, 'Next')),
      findsNothing,
    );
    await h.dispose(tester);
  });

  testWidgets('shows the coach mark when the calling screen is visible', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.app);
    await _settle(tester);

    h.show(tester);
    await _settle(tester);

    expect(CoachMarkOverlay.isShowing, isTrue);
    expect(find.text(_titleA), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('isContextVisible is false for an inactive shell tab', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.app);
    await _settle(tester);
    final contextA = tester.element(find.byKey(h.targetKey));
    expect(CoachMarkOverlay.isContextVisible(contextA), isTrue);

    h.router.go('/b');
    await _settle(tester);

    // 유지되는 브랜치라 위젯은 살아 있지만 화면에는 없다.
    expect(contextA.mounted, isTrue);
    expect(CoachMarkOverlay.isContextVisible(contextA), isFalse);
    await h.dispose(tester);
  });

  testWidgets(
    'does not show from an inactive tab and leaves the visible tab tappable',
    (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.app);
      await _settle(tester);

      h.router.go('/b');
      await _settle(tester);

      // 탭 A의 지연 콜백이 뒤늦게 실행된 상황을 재현.
      h.show(tester);
      await _settle(tester);

      expect(CoachMarkOverlay.isShowing, isFalse);
      expect(find.text(_titleA), findsNothing);
      // 스킵된 코치마크는 '본 것'으로 처리하지 않는다 — 다음 진입 때 다시 시도.
      expect(h.completed, 0);

      await tester.tap(find.text(_tabBButton));
      await tester.pump();
      expect(h.tapsOnB, 1, reason: 'no full-screen barrier should swallow taps');
      await h.dispose(tester);
    },
  );

  testWidgets('dismisses itself when the tab changes while shown', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.app);
    await _settle(tester);

    h.show(tester);
    await _settle(tester);
    expect(find.text(_titleA), findsOneWidget);

    h.router.go('/b');
    await _settle(tester);

    expect(CoachMarkOverlay.isShowing, isFalse);
    expect(find.text(_titleA), findsNothing);
    expect(h.completed, 0);

    await tester.tap(find.text(_tabBButton));
    await tester.pump();
    expect(h.tapsOnB, 1);
    await h.dispose(tester);
  });

  testWidgets('does not show when the screen is covered by a pushed route', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.app);
    await _settle(tester);

    h.router.go('/a/detail');
    await _settle(tester);
    expect(find.text(_detailTitle), findsOneWidget);

    h.show(tester);
    await _settle(tester);

    expect(CoachMarkOverlay.isShowing, isFalse);
    expect(find.text(_titleA), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('dismisses when a route is pushed over the calling screen', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.app);
    await _settle(tester);

    h.show(tester);
    await _settle(tester);
    expect(find.text(_titleA), findsOneWidget);

    h.router.go('/a/detail');
    await _settle(tester);

    expect(CoachMarkOverlay.isShowing, isFalse);
    expect(find.text(_titleA), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('completing the coach mark still calls onComplete', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.app);
    await _settle(tester);

    h.show(tester);
    await _settle(tester);

    await tester.tap(find.text('Got it'));
    await _settle(tester);

    expect(h.completed, 1);
    expect(CoachMarkOverlay.isShowing, isFalse);
    await h.dispose(tester);
  });
}
