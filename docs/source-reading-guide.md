# AltTab 源码阅读指南

> 面向"第一次打开这个仓库"的读者。读完本文你应该能：知道每个目录为什么存在、跟着一条真实数据流走完全程、并且能定位"改某个功能要动哪些文件"。
>
> 规模（本次实测）：`src/` 306 个 `.swift`，68,387 行；74 份 `*Specs.md`，72 个 `*Tests.swift`，8 个 `*Testable.swift`。
>
> 更细的模块级笔记在 `docs/source-reading-notes/`（四份，共约 690 行），本文每节都会指向对应章节。

---

## 1. 这是什么

AltTab 给 macOS 补上 Windows 风格的「窗口切换器」：按住 `⌥` 弹出一块**不抢焦点**的浮动面板，列出所有应用的所有窗口（带实时缩略图），用 `Tab`/方向键移动选中，松手聚焦。

它不是"再写一个 ⌘Tab"：系统的 ⌘Tab 按**应用**切，AltTab 按**窗口**切，还要保证选中窗口的缩略图是真的、Space 是对的、Mission Control 开着时不添乱、以及焦点确实落到那个窗口上。

三件事决定了这个项目的骨架：

1. **窗口信息全在别的进程里**。要枚举窗口得问 SkyLight（WindowServer 私有 API），要读标题/焦点得问 Accessibility，问一次就是一次跨进程往返。于是有了一整套调度器、缓存、纯策略（`src/macos/`、`src/util/`）。
2. **面板必须比系统切换器更快**。按下到出图是几十毫秒的预算，主线程上任何阻塞调用都会直接变成"卡"。于是有了 `main-thread-ipc.md` 那套规矩和"纯内核 + 笨外壳"的分层。
3. **窗口状态是持续变化的**。应用切前台、窗口被关、标签组换页、Space 切换——面板开着的时候这些都在发生。于是有了 reducer（`WindowEventReducer`）和注意力模型（`AttentionEngine`）。

---

## 2. 五分钟上手

```bash
ls config/local.xcconfig   # gitignored；新 worktree 要从主 checkout 拷一份，缺了会在 CodeSign 阶段失败
bash ai/build.sh                                          # 构建（含插画资源校验）
bash ai/test.sh                                           # 单测（Debug 配置，1.3s 级增量）
bash ai/run.sh                                            # 跑起来并流式看日志
```

- 三个 scheme：`Debug`（开发）、`Test`（单测）、`Release`（CI 用）。
- 不要用 `scripts/run_tests.sh` 做日常回归：它是 CI 入口，Release 配置每次改动都要全量重编 131 个测试文件（34s vs 1.3s）。
- 日志：`--logs=debug`，或菜单栏 → Debug tools 打开实时日志窗口。
- 设置里有一堆 QA 用 CLI 开关（`src/debug/QaLifecycle.swift`），跑 UI 回归时用得上。

阅读顺序上，**先构建跑通再读代码**。这个项目大量注释在解释"为什么不能换一种写法"，没有运行环境时读起来像危言耸听。

---

## 3. 全局架构：三层 + 一条主线

```
┌──────────────────────────────────────────────────────────────────┐
│ 入口层  src/main.swift  src/App.swift  src/Menubar.swift  MainMenu│
│         （进程信号/崩溃兜底 → NSApplication → 菜单栏 → 主菜单）      │
└───────────────┬──────────────────────────────────────────────────┘
                │ 只在这里"装配"：observe 事件、建窗口、串流程
┌───────────────▼──────────────────────────────────────────────────┐
│ 业务层  switcher(27.7k)  preferences(10.8k)  pro(6.1k)            │
│         events(4.4k)     window-tracking(4.0k)                   │
│         windowserver(0.9k)  secondary-windows(2.6k)  api(31)      │
└───────────────┬──────────────────────────────────────────────────┘
                │ 只调"能力"，不直接碰系统 API
┌───────────────▼──────────────────────────────────────────────────┐
│ 基础层  kit(3.1k 控件)   macos(3.2k 系统封装)   util(2.0k 并发工具) │
│         debug(1.8k，几乎全在 #if DEBUG 内)                        │
└───────────────┬──────────────────────────────────────────────────┘
                ▼
        macOS 公开 / 私有 API
```

