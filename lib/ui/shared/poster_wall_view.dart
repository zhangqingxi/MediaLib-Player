import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/media_item.dart';
import '../../grpc/client.dart';
import '../tv/tv_focus_card.dart';
import 'media_detail_modal.dart';
import 'settings_modal.dart';

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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 顶部状态栏与专区胶囊
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
          const SizedBox(width: 24),

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

          // 右侧：刷新与服务器连接设置按钮
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 22),
            tooltip: "刷新媒体库",
            onPressed: _loadMediaItems,
          ),
          const SizedBox(width: 6),
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
