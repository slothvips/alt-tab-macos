# src/switcher 模块阅读笔记

范围：`src/switcher/`（87 个 .swift，27676 行，含 `main-window/` `state/` `search-discovery/`）。只读分析，行号为 `wc -l` 与读文件时的实际行号（2026-11-18，当前工作区状态）。

## 1. 一句话职责

`src/switcher/` 就是 AltTab 的"切换器"本体：`state/` 维护窗口/应用模型并把它压缩成一次会话的选中状态，`main-window/` 把模型渲染成一块不抢焦点的浮动面板，`search-discovery/` 负责面板内的搜索与首次搜索引导；`SwitcherSession` 是"从按下快捷键到面板消失"这一个生命周期的状态容器。

## 2. 目录与文件地图

| 路径 | 行数 | 一句话 |
|---|---|---|
| `SwitcherSession.swift` | 114 | 一次召唤的全部会话状态（选中、悬停、搜索、预览帧缓存）；静态 `current` 非 nil ⇔ 面板在屏上 |
| `ATShortcut.swift` | 147 | 快捷键匹配与 down/up 触发阶段的适配器，把 keyDown 翻译成动作 id |
| `ShortcutAction.swift` | 79 | 动作 id → 闭包（聚焦/循环/关闭/最小化/全屏/退出/隐藏/搜索/Esc） |
| `KeyRepeatTimer.swift` | 139 | 按住快捷键时的"人工自动重复"（modifier-only 快捷键系统不会重复） |
| `KeyRepeatTimerTestable.swift` | 63 | 自动重复的时间判定纯内核（宽限期、迟到 tick） |
| `Search.swift` | 37 | 应用名/标题匹配入口，结果缓存在 `Window.sw*` 字段 |
| `SearchTestable.swift` | 385 | 分层模糊匹配与打分（大小写、词首、连续命中） |
| `Appearance.swift` | 211 | 由偏好算出的像素参数（内边距、圆角、icon 尺寸、行数） |
| `AppearanceTestable.swift` | 42 | "舒适阅读宽度"启发式，纯函数 |
| `PreviewPanel.swift` | 100 | 选中窗口的大图预览面板（`canBecomeKey = false`） |
| `main-window/TilesPanel.swift` | 254 | NSPanel：`show()`/`orderOut`/尺寸/淡出/键盘交还 |
| `main-window/TilesView.swift` | 899 | 全静态 UI 编排者：tile 池、布局、搜索框、高亮、滚动 |
| `main-window/TileView.swift` | 776 | 单个 tile：缩略图/图标/标题/状态角标/搜索高亮/悬停回调 |
| `main-window/TilePool.swift` | 15 | 池容量规则：只增不减，最少 20 |
| `main-window/TileGridLayout.swift` | 110 | 网格排版算术（换行、总尺寸、行居中、RTL） |
| `main-window/TileOverView.swift` | 168 | 悬停浮层与红绿灯按钮（quit/close/min/max） |
| `main-window/TileUnderLayer.swift` | 46 | 选中/悬停的底层高亮 CALayer |
| `main-window/TileTitleView.swift` | 137 | 单行标题控件（禁隐式动画、禁 intrinsic 计算） |
| `main-window/TileFontIconView.swift` | 277 | SF Symbols 字体图标 + 状态图标枚举 |
| `main-window/StatusIconsView.swift` | 152 | Space 号/隐藏/全屏/最小化角标 |
| `main-window/TilesPanelBackgroundView.swift` | 138 | 毛玻璃（macOS 26 玻璃）背景与 `hostView` 协议 |
| `main-window/DragAndDropResolver.swift` | 54 | 拖放判定纯内核（死区、目标、定时器） |
| `state/Windows.swift` | 977 | 窗口列表 + 过滤/排序/选中/悬停 + 增删窗口 |
| `state/Applications.swift` | 1341 | 应用发现、全量窗口盘点、AX 元素采集、标题/标签刷新、badge |
| `state/Window.swift` | 740 | 单个窗口活对象（AX 元素、缩略图、`tracked` 记录、close/min/fullscreen） |
| `state/Application.swift` | 231 | 单个应用活对象（icon、focusedWindow、windowless 占位） |
| `state/WindowEventReducer.swift` | 1913 | 纯 reducer：一个 `ReducerInput` → 状态演进 + 副作用列表 |
| `state/TrackedWindowState.swift` | 1048 | reducer 的状态/输入/输出定义 + `TabGroupsTable` |
| `state/TrackedWindowStateBridge.swift` | 250 | 活模型 ↔ reducer 的唯一 IO 缝（snapshot/apply/execute） |
| `state/TabGroupResolver.swift` | 1047 | 原生标签组判定纯内核（标题匹配 + 几何推断） |
| `state/TabGroup.swift` | 91 | 标签组唯一写入口，绑定纯表到活模型 |
| `state/SelectionResolver.swift` | 320 | 选中/新来者/移除回退/悬停重锚的纯内核 |
| `state/WindowOrderResolver.swift` | 111 | 排序纯内核 + 一应用一窗口的代表挑选 |
| `state/WindowFilterResolver.swift` | 99 | 单窗口"是否显示"纯内核 |
| `state/WindowAdmissionResolver.swift` | 219 | 物理表面是否算"可切换目标"的准入内核 |
| `state/PhantomWindowDetector.swift` | 79 | 幽灵窗口判定（ordered-out / alpha 0） |
| `state/FocusIntentPolicy.swift` | 277 | 聚焦请求代际、结果校验、迟到答案 |
| `state/WindowThumbnails.swift` | 197 | 抓图调度（缩略图/全分辨率预览）与几何校验 |
| `state/TabReadPolicy.swift` | 104 | 何时值得重读某窗口的标签 |
| `state/Spaces.swift` | 96 | Space 拓扑 + 每窗口 Space 的快照/应用 |
| `state/Screens.swift` | 121 | 屏幕表与 preferred 屏幕 |
| `state/SearchModeResolver.swift` | 124 | 搜索模式状态机（开启/关闭/按键路由） |
| `state/SearchFieldEditing.swift` | 27 | 搜索框光标归属规则 |
| `state/ShortcutModifierResolver.swift` | 48 | 修饰键匹配的纯内核（含搜索编辑时的门控） |
| `state/ExceptionMatcher.swift` | 66 | 例外名单/全屏禁用快捷键的判定 |
| `state/WindowTitle.swift` | 54 | 把多行标题压成单行 |
| `state/ApplicationDiscriminator.swift` | 82 | 某 pid 是否算"真正的应用" |
| `state/ApplicationState.swift` | 89 | 应用纯值记录 + pid 解析 |
| `state/WindowState.swift` | 49 | 窗口纯值记录（各内核共用） |
| `state/BruteForceWindowMatch.swift` | 66 | 暴力 AX 扫描中"是否根窗口元素" |
| `search-discovery/SearchDiscoveryPolicy.swift` | 141 | 首次搜索引导的资格/次数/冷却/历史 |
| `search-discovery/SearchDiscoveryHint.swift` | 340 | 提示的单例生命周期与锚定 |
| `search-discovery/SearchDiscoveryPanel.swift` | 396 | 气泡面板本体（兔子 + 文案 + 关闭） |
| `search-discovery/SearchDiscoveryShortcut.swift` | 20 | 快捷键的人类可读文案 |
| `state/TestInteractionModel.swift` + `TestReducerRunner` + `TestScenarioSimulator` + `TestScenarioGenerator` | 1711 | 场景模拟/日志回放测试骨架（不参与 App） |
| `*Testable.swift`（3 个） | 490 | 与测试目标共享的纯逻辑 |
| `*Tests.swift`（29 个） | 10859 | XCTest（占本目录 39%） |
| `*Specs.md`（30 个） | — | 与实现/测试成三件套的规格 |

