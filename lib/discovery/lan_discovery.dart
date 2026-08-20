import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 局域网发现的服务端节点实体
class DiscoveredServer {
  final String serverName;
  final String version;
  final String host;
  final int httpPort;
  final int grpcPort;
  final bool authEnabled;
  final List<String> ipList;
  final String hostname;

  DiscoveredServer({
    required this.serverName,
    this.version = "1.0.0",
    required this.host,
    this.httpPort = 8080,
    this.grpcPort = 8080,
    this.authEnabled = false,
    this.ipList = const [],
    this.hostname = "",
  });

  String get displayAddress => "$host:$httpPort";

  factory DiscoveredServer.fromJson(Map<String, dynamic> json, String remoteIP) {
    final ips = (json['ip_list'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    return DiscoveredServer(
      serverName: json['server_name'] ?? "MediaLib Server",
      version: json['version'] ?? "1.0.0",
      host: remoteIP.isNotEmpty ? remoteIP : (ips.isNotEmpty ? ips.first : "127.0.0.1"),
      httpPort: json['http_port'] ?? 8080,
      grpcPort: json['grpc_port'] ?? 8080,
      authEnabled: json['auth_enabled'] ?? false,
      ipList: ips,
      hostname: json['hostname'] ?? "",
    );
  }
}

/// 局域网 UDP 广播自动发现服务 (LAN Service Discovery)
class LANDiscoveryService {
  static const int discoveryPort = 18088;
  static const String probeMagic = "MEDIALIB_DISCOVER";
  static const String ackMagic = "MEDIALIB_DISCOVER_ACK";

  /// 发起局域网广播探测，获取所有在线的 MediaLib 服务端
  static Future<List<DiscoveredServer>> discover({
    Duration timeout = const Duration(milliseconds: 2200),
  }) async {
    final Map<String, DiscoveredServer> discovered = {};
    RawDatagramSocket? socket;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final completer = Completer<List<DiscoveredServer>>();
      final probeBytes = utf8.encode(probeMagic);

      // 发送全局广播探测
      socket.send(
        probeBytes,
        InternetAddress("255.255.255.255"),
        discoveryPort,
      );

      // 监听响应
      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null) {
            try {
              final rawStr = utf8.decode(datagram.data);
              final jsonMap = json.decode(rawStr);
              if (jsonMap['magic'] == ackMagic) {
                final server = DiscoveredServer.fromJson(
                  jsonMap,
                  datagram.address.address,
                );
                discovered[server.displayAddress] = server;
              }
            } catch (_) {}
          }
        }
      });

      // 超时返回收集到的结果
      Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(discovered.values.toList());
        }
      });

      return await completer.future;
    } catch (e) {
      return discovered.values.toList();
    } finally {
      socket?.close();
    }
  }
}
