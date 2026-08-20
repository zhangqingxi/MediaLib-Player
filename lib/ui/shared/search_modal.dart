import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/media_item.dart';
import '../../grpc/client.dart';
import '../tv/tv_focus_card.dart';
import 'media_detail_modal.dart';

/// 全局即时模糊搜索浮层 (Instant Global Search Overlay)
class SearchModal extends StatefulWidget {
  const SearchModal({Key? key}) : super(key: key);

  @override
  State<SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<SearchModal> {
  final TextEditingController _searchController = TextEditingController();
  final MediaLibClient _client = MediaLibClient();
  Timer? _debounceTimer;

  List<MediaItemModel> _results = [];
  bool _isLoading = false;
  String _selectedFilter = "全部";

  final List<String> _filters = ["全部", "4K UHD", "蓝光原盘", "3D立体", "科幻", "动作", "悬疑"];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch();
    });
  }

  Future<void> _executeSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty && _selectedFilter == "全部") {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    String? discType;
    String? resolution;
    String? genre;

    if (_selectedFilter == "4K UHD") {
      resolution = "4K";
    } else if (_selectedFilter == "蓝光原盘") {
      discType = "BD";
    } else if (_selectedFilter == "3D立体") {
      discType = "3D";
    } else if (_selectedFilter != "全部") {
      genre = _selectedFilter;
    }

    final items = await _client.listItems(
      keyword: query,
      discType: discType,
      resolution: resolution,
      genre: genre,
      pageSize: 40,
    );

    if (mounted) {
      setState(() {
        _results = items;
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 1000,
        height: 680,
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
            // 1. 顶部搜索输入框与关闭按键
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.primary, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
                      decoration: const InputDecoration(
                        hintText: "输入片名、原名、影人或拼音搜索影视...",
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 16),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        _executeSearch();
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. 快捷标签筛选行
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                itemBuilder: (ctx, i) {
                  final f = _filters[i];
                  final isSelected = _selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceLight,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedFilter = f);
                          _executeSearch();
                        }
                      },
                    ),
                  );
                },
              ),
            ),

            // 3. 搜索结果网格
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchController.text.isEmpty
                                    ? Icons.manage_search_rounded
                                    : Icons.sentiment_dissatisfied,
                                size: 54,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.isEmpty
                                    ? "输入关键词或点击标签即时搜索"
                                    : "未找到符合条件的影视资源",
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: isDesktop ? 180 : 130,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final item = _results[i];
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
}
