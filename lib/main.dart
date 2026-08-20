import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'core/constants.dart';
import 'ui/auth/auth_guard_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化发烧级 media_kit 播放引擎 (集成 libmpv / libplacebo / libbluray)
  MediaKit.ensureInitialized();

  // 2. PC 桌面端窗口设置 (无边框暗黑发烧级窗口)
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(960, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: "MediaLib Player",
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MediaLibPlayerApp());
}

class MediaLibPlayerApp extends StatelessWidget {
  const MediaLibPlayerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediaLib Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          background: AppColors.background,
        ),
        fontFamily: Platform.isWindows ? 'Microsoft YaHei' : null,
      ),
      home: const AuthGuardView(),
    );
  }
}
