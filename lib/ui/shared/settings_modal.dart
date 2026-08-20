import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../grpc/client.dart';
import '../../discovery/lan_discovery.dart';

/// 播放器服务器连接、局域网自动发现与 TV 扫码/PIN 配对面板
class ServerSettingsModal extends StatefulWidget {
  final VoidCallback onSaved;

  const ServerSettingsModal({Key? key, required this.onSaved}) : super(key: key);

  @override
  State<ServerSettingsModal> createState() => _ServerSettingsModalState();
}

class _ServerSettingsModalState extends State<ServerSettingsModal> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: "8080");
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tokenController = TextEditingController();

  int _loginMode = 0; // 0: 账号密码, 1: Token令牌, 2: 扫码/PIN配对
  bool _isTesting = false;
  String _statusMsg = "";
  bool _isSuccess = false;

  // 局域网发现
  bool _isDiscovering = false;
  List<DiscoveredServer> _discoveredServers = [];

  // TV 配对会话
  String? _pairingSessionId;
  String? _pairingPinCode;
  String? _pairingQrUrl;
  int _pairingExpiresIn = 300;
  Timer? _pairingPollTimer;
  Timer? _pairingCountdownTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
    _startLANDiscovery();
  }

  @override
  void dispose() {
    _pairingPollTimer?.cancel();
    _pairingCountdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    final client = MediaLibClient();
    _hostController.text = client.host;
    _portController.text = client.port.toString();
    _tokenController.text = client.token;

    try {
      final prefs = await SharedPreferences.getInstance();
      _hostController.text = prefs.getString('server_host') ?? client.host;
      _portController.text = (prefs.getInt('server_port') ?? client.port).toString();
      _usernameController.text = prefs.getString('server_username') ?? "";
      _tokenController.text = prefs.getString('server_token') ?? client.token;
    } catch (_) {}
  }

  Future<void> _startLANDiscovery() async {
    setState(() {
      _isDiscovering = true;
      _discoveredServers = [];
    });
    final servers = await LANDiscoveryService.discover();
    if (mounted) {
      setState(() {
        _discoveredServers = servers;
        _isDiscovering = false;
      });
    }
  }

  void _selectDiscoveredServer(DiscoveredServer s) {
    setState(() {
      _hostController.text = s.host;
      _portController.text = s.httpPort.toString();
    });
    _testAndSave();
  }

  Future<void> _startPairingSession() async {
    _pairingPollTimer?.cancel();
    _pairingCountdownTimer?.cancel();

    final client = MediaLibClient();
    client.configure(
      host: _hostController.text.trim().isNotEmpty ? _hostController.text.trim() : "127.0.0.1",
      port: int.tryParse(_portController.text.trim()) ?? 8080,
    );

    final res = await client.startPairing();
    if (res['session_id'] != null) {
      setState(() {
        _pairingSessionId = res['session_id'];
        _pairingPinCode = res['pin_code'];
        _pairingQrUrl = res['qr_url'];
        _pairingExpiresIn = res['expire_seconds'] ?? 300;
      });

      // 倒计时
      _pairingCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_pairingExpiresIn <= 1) {
          timer.cancel();
          _pairingPollTimer?.cancel();
        } else {
          setState(() => _pairingExpiresIn--);
        }
      });

      // 轮询检查授权状态
      _pairingPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (_pairingSessionId == null) return;
        final statusRes = await client.checkPairingStatus(_pairingSessionId!);
        if (statusRes['status'] == 'authorized') {
          _pairingPollTimer?.cancel();
          _pairingCountdownTimer?.cancel();
          _onPairingSuccess(statusRes);
        }
      });
    }
  }

  Future<void> _onPairingSuccess(Map<String, dynamic> data) async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8080;
    final token = data['token'] ?? "";
    final username = data['username'] ?? "TV-User";

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_host', host);
      await prefs.setInt('server_port', port);
      await prefs.setString('server_username', username);
      await prefs.setString('server_token', token);
    } catch (_) {}

    setState(() {
      _isSuccess = true;
      _statusMsg = "🎉 TV 设备已成功配对授权！用户: $username";
    });

    widget.onSaved();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _testAndSave() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8080;
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final token = _tokenController.text.trim();

    if (host.isEmpty) {
      setState(() {
        _statusMsg = "请输入服务器 IP 或域名";
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _statusMsg = "正在连通服务器并校验身份...";
      _isSuccess = false;
    });

    final client = MediaLibClient();
    client.configure(
      host: host,
      port: port,
      token: token,
    );

    bool loginSuccess = false;
    String errorMsg = "";

    if (_loginMode == 0 && username.isNotEmpty && password.isNotEmpty) {
      final res = await client.loginPlayer(username: username, password: password);
      loginSuccess = res['success'] == true;
      if (!loginSuccess) {
        errorMsg = res['error'] ?? "账号或密码错误";
      }
    } else if (_loginMode == 1 && token.isNotEmpty) {
      final res = await client.validateToken(token);
      loginSuccess = res['valid'] == true;
      if (!loginSuccess) {
        errorMsg = "访问令牌无效或已过期";
      }
    } else {
      // 匿名探活
      final res = await client.checkHealth();
      loginSuccess = res;
      if (!loginSuccess) {
        errorMsg = "无法连接到 $host:$port，请检查服务端是否已启动";
      }
    }

    if (loginSuccess) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('server_host', host);
        await prefs.setInt('server_port', port);
        if (username.isNotEmpty) await prefs.setString('server_username', username);
        if (client.token.isNotEmpty) await prefs.setString('server_token', client.token);
      } catch (_) {}

      setState(() {
        _isTesting = false;
        _isSuccess = true;
        _statusMsg = "✅ 连接成功！已保存配置";
      });

      widget.onSaved();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      setState(() {
        _isTesting = false;
        _isSuccess = false;
        _statusMsg = "❌ 连接失败: $errorMsg";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.settings_input_component, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "服务器连接与设备配对",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 16),

              // 1. 局域网服务自动发现条
              _buildLANDiscoverySection(),
              const SizedBox(height: 16),

              // 2. 服务器地址与端口
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _hostController,
                      label: "服务器 IP / 域名",
                      hint: "如 192.168.1.100",
                      icon: Icons.dns_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _buildTextField(
                      controller: _portController,
                      label: "端口",
                      hint: "8080",
                      icon: Icons.numbers,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. 登录与配对模式选择
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabButton("账号密码", _loginMode == 0, () => setState(() => _loginMode = 0)),
                    const SizedBox(width: 8),
                    _buildTabButton("Token 令牌", _loginMode == 1, () => setState(() => _loginMode = 1)),
                    const SizedBox(width: 8),
                    _buildTabButton("📱 扫码/PIN配对", _loginMode == 2, () {
                      setState(() => _loginMode = 2);
                      _startPairingSession();
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. 模式内容
              if (_loginMode == 0) ...[
                _buildTextField(
                  controller: _usernameController,
                  label: "播放器账号",
                  hint: "输入在后台添加的播放器用户名",
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _passwordController,
                  label: "密码",
                  hint: "账号密码（未设密码可留空）",
                  icon: Icons.lock_outline,
                  obscureText: true,
                ),
              ] else if (_loginMode == 1) ...[
                _buildTextField(
                  controller: _tokenController,
                  label: "访问令牌 (Token)",
                  hint: "输入 pl_ 开头的播放器访问令牌",
                  icon: Icons.key_outlined,
                ),
              ] else if (_loginMode == 2) ...[
                _buildPairingView(),
              ],

              const SizedBox(height: 20),

              // 状态信息展示
              if (_statusMsg.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _isSuccess ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isSuccess ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _statusMsg,
                    style: TextStyle(
                      color: _isSuccess ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ),

              // 底部动作按钮
              if (_loginMode != 2)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("取消", style: TextStyle(color: AppColors.textMuted)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isTesting ? null : _testAndSave,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        _isTesting ? "正在测试..." : "测试连接并保存",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLANDiscoverySection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.radar_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    "局域网在线服务端",
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              InkWell(
                onTap: _startLANDiscovery,
                child: Row(
                  children: [
                    if (_isDiscovering)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                      )
                    else
                      const Icon(Icons.refresh, color: AppColors.textSecondary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _isDiscovering ? "探测中..." : "重新探测",
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_discoveredServers.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._discoveredServers.map((s) => InkWell(
                  onTap: () => _selectDiscoveredServer(s),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.dns, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              s.serverName,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Text(
                          s.displayAddress,
                          style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                )),
          ] else if (!_isDiscovering) ...[
            const SizedBox(height: 6),
            const Text(
              "未发现局域网广播节点，可直接在下方手动输入 IP",
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPairingView() {
    if (_pairingPinCode == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 二维码
              if (_pairingQrUrl != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: _pairingQrUrl!,
                    version: QrVersions.auto,
                    size: 110,
                  ),
                ),
              const SizedBox(width: 24),

              // PIN 码
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("快捷 6 位 PIN 码", style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Text(
                      _pairingPinCode!,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "有效期剩余: $_pairingExpiresIn 秒",
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "手机微信/浏览器扫码，或在管理后台输入此 PIN 码即可一键授权此 TV 设备",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white12,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textMuted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
