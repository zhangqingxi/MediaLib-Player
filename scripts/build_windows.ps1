# MediaLib-Player Windows 发烧级客户端一键编译打包脚本
# 前提：已安装 Flutter SDK 与 Visual Studio C++ 编译工具链
$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  MediaLib-Player Windows 客户端打包构建    " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
Set-Location $ProjectDir

Write-Host "[1/4] 清理旧产物与获取依赖..." -ForegroundColor Yellow
flutter clean
flutter pub get

Write-Host "[2/4] 执行 Windows Release 编译..." -ForegroundColor Yellow
flutter build windows --release

$ReleaseDir = Join-Path $ProjectDir "build\windows\x64\runner\Release"
if (Test-Path $ReleaseDir) {
    Write-Host "[3/4] 编译成功！产物目录: $ReleaseDir" -ForegroundColor Green
    
    # 自动补充内置 JRE 相对路径目录结构 (免手动配环境变量)
    $JreTargetDir = Join-Path $ReleaseDir "jre"
    if (-not (Test-Path $JreTargetDir)) {
        New-Item -ItemType Directory -Path $JreTargetDir -Force | Out-Null
        Write-Host "  -> 已就绪内置 JRE 挂载点: $JreTargetDir (供 libbluray BD-J 原盘 Java 交互菜单免配环境变量直接加载)" -ForegroundColor Gray
    }

    Write-Host "[4/4] 全部构建步骤完成！可直接运行: $(Join-Path $ReleaseDir 'medialib_player.exe')" -ForegroundColor Cyan
} else {
    Write-Host "❌ 编译失败，未找到 Release 产物目录" -ForegroundColor Red
}
