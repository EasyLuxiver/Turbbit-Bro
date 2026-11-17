# TBB-FEEL-16 整体体验打磨与交付准备

- 日期：2026-11-14
- 阶段：`STAGE=4`
- 目标：从功能开发转入完整体验检查、细化、整合准备与交付检查；不新增角色/按键/资源条/关卡/障碍/独立玩法。
- 结论：**已修复本轮发现的 P1/P2 可修问题，产出最终候选包（FEEL-16）和美术/音频整合清单。仍有人工试玩、氧气失败可达性决策、正式美术/音频三项未闭环，不能宣布内容冻结或游戏完成。**

## 1. 整体体验审计

检查路径：首次启动 → 主菜单 → 开场 7 格 → 教学 4 步 → 正式比赛（Z1/Z2/Z3）→ SHIFT → MISCHIEF → 救援/自动恢复 → 氧气 → 失败 → 终点 → 成绩 → Retry。

### 方法

- 实际窗口运行：1600×900、1920×1080、全屏 2560×1600。
- 真实场景流程：`stage11_story_flow`、`stage3_playtest` 两圈、`stage4_flow`、`stage4_menu_input`、`stage15_fail_flow`。
- 逐张查看截图：菜单、开场 7 格、教学 step1/2/3/fail、Z1/Z3、浮标、MISCHIEF 双向、SHOWTIME+SHIFT、氧气水下、失败、终点。
- 自动跑圈只作为流程/判定证据，不作为趣味性结论。

### 发现

| 级别 | 问题 | 证据 | 处理 |
|---|---|---|---|
| P0 | 无 | 两圈 55/55、0 事故；正式菜单/Retry/失败场景均可进入 | — |
| P1 | 暂停帮助仍写“BRO METER 满会让当前角色电流过载”，与 FEEL-15 的“未受控角色 MISCHIEF”不一致 | 旧 `pause.help_body` | **已修复**：改为“满会让未被控制的兄弟捣乱”；中英同步 |
| P1 | 失败画面底部 `R / ENTER 重开 · M 主菜单` 与下沉 TUBO 重叠，情绪画面被文字压住 | `screenshots/feel15-fail-1920.png` 旧版 | **已修复**：TUBO 移到左下、BITT 移到右上；重拍见 `screenshots/feel16-fail-1920.png` |
| P1 | 失败场景同时处理 R/M 与 GameManager 全局 R/M，可能一帧触发两次重开 | `fail.gd` 与 `game_manager._unhandled_input` | **已修复**：失败场景只补 ENTER，R/M 交给全局 |
| P2 | `stage4_hud_score` 仍断言旧结算“救援成功/翻船数”，与 FEEL-12 后的四行结算不符 | 测试失败 5 项 | **已修复**：改为当前时间/失误/干净通过/BRO COMBO，并豁免键帽固定小字号；41 checks PASS |
| P2 | 正式比赛没有音频，所有碰撞/救援/氧气/SHOWTIME 无声音 | 全项目无音频资源 | **未修复**：列入音频整合清单，需素材 |
| P2 | 正式角色仍是原生形状；`art_test/feel13` 拆件只是技术样，未接正式比赛 | `art_test/feel13` | **未修复**：列入美术整合清单，需正式素材/制作人批准 |
| P2 | 氧气失败在正常“自动恢复”下几乎不可达：满氧 8 s，自动恢复 4.58 s，且自动恢复总会发生 | `stage15_oxygen_fail`、`_rescue_auto` | **未修复**：这是任务内两项要求的冲突，需要制作人决定失败条件（见第 4 节） |
| P3 | 失败/终点文案仍以“训练完成”为标题；终点画面已经是终点舞台 | `result.title` | 保留：避免破坏现有双语/回归；是否改成“抵达终点”由制作人定 |

### 场景衔接

- 菜单 → 开场 → 教学 → 比赛：`stage11_story_flow` 4/4；正式流程无断点。
- 比赛 → 结算：`stage3_playtest` 两圈均到达 result；Retry 从结算 R 进入。
- 氧气耗尽 → 失败：`stage15_fail_flow` 3/3，`FAILED` → `fail.tscn` → R → `race.tscn`。
- 失败/结算均不写 best；`best.json` 前后 MD5 一致。

## 2. 核心玩法质量检查

### SHIFT

