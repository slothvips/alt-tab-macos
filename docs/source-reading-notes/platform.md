## 1. 一句话职责

- **`src/pro/`**：付费墙与付费旅程——判定用户当前是不是 Pro（`LicenseManager`），据此在运行期拦截功能（`ProFeature`），并驱动 Day 1/4/15/35 的提示、免费体验与降级/恢复（`ProTransition*`、`ui/`）。
- **`src/window-tracking/`**：语义面——「用户此刻在看哪个窗口」。每个进程一个 AX observer 把焦点/标题/窗口生死推上来，`AttentionModel` 是两个纯决策核之一，`AttentionEngine` 是主线程外壳，结果只允许用来写窗口顺序。
- **`src/windowserver/`**：物理面——窗口「存在、在哪、多大、在哪个 Space、最小化/全屏」由 SkyLight/CGS 决定；这里放纯解码、通知 id 路由、快照库存与 AX 元素获取策略，不含注意力判断。
- **`src/api/`**：只有 `Endpoints.swift`，把后端域名、license API base、带归因参数的 checkout URL 集中成常量。

## 2. 目录与文件地图

行数为 `wc -l` 实测；`Tests`/`Specs` 按目录合并成一行，避免表过长。

| 路径 | 行数 | 一句话 |
|---|---|---|
| `src/api/Endpoints.swift` | 31 | 域名/license base URL/`?via=` checkout 归因码 |
| `src/windowserver/README.md` | 59 | 物理面与语义面的边界说明（本目录最好的入口） |
| `src/windowserver/WsEventRouting.swift` | 99 | SLS 通知 id（811/804/806/807/815/816/808/1325/1326/1329/1401）→ 动作；`WsEventIngress` 只合并几何事件 |
| `src/windowserver/WsWindowState.swift` | 72 | `WsRawWindow` + 纯解码：visible=attrs bit 0x2、minimized=tags 1<<60、fullscreen=mask 0x20 |
| `src/windowserver/WindowSurfaceInventory.swift` | 176 | 全 Space 的 wid→`WsRawWindow` 库存、快照代序、`representativeWid` 沿 parentWid 上溯 |
| `src/windowserver/PublishedWindows.swift` | 38 | 一次批量读 `kAXWindows`+`kAXFocusedWindow`+`kAXMainWindow` 并合并（其他 Space 的窗口靠后两者） |
| `src/windowserver/WindowElementAcquisition.swift` | 87 | wid→`AXUIElement` 的执行器；`found/absent/noAnswer` 三态，避免「读不到」被当成「已关闭」 |
| `src/windowserver/WindowAcquisitionPolicy.swift` | 14 | 两条获取路径：当前 Space 批量读 / 其他 Space 暴力枚举 |
| `src/windowserver/WindowServerQuery.swift` | 36 | 「一次大 SLS 调用」批量查询，必须 off-main |
| `src/windowserver/*Specs.md`（5 个） | 325 | 各纯核的证据与边界 |
| `src/windowserver/*Tests.swift`（4 个） | 394 | 对应单元测试 |
| `src/window-tracking/AxObserverRegistry.swift` | 736 | 每进程 1 个 `AXObserver`；回调分发、元素镜像、destroy 关联、恢复 tick |
| `src/window-tracking/AxObserverHealth.swift` | 586 | 订阅状态机（纯）：创建/订阅/退避/全局权限失败/重建 |
| `src/window-tracking/AttentionModel.swift` | 225 | 纯核：front process 与 per-process focused window 分开建模，决定 `.front` |
| `src/window-tracking/AttentionDriver.swift` | 269 | 把 reducer 词汇翻译成 model 词汇，分配 `IngressSequence`，持有 model state |
| `src/window-tracking/AttentionEngine.swift` | 283 | 主线程外壳：进程代、settle 定时器、commit、未表示窗口的等待器 |
| `src/window-tracking/AttentionSettlePolicy.swift` | 57 | 一个进程的答案突发只让最后一个提交（60ms/200ms） |
| `src/window-tracking/AxTitleNotificationPolicy.swift` | 44 | 一次 `AXTitleChanged` 是否属于「窗口本身」 |
| `src/window-tracking/TrackingTypes.swift` | 72 | `ProcessGeneration`/`WindowIdentity`/`IngressSequence`/`MonotonicTimestamp`/`QueryIssueOrder` |
| `src/window-tracking/TrackingTelemetry.swift` | 273 | DEBUG 遥测 schema（扁平、无标题），`--qa-state`/`--qa-telemetry` 的数据源 |
| `src/window-tracking/TrackingTelemetryRecorder.swift` | 124 | 运行期写遥测的唯一入口；Release 编译为空 |
| `src/window-tracking/*Specs.md`（8 个） | 662 | 含 `AttentionOrderSpecs.md`（谁能写顺序） |
| `src/window-tracking/*Tests.swift`（6 个） | 1219 | 注意力/健康/遥测/settle 的单元测试 |
| `src/pro/license/LicenseManager.swift` | 360 | 唯一授权真相：trial 14 天、Keychain 全有或全无、30 天校验、`forcesPro` |
| `src/pro/license/LicenseState.swift` | 35 | 五态枚举 + `isProAvailable`/appcast tier |
| `src/pro/license/LicenseAPI.swift` | 60 | protocol + 结果 DTO + 本地化错误 |
| `src/pro/license/RemoteLicenseClient.swift` | 179 | `/activate` `/validate` `/deactivate` 的 HTTP 实现（含机器名/试用归因） |
| `src/pro/license/Keychain.swift` | 110 | GenericPassword 读写；先 update 后 add，从不先删 |
| `src/pro/license/MachineFingerprint.swift` | 21 | IOPlatformUUID，失败回落 Keychain 里的 UUID |
| `src/pro/license/Clock.swift` | 32 | `Clock` 协议 + DEBUG QA 时钟 |
| `src/pro/license/LicenseManagerSpecs.md` | 132 | 授权状态机与 20+ 条不变量（权威文档） |
| `src/pro/license/LicenseManagerTests.swift` | 981 | 覆盖 A–J 全部场景 |
| `src/pro/ProFeature.swift` | 39 | 运行期门禁入口 `attemptUse()` 与「存量值是否 Pro」 |
| `src/pro/ProFeatureCopy.swift` | 18 | 四处功能文案与试用承诺的本地化字符串 |
| `src/pro/scheduling/ProTransitionManager.swift` | 443 | 协调器：license 变化、免费体验、延后展示、派发 UI 动作 |
| `src/pro/scheduling/ProTransitionState.swift` | 180 | 持久化 Day-X 标记、remembered 索引、快照/恢复 Pro 偏好 |
| `src/pro/scheduling/ProTransitionScheduler.swift` | 82 | 单个 wall-clock `DispatchWorkItem`，跨重启补火 |
| `src/pro/scheduling/ProTransitionManagerTestable.swift` | 216 | 纯决策：硬门禁/开面板/定时/徽标/证据排序 |
| `src/pro/scheduling/Day1WelcomeLetterPopover.swift` | 175 | 欢迎信（含 Free/Pro 对照表） |
| `src/pro/scheduling/Day4TourPopover.swift` | 82 | 第 4 天风格漫游，选择写 `appearanceStyle` |
| `src/pro/scheduling/Day15FullUpgradeWindow.swift` | 68 | 全屏升级窗；`showWithTrialEvidence` 先读历史再开窗 |
| `src/pro/scheduling/Day15HardGatePopover.swift` | 42 | 过期后每次被拦都弹的小 popover（`.applicationDefined`） |
| `src/pro/scheduling/Day35FinalWindow.swift` | 26 | 第 35 天最后提醒，复用升级窗布局 |
| `src/pro/scheduling/ProTransitionTests.swift` | 700 | 计时/免费体验/Day4 重试/证据优先级 |
| `src/pro/scheduling/ProTransitionSpecs.md` | 82 | 旅程时间表、各 surface 的触发与错过规则 |
| `src/pro/ui/ProPromptHost.swift` | 109 | 动作→窗口的分发器；会话/竞争 UI/全屏等展示条件 |
| `src/pro/ui/ProPromptPresentation.swift` | 65 | 带 generation 的异步加载 + 2s 兜底，取消后不可复活 |
| `src/pro/ui/ProPromptWindow.swift` | 58 | 无关闭/最小化/ Escape 的提示窗基类；按钮拒绝 Return |
| `src/pro/ui/ProPromptPopover.swift` | 125 | 菜单栏锚定 popover 的构造/展示/行布局 |
| `src/pro/ui/ProPromptHeader.swift` | 64 | 标题 + 兔子插图 |
| `src/pro/ui/ProBadgeView.swift` | 401 | Pro 渐变、shine 动画、分段控件角标 |
| `src/pro/ui/ProJourneyView.swift` | 417 | 四页签对比视图（过期窗、Day35、Settings 共用） |
| `src/pro/ui/ProGradientButton.swift` | 71 | 渐变主按钮 |
| `src/pro/ui/*Tests.swift`（2 个） | 573 | 提示流程/展示逻辑 |
| `src/pro/ui/*Specs.md`（2 个） | 105 | 分段角标与旅程视图 |