## 3. 核心类型与关系

```
KeyboardEvents ─┐                                   ┌─ WindowServerEvents
TrackpadEvents ─┼─ ShortcutActions.execute(id)      ├─ AttentionEngine
CursorEvents  ─┘        │                           └─ Applications(采集结果)
                        ▼                                        │ ReducerInput
              App.showUiOrCycleSelection                          ▼
                        │                          TrackedWindowStateBridge
                        ▼                            (snapshot→reduce→apply)
                SwitcherSession.current  ◄──────┐               │
                        │                       │               ▼
                        ▼                       │      WindowEventReducer (pure)
              Windows.list: [Window] ───────────┘               │ effects
                   │        │                                   ▼
     TabGroups.table      Application              WindowServerEvents.subscribe
                   │        │                       / AX 读 / 抓图 / 移除窗口
                   ▼        ▼
            TilesView（全静态）──► TilePool: [TileView] ──► TilesPanel(NSPanel)
                   │                        │
                   └── WindowThumbnails ────┴──► Window.thumbnail / PreviewPanel
```

持有关系：
- 全部是"静态单例 + 全局可变表"风格：`Applications.list`、`Windows.list`/`byWindowId`、`TabGroups.table`、`Spaces.*`、`TilesView.*`、`TilesPanel.shared`、`SwitcherSession.current`。
- `Window` 持有 `Application`、`tracked: TrackedWindow`、`thumbnail`、`axUiElement`；`Application` 反向持有 `focusedWindow: Window?`（`state/Application.swift:31`）。
- `Window.isTabbed` / `tabbedSiblingWids` 是从 `TabGroups` 派生的只读计算属性，不是存储（`state/Window.swift:56-61`）。
- `TilesView.recycledViews[i]` 与 `Windows.list[i]` 严格同下标（见 §7 第 1 条）。

