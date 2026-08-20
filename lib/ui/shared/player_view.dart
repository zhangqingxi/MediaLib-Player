import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/constants.dart';
import '../../models/media_item.dart';
import '../../player/player_controller.dart';
import '../../player/bluray_menu_controller.dart';
import 'bdinfo_capsule_widget.dart';
import 'track_selector_modal.dart';

/// 发烧级全屏播放器界面 (含 OSD、音轨/字幕面板与原盘菜单交互)
class PlayerView extends StatefulWidget {
  final MediaItemModel item;
  final int startPositionSec;

  const PlayerView({
    Key? key,
    required this.item,
    this.startPositionSec = 0,
  }) : super(key: key);

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  late final MediaLibPlayerController _controller;
  late final BluRayMenuController _menuController;
  bool _showOsd = true;

  @override
  void initState() {
    super.initState();
    _controller = MediaLibPlayerController();
    _menuController = BluRayMenuController(_controller.player);
    _controller.playItem(widget.item, startPositionSec: widget.startPositionSec);

    // 隐藏状态栏全屏沉浸
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _openTrackSelector() {
    showDialog(
      context: context,
      builder: (context) => TrackSelectorModal(
        controller: _controller,
        item: widget.item,
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final isBluRay = widget.item.discType == "BD" || widget.item.discType == "UHD" || widget.item.discType == "3D";

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKey: (node, event) {
          if (event is RawKeyDownEvent) {
            // 遥控器与快捷键响应
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.enter) {
              _controller.togglePlayPause();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _controller.seekRelative(10); // 快进 10s
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _controller.seekRelative(-10); // 快退 10s
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
              // M 键呼出音轨与字幕调谐面板
              _openTrackSelector();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyB && isBluRay) {
              // B 键呼出原盘顶层菜单
              _menuController.showTopMenu();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.backspace) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () {
            setState(() => _showOsd = !_showOsd);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. 核心视频图层
              Center(
                child: Video(
                  controller: _controller.videoController,
                  controls: NoVideoControls,
                ),
              ),

              // 2. 缓冲转圈
              AnimatedBuilder(
                animation: _controller,
                builder: (ctx, _) {
                  if (_controller.isBuffering) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // 3. 悬浮 OSD 控制层
              if (_showOsd) _buildOsdOverlay(isBluRay),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOsdOverlay(bool isBluRay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (ctx, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.8),
                Colors.transparent,
                Colors.black.withOpacity(0.9),
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 顶部栏：返回键 + 片名 + 原盘菜单按键 + BDINFO 胶囊
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.item.originalTitle.isNotEmpty)
                          Text(
                            widget.item.originalTitle,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // 原盘菜单按钮 (BD-J / HDMV)
                  if (isBluRay) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _menuController.showTopMenu(),
                      icon: const Icon(Icons.menu_book_outlined, size: 14, color: AppColors.primary),
                      label: const Text("原盘菜单", style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 12),
                  ],

                  BDInfoCapsuleWidget(item: widget.item),
                ],
              ),

              // 底部栏：进度条 + 控制按钮 + 轨道切换 + 杜比徽标
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 进度条
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: Colors.white.withOpacity(0.2),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: _controller.currentPosition.inSeconds.toDouble().clamp(
                            0.0,
                            _controller.totalDuration.inSeconds.toDouble() > 0
                                ? _controller.totalDuration.inSeconds.toDouble()
                                : 1.0,
                          ),
                      max: _controller.totalDuration.inSeconds.toDouble() > 0
                          ? _controller.totalDuration.inSeconds.toDouble()
                          : 1.0,
                      onChanged: (val) {
                        _controller.player.seek(Duration(seconds: val.toInt()));
                      },
                    ),
                  ),

                  // 控制按钮与时间戳
                  Row(
                    children: [
                      // 播放/暂停
                      IconButton(
                        icon: Icon(
                          _controller.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: Colors.white,
                          size: 36,
                        ),
                        onPressed: _controller.togglePlayPause,
                      ),
                      const SizedBox(width: 8),

                      // 时间显示
                      Text(
                        "${_formatDuration(_controller.currentPosition)} / ${_formatDuration(_controller.totalDuration)}",
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const Spacer(),

                      // 音轨与字幕快速调谐按钮
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceLight,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: _openTrackSelector,
                        icon: const Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
                        label: const Text("音轨 / 字幕 / 倍速", style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 12),

                      // 杜比视界高光角标
                      if (widget.item.hasDolbyVision)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.dolbyVision.withOpacity(0.2),
                            border: Border.all(color: AppColors.dolbyVision),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "DOLBY VISION ACTIVE",
                            style: TextStyle(
                              color: AppColors.dolbyVision,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
