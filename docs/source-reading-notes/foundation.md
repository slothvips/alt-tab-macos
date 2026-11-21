# 基础层阅读笔记：kit / macos / util / debug / secondary-windows / _test-support

> 只读源码分析，未构建、未运行。所有结论指向具体文件（多数带行号）。未核实处统一标"不确定"。
> 行数为 `wc -l` 实测；目录内 `.swift` 与 `*Specs.md` / `*Tests.swift` 分开统计。

## 1. 一句话职责

- **`src/kit`**：可复用的 AppKit 控件与轻量视图封装（按钮、开关、表格行、标签、弹窗、插画）。不含业务逻辑，只解决"系统控件太慢 / 太长 / 不合设计"的问题。
- **`src/macos`**：macOS 系统能力的唯一入口——Accessibility、SkyLight/CGS、进程与 sysctl、TCC 权限、登录项、日志、Mission Control 探测，以及三条"阻塞调用不许在主线/线程爆炸"的调度器。
- **`src/util`**：与 UI 无关的横切基础设施——后台线程与队列预算、节流/合并、可单测的纯策略（重试、扫描预算、重绘节奏）、用量统计、公证票据停放、搬到 Applications。
- **`src/debug`**：调试与 QA 支撑，几乎全部包在 `#if DEBUG` 内：主线程卡顿归因、看门狗、benchmark、由 CLI 驱动的 QA 生命周期/菜单/界面截图/试用剧本。
- **`src/secondary-windows`**：除切换器之外的所有窗口——Debug 窗口（日志 + 队列图）、反馈窗口、首次运行的权限窗口（含 onboarding、彩带、权限流程决策）。
- **`src/_test-support`**：单元测试目标的替身与测试专用支撑，只编译进 `unit-tests`，不是生产实现。

## 2. 目录与文件地图

目录汇总（实测）：

| 路径 | .swift 文件 | 行数（含 md） | 一句话 |
|---|---|---|---|
| `src/kit/` | 28 | 3331 | 轻量 AppKit 控件集 |
| `src/macos/` | 28 | 3387 | 系统 API 封装 + 调度器 + 权限 |
| `src/util/` | 12 | 2222 | 线程预算、节流、纯策略、统计 |
| `src/debug/` | 8 | 1787 | DEBUG/QA 工具 |
| `src/secondary-windows/` | 11 | 2663 | 非切换器窗口 |
| `src/_test-support/` | 2 | 390 | 测试替身 |

关键文件（省略 `src/` 前缀）：

