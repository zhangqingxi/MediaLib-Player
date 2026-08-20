import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants.dart';
import '../../models/media_item.dart';
import '../../models/playback.dart';
import '../../grpc/client.dart';
import 'bdinfo_capsule_widget.dart';
import 'episode_selector_widget.dart';
import 'collection_detail_modal.dart';
import 'player_view.dart';

/// 影片详情与版本/分集选择弹窗 (Media Detail Modal)
class MediaDetailModal extends StatefulWidget {
  final MediaItemModel item;

  const MediaDetailModal({Key? key, required this.item}) : super(key: key);

  @override
  State<MediaDetailModal> createState() => _MediaDetailModalState();
}

class _MediaDetailModalState extends State<MediaDetailModal> {
  final MediaLibClient _client = MediaLibClient();
  PlaybackProgressModel _progress = PlaybackProgressModel();
  MediaItemModel? _detailedItem;
  EpisodeModel? _lastWatchedEpisode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetailAndProgress();
  }

  Future<void> _loadDetailAndProgress() async {
    final progress = await _client.getProgress(mediaId: widget.item.id);
    final detailed = await _client.getItem(widget.item.id);

    EpisodeModel? targetEpisode;
    if (detailed != null && detailed.episodes.isNotEmpty) {
      if (progress.hasRecord && progress.episodeId > 0) {
        targetEpisode = detailed.episodes.firstWhere(
          (e) => e.id == progress.episodeId,
          orElse: () => detailed.episodes.first,
        );
      } else {
        targetEpisode = detailed.episodes.first;
      }
    }

    if (mounted) {
      setState(() {
        _progress = progress;
        _detailedItem = detailed ?? widget.item;
        _lastWatchedEpisode = targetEpisode;
        _isLoading = false;
      });
    }
  }

  void _startPlayback({bool resume = true, EpisodeModel? episode}) {
    Navigator.of(context).pop();
    final targetEpisode = episode ?? _lastWatchedEpisode;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerView(
          item: _detailedItem ?? widget.item,
          episode: targetEpisode,
          startPositionSec: resume ? _progress.positionSec : 0,
        ),
      ),
    );
  }

  String _formatSeconds(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) {
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    }
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final item = _detailedItem ?? widget.item;
    final hasProgress = _progress.hasRecord && _progress.positionSec > 10 && !_progress.completed;
    final isTVSeries = item.isTV;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 960,
        height: isTVSeries ? 660 : 580,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Stack(
          children: [
            // 1. 背景剧照大图与渐变遮罩
            if (item.backdropUrl.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: item.backdropUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox(),
                ),
              ),

            // 暗黑发烧级渐变层
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.surface.withOpacity(0.85),
                      AppColors.surface.withOpacity(0.96),
                      AppColors.surface,
                    ],
                  ),
                ),
              ),
            ),

            // 2. 详情内容区
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左侧高清海报
                    Container(
                      width: 220,
                      height: 330,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CachedNetworkImage(
                        imageUrl: item.posterUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surfaceLight,
                          child: const Icon(Icons.movie, size: 48, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    const SizedBox(width: 28),

                    // 右侧元数据、剧集选集与操作
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 标题与原始标题
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (item.year > 0) ...[
                                const SizedBox(width: 10),
                                Text(
                                  "(${item.year})",
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (item.originalTitle.isNotEmpty && item.originalTitle != item.title) ...[
                            const SizedBox(height: 3),
                            Text(
                              item.originalTitle,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),

                          // 评分、时长与类型标签
                          Row(
                            children: [
                              if (item.rating > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.black, size: 13),
                                      const SizedBox(width: 3),
                                      Text(
                                        item.rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              if (item.runtime > 0) ...[
                                Text(
                                  "${item.runtime} 分钟",
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(width: 10),
                              ],
                              if (item.genres.isNotEmpty)
                                Text(
                                  item.genres.join(" / "),
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 蓝光技术规格胶囊 (BDInfoCapsule)
                          if (item.bdinfo != null)
                            BDInfoCapsuleWidget(bdinfo: item.bdinfo!)
                          else
                            Row(
                              children: [
                                if (item.discType.isNotEmpty) _buildSpecBadge(item.discType),
                                if (item.resolution.isNotEmpty) _buildSpecBadge(item.resolution),
                                if (item.edition.isNotEmpty) _buildSpecBadge(item.edition),
                              ],
                            ),
                          const SizedBox(height: 10),

                          // 所属系列合辑提示与跳转
                          if (item.collection.isNotEmpty) ...[
                            InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                showDialog(
                                  context: context,
                                  builder: (context) => CollectionDetailModal(collectionName: item.collection),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.collections_bookmark_rounded, color: AppColors.primary, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      "所属系列：${item.collection}",
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 11),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // 剧情简介
                          SizedBox(
                            height: isTVSeries ? 60 : 120,
                            child: SingleChildScrollView(
                              child: Text(
                                item.overview.isNotEmpty ? item.overview : "暂无剧情介绍",
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),

                          // 如果是连续剧集，展示季/集选集组件
                          if (isTVSeries) ...[
                            const SizedBox(height: 12),
                            Expanded(
                              child: EpisodeSelectorWidget(
                                item: item,
                                currentSelectedEpisode: _lastWatchedEpisode,
                                onEpisodeSelected: (ep) {
                                  setState(() => _lastWatchedEpisode = ep);
                                  _startPlayback(resume: true, episode: ep);
                                },
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // 底部播放动作按钮栏
                          Row(
                            children: [
                              if (hasProgress) ...[
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _startPlayback(resume: true),
                                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                  label: Text(
                                    isTVSeries && _lastWatchedEpisode != null
                                        ? "继续观看 ${_lastWatchedEpisode!.episodeLabel} (${_formatSeconds(_progress.positionSec)})"
                                        : "继续观看 (${_formatSeconds(_progress.positionSec)})",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _startPlayback(resume: false),
                                  icon: const Icon(Icons.replay_rounded, size: 16),
                                  label: Text(isTVSeries ? "从第 1 集播放" : "从头播放"),
                                ),
                              ] else ...[
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _startPlayback(resume: false),
                                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                                  label: Text(
                                    isTVSeries && _lastWatchedEpisode != null
                                        ? "播放 ${_lastWatchedEpisode!.episodeLabel}"
                                        : "立即播放",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 右上角关闭按钮
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecBadge(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
