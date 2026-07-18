# 译境 · iOS 翻译 App 原型

这是根据 `翻译 App.pdf` 与 `翻译软件iOS应用设计.zip` 中的高保真原型实现的原生 SwiftUI App。

## 工程

- Xcode 工程：`TranslationPrototype.xcodeproj`
- App 名称：译境
- Bundle ID：`com.codex.translationprototype`
- 最低系统：iOS 17
- 技术：SwiftUI、原生 TabView、Observation、AVFoundation、PhotosUI；iOS 26+ 的系统标签栏自动采用 Liquid Glass。

## 已实现

- 文字翻译：点击原文后，真实原文卡直接以一根 `.spring(duration: 0.45, bounce: 0.12)` 弹簧从静息高度展开到整个视口，软件键盘在下一个 runloop 请求焦点、与展开并行升起；tab bar 隐藏或键盘安全区变化时弹簧带速度重定向，不等待布局稳定，也没有快照覆盖层或结束时的交叉淡化交接。文字、听写和语言调整先保存为草稿；只有点击右上角陶土色圆形对勾“完成并翻译”后才提交并发起真实翻译。结果页继续支持交换语言、朗读、复制、收藏、分享与其他译法。
- 真实翻译：文字页接入谷歌翻译非官方免费接口（`translate.googleapis.com`，`client=gtx`，无需 API Key）。提交后显示加载态，失败展示中文错误与重试按钮；新提交会取消在途请求。源语言支持“自动检测”（`sl=auto`），语言对栏展示检测结果，检测出语言后才可交换；单句译文附带谷歌返回的备选译法（多句时不提供），无备选时隐藏“其他译法”入口。
- 设置：文字页右上角入口打开设置页。翻译模型可切换——谷歌翻译（免费）当前可用，自研模型与 LLM 翻译（自带 API Key）以“即将推出”禁用占位展示；通用偏好含“翻译后自动朗读译文”。翻译引擎、偏好与上次使用的语言对经 UserDefaults 持久化，首次启动保留演示内容，此后按记忆的语言对空白开始。
- 对话翻译：双语气泡、讲话方切换、监听暂停/恢复、模拟新增转写与自动滚动。
- 相机翻译：照片选择、识别加载态、菜单翻译覆盖卡、闪光灯与曝光状态。
- 语言选择：源/目标语言切换、名称/别名/代码搜索、选择状态与空结果状态。
- 历史与收藏：共享翻译记录、收藏过滤、即时星标切换、点选记录回填文字页。
- 文字、语音、相机作为原生 TabView 的三个顶层区域；常态下标签栏持续可见并保留各 tab 状态，仅文字页专注键入时由系统暂时隐藏，提交草稿后恢复。iOS 26+ 由系统呈现 Liquid Glass，iOS 17–25 使用对应系统标签栏外观；selection 实际变化时触发系统触觉反馈。
- 专注键入态不再向 `.keyboard` 工具栏放置“完成”；软件键盘和硬件键盘均使用固定在页面右上角的提交按钮，避免底部操作与系统标签栏重叠。
- 键入转场只有一个状态源：草稿是否存在。原文编辑器全程保持同一身份，展开与收回都是对真实卡片的布局动画（渲染树逐帧插值各视图 frame，卡面 Shape 每帧重算路径保持 22pt 连续圆角不变形），没有几何测量、跨事务验证或阶段编排；转场全程可交互、可打断，展开途中点对勾会带着当前速度平滑反向。结果区通过约 0.16 秒透明度 transition 在纸面下淡出/淡入，位置跟随布局弹簧；对勾延迟约 40ms 后从 0.84 倍轻弹至原尺寸。
- 开启“减弱动态效果”时，布局直接切换到终态（无尺寸、位移、缩放动画），结果区与头部按钮仅保留约 0.12 秒透明度淡化；键盘与 tab bar 继续使用系统行为。

> 这是可交互的产品原型。文字翻译已接入谷歌翻译非官方免费接口（需要能够访问谷歌服务的网络环境）；语音转写与菜单 OCR 仍使用本地演示数据。自研模型与基于 LLM 的翻译引擎为后续计划，暂以占位形式出现在设置页。

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

工程包含 `TranslationPrototypeUITests` UI 测试 Target，验收目标覆盖文字翻译与收藏、语言搜索与选择、语音暂停与新增对话、相机识别结果、原生 TabView 的跨 tab 切换/选中态同步/状态保留、“键入草稿 → 完成并翻译 → 恢复结果页”，以及 DEBUG “减弱动态效果”终态回归，共八条主流程。UI 测试统一携带 `--prototype-canned-translation` 与 `--prototype-reset-settings` 启动参数：前者注入固定演示译文（不访问真实网络），后者复位持久化偏好，保证断言稳定。第八条动画可见性回归不比较脆弱的毫秒级截图，而是由实际 `TextEntryPaperShape.path(in:)` 绘制路径的 DEBUG 探针验证展开和收回均经过起点、至少一个中间值与终点；其余流程只断言稳定终态。可用任意已安装的 iPhone 模拟器运行；例如：

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

