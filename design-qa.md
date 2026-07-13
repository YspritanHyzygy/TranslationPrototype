# 译境 iOS 原型 · Design QA

## Result

`passed`

最终实现已逐屏对照文件夹内的 HTML/JSX 高保真源稿与 PDF 画板。没有遗留的 P0、P1 或 P2 视觉问题；四条核心 XCUITest 流程全部通过，最终测试结果无运行时警告。

## Source visual truth

- 原始高保真源稿：`tmp/source-prototype-bsdtar/翻译 App.dc.html`
- 原始视觉画板：`翻译 App.pdf`
- PDF 渲染：`tmp/pdfs/translation-app-1.png`
- 浏览器完整渲染状态：五个核心画面同屏，包含文字、语音、相机、语言选择、历史与收藏。
- 设计基准：纸张 `#F7F4EF`、墨色 `#1C1A17`、陶土色 `#C2603F`；正文使用系统无衬线，译文使用衬线体。

## Implementation captures

- 文字：`tmp/qa/final2-text.png`
- 语音：`tmp/qa/final2-voice.png`
- 相机：`tmp/qa/final2-camera.png`
- 语言选择：`tmp/qa/final2-language.png`
- 历史与收藏：`tmp/qa/final2-history.png`

截图来自 iPhone 17 Pro、iOS 27 Simulator，逻辑视口约为 402 × 874 pt，像素截图为 944 × 2048。状态栏时间固定为 9:41，便于与源稿对照。

## Comparison evidence

### Full-view comparison

- 五个画面的信息架构、颜色关系、卡片层级、圆角语言控件、底部模式切换器、相机取景器与两张选择面板均与源稿一致。
- 文字页保留大字号衬线译文、浅陶土结果卡与底部四个结果操作。
- 语音页保留三段对话、右侧陶土气泡、底部监听状态与三按钮结构。
- 相机页保留暖暗取景背景、倾斜菜单纸张、三张 OCR 结果卡与相机控制。
- 语言页和历史页的列表边界、分组标题、选择/收藏状态与源稿一致。

### Focused-region comparison

- 文字页标题由早期 28 pt 收敛为源稿 24 pt；源/目标语言胶囊和交换按钮的尺寸、强调色与阴影已对齐。
- 语音页方向修正为 `English ⇄ 中文`；侧边语言按钮改为白底加细陶土选中环，避免偏离源稿的整块强调色。
- 语言列表删除源稿不存在的 Italiano 与 Português，最终以 Deutsch 结尾。
- 全屏背景补齐安全区，修正语音页上下出现黑色露底的问题。
- 清空文字时不再强制设置输入焦点，消除了测试期间的 invalid frame 运行时警告。
- 父级可访问性标识已拆分，避免覆盖子控件的可访问性名称，并让自动化测试可以稳定命中每个动作。

## Interaction QA

最终命令：

```bash
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild test \
  -project TranslationPrototype.xcodeproj \
  -scheme TranslationPrototype \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=A1C19D10-FDA8-44F7-A110-162A6C61B98B' \
  -derivedDataPath /private/tmp/TranslationPrototypeReleaseQA \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:TranslationPrototypeUITests
```

- Environment: Xcode 27.0 beta 2, iPhone 17 Pro Simulator, iOS 27.
- Result: 4 passed, 0 failed, 0 skipped.
- Runtime warnings: 0.
- Result bundle: `/private/tmp/TranslationPrototypeReleaseQA/Logs/Test/Test-TranslationPrototype-2026.07.12_15-24-23--0400.xcresult`
- Covered flows:
  - 文字听写 → 译文 → 收藏 → 历史筛选。
  - 语言搜索 → 切换目标语言。
  - 语音监听暂停/恢复 → 新增对话。
  - 相机快门 → 加载 → 三条识别结果。

## Acceptable prototype boundaries

- 文字翻译、语音转写和 OCR 使用本地演示数据；这是交互原型，不是生产翻译引擎。
- `PhotosPicker` 可选择真实照片，但默认相机画面是与源稿一致的模拟菜单场景。
- SwiftUI 使用 SF Symbols 的 `textformat`，在系统中显示为 `Aa`；源稿底部使用定制 `T` 字形，这是可接受的原生图标替代，不影响交互或布局。
