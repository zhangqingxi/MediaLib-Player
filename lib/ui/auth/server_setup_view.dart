import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../grpc/client.dart';
import '../../discovery/lan_discovery.dart';
import 'login_pairing_view.dart';

/// 服务端连接配置向导页 (Server Connection & LAN Radar Setup)
class ServerSetupView extends StatefulWidget {
  final bool isInitialSetup;

  const ServerSetupView({Key? key, this.isInitialSetup = true}) : super(key: key);

  @override
  State<ServerSetupView> createState() => _ServerSetupViewState();
}

class _ServerSetupViewState extends State<ServerSetupView> with SingleTickerProviderStateMixin {
  final TextEditingController _hostController = TextEditingController(text: "127.0.0.1");
  final TextEditingController _portController = TextEditingController(text: "18080");

  final MediaLibClient _client = MediaLibClient();
  List<DiscoveredServer> _discoveredServers = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  String _errorMessage = "";

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _loadExistingConfig();
    _startRadarScan();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final h = prefs.getString('server_host') ?? "127.0.0.1";
    final p = prefs.getInt('server_port') ?? 18080;
    if (mounted) {
      setState(() {
        _hostController.text = h;
        _portController.text = p.toString();
      });
    }
  }

  Future<void> _startRadarScan() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _errorMessage = "";
    });

    try {
      final servers = await LANDiscoveryService.discover(
        timeout: const Duration(milliseconds: 2500),
      );
      if (mounted) {
        setState(() {
          _discoveredServers = servers;
          _isScanning = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _testAndConnect({String? host, int? port}) async {
    final targetHost = (host ?? _hostController.text).trim();
    final targetPort = port ?? int.tryParse(_portController.text.trim()) ?? 18080;

    if (targetHost.isEmpty) {
      setState(() => _errorMessage = "请输入有效的服务端 IP 地址或主机名");
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = "";
    });

    _client.configure(
      host: targetHost,
      port: targetPort,
      deviceName: Platform.isWindows ? "Windows-PC" : (Platform.isAndroid ? "TV-Box" : "Client"),
    );

    final isOk = await _client.checkHealth();

    if (!mounted) return;

    if (isOk) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_host', targetHost);
      await prefs.setInt('server_port', targetPort);

      setState(() => _isConnecting = false);

      // 进入登录/扫码配对页
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPairingView()),
      );
    } else {
      setState(() {
        _isConnecting = false;
        _errorMessage = "无法连接至 $targetHost:$targetPort，请确认 MediaLib 后端已启动并放行防火墙。";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 背景光晕装饰
          Positioned(
            left: -100,
            top: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            right: -80,
            bottom: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.withOpacity(0.08),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Container(
                  width: isDesktop ? 680 : double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 顶部 Logo 与系统标语
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                            ),
                            child: const Icon(Icons.hub_rounded, color: AppColors.primary, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      "MediaLib",
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                                      ),
                                      child: const Text(
                                        "SERVER SETUP",
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "第一步：配置并接入您的 MediaLib 发烧级媒体中枢",
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // 1. 局域网 UDP 雷达自动扫描区域
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.background.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (ctx, child) => Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _isScanning
                                              ? AppColors.primary.withOpacity(0.4 + 0.6 * _pulseController.value)
                                              : AppColors.success,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "局域网自动雷达扫描 (UDP Discovery)",
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: _isScanning ? null : _startRadarScan,
                                  icon: _isScanning
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                        )
                                      : const Icon(Icons.refresh_rounded, size: 16),
                                  label: Text(_isScanning ? "扫描中..." : "重新探测"),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (_discoveredServers.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                alignment: Alignment.center,
                                child: Text(
                                  _isScanning
                                      ? "正在广播探测局域网中的 MediaLib 服务端 (:18088)..."
                                      : "暂未探测到广播服务端，可直接在下方手动输入 IP 和端口连接。",
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _discoveredServers.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (ctx, i) {
                                  final s = _discoveredServers[i];
                                  return InkWell(
                                    onTap: _isConnecting ? null : () => _testAndConnect(host: s.host, port: s.httpPort),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceLight,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.dns_rounded, color: AppColors.primary, size: 20),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  s.serverName,
                                                  style: const TextStyle(
                                                    color: AppColors.textPrimary,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  "http://${s.host}:${s.httpPort} (v${s.version})",
                                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.black,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              minimumSize: Size.zero,
                                            ),
                                            onPressed: _isConnecting ? null : () => _testAndConnect(host: s.host, port: s.httpPort),
                                            child: const Text("一键接入", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 2. 手动填写地址输入表单
                      const Text(
                        "手动指定服务器 IP / 域名",
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _hostController,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: "服务端 IP / 域名",
                                labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                                hintText: "127.0.0.1 或 192.168.x.x",
                                prefixIcon: const Icon(Icons.computer, color: AppColors.primary, size: 20),
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _portController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: "HTTP / REST 端口",
                                labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                                hintText: "18080",
                                prefixIcon: const Icon(Icons.tag, color: AppColors.primary, size: 20),
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
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
                                  _errorMessage,
                                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),

                      // 底部确认与测试按钮
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isConnecting ? null : () => _testAndConnect(),
                          icon: _isConnecting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(Icons.link_rounded),
                          label: Text(
                            _isConnecting ? "正在测试连通性..." : "测试并连接服务端",
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
