import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants.dart';
import '../../models/media_item.dart';
import '../../grpc/client.dart';
import '../tv/tv_focus_card.dart';
import '../tv/tv_navigation_wrapper.dart';
import 'media_detail_modal.dart';
import 'settings_modal.dart';
import 'search_modal.dart';
import 'collection_detail_modal.dart';
import 'explore_view.dart';
import 'player_view.dart';

/// 跨端自适应发烧级海报墙主界面 (Curated Poster Wall Home)
class PosterWallView extends StatefulWidget {
  const PosterWallView({Key? key}) : super(key: key);

  @override
  State<PosterWallView> createState() => _PosterWallViewState();
}

class _PosterWallViewState extends State<PosterWallView> {
  final MediaLibClient _client = MediaLibClient();
  List<MediaItemModel> _allItems = [];
  bool _isLoading = true;
  int _activeHeroIndex = 0;

  // 8 大发烧影视专区元数据定义
  final List<Map<String, dynamic>> _flagshipZones = [
    {
      'id': '4k',
      'title': '4K 极画质专区',
      'subtitle': '杜比视界 · HDR10+ · 2160p UHD 原盘',
      'tag': 'ULTRA HD',
      'tagBg': Color(0xFF78350F),
      'tagText': Color(0xFFFCD34D),
      'gradient': [Color(0xFF451A03), Color(0xFF0F172A), Color(0xFF020617)],
      'border': Color(0xFFB45309),
      'icon': '🌟',
      'desc': '顶级高码率 4K 原盘串流，支持动态 HDR 元数据与高精色彩还原',
      'discType': '4K UHD',
    },
    {
      'id': 'boxset',
      'title': '宇宙系列合辑',
      'subtitle': '漫威 · 星球大战 · 007 · 指环王全系',
      'tag': 'BOXSETS',
      'tagBg': Color(0xFF1E3A8A),
      'tagText': Color(0xFF7DD3FC),
      'gradient': [Color(0xFF172554), Color(0xFF0F172A), Color(0xFF020617)],
      'border': Color(0xFF1D4ED8),
      'icon': '🪐',
      'desc': '按宇宙编年史与合集收录，一键连续播放系列史诗巨制',
      'isBoxset': true,
    },
    {
      'id': '3d',
      'title': '3D 立体视觉专区',
      'subtitle': 'MVC 编码 · 左右/上下格式 · 双目立体',
      'tag': '3D BLU-RAY',
      'tagBg': Color(0xFF164E63),
      'tagText': Color(0xFF67E8F9),
      'gradient': [Color(0xFF083344), Color(0xFF0F172A), Color(0xFF020617)],
      'border': Color(0xFF0E7490),
      'icon': '🕶️',
      'desc': '沉浸式双目立体原盘画质，支持头显与 3D 电视直接输出',
      'discType': '3D立体',
    },
    {
      'id': 'disc',
      'title': '蓝光原盘发烧专区',
      'subtitle': 'BD-ISO · BDMV · 母带直出原轨',
      'tag': 'ORIGINAL BD',
      'tagBg': Color(0xFF312E81),
      'tagText': Color(0xFFA5B4FC),
      'gradient': [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF020617)],
      'border': Color(0xFF4338CA),
      'icon': '💿',
      'desc': '无损封装原汁原味，直通原生多国全景声与 DTS:X 音轨',
      'discType': '蓝光原盘',
    },
    {
      'id': 'anime',
      'title': '动漫新番与国漫',
      'subtitle': '连载番剧 · 剧场版 · BDRip 高清重置',
      'tag': 'ANIME ZONE',
      'tagBg': Color(0xFF881337),
      'tagText': Color(0xFFFDA4AF),
      'gradient': [Color(0xFF4C0519), Color(0xFF0F172A), Color(0xFF020617)],
      'border': Color(0xFFBE123C),
      'icon': '🌸',
      'desc': '热门日漫剧场版、国漫连载与全套无损原盘音质收藏',
      'type': 'anime',
    },
    {
      'id': 'tv',
      'title': '连续剧集连载专区',
      'subtitle': '美剧 · 华语剧集 · 英剧 · 4K 多季精选',
      'tag': 'TV SERIES',
      'tagBg': Color(0xFF064E3B),
      'tagText': Color(0xFF6EE7B7),
      'gradient': [Color(0xFF022C22), Color(0xFF0F172A), Color(0xFF020617)],
      'border': Color(0xFF047857),
      'icon': '📺',
      'desc': '分季自动整理与单集精准匹配，支持连播与跳过片头片尾',
      'type': 'tv',
    },
    {
      'id': 'mini',
      'title': '小体积压制精选',
      'subtitle': 'MiniBD · Web-DL · 高码率 H.265',
      'tag': 'MINI SIZE',
      'tagBg': Color(0xFF0C4A6E),
      'tagText': Color(0xFF7DD3FC),
      'gradient': [Color(0xFF082F49), Color(0xFF0F172A), Color(0xFF020617)],
      'border': Color(0xFF0369A1),
      'icon': '📦',
      'desc': '兼顾画质与存储空间的高精压缩版，移动设备流畅解码',
      'discType': '小体积压制',
    },
    {
      'id': 'atmos',
      'title': '杜比全景声音效专区',
      'subtitle': 'Dolby Atmos · DTS:X · 7.1.4 沉浸声道',
      'tag': 'AUDIO PHILE',
      'tagBg': Color(0xFF581C87),
      'tagText': Color(0xFFD8B4FE),
      'gradient': [Color(0xFF3B0764), Color(0xFF0F172A), Color(0xFF020617)],
      'border': Color(0xFF7E22CE),
      'icon': '🎙️',
      'desc': '专为家庭影院打造的声音空间，定位准确且震撼低音直通',
      'genre': '全景声',
    },
  ];

  // 6 大沉浸风格流派卡片定义
  final List<Map<String, dynamic>> _genreExhibits = [
    {
      'title': '邵氏武侠 · 刀光剑影',
      'desc': '大醉侠 / 新独臂刀 / 卧虎藏龙 4K 数码修复',
      'tag': '武侠仙侠 · 原盘修复',
      'gradient': [Color(0xFF450A0A), Color(0xFF0F172A), Color(0xFF020617)],
      'border': Color(0xFF991B1B),
      'tagBg': Color(0xFF7F1D1D),
      'tagText': Color(0xFFFCA5A5),
      'icon': '🗡️',
      'genre': '武侠',
    },
    {
      'title': '硬核科幻 · 赛博未来',
      'desc': '星际穿越 / 银翼杀手 / 沙丘 4K 杜比视界巨幕',
      'tag': '太空科幻 · 杜比视界',
      'gradient': [Color(0xFF083344), Color(0xFF0F172A), Color(0xFF020617)],
      'border': Color(0xFF155E75),
      'tagBg': Color(0xFF164E63),
      'tagText': Color(0xFF67E8F9),
      'icon': '🚀',
      'genre': '科幻',
    },
    {
      'title': '恐怖惊悚 · 怪谈民俗',
      'desc': '僵尸先生 / 咒 / 招魂 / 双瞳 杜比全景声重温',
      'tag': '恐怖悬疑 · 沉浸声场',
      'gradient': [Color(0xFF022C22), Color(0xFF0F172A), Color(0xFF020617)],
      'border': Color(0xFF065F46),
      'tagBg': Color(0xFF064E3B),
      'tagText': Color(0xFF6EE7B7),
      'icon': '👻',
      'genre': '恐怖',
    },
    {
      'title': '港产喜剧 · 经典无厘头',
      'desc': '周星驰系列 / 东成西就 / 家有喜事 经典原声',
      'tag': '喜剧合家欢 · 粤语原声',
      'gradient': [Color(0xFF451A03), Color(0xFF0F172A), Color(0xFF020617)],
      'border': Color(0xFF9A3412),
      'tagBg': Color(0xFF7C2D12),
      'tagText': Color(0xFFFDE047),
      'icon': '😂',
      'genre': '喜剧',
    },
    {
      'title': '动作警匪 · 极限特工',
      'desc': '速度与激情 / 碟中谍 / 007 / 杀破狼 原盘高码',
      'tag': '极限动作 · 爆燃追车',
      'gradient': [Color(0xFF431407), Color(0xFF0F172A), Color(0xFF020617)],
      'border': Color(0xFF9A3412),
      'tagBg': Color(0xFF7C2D12),
      'tagText': Color(0xFFFDBA74),
      'icon': '🏎️',
      'genre': '动作',
    },
    {
      'title': '悬疑犯罪 · 神级反转',
      'desc': '看不见的客人 / 盗梦空间 / 记忆碎片 烧脑神作',
      'tag': '烧脑悬疑 · 高分反转',
      'gradient': [Color(0xFF3B0764), Color(0xFF0F172A), Color(0xFF020617)],
      'border': Color(0xFF6B21A8),
      'tagBg': Color(0xFF581C87),
      'tagText': Color(0xFFD8B4FE),
      'icon': '🕵️',
      'genre': '悬疑',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAllMedia();
  }

  Future<void> _loadAllMedia() async {
    setState(() => _isLoading = true);
    await _client.init();
    final items = await _client.listItems(pageSize: 100);
    if (mounted) {
      setState(() {
        _allItems = items;
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

  void _openSettingsModal() {
    showDialog(
      context: context,
      builder: (context) => ServerSettingsModal(
        onSaved: () => _loadAllMedia(),
      ),
    );
  }

  void _openCollectionsModal() {
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
                  BoxShadow(color: Colors.black.withOpacity(0.85), blurRadius: 36),
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

  void _navigateToExplore({String? discType, String? genre, String? type}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExploreView(
          initialDiscType: discType,
          initialGenre: genre,
          initialType: type,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return TVNavigationWrapper(
      onMenuPressed: _openSettingsModal,
      onSearchPressed: _openSearchModal,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F17), // WebUI 同款深邃暗黑蓝
        body: SafeArea(
          child: Column(
            children: [
              // 1. 顶部全局状态与搜索导航栏
              _buildTopBar(isDesktop),

              // 2. 主体滚动内容区
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 0. 旗舰焦点巨幕 (Hero Spotlight Banner)
                            if (_allItems.isNotEmpty)
                              _buildActiveHeroBanner(_allItems[_activeHeroIndex % _allItems.length], isDesktop)
                            else
                              _buildEmptyHeroBanner(isDesktop),

                            const SizedBox(height: 32),

                            // 1. 发烧影视专区 (Flagship Zones Grid)
                            _buildSectionHeader("发烧影视专区", "4K UHD · 原盘 · 3D · 剧集 · 全景声", () => _navigateToExplore()),
                            const SizedBox(height: 16),
                            _buildFlagshipZonesGrid(isDesktop),

                            const SizedBox(height: 36),

                            // 2. 精选电影流派大卡片 (Genre Exhibits)
                            _buildSectionHeader("精选电影流派", "武侠 · 科幻 · 悬疑 · 港产喜剧 · 动作", () => _navigateToExplore()),
                            const SizedBox(height: 16),
                            _buildGenreExhibitsGrid(isDesktop),

                            // 3. 最新入库海报瀑布流 (如果媒体库有内容)
                            if (_allItems.isNotEmpty) ...[
                              const SizedBox(height: 36),
                              _buildSectionHeader("最新入库影视", "最近更新 · 原盘解析完成", () => _navigateToExplore()),
                              const SizedBox(height: 16),
                              _buildRecentPosterRow(),
                            ],

                            const SizedBox(height: 48),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部全局导航栏 (Top Bar)
  Widget _buildTopBar(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          // 左侧品牌 Logo 与标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                ),
                child: const Icon(Icons.play_circle_filled_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        "MediaLib",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("PLAYER", style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Text(
                    "影视精选海报墙 · Media Library Highlights",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),

          // 搜索按键 (快捷键 /)
          InkWell(
            onTap: _openSearchModal,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text("全域搜索", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text("/", style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 多维探索中心直达按钮
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceLight,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            onPressed: () => _navigateToExplore(),
            icon: const Icon(Icons.explore_outlined, size: 17, color: AppColors.primary),
            label: const Text("多维探索", style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),

          // 系列合辑
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined, color: AppColors.textSecondary, size: 20),
            tooltip: "经典系列合辑",
            onPressed: _openCollectionsModal,
          ),
          const SizedBox(width: 4),

          // 刷新
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
            tooltip: "刷新媒体库",
            onPressed: _loadAllMedia,
          ),
          const SizedBox(width: 4),

          // 设置与账号
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 20),
            tooltip: "服务器与账号设置",
            onPressed: _openSettingsModal,
          ),
        ],
      ),
    );
  }

  /// 模块标题与「进入专区 →」
  Widget _buildSectionHeader(String title, String subtitle, VoidCallback onMore) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.2),
            ),
            const SizedBox(width: 10),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        TextButton(
          onPressed: onMore,
          child: const Row(
            children: [
              Text("进入专区", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: 12),
            ],
          ),
        ),
      ],
    );
  }

  /// 空库时的 1:1 WebUI 风格发烧级就绪引导巨幕 (Empty State Hero Banner)
  Widget _buildEmptyHeroBanner(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF0F172A),
            Color(0xFF1E1B4B),
          ],
        ),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 24),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左侧：文案与按钮
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                      ),
                      child: const Text("MEDIALIB 媒体库", style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    const Text("发烧级家庭影院就绪", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF451A03),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF78350F)),
                      ),
                      child: const Text("4K UHD · 杜比视界 P7 · 全景声", style: TextStyle(color: Color(0xFFFCD34D), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "高清原盘海报墙已就绪 · 发烧音画中枢",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "支持 115 开放平台、WebDAV 协议与本地磁盘挂载，内置防风控流控卫士与毫秒级 302 直链分发。\n系统自动监听目录变动，完成 TMDB 智能刮削、BDINFO 蓝光双层杜比视界 (FEL/MEL) 与 TrueHD/DTS:X 多音轨全自动识别提取。",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _navigateToExplore(),
                      icon: const Icon(Icons.explore_rounded, size: 18),
                      label: const Text("进入多维探索中心", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _openSettingsModal,
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text("服务器与账号配置"),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 右侧：特性透视面板 (4 宫格)
          if (isDesktop) ...[
            const SizedBox(width: 32),
            Container(
              width: 320,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success)),
                          const SizedBox(width: 6),
                          const Text("引擎特性透视", style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Text("BDINFO & VFS", style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace')),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 16),
                  Row(
                    children: [
                      _buildFeatureTile("🌟 4K UHD 原盘", "杜比视界 FEL P7", "双层 12-bit 色深透传", const Color(0xFFFCD34D)),
                      const SizedBox(width: 8),
                      _buildFeatureTile("🔊 次世代音轨", "TrueHD Atmos", "7.1.4 沉浸声源码直出", const Color(0xFF38BDF8)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildFeatureTile("🛡️ 防封流控", "115 令牌桶削峰", "302 静默预换链保护", const Color(0xFF34D399)),
                      const SizedBox(width: 8),
                      _buildFeatureTile("⚡ 极速响应", "多级 SSD VFS", "毫秒级文件列表缓存", const Color(0xFFC084FC)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureTile(String tag, String title, String sub, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tag, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1),
            const SizedBox(height: 1),
            Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 9), maxLines: 1),
          ],
        ),
      ),
    );
  }

  /// 媒体库有内容时的焦点轮播大图 (Active Hero Banner)
  Widget _buildActiveHeroBanner(MediaItemModel item, bool isDesktop) {
    return Container(
      width: double.infinity,
      height: isDesktop ? 340 : 260,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 24),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 背景大图
          if (item.backdropUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: item.backdropUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox(),
            ),

          // 渐变黑影
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF0B0F17).withOpacity(0.95),
                  const Color(0xFF0B0F17).withOpacity(0.75),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // 内容信息
          Padding(
            padding: const EdgeInsets.all(28),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 规格标签行
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "${item.discType} 蓝光原盘",
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (item.hasDolbyVision) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.dolbyVision),
                              ),
                              child: const Text(
                                "DOLBY VISION",
                                style: TextStyle(color: AppColors.dolbyVision, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          if (item.rating > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.white, size: 12),
                                  const SizedBox(width: 2),
                                  Text(
                                    item.rating.toStringAsFixed(1),
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 片名
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // 简介
                      if (item.overview.isNotEmpty)
                        Text(
                          item.overview,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 16),

                      // 按钮行
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => PlayerView(item: item)),
                              );
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: const Text("立即播放", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withOpacity(0.3)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _openDetailModal(item),
                            icon: const Icon(Icons.info_outline, size: 16),
                            label: const Text("影片详情"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 8 大发烧影视专区网格 (Flagship Zones Grid)
  Widget _buildFlagshipZonesGrid(bool isDesktop) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 4 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 2.1,
      ),
      itemCount: _flagshipZones.length,
      itemBuilder: (ctx, i) {
        final z = _flagshipZones[i];
        return InkWell(
          onTap: () {
            if (z['isBoxset'] == true) {
              _openCollectionsModal();
            } else {
              _navigateToExplore(
                discType: z['discType'],
                type: z['type'],
                genre: z['genre'],
              );
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: z['gradient'] as List<Color>,
              ),
              border: Border.all(color: (z['border'] as Color).withOpacity(0.6)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: z['tagBg'] as Color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        z['tag'] as String,
                        style: TextStyle(color: z['tagText'] as Color, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Row(
                      children: [
                        Text("进入", style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        SizedBox(width: 2),
                        Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 10),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(z['icon'] as String, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            z['title'] as String,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      z['subtitle'] as String,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 6 大精选流派大卡片 (Genre Exhibits Grid)
  Widget _buildGenreExhibitsGrid(bool isDesktop) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 3 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 2.2,
      ),
      itemCount: _genreExhibits.length,
      itemBuilder: (ctx, i) {
        final g = _genreExhibits[i];
        return InkWell(
          onTap: () => _navigateToExplore(genre: g['genre'] as String),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: g['gradient'] as List<Color>,
              ),
              border: Border.all(color: (g['border'] as Color).withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: g['tagBg'] as Color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        g['tag'] as String,
                        style: TextStyle(color: g['tagText'] as Color, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Row(
                      children: [
                        Text("进入专区", style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        SizedBox(width: 2),
                        Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 10),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(g['icon'] as String, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            g['title'] as String,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      g['desc'] as String,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 最新入库海报流
  Widget _buildRecentPosterRow() {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _allItems.take(15).length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (ctx, i) {
          final item = _allItems[i];
          return SizedBox(
            width: 125,
            child: TVFocusCard(
              item: item,
              onTap: () => _openDetailModal(item),
            ),
          );
        },
      ),
    );
  }
}
