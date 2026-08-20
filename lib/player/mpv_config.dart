import 'dart:io';

/// 发烧级 MPV / libplacebo / libdovi GPU 渲染管线配置
class MPVEngineConfig {
  /// 生成针对当前平台的 MPV 最佳画质初始化参数字典
  static Map<String, dynamic> getOptimizedProperties({
    bool enableDolbyVisionP7Transform = true,
    bool enableAudioPassthrough = true,
    bool isExternalHDRDisplay = true,
  }) {
    final Map<String, dynamic> props = {
      // 1. 极速内存缓冲池 (32MB)
      "demuxer-max-bytes": 32 * 1024 * 1024,
      "demuxer-max-back-bytes": 16 * 1024 * 1024,
      "demuxer-readahead-secs": 20,
    };

    if (Platform.isWindows) {
      // ===== Windows PC 平台发烧级 GPU-Next 渲染管线 =====
      props.addAll({
        // 渲染后端与图形 API
        "vo": "gpu-next",
        "gpu-api": "d3d11",
        "gpu-context": "d3d11",
        "hwdec": "d3d11va",

        // 杜比视界 RPU 动态元数据与色调映射
        "target-colorspace-hint": isExternalHDRDisplay ? "yes" : "no",
        "tone-mapping": "spline",
        "tone-mapping-mode": "hybrid",
        "tone-mapping-max-boost": "1.5",
        "gamut-mapping-mode": "clip",
        "hdr-compute-peak": "yes",

        // libdovi Profile 7 FEL/MEL 实时解析
        "dovi-p7-rpu": enableDolbyVisionP7Transform ? "yes" : "no",

        // 音频直通源码透传 (TrueHD Atmos / DTS-HD MA / AC3)
        "audio-channels": "7.1,5.1,stereo",
        "audio-spdif": enableAudioPassthrough ? "ac3,dts,eac3,truehd,dts-hd" : "",
        "audio-pitch-correction": "yes",
      });
    } else if (Platform.isAndroid) {
      // ===== Android TV / 盒子平台硬件隧道 (Tunnel Mode) 管线 =====
      props.addAll({
        "vo": "gpu",
        "hwdec": "mediacodec",
        "mediacodec-all": "yes",
        "audio-channels": "auto",
        "audio-spdif": enableAudioPassthrough ? "ac3,eac3,dts,truehd,dts-hd" : "",
      });
    } else if (Platform.isMacOS) {
      // ===== macOS 平台 Metal / MoltenVK 渲染管线 =====
      props.addAll({
        "vo": "gpu-next",
        "gpu-api": "vulkan",
        "hwdec": "videotoolbox",
        "target-colorspace-hint": "yes",
      });
    }

    return props;
  }
}
