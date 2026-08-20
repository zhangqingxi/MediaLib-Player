import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants.dart';
import '../../models/media_item.dart';

/// 剧集多季/多集选集组件 (TV Series Season & Episode Selector)
class EpisodeSelectorWidget extends StatefulWidget {
  final MediaItemModel item;
  final EpisodeModel? currentSelectedEpisode;
  final ValueChanged<EpisodeModel> onEpisodeSelected;

  const EpisodeSelectorWidget({
    Key? key,
    required this.item,
    this.currentSelectedEpisode,
    required this.onEpisodeSelected,
  }) : super(key: key);

  @override
  State<EpisodeSelectorWidget> createState() => _EpisodeSelectorWidgetState();
}

class _EpisodeSelectorWidgetState extends State<EpisodeSelectorWidget> {
  late int _selectedSeason;

  @override
  void initState() {
    super.initState();
    final seasons = widget.item.seasonGroups.keys.toList();
    if (widget.currentSelectedEpisode != null) {
      _selectedSeason = widget.currentSelectedEpisode!.seasonNumber;
    } else if (seasons.isNotEmpty) {
      _selectedSeason = seasons.first;
    } else {
      _selectedSeason = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final seasonGroups = widget.item.seasonGroups;
    final seasons = seasonGroups.keys.toList()..sort();
    final episodes = seasonGroups[_selectedSeason] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 季 Tab 栏 (Season Tabs)
        if (seasons.length > 1)
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: seasons.length,
              itemBuilder: (ctx, i) {
                final sNum = seasons[i];
                final isSelected = _selectedSeason == sNum;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(19),
                    onTap: () => setState(() => _selectedSeason = sNum),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.white12,
                        ),
                      ),
                      child: Text(
                        "第 $sNum 季",
                        style: TextStyle(
                          color: isSelected ? Colors.black : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // 2. 分集横向滑动卡片列表 / 网格
        SizedBox(
          height: 140,
          child: episodes.isEmpty
              ? const Center(
                  child: Text(
                    "暂无分集数据",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: episodes.length,
                  itemBuilder: (ctx, i) {
                    final ep = episodes[i];
                    final isPlaying = widget.currentSelectedEpisode?.id == ep.id;

                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      child: FocusableActionDetector(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => widget.onEpisodeSelected(ep),
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isPlaying
                                    ? AppColors.primary
                                    : Colors.white.withOpacity(0.08),
                                width: isPlaying ? 2 : 1,
                              ),
                              boxShadow: isPlaying
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.3),
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 分集截图与编号角标
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ep.stillUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: ep.stillUrl,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) => _buildPlaceholder(),
                                              )
                                            : _buildPlaceholder(),
                                      ),
                                      // 渐变遮罩
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.7),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // 编号标号
                                      Positioned(
                                        top: 6,
                                        left: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.75),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            ep.episodeLabel,
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (isPlaying)
                                        const Center(
                                          child: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: AppColors.primary,
                                            child: Icon(
                                              Icons.play_arrow_rounded,
                                              color: Colors.black,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // 分集标题与说明
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ep.title.isNotEmpty
                                            ? "${ep.episodeNumber}. ${ep.title}"
                                            : "第 ${ep.episodeNumber} 集",
                                        style: TextStyle(
                                          color: isPlaying
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (ep.overview.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          ep.overview,
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 10,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 24),
      ),
    );
  }
}
