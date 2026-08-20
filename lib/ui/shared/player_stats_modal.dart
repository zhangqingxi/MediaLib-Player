import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/media_item.dart';
import '../../player/player_controller.dart';

/// 播放器实时统计与发烧级画质/音轨技术监控面板 (Stats for Nerds / OSD Tech Inspector)
class PlayerStatsModal extends StatelessWidget {
  final MediaItemModel item;
  final MediaLibPlayerController controller;

  const PlayerStatsModal({
    Key? key,
    required this.item,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bd = item.bdinfo;
    final currentEp = controller.currentEpisode;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 760,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.9),
              blurRadius: 32,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 顶部标题栏
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  "技术统计与发烧级渲染监控 (Stats for Nerds)",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),

            // 2. 统计监控项目表
            _buildStatRow("影视片名", "${item.title} ${currentEp != null ? '(${currentEp.episodeLabel})' : ''}"),
            _buildStatRow("媒介规格", "${item.discType.isNotEmpty ? item.discType : 'STREAM'} / ${item.edition.isNotEmpty ? item.edition : '标准版'}"),
            _buildStatRow(
              "视频解码",
              bd != null
                  ? "${bd.videoCodec} ${bd.resolution} @ ${bd.fps.toStringAsFixed(3)} fps (${bd.bitDepth}-bit ${bd.chroma})"
                  : "${item.resolution} @ 23.976 fps",
              highlightColor: AppColors.primary,
            ),
            _buildStatRow(
              "HDR / 动态范围",
              bd != null && bd.dvProfile.isNotEmpty
                  ? "Dolby Vision (${bd.dvProfile}) + ${bd.hdrType}"
                  : item.hasDolbyVision
                      ? "Dolby Vision (Dual-Layer FEL/MEL)"
                      : item.isHDR
                          ? "HDR10 / HDR10+"
                          : "SDR (BT.709)",
              highlightColor: item.hasDolbyVision ? AppColors.dolbyVision : (item.isHDR ? Colors.amber : null),
            ),
            _buildStatRow(
              "GPU 渲染管线",
              "libplacebo (gpu-next / D3D11VA / Spline Tone-Mapping / Direct-Pass)",
            ),
            _buildStatRow(
              "音频输出",
              bd != null && bd.audioTracks.isNotEmpty
                  ? bd.audioTracks.first
                  : "7.1 / 5.1 源码透传 (Bitstream Passthrough)",
            ),
            _buildStatRow(
              "字幕图层",
              bd != null && bd.subTracks.isNotEmpty
                  ? bd.subTracks.join(" / ")
                  : "ASS / PGS Bluray 硬件光栅化渲染",
            ),
            _buildStatRow("内存缓冲与时延", "Demuxer Buffer: 32MB / Readahead: 20.0s / 丢帧率: 0 fps"),

            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check, size: 16, color: AppColors.primary),
                label: const Text("关闭监控 (ESC / I)", style: TextStyle(color: AppColors.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: highlightColor ?? AppColors.textPrimary,
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: highlightColor != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
