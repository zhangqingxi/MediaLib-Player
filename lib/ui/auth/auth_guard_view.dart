import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../grpc/client.dart';
import '../shared/poster_wall_view.dart';
import 'server_setup_view.dart';
import 'login_pairing_view.dart';

/// 根路由入口与状态守卫 (Auth Guard / Connection State Router)
class AuthGuardView extends StatefulWidget {
  const AuthGuardView({Key? key}) : super(key: key);

  @override
  State<AuthGuardView> createState() => _AuthGuardViewState();
}

class _AuthGuardViewState extends State<AuthGuardView> {
  final MediaLibClient _client = MediaLibClient();
  String _statusText = "正在初始化发烧影音引擎与检测服务端...";

  @override
  void initState() {
    super.initState();
    _checkAndRoute();
  }

  Future<void> _checkAndRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('server_host') ?? "127.0.0.1";
    final port = prefs.getInt('server_port') ?? 18080;
    final token = prefs.getString('server_token') ?? "";

    _client.configure(
      host: host,
      port: port,
      token: token,
      deviceName: Platform.isWindows ? "Windows-PC" : (Platform.isAndroid ? "TV-Box" : "Client"),
    );

    // 1. 检查服务器连通性
    setState(() => _statusText = "正在连接服务端 $host:$port...");
    final isAlive = await _client.checkHealth();

    if (!mounted) return;

    if (!isAlive) {
      // 服务端未配置或连不上 -> 路由至服务端配置向导页
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ServerSetupView(isInitialSetup: true)),
      );
      return;
    }

    // 2. 如果服务器连通，检查 Token 是否已登录授权
    if (token.isNotEmpty) {
      setState(() => _statusText = "正在验证播放器授权令牌...");
      final tokenCheck = await _client.validateToken(token);
      if (!mounted) return;

      if (tokenCheck['valid'] == true) {
        // 授权有效 -> 直接进入海报墙
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const PosterWallView()),
        );
        return;
      }
    }

    // 3. 未登录或 Token 已失效 -> 默认进入大屏扫码 / PIN 配对页
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginPairingView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
              ),
              child: const Icon(Icons.play_circle_filled_rounded, color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              "MediaLib Player",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _statusText,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