- 有明确价值：低梁/岩/鸟需要换到 TUBO；鲨鱼/闸门需要 BITT；浮木/高墙必须两段配合。
- SHOWTIME 中 SHIFT 只换控制，不取消 TUBO 的表演；`stage15_showtime_shift` 9/9。
- 原“换手后角色继续失控”的残留已被 FEEL-15 的 MISCHIEF 状态机处理：SHIFT 当帧取消旧角色动作。

### BRO MISCHIEF

- 触发：未被控制角色惩罚条满；有 0.45 s 前摇、0.70 s 动作、0.22 s 收尾、1.8 s 冷却。
- 双向：BITT 电 TUBO；TUBO 拽绳让 BITT 减速。两者都不锁跳跃/下潜/SHIFT。
- 公平性：前摇有文字/中心提示；动作只施加一次；结束后惩罚条清零；SHIFT 可中断并由新未受控角色接管。
- 仍需人判断：4.58 s 事件是否太长/太短、0.45 s 前摇是否够读、1.8 s 冷却是否合适。

### 主动救援 / 自动恢复 / 氧气

- 主动救援有操作价值：必须 SHIFT 到 BITT、按 SPACE、实际接近/下潜/接住；11/11 矩阵。
- 自动恢复是兜底，明显更慢（4.58 s），有闪白和“下次按 SPACE 更快”的反馈。
- 氧气只在 TUBO 水下显示/消耗；正常骑乘隐藏。
- **未解决**：满氧 8 s、自动恢复 4.58 s 且必定发生，导致“氧气耗尽失败”在正常流程中几乎不可达。需要制作人选择：
  1. 失败条件改为“玩家主动下潜过深/在水下停留超过阈值”；
  2. 自动恢复延迟到氧气耗尽之后（与本轮“自动在耗尽前”要求冲突）；
  3. 保留当前作为极端/测试路径，不作为常规失败。
  本轮没有擅自改数值。

### 55 组节奏

- 两圈 55/55、0 事故；全量 audit 55/55 设计答案正确、no_solution=[]。
- 动态浮标/木箱只做减速反馈，不升级事故；两圈自动跑圈仍 0 事故。
- 普通路线可完成；技巧路线仍有 SHOWTIME/OVERDRIVE/精准通过表现空间。
- 仍需真人判断疲劳/重复：尤其 Z3 最后 13 组、MISCHIEF 事件频率。

## 3. 已修复问题与验证

### 3.1 暂停帮助文案

- 文件：`scripts/autoload/locale.gd`。
- 改为：
  - 中：`TUBO 头顶三颗气泡是氧气；BRO METER 满会让未被控制的兄弟捣乱`
  - 英：`THREE BUBBLES OVER TUBO ARE AIR; A FULL BRO METER MAKES THE UNCONTROLLED BRO CAUSE TROUBLE`
- 验证：`stage4_bilingual` PASS；暂停页文案读取通过。

### 3.2 失败画面布局

- 文件：`scripts/fail.gd`。
- TUBO 从画面中央移到左下 `0.16/0.78`；BITT 从标题后方移到右上 `0.84/0.30`；提示文字不再压住角色。
- 验证：`screenshots/feel16-fail-1920.png`；`stage15_fail_flow` 3/3。

### 3.3 失败场景重复输入

- 文件：`scripts/fail.gd`。
- 去掉本地 R/M，保留 ENTER；R/M 由 GameManager 全局处理，避免同一按键触发两次 `start_race`/`go_to_menu`。
- 验证：fail 场景冒烟；`stage15_fail_flow` PASS。

### 3.4 测试与旧断言

- `stage4_hud_score`：更新到 FEEL-12 后的四行结算；键帽固定小字号不参与正文最小字号；41 checks PASS。
- `stage12_skills`：护盾移除后的 9 项断言；PASS。
- `stage4_bro_meter`：FEEL-15 MISCHIEF 语义；PASS。

## 4. 尚未解决的问题

