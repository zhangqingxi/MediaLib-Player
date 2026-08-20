# MediaLib Player Windows 桌面端环境配置与构建部署指南

本文档面向 Windows 开发者与发烧友用户，详细介绍 **MediaLib-Player** 桌面客户端的系统环境要求、构建工具链安装、零环境变量自包含运行机制、杜比视界 (Dolby Vision) / HDR 点亮配置以及独立发行包打包。

---

## 1. 系统与硬件配置要求

| 维度 | 最低配置 | 推荐配置 (发烧级 4K HDR/原盘) |
| :--- | :--- | :--- |
| **操作系统** | Windows 10 64-bit (1809 及以上) | **Windows 11 64-bit (22H2/23H2+)** (HDR 色彩管理与自动色调映射更佳) |
| **处理器 (CPU)** | Intel Core i3 8代 / AMD Ryzen 1000 系列 | Intel Core i5 10代+ / AMD Ryzen 3000 系列及以上 |
| **显卡 (GPU)** | NVIDIA GTX 960 (支持 HEVC 10-bit 硬解) / AMD RX 460 / Intel HD 630 | **NVIDIA RTX 2060 / GTX 1660+ / AMD RX 5600+ / Intel Arc A380+** (支持 Direct3D 11VA / Vulkan 与 libplacebo 着色器) |
| **显示器/电视** | 普通 1080p 显示器 (支持自动 SDR 色调映射) | **支持 HDR10 / 杜比视界 (Dolby Vision) 的 4K 显示器或 OLED/MiniLED 电视** |
| **连接线缆** | HDMI 1.4 / DP 1.2 | **HDMI 2.0b / HDMI 2.1 / DisplayPort 1.4+** 高速线缆 (支持 4K 60Hz 10-bit HDR) |

---

## 2. 源码构建环境准备 (针对开发者)

若需要从源码编译 Windows 桌面端应用，需准备以下工具链：