## 3. 核心类型与关系

两条平面各管一半，中间由 `AttentionModel` 汇合，最终只有一个出口写顺序。

```
SLS notify proc（811 create / 804 destroy / 806,807 geometry /
                 815,816 order / 808 "focused" / 1325,1326 space / 1329,1401 space）
   │  WsEventIngress（纯；几何事件按 (segment,wid) 覆盖合并）
   ▼  主线程
TrackedWindowStateBridge.dispatch(.windowCreated/.windowDestroyed/…)
   ▲
NSWorkspace.didActivateApplication ──▶ .appActivated（只有 pid，没有窗口）

AXObserverRegistry（每 pid 1 个 observer，axSemantics 线程）
   ├ title/focused/main/windowCreated/elementDestroyed ─▶ Applications.applyObserved*
   └ 焦点类 ─▶ AttentionEngine.axSemanticFocus(pid,wid) ─settle 60/200ms─▶ driver.decideSemantic
type-13 点击 ─▶ AttentionEngine.directedAttention ─────▶ driver.decideDirected
                                                         │
                        AttentionDriver.translate → AttentionModel.reduce
                                                         │ .front(window)
                        ReducerInput.attentionCommitted → WindowEventReducer.applyFocusAndBump
                                                         ▼
                                                  Windows.list 的 MRU 顺序
```

