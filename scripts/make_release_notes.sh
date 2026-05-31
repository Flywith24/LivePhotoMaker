#!/usr/bin/env bash
set -euo pipefail

version="${1:-${GITHUB_REF_NAME:-}}"
output="${2:-release_notes.md}"

if [[ -z "$version" ]]; then
  echo "Usage: $0 <version> [output]" >&2
  exit 1
fi

cat > "$output" <<EOF
# LivePhotoMaker ${version}

macOS App，用于将本地视频转换并导入「照片」App，让系统识别为 Live Photo。

EOF

case "$version" in
  v1.2.1)
    cat >> "$output" <<'EOF'
## 主要变化

- 修复 GitHub Actions 在旧 macOS SDK 上构建失败的问题。
- 支持 HEIC 封面输出，更接近 iPhone Live Photo 的资源结构。
- 支持 JPG、PNG、HEIC 等图片作为自定义封面输入。
- 支持每个视频独立设置封面，批量导入时不会互相覆盖。
- 支持从视频中选择一帧作为封面，并使用更兼容的 JPEG 临时封面避免预览偏色。
- 改进 MOV 输入兼容性，保留音视频轨道 metadata 和辅助图像轨道，同时避免 AVFoundation 崩溃路径。
- 增强 HDR/HEIC 路径：在系统支持时请求 ISO HDR 编码、gain map 生成或保留。
- 修复封面缩略图溢出容器的问题。

## 安装

下载 `LivePhotoMaker-v1.2.1-macos.dmg`，打开后将 `LivePhotoMaker.app` 拖入 Applications。
EOF
    ;;
  v1.1.0)
    cat >> "$output" <<'EOF'
## 主要变化

- 支持批量导入多个视频。
- 支持为视频设置自定义封面。
- 支持从视频中选择封面帧。
- 改进主界面视觉设计。
- 新增关于本软件与检查更新入口。
- 改进可拖拽安装的 DMG 页面和 App 图标。

## 安装

下载 `LivePhotoMaker-v1.1.0-macos.dmg`，打开后将 `LivePhotoMaker.app` 拖入 Applications。
EOF
    ;;
  v1.0.1)
    cat >> "$output" <<'EOF'
## 主要变化

- 新增 App 图标。
- 新增可拖拽安装的 DMG 包。
- 新增 GitHub Actions release workflow，用 tag 自动构建并上传 DMG。

## 安装

下载 `LivePhotoMaker-v1.0.1-macos.dmg`，打开后将 `LivePhotoMaker.app` 拖入 Applications。
EOF
    ;;
  v1.0.0)
    cat >> "$output" <<'EOF'
## 主要变化

- 初始版本。
- 支持选择本地视频并生成 Live Photo 配对资源。
- 支持导入到 macOS「照片」App，让系统识别为 Live Photo。

## 安装

下载 `LivePhotoMaker-v1.0.0-macos.zip`，解压后运行 App。
EOF
    ;;
  *)
    cat >> "$output" <<EOF
## 主要变化

- 请查看本次 tag 对应的 commit 记录获取详细变化。

## 安装

下载 \`LivePhotoMaker-${version}-macos.dmg\`，打开后将 \`LivePhotoMaker.app\` 拖入 Applications。
EOF
    ;;
esac
