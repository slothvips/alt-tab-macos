# preferences / events 模块阅读笔记

> 只读分析，未构建、未跑测试。实测范围：`src/preferences/` 49 文件 11166 行（30 个源文件 9607 行），`src/events/` 31 文件 4710 行（23 个源文件 3518 行）；差额是 `*Tests.swift` / `*Specs.md`。行号以当前工作区为准。

## 1. 一句话职责

- **preferences/** —— 回答"一个偏好是什么、默认多少、怎么改、怎么迁移"：`Preferences` 把 `UserDefaults` 包成带缓存的类型化读写，`MacroPreferences` 定义所有枚举值，`PreferencesMigrations` 按版本改写历史数据，`settings-window/` 用纯代码（无 xib、无 SwiftUI）拼出设置窗口。
- **events/** —— 回答"系统发生了什么事"：把 Carbon 热键、CGEvent tap、SkyLight/WindowServer 通知、AX 观察者、NSWorkspace/分布式通知接起来，翻译成 `App.showUiOrCycleSelection` / `focusTarget` / `hideUi` 这类动作；可判定的部分抽成纯内核（`GestureTriggerKernel`、`ModifierReleaseLog`、`AxQueryRouting`、`CaptureDiscovery`）以便单测。

## 2. 目录与文件地图

### preferences/ 根目录（定义与持久化）

| 路径 | 行数 | 一句话 |
|---|---|---|
| `src/preferences/Preferences.swift` | 560 | 默认值总表 + 全部 getter/setter + `CachedUserDefaults` 缓存 + `ExceptionEntry` |
| `src/preferences/PreferenceDefinition.swift` | 159 | 单个 Pro 门禁偏好的读/降级/恢复；`ProGatedPreferences` 注册表 |
| `src/preferences/MacroPreferences.swift` | 434 | 所有下拉/单选枚举（`MacroPreference` 协议族）与本地化文案 |
| `src/preferences/PreferencesMigrations.swift` | 400 | 版本号驱动的迁移表，逐版本改键名与值编码 |
| `src/preferences/PreferencesPersistenceCheck.swift` | 104 | 启动期检测 plist 是符号链接/不可写并弹框 |
| `src/preferences/PreferencesPersistenceProbe.swift` | 64 | 上面那个检查的纯判定 |
| `src/preferences/ShortcutSymbolsTests.swift` | 29 | 符号键位解析回归测试（无同名实现文件） |

### preferences/settings-window/

| 路径 | 行数 | 一句话 |
|---|---|---|
| `SettingsWindow.swift` | 1375 | 窗口/侧栏/分区容器/搜索过滤/滚动选中同步 |
| `TableGroupView.swift` | 703 | 系统设置风格卡片分组、行、文本与分隔线工厂 |
| `LabelAndControl.swift` | 390 | 偏好键 → 控件的桥：建控件、读初值、统一回写 |
| `SettingsSearch.swift` | 306 | 模糊匹配打分（查询 token vs 文本 token） |
| `SidebarList.swift` | 334 | `[侧栏｜分隔线｜编辑器]` 骨架 + 行视图 + 滚动 hover 修正 |
| `SettingsSearchHighlight.swift` | 194 | 命中文本高亮 / 控件黄框 target |
| `SidebarListTests.swift` 等 4 个测试 | 50–123 | 纯逻辑测试 |
| `SettingsSearchIndex.swift` | 80 | 构建期 builder（push 式索引）+ sheet 静态可搜字符串 |
| `SettingsSectionSearchContent.swift` | 54 | 一个分区的 base + dynamic 可搜内容 |
| `EmailLineWrap.swift` | 99 | 升级按钮里邮箱文本的换行与缩字号 |
| `tabs/controls/ControlsTab.swift` | 1058 | Controls 分区协调者 + 全局快捷键注册表 `shortcuts` |
| `tabs/controls/ShortcutEditor.swift` | 790 | 单个被复用的快捷键编辑器（三个 pane 懒建） |
| `tabs/controls/NativeHotkeyResolver.swift` | 52 | 纯判定：要不要关掉系统 ⌘⇥ / ⌘⇧⇥ |
| `tabs/controls/OverrideClickResolver.swift` | 42 | 纯判定：override 控件点击 → skip / write |
| `tabs/controls/{ShortcutsWhenActiveSheet,AdditionalControlsSheet}.swift` | 74 / 47 | 两个懒建 sheet |
| `tabs/appearance/AppearanceTab.swift` | 702 | 外观分区 + 两个 sheet |
| `tabs/ExceptionsTab.swift` | 446 | 例外列表（应用级 hide/ignore） |
| `tabs/ExceptionEditorView.swift` | 393 | 右侧例外编辑器 |
| `tabs/GeneralTab.swift` | 143 | 登录项/菜单栏图标/语言/导入导出/重置 |
| `tabs/UpgradeTab.swift` | 341 | Pro 升级页，也是被 bounce 的目标 |
| `tabs/AboutTab.swift` / `AcknowledgmentsTab.swift` | 144 / 38 | 静态文本页 |

### events/

| 路径 | 行数 | 一句话 |
|---|---|---|
| `KeyboardEvents.swift` | 290 | Carbon 热键注册 + 两个 CGEvent tap（session 被动 / Esc 吸收） |
| `KeyboardEventsTestable.swift` | 112 | `handleKeyboardEvent`：把三种输入源收敛成一个判定入口 |
| `ModifierReleaseLog.swift` | 170 | 记录物理 key-down 顺序，配对延迟到达的 Carbon 热键 |
| `PreferencesEvents.swift` | 82 | 偏好变更的副作用分发（自称过渡脚手架） |
| `WindowServerEvents.swift` | 410 | SkyLight 通知流 → reducer；`wsWindows` 订阅集 |
| `TrackpadEvents.swift` | 306 | 手势：被动检测 tap + 按需吸收 tap；`NavigationSwipeDetector` |
| `GestureTriggerKernel.swift` | 243 | 手势触发纯状态机 + `GestureTracker` |
| `CursorEvents.swift` | 209 | 鼠标 tap：点击/hover/中键关窗/指针死区 |
| `ScrollwheelEvents.swift` | 41 | 会话内吞掉连续滚轮，放行鼠标滚轮 |
| `WindowAttentionEvents.swift` | 186 | type-13 `CGSEvent` 预言"刚点了哪个窗口" |
| `WindowCaptureEvents.swift` | 495 | ScreenCaptureKit 截图（不是监听，但住在 events/） |
| `CaptureDiscovery.swift` | 62 | 有界、带优先级的待发现请求队列 |
| `AxQueryRouting.swift` | 30 | 纯判定：AX 查询进哪条池 |
| `{ContextMenu,Dock,InputSource,Screens,ScreenLock,SleepWake,SystemAppearance,SystemScrollerStyle,RunningApplications}Events.swift` | 14–47 各 | 系统通知/观察者 → 单个动作 |
| `CliEvents.swift` | 622 | CFMessagePort 上的 CLI 服务端（不属于事件循环语义） |

## 3. 核心类型与关系

**偏好定义体系**（值只在 `UserDefaults` 里存一个整数/字符串，枚举由 `allCases` 下标还原）：

```
MacroPreferences.swift   枚举 + localizedString（index 即存储值）
        │
Preferences.defaultValues ──register(defaults:)──► UserDefaults 注册域
        │                                              │ standard.string(forKey:)
        │                                    CachedUserDefaults（每键缓存，NSNull 表示 nil）
        │                                              │
        └── ownedKeys / all（persistentDomain 过滤快照）◄┘
                                    │
                     Preferences.<key> 静态 getter
                                    │
              ProGatedPreferences ──► PreferenceDefinition.read()（锁定时返回 free 值）
```

几个结构点：
- `MacroPreference` 协议只有 `localizedString`（`MacroPreferences.swift:410-420`），派生协议 `SfSymbolMacroPreference` / `ImageMacroPreference` 分别给单选按钮提供图标。
- `PreferenceDefinition<T>` 是"一个 Pro 门禁偏好"的唯一声明：键、free 值、remembered key、判定函数（`PreferenceDefinition.swift:7-18`）。读取时三分支：免费体验期读 remembered、锁定后仍存 Pro 值则给 free、否则读存储值（`29-41`）。
- `Preferences.all` 是 `persistentDomain` 的**过滤快照**（只留 `ownedKeys`），专供"用户是否显式设置过"（`Preferences.swift:241-247`）。

**设置界面生成方式**：分区声明 → 构建期索引 → 控件工厂 → 搜索内容。

```
SettingsWindow.sectionDefinitions()            // 4 个 id → builder 闭包
  └─ addSection(definition)
       └─ SettingsSearchIndex.indexed { builder() }      // 开一个 builder
            └─ AppearanceTab / ControlsTab / GeneralTab / ExceptionsTab.initTab()
                 └─ LabelAndControl.makeDropdown / makeRadioButtons / makeSwitch
                    TableGroupView.makeText / Row
                      ├─ 读 CachedUserDefaults 初值
                      ├─ setupControl(onAction:)            // 唯一回写入口
                      └─ registerString / registerTarget    // 搜索索引
       └─ collectSearchContent(视图树，兜底) + builder 结果 → SettingsSectionSearchContent
```

**事件监听体系**（输入源 → 统一判定 → 动作）：

```
Carbon RegisterEventHotKey ────┐
cgSession tap .flagsChanged ───┤
NSEvent local monitor ─────────┼─► handleKeyboardEvent(globalId | keyCode | modifiers, …)
cghid tap (Esc, 按需启用) ─────┘        └─ triggerMatchingShortcuts → ControlsTab.shortcuts[id].executeAction

cghid gesture taps ──────────────► GestureTriggerKernel → App.showUiOrCycleSelection
SkyLight notify procs ───────────► WsEventIngress → TrackedWindowStateBridge.dispatch
NSWorkspace / DistributedNC / AXObserver ─► 各 *Events 类 → 单个 App/Model 调用
```

## 4. 端到端数据流

### a) 用户改一个偏好到生效并持久化

1. 控件由 `LabelAndControl.setupControl` 装配，`onAction` 统一指向 `controlWasChanged`（`LabelAndControl.swift:306-313`）。
2. 点击 → `controlWasChanged`：快捷键走 `Preferences.setShortcut`，其余读值后与旧值比对、相同就 return（`315-334`）；值格式由 `getControlValue` 归一（下拉存 index、滑杆取整、按钮存 on/off）（`358-374`）。
3. `Preferences.set` → `write(key, notify)`（`Preferences.swift:213-215, 224-231`）：先 `UserDefaults.set`，再清 `CachedUserDefaults` 该键、清 `cachedAll`，最后 `PreferencesEvents.preferenceChanged(key)`。
4. 分发：`PreferencesEvents.preferenceChanged` 先处理 Pro 反弹（存的是 Pro 值且已锁 → `UpgradeTab.navigateToUpgradeTab`）、取消搜索发现提示、转 `ControlsTab.preferenceChanged`，再按 key 分支（`PreferencesEvents.swift:53-76`）。
5. 生效：需要重建 UI 的键（`appearanceStyle/Size/Theme`、`showOnScreen`、override 键、每快捷键分组键）走 `App.resetPreferencesDependentComponents` → `TilesView.reset()`（`App.swift:50-53`）；菜单栏图标走 `Menubar.menubarIconCallback`；手势走 `TrackpadEvents.toggle`（`69-73`）。
6. 快捷键另有一条链：`ControlsTab.preferenceChanged` → `applyShortcutPreference` → `addShortcut` → `KeyboardEvents.addGlobalShortcut`（Carbon 重注册）→ `toggleNativeCommandTabIfNeeded`（`ControlsTab.swift:175-213, 722-751, 933-950`）。
7. 持久化本身由 cfprefsd 完成；写入失败是静默的，所以启动期有 `PreferencesPersistenceCheck.runInBackground()`（`App.swift:641`，探测逻辑 `PreferencesPersistenceCheck.swift:20-45`）。

### b) 一次全局键按下到事件被派发

1. 注册：`RegisterEventHotKey(key, mods, hotkeyId, GetEventDispatcherTarget(), …)`，签名 `"altt"`，id 约定 `nextWindowShortcutN → N`、`holdShortcutN → 9+N`（`KeyboardEvents.swift:188-204`；`KeyboardEventsTestable.swift:5-10`）。
2. 系统在主线程投递 `kEventHotKeyPressed`，handler 取出 `EventHotKeyID.id`（`KeyboardEvents.swift:257-267`）。
3. 先尝试认领"物理按下记录"：`claimRecordedRelease(globalId)`（`99-106`）→ `ModifierReleaseLog.claimRelease`，用被动 tap 记下的 key-down 顺序判断"hold 修饰键是否在这次按下之后才松开"（`ModifierReleaseLog.swift:116-138`）。
4. `handleKeyboardEvent`：先让搜索框吃掉编辑键；再 `triggerMatchingShortcuts` 遍历 `ControlsTab.shortcuts`（`KeyboardEventsTestable.swift:36-54, 91-112`）。
5. `ATShortcut.matches` + `shouldTrigger` 通过 → `executeAction(isARepeat)`；`holdShortcut*` 例外（不复位 pass-through）。
6. 修饰键松开：被动 `cgSession` tap 收到 `.flagsChanged` → `ModifierReleaseLog.record` 后 hop 到 main 调同一入口（`KeyboardEvents.swift:30-38`）。
7. 面板内的普通按键：`NSEvent.addLocalMonitorForEvents([.keyDown,.keyUp])`，返回值决定是否吞掉事件（`207-217`）。
8. 全局路径的 key-up：Carbon `kEventHotKeyReleased`（`269-277`）。Esc 例外由单独的 `cghid` 吸收 tap 提前抢走（`56-83`）。

## 5. 对外边界

**preferences 依赖**：`ShortcutRecorder`（`Shortcut` 模型与存档，`Preferences.swift:404-425`）、`LicenseManager`/`ProTransitionManager`/`ProTransitionState`（Pro 门禁，`PreferenceDefinition.swift:31-34`）、`App.bundleIdentifier`/`App.version`（域与迁移版本）、`CGSymbolicHotKey`（`NativeHotkeyResolver`）。

**谁依赖 preferences**：几乎全仓。典型：`switcher/ATShortcut.swift:45,69,101`、`TilesView.swift:257`、`SearchDiscoveryHint.swift:237`、`TileView.swift:216`、`UsageStats.swift:44`、`Menubar.swift:57`、`pro/scheduling/ProTransitionState.swift:51,63`。**先把 `Preferences.initialize()` 的时序读清楚，再读其它模块**（`App.swift:616-623`）。

**events 依赖**：Carbon HIToolbox、`CGEvent`/`CGEventTap`、SkyLight（`SLSRegisterConnectionNotifyProc` 等）、AX（`AXCallScheduler`、`AXObserverRegistry`）、`BackgroundWork` 的 runloop 线程、`SwitcherSession`/`TilesPanel`/`Windows`/`Applications` 模型。

**谁依赖 events**：`App.swift` 是唯一装配入口（`530-563`：`CursorEvents.observe`、`TrackpadEvents.observe`、`WindowAttentionEvents.observe`、`CliEvents.observe`、`PreferencesEvents.initialize`；`639` 的 `WindowServerEvents.observe` 在许可证/权限门之前）。`App.swift:101-118` 在隐藏路径上反向调用 `TrackpadEvents.reset` 与 `KeyboardEvents.updateEscapeAbsorptionTap`。注意存在 `events → preferences/settings-window` 的回边：`KeyboardEvents` 读 `ControlsTab.shortcuts`，`PreferencesEvents` 调 `ControlsTab`/`UpgradeTab`（见 `PreferencesEvents.swift:43,62-73`）。

## 6. 推荐阅读顺序

1. **持久化底座**：`Preferences.swift:89-160`（getter）+ `213-251`（写与两份缓存）+ `442-528`（`CachedUserDefaults`）。读完能答：为什么读写偏好是 IPC、为什么每键都要缓存、`NSNull` 干什么用。
2. **定义与门禁**：`MacroPreferences.swift:408-434` + `PreferenceDefinition.swift` 全文。读完能答：加一个新下拉要动哪几处、Pro 锁定后读到的为什么不是存储值。
3. **变更如何落地**：`PreferencesEvents.swift` 全文 + `ControlsTab.swift:110-213, 722-780, 933-950`。读完能答：改一个偏好最多会触发哪几条副作用、快捷键为什么改完立刻生效。
4. **设置界面生成**：`SettingsWindow.swift:579-700` + `LabelAndControl.swift:173-374` + `SettingsSearchIndex.swift` + `SettingsSectionSearchContent.swift`。读完能答：一个新分区/新行要写什么、搜索索引为什么有 base 与 dynamic 两份。
5. **事件层**：`KeyboardEventsTestable.swift:36-112` → `KeyboardEvents.swift` → `ModifierReleaseLog.swift` → `TrackpadEvents.swift` + `GestureTriggerKernel.swift` → `WindowServerEvents.swift`。读完能答：一次按键或手势怎么变成动作、tap 为什么分被动/主动。

## 7. 关键不变量与坑

1. **所有写入必须经 `Preferences.write`**：写 store → 清 `CachedUserDefaults` 键 → 清 `cachedAll` → 通知（`Preferences.swift:221-231`）。绕过者要自己补缓存失效，样例是 `ControlsTab.swift:599-611` 与 `GeneralTab.swift:101-104`；漏一处，读方就永久拿到旧值。
2. **未注册的键会直接崩**：`getThenConvertOrReset` 对 `string(forKey:)!` 强解包（`Preferences.swift:508-523`），所以 `Preferences.initialize()` 必须早于任何读（`App.swift:616-623` 有注释解释这个顺序为什么不能动）。
3. **迁移只在 plist 版本 ≤ 当前版本且 ≠ `"#VERSION#"` 时执行**，之后无条件把 `App.version` 写回（`PreferencesMigrations.swift:17-27, 68-71`）。降级跑一次就会永久跳过中间迁移，且 `"#VERSION#"` 是开发构建的"永不迁移"标记。
4. **迁移表顺序有意义**：快捷键"字符串 → 存档结构体"必须排在最后（`PreferencesMigrations.swift:59-60, 100-106`），因为前面的迁移还把它当字符串读。新增迁移时插错位置比漏写更危险。
5. **解码失败会被静默重置为默认**：`CachedUserDefaults.shortcut` 解不出就 `removeObject`（`Preferences.swift:469-484`，`484` 的递归重读）。所以 `ExceptionEntry` 写了宽容 decoder 兼容旧的单字符串形状（`530-560`）；新增 Codable 偏好必须考虑失败的代价。
6. **键名后缀规则**：index 0 无后缀（`indexToName`，`Preferences.swift:431-433`），手势固定占 `gestureIndex = maxShortcutCount = 9` → 存成 `…10`（`148-154`）。手拼字符串迟早错，尤其 `showTabsAsWindows` 的 Bool→index 迁移依赖 `GroupTabsPreference` 顺序不变（`MacroPreferences.swift:255-269`）。
7. **`hasOverride` 读 `persistentDomain` 而不是注册默认值**（`Preferences.swift:278-280`）；否则"没设置过"会看起来像"已设置"。`all` 还过滤 `ownedKeys`（`241-247`），导入设置时同样用它白名单（`GeneralTab.swift:101`）。
8. **override 的 index 0 有三项走 Pro 门禁**（`Preferences.swift:314-340` + `PreferenceDefinition.swift:119-142`）；`removeOverride` 还要清 remembered key，否则解锁流程会把它重建出来（`Preferences.swift:285-301`）。
9. **快捷键冲突会真的清掉别人**：开方向键/Vim 键时先查冲突，有窗口就弹框确认，无窗口（启动期）宁可把自己关掉（`ControlsTab.swift:813-829, 975-1015`）；冲突标签从模型解析、不依赖当前编辑器里有没有那个控件（`873-880`）。同一 id 在 `ControlsTab.shortcuts` 里注册前必先 `removeShortcutIfExists`（`722-731`）。
10. **热键 id 有两套编号，靠前缀分流**：`nextWindowShortcutN → N`、`holdShortcutN → 9+N`（`KeyboardEventsTestable.swift:5-10`）；`ControlsTab.shortcuts` 的键是完整 controlId。改编号规则会同时影响 Carbon 回调反查与 `ModifierReleaseLog` 的 chord 集合（`KeyboardEvents.swift:99-119`）。
11. **Esc 吸收 tap 默认关闭**，只在"会话中 + 有快捷键绑 Esc"时启用（`KeyboardEvents.swift:239-249, 156-165`；由 `ControlsTab.recomputeEscapeAbsorption` 写 `anyShortcutUsesEscape`，`ControlsTab.swift:735-738`）。常开会破坏第三方输入法（#5766），这是刻意的取舍。
12. **tap 会被系统关掉，必须能自愈**：两条 tap 的 `tapDisabledByTimeout/ByUserInput` 分支各自重启用（`KeyboardEvents.swift:47-50, 141-150`；`TrackpadEvents.swift:116-135`），唤醒与解锁再统一扫一遍（`SleepWakeEvents.swift:26-29`、`ScreenLockEvents.swift:37-38`）。改 tap 代码时这条最容易被删。
13. **SkyLight 的 per-window 订阅是"替换"不是"追加"**：每次必须发全集，否则只剩一个窗口在被监听（`WindowServerEvents.swift:338-351` 有实测数字）；从 `wsWindows` 里删除即退订（`366-380`）；`pruneSubscriptions` 必须保留仍在模型里的 wid（`392-398`）。
14. **手势两个 tap 的创建顺序反直觉**：检测 tap 后创建却先运行，因为同一位置后者先跑（`TrackpadEvents.swift:71-99`）；检测 tap 必须 `listenOnly`，否则光标延迟被本进程 gate（#5911，`5-11`）。吸收 tap 只在手指数量够或会话中才 enable（`104-109, 155-159`）。
15. **跨线程纪律**：所有 tap 回调只读整数、然后 hop 到 main 再碰模型（`KeyboardEvents.swift:30-38, 67-69`；`WindowServerEvents.swift:83-123`）；`TrackpadEvents.reset` 反向 hop 回 tap 线程，因为它的状态归那条线程（`59-69`）。
16. **设置的搜索索引有两套来源**：构建期 builder（`SettingsSearchIndex.indexed`，`36-43`）+ 运行期重建的行（`refreshSectionSearchContent`，`SettingsWindow.swift:680-688`）。重建行后不刷新 → 靶点指向已销毁的控件，症状是"搜 sho 不再高亮 Shortcut 1"（`SettingsSectionSearchContent.swift:1-20` 记录了这个 bug）。

## 8. 不确定 / 没读到

- 只读了头部或结构、未逐行：`ShortcutEditor.swift`(790)、`AppearanceTab.swift`(702)、`ExceptionEditorView.swift`(393)、`UpgradeTab.swift`(341)、`TableGroupView.swift` 400–703、`SidebarList.swift` 后半、`CliEvents.swift` 的 `CliServer`/`CliClient`。
- `WindowAttentionEvents` 的 CGS 字段号（40/51/50/83）与"type-13 只覆盖跨应用点击"来自文件内注释自述，未在系统头文件或实测日志中核实。
- `ControlsTab.defaultShortcuts` 只在测试里被引用（`pro/ui/ProPromptFlowTests.swift:119`、`kit/CustomRecorderControlTests.swift:9`），本次没找到生产定义位置（可能在测试支持文件里）——不确定。
- `PreferencesPersistenceProbe.verdict` 的判定细节只看了调用点（`PreferencesPersistenceCheck.swift:23`），未逐行读。
- 任务描述给的 39/27 文件与实测 49/31 不一致，估计统计时排除了 `*Tests.swift`/`*Specs.md` 之外还排除了别的分类，未深究。
- 本轮没有构建、没有跑测试，所有"会不会编译/会不会挂"的判断都只是读代码得出的。