- **身份**：`ProcessGeneration`（pid + 代）是一切 identity 规则的键，因为 pid 会被复用（`TrackingTypes.swift:3-13`）。
- **窗口身份**：`WindowIdentity` = 进程代 + wid；wid 是 session 内唯一的表面对身份（`TrackingTypes.swift:15-25`）。
- **注意力状态**：`AttentionModelState` 里 `frontProcess` 与 `focusedWindow[process]` 分开存；`visibleFront` 为 nil 表示「没人说过」，不是「没有窗口」（`AttentionModel.swift:122-148`）。
- **物理库存**：`WindowSurfaceInventory.byWindowId` 是全 Space 的 `WsRawWindow`，与 `Windows.byWindowId`（可切换目标）刻意分开（`WindowSurfaceInventory.swift:84-99`）。
- **Pro 状态**：`LicenseState`（五态）→ `ProFeature.attemptUse()` 的运行期判断 + `ProTransitionState` 的持久化标记，两者通过 `ProTransitionManagerTestable.State` 快照汇合（`ProTransitionState.swift:74-97`）。

## 4. 端到端数据流

### a) 系统里出现 / 移动 / 关闭一个窗口

1. **出现**：811 → `WsEventRouting` 判为 `.acquireAndDiscriminate`（`WsEventRouting.swift:38-48`）→ reducer 的 `.windowCreated` → 发现流程用 `WindowElementAcquisition` 拿 AX 元素。811 总是最早（实测 11/11，早 36–597ms，`AxObserverHealth.swift:49-58`），所以它是主触发。
2. **AX 侧补充**：`windowCreated` 通知会带回活的元素**和**它的 `AXTabGroup`，一次读全（`AxObserverRegistry.swift:526-554`）；对已跟踪的 wid 只刷新事实。
3. **移动/缩放**：806/807 只表示「去读最新几何」。同一 segment（中间没有语义事件）同一 wid 的重复报告被覆盖（`WsEventRouting.swift:78-92`），真正的查询走 off-main 的 `WindowServerQuery`（`WindowServerQuery.swift:3-10`，忙时实测 ~27ms）。
4. **关闭**：804 → `.remove`；816 order-out 只是「可能没了」，要给一次探测；AX 的 `elementDestroyed` 更快（实测 ~175ms），但**只作为线索**——Apps 会重建元素而窗口仍在，所以走重对账而不是直接判死（`AxObserverRegistry.swift:504-520`）。
5. **前台切换**：`NSWorkspace` 只给 pid（`WindowServerEvents.swift:55-69`）→ `.appActivated` → `AttentionModel` 把 front 换成该进程；若它从没被命名过窗口，就发**一次** bounded 的 `kAXFocusedWindow` 读（`AttentionModel.swift:40-49`，`AttentionModelDecision.readFocusedWindow` at :216）。
6. **谁真的改顺序**：只有 `.front` 或结构性修补；808/815/816 一律被丢弃（`AttentionDriver.swift:178-188`，规则见 `AttentionOrderSpecs.md:39-57`）。