| 路径 | 行数 | 一句话 |
|---|---|---|
| `util/BackgroundWork.swift` | 179 | 全局线程/队列登记表 + `LabeledOperationQueue` + 线程预算 assert |
| `util/SchedulingPolicy.swift` | 275 | 纯策略：节流、重试退避、重绘节奏、AX 扫描预算 |
| `util/Throttler.swift` | 137 | `Throttler` / `ThrottlerWithKey` / `ConcurrentMap` / `ConcurrentArray` |
| `util/CoalescedWork.swift` | 119 | `RepaintCoalescer`（尾沿合并重绘）+ `BatchCoalescer` |
| `util/UsageStats.swift` | 205 | 用量计数（时间戳数组）+ 去抖落盘 |
| `util/StapledTicket.swift` | 83 | 运行期把公证票据挪走、退出时还原（性能优化） |
| `macos/AXCallScheduler.swift` | 284 | AX 调用三车道执行器（首试/扫描/重试）+ 每 pid 并发上限 |
| `macos/CGSCallScheduler.swift` | 101 | WindowServer/SkyLight 阻塞读的唯一出口 |
| `macos/ProcessCallScheduler.swift` | 23 | 进程/sysctl 查询的离主线执行 |
| `macos/SystemPermissions.swift` | 341 | TCC 权限检测、提示、重试、启动流程 |
| `macos/AXUIElement.swift` | 416 | AX 属性批量读、自有进程线程规则、暴力扫描 |
| `macos/api-wrappers/SkyLight.framework.swift` | 300 | 私有符号绑定：Space、截图、makeKeyWindow、通知 |
| `macos/api-wrappers/HelperExtensions.swift` | 420 | AppKit 扩展合集（颜色、约束、面板 chrome、CGEvent） |
| `macos/api-wrappers/Logger.swift` | 135 | 单通道日志，`--logs=` 控制级别 |
| `macos/api-wrappers/HelperExtensionsTestable.swift` | 90 | **生产代码**：`onAction`、`isValidPersistedFrame`、`pid.isAlive` |
| `kit/text/LightLabel.swift` | 236 | 绕过 NSTextField/TextKit 的只读标签 |
| `kit/AnchoredPopover.swift` | 314 | 菜单栏弹窗 + `StatusItemAnchor` 就绪判定 |
| `kit/LocalizedIllustration.swift` | 71 | 插画缓存 + 本地化/RTL/暗色 |
| `kit/CustomRecorderControl.swift` | 150 | 快捷键录制控件（冲突处理） |
| `kit/TableView.swift` | 87 | 名字是 TableView，内容是 `SidebarRowsList` + 滚动转发 |
| `kit/SheetWindow.swift` | 100 | 设置项 sheet 基类 + `NSAlert.present/runAttached` |
| `debug/MainThreadStall.swift` | 54 | 主线程长步骤归因（release 也可用） |
| `debug/MainThreadWatchdog.swift` | 145 | 主线程栈采样（仅 DEBUG） |
| `debug/QaLifecycle.swift` | 300 | QA 会话、伪造权限、可控时钟 |
| `debug/QaSurfaces.swift` | 605 | 逐个打开所有界面的截图夹具 |
| `secondary-windows/DebugWindow.swift` | 456 | 实时日志窗口 + 检视工具 |
| `secondary-windows/permission-window/PermissionsWindow.swift` | 281 | 首次运行权限窗口 |
| `secondary-windows/permission-window/PermissionFlow.swift` | 84 | 权限步骤的纯决策 |
| `secondary-windows/permission-window/OnboardingPopover.swift` | 595 | 首次运行两步引导 |
| `secondary-windows/FeedbackWindow.swift` | 322 | 反馈表单（bug/enhancement） |
| `_test-support/Mocks.swift` | 296 | 与生产同名的 stub 类型 |

## 3. 核心类型与关系

分层（下层不知道上层）：

```
                 ┌── src/debug (DEBUG) ── 读调度器队列深度、采样主线程
                 │
  业务层  switcher/ events/ preferences/ pro/ window-tracking/
                 │            │                 │
        ┌────────▼───┐  ┌─────▼──────┐   ┌──────▼────────────┐
 L3     │ src/kit    │  │ src/secondary-windows │           │
        │ 控件       │  │ Debug/Feedback/权限窗口            │
        └────────┬───┘  └─────┬──────┘   └──────┬────────────┘
                 │            │                 │
 L2      ┌───────▼────────────▼─────────────────▼────────┐
         │ src/util：LabeledOperationQueue / Throttler /  │
         │ Policy / UsageStats / StapledTicket            │
         └───────┬────────────────────────────────────────┘
                 │ 线程与队列
 L1      ┌───────▼────────────────────────────────────────┐
         │ src/macos：AXCallScheduler · CGSCallScheduler · │
         │ ProcessCallScheduler · SystemPermissions ·      │
         │ SkyLight/AX/CGS 符号绑定 · Logger · MissionControl │
         └───────┬────────────────────────────────────────┘
                 │
 L0            macOS 私有/公开 API
```

关键耦合点只有两个：

1. **队列来自 `util`**：`LabeledOperationQueue`（`util/BackgroundWork.swift:163`）是所有调度器和业务队列的基类，构造时会向 `BackgroundWork` 报备线程数（`:170`），超过 50 就 `assert`（`:55-60`）。因此新增队列会改变全局线程预算。
2. **调度器来自 `macos`**：`AXCallScheduler` / `CGSCallScheduler` / `ProcessCallScheduler` 三个单例是所有阻塞系统调用的门面，业务层只调它们的用例方法。

`kit` 对下层几乎无依赖（只用 `HelperExtensions` 的 `fit()`/`onAction`）；`secondary-windows` 同时依赖 `kit`（控件）、`macos`（权限状态）、`debug`（QAMenu/DebugWindow）。

## 4. 关键能力清单（最该先记住的现成件）

