# 译境 iOS 原型 · Design QA

## Historical baseline result

`passed` (previous five-flow baseline)

上一轮最终实现已逐屏对照文件夹内的 HTML/JSX 高保真源稿与 PDF 画板。当时没有遗留的 P0、P1 或 P2 视觉问题；五条核心 XCUITest 流程全部通过，包含原生 TabView 顶层导航、选中态同步与跨 tab 状态保留的回归验证。以下截图与 5/5 结果均作为此历史基线的证据保留。

## Committed input-flow revision (historical pre-motion baseline)

`passed` (six-flow revision)

- 点击原文后进入专注键入态；保留页面标题和语言方向，暂时隐藏译文结果、结果操作、历史/设置入口与系统 tab bar。
- 键入、听写、清空以及编辑态的语言调整只更新草稿，不立即改写已提交原文或译文。
- 右上角陶土色圆形对勾是唯一提交入口；点击“完成并翻译”后一次性提交草稿、生成译文并恢复 tab bar。Return 仍用于多行换行。
- 移除键盘工具栏中的“完成”，软件键盘与硬件键盘共用页面右上角按钮，避免底部按钮与系统 tab bar 重叠。

最终代码的六条 XCUITest 与两条草稿模型单元测试全部通过，且已实测软件键盘与硬件键盘连接态：顶部提交按钮位置一致，专注态无 tab bar，底部无应用级“完成”工具栏；提交后译文卡与 tab bar 均恢复。

## Paper-expansion motion revision (historical baseline)

`passed` (seven-flow motion revision)

- 点击原文后，原文卡保持同一个编辑器身份，在约 0.34 秒内以无反弹的克制曲线原地展开；译文与结果操作在约 0.18 秒内柔和淡出并下移 8pt。
- 展开开始约 80ms 后再让软件键盘跟进，避免键盘安全区、页面布局与系统 tab bar 同帧跳变。
- Header 右侧占位保持稳定：历史/设置淡出，46pt 陶土色对勾由 0.90 倍轻微弹入；标题和语言方向栏不移动。
- 草稿、听写、语言选择和“完成并翻译”语义不变；临时失焦、系统收起键盘或语言选择器返回都不提交，也不重播进入动画。
- tab bar 仍由系统 toolbar visibility 按草稿状态隐藏与恢复，不监听键盘高度，不自定义其形状或平台动画。
- 开启 Reduce Motion 时，取消卡片尺寸、位移和缩放动画，仅保留约 0.12 秒交叉淡化；键盘与 tab bar 继续使用系统行为。

最终代码在 Xcode 27.0、iPhone 17 Pro / iOS 27.0 Simulator 完成通用构建、2/2 草稿模型单元测试、7/7 完整 UI 回归和 1/1 Reduce Motion 定向回归。软件键盘、硬件键盘与 Reduce Motion 三条路径均已录屏并检查；稳定态未发现闪帧、重复卡片、文字跳行、旧译文闪现或底部应用级“完成”工具栏，提交后译文与系统 tab bar 正常恢复。

以上结论与产物作为修改前的“无反弹纸张展开”基线保留，不作为下述“视觉纸层 / 克制轻弹”优化的最终验收结论。

## Foreground paper-overlay visibility revision (historical baseline)

`superseded`（实机观感仍掉帧、交接处有跳变，被下述“直接布局动画”修订取代；以下记录与产物保留为历史证据）

