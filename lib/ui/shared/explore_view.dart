import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/media_item.dart';
import '../../grpc/client.dart';
import '../tv/tv_focus_card.dart';
import '../tv/tv_navigation_wrapper.dart';
import 'media_detail_modal.dart';
import 'search_modal.dart';

/// 多维探索中心与海报列表页 (Explore & Filter View)
class ExploreView extends StatefulWidget {
  final String? initialDiscType;
  final String? initialGenre;
  final String? initialType;
  final String? initialCollection;

  const ExploreView({
    Key? key,
    this.initialDiscType,
    this.initialGenre,
    this.initialType,
    this.initialCollection,
  }) : super(key: key);

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  final MediaLibClient _client = MediaLibClient();
  List<MediaItemModel> _items = [];
  bool _isLoading = true;

  late String _selectedType;
  late String _selectedDiscType;
  late String _selectedGenre;
  String _selectedSort = "最新添加";

  final List<String> _typeFilters = ["全部", "电影", "连续剧集", "动漫番剧"];
  final List<String> _discTypeFilters = ["全部", "4K UHD", "蓝光原盘", "3D立体", "小体积压制", "DVD怀旧"];
  final List<String> _genreFilters = [
    "全部", "武侠", "科幻", "悬疑", "恐怖", "喜剧", "动作", "犯罪", "奇幻", "动画", "惊悚", "战争", "纪录"
  ];
  final List<String> _sortOptions = ["最新添加", "上映年份", "⭐ 评分"];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? "全部";
    _selectedDiscType = widget.initialDiscType ?? "全部";
    _selectedGenre = widget.initialGenre ?? "全部";
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);

    String? discParam;
    if (_selectedDiscType == "4K UHD") discParam = "UHD";
    if (_selectedDiscType == "蓝光原盘") discParam = "BD";
    if (_selectedDiscType == "3D立体") discParam = "3D";
    if (_selectedDiscType == "小体积压制") discParam = "MiniBD";

    final list = await _client.listItems(
      discType: discParam,
      genre: _selectedGenre != "全部" ? _selectedGenre : null,
      collection: widget.initialCollection,
      pageSize: 80,
    );

    // 客户端排序
    if (_selectedSort == "上映年份") {
      list.sort((a, b) => b.year.compareTo(a.year));
    } else if (_selectedSort == "⭐ 评分") {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    }

    if (mounted) {
      setState(() {
        _items = list;
        _isLoading = false;
      });
    }
  }

  void _openDetail(MediaItemModel item) {
    showDialog(
      context: context,
      builder: (context) => MediaDetailModal(item: item),
    );
  }

  void _openSearch() {
    showDialog(
      context: context,
      builder: (context) => const SearchModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 700;

    return TVNavigationWrapper(
      onBackPressed: () => Navigator.of(context).pop(),
      onSearchPressed: _openSearch,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Row(
            children: [
              const Text(
                "多维探索中心",
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "共 ${_items.length} 部作品",
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded, color: AppColors.primary),
              tooltip: "搜索影视",
              onPressed: _openSearch,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              tooltip: "刷新列表",
              onPressed: _loadItems,
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            // 筛选控制区
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.6),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 媒介规格胶囊
                  _buildFilterRow("媒介规格", _discTypeFilters, _selectedDiscType, (val) {
                    setState(() => _selectedDiscType = val);
                    _loadItems();
                  }),
                  const SizedBox(height: 8),

                  // 2. 流派题材胶囊
                  _buildFilterRow("精选流派", _genreFilters, _selectedGenre, (val) {
                    setState(() => _selectedGenre = val);
                    _loadItems();
                  }),
                ],
              ),
            ),

            // 海报网格
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.movie_filter_outlined, size: 56, color: AppColors.textMuted),
                              const SizedBox(height: 14),
                              const Text("未找到符合当前筛选条件的影视资源", style: TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                                onPressed: () {
                                  setState(() {
                                    _selectedDiscType = "全部";
                                    _selectedGenre = "全部";
                                  });
                                  _loadItems();
                                },
                                child: const Text("重置所有筛选"),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: isDesktop ? 180 : 130,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _items.length,
                          itemBuilder: (ctx, i) {
                            final item = _items[i];
                            return TVFocusCard(
                              item: item,
                              onTap: () => _openDetail(item),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow(String label, List<String> options, String current, Function(String) onSelect) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              itemBuilder: (ctx, i) {
                final opt = options[i];
                final isSelected = current == opt;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => onSelect(opt),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.08)),
                      ),
                      child: Text(
                        opt,
                        style: TextStyle(
                          color: isSelected ? Colors.black : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