1. **氧气失败可达性**：满氧 8 s、自动恢复 4.58 s，正常流程中自动恢复先发生，氧气耗尽失败几乎只能由测试强制触发。需要制作人定失败条件，不能靠改一个数同时满足“自动在耗尽前”和“耗尽必须失败”。
2. **真人趣味性未验证**：两圈自动 55/55 不能说明好玩；MISCHIEF 频率、救援手感、浮标反馈、终点情绪都需制作人试玩。
3. **正式美术未接入**：角色/场景/UI 仍是原生占位；`art_test/feel13` 拆件技术样不接正式比赛。
4. **音频完全缺失**：无 BGM/SFX；美术/音频清单已给出触发点，但未制作素材。
5. **干净环境未验证**：导出包在本机启动通过；未在另一台无 Godot 的机器/新用户目录验证。
6. **MISCHIEF 满格可见性**：HUD 只显示当前主控角色的惩罚条；未受控满格角色在事件开始前没有持续可视化提示（只有满格信号/事件前摇）。是否需要双条显示，需制作人决定。

## 5. 美术 / 音频整合清单

见：[FEEL-16-ART-AUDIO-INTEGRATION.md](../../delivery/FEEL-16-ART-AUDIO-INTEGRATION.md)

- 包含角色部件命名、透明/pivot/尺寸要求、19 个动画状态到代码状态的映射、SFX 触发点、BGM 区域/情绪、导入格式和验收方式。
- 现有资源只标“占位/技术样”，没有冒充最终素材。

## 6. 交付质量检查

### 1920 / 全屏

- 菜单：`screenshots/feel14-menu-window/1920/fullscreen.png` 三种启动画面。
- 比赛 HUD：1920/全屏实际截图（FEEL-14 和本轮回归）。
- 氧气：`feel15/oxygen-1920-*` 与 `*-fullscreen.png`，3/2/1/0 全对。
- 失败：`screenshots/feel16-fail-1920.png`。
- 终点：`screenshots/feel15-result-B-1920.png`。

### 菜单 / 语言 / 输入 / 暂停 / 退出

- 主菜单只有开始/设置/退出；`stage4_menu_input` 窗口化 PASS。
- 双语：`stage4_bilingual` PASS；结果页四行仍正常。
- 暂停/帮助：文案已修正；`stage4_flow` PASS。
- 退出：二次确认路径未改。

### 成绩 / 重开

- `best.json` MD5 前后一致：`067DEB9A71A19C2F6F9F6DC41FEABF09`。
- 两圈跑圈通过 Retry 进入第二圈；失败场景 R/ENTER 回 race。
- 失败/结算均不写 best。

### 资源加载 / 异常 / 性能

- 正式场景无脚本/资源加载错误；导出包 `--headless --quit` 退出 0。
- `stage8_hz_regression` PASS（30/60/120）。
- 未做独立性能基准；无新增每帧重资源分配（MISCHIEF 只在事件期间画少量线/弧）。

### 正式导出包

- 路径：`build/FEEL-16/TurbbitBro.exe`（106 MiB）
- SHA-256：`5cd1c107ce2d977ccbc9fa6f1b013ed182b8edc8d456c2bf0a1030bba8753c9f`
- 包含：menu/opening_comic/tutorial/race/result/fail；排除 stage/test 场景。
- 同机启动通过；未在干净机器验证。

## 7. 完整流程验证

- 开场→菜单→教学→正式比赛：`stage11_story_flow` 4/4。
- 正式比赛两圈：run1/run2 **55/55、0 事故**；`STAGE3 PLAYTEST: PASS`。
- Retry：第二圈从 result Retry 进入。
- 失败→重开：`stage15_fail_flow` 3/3。
- 菜单输入/结算/双语：`stage4_menu_input`、`stage4_flow`、`stage4_bilingual` PASS。
- 关键玩法：SHOWTIME 9/9、动态浮标 6/6、救援 11/11、氧气/自动恢复 9/9、MISCHIEF 13/13、OVERDRIVE 15/15、relay 10/10。

## 8. 距离正式交付还差什么

1. 制作人实际试玩并给出“有趣/有保留/不有趣”结论。
2. 决定氧气失败条件，解决“自动恢复必先发生”与“氧气耗尽必须失败”的冲突。
3. 正式角色/场景/UI 美术接入（当前全是原生占位）。
4. BGM/SFX 制作与接入（当前完全静音）。
5. 干净机器/干净用户目录启动验证。
6. 制作人决定是否把结果页标题从“训练完成”改为“抵达终点”。

**本轮停止。不宣布内容冻结，不自行宣布游戏完成；最终候选版本等待制作人验收。**