- 根因不是系统 Reduce Motion，而是旧实现的主弹簧只走到较短的中间高度，剩余展开被后续布局更新补齐；同时转场纸层可能位于真实滚动内容之后。代码虽有动画，屏幕观感仍接近瞬切。
- 当前覆盖层始终挂载在 `GeometryReader` 内并明确位于 `ScrollView` 前方。它使用纯 SwiftUI 重绘冻结的语言、原文、字数与底部操作，不复制 `TextEditor`；真实编辑器保持同一身份，只在无动画事务中切换一次最终布局。
- 点击原文后先冻结原文卡与结果区，再以无动画事务建立草稿并隐藏系统 tab bar。原文卡测量同时携带 generation、验证轮次、frame 与 viewport；首个候选跨到下一轮主线程事务复验，连续两次相差不足 1pt 才冻结目标高度。较晚到达的 toolbar safe-area 会替换旧候选并重走验证；几何不变时 generation 与验证轮次也会确定性触发回调，不会永久停在 entering。
- 几何确认后，已长期存在的 `progress = 0` 直接以 `.spring(duration: 0.38, bounce: 0.12)` 动到完整冻结纸面，不依赖 `Task.yield`、10–20ms 首帧等待、真实编辑器动态 mask，或弹簧结束后的第二段目标高度补跳。
- 自定义 `TextEntryPaperShape` 控制 22pt 连续圆角纸层的实际裁切路径；陶土色细边、字数和操作栏跟随纸张下缘。长多行正文位于可裁切的弹性区域，底部操作具有更高布局优先级。
- 结果区 0.14 秒淡出并下移 6pt；Header 使用稳定占位，对勾延迟 40ms 后从 0.84 倍以 0.30 秒、`bounce: 0.22` 轻弹出现。键盘从纸层动画开始约 180ms 后请求焦点。
- 进入完成后通过 0.08 秒交叉淡化把前景快照交回真实卡片。完成编辑时冻结当前草稿外观、收键盘并提交一次翻译；纸层以约 0.30 秒无反弹曲线收回，结果区延迟 80ms 恢复，阶段切换由动画完成回调驱动。
- 阴影使用两张静态表面交叉淡化，不动画模糊半径；系统 tab bar 不继承纸层动画事务。草稿、听写、清空、语言选择与“完成后翻译”语义没有改变。
- Reduce Motion 下不执行纸层揭示、位移或缩放，仅保留 0.12 秒交叉淡化。
- DEBUG 探针直接由 `TextEntryPaperShape.path(in:)` 的实际裁切矩形记录纸张底边；展开和收回均要求有效位移、至少三个单调位置以及起点、中间值、终点。探针状态完全置于 `#if DEBUG`，Release 行为不暴露该入口。

当前验收环境：Xcode 27.0 (`27A5218g`)，iPhone 17 Pro / iOS 27.0 (`24A5380i`) Simulator。

| Artifact | Result |
| --- | --- |
| `/private/tmp/TranslationPrototype-paper-overlay-debug-cross-transaction-final-2158.xcresult` | Debug 通用 Simulator build succeeded；0 errors、0 warnings |
| `/private/tmp/TranslationPrototype-paper-overlay-release-cross-transaction-final-2159.xcresult` | Release 通用 Simulator build succeeded；0 errors、0 warnings |
| `/private/tmp/TranslationPrototype-paper-overlay-ui-cross-transaction-final-2157.xcresult` | 完整 UI 8 passed、0 failed、0 skipped（222.018 秒）；无 runtime warnings |
| `/private/tmp/TranslationPrototype-paper-overlay-motion-cross-transaction-final-2156.xcresult` | 动画实际路径专项 1 passed、0 failed；无 runtime warnings |
| `/private/tmp/TranslationPrototype-paper-overlay-unit-cross-transaction-final-2160.xcresult` | 草稿模型 2 passed、0 failed（0.003 秒）；无 runtime warnings |
| `/private/tmp/TranslationPrototype-paper-overlay-release-five-cross-transaction-final-2161.xcresult` | Release 定向草稿流程连续五轮 5 passed、0 failed（365.522 秒；无 runtime warnings；仅命令行临时 `ENABLE_TESTABILITY=YES`） |
| `tmp/qa/text-entry-paper-overlay-visible-current2.mov` | H.264 QuickTime 可解码，但夹杂 `simctl recordVideo` 黑帧/损坏帧；仅作辅助端点记录，不作精确时序或流畅度证据 |

验收边界保持明确：Simulator 当前无法提供可信的最终 Animation Hitches 签收，因此不从录屏推断“无应用自身 ≥33ms 主线程停顿”。真正硬件键盘、动态字体、VoiceOver、实体触觉，以及 Release 真机 SwiftUI + Animation Hitches + Time Profiler，仍需设备在线后完成。

## Direct layout animation revision (current)