| 类型 / 函数 | 位置 | 用途 |
|---|---|---|
| `LabeledOperationQueue` | `util/BackgroundWork.swift:163` | 带标签+QoS+并发上限+线程报备的 OperationQueue，`addOperationAfter` 见 `:174` |
| `AXCallScheduler.shared.schedule(key:pid:scan:block:)` | `macos/AXCallScheduler.swift:79` | 发 AX 调用；同 key 只跑一个、超时按 `RetryPolicy` 退避、每 pid 最多 3 并发（`:31`） |
| `CGSCallScheduler.run / windowsInSpaces / existingWindowIds` | `macos/CGSCallScheduler.swift:30,52,69` | WindowServer 阻塞读；`run` 是"任意阻塞读"的逃生口 |
| `ProcessCallScheduler.isActualApplication` | `macos/ProcessCallScheduler.swift:17` | 判断 pid 是否真实可切换应用 |
| `AXUIElement.attributes(_:pid:)` / `windowsByBruteForce` | `macos/AXUIElement.swift:152,272` | 一次批量读多属性；暴力扫 AXUIElementID（250ms 预算） |
| `makeKeyWindow(psn:wid:)` | `macos/api-wrappers/SkyLight.framework.swift:184` | 合成鼠标事件让别的 app 的窗口变 key |
| `setNativeCommandTabEnabled` | `macos/api-wrappers/SkyLight.framework.swift:98` | 关掉系统 ⌘⇥ 符号热键 |
| `SystemPermissions.promptOrOpenPane` | `macos/SystemPermissions.swift:108` | 只在没条目时弹系统提示，否则打开设置面板 |
| `MissionControl.state()` | `macos/MissionControl.swift:44` | 判断 Mission Control/App Exposé/Show Desktop 是否在屏 |
| `Throttler` / `ThrottlerWithKey` | `util/Throttler.swift:3,36` | 前沿执行 + 尾沿合并；带 key 版可跨线程 |
| `RepaintCoalescer` / `BatchCoalescer` | `util/CoalescedWork.swift:10,74` | 重绘尾沿合并；批量读合并（主线程断言） |
| `RetryPolicy` / `AxTraversalPolicy` | `util/SchedulingPolicy.swift:104,247` | 退避参数与时间预算的唯一来源，可单测 |
| `LightLabel` | `kit/text/LightLabel.swift:20` | 大量行标签的低成本替代品，自带搜索高亮 |
| `LocalizedIllustration.image` | `kit/LocalizedIllustration.swift:8` | 取插画（缓存 key 含 locale/暗色/RTL/覆盖词） |
| `AnchoredPopover.present` | `kit/AnchoredPopover.swift:34` | 菜单栏图标就绪后才弹的 popover，超时降级为无箭头 |
| `NSAlert.present / runAttached` | `kit/SheetWindow.swift:79,86` | 能挂 sheet 就挂、否则 app-modal |
| `Logger.*` + `--logs=debug` | `macos/api-wrappers/Logger.swift:31-83` | 唯一日志通道，格式化与 IO 在 `writeQueue` |
| `MainThreadStall.step()` | `debug/MainThreadStall.swift:25` | 标注主线程长步骤（阈值 16ms，`:17`） |
| `NSControl.onAction` | `macos/api-wrappers/HelperExtensionsTestable.swift:23` | 用闭包替代 target/selector（关联对象实现） |

## 5. 对外边界（谁在用）

按类型名 grep 得出（排除本目录自身）：

