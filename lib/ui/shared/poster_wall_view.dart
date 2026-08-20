import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/media_item.dart';
import '../../grpc/client.dart';
import '../tv/tv_focus_card.dart';
import '../tv/tv_navigation_wrapper.dart';
import 'media_detail_modal.dart';
import 'settings_modal.dart';
import 'search_modal.dart';
import 'collection_detail_modal.dart';

/// 跨端自适应海报墙主界面 (Poster Wall Home)
class PosterWallView extends StatefulWidget {
  const PosterWallView({Key? key}) : super(key: key);

  @override
  State<PosterWallView> createState() => _PosterWallViewState();
}

class _PosterWallViewState extends State<PosterWallView> {
  final MediaLibClient _client = MediaLibClient();
  List<MediaItemModel> _items = [];
  bool _isLoading = true;
  String _selectedDiscType = "全部";
  String _selectedGenre = "全部";

  @override
  void initState() {
    super.initState();
    _initClientAndLoad();
  }

  Future<void> _initClientAndLoad() async {
    await _client.init();
    _loadMediaItems();
  }

  Future<void> _loadMediaItems() async {
    setState(() => _isLoading = true);
    final list = await _client.listItems(
      discType: _selectedDiscType,
      genre: _selectedGenre,
      pageSize: 60,
    );
    if (mounted) {
      setState(() {
        _items = list;
        _isLoading = false;
      });
    }
  }

  void _openDetailModal(MediaItemModel item) {
    showDialog(
      context: context,
      builder: (context) => MediaDetailModal(item: item),
    );
  }

  void _openSearchModal() {
    showDialog(
      context: context,
      builder: (context) => const SearchModal(),
    );
  }

  void _openCollectionsDialog() async {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _client.listCollections(),
        builder: (context, snapshot) {
          final collections = snapshot.data ?? [];
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
            child: Container(
              width: 800,
              height: 540,
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
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.collections_bookmark_rounded, color: AppColors.primary, size: 24),
                        const SizedBox(width: 12),
                        const Text(
                          "经典系列影视合辑 (Franchise Boxsets)",
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textMuted),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : collections.isEmpty
                            ? const Center(
                                child: Text("媒体库中暂未发现系列合辑", style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(20),
                                itemCount: collections.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (ctx, i) {
                                  final col = collections[i];
                                  final name = col['Name'] ?? col['name'] ?? '未命名合辑';
                                  final count = col['ItemCount'] ?? col['item_count'] ?? 0;
                                  return InkWell(
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      showDialog(
                                        context: context,
                                        builder: (context) => CollectionDetailModal(collectionName: name),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.movie_filter_rounded, color: AppColors.primary, size: 22),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceLight,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              "$count 部作品",
                                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openSettingsModal() {
    showDialog(
      context: context,
      builder: (context) => ServerSettingsModal(
        onSaved: () {
          _loadMediaItems();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTVOrDesktop = MediaQuery.of(context).size.width > 700;

    return TVNavigationWrapper(
      onMenuPressed: _openSettingsModal,
      onSearchPressed: _openSearchModal,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [\n              // 1. 顶部状态栏与专区胶囊
              _buildTopBar(isTVOrDesktop),

              // 2. 流派快速分类条
              _buildGenreFilterBar(),

              // 3. 海报墙网格
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : _items.isEmpty
                        ? _buildEmptyState()
                        : _buildPosterGrid(isTVOrDesktop),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isTVOrDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // 品牌 Logo 与标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                ),
                child: const Icon(Icons.play_circle_filled_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 10),
              const Text(
                "MediaLib",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),

          // 媒介形态专区胶囊 (4K UHD / 蓝光原盘 / 3D)
          if (isTVOrDesktop)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AppConstants.discTypes.map((type) {
                    final isSelected = _selectedDiscType == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedDiscType = type);
                            _loadMediaItems();
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // 搜索触发按键
          InkWell(
            onTap: _openSearchModal,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 18),
                  if (isTVOrDesktop) ...[
                    const SizedBox(width: 6),
                    const Text("搜索", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text("/", style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 系列合辑快捷入口
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined, color: AppColors.textSecondary, size: 22),
            tooltip: "经典系列合辑展台",
            onPressed: _openCollectionsDialog,
          ),
          const SizedBox(width: 4),

          // 刷新媒体库
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 22),
            tooltip: "刷新媒体库",
            onPressed: _loadMediaItems,
          ),
          const SizedBox(width: 4),

          // 服务器与账号设置
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 22),
            tooltip: "服务器与账号设置",
            onPressed: _openSettingsModal,
          ),
        ],
      ),
    );
  }

  Widget _buildGenreFilterBar() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: AppConstants.genres.length,
        itemBuilder: (ctx, i) {
          final g = AppConstants.genres[i];
          final isSelected = _selectedGenre == g;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(g),
              selected: isSelected,
              selectedColor: AppColors.surfaceLight,
              backgroundColor: Colors.transparent,
              checkmarkColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.1),
                ),
              ),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 12,
              ),
              onSelected: (selected) {
                setState(() => _selectedGenre = selected ? g : "全部");
                _loadMediaItems();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPosterGrid(bool isTVOrDesktop) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isTVOrDesktop ? 190 : 130,
        childAspectRatio: 0.68,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final item = _items[i];
        return TVFocusCard(
          item: item,
          onTap: () => _openDetailModal(item),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie_filter_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text(
            "当前专区暂无影视条目",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  setState(() {
                    _selectedDiscType = "全部";
                    _selectedGenre = "全部";
                  });
                  _loadMediaItems();
                },
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text("重置筛选"),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                onPressed: _openSettingsModal,
                icon: const Icon(Icons.settings, size: 18),
                label: const Text("配置服务器"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
