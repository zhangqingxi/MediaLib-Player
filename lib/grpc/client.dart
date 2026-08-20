import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';
import '../models/playback.dart';

/// MediaLib 后端通信客户端（支持 gRPC 高性能通信与 REST API 降级）
class MediaLibClient {
  static final MediaLibClient _instance = MediaLibClient._internal();
  factory MediaLibClient() => _instance;
  MediaLibClient._internal();

  String _host = "127.0.0.1";
  int _port = 8080;
  String _authToken = "";
  String _deviceName = "PC-Client";

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
      "User-Agent": "MediaLibPlayer/1.0 (CrossPlatform; $deviceName)",
    };
    if (_authToken.isNotEmpty) {
      map["Authorization"] = "Bearer $_authToken";
    }
    return map;
  }

  String get deviceName => _deviceName;

  // ==========================================
  // 1. 媒体服务 (MediaService 映射)
  // ==========================================

  /// 获取海报墙条目列表
  Future<List<MediaItemModel>> listItems({
    int page = 1,
    int pageSize = 40,
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
    if (collection != null && collection.isNotEmpty) queryParams["collection"] = collection;
    if (keyword != null && keyword.isNotEmpty) queryParams["keyword"] = keyword;
    if (discType != null && discType != "全部") queryParams["disc_type"] = discType;
    if (resolution != null && resolution != "全部") queryParams["resolution"] = resolution;
    if (edition != null && edition != "全部") queryParams["edition"] = edition;
    if (genre != null && genre != "全部") queryParams["genre"] = genre;

    final uri = Uri.parse("$baseUrl/api/media/items").replace(queryParameters: queryParams);
    try {
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
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
    final uri = Uri.parse("$baseUrl/api/media/items/$id");
    try {
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        return MediaItemModel.fromMap(data);
      }
    } catch (e) {}
    return null;
  }

  /// 播放动态换链：起播瞬间换取 115 真实 302 直链或流媒体地址（抗风控核心）
  Future<StreamUrlResponse> getStreamURL({required int itemId, String fileKey = ""}) async {
    final uri = Uri.parse("$baseUrl/api/media/stream_url");
    try {
      final resp = await http
          .post(
            uri,
            headers: _headers,
            body: json.encode({"item_id": itemId, "file_key": fileKey}),
          )
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        return StreamUrlResponse.fromMap(data);
      }
    } catch (e) {}
    
    // 降级兜底地址
    return StreamUrlResponse(playUrl: "$baseUrl/api/stream/$fileKey");
  }

  // ==========================================
  // 2. 播放器同步服务 (PlaybackService 映射)
  // ==========================================

  /// 获取续播断点
  Future<PlaybackProgressModel> getProgress({required int mediaId, int episodeId = 0}) async {
    final uri = Uri.parse("$baseUrl/api/playback/progress?media_id=$mediaId&episode_id=$episodeId");
    try {
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
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
      "is_finished": isFinished,
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