## 4. 端到端数据流（按下快捷键 → 缩略图出现在屏幕上）

1. **按键匹配**：`src/events/KeyboardEventsTestable.swift:97-98` 遍历所有 `ATShortcut`，`ATShortcut.matches` 判修饰键与阶段（`ATShortcut.swift:21-41`），`shouldTrigger` 判 scope/会话（`ATShortcut.swift:62-79`），然后 `executeAction`（`ATShortcut.swift:81-85`）。
2. **动作分发**：`ShortcutActions.execute(id)`（`ShortcutAction.swift:57-78`）：index≥1 的 Pro 门控；`nextWindowShortcut*` 走 `App.showUiOrCycleSelection(index, false)`。
3. **建立会话**：`App.showUiOrCycleSelection`（`src/App.swift:375-440`）复用或新建 `SwitcherSession`，把 `windowIdsAtSummon` 定格（`:383`）；首次召唤或换快捷键时：面板 `alphaValue = 0`（`:406`）、`TilesView.startSearchSession`、`Windows.updatesBeforeShowing()`（`:413`）、`Windows.setInitialSelectedAndHoveredWindowIndex()`（`:414`）。
4. **算列表**：`Windows.updatesBeforeShowing`（`state/Windows.swift:94-127`）快照偏好 → 逐窗口 `shouldShowTheUser`（`:164-189`，走 `WindowFilterResolver`）→ `refreshWhichWindowsToShowTheUser` 落实"一应用一窗口"（`:129-151`）→ `sort()`（`:538-561`，走 `WindowOrderResolver`）。
5. **定初选**：`setInitialSelectedAndHoveredWindowIndex`（`state/Windows.swift:239-248`）→ `SelectionResolver.initialPickIndex`；`updateSelectedAndHoveredWindowIndex`（`:382-429`）写入 `selectedIndex`/`selectedTarget`，并触发高亮与预览抓取。
6. **组 UI 并显示**：`App.buildUiAndShowPanel`（`src/App.swift:442-475`）：`Appearance.update` → `TilesView.swapBackgroundViewIfNeeded` → `refreshUi()` → `TilesPanel.show()`（`main-window/TilesPanel.swift:156-176`：alpha 1、`makeKeyAndOrderFront`、记 `panelShownAt`）→ 预览帧 → 启动自动重复 → `WindowThumbnails.refreshAsync(list, ...)` 异步抓图。
7. **渲染一轮**：`App.refreshUi`（`src/App.swift:359-373`）：`Windows.updateSelectedWindow` → `TilesPanel.updateContents`（`TilesPanel.swift:50-62`，包在 `caTransaction` 里）→ `TilesView.updateItemsAndLayout`。
8. **排版**：`TilesView.updateItemsAndLayout`（`main-window/TilesView.swift:453-479`）→ `fillTiles`（`:515-536`，按 `Windows.list` 下标把窗口塞进 `recycledViews`，被过滤的 tile `frame = .zero`）→ `TileGridLayout.compute`（`main-window/TileGridLayout.swift:39`）→ `layoutTileViews` 写 frame、建 `rows`、换 `documentView.subviews`（`:544-570`）→ `centerRows` → `highlightStartView`。
9. **填内容**：`TileView.updateRecycledCellWithNewContent`（`main-window/TileView.swift:81-89`）→ `updateValues`（`:310-359`）：有 `window.thumbnail` 就画截图，否则退回 app 图标/占位。
10. **截图回填**：`WindowThumbnails.refreshAsync`（`state/WindowThumbnails.swift:153-179`）把任务丢到后台队列，macOS 26+ 走 ScreenCaptureKit、更早走 `CGSHWCaptureWindowList`；结果回到 `Window.refreshThumbnail`（`state/Window.swift:245-269`），校验后写 `thumbnail` 并直接刷新已挂载的 `TileView`/`PreviewPanel`——这就是"缩略图晚一拍出现"的来源。
11. **会话内的变化**：外部事件 → `WindowServerEvents.route` → `TrackedWindowStateBridge.dispatch(ReducerInput)`（`state/TrackedWindowStateBridge.swift:25-43`）→ reducer 改模型/发副作用 → `App.refreshOpenUiAfterExternalEvent`（`src/App.swift:341-351`）经 `switcherUiRepaintCoalescer` 回到第 7 步。
12. **收尾**：松手时 `.focusOnRelease` 由 `ATShortcut.shouldTrigger` 放行 → `App.focusTarget` → `focusSelectedWindow` → `beginHideUi`（`src/App.swift:74-94`）：先 `SwitcherSession.current = nil`，再 `window.focus(...)` 交还键盘，最后 `finishHideUi` 清搜索与会话。