- 实测反馈：纸层方案展开仍掉帧、有动效瑕疵、响应不够灵动。定位到三类根因——覆盖层每帧重排（`.frame(height: 动画值)` 驱动的快照内容排版 + 两张 `blur(radius: 8)` 阴影板逐帧交叉淡化 + 动画 Shape `mask` 的离屏通道）；覆盖层目标高度在键盘出现前冻结，与被键盘压矮的真实卡片在 0.08 秒交接淡化时高度不一致；点按后跨两次主线程事务验证几何、键盘再延迟 180ms，四拍串行且转场锁定交互。
- 本轮删除全部快照覆盖层、几何验证管线与 `idle/entering/editing/exiting` 阶段机（净删约 900 行）。唯一状态源为草稿是否存在：点击原文在同一事务内建立草稿，真实卡片以 `.spring(duration: 0.45, bounce: 0.12)` 从静息高度展开到 `max(260, viewport - 32)`；完成提交以 `.smooth(duration: 0.32)` 收回。原文编辑器全程同一身份，无交接、无双重曝光窗口。
- 键盘在下一个 runloop 请求焦点，与展开并行升起；tab bar 隐藏与键盘安全区提交改变目标高度时，弹簧带速度重定向。转场全程可交互、可打断：展开途中点对勾会带当前速度平滑反向。
- 结果区以约 0.16 秒透明度 transition 在纸面（`zIndex` 更高）之下淡出/淡入，位置由布局动画带动；对勾维持延迟 40ms、0.84 倍、`bounce: 0.22` 轻弹；头部历史/设置按钮 0.15 秒淡化。卡面描边与阴影直接随卡片形变，不再使用静态双表面交叉淡化。
- 22pt 连续圆角由 `TextEntrySurfaceShape` 每帧重算路径保证缩放不变形；DEBUG 动画探针即由该 Shape 的 `path(in:)` 采样真实卡片底边逐帧轨迹（`onGeometryChange` 只在布局目标提交时回调，观察不到渲染树逐帧插值，不用于采样）。评估标准不变：有效位移 ≥24pt、起点/中间值/终点齐备、至少三个单调位置。
- Reduce Motion：布局直接切换终态（无尺寸、位移、缩放动画），结果区与头部按钮保留约 0.12 秒透明度淡化；键盘与 tab bar 继续系统行为。草稿、听写、清空、语言选择与“完成后翻译”语义不变。

当前验收环境：Xcode 27.0，iPhone 17 Pro / iOS 27.0 Simulator。

| Artifact | Result |
| --- | --- |
| Debug 通用 Simulator 构建 | build succeeded；0 errors |
| 动画实际路径专项（`testTextEntryPaperMotionRendersIntermediateFrames`） | 1 passed、0 failed（真实卡面逐帧轨迹：起点/中间/终点齐备、单调） |
| 草稿模型单元测试 | 2 passed、0 failed |
| 完整 UI 套件（8 条主流程） | 8 passed、0 failed、0 skipped（约 230 秒） |

验收边界与上一轮一致：Simulator 不出具 Animation Hitches 结论；真机 Instruments、真正硬件键盘、动态字体、VoiceOver 与实体触觉验收待设备在线后补做。

## Source visual truth

- 原始高保真源稿：`tmp/source-prototype-bsdtar/翻译 App.dc.html`
- 原始视觉画板：`翻译 App.pdf`
- PDF 渲染：`tmp/pdfs/translation-app-1.png`
- 浏览器完整渲染状态：五个核心画面同屏，包含文字、语音、相机、语言选择、历史与收藏。
- 设计基准：纸张 `#F7F4EF`、墨色 `#1C1A17`、陶土色 `#C2603F`；正文使用系统无衬线，译文使用衬线体。

## Implementation captures

- 文字：`tmp/qa/native-tab-text.png`
- 语音：`tmp/qa/native-tab-voice.png`
- 相机：`tmp/qa/native-tab-camera.png`
- 语言选择：`tmp/qa/final2-language.png`
- 历史与收藏：`tmp/qa/final2-history.png`
- 专注键入（软件键盘）：`tmp/qa/text-draft-soft-keyboard.png`
- 专注键入（硬件键盘）：`tmp/qa/text-draft-hardware-keyboard.png`
- 完成并翻译后的结果页：`tmp/qa/text-draft-result.png`
- 克制轻弹专注态（软件键盘）：`tmp/qa/text-entry-spring-soft-keyboard.png`
- 克制轻弹硬件偏好路径：`tmp/qa/text-entry-spring-hardware-keyboard.png`
- 克制轻弹 Reduce Motion：`tmp/qa/text-entry-spring-reduce-motion.png`
- 克制轻弹提交后结果：`tmp/qa/text-entry-spring-result.png`
- 当前前景纸层辅助端点录屏：`tmp/qa/text-entry-paper-overlay-visible-current2.mov`（含 `simctl recordVideo` 损坏帧，不作精确时序证据）

三个主界面截图重新采集自采用原生 TabView 的最终构建；语言与历史截图沿用未受导航重构影响的既有证据。运行环境为 iPhone 17 Pro、iOS 27 Simulator，逻辑视口约为 402 × 874 pt，新截图像素尺寸为 1206 × 2622，状态栏时间固定为 9:41。

