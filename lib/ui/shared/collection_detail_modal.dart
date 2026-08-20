import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants.dart';
import '../../models/media_item.dart';
import '../../grpc/client.dart';
import 'bdinfo_capsule_widget.dart';
import 'player_view.dart';

/// 影视合辑 / 系列专题时间线展台 (Franchise Boxset Timeline Modal)
class CollectionDetailModal extends StatefulWidget {
  final String collectionName;

  const CollectionDetailModal({Key? key, required this.collectionName}) : super(key: key);

  @override
  State<CollectionDetailModal> createState() => _CollectionDetailModalState();
}

class _CollectionDetailModalState extends State<CollectionDetailModal> {
  final MediaLibClient _client = MediaLibClient();
  List<MediaItemModel> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollectionItems();
  }

  Future<void> _loadCollectionItems() async {
    final list = await _client.listItems(
      collection: widget.collectionName,
      pageSize: 50,
    );
    // 按上映年份排序
    list.sort((a, b) => a.year.compareTo(b.year));

    if (mounted) {
      setState(() {
        _items = list;
        _isLoading = false;
      });
    }
  }

  void _startPlaybackFromIndex(int index) {
    if (index >= _items.length) return;
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerView(item: _items[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 960,
        height: 640,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.85),
              blurRadius: 36,
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. 顶部合辑头图与标题栏
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.collections_bookmark_rounded, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.collectionName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "全系列共包含 ${_items.length} 部经典作品 · 按上映年份顺序排列",
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (_items.isNotEmpty) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _startPlaybackFromIndex(0),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text("从首部顺序连播", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. 时间线列表
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _items.isEmpty
                      ? const Center(
                          child: Text(
                            "合辑内暂无条目",
                            style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (ctx, i) {
                            final item = _items[i];
                            return _buildTimelineItem(item, i);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(MediaItemModel item, int index) {
    return InkWell(
      onTap: () => _startPlaybackFromIndex(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            // 序号标号
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
              ),
              child: Center(
                child: Text(
                  "${index + 1}",
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // 海报
            Container(
              width: 50,
              height: 75,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
              child: CachedNetworkImage(
                imageUrl: item.posterUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.surfaceLight,
                  child: const Icon(Icons.movie, size: 20, color: AppColors.textMuted),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // 片名与简介
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.year > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          "(${item.year})",
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                      if (item.rating > 0) ...[
                        const SizedBox(width: 10),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              item.rating.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  if (item.overview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.overview,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  BDInfoCapsuleWidget(item: item, isCompact: true),
                ],
              ),
            ),

            // 播放图标
            IconButton(
              icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 36),
              onPressed: () => _startPlaybackFromIndex(index),
            ),
          ],
        ),
      ),
    );
  }
}