## 5. 对外边界

依赖（本目录 import 或用到的外部模块）：
- `src/events/`：`KeyboardEvents`（驱动 `ATShortcut`）、`WindowServerEvents`（把 WS 通知变成 `ReducerInput`，并 `subscribe` wid）、`TrackpadEvents`/`CursorEvents`/`ContextMenuEvents`/`DismissalInput`。
- `src/window-tracking/`：`AttentionEngine`（当前用户上下文、焦点归属）、`AxObserverRegistry`、`AXCallScheduler`。
- `src/windowserver/`：`WindowServerQuery`、`WindowSurfaceInventory`、`WsRawWindow`/`WsWindowState`。
- `src/api/`：AX、CGWindow、SkyLight/CGS 封装；`src/util/`：`Throttler`、`CGSCallScheduler`、`BackgroundWork`、`MainThreadStall`、`RepaintCoalescer`。
- `src/preferences/`、`src/pro/`（`ProFeature`、`ProTransitionManager`）、`src/debug/`（QA/CLI）。

被谁调用：
- `src/App.swift` 是唯一编排者（show/hide/refresh/focus 全在这里）。
- `src/events/CliEvents.swift`、`src/debug/Qa*` 直接读 `Windows.list` 做断言与快照。
- 偏好设置 UI（如 `ExceptionsTab.swift:191`）与 Pro 提示读 `Windows.list`/`Applications.list`。
- 单元测试目标：`*Tests.swift` 直接调用各纯内核，绕过 AppKit。

## 6. 推荐阅读顺序

**第 1 档 — 会话与编排（约 900 行）**：`SwitcherSession.swift` + `src/App.swift:280-475`（show/refresh/hide）+ `ShortcutAction.swift`。
读完能回答：一次召唤由谁创建、状态放哪、为什么隐藏时要先置 nil。

**第 2 档 — 列表与选中（约 1400 行）**：`state/Windows.swift` + `SelectionResolver.swift` + `WindowOrderResolver.swift` + `WindowFilterResolver.swift`。
读完能回答：为什么列表是这个顺序、初选为何跳过第一个、用户选过之后为何锁 id。

**第 3 档 — 模型到像素（约 2100 行）**：`main-window/TilesPanel.swift` + `TilesView.swift` + `TileView.swift` + `TileGridLayout.swift` + `TilePool.swift`。
读完能回答：tile 池与列表下标的对应、搜索框为何冻结面板位置、缩略图为什么先空后满。

**第 4 档 — 事件如何进模型（约 4200 行）**：`WindowEventReducer.swift`（先读入口和分支表）+ `TrackedWindowState.swift` + `TrackedWindowStateBridge.swift` + `TabGroup.swift` + `TabGroupResolver.swift`。
读完能回答：一个 WS 通知怎么变成模型变更、标签组由谁说了算、reducer 与活模型如何保持一致。

**第 5 档 — 发现与图像（约 2500 行）**：`state/Applications.swift` + `Window.swift` + `Application.swift` + `WindowAdmissionResolver.swift` + `PhantomWindowDetector.swift` + `WindowThumbnails.swift`。
读完能回答：窗口是怎么被发现的、什么表面被拒、什么算幽灵、什么时候抓图。

## 7. 关键不变量与坑