## Comparison evidence

### Full-view comparison

- 五个画面的信息架构、颜色关系和内容层级与源稿一致；三个主模式采用系统 TabView，标签栏外形与动效遵循当前 iOS，不再以源稿的自定义底栏作为像素级一致目标。
- 文字页保留大字号衬线译文、浅陶土结果卡与底部四个结果操作。
- 语音页保留三段对话、右侧陶土气泡、底部监听状态与三按钮结构。
- 相机页保留暖暗取景背景、倾斜菜单纸张、三张 OCR 结果卡与相机控制。
- 语言页和历史页的列表边界、分组标题、选择/收藏状态与源稿一致。

### Focused-region comparison

- 文字页标题由早期 28 pt 收敛为源稿 24 pt；源/目标语言胶囊和交换按钮的尺寸、强调色与阴影已对齐。
- 语音页方向修正为 `English ⇄ 中文`；侧边语言按钮改为白底加细陶土选中环，避免偏离源稿的整块强调色。
- 语言列表删除源稿不存在的 Italiano 与 Português，最终以 Deutsch 结尾。
- 全屏背景补齐安全区，修正语音页上下出现黑色露底的问题。
- 顶层导航改为原生 `TabView(selection:)`；系统负责安全区、命中区域、选中语义和平台外观。iOS 26+ 标签栏自动采用 Liquid Glass，iOS 17–25 使用对应系统样式；应用仅在 selection 实际变化时触发 selection 触觉，三个 tab 保留各自本地状态。
- 普通结果态清空会直接清除已提交原文与译文；专注态清空只清草稿并保持输入焦点，不触发翻译。
- 原生 TabView 提供系统 tab bar、tab item 与选中态可访问性语义；UI 测试通过稳定的中文标签定位三个 tab，页面动作继续使用各自标识。

## Historical interaction QA

上一轮基线命令：

```bash
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild test \
  -project TranslationPrototype.xcodeproj \
  -scheme TranslationPrototype \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=A1C19D10-FDA8-44F7-A110-162A6C61B98B' \
  -derivedDataPath /private/tmp/TranslationPrototypeNativeTabFinalQA3 \
  -resultBundlePath /private/tmp/TranslationPrototypeNativeTabFinalQA3.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:TranslationPrototypeUITests
```

- Environment: Xcode 27.0 beta 2, iPhone 17 Pro Simulator, iOS 27.
- Result: 5 passed, 0 failed, 0 skipped.
- Runtime warnings: 0.
- Haptics: selection 变化和触觉触发逻辑已覆盖；模拟器无法产生实体震感，手感需在真实 iPhone 上确认。
- Result bundle: `/private/tmp/TranslationPrototypeNativeTabFinalQA3.xcresult`
- Covered flows:
  - 文字听写 → 译文 → 收藏 → 历史筛选。
  - 语言搜索 → 切换目标语言。
  - 语音监听暂停/恢复 → 新增对话。
  - 相机快门 → 加载 → 三条识别结果。
  - 文字 → 语音 → 相机 → 语音 → 文字，原生标签栏持续存在、选中态同步，语音页本地状态保持。

## Committed input-flow acceptance result (pre-motion baseline)

最终完整回归命令：

```bash
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild test \
  -project TranslationPrototype.xcodeproj \
  -scheme TranslationPrototype \
  -destination 'platform=iOS Simulator,id=A1C19D10-FDA8-44F7-A110-162A6C61B98B' \
  -derivedDataPath /private/tmp/TranslationPrototypeFinalExpandedBuild-019f59b0 \
  -resultBundlePath /private/tmp/TranslationPrototypeFinalExpandedUI6-019f59b0.xcresult \
  -only-testing:TranslationPrototypeUITests
```

