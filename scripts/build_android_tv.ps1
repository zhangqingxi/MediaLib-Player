# MediaLib-Player Android TV / 盒子版 Leanback APK 一键打包脚本
# 前提：已安装 Flutter SDK 与 Android SDK / NDK
$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  MediaLib-Player Android TV APK 打包构建   " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
Set-Location $ProjectDir

Write-Host "[1/3] 清理与获取依赖..." -ForegroundColor Yellow
flutter clean
flutter pub get

Write-Host "[2/3] 执行 Android TV Release APK 编译 (启用 Leanback & 硬件隧道)..." -ForegroundColor Yellow
flutter build apk --release --target-platform android-arm64,android-arm

$ApkPath = Join-Path $ProjectDir "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $ApkPath) {
    Write-Host "[3/3] 打包成功！TV APK 文件: $ApkPath" -ForegroundColor Green
    Write-Host "  -> 可直接通过 U 盘或 ADB 安装到索尼、小米、TCL 电视及各类外贸外置播放盒" -ForegroundColor Cyan
} else {
    Write-Host "❌ 编译失败，未找到 APK 产物" -ForegroundColor Red
}