### b) pro 功能如何挂接

- **授权入口**：`App.swift:666/669` 调 `LicenseManager.initialize()`；`App.swift:648-651` 把 `onStateChanged` 接到 `ProTransitionManager.onLicenseStateChanged()`；`onBeforeProUnlock`（`App.swift:645-646`）在翻成 `.pro` **之前**恢复被快照的 Pro 偏好。
- **启动与里程碑**：`App.swift:567` 在权限齐备后调 `onAppBecameUsable`，试用从这一刻起算（`LicenseManager.swift:169-180`）；`App.swift:585-587` 绑定 `onAction` → `ProPromptHost.dispatch`，然后 `onAppLaunchComplete` 补火错过的定时器。
- **Switcher 钩子**：`App.swift:407` `onSwitcherShown`（Day4/免费体验/过期）、`App.swift:102` `onSwitcherDismissed`（延后 1s 展示，`ProTransitionManager.swift:223-233`）、`App.swift:117` `refreshAfterSwitcherDismissal`（过期降级延到可见工作之后，:240-248）。
- **运行期门禁**：额外快捷键 `ShortcutAction.swift:64`、搜索 `TilesView.swift:101`，都走 `ProFeature.attemptUse()`（`ProFeature.swift:22-32`）；设置侧写入被 `PreferencesEvents.swift:62` 弹回。
- **徽标**：`Menubar.swift:228` 读 `shouldShowBadgeDot`，第 13/14 天显示（`ProTransitionManagerTestable.swift:135-142`）。

## 5. 对外边界

- **pro 依赖**：`Preferences`/`ProGatedPreferences`（`PreferenceDefinition.swift:97`）、`UsageStats.loadTrialEvidence`、`Menubar`、`App`（`hideUi`/`showSecondaryWindow`/`resetPreferencesDependentComponents`）、`AnchoredPopover`（`src/kit/`）、`SearchDiscoveryHint`。
- **谁依赖 pro**：`PreferencesEvents`、`PreferenceDefinition`、`SettingsWindow`/`UpgradeTab`/`AppearanceTab`/`ControlsTab`、`Menubar`、`App`、`switcher`（搜索与额外快捷键）、`debug/QA*`（`QaTrial`、`QAMenu`、`QaLifecycle`）。
- **window-tracking 依赖**：`Applications`、`Windows`、`TabGroups`、`FocusIntents`、`WindowSurfaceInventory`/`WindowServerQuery`、`AXCallScheduler`/`CGSCallScheduler`、`BackgroundWork.axSemanticsThread`（`AxObserverRegistry.swift:640-643`，线程建于 `src/util/BackgroundWork.swift:45`）。
- **谁依赖 window-tracking**：`WindowServerEvents`（`.appActivated`、`subscribe`）、`Applications`（`applyObserved*`、`deliversTitles`）、`RunningApplications`/`WindowAttentionEvents`、`switcher`（`AttentionEngine.currentUserContext` 用于全屏快捷键例外，`App.swift:491`）、`debug` 遥测。
- **windowserver 依赖**：`WindowServerEvents`、`Applications`、`AxObserverRegistry`、`AttentionEngine`（等待表示窗口时 `upsert` 行并创建候选，`AttentionEngine.swift:217-263`）。
- **api**：被 `LicenseManager`（`licenseApiBaseUrl`，`LicenseManager.swift:22`）、`ProTransitionManager.openCheckout`（:396-398）、`Menubar`/Settings 的 checkout 入口使用。

## 6. 推荐阅读顺序