- Environment: Xcode 27.0 (`27A5218g`), iPhone 17 Pro Simulator, iOS 27.0 (`24A5380i`).
- Result: 6 passed, 0 failed, 0 skipped.
- Runtime warnings: 0.
- Result bundle: `/private/tmp/TranslationPrototypeFinalExpandedUI6-019f59b0.xcresult`.
- 新增草稿流程覆盖：未修改草稿直接提交 → 再次进入编辑 → 多行 Return → 清空与键入新草稿 → 修改草稿目标语言并关闭选择器 → 不再次点按编辑器即可继续输入 → 双次交换草稿语言并确认文字不变、结果未出现 → 点击“完成并翻译” → 精确验证新译文、已提交语言方向和 tab bar 恢复。
- 听写流程已改为：听写结果只写入草稿，点击“完成并翻译”后才继续验证译文、收藏和历史。
- 草稿模型单元测试 2/2 通过，runtime warnings 为 0，结果包为 `/private/tmp/TranslationPrototypeModelTests-019f59b0.xcresult`；覆盖草稿变更不改写已提交会话，以及空草稿提交清空译文。
- 软件键盘定向回归 1/1 通过，结果包为 `/private/tmp/TranslationPrototypeSoftKeyboardFinal-019f59b0.xcresult`；截图确认编辑卡缩至键盘上方，键盘区域没有应用级“完成”。
- 硬件键盘连接态定向回归 1/1 通过，结果包为 `/private/tmp/TranslationPrototypeDraftScreenshotsLatest-019f59b0.xcresult`；截图确认编辑卡扩展至可用区域，顶部提交按钮位置不变，底部没有“完成”或 tab bar 重叠。
- 辅助功能特大动态字体定向回归 1/1 通过，runtime warnings 为 0，结果包为 `/private/tmp/TranslationPrototypeDynamicType-019f59b0.xcresult`；Simulator 已恢复到原来的 `large`。
- 仍需真机感知类人工检查：触觉手感，以及 VoiceOver 配合实体键盘的完整朗读体验；功能的无障碍名称“完成并翻译”已由 UI 测试定位验证。

## Previous motion acceptance result and artifact checklist

- 完整 UI 套件 7 passed、0 failed、0 skipped：保留原有六条主流程，并增加一条 DEBUG Reduce Motion 终态回归。结果包：`/private/tmp/TranslationPrototype-ui-final-08ED000D-08F6-4D17-8AC3-2FA9492A760F.xcresult`。
- 草稿模型单元测试 2 passed、0 failed；结果包：`/private/tmp/TranslationPrototype-unit-final-44EB6AF3-96C6-4C94-9BFF-141CFEF98978.xcresult`。通用 Simulator 构建结果包：`/private/tmp/TranslationPrototype-generic-final-0D94DC89-CC98-4231-B100-2BE25803CC9E.xcresult`。
- DEBUG Reduce Motion 定向回归 1 passed、0 failed；结果包：`/private/tmp/TranslationPrototype-reduce-motion-877986E1-25DE-473F-959D-9C9308A02F4F.xcresult`。自动化只断言稳定终态，不断言短暂中间帧或精确动画耗时。
- 软件键盘冷启动验收通过：卡片展开后操作区位于键盘上方，无文字跳行、重复卡片、旧译文闪现或底部“完成”工具栏。
- 硬件键盘冷启动验收通过：编辑器填满可用空间且可正常输入，顶部对勾位置与软件键盘模式一致，底部无“完成”或 tab bar 重叠。
- Reduce Motion 验收通过：仅出现短暂交叉淡化，无尺寸、位移或缩放转场，完成提交后译文与 tab bar 恢复。

| Artifact | Acceptance purpose | Status |
| --- | --- | --- |
| `tmp/qa/text-entry-motion-soft-keyboard.mov` | 软件键盘进入与完成退出全程 | 已录制并检查 |
| `tmp/qa/text-entry-motion-hardware-keyboard.mov` | 硬件键盘下的展开、输入与收回 | 已录制并检查 |
| `tmp/qa/text-entry-motion-reduce-motion.mov` | Reduce Motion 交叉淡化退化路径 | 已录制并检查 |
| `tmp/qa/text-entry-motion-soft-keyboard.png` | 软件键盘专注稳定态 | 已截取并检查 |
| `tmp/qa/text-entry-motion-hardware-keyboard.png` | 硬件键盘专注稳定态 | 已截取并检查 |
| `tmp/qa/text-entry-motion-reduce-motion.png` | Reduce Motion 专注稳定态 | 已截取并检查 |
| `tmp/qa/text-entry-motion-result.png` | 完成提交后的译文与 tab bar 恢复 | 已截取并检查 |

以上 7/7、2/2、1/1 结果及 `text-entry-motion-*` 产物属于修改前基线。

## Previous constrained-spring performance acceptance (historical)

当前状态：`Simulator 实现与功能回归通过；真机性能签收待完成`。

