import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/media_item.dart';

/// 蓝光母带规格胶囊徽标组件 (BDINFO Capsule Badge)
class BDInfoCapsuleWidget extends StatelessWidget {
  final MediaItemModel? item;
  final BDInfoCapsuleModel? bdinfo;
  final bool isCompact;

  const BDInfoCapsuleWidget({
    Key? key,
    this.item,
    this.bdinfo,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Widget> badges = [];

    final is4k = item?.is4K ?? (bdinfo?.video?.resolutionLabel.contains("4K") ?? false);
    final resolution = item?.resolution ?? bdinfo?.video?.resolutionLabel ?? "";
    final discType = item?.discType ?? bdinfo?.sourceType ?? "";
    final hasDolbyVision = item?.hasDolbyVision ?? (bdinfo?.video?.isDolbyVision ?? false);
    final isHdr = bdinfo?.video?.isHDR ?? false;
    final hasAtmos = item?.hasAtmos ?? (bdinfo?.hasAtmos ?? false);

    // 1. 分辨率标
    if (is4k) {
      badges.add(_buildBadge("4K UHD", Colors.amber.shade400, Colors.black));
    } else if (resolution.contains("1080") || discType == "BD") {
      badges.add(_buildBadge("1080p BD", Colors.blue.shade300, Colors.black));
    }

    // 2. 杜比视界金标 / HDR10 标
    if (hasDolbyVision) {
      badges.add(_buildBadge("VISION", AppColors.dolbyVision, Colors.black, isBold: true));
    } else if (isHdr) {
      badges.add(_buildBadge("HDR10", Colors.orange.shade300, Colors.black));
    }

    // 3. 杜比全景声 / 次世代音轨标
    if (hasAtmos) {
      badges.add(_buildBadge("ATMOS", AppColors.atmos, Colors.black));
    } else if (bdinfo != null && bdinfo!.audioTracks.isNotEmpty) {
      final codec = bdinfo!.audioTracks.first.codec;
      if (codec.contains("DTS")) {
        badges.add(_buildBadge("DTS-HD", Colors.red.shade300, Colors.black));
      } else if (codec.contains("TrueHD")) {
        badges.add(_buildBadge("TrueHD", Colors.cyan.shade300, Colors.black));
      }
    }

    // 4. 原盘形态标
    if (discType == "3D") {
      badges.add(_buildBadge("3D立体", Colors.teal.shade300, Colors.black));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: isCompact ? 4 : 6,
      runSpacing: 4,
      children: badges,
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor, {bool isBold = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 5 : 7,
        vertical: isCompact ? 1.5 : 2.5,
      ),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.92),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: isCompact ? 9.5 : 11,
          fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
