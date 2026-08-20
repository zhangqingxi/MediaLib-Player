import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants.dart';
import '../../models/media_item.dart';
import '../shared/bdinfo_capsule_widget.dart';

/// Android TV 遥控器与 PC 键鼠通用的发烧级海报获焦卡片 (Focusable Poster Card)
class TVFocusCard extends StatefulWidget {
  final MediaItemModel item;
  final VoidCallback onTap;
  final double width;
  final double height;

  const TVFocusCard({
    Key? key,
    required this.item,
    required this.onTap,
    this.width = 175,
    this.height = 255,
  }) : super(key: key);

  @override
  State<TVFocusCard> createState() => _TVFocusCardState();
}

class _TVFocusCardState extends State<TVFocusCard> {
  bool _isFocused = false;
  bool _isHovered = false;

  bool get _isActive => _isFocused || _isHovered;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onFocusChange: (f) {
        setState(() => _isFocused = f);
      },
      onShowHoverHighlight: (h) {
        setState(() => _isHovered = h);
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isActive ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isActive ? AppColors.primary : Colors.white.withOpacity(0.08),
                width: _isActive ? 2.5 : 1.0,
              ),
              boxShadow: _isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.45),
                        blurRadius: 18,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. 海报底图
                  widget.item.posterUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.item.posterUrl,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Container(
                            color: AppColors.card,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                          ),
                          errorWidget: (ctx, url, err) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),

                  // 2. 顶部左侧发烧规格胶囊 (4K / 杜比 / 全景声)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: BDInfoCapsuleWidget(item: widget.item, isCompact: true),
                  ),

                  // 3. 底部阴影遮罩与片名
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.85),
                            Colors.black.withOpacity(0.96),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (widget.item.year > 0)
                                Text(
                                  "${widget.item.year}",
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                              const Spacer(),
                              if (widget.item.rating > 0)
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 12),
                                    const SizedBox(width: 2),
                                    Text(
                                      widget.item.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.card,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.movie_outlined, size: 36, color: AppColors.textMuted),
              const SizedBox(height: 8),
              Text(
                widget.item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
