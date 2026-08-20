import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Android TV 遥控器 D-Pad 全局按键捕获与焦点控制器
class TVNavigationWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onPlayPausePressed;
  final VoidCallback? onBackPressed;

  const TVNavigationWrapper({
    Key? key,
    required this.child,
    this.onMenuPressed,
    this.onPlayPausePressed,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          // 1. 遥控器 Menu 菜单键
          if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
              event.logicalKey == LogicalKeyboardKey.keyM) {
            onMenuPressed?.call();
            return KeyEventResult.handled;
          }

          // 2. 遥控器 Play/Pause 多媒体键
          if (event.logicalKey == LogicalKeyboardKey.mediaPlayPause ||
              event.logicalKey == LogicalKeyboardKey.mediaPlay ||
              event.logicalKey == LogicalKeyboardKey.mediaPause) {
            onPlayPausePressed?.call();
            return KeyEventResult.handled;
          }

          // 3. 返回键
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (onBackPressed != null) {
              onBackPressed!();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
