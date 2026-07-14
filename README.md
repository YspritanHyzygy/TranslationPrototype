# 译境 · iOS 翻译 App 原型

这是根据 `翻译 App.pdf` 与 `翻译软件iOS应用设计.zip` 中的高保真原型实现的原生 SwiftUI App。

## 工程

- Xcode 工程：`TranslationPrototype.xcodeproj`
- App 名称：译境
- Bundle ID：`com.codex.translationprototype`
- 最低系统：iOS 17
- 技术：SwiftUI、原生 TabView、Observation、AVFoundation、PhotosUI；iOS 26+ 的系统标签栏自动采用 Liquid Glass。

## 已实现

- 文字翻译：点击原文后，真实编辑布局一次切换到最终状态；始终挂载在滚动内容前方的纯 SwiftUI 纸层会先跨主线程事务确认标签栏隐藏后的稳定几何，再以约 0.38 秒、`bounce: 0.12` 的克制轻弹从冻结原文卡展开到完整纸面。软件键盘从纸层动画真正开始约 180ms 后跟进，避免 tab bar、键盘安全区与 `TextEditor` 共同参与逐帧重排。文字、听写和语言调整先保存为草稿；只有点击右上角陶土色圆形对勾“完成并翻译”后才提交并生成本地演示译文。结果页继续支持交换语言、朗读、复制、收藏、分享与其他译法。
- 对话翻译：双语气泡、讲话方切换、监听暂停/恢复、模拟新增转写与自动滚动。
- 相机翻译：照片选择、识别加载态、菜单翻译覆盖卡、闪光灯与曝光状态。
- 语言选择：源/目标语言切换、名称/别名/代码搜索、选择状态与空结果状态。
- 历史与收藏：共享翻译记录、收藏过滤、即时星标切换、点选记录回填文字页。
- 文字、语音、相机作为原生 TabView 的三个顶层区域；常态下标签栏持续可见并保留各 tab 状态，仅文字页专注键入时由系统暂时隐藏，提交草稿后恢复。iOS 26+ 由系统呈现 Liquid Glass，iOS 17–25 使用对应系统标签栏外观；selection 实际变化时触发系统触觉反馈。
- 专注键入态不再向 `.keyboard` 工具栏放置“完成”；软件键盘和硬件键盘均使用固定在页面右上角的提交按钮，避免底部操作与系统标签栏重叠。
- 键入转场保持同一个原文编辑器的稳定身份，并以 `idle → entering → editing → exiting` 独立阶段组织视觉状态；草稿、视觉阶段与键盘焦点互不驱动。前景覆盖层重绘冻结的语言、原文、字数和底部操作，自定义 `AnimatableShape` 只改变纸张裁切路径；进入动画只在连续两次、且跨主线程事务的卡片与 viewport 几何相差不足 1pt 后启动，较晚到达的新安全区会作废旧候选。结果区约 0.14 秒淡出并下移 6pt，对勾延迟约 40ms 后从 0.84 倍轻弹至原尺寸；大面积阴影只在两个静态表面之间交叉淡化，不随卡片高度逐帧拉伸。
- 开启“减弱动态效果”时，取消纸层揭示、尺寸、位移和缩放，仅保留约 0.12 秒交叉淡化；键盘与 tab bar 继续使用系统行为。

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

工程包含 `TranslationPrototypeUITests` UI 测试 Target，验收目标覆盖文字翻译与收藏、语言搜索与选择、语音暂停与新增对话、相机识别结果、原生 TabView 的跨 tab 切换/选中态同步/状态保留、“键入草稿 → 完成并翻译 → 恢复结果页”，以及 DEBUG “减弱动态效果”终态回归，共八条主流程。第八条动画可见性回归不比较脆弱的毫秒级截图，而是由实际 `TextEntryPaperShape.path(in:)` 绘制路径的 DEBUG 探针验证展开和收回均经过起点、至少一个中间值与终点；其余流程只断言稳定终态。可用任意已安装的 iPhone 模拟器运行；例如：

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

模拟器可以验证 selection 确实发生变化，但无法验证实体震感；触觉强度与手感需要在真实 iPhone 上最终确认。

