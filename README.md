# 译境 · iOS 翻译 App 原型

这是根据 `翻译 App.pdf` 与 `翻译软件iOS应用设计.zip` 中的高保真原型实现的原生 SwiftUI App。

## 工程

- Xcode 工程：`TranslationPrototype.xcodeproj`
- App 名称：译境
- Bundle ID：`com.codex.translationprototype`
- 最低系统：iOS 17
- 技术：SwiftUI、Observation、AVFoundation、PhotosUI

## 已实现

- 文字翻译：可编辑原文、即时本地演示译文、交换语言、模拟听写、朗读、复制、收藏、分享与其他译法。
- 对话翻译：双语气泡、讲话方切换、监听暂停/恢复、模拟新增转写与自动滚动。
- 相机翻译：照片选择、识别加载态、菜单翻译覆盖卡、闪光灯与曝光状态。
- 语言选择：源/目标语言切换、名称/别名/代码搜索、选择状态与空结果状态。
- 历史与收藏：共享翻译记录、收藏过滤、即时星标切换、点选记录回填文字页。
- 横向滑动可在文字、语音、相机三种模式间切换。

> 这是可交互的产品原型。翻译、语音转写与菜单 OCR 使用本地演示数据，不包含线上翻译服务或生产级模型接入。

## 在 Xcode 中运行

1. 用 Xcode 打开 `TranslationPrototype.xcodeproj`。
2. 选择 `TranslationPrototype` Scheme。
3. 选择任意 iOS 17 或更高版本的 iPhone 模拟器。
4. 点击 Run。

本机当前 Xcode 安装在 `/Applications/Xcode-beta.app`。如果终端的 `xcode-select` 仍指向 Command Line Tools，可用：

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild \
  -project TranslationPrototype.xcodeproj \
  -scheme TranslationPrototype \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/TranslationPrototypeDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 原型素材

- `翻译 App.pdf`：视觉画板。
- `翻译软件iOS应用设计.zip`：HTML/JSX 高保真源稿。
- `tmp/`：本次核对使用的临时渲染与截图，不参与 App 构建。

## 自动化验收

工程包含 `TranslationPrototypeUITests` UI 测试 Target，覆盖文字翻译与收藏、语言搜索与选择、语音暂停与新增对话、相机识别结果四条主流程。可用任意已安装的 iPhone 模拟器运行；例如：

```bash
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild test \
  -project TranslationPrototype.xcodeproj \
  -scheme TranslationPrototype \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /private/tmp/TranslationPrototypeReleaseQA \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:TranslationPrototypeUITests
```

最终视觉对照、修正记录与测试证据见 `design-qa.md`。