1. **`windowserver/README.md` + `WsEventRouting.swift` + `WsWindowState.swift`**（约 30 分钟）→ 能回答：哪些数字是可见/最小化/全屏？808 为什么不能移动 MRU？几何事件怎么被合并？
2. **`window-tracking/AttentionOrderSpecs.md` + `AttentionModel.swift`**（约 45 分钟）→ 能回答：什么算「用户在看这个窗口」？为什么 front process 与 focused window 要分开？哪几种情况顺序**不**动？
3. **`AttentionDriver.swift` + `AttentionSettlePolicy.swift` + `AttentionEngine.swift`**（约 45 分钟）→ 能回答：`IngressSequence` 解决什么？60ms/200ms 从哪来？点击为什么不等 settle？发现落后时怎么等窗口对象？
4. **`AxObserverRegistry.swift` + `AxObserverHealth.swift`**（约 1 小时）→ 能回答：为什么一个进程只有一个 observer？退避/冷却/重建的边界？权限失败为什么只能靠 `AXIsProcessTrusted` 升级？
5. **`pro/license/LicenseManagerSpecs.md` → `LicenseManager.swift` → `ProTransitionSpecs.md` → `ProTransitionManager.swift`**（约 1.5 小时）→ 能回答：Pro 的五态与「无宽限期」怎么落地？免费体验为什么只给一次？提示为什么都要等 switcher 关闭后 1 秒？

## 7. 关键不变量与坑

- **一个进程一个 AX observer，绝不按窗口订阅**：按窗口 observer 造成的孤儿 runloop source 曾让虚拟内存涨到 399GB（`AxObserverRegistry.swift:4-9`）；拆除时显式 `CFRunLoopRemoveSource`（:408-416）。
- **`kAXFocusedUIElementChanged` 永远不要订阅**：曾伤害 JetBrains 系、LibreOffice、MATLAB（`AxObserverRegistry.swift:322-323`）。
- **observer 必须在 `.commonModes` 安装且只装一次**：只在 default mode 会在滚动/菜单跟踪时丢通知（`AxObserverRegistry.swift:313-320`）。
- **只有「我们的」权限失效才是全局失败**：多个进程在权限正常时也会回 `-25211`，所以要 `AXIsProcessTrusted()` 复核，否则一次误判会让所有 app 的订阅都不再被尝试（`AxObserverRegistry.swift:688-706`）。
- **线程**：`observers`/`health` 只在 `axSemanticsThread` 上；回调里只做本地 `CFEqual`，任何 AX IPC 都交给 `AXCallScheduler`/`CGSCallScheduler`（`AxObserverRegistry.swift:17-19`, :438-456）。主线程镜像只读一个字位（`titleCapablePids`，:26-30）。
- **pid 复用**：`processExited` 必须校验代，否则会拆掉复用同一 pid 的新进程的 observer（`AxObserverRegistry.swift:175-183`）。
- **AX destroy 与 WS order-out 的关联是「一次性、按 wid」**：2 秒窗口，命中一次就消耗（`AxObserverHealth.swift:4-25`）。
- **`elementDestroyed` 不是死亡证明**：Chromium/Electron 会重建元素而窗口还在，判死要新 AX 列表 + WS 表面对账（`AxObserverRegistry.swift:504-520`）。
- **「读不到」≠「没有」**：`WindowElementAcquisition.Outcome.noAnswer` 与 `.absent` 分开，混用会把活窗口从切换器删掉（`WindowElementAcquisition.swift:11-22`）。
- **`isMinimized` 的 `true` 会过期**：Dock 还原时该位要到动画结束（~644ms）才清，还原应改由 order-in 推导（`WsWindowState.swift:60-67`）。
- **全量快照与被单点修改的先后**：`beginSnapshot()` 必须在查询离开主线程**之前**打戳，否则飞行中的定向修改会被旧答案覆盖（`WindowSurfaceInventory.swift:101-126`）。未发生全量扫描前 `visibleSurfaces` 返回 nil，不是空数组（:128-133）。
- **注意力写入只有两个来源**：attention 决策与结构性修补；类型系统用 `AttentionWriteSource` 标注（`TrackingTypes.swift:64-71`，`AttentionOrderSpecs.md:37-57`）。AltTab 自己的切换不算——顺序要等 OS 回报焦点后才动。
- **顺序比较只在一个进程内做**：跨进程不比较 `IngressSequence`，bounded read 携带的是**发出时**的序号（`AttentionModel.swift:59-69`，`AttentionDriver.swift:194-215`）。
- **Pro 的 Keychain 写入全有或全无**：任一写失败就回滚本次已写项，状态不进 `.pro`（`LicenseManager.swift:184-229`）。`setValue` 从不先删，避免对写失败但读正常的 keychain 毁掉已有授权（`Keychain.swift:38-45`）。
- **授权签名/TeamID/bundle id 必须稳定**：Keychain 项绑定代码签名，换签名会让所有用户的授权失效（`AGENTS.md` 的 License/Keychain invariant；实现见 `Keychain.swift:64-66` 用 `WhenUnlocked`、无访问控制）。
- **提示窗拒绝 Return**：`keyEquivalent = ""` 且 `ProPrimaryButton` 过滤 keyCode 36/76，防止残留按键触发购买（`ProPromptWindow.swift:4-21`, :52-58；`ProPromptPopover.swift:107-118`）。
- **提示窗口没有退路**：无关闭/最小化/缩放按钮，`cancelOperation` 空实现（`ProPromptWindow.swift:23-49`）。
- **取消过的历史读取不能复活**：`ProPromptPresentation` 用 generation + `isPending` 双重校验，2 秒兜底后也不允许晚到答案替换内容（`ProPromptPresentation.swift:23-44`）。
- **定时器用 wall clock**：`asyncAfter(wallDeadline:)`，睡眠期间不把试用终点往后推，醒来补火（`ProTransitionScheduler.swift:54-56`）。
- **状态只跟随时钟于 `refreshState()`**：`state` 不会自己过期，运行中要靠 `trialEndedSinceLastRefresh` 在可见工作之后刷新（`LicenseManager.swift:140-145`，`ProTransitionManager.swift:240-248`）。
- **恢复 remembered 值必须 `notify: false`**：否则锁仍生效时 `isProLocked && isStoredValuePro` 会把用户弹到 Upgrade 页（`ProTransitionState.swift:58-69`）。
- **`attemptUse()` 有副作用**：可能消耗免费体验或排队提示，所以 `SearchModeResolver` 明确要求不要在非用户动作路径反复调用（`src/switcher/state/SearchModeResolver.swift:9`）。
- **遥测只观察不决策**：Release 下所有入口编译为空，字段是封闭集合，没有位置能塞标题或按键（`TrackingTelemetry.swift:3-13`, :136-149；`TrackingTelemetryRecorder.swift:8-13`）。

