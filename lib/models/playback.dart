/// 播放地址换链响应
class StreamUrlResponse {
  final String playUrl;
  final bool isDirect;
  final int expireAt;
  final Map<String, String> headers;

  StreamUrlResponse({
    required this.playUrl,
    this.isDirect = false,
    this.expireAt = 0,
    this.headers = const {},
  });

  factory StreamUrlResponse.fromMap(Map<String, dynamic> map) {
    return StreamUrlResponse(
      playUrl: map['play_url'] ?? '',
      isDirect: map['is_direct'] ?? false,
      expireAt: map['expire_at'] ?? 0,
      headers: (map['headers'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          {},
    );
  }
}

/// 播放进度记录与断点
class PlaybackProgressModel {
  final bool hasRecord;
  final int positionSec;
  final int durationSec;
  final double progress;
  final bool completed;
  final String lastDeviceName;
  final int updatedAtUnix;

  PlaybackProgressModel({
    this.hasRecord = false,
    this.positionSec = 0,
    this.durationSec = 0,
    this.progress = 0.0,
    this.completed = false,
    this.lastDeviceName = '',
    this.updatedAtUnix = 0,
  });

  factory PlaybackProgressModel.fromMap(Map<String, dynamic> map) {
    return PlaybackProgressModel(
      hasRecord: map['has_record'] ?? false,
      positionSec: map['position_sec'] ?? 0,
      durationSec: map['duration_sec'] ?? 0,
      progress: (map['progress'] is num) ? (map['progress'] as num).toDouble() : 0.0,
      completed: map['completed'] ?? false,
      lastDeviceName: map['last_device_name'] ?? '',
      updatedAtUnix: map['updated_at_unix'] ?? 0,
    );
  }
}
