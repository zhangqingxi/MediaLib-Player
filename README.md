# MediaLib Player (跨端发烧级影音播放器)

> 专为 **MediaLib** 打造的高性能跨平台发烧级播放器客户端。
> 覆盖 **Android TV (电视盒子 / 智能电视)**、**Android 手机版**、**Windows PC** 以及 **macOS**。

---

## 🌟 核心特性

1. **原盘菜单级交互 (BD-J / HDMV)**：
   - 内置 `libbluray` 蓝光原盘导航引擎；
   - PC 端采用自包含嵌入式 JRE 运行时架构（无须配置任何环境变量，开箱即用）；
   - TV 端支持 HDMV 交互菜单与正片智能 MPLS 探测。

2. **全规格杜比视界 (Dolby Vision P5 / P7 / P8) 解析与电视亮标**：
   - **Android TV 盒子端**：启用 `FEATURE_TunneledPlayback` 硬件安全通道直通电视，触发电视硬件 **Dolby Vision 亮标**；
   - **PC 端 (Windows)**：基于 `libmpv` + `libplacebo` + `libdovi`，在显卡着色器中执行 32 位浮点全精度逆变换（彻底纠偏 P5 偏绿偏紫，完整呈现 P7 双层 MEL/FEL 光影与色调映射）。

3. **gRPC 毫秒级抗风控起播换链与进度同步**：
   - 基于 `api/proto/v1/medialib.proto` 协议全链路打通；
   - 起播瞬间毫秒级向服务端换取 115 OpenAPI 302 直链；
   - 单向递增时钟打点仲裁（`timestamp_ms`），防止多端网络延迟回滚断点；
   - 支持跨设备双向流式遥控（`SyncSession`）。

4. **发烧级多端自适应海报墙 UI**：
   - **Android TV**：针对遥控器 D-Pad 优化的 3D 悬浮高光放大卡片与呼吸动效；
   - **PC 桌面端**：多专区胶囊（4K UHD / 蓝光原盘 / 3D立体 / 合辑）直达与流畅鼠标滚轮交互；
   - **手机端**：触控手势快进、音量与屏幕亮度调节。

---

## 📂 项目工程结构

```
MediaLib-Player/
  ├── protos/
  │     └── medialib.proto            # gRPC 核心通信协议
  ├── lib/
  │     ├── core/                     # 主题、全局常量与网络配置
  │     ├── grpc/                     # gRPC / REST 通信客户端与换链服务
  │     ├── models/                   # 媒体条目、BDINFO 胶囊、多音轨数据模型
  │     ├── player/                   # media_kit / libmpv 播放引擎与打点控制器
  │     └── ui/
  │           ├── shared/             # 自适应海报墙、全屏 OSD 播放器、BDINFO 徽标
  │           └── tv/                 # Android TV 遥控器 D-Pad 焦点卡片 (TVFocusCard)
  ├── android/                        # Android TV / 手机原生工程清单 (Leanback 支持)
  ├── windows/                        # Windows 原生桌面启动工程
  └── runtime/                        # PC 端内置 JRE / libbluray 架构目录
```

---

## 🚀 编译与运行

### 1. 运行桌面版 (Windows PC / macOS)
```bash
# 获取依赖
flutter pub get

# 运行 Windows 桌面端
flutter run -d windows
```

### 2. 构建 Android TV 盒子 / 手机版 APK
```bash
# 构建全架构 release APK (支持 Leanback TV Launcher)
flutter build apk --release
```

---

## 🔗 关联项目
- **MediaLib 后端核心**：[MediaLib](https://github.com/zhangqingxi/MediaLib)