依赖方向严格向下。两个例外值得记住：

- `events/` 反向调用 `preferences/settings-window/ControlsTab.shortcuts`（快捷键注册表住在设置里），文件内有注释说明这是历史遗留的耦合。
- `debug/` 被生产代码少量引用（`MainThreadStall`、`QaLifecycle`），其余全是 DEBUG 专用。

### 3.1 三条主线

| 主线 | 一句话 | 去哪读 |
|---|---|---|
| 按键 → 面板 → 聚焦 | 热键/tap → `ATShortcut` → `App.showUiOrCycleSelection` → `Windows.updatesBeforeShowing` → `TilesView` 排版 → 缩略图异步回填 → 松手 `focusTarget` | notes/switcher.md §4（12 步，带行号） |
| 系统窗口变化 → 模型 | SkyLight 通知 + AX 通知 → reducer → `Windows.list` 顺序 | notes/platform.md §4a |
| 改一个偏好 → 生效 | 控件 → `Preferences.write` → `PreferencesEvents` → 各子系统 | notes/preferences-events.md §4a |

三条线在 `App.swift` 汇合。**`App.swift`（724 行）是全项目唯一的编排者**，读任何模块前先把它读一遍，后面会省很多来回。

---

## 4. 代码组织约定（读代码前必须知道的 6 条）

1. **三件套**：`Foo.swift`（实现）+ `FooSpecs.md`（规格与边界）+ `FooTests.swift`（XCTest），同目录同名前缀。74/72 对。改行为时必须同时改 specs，仓库有 `/audit-specs-tests` 之类的技能在检查漂移。
2. **纯内核 + 笨外壳（Humble Object）**：能做决定的逻辑抽到无 AppKit 依赖的类型里（常命名为 `*Testable.swift` 或 `*Resolver`/`*Policy`/`*Kernel`），单测只测内核；窗口/视图/tap 那层刻意不单测，`src/coverage.md` 开头明写了这是设计而非缺口。
3. **`*Testable.swift` 是生产代码**，只是"没有 AppKit 依赖、可被测试目标编译"。`macos/api-wrappers/HelperExtensionsTestable.swift` 名字带 Testable，内容是纯生产代码。
4. **静态单例 + 全局可变表**：`Windows.list`、`Applications.list`、`TabGroups.table`、`TilesView.*`、`TilesPanel.shared`、`SwitcherSession.current`。没有 DI 容器，也没有 ViewModel；跨模块协作靠这些静态入口。读的时候把它当"进程内全局状态"。
5. **零 Storyboard、零 SwiftUI、零 xib**。所有界面是纯 Swift 手搓 AppKit，`git grep -i swiftui` 只会命中注释。
6. **注释写"为什么"，密度极高且都是实测数字**。"实测 280ms"、"一次按键 8ms"、"399GB 虚拟内存"这类都是真实故障记录。**这些注释是资产，不是噪音**——它们记录了改法背后的约束，读的时候不要跳过。

---

## 5. 十二个目录，各一句话

