import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../grpc/client.dart';
import '../shared/poster_wall_view.dart';
import 'server_setup_view.dart';

/// 登录与大屏/桌面扫码配对页 (Login & QR/PIN Device Pairing View)
class LoginPairingView extends StatefulWidget {
  const LoginPairingView({Key? key}) : super(key: key);

  @override
  State<LoginPairingView> createState() => _LoginPairingViewState();
}

class _LoginPairingViewState extends State<LoginPairingView> {
  final MediaLibClient _client = MediaLibClient();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  int _selectedTab = 0; // 0: 扫码/PIN码配对 (默认), 1: 账号密码登录, 2: Token 直连

  // 配对状态
  String _pairingSessionId = "";
  String _pairingPinCode = "";
  String _pairingQrUrl = "";
  int _expireSecondsRemaining = 300;
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  bool _isLoadingPairing = true;

  // 账号登录状态
  bool _isLoggingIn = false;
  String _authErrorMessage = "";

  @override
  void initState() {
    super.initState();
    _startPairingSession();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _startPairingSession() async {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();

    setState(() {
      _isLoadingPairing = true;
      _authErrorMessage = "";
      _expireSecondsRemaining = 300;
    });

    final res = await _client.startPairing();
    if (!mounted) return;

    if (res['session_id'] != null && res['pin_code'] != null) {
      final sessId = res['session_id'].toString();
      final pin = res['pin_code'].toString();
      final qrUrl = "${_client.baseUrl}/api/player/pair/authorize?session_id=$sessId&pin=$pin";

      setState(() {
        _pairingSessionId = sessId;
        _pairingPinCode = pin;
        _pairingQrUrl = qrUrl;
        _isLoadingPairing = false;
      });

      // 启动 2 秒一次的轮询
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollPairingStatus());

      // 倒计时定时器
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_expireSecondsRemaining <= 1) {
          timer.cancel();
          _pollingTimer?.cancel();
          if (mounted) setState(() => _expireSecondsRemaining = 0);
        } else {
          if (mounted) setState(() => _expireSecondsRemaining--);
        }
      });
    } else {
      setState(() {
        _isLoadingPairing = false;
        _authErrorMessage = res['error'] ?? "获取配对会话失败，请检查服务器连接。";
      });
    }
  }

  Future<void> _pollPairingStatus() async {
    if (_pairingSessionId.isEmpty) return;
    final res = await _client.checkPairingStatus(_pairingSessionId);
    if (!mounted) return;

    if (res['status'] == 'authorized' && res['token'] != null) {
      _pollingTimer?.cancel();
      _countdownTimer?.cancel();

      final token = res['token'].toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_token', token);

      // 进入发烧级海报墙主页
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PosterWallView()),
      );
    }
  }

  Future<void> _handlePasswordLogin() async {
    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();
    if (user.isEmpty || pass.isEmpty) {
      setState(() => _authErrorMessage = "请输入播放器账号与密码");
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _authErrorMessage = "";
    });

    final res = await _client.loginPlayer(username: user, password: pass);
    if (!mounted) return;

    if (res['success'] == true) {
      final token = res['token'].toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_token', token);

      setState(() => _isLoggingIn = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PosterWallView()),
      );
    } else {
      setState(() {
        _isLoggingIn = false;
        _authErrorMessage = res['error'] ?? "登录认证失败";
      });
    }
  }

  Future<void> _handleTokenLogin() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _authErrorMessage = "请输入播放器专属授权令牌 (Token)");
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _authErrorMessage = "";
    });

    final check = await _client.validateToken(token);
    if (!mounted) return;

    if (check['valid'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_token', token);

      setState(() => _isLoggingIn = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PosterWallView()),
      );
    } else {
      setState(() {
        _isLoggingIn = false;
        _authErrorMessage = "令牌无效或已被禁用，请重新生成";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 760;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 顶部微光
          Positioned(
            left: MediaQuery.of(context).size.width * 0.3,
            top: -150,
            child: Container(
              width: 500,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 顶部状态栏与切换服务器按钮
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.play_circle_filled_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "MediaLib Player",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: Colors.white.withOpacity(0.15)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          _pollingTimer?.cancel();
                          _countdownTimer?.cancel();
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const ServerSetupView(isInitialSetup: false)),
                          );
                        },
                        icon: const Icon(Icons.dns_outlined, size: 16, color: AppColors.primary),
                        label: Text("服务器: ${_client.host}:${_client.port}", style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                // 主认证卡片
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        width: isDesktop ? 760 : double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.85),
                              blurRadius: 36,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // 标题与切换 Tab
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildTabButton(0, "📱 手机扫码 / PIN 授权 (推荐)"),
                                const SizedBox(width: 12),
                                _buildTabButton(1, "🔑 账号密码登录"),
                                const SizedBox(width: 12),
                                _buildTabButton(2, "🎟️ Token 直连"),
                              ],
                            ),
                            const Divider(color: Colors.white12, height: 36),

                            if (_authErrorMessage.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.danger.withOpacity(0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _authErrorMessage,
                                        style: const TextStyle(color: AppColors.danger, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // 内容区根据 Tab 切换
                            if (_selectedTab == 0)
                              _buildQrAndPinPairingSection(isDesktop)
                            else if (_selectedTab == 1)
                              _buildPasswordLoginSection()
                            else
                              _buildTokenLoginSection(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
          _authErrorMessage = "";
        });
        if (index == 0 && _pairingPinCode.isEmpty) {
          _startPairingSession();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  /// 1. 扫码与 PIN 码配对面板
  Widget _buildQrAndPinPairingSection(bool isDesktop) {
    if (_isLoadingPairing) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text("正在生成 TV / 桌面设备配对凭据...", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    if (_expireSecondsRemaining <= 0) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.timer_off_outlined, color: AppColors.danger, size: 48),
            const SizedBox(height: 12),
            const Text("配对二维码与 PIN 码已过期", style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
              onPressed: _startPairingSession,
              icon: const Icon(Icons.refresh),
              label: const Text("重新生成配对码"),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 左侧：高清二维码
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: _pairingQrUrl.isNotEmpty
              ? QrImageView(
                  data: _pairingQrUrl,
                  version: QrVersions.auto,
                  size: 180.0,
                  backgroundColor: Colors.white,
                )
              : const SizedBox(width: 180, height: 180),
        ),
        const SizedBox(width: 32),

        // 右侧：6 位 PIN 码与指引
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "手机扫码或输入 PIN 码极速授权",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "无需在电视或电脑上繁琐输入密码，打开手机 App 扫码，或在网页端直接输入下方 6 位配对码：",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),

              // 6 位大字 PIN 码
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _pairingPinCode.length == 6
                          ? "${_pairingPinCode.substring(0, 3)} ${_pairingPinCode.substring(3)}"
                          : _pairingPinCode,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.0,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "等待授权中... 有效期剩余 ${_expireSecondsRemaining ~/ 60}分${_expireSecondsRemaining % 60}秒",
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
                    tooltip: "刷新二维码",
                    onPressed: _startPairingSession,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 2. 账号密码登录面板
  Widget _buildPasswordLoginSection() {
    return Column(
      children: [
        TextField(
          controller: _usernameController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: "播放器账号 (Username)",
            hintText: "admin 或您的播放器用户名",
            prefixIcon: const Icon(Icons.person, color: AppColors.primary),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: "播放器密码 (Password)",
            prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoggingIn ? null : _handlePasswordLogin,
            child: _isLoggingIn
                ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                : const Text("登录并进入海报墙", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  /// 3. Token 直连面板
  Widget _buildTokenLoginSection() {
    return Column(
      children: [
        TextField(
          controller: _tokenController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: "播放器专属令牌 (Token)",
            hintText: "在服务端后台「播放器对接」复制生成的 Token",
            prefixIcon: const Icon(Icons.vpn_key, color: AppColors.primary),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoggingIn ? null : _handleTokenLogin,
            child: _isLoggingIn
                ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                : const Text("校验令牌并接入", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ],
    );
  }
}