上一版“无反弹纸张展开”动效已在 Xcode 27.0（`27A5218g`）、iPhone 17 Pro / iOS 27.0（`24A5380i`）Simulator 完成验收：通用 Simulator 构建通过，完整 UI 套件为 7 passed、0 failed、0 skipped，草稿模型单元测试为 2 passed、0 failed，DEBUG Reduce Motion 定向回归为 1 passed、0 failed。以下结果包与录屏作为修改前基线保留；它们不代表本轮“视觉纸层 / 克制轻弹”性能优化的最终结果。

- 通用 Simulator 构建结果包：`/private/tmp/TranslationPrototype-generic-final-0D94DC89-CC98-4231-B100-2BE25803CC9E.xcresult`
- 完整 UI 结果包：`/private/tmp/TranslationPrototype-ui-final-08ED000D-08F6-4D17-8AC3-2FA9492A760F.xcresult`
- 草稿模型结果包：`/private/tmp/TranslationPrototype-unit-final-44EB6AF3-96C6-4C94-9BFF-141CFEF98978.xcresult`
- Reduce Motion 定向结果包：`/private/tmp/TranslationPrototype-reduce-motion-877986E1-25DE-473F-959D-9C9308A02F4F.xcresult`
- 转场录屏：`tmp/qa/text-entry-motion-soft-keyboard.mov`、`tmp/qa/text-entry-motion-hardware-keyboard.mov`、`tmp/qa/text-entry-motion-reduce-motion.mov`
- 稳定态截图：`tmp/qa/text-entry-motion-soft-keyboard.png`、`tmp/qa/text-entry-motion-hardware-keyboard.png`、`tmp/qa/text-entry-motion-reduce-motion.png`、`tmp/qa/text-entry-motion-result.png`

上一轮“视觉纸层 / 克制轻弹”实现与 Simulator 功能回归已完成。真实编辑卡会在无动画事务中直接进入最终布局，动画只作用于冻结的纸层、遮罩、透明度与缩放；结果区在转场期间位于纸层之后，完成收回后才恢复，避免键盘和 tab bar 改写纸张轨迹。以下结果保留为当前前景覆盖层修复之前的历史性能基线。

- Release Simulator 构建通过：`/private/tmp/TranslationPrototype-release-spring-final2.xcresult`
- 完整 UI 套件 7 passed、0 failed：`/private/tmp/TranslationPrototype-ui-spring-final2.xcresult`（208.211 秒）
- 草稿模型单元测试 2 passed、0 failed：`/private/tmp/TranslationPrototype-unit-spring-final2.xcresult`（0.003 秒）
- DEBUG Reduce Motion 定向回归 1 passed、0 failed：`/private/tmp/TranslationPrototype-reduce-spring-video-final2.xcresult`
- Release 定向流程连续执行 5 次，5 passed、0 failed：`/private/tmp/TranslationPrototype-release-entry-five-spring-final3.xcresult`（365.909 秒；仅为让 Release UI 测试宿主解析测试模块，在命令行临时传入 `ENABLE_TESTABILITY=YES`，未修改工程的 Release 设置）
- 新版转场录屏：`tmp/qa/text-entry-spring-soft-keyboard.mov`、`tmp/qa/text-entry-spring-hardware-keyboard.mov`、`tmp/qa/text-entry-spring-reduce-motion.mov`
- 稳定态截图：`tmp/qa/text-entry-spring-soft-keyboard.png`、`tmp/qa/text-entry-spring-hardware-keyboard.png`、`tmp/qa/text-entry-spring-reduce-motion.png`、`tmp/qa/text-entry-spring-result.png`

上一轮性能签收仍有明确边界：当前 Xcode 27 beta 的标准 Animation Hitches 模板不支持该 Simulator，已安装模板中也没有计划里的 `Core Animation` 或 `Hangs`；命令行 SwiftUI / Time Profiler 采样未能正常结束，因此没有生成可验证的 trace。故“无应用自身 ≥33ms 主线程停顿、无 Long View Body Update”尚不能仅凭录屏宣称通过。另一个名为 hardware 的产物只覆盖了 Simulator 的硬件键盘偏好路径，录屏中软键盘仍然可见，不作为真正硬件键盘验收证据。真实硬件键盘模式、动态字体与 VoiceOver 的本轮人工复核，以及 Release 真机 SwiftUI + Animation Hitches + Time Profiler，均保留到设备在线后完成。

