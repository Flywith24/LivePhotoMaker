# LivePhotoMaker

LivePhotoMaker 是一个 macOS 小工具，可以把本地视频转换并导入到系统「照片」App，让 Photos 将其识别为 Live Photo。

## 功能

- 批量选择或拖拽导入本地视频文件
- 支持自定义封面图
- 自动生成 Live Photo 所需的配对资源
- 写入 Apple Photos 识别需要的照片和 QuickTime 元数据
- 直接导入到 macOS「照片」App
- 关于本软件
- 检查 GitHub Release 更新
- 支持隐藏命令行转换模式，便于调试

## 系统要求

- macOS 14 或更高版本
- Xcode 或 Command Line Tools
- 第一次导入时需要允许 App 添加内容到「照片」图库

## 本地构建

在项目目录运行：

```bash
./build_app.sh
```

构建完成后，App 会生成在：

```text
.build/LivePhotoMaker.app
.build/dist/LivePhotoMaker.dmg
```

打开 DMG 后，将 `LivePhotoMaker.app` 拖入 `Applications`。首次运行后，选择一个视频，点击 `Create Live Photo`。第一次使用时，macOS 会弹出照片权限请求，请允许添加到照片图库。

## 命令行转换

图形界面会自动导入 Photos。项目也保留了隐藏命令行入口，用于只生成 Live Photo 资源对：

```bash
.build/debug/LivePhotoMaker --convert /path/to/video.mp4 /path/to/output-folder
```

也可以传入自定义封面：

```bash
.build/debug/LivePhotoMaker --convert /path/to/video.mp4 /path/to/output-folder /path/to/cover.png
```

输出目录会得到一组同名的 `JPG` 和 `MOV` 文件。

## GitHub Actions 构建

仓库包含 `.github/workflows/build.yml`。构建可以通过三种方式触发：

- 推送到 `main` 或 `master`
- 创建或更新 Pull Request
- 在 GitHub 仓库页面打开 `Actions`，选择 `Build macOS App`，点击 `Run workflow` 手动触发

构建成功后，Actions 会上传一个 `LivePhotoMaker-app` artifact，里面包含 `LivePhotoMaker.app.zip` 和 `LivePhotoMaker.dmg`。

## GitHub Release

推送 `v*` tag 会自动创建 Release：

```bash
git tag v1.0.0
git push origin v1.0.0
```

Release workflow 会构建并上传 `LivePhotoMaker-v1.0.0-macos.dmg`。用户打开 DMG 后，可以将 App 拖入 Applications 安装。

## Live Photo 原理

Photos 识别 Live Photo 需要一张静态照片和一个配对视频。LivePhotoMaker 会：

- 从视频中提取中间帧作为 JPG
- 给 JPG 写入 Apple Maker metadata 中的 asset identifier
- 将视频重新封装为 MOV
- 给 MOV 写入 `com.apple.quicktime.content.identifier`
- 添加 `com.apple.quicktime.still-image-time` metadata track
- 通过 Photos framework 用 `.photo` 和 `.pairedVideo` 资源类型导入

这样导入后，Photos 才会把两份资源合并识别为一个 Live Photo。