| 目录 | 行数 | 一句话 | 详细笔记 |
|---|---:|---|---|
| `src/switcher/` | 27,676 | 切换器本体：窗口/应用模型、选中逻辑、面板渲染、搜索、标签组 | notes/switcher.md |
| `src/preferences/` | 10,763 | 偏好定义/默认值/迁移 + 纯代码搭出来的设置窗口 | notes/preferences-events.md §1-4 |
| `src/pro/` | 6,071 | 授权（试用/Pro/Keychain）+ Day1/4/15/35 提示旅程 | notes/platform.md §1-4b |
| `src/events/` | 4,373 | 所有输入与系统通知：Carbon 热键、CGEvent tap、SkyLight 通知、AX observer 接入 | notes/preferences-events.md §5 |
| `src/window-tracking/` | 4,015 | 语义面"用户此刻在看哪个窗口"：每进程一个 AX observer + 注意力模型 | notes/platform.md §3-4 |
| `src/windowserver/` | 916 | 物理面：窗口存在/位置/Space/最小化/全屏的纯解码与通知路由（先读这里的 README） | notes/platform.md §4a |
| `src/macos/` | 3,156 | 系统能力唯一入口 + 三条阻塞调用调度器（AX/CGS/Process） | notes/foundation.md §2-4 |
| `src/kit/` | 3,084 | 轻量 AppKit 控件（标签、开关、表格行、popover、插画） | notes/foundation.md §4 |
| `src/secondary-windows/` | 2,591 | 除切换器外的窗口：Debug、反馈、首次运行权限/引导 | notes/foundation.md §1 |
| `src/util/` | 1,959 | 线程与队列预算、节流合并、可单测的时间策略、用量统计 | notes/foundation.md §4 |
| `src/debug/` | 1,787 | 主线程卡顿归因、看门狗、benchmark、CLI 驱动的 QA 剧本 | notes/foundation.md §7 |
| `src/api/` | 31 | 只有后端域名与 checkout 归因参数 | — |

根目录四个文件：`main.swift`（信号与崩溃兜底，然后 `App.shared.run()`）、`App.swift`（编排）、`Menubar.swift`（状态栏菜单）、`MainMenu.swift`（让复制粘贴等标准快捷键能用）。

---

## 6. 推荐阅读路线（约 3 天，每天 3-4 小时）

时间估算是"读懂并能改"的标准，不是"翻一遍"。

### 第 1 天：先把骨架立起来（约 4h）

| 步骤 | 读什么 | 读完能回答 | 时间 |
|---|---|---|---|
| 1 | `src/main.swift` + `src/App.swift` 的 `applicationDidFinishLaunching` 与 `continueAppLaunchAfterPermissionsAreGranted` | 启动分哪两段？为什么 `BackgroundWork.preStart()` 和 `Preferences.initialize()` 必须排在最前？权限没给之前为什么就能装 WindowServer tap？ | 40m |
| 2 | `App.swift` 的 `showUiOrCycleSelection` / `buildUiAndShowPanel` / `refreshUi` / `beginHideUi` | 一次召唤的生命周期、为什么隐藏时先置 `SwitcherSession.current = nil` 再交还键盘 | 60m |
| 3 | `src/switcher/SwitcherSession.swift` + `ShortcutAction.swift` + `ATShortcut.swift` | 会话状态存哪、动作 id 怎么映射、修饰键什么时候算"松手" | 40m |
| 4 | `src/windowserver/README.md` + `WsEventRouting.swift` + `WsWindowState.swift` | 物理面/语义面的分工，最小化/全屏/session 在哪个 bit | 40m |
| 5 | `src/window-tracking/AttentionOrderSpecs.md` + `AttentionModel.swift` | 什么算"用户在看这个窗口"，哪几种事件**不**改顺序 | 45m |

### 第 2 天：模型与渲染（约 4h）

| 步骤 | 读什么 | 读完能回答 | 时间 |
|---|---|---|---|
| 6 | `src/switcher/state/Windows.swift` + `SelectionResolver` / `WindowOrderResolver` / `WindowFilterResolver` | 列表顺序怎么来、初选为什么跳过第一个、`selectedIndex` 与 `selectedTarget` 为什么双写 | 90m |
| 7 | `src/switcher/main-window/TilesPanel.swift` + `TilesView.swift` + `TileGridLayout.swift` + `TilePool.swift` | tile 池与 `Windows.list` 下标怎么对应、面板为什么不能变 key window | 90m |
| 8 | `src/switcher/state/WindowThumbnails.swift` + `TileView.updateValues` | 缩略图为什么"先空后满"、全分辨率为什么只抓选中 ±2 | 45m |
| 9 | `src/util/BackgroundWork.swift` + `SchedulingPolicy.swift` + 三个调度器 | 一条阻塞 AX/CGS 调用从发起到回到主线程的全程，线程预算是怎么被卡的 | 60m |

