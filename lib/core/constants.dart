import 'package:flutter/material.dart';

/// MediaLib Player 全局发烧级影视主题与常量定义
class AppColors {
  // 深空发烧级背景体系（防 OLED 烧屏与暗室观影优化）
  static const Color background = Color(0xFF0A0E17);
  static const Color surface = Color(0xFF131B2C);
  static const Color surfaceLight = Color(0xFF1E293B);
  static const Color card = Color(0xFF162032);
  static const Color cardHover = Color(0xFF22314E);

  // 品牌流光主色
  static const Color primary = Color(0xFF38BDF8);       // 天空蓝
  static const Color primaryGlow = Color(0xFF0284C7);
  static const Color accent = Color(0xFFF59E0B);        // 发烧金 / 杜比标
  static const Color dolbyVision = Color(0xFFFFB703);   // 杜比视界金
  static const Color atmos = Color(0xFF06B6D4);          // 杜比全景声蓝

  // 文字分级
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // 状态指示色
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

class AppConstants {
  static const String appName = "MediaLib Player";
  static const String appVersion = "1.0.0";
  
  // 默认服务端连接地址 (支持局域网 IP / 域名 / 端口)
  static const String defaultServerHost = "127.0.0.1";
  static const int defaultServerPort = 8080;
  static const int defaultGrpcPort = 50051;

  // 播放打点间隔（秒）
  static const int progressReportIntervalSec = 5;

  // 专区分类
  static const List<String> discTypes = ["全部", "4K UHD", "蓝光原盘", "3D立体", "DVD怀旧", "剧集番剧"];
  static const List<String> genres = ["全部", "武侠", "动作", "科幻", "悬疑", "恐怖", "喜剧", "犯罪", "奇幻", "动画"];
}