### 前景纸层动画可见性修复（当前）

此前的代码虽然执行了动画，但主弹簧只把纸层推进到较短的中间高度，剩余的大幅展开又由后续布局更新完成；纸层还可能被真实滚动内容遮住，因此肉眼接近瞬切。当前实现改为始终挂载且明确位于 `ScrollView` 前方的覆盖层：

- 点击原文时先冻结原文卡与结果区，再用无动画事务一次性建立草稿并隐藏系统 tab bar。原文卡的测量值包含 generation、验证轮次、卡片 frame 与 viewport；首个候选会跨到下一轮主线程事务复验，连续两次相差不足 1pt 才冻结目标高度并启动动画。若父级 toolbar 的安全区稍后才提交，新测量会替换候选并重新验证；几何完全不变时 generation 与验证轮次也会确定性触发复验，不会静默跳到编辑态或永久停在 entering。
- 几何确认后，已长期存在的 `progress = 0` 直接以 `.spring(duration: 0.38, bounce: 0.12)` 动到完整冻结纸面，不使用 `Task.yield`、10–20ms 首帧猜测，也不在弹簧结束后追加第二次目标高度。
- 覆盖层使用纯 SwiftUI 重绘冻结内容，真实 `TextEditor` 只切换一次布局并保持身份；转场完成后以 0.08 秒交叉淡化交接。长多行文本在覆盖层内裁切，字数与底部操作保持在纸张下缘。
- 完成时先冻结当前草稿外观、收起键盘并提交，纸层以约 0.30 秒无反弹曲线收回；动画完成回调负责阶段交接，结果区延迟约 80ms 恢复。
- DEBUG 动画探针从实际 `AnimatableShape` 裁切后的底边记录展开与收回路径，要求有效位移、至少三个单调位置，以及起点、中间值、终点均存在；Release 构建不包含该探针行为。
- Reduce Motion 仍只保留约 0.12 秒交叉淡化；草稿、“完成后翻译”、语言选择、听写和系统 tab bar 语义不变。

当前验收环境为 Xcode 27.0、iPhone 17 Pro / iOS 27.0 Simulator：Debug 与 Release 通用构建均成功，0 errors、0 warnings；完整 UI 套件 8 passed、0 failed、0 skipped（222.018 秒）；动画实际路径专项 1 passed；草稿模型 2 passed；Release 定向草稿流程连续五轮 5 passed、0 failed（365.522 秒）。结果包依次为 `/private/tmp/TranslationPrototype-paper-overlay-debug-cross-transaction-final-2158.xcresult`、`/private/tmp/TranslationPrototype-paper-overlay-release-cross-transaction-final-2159.xcresult`、`/private/tmp/TranslationPrototype-paper-overlay-ui-cross-transaction-final-2157.xcresult`、`/private/tmp/TranslationPrototype-paper-overlay-motion-cross-transaction-final-2156.xcresult`、`/private/tmp/TranslationPrototype-paper-overlay-unit-cross-transaction-final-2160.xcresult` 与 `/private/tmp/TranslationPrototype-paper-overlay-release-five-cross-transaction-final-2161.xcresult`。测试摘要均无 runtime warnings。Release 重复测试仅在命令行临时传入 `ENABLE_TESTABILITY=YES`，没有修改工程的 Release 设置。

`tmp/qa/text-entry-paper-overlay-visible-current2.mov` 可由 Quick Look 解码，但 `simctl recordVideo` 夹杂黑帧/损坏帧，因此只保留为辅助端点记录，不作为动画时序或流畅度签收；中间帧证据以实际 `TextEntryPaperShape.path(in:)` 探针为准。

真机 Animation Hitches / Time Profiler、真正硬件键盘、动态字体与 VoiceOver 的最终感知验收仍需设备在线后完成；目前不以 Simulator 录屏替代“无应用自身 ≥33ms 主线程停顿”的真机结论。

最终视觉对照、修正记录与测试证据见 `design-qa.md`。
