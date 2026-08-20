import 'package:media_kit/media_kit.dart';

enum BluRayColorButton {
  red,
  green,
  yellow,
  blue,
}

/// BD-J (Java) 与 HDMV 原盘菜单级交互控制器
class BluRayMenuController {
  final Player player;

  BluRayMenuController(this.player);

  /// 呼出顶层主菜单 (Top Menu)
  Future<void> showTopMenu() async {
    try {
      // 触发 libbluray / mpv discnav 导航命令
      await (player.platform as dynamic)?.command(["discnav", "menu"]);
    } catch (_) {}
  }

  /// 呼出弹出式菜单 (Pop-up Menu)
  Future<void> showPopupMenu() async {
    try {
      await (player.platform as dynamic)?.command(["discnav", "popup"]);
    } catch (_) {}
  }

  /// 菜单光标上移
  Future<void> navigateUp() async {
    try {
      await (player.platform as dynamic)?.command(["discnav", "up"]);
    } catch (_) {}
  }

  /// 菜单光标下移
  Future<void> navigateDown() async {
    try {
      await (player.platform as dynamic)?.command(["discnav", "down"]);
    } catch (_) {}
  }

  /// 菜单光标左移
  Future<void> navigateLeft() async {
    try {
      await (player.platform as dynamic)?.command(["discnav", "left"]);
    } catch (_) {}
  }

  /// 菜单光标右移
  Future<void> navigateRight() async {
    try {
      await (player.platform as dynamic)?.command(["discnav", "right"]);
    } catch (_) {}
  }

  /// 确认/激活选中的菜单项
  Future<void> activateSelection() async {
    try {
      await (player.platform as dynamic)?.command(["discnav", "select"]);
    } catch (_) {}
  }

  /// 触发 BD-J 彩色功能按键 (红/绿/黄/蓝)
  Future<void> pressColorButton(BluRayColorButton button) async {
    try {
      await (player.platform as dynamic)?.command(["discnav", button.name]);
    } catch (_) {}
  }
}