- **`util` 被全体使用**：`LabeledOperationQueue` 只经 `BackgroundWork` 暴露，`Throttler` 见 `events/`、`switcher/state/`；`RepaintCoalescer` 只被 `src/App.swift` 用。
- **`macos` 是系统能力总入口**：`AXCallScheduler`/`CGSCallScheduler` → `events/`、`switcher/state/`、`window-tracking/`；`SkyLight` 的 `CGS_CONNECTION` → `events/`、`switcher/state/`、`windowserver/`；`SystemPermissions` → `App.swift`、`window-tracking/`。
- **`kit` 主要服务设置与 menubar**：`LightLabel` → `preferences/settings-window/`（含 `tabs/controls`）；`LocalizedIllustrationView`/`AnchoredPopover` → `pro/ui/`、`pro/scheduling/`；`SheetWindow` → 设置窗口各 tab。
- **`secondary-windows` 由 App/Menubar 打开**：`PermissionsWindow` → `App.swift`、`Menubar.swift`、`pro/ui`；`FeedbackWindow` → `App.swift`、`pro/ui`、`switcher/search-discovery`；`DebugWindow` → `App.swift`；`DebugProfile` → `switcher/state/`。
- **`debug` 被两处生产代码与 QA 通道读**：`QaLifecycle` → `App.swift`、`main.swift`、`events/`、`macos/SystemPermissions.swift`、`pro/license`；`QaSurfaces` 被 `events/`、`preferences/.../controls`、`util/UsageStats.swift:29`（仅注释）引用。
- **`_test-support`** 只被 `unit-tests` target 引用（`project.pbxproj` 中 `Mocks.swift` 仅在测试 Sources 里）。

## 6. 推荐阅读顺序

1. **先读 `util/BackgroundWork.swift` + `util/SchedulingPolicy.swift`**（约 450 行）。线程模型和所有"为什么是这个时间常数"都在这里，后面每个调度器都引用它。
2. **再读三个调度器**：`ProcessCallScheduler`（23 行，最短）→ `CGSCallScheduler`（101）→ `AXCallScheduler`（284）。读完就懂"阻塞调用怎么进、结果怎么回主线程"。
3. **然后按需读 `macos` 的具体封装**：`AXUIElement.swift`、`SystemPermissions.swift`、`SkyLight.framework.swift`。这三份最长也最密，建议只在改相关功能时通读。
4. **UI 层按改动面挑**：改菜单栏 → `kit/AnchoredPopover.swift`；改设置 → `kit/text/LightLabel.swift` + `kit/SheetWindow.swift`；改首次运行 → `secondary-windows/permission-window/*`（先 `PermissionFlow.swift`）。
5. **调试/QA 留在最后**：`debug/MainThreadStall.swift`（会用即可）、`QaSurfaces.swift`（只在跑 VR-01 时读）。

## 7. 关键不变量与坑

**线程**

- 自有进程的 AX 读**必须回主线程**（`macos/AXUIElement.swift:79-84`）——同进程 AX 不产生 IPC，直接进 AppKit，off-main 会 `__CF_IS_OBJC` trap。所有 pid-aware 访问器都靠它兜底。
- `CGEvent.toNSEvent()` off-main 会 `main.sync`（`macos/api-wrappers/HelperExtensions.swift:387-397`）；从主线程调用时不能改成 sync，否则死锁。
- 三条 AX 车道**按 QoS 隔离**，不只是宽度（`macos/AXCallScheduler.swift:56-74`）；QoS 会被捐赠给目标进程，改宽度不改 QoS 得不到隔离。
- 全局线程预算硬上限：`assert(totalPotentialThreadCount <= 50)`（`util/BackgroundWork.swift:55-60`）。新增队列会走到这条断言的计数里。
- 每个 app 一个 AXObserver 共享**一个** runloop（`util/BackgroundWork.swift:43-45`）。

**"失败不是答案"**

- `throwIfNotSuccess` 把错误分成 `appUnresponsive`（可重试）与 `noAnswer`（永久），而 `noAnswer` 不重试也不隔离 app（`AXUIElement.swift:28-31`、`AXCallScheduler.swift:218-223`）。
- `castSafely` 遇到 `.axError` 占位和 `AXValueGetValue` 失败一律返回 nil，绝不返回 0（`AXUIElement.swift:175-197`）——零值曾被当成真实的 0×0 尺寸。
- CGS 的"空数组"和"nil"是两回事，空值不能单独作为证据（`macos/CGSCallScheduler.swift:75-83`）。

**缓存与频率**

- `LocalizedIllustration`：图片 `countLimit = 48`、drawer `countLimit = 4`（`kit/LocalizedIllustration.swift:19,31`），key 含 bundle/名字/locale/暗色/RTL/覆盖词。
- `LightLabel.intrinsicContentSize` 按 `bounds.width` 缓存（`kit/text/LightLabel.swift:154-180`）；改 `font`/`lineBreakMode`/`maximumNumberOfLines` 会失效缓存。
- `PopupButtonLikeSystemSettings` 按当前标题缓存测量结果，否则每次焦点切换约 50ms（`kit/PopupButtonLikeSystemSettings.swift:12-21,31-45`）。
- `UsageStats` 只在 `writeQueue` 上改内存，2s 去抖落盘，退出时 `flushNow`（`util/UsageStats.swift:17,109`）。时间戳是存储格式，不许去重/分桶（`:3-4`）。

