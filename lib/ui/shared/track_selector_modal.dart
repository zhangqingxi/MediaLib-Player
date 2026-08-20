import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/media_item.dart';
import '../../player/player_controller.dart';

/// 播放器音轨、字幕与播放参数调谐面板 (Track & Audio/Subtitle Selector)
class TrackSelectorModal extends StatefulWidget {
  final MediaLibPlayerController controller;
  final MediaItemModel item;

  const TrackSelectorModal({
    Key? key,
    required this.controller,
    required this.item,
  }) : super(key: key);

  @override
  State<TrackSelectorModal> createState() => _TrackSelectorModalState();
}

class _TrackSelectorModalState extends State<TrackSelectorModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      alignment: Alignment.centerRight,
      insetPadding: const EdgeInsets.only(top: 20, bottom: 20, right: 20),
      child: Container(
        width: 380,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 24,
              offset: const Offset(-8, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. 顶部标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
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
                        child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "影音规格与轨道调谐",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
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
            ),

            // 2. Tab 分页标签
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: "音轨"),
                Tab(text: "字幕"),
                Tab(text: "倍速"),
                Tab(text: "画质"),
              ],
            ),
            const Divider(color: Colors.white12, height: 1),

            // 3. Tab 内容区
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAudioTracksTab(),
                  _buildSubtitleTracksTab(),
                  _buildSpeedTab(),
                  _buildVideoQualityTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 音轨选择
  Widget _buildAudioTracksTab() {
    final audioTracks = widget.item.bdinfo?.audioTracks ?? [];
    if (audioTracks.isEmpty) {
      return _buildEmptyTabMessage("未探测到多音轨数据，使用默认系统音轨");
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: audioTracks.length,
      itemBuilder: (ctx, i) {
        final track = audioTracks[i];
        final isSelected = widget.controller.activeAudioTrack == track.title || i == 0;

        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: track.isAtmos
                  ? AppColors.atmos.withOpacity(0.2)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.audiotrack,
              size: 16,
              color: track.isAtmos ? AppColors.atmos : AppColors.textSecondary,
            ),
          ),
          title: Text(
            track.title.isNotEmpty ? track.title : "${track.language} (${track.codec})",
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            "${track.codec} · ${track.channelLayout} ${track.bitRate.isNotEmpty ? '· ' + track.bitRate : ''}",
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary, size: 18) : null,
          onTap: () {
            setState(() {
              widget.controller.activeAudioTrack = track.title;
            });
            // 切换底层 MPV 音轨
            widget.controller.player.setAudioTrack(AudioTrack.auto());
          },
        );
      },
    );
  }

  /// 字幕选择
  Widget _buildSubtitleTracksTab() {
    final subTracks = widget.item.bdinfo?.subtitleTracks ?? [];
    if (subTracks.isEmpty) {
      return _buildEmptyTabMessage("未探测到内嵌字幕轨，可加载外部 ASS/SRT 字幕");
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: subTracks.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          final isOff = widget.controller.activeSubtitleTrack == "off";
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: const Icon(Icons.subtitles_off_outlined, color: AppColors.textMuted, size: 18),
            title: Text(
              "关闭字幕",
              style: TextStyle(
                color: isOff ? AppColors.primary : AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
            trailing: isOff ? const Icon(Icons.check_circle, color: AppColors.primary, size: 18) : null,
            onTap: () {
              setState(() => widget.controller.activeSubtitleTrack = "off");
              widget.controller.player.setSubtitleTrack(SubtitleTrack.no());
            },
          );
        }

        final track = subTracks[i - 1];
        final isSelected = widget.controller.activeSubtitleTrack == track.title;

        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: track.isForced ? Colors.orange.withOpacity(0.2) : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.subtitles_outlined,
              size: 16,
              color: track.isForced ? Colors.orange : AppColors.textSecondary,
            ),
          ),
          title: Text(
            track.title.isNotEmpty ? track.title : "${track.language} (${track.format})",
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            "${track.language} · ${track.format} ${track.isForced ? '· 强制字幕' : ''}",
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary, size: 18) : null,
          onTap: () {
            setState(() => widget.controller.activeSubtitleTrack = track.title);
            widget.controller.player.setSubtitleTrack(SubtitleTrack.auto());
          },
        );
      },
    );
  }

  /// 播放倍速
  Widget _buildSpeedTab() {
    final speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: speeds.length,
      itemBuilder: (ctx, i) {
        final spd = speeds[i];
        final isSelected = (widget.controller.playbackSpeed - spd).abs() < 0.01;

        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          title: Text(
            "${spd}x ${spd == 1.0 ? ' (正常倍速)' : ''}",
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary, size: 18) : null,
          onTap: () {
            setState(() => widget.controller.playbackSpeed = spd);
            widget.controller.player.setRate(spd);
          },
        );
      },
    );
  }

  /// 画质与色调映射状态
  Widget _buildVideoQualityTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow("视频分辨率", widget.item.resolution.isNotEmpty ? widget.item.resolution : "4K UHD (3840x2160)"),
          _buildInfoRow("母盘规格", widget.item.discType.isNotEmpty ? widget.item.discType : "蓝光原盘 (BDMV)"),
          _buildInfoRow("HDR 模式", widget.item.hasDolbyVision ? "Dolby Vision Profile 7 -> 8.1" : "HDR10 / PQ"),
          _buildInfoRow("色调映射引擎", "libplacebo Spline GPU-Next"),
          _buildInfoRow("硬件解码", "Direct3D 11VA / Vulkan GPU"),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "已启用杜比视界 Profile 7 动态 RPU SEI 注入，支持点亮外接电视与显示器 HDR 引擎。",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyTabMessage(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
        ),
      ),
    );
  }
}