## 8. 不确定 / 没读到的部分

- **808 的命名与语义有冲突**：枚举叫 `windowFocused`、映射到 `.noteFocusEvent`（`WsEventRouting.swift:16`, :28, :43），但 README 与规格说 808 是「order change, not focus」且不能移动 MRU（`windowserver/README.md:11-12`）；代码一律在 `AttentionDriver` 丢弃它（:178-188）。这个矛盾是注释层面的，我没有在真机上核实 808 到底表示什么。
- **`src/events/WindowServerEvents.swift` 只读了前 ~175 行**：`route()` 全部分支、`pruneSubscriptions`、Mission Control 抑制、以及 `subscribe` 的具体准入没核到。
- **模型与排序在范围外**：`WindowEventReducer`、`TrackedWindowState`、`Windows`、`Applications`、`TabGroups` 都在 `src/switcher/`，我只按接口引用（`TrackedWindowStateBridge.swift:25-43`），没有通读其规则。
- **`ProBadgeView.swift` 只读到渐变与 shine（1-60）**：`SegmentSymbol`/`SegmentOverlay`（:121-401）只看了函数名与测试文件名，未逐行。
- **`ProJourneyView.swift` 只读前 70 行**：四页签刷新、`ProComparisonView`/`ProJourneyCard`/`ProActivationPopover`（:275-417）未细读。
- **`Day4TourPopover`/`ProPromptHeader`/`ProGradientButton` 只读了结构**，未核对像素级约束与无障碍。
- **行数与任务给的规模不符**：实测 `windowserver/` 是 13 个文件 1262 行（含 README/Specs/Tests），不是 11 文件 0.9k；`pro/` 35 文件 6390 行、`window-tracking/` 27 文件 4595 行。
- **没有运行任何构建或测试**，所有结论来自源码与随附 Specs；涉及「实测毫秒数」的引用都是文件里的注释与规格，我未复测。
