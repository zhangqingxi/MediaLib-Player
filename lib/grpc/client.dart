import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../models/playback.dart';

/// MediaLib 后端通信客户端（支持 gRPC 高性能通信与 REST API 统一对接）
class MediaLibClient {
  static final MediaLibClient _instance = MediaLibClient._internal();
  factory MediaLibClient() => _instance;
  MediaLibClient._internal();

  String _host = "127.0.0.1";
  int _port = 8080;
  String _authToken = "";
  String _deviceName = "PC-Client";
  Map<String, dynamic>? _currentUser;

  String get host => _host;
  int get port => _port;
  String get token => _authToken;
  String get deviceName => _deviceName;
  Map<String, dynamic>? get currentUser => _currentUser;

  /// 初始化并加载持久化配置
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _host = prefs.getString('server_host') ?? "127.0.0.1";
      _port = prefs.getInt('server_port') ?? 8080;
      _authToken = prefs.getString('server_token') ?? "";
    } catch (_) {}
  }

  void configure({
    required String host,
    int port = 8080,
    String token = "",
    String deviceName = "MediaLib-Player",
  }) {
    _host = host.trim();
    _port = port;
    _authToken = token.trim();
    _deviceName = deviceName;
  }

  String get baseUrl => "http://$_host:$_port";

  Map<String, String> get _headers {
    final map = <String, String>{
      "Content-Type": "application/json",
      "User-Agent": "MediaLibPlayer/1.0 (CrossPlatform; $_deviceName)",
    };
    if (_authToken.isNotEmpty) {
      map["Authorization"] = "Bearer $_authToken";
    }
    return map;
  }

  // ==========================================
  // 1. 探活与用户鉴权
  // ==========================================

  /// 健康检查
  Future<bool> checkHealth() async {
    final uri = Uri.parse("$baseUrl/health");
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 4));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 播放器账号密码登录
  Future<Map<String, dynamic>> loginPlayer({required String username, required String password}) async {
    final uri = Uri.parse("$baseUrl/api/player/login");
    try {
      final resp = await http
          .post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: json.encode({"username": username, "password": password}),
          )
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        _authToken = data['token'] ?? "";
        _currentUser = data;
        return {"success": true, "token": _authToken, "user": data};
      } else {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        return {"success": false, "error": data['error'] ?? "登录失败"};
      }
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  /// 校验 Token
  Future<Map<String, dynamic>> validateToken(String token) async {
    final uri = Uri.parse("$baseUrl/api/player/items?limit=1");
    try {
      final resp = await http
          .get(uri, headers: {"Authorization": "Bearer $token"})
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        _authToken = token;
        return {"valid": true};
      }
    } catch (_) {}
    return {"valid": false};
  }

  // ==========================================
  // 2. 媒体海报墙与详情服务
  // ==========================================

  /// 获取海报墙条目列表
  Future<List<MediaItemModel>> listItems({
    int page = 1,
    int pageSize = 60,
    String? collection,
    String? keyword,
    String? discType,
    String? resolution,
    String? edition,
    String? genre,
  }) async {
    final queryParams = <String, String>{
      "page": page.toString(),
      "page_size": pageSize.toString(),
    };
    if (collection != null && collection.isNotEmpty && collection != "全部") {
      queryParams["collection"] = collection;
    }
    if (keyword != null && keyword.isNotEmpty) queryParams["keyword"] = keyword;
    if (discType != null && discType.isNotEmpty && discType != "全部") {
      queryParams["disc_type"] = discType;
    }
    if (resolution != null && resolution.isNotEmpty && resolution != "全部") {
      queryParams["resolution"] = resolution;
    }
    if (edition != null && edition.isNotEmpty && edition != "全部") {
      queryParams["edition"] = edition;
    }
    if (genre != null && genre.isNotEmpty && genre != "全部") {
      queryParams["genre"] = genre;
    }

    final uri = Uri.parse("$baseUrl/api/items").replace(queryParameters: queryParams);
    try {
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        final items = (data['items'] as List<dynamic>?) ?? [];
        return items.map((e) => MediaItemModel.fromMap(e)).toList();
      }
    } catch (e) {
      // 容错处理
    }
    return [];
  }

  /// 获取单个影片详情（含 BDINFO 胶囊）
  Future<MediaItemModel?> getItem(int id) async {
    final uri = Uri.parse("$baseUrl/api/posterwall/detail?id=$id");
    try {
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        if (data['item'] != null) {
          return MediaItemModel.fromMap(data['item']);
        }
        return MediaItemModel.fromMap(data);
      }
    } catch (e) {}
    return null;
  }

  /// 播放动态换链：起播瞬间换取 115 真实 302 直链或流媒体地址（抗风控核心）
  Future<StreamUrlResponse> getStreamURL({required int itemId, String fileKey = ""}) async {
    // 1. 如果已有签名 fileKey，直接走直链
    if (fileKey.isNotEmpty) {
      return StreamUrlResponse(playUrl: "$baseUrl/api/stream/$fileKey");
    }

    // 2. 查询条目详情中的可播放 STRM
    final item = await getItem(itemId);
    if (item != null && item.libraryPath.isNotEmpty) {
      return StreamUrlResponse(
        playUrl: "$baseUrl/api/stream/${Uri.encodeComponent(item.libraryPath)}",
        isDirect: true,
      );
    }

    return StreamUrlResponse(playUrl: "$baseUrl/api/stream/$itemId");
  }

  // ==========================================
  // 3. 播放器同步服务 (PlaybackService)
  // ==========================================

  /// 获取续播断点
  Future<PlaybackProgressModel> getProgress({required int mediaId, int episodeId = 0}) async {
    final uri = Uri.parse("$baseUrl/api/playback/progress?media_id=$mediaId&episode_id=$episodeId");
    try {
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        if (data['record'] != null) {
          return PlaybackProgressModel.fromMap(data['record']);
        }
        return PlaybackProgressModel.fromMap(data);
      }
    } catch (e) {}
    return PlaybackProgressModel();
  }

  /// 上报播放进度打点（带单向时钟与毫秒时间戳保护）
  Future<bool> reportProgress({
    required int mediaId,
    int episodeId = 0,
    int strmId = 0,
    required int positionSec,
    required int durationSec,
    required String clientSessionId,
    bool isPaused = false,
    bool isFinished = false,
  }) async {
    final uri = Uri.parse("$baseUrl/api/playback/progress");
    final payload = {
      "media_id": mediaId,
      "episode_id": episodeId,
      "strm_id": strmId,
      "position_sec": positionSec,
      "duration_sec": durationSec,
      "device_name": _deviceName,
      "client_session_id": clientSessionId,
      "is_paused": isPaused,
      "completed": isFinished,
      "timestamp_ms": DateTime.now().millisecondsSinceEpoch,
    };

    try {
      final resp = await http
          .post(uri, headers: _headers, body: json.encode(payload))
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