1. **`recycledViews[i]` 与 `Windows.list[i]` 同下标，`selectedIndex` 是列表下标而非"第几个可见 tile"**。`TilesView.fillTiles` 用同一个 `index` 取 `Windows.list[index]`（`main-window/TilesView.swift:517-533`），被过滤的窗口只把 tile 的 frame 置零（`:528-531`）而不重排池子。所以任何"按可见序号"的假设都会错位。
2. **`SwitcherSession.current` 是"面板可见"的唯一真相**。创建在 `App.swift:379-387`，销毁在 `beginHideUi` 的第一行之后（`src/App.swift:79`）；全代码库用它判"切换器是否在屏"。`isActive` 只是它的派生（`SwitcherSession.swift:11`）。
3. **选中是"下标 + 目标 id"双写，并且区分用户选择与默认落点**。`selectedIndex` 会因列表重排而指向别的窗口，所以同时记 `selectedTarget`；只有 `userPickedSelection` 为真才把 id 当承诺（`SwitcherSession.swift:37-55`，写入点 `Windows.swift:388/411-412`）。这是 #5665 那类"选中漂移"的修法。
4. **"新来者"由召唤时刻的快照派生，不是由焦点变化派生**。`windowIdsAtSummon`（`App.swift:383`）→ `SelectionWindow.appearedAfterSummon`（`Windows.swift:320-331`）。原因写在 `SelectionResolver.swift:11-24`：标签组中途换代表是焦点变化但没有新窗口，按焦点判会让选中一路滑走。
5. **`Window.tracked` 是跨桥的单值，`state` 级字段必须手工进 `Carried`**。`Window.swift:19/94-97` 与 `TrackedWindowStateBridge.swift:100-136`；新增 per-window 字段自动双向（编译器保证），但 `TrackedWindowState` 上的新字段若忘了 snapshot，会"每次都从空开始"，而单测传的是一个贯穿的状态所以测不出来——`TrackedWindowStateBridge.swift:88-96` 明写了这条教训。
6. **标签组成员资格只有一个写入口，`isTabbed` 是派生的**。`state/TabGroup.swift:11-22`（组 ≥2 成员、至多一个代表、一 wid 至多一组），读取侧 `Window.swift:56-61` 是 get-only。历史上"存 per-window 标志"让矛盾状态可表示，这是刻意的结构选择。
7. **主线程不做阻塞 CGS 调用**。`Window.init` 把 `spaceIds` 默认成当前 Space（`state/Window.swift:109-113`），真实 Space 由 `addDiscoveredWindow` 在后台查好再落地（`state/Applications.swift:386-395`）。改动初始化路径时别把 `CGSCopySpacesForWindows` 塞回 main。
8. **`shouldShowTheUser` 是缓存值，只在 `updatesBeforeShowing` 里重算**（`state/Windows.swift:121-123`）。别处读到的是上一轮过滤结果；想在别处判断"现在该不该显示"，用 `shouldDisplay`（`:52-54`，含搜索）。
9. **AppKit 里改 first responder / 输入法上下文的调用必须延后一轮 runloop**。`TilesView.takeTheCaretFromTheField`（`main-window/TilesView.swift:63-79`）与 `giveTheFieldTheCaret`（`:118-128`）都是 `DispatchQueue.main.async`，因为激活/停用系统输入法上下文是同步 XPC，实测可到 3s（#5981）；放在首帧前会顶住 CoreAnimation 提交。
10. **抓图分两档：缩略尺寸给所有 tile，全分辨率只给选中窗口 ±2**。`WindowThumbnails.capturePixelSize`（`state/WindowThumbnails.swift:44-54`）、`fetchPreviewFrames`（`:186-196`）、缓存上限 10 张 LRU（`SwitcherSession.swift:92-113`）。给所有窗口抓全分辨率会拖垮系统截图通道（#5861）。
11. **自动重复的宽限期从"面板真正可见"起算**（`main-window/TilesPanel.swift:169-171` 记 `panelShownAt`，判定在 `KeyRepeatTimerTestable`），不是从按键按下起算；否则一次慢 show 会先把宽限期吃掉，用户还没看到面板选中就开始跑。
12. **`removeWindows` 故意不 `unsubscribe` WindowServerEvents**（`state/Windows.swift:873-875`）：离开模型不等于 wid 消失，重新出现只靠这条订阅宣告。清理逻辑勿"顺手补上"。

## 8. 不确定 / 没读到的部分

- `state/WindowEventReducer.swift`（1913 行）只读了入口、`ReducerInput` 分支表和若干大段注释，**没有逐条验证每个分支的行为**；本文对它的描述以注释与调用点为准。
- `state/Applications.swift` 第 470-1341 行（AX 元素结束对账、inactive tab 暴力发现、badge 刷新）只读了函数签名与少量上下文，未读实现细节。
- `state/TabGroupResolver.swift` 的两条 claim 路径（标题匹配 vs 几何推断）只读了头部说明与函数列表，**未读判别细节**，因此笔记没有断言具体判定顺序。
- 未运行构建或测试（任务要求只读）；行数来自 `wc -l`，与磁盘当前状态一致。
- `src/debug/`、`src/events/CliEvents.swift` 对本模块的用法只确认了引用点，未读全文。
- `SearchTestable.swift` 的模糊匹配算法只读了入口签名，未读评分细节；`Search.swift:33` 的 `appScore * 1.02` 是"应用名略优先"的实证，但未验证该系数来历。