### 前景纸层动画可见性修复（历史）

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

### 直接布局动画重构（当前）

上一轮“前景纸层”方案在实测中仍掉帧且有交接瑕疵，根因是覆盖层自身的逐帧成本与冻结几何和真实布局的错位：

- 覆盖层纸面内容挂在 `.frame(height: revealHeight)` 上，`revealHeight` 是动画值，等于每帧对 25pt 正文与底部操作栏做一次完整排版；同一帧内还有两张 `blur(radius: 8)` 阴影板逐帧交叉淡化、`mask` 内的动画 Shape 逐帧重建，多个离屏渲染通道叠加。
- 覆盖层目标高度在键盘出现前冻结，而真实卡片会被键盘安全区压矮；结尾 0.08 秒交叉淡化交接时两边高度不一致，底部操作栏可见跳变。
- 点按后需跨两次主线程事务确认几何稳定才启动动画，键盘再延迟 180ms——“等待 → 纸张 → 键盘 → 交接”四拍串行，转场期间还锁定交互。

当前实现删除全部覆盖层与阶段编排（净删约 900 行），改为对真实卡片的直接布局动画：

- 唯一状态源是草稿是否存在。点击原文在同一个事务里建立草稿，`.spring(duration: 0.45, bounce: 0.12)` 驱动真实卡片高度从静息值一次展开到最终纸面；键盘在下一个 runloop 请求焦点、与展开并行升起。SwiftUI 在渲染树逐帧插值各视图 frame，卡面 `TextEntrySurfaceShape` 每帧重算路径，22pt 连续圆角在缩放中不变形。
- **编辑高度不依赖容器底部安全区。** 对模拟器实录的逐帧分析显示，系统 tab bar 的安全区插入量是异步提交的：隐藏后约 700ms 才释放、恢复时立即插回，且两次都以内容快照交叉淡化的方式落地——任何跟随该安全区的布局都会先停在中间高度、再突跳约 47pt 并出现整卡残影/闪变（旧覆盖层方案同样受害于此）。现在滚动容器 `ignoresSafeArea(.container, edges: .bottom)`，编辑高度由「扩展视口 − 键盘裁切 − 窗口级底部安全区」计算：窗口 inset 不随 tab bar 变化，键盘仍是被尊重的独立安全区域（软件键盘升起时卡片底边平滑跟随键盘顶，弹簧带速度重定向）。tab bar 的迟到提交只再改变一个不可见的滚动边距，展开一步到位、退出无闪变。
- 完成提交以 `.smooth(duration: 0.32)` 收回；结果区以约 0.16 秒透明度 transition 在纸面（`zIndex` 更高）之下淡出/淡入，位置由布局动画自然带动。阴影与描边直接挂在卡面上，不再需要静态双表面交叉淡化。转场全程可点按、可打断（展开途中点对勾会平滑反向收回）。
- 提交触感由复用且预热（`prepare()`）的 `UIImpactFeedbackGenerator` 在动画事务提交后触发，避免冷启动触感引擎在转场首帧阻塞主线程。
- DEBUG 动画探针改由真实卡面 Shape 的 `path(in:)` 逐帧采样底边轨迹，仍要求有效位移、起点/中间值/终点齐备与单调性；`onGeometryChange` 只在布局目标提交时回调、观察不到逐帧插值，故不用于采样。探针完全置于 `#if DEBUG`。
- Reduce Motion 下布局直接切换终态，仅保留约 0.12 秒透明度淡化；草稿、“完成后翻译”、语言选择、听写和系统 tab bar 语义不变。

本轮验收环境为 Xcode 27.0、iPhone 17 Pro / iOS 27.0 Simulator：Debug 通用构建成功、0 errors；完整 UI 套件 8 passed、0 failed、0 skipped，其中动画实际路径专项由真实卡面 Shape 采样的逐帧轨迹通过（起点/中间值/终点齐备、单调）；草稿模型单元测试 2 passed、0 failed。另以 `simctl recordVideo` 对克隆设备实录草稿全流程并逐帧测量卡片底边：进入约 25 个连续中间帧单段直达终态、停稳后无任何后跳，退出约 30 帧连续收回、首帧无整卡闪变。真机 Animation Hitches / Time Profiler、真正硬件键盘、动态字体与 VoiceOver 的最终感知验收仍需设备在线后完成。

最终视觉对照、修正记录与测试证据见 `design-qa.md`。