### 第 3 天：事件、状态、配置（约 4h）

| 步骤 | 读什么 | 读完能回答 | 时间 |
|---|---|---|---|
| 10 | `src/events/KeyboardEvents.swift` + `KeyboardEventsTestable.swift` + `ModifierReleaseLog.swift` | 三种输入源（Carbon/tap/local monitor）怎么收敛成一个判定入口，tap 被系统关掉后怎么自愈 | 75m |
| 11 | `src/switcher/state/WindowEventReducer.swift`（先读入口 + `ReducerInput` 分支表）+ `TrackedWindowStateBridge.swift` | 一个 WS 通知怎么变成模型变更，副作用怎么出去 | 60m |
| 12 | `src/preferences/Preferences.swift` + `PreferencesEvents.swift` | 为什么读写偏好是 IPC、为什么每键都要缓存、改一个偏好会触发哪些副作用 | 60m |
| 13 | `src/preferences/settings-window/SettingsWindow.swift` + `LabelAndControl.swift` | 新增一个设置行要动哪几处，搜索索引为什么有 base 和 dynamic 两份 | 45m |
| 14 | `src/pro/license/LicenseManagerSpecs.md` | Pro 五态、无宽限期、Keychain 全有或全无 | 30m |

读完这 14 步，仓库里 90% 的文件你能说出它为什么存在。

---

## 7. 按任务查表（改代码时用）

| 我要…… | 先读 | 大概率要改 |
|---|---|---|
| 加一个设置项 | `preferences/Preferences.swift` 默认值表 → `LabelAndControl.swift` | `Preferences` + 对应 `tabs/*Tab.swift` + `SettingsSearchIndex` |
| 加一个键盘动作 | `ShortcutAction.swift` → `events/KeyboardEvents.swift` | `ShortcutAction` + `ControlsTab.shortcuts` 注册处 |
| 改切换器布局/尺寸 | `Appearance.swift` + `TileGridLayout.swift` | `Appearance` + `TileGridLayout` + `TilesView.updateItemsAndLayout` |
| 修"缩略图不刷新/错位" | `WindowThumbnails.swift` + `Window.refreshThumbnail` + `WindowServerEvents` | 抓图调度或 `shouldShowTheUser` 缓存 |
| 修"选中漂移" | `SelectionResolver` + `SwitcherSession` 的 `selectedTarget` | `Windows.updateSelectedAndHoveredWindowIndex` |
| 修"窗口不消失/幽灵窗口" | `WindowAdmissionResolver` + `PhantomWindowDetector` + `AxObserverHealth` | 准入判定，不是 UI |
| 面板卡顿 | `src/main-thread-ipc.md` + `MainThreadStall.step()` 埋点 | 把阻塞调用挪进三条调度器之一 |
| 改 Pro 提示节奏 | `ProTransitionSpecs.md` + `ProTransitionManagerTestable.swift` | 纯决策核心里改，别改 UI |
| 加一种系统通知 | `src/events/*Events.swift` 任一短文件（14-50 行）当模板 | 新 `*Events` + `App` 里 observe 一行 |

---

## 8. 十个最容易踩的坑（跨模块精选）

