import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// 안전한 뒤로가기 헬퍼.
///
/// 딥링크·앱 재시작·`initialLocation` 등으로 화면에 **직접 진입**하면 네비게이션
/// 스택에 pop할 페이지가 없어 `context.pop()`이 `GoError: There is nothing to pop`
/// 을 던진다. 이 확장은 pop 가능 여부를 먼저 확인하고, 불가능하면 `fallbackPath`
/// 로 `go()`한다 (기존 login/weight/water 화면의 `canPop ? pop : go` 패턴 공용화).
extension SafeBackNavigation on BuildContext {
  /// pop 가능하면 pop, 아니면 [fallbackPath]로 이동한다.
  void popOrGo(String fallbackPath) {
    if (canPop()) {
      pop();
    } else {
      go(fallbackPath);
    }
  }
}