**私有 API**

- `shouldHideAnchor` 用 `respondsTo` 探测、KVC 写入（`kit/AnchoredPopover.swift:184`）；`_setDisableSheetAnimation:` 只在 QA 且 `Preferences.qaPristine` 时调用（`debug/QaSheetAnimation.swift:20-25`）；`abortAllToolTips` 同样先探测（`kit/Tooltips.swift:6-9`）。
- `SLSWindowIteratorGetBounds` 必须走 `@convention(c)` 指针，因为 x86_64 上结构体按 sret 返回（`SkyLight.framework.swift:284-297`）。其它私有符号都用 `@_silgen_name`。
- `SLSRequestNotificationsForWindows` **替换**整张监视表，不是追加（`:220-229`）。

**权限**

- 读 Accessibility 用私有 `TCCAccessCheckAuditToken`（~10ms/次），因为 `AXIsProcessTrusted` 是进程内缓存且会被提前到达的通知刷新成旧值（`SystemPermissions.swift:155-168`）。
- Screen Recording 用"能否看到别的 app 的窗口标题"做廉价探测，`CGPreflightScreenCaptureAccess` 冻结在进程启动时（`:206-232`）；那次探测有 6s 超时并允许返回 nil（`:325-340`）。
- `.skipped` 只表示用户放弃，永远不能掩盖真实授权（`:219-225`）。

**测试替身与命名坑**

- `_test-support/Mocks.swift` 里有与生产**同名**的 `App`、`Preferences`、`Logger`、`ModifiersFlags` 等（`:74-283`）；`ProPromptTestSupport.swift:6-92` 同理。读生产逻辑时不要把这些当实现。
- `macos/api-wrappers/HelperExtensionsTestable.swift` 名字带 Testable，但内容是**生产代码**（`onAction` 在 `:23`，`isValidPersistedFrame` 在 `:11`，`pid.isAlive` 在 `:28`）。
- `kit/TableView.swift` 里没有 TableView，而是 `SidebarRowsList`/`ForwardingVerticalScrollView`/`ForwardingVerticalDocumentView`（`:5-87`）。
- `kit/CustomRecorderControl.swift:51-57` 用 `ObjCExceptionCatcher` 包住 AppKit 约束更新，否则 macOS 26 上会 SIGTRAP；这是崩溃修复，不是冗余。

## 8. 不确定 / 没读到的部分

- 只读了头部与声明清单、未通读：`debug/QaLifecycle.swift`（300）、`debug/QaSurfaces.swift`（605）、`debug/QaTrial.swift`（266）、`debug/QAMenu.swift`（319）、`secondary-windows/DebugWindow.swift`（456）、`permission-window/OnboardingPopover.swift`（595）。这些文件内部的步骤细节本文没有覆盖。
- 各目录的 `*Specs.md` / `*Tests.swift` 只读了 3 份摘要（AnchoredPopover、ProcessLiveness、PersistedWindowFrame），其余仅确认存在；因此"测试覆盖了什么"未核实。
- 第 5 节"谁在用"是按类型名 grep 得出，可能漏掉同义调用或反射调用；`QaSurfaces` 与 `util/UsageStats.swift:29` 只有注释关联，是否真有代码路径引用未确认。
- `xcodeproj` 的 target 归属只抽查了 4 个文件（LightLabel、LocalizedIllustration、BackgroundWork、Mocks），其它文件是否同时进测试 target 未逐一核对。
- 目录文件数比任务描述多（kit 实测 28 个 .swift +3 个 md；macos 28 个 .swift +6 个 md），差异来自是否统计 Specs；行数按"含 md"统计，与任务给的约数（3.1k/3.2k）略有出入。
- 未运行任何东西：所有"性能数字"（1s AX 超时、50ms 弹窗测量、275ms sheet 动画等）都来自源码注释里记录的实测，我本人没有复测。