1. **`Windows.list[i]` 与 `TilesView.recycledViews[i]` 严格同下标**。被过滤的窗口只是把 tile 的 frame 置零，不重排池子。任何"第 n 个可见 tile"的假设都会错位（`main-window/TilesView.swift:517-533`）。
2. **`SwitcherSession.current != nil` 是"面板在屏"的唯一真相**。所有流程都用它判活，`isActive` 只是派生。
3. **主线程上改 first responder / 输入法上下文是同步 XPC**，实测 3s（#5981）。`TilesView` 里拿/还光标的操作全部 `DispatchQueue.main.async`，别"优化"成同步。
4. **本进程自己的 AX 读必须回主线程**（同进程不产生 IPC，直接进 AppKit，off-main 会 trap）。别的进程的 AX 读必须离主线，走 `AXCallScheduler`。
5. **"读不到" ≠ "没有"**：`WindowElementAcquisition.Outcome.noAnswer` 与 `.absent` 分开；事件 tap 被系统关掉（`tapDisabledByTimeout`）后必须自愈重装。
6. **SkyLight 的 per-window 订阅是"替换"不是"追加"**：每次发全集，发增量会导致只剩一个窗口在被监听（实测 0 vs 91/143/51 个事件）。
7. **偏好未注册的键会直接崩**（`getThenConvertOrReset` 里强解包），所以 `Preferences.initialize()` 必须早于任何读取，且迁移跑在 `registerDefaults()` 之前。
8. **绕过 `Preferences.write` 写 UserDefaults 会让缓存永久脏**，必须自己清 `CachedUserDefaults` 和 `cachedAll`。
9. **`elementDestroyed` 不是死亡证明**：Chromium/Electron 会重建元素而窗口还在，判死要 AX 列表 + WS 表面对账。
10. **别把 `#if DEBUG` 的工具当生产实现**，也别信 `_test-support/Mocks.swift` 里与生产同名的 `App`/`Preferences`/`Logger`。

完整清单（含每条的文件:行号依据）：notes/switcher.md §7、notes/platform.md §7、notes/preferences-events.md §7、notes/foundation.md §7。

---

## 9. 两个仓库级文档，值得单独读

- **`src/windowserver/README.md`（59 行）**：物理面与语义面的边界。全仓最好的入口文件，建议第 1 天就读。
- **`src/main-thread-ipc.md`**：主线程 IPC 的审计记录，说明哪些 AppKit 调用会变成同步 XPC、哪些 `NSWorkspace` 调用可以离主线，附证据。改性能前必读。

另外 `AGENTS.md` 本身就是一份架构约定（主线程 IPC、注释规范、License/Keychain 不变量、构建流程），比多数项目的 README 更有信息量。

---

## 10. 附录

### 10.1 模块笔记

| 文件 | 覆盖 | 行数 |
|---|---|---|
| `docs/source-reading-notes/switcher.md` | `src/switcher/` 全量 + 端到端 12 步数据流 | 170 |
| `docs/source-reading-notes/preferences-events.md` | 偏好体系、设置窗口生成、三种输入源收敛 | 188 |
| `docs/source-reading-notes/platform.md` | pro / window-tracking / windowserver / api | 172 |
| `docs/source-reading-notes/foundation.md` | kit / macos / util / debug / secondary-windows + 现成件清单 | 191 |

每份都按同一结构写：职责 → 文件地图 → 核心类型关系 → 数据流 → 对外边界 → 阅读顺序 → 不变量与坑 → **不确定的部分**。最后一节是刻意保留的：读的人是四个并行 agent，各自声明了"只读了签名没读实现"的范围，别把那些段落当已核实结论。

### 10.2 本文是怎么产出的

四个 agent 并行各读一块（switcher / preferences+events / platform / pro+tracking+windowserver / foundation），共用同一份输出模板，然后由主 pane 汇总、去重、补入口层与构建信息。交叉核对过的不一致处：

- 目录行数：笔记里的"含 md"统计与本文的"仅 `.swift`"统计不同，本文用后者（`wc -l` 实测）。
- `808` 事件语义在 `WsEventRouting.swift` 的枚举名（`windowFocused`）与 README（"不是焦点"）之间矛盾，代码实际在 `AttentionDriver` 丢弃它。**未在真机核实**。

### 10.3 本文没有覆盖的

- 没有运行构建或测试，所有"实测毫秒数"引用自源码注释，未经复测。
- `WindowEventReducer.swift`（1913 行）、`Applications.swift`（1341 行）的逐分支行为未核实。
- 本地化流程（`resources/l10n`、`scripts/l10n`）、图标/插画编译（`scripts/assets`）、公证发布（`scripts/notarytool`）完全未读。
- QA/CLI 那套自动化（`src/debug/Qa*`、`CliEvents`）只看了入口。
