import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/durations.dart';

/// 탭 가능한 요소에 눌림(scale-down) 피드백을 주는 공용 래퍼.
///
/// 그라데이션·그림자 등 커스텀 데코레이션을 가진 Container처럼 Material 리플을
/// 적용하기 어려운 곳에서도 동작한다. `MediaQuery`의 reduced-motion 설정을
/// 존중하며(설정 시 스케일 애니메이션을 즉시 스킵), 탭 시 선택적으로 햅틱을 준다.
///
/// 리플이 어울리는 단순 표면에는 `InkWell`/`InkResponse`를 직접 쓰는 편이 낫다.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.enableHaptic = false,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 눌렀을 때 축소 비율 (기본 0.97).
  final double pressedScale;

  /// 탭 시 `HapticFeedback.lightImpact()` 여부 (기본 false).
  final bool enableHaptic;

  final HitTestBehavior behavior;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  bool get _interactive =>
      widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (!_interactive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.enableHaptic) HapticFeedback.lightImpact();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      onTapDown: _interactive ? (_) => _setPressed(true) : null,
      onTapUp: _interactive ? (_) => _setPressed(false) : null,
      onTapCancel: _interactive ? () => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: AppDurations.of(context, AppDurations.press),
        curve: AppCurves.enter,
        child: widget.child,
      ),
    );
  }
}