- Release Simulator 构建通过。完整 UI 为 7/7，草稿模型单元测试为 2/2，DEBUG Reduce Motion 定向回归为 1/1。
- Release 定向草稿流程连续执行五次均通过：5 passed、0 failed，累计测试时间 365.909 秒。该测试覆盖结果态进入、长多行文字、清空、语言选择器返回、双次交换方向、完成提交与 tab bar 恢复。
- 三条录屏的有效帧已人工复核：冻结纸层未被键盘出现改写为反向轨迹，结果区在退出纸层之后恢复，未见重复卡片、文字基线跳动或旧译文浮在纸层上。`simctl recordVideo` 偶发黑帧/损坏帧属于录制器产物，稳定态截图取自有效 XCUITest 附件或可解码视频帧。
- Xcode 27 beta 的标准 Animation Hitches 模板不支持该 Simulator；`xctrace list templates` 也未列出计划中的 `Core Animation` 与 `Hangs` 模板。命令行 SwiftUI / Time Profiler 采样未正常结束，没有产出可验证 trace。因此主线程 ≥33ms、Long View Body Update 与连续错帧指标尚未签收，不以录屏替代 Instruments 数据。
- Simulator 的硬件键盘偏好测试 1/1 通过，但录屏中软键盘仍可见；该产物仅证明偏好路径未破坏交互，不证明真正的硬件键盘布局。需在 Device Hub 明确启用 `Connect Hardware Keyboard` 后重测。
- 本轮自动化已覆盖软件键盘、Reduce Motion、长多行文字、语言选择器返回和连续进入/退出。动态字体、VoiceOver、真正硬件键盘模式及实体触觉仍需人工复核。
- 真机在线后以 Release 的 SwiftUI + Animation Hitches + Time Profiler 最终签收。真机离线时保留为外部待验证，不凭 Simulator 宣称最终性能通过。

| Artifact | Acceptance purpose | Status |
| --- | --- | --- |
| `/private/tmp/TranslationPrototype-release-spring-final2.xcresult` | Release Simulator 构建 | 通过 |
| `/private/tmp/TranslationPrototype-ui-spring-final2.xcresult` | 完整 UI 回归 | 7 passed、0 failed（208.211 秒） |
| `/private/tmp/TranslationPrototype-unit-spring-final2.xcresult` | 草稿模型测试 | 2 passed、0 failed（0.003 秒） |
| `/private/tmp/TranslationPrototype-reduce-spring-video-final2.xcresult` | Reduce Motion 定向回归 | 1 passed、0 failed |
| `/private/tmp/TranslationPrototype-release-entry-five-spring-final3.xcresult` | Release 定向流程五轮重复 | 5 passed、0 failed（365.909 秒） |
| `tmp/qa/performance/text-entry-spring-swiftui-time-profiler.trace` | SwiftUI 长更新与主线程归因 | 未生成；CLI 采样未正常结束 |
| `tmp/qa/performance/text-entry-spring-core-animation-hangs.trace` | 帧表现与 Hangs 对照 | 未生成；当前模板不可用 |
| `tmp/qa/text-entry-spring-soft-keyboard.mov` | 软件键盘进入、稳定与完成退出 | 已录制并检查 |
| `tmp/qa/text-entry-spring-hardware-keyboard.mov` | Simulator 硬件键盘偏好路径 | 已录制；软键盘仍可见，不作为硬件模式证明 |
| `tmp/qa/text-entry-spring-reduce-motion.mov` | Reduce Motion 交叉淡化退化路径 | 已录制并检查 |
| `tmp/qa/text-entry-spring-soft-keyboard.png` | 软件键盘专注稳定态 | 已截取并检查 |
| `tmp/qa/text-entry-spring-hardware-keyboard.png` | 硬件偏好路径稳定态 | 已截取；不作为硬件模式证明 |
| `tmp/qa/text-entry-spring-reduce-motion.png` | Reduce Motion 专注稳定态 | 已截取并检查 |
| `tmp/qa/text-entry-spring-result.png` | 完成提交后的译文与 tab bar 恢复 | 已截取并检查 |
| `待回填（真机 .trace 路径）` | Release 真机 Animation Hitches + Time Profiler | 待设备在线后采集 |

## Acceptable prototype boundaries

- 文字翻译、语音转写和 OCR 使用本地演示数据；这是交互原型，不是生产翻译引擎。
- `PhotosPicker` 可选择真实照片，但默认相机画面是与源稿一致的模拟菜单场景。
- 原生 TabView 的“文字”tab 使用 SF Symbols 的 `textformat`，在系统中显示为 `Aa`；源稿使用定制 `T` 字形，这是为遵循平台标签栏规范而接受的视觉差异。
