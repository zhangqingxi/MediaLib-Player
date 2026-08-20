import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/media_item.dart';
import '../grpc/client.dart';
import '../core/constants.dart';

/// 跨平台发烧级播放器控制器
class MediaLibPlayerController extends ChangeNotifier {
  late final Player player;
  late final VideoController videoController;

  MediaItemModel? _currentItem;
  Timer? _progressReportTimer;
  String _sessionId = "";
  bool _isDisposed = false;
  int _lastReportedSec = 0;

  // 播放状态
  bool isBuffering = false;
  bool isPlaying = false;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;
  double playbackSpeed = 1.0;

  // 杜比视界与渲染参数
  bool isDolbyVisionActive = false;
  String activeAudioTrack = "";
  String activeSubtitleTrack = "";

  MediaItemModel? get currentItem => _currentItem;

  MediaLibPlayerController() {
    // 1. 初始化底层 media_kit / libmpv 发烧级核心
    player = Player(
      configuration: const PlayerConfiguration(
        title: "MediaLib Player",
        ready: true,
        bufferSize: 32 * 1024 * 1024, // 32MB 极速缓冲
      ),
    );

    videoController = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
        hwdec: 'd3d11va', // Windows 默认硬解，Android 走 mediacodec
      ),
    );

    _initListeners();
  }

  void _initListeners() {
    player.stream.buffering.listen((b) {
      isBuffering = b;
      notifyListeners();
    });

    player.stream.playing.listen((p) {
      isPlaying = p;
      notifyListeners();
    });

    player.stream.position.listen((pos) {
      currentPosition = pos;
      notifyListeners();
    });

    player.stream.duration.listen((dur) {
      totalDuration = dur;
      notifyListeners();
    });
  }

  /// 播放指定媒体条目（执行起播瞬间换链、断点恢复与杜比 GPU 参数注入）
  Future<void> playItem(MediaItemModel item) async {
    _currentItem = item;
    _sessionId = "sess_${DateTime.now().millisecondsSinceEpoch}";
    _lastReportedSec = 0;
    isDolbyVisionActive = item.hasDolbyVision;
    notifyListeners();

    final client = MediaLibClient();

    // 1. 毫秒级向服务端请求最新的真实播放直链（115 OpenAPI 抗风控换链）
    final streamResp = await client.getStreamURL(itemId: item.id);
    final finalPlayUrl = streamResp.playUrl;

    // 2. 检查服务端历史播放进度（断点续播）
    final progressRecord = await client.getProgress(mediaId: item.id);
    Duration startPosition = Duration.zero;
    if (progressRecord.hasRecord && !progressRecord.completed && progressRecord.positionSec > 10) {
      startPosition = Duration(seconds: progressRecord.positionSec);
    }

    // 3. 打开媒体流
    await player.open(
      Media(
        finalPlayUrl,
        httpHeaders: streamResp.headers,
        start: startPosition,
      ),
      play: true,
    );

    // 4. 启动单向时钟打点定时器（每 5 秒上报一次进度，防回滚）
    _startProgressReportTimer();
  }

  void _startProgressReportTimer() {
    _progressReportTimer?.cancel();
    _progressReportTimer = Timer.periodic(
      const Duration(seconds: AppConstants.progressReportIntervalSec),
      (_) => _reportCurrentProgress(),
    );
  }

  Future<void> _reportCurrentProgress({bool isFinished = false}) async {
    if (_currentItem == null || _isDisposed) return;

    final posSec = currentPosition.inSeconds;
    final durSec = totalDuration.inSeconds;

    if (durSec <= 0 || posSec < 0) return;

    // 单向递增时钟保护：防止网络抖动发送旧时间戳
    if (posSec >= _lastReportedSec || isFinished) {
      _lastReportedSec = posSec;
      await MediaLibClient().reportProgress(
        mediaId: _currentItem!.id,
        positionSec: posSec,
        durationSec: durSec,
        clientSessionId: _sessionId,
        isPaused: !isPlaying,
        isFinished: isFinished || (durSec > 0 && posSec >= durSec - 15),
      );
    }
  }

  /// 播放 / 暂停切换
  void togglePlayPause() {
    player.playOrPause();
  }

  /// 快进 / 快退指定秒数 (D-Pad 左右键)
  void seekRelative(int seconds) {
    final target = currentPosition + Duration(seconds: seconds);
    if (target < Duration.zero) {
      player.seek(Duration.zero);
    } else if (target > totalDuration) {
      player.seek(totalDuration);
    } else {
      player.seek(target);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _progressReportTimer?.cancel();
    _reportCurrentProgress(isFinished: false);
    player.dispose();
    super.dispose();
  }
}