### 2.1 安装 Visual Studio 2022 C++ 构建工具
Flutter Windows 桌面端依赖 MSVC C++ 编译器及 Windows SDK：
1. 下载并安装 [Visual Studio 2022 Community (社区版)](https://visualstudio.microsoft.com/vs/community/)；
2. 在 Visual Studio Installer 安装组件中，**务必勾选「使用 C++ 的桌面开发」(Desktop development with C++)**；
3. 确认右侧安装详细信息中包含：
   - **MSVC v143 - VS 2022 C++ x64/x86 生成工具**；
   - **Windows 10/11 SDK** (最新版本)；
   - **适用于 Windows 的 C++ CMake 工具**。

### 2.2 安装 Flutter SDK
1. 下载并解压 [Flutter SDK](https://flutter.dev/docs/get-started/install/windows)（推荐 Flutter 3.16.0 及以上版本）；
2. 将 `flutter\bin` 目录追加到系统的 `Path` 环境变量中；
3. 在 PowerShell 中执行环境诊断，确保全项为绿色对勾：
   ```powershell
   flutter doctor
   ```
   *注：确保 `[✓] Windows Version`、`[✓] Flutter`、`[✓] Visual Studio - develop for Windows` 均已就绪。*

### 2.3 启用 Flutter Windows 桌面端支持
```powershell
flutter config --enable-windows-desktop
```

---

## 3. 零环境变量架构与便携自包含说明 (普通用户免配置)

**MediaLib-Player** 针对发烧级影音核心（libmpv、libplacebo、libdovi、libbluray BD-J 原盘 Java 菜单引擎）进行了**全自包含嵌入式封装**，普通终端用户安装或解压运行即可，**无需在 Windows 系统中手动配置任何环境变量**：

1. **GPU 渲染动态链接库 (`libmpv.dll` / `libplacebo.dll`)**：
   - 由 `media_kit_libs_windows_video` 在编译时自动内嵌打包到应用程序同级目录 (`build/windows/x64/runner/Release/`)；
   - 启动时自动通过相对路径定位，支持 Direct3D 11VA 与 Vulkan 硬件加速。
2. **蓝光原盘 BD-J 菜单运行时 (`Embedded JRE`)**：
   - 原盘菜单所需的微型 Java 虚拟机置于应用根目录 `./runtime/jre/` 下；
   - 播放器启动时在内存级将当前路径注入 `JAVA_HOME`，完全不污染宿主机系统环境。

---

## 4. 本地编译、调试与生产打包

### 4.1 获取工程依赖
进入播放器源码根目录执行：
```powershell
cd D:\Projects\MediaLib-Player
flutter pub get
```

### 4.2 本地运行与联调
```powershell
# 启动 Windows 桌面端并连接本机的 MediaLib 服务端 (默认端口 :18080 或 :8080)
flutter run -d windows
```

### 4.3 生产环境独立 Release 打包
执行全量 Release 编译：
```powershell
flutter build windows --release
```
编译成功后，生成的绿色便携版目录位于：
```
D:\Projects\MediaLib-Player\build\windows\x64\runner\Release\
  ├── medialib_player.exe               # 播放器主程序
  ├── flutter_windows.dll               # Flutter 桌面渲染核心
  ├── media_kit_libs_windows_video.dll  # libmpv / libplacebo 硬件加速动态库
  ├── data/                             # 静态资源与字体
  └── runtime/                          # 嵌入式 JRE (用于 BD-J 原盘菜单)
```
用户只需将整个 `Release` 文件夹打包压缩（如 `MediaLib-Player-v1.0-Win64.zip`），解压后双击 `medialib_player.exe` 即可直接运行。

---

## 5. 发烧级杜比视界 (Dolby Vision) 与 HDR 最佳显卡设置

为了让支持杜比视界/HDR 的显示器或电视发挥最佳画质，建议在 Windows 桌面端进行以下设置：

### 5.1 Windows 系统级 HDR 开启
1. 打开 Windows **「设置」 -> 「系统」 -> 「屏幕」**；
2. 选中连接的电视或 HDR 显示器，打开 **「使用 HDR」** 开关；
3. 将 **「自动 HDR (Auto HDR)」** 保持开启，并在「HDR 显示校准」中完成峰值亮度校准。

### 5.2 NVIDIA 显卡控制面板颜色设置
1. 桌面右键打开 **「NVIDIA 控制面板」** -> 展开左侧 **「显示」 -> 「更改分辨率」**；
2. 在底部选择 **「使用 NVIDIA 颜色设置」**：
   - **桌面颜色深度**：最高 (32 位)；
   - **输出颜色深度**：**10 bpc** 或 **12 bpc** (根据显示器 HDMI/DP 带宽上限选择)；
   - **输出颜色格式**：**RGB** (PC 监视器) 或 **YCbCr422 / YCbCr444** (电视)；
   - **输出动态范围**：**全范围 (Full)**。
3. 点击「应用」保存。

### 5.3 源码音频透传 (Bitstream Passthrough)
若通过显卡 HDMI 接口直连 eARC 回音壁、功放或发烧级家庭影院：
- 在 Windows 声音设置中，将输出设备选择为 HDMI / 功放设备；
- 在 MediaLib-Player 的设置弹窗中开启 **「音频直通源码透传」**；
- 播放 DTS-HD MA、TrueHD、Dolby Atmos (杜比全景声) 时，功放将精准点亮原生音频源码徽标。

---

## 6. Windows 桌面端全局快捷键一览表

| 快捷键 | 功能操作 | 适用场景 |
| :--- | :--- | :--- |
| **`Space` / `Enter`** | 播放 / 暂停切换 | 视频播放中 |
| **`→` (方向键右)** | 快进 10 秒 | 视频播放中 |
| **`←` (方向键左)** | 快退 10 秒 | 视频播放中 |
| **`↑` (方向键上)** | 增加音量 (+5%) | 视频播放中 |
| **`↓` (方向键下)** | 降低音量 (-5%) | 视频播放中 |
| **`I` / `S`** | 呼出 / 关闭 **Stats for Nerds** 技术监控浮层 | 视频播放中 |
| **`M` / `T`** | 呼出 **音轨 / 字幕 / 倍速** 快速调谐面板 | 视频播放中 |
| **`E`** | 呼出 **电视剧快速选集抽屉** (无需退出全屏) | 电视剧播放中 |
| **`B`** | 呼出 **原盘顶层菜单 (BD-J / HDMV)** | 蓝光原盘播放中 |
| **`ESC` / `Backspace`** | 退出全屏 / 关闭弹窗 / 返回上一级 | 全局 |
| **`/` 或 `Ctrl + F`** | 呼出 **全局即时模糊搜索浮层** | 海报墙主页 |
