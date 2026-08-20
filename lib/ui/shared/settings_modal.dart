import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../grpc/client.dart';

/// 播放器服务器连接与账号登录设置面板
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

  bool _useTokenOnly = false;
  bool _isTesting = false;
  String _statusMsg = "";
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
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

    if (!_useTokenOnly && username.isNotEmpty && password.isNotEmpty) {
      final res = await client.loginPlayer(username: username, password: password);
      loginSuccess = res['success'] == true;
      if (!loginSuccess) {
        errorMsg = res['error'] ?? "账号或密码错误";
      }
    } else if (token.isNotEmpty) {
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
      Future.delayed(const Duration(milliseconds: 900), () {
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
        width: 480,
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
                        "服务器连接与账号设置",
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
              const SizedBox(height: 20),

              // 服务器地址与端口
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _hostController,
                      label: "服务器 IP / 域名",
                      hint: "如 192.168.1.100 或 127.0.0.1",
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

              // 登录模式切换
              Row(
                children: [
                  _buildTabButton("账号密码登录", !_useTokenOnly, () => setState(() => _useTokenOnly = false)),
                  const SizedBox(width: 10),
                  _buildTabButton("Token 令牌登录", _useTokenOnly, () => setState(() => _useTokenOnly = true)),
                ],
              ),
              const SizedBox(height: 16),

              // 账号密码模式
              if (!_useTokenOnly) ...[
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
              ] else ...[
                _buildTextField(
                  controller: _tokenController,
                  label: "访问令牌 (Token)",
                  hint: "输入 pl_ 开头的播放器访问令牌",
                  icon: Icons.key_outlined,
                ),
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
