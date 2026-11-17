# FEEL-33 全游戏运行审查与历史 BUG 修复

- 基线：FEEL-32
- 模式：CONTROLLED_WRITE
- 未导出 EXE、未打包、未覆盖 CloudBase/GitHub 公开 Web；`best.json` 未修改（MD5 `067DEB9A71A19C2F6F9F6DC41FEABF09`）。
- 本轮实际使用 Godot MCP（hybridindie/godot-mcp 2026.10.20.1，桥接 9081）和自动化测试，两者分开记录。

## 1. Godot MCP 实际使用记录

连接状态：

- `godot_health_check`：`bridge_connected=true`，addon 2026.10.20.1，项目 `D:/GAMESTUDIO/TURBBIT/`
- 启用工具集：`playtest,scripts`（runtime/input/input_map/testing/debugger/profiling/scripts）
- 编辑器 play 窗口；不是 headless。

实际操作：

| 操作 | 工具 | 结果 |
|---|---|---|
| 菜单 | `godot_runtime_play_scene(menu.tscn)` + screenshot | 菜单正常，4 个按钮，测试场入口可见 |
| 开场 | `godot_input_simulate_key(Enter)` | 进入 1/7 漫画 |
| 跳过漫画/进教学 | `Escape` | 教学 step1 正常 |
| 教学 SHIFT | `Shift` | 提示切换、主台词布局稳定；但发现教学里触发 MISCHIEF（见 §3） |
| 教学→比赛 | `K` | 正式比赛，RACE 0/55，时间开始走 |
| 比赛操作 | `Right` + `Space` | 赛程走到 2/55，HUD 出现海藻/晃动量 |
| 测试场 | `play_scene(test_arena)` + `find_ui_elements` + `simulate_mouse` | 点击“生成”成功生成 SURFACE_ROCK；滑条选到 SHARK6 后生成成功 |
| 运行场景树 | `godot_runtime_get_game_scene_tree` | 读到 Race/Turtle/Rabbit/MountController/HUD 等完整节点 |
| 游戏输出 | `godot_runtime_get_game_output` | 只有 LEVEL SEED / SNACK DRAW，无 error/warning |
| 性能 | `godot_profiling_get_performance_monitors` | 比赛 FPS 151、draw_calls 826、primitives 29460；菜单/测试场 FPS 165 |

MCP 截图证据（已归档）：

- `docs/reports/longrun/feel33/01-menu.png`
- `02-comic.png`
- `03-tutorial.png`
- `04-tutorial-after-shift.png`（修复前：乌龟翻肚皮 + 捣乱大字压在教学上）
- `05-arena-rock.png`
- `06-arena-shark6.png`
- `07-race-play.png`

MCP 限制（没有假装完成）：

- 项目里的 Turtle/Rabbit 是 `Node2D`，碰撞是 `get_body_rect()` + 自定义 rect 判定，不是 `PhysicsBody2D/CollisionShape2D`；MCP 场景树能确认没有物理体节点，碰撞一致性由 `stage31` 的逐类命中测试验证。信号流是 `GameManager` 的自定义 signal，既不在节点连接面板集中展示，也不在 MCP 的默认 inspection 输出里。
- MCP 驱动的是 **Godot 编辑器 play 会话**，不是 Web 浏览器；CloudBase/Web 的掉帧与清晰度没有用 MCP 验证。
- `godot_runtime_read_property` 在本项目测试中多次 `read_pending` 超时；因此运行时状态主要用场景树、截图和 profiling，而不是逐属性读取。
- `godot_debugger_get_stack_frames` / 局部变量在 Godot 4.7 不可用（工具本身标注 UNSUPPORTED）。
- 没有用 MCP 完成 55 组真人级完整跑图；这一项用自动驾驶长跑 + 真实窗口流程补足。

## 2. 历史 BUG 修复

### 2.1 MISCHIEF 概率偏差（FEEL-29 遗留，已确认）

- 原代码：`race.gd:3891` `randf() > 0.68` 走“取消”，实际动手率约 68–71%。
- 复现：`stage29_mischief_audit` 2000 样本/角色，修复前约 70%。
- 根因：概率分支反转。
- 修改：`race.gd:3896` 改为 `randf() > 0.32`，约 32% 动手；其余退回 `ignore=8`。
- 保留：2.6 s 抱怨窗口、冷却、SHIFT 中断、救援优先、340 px 安全距离。
- 修复后：

| 角色 | 启动数/样本 | 触发率 |
|---|---:|---:|
| 兔子 | 637/2000 | **31.85%** |
| 乌龟 | 626/2000 | **31.30%** |

- 状态检查：启动时 `complaint_role` 清空、进入 `TELEGRAPH`、`mischief_lock_role` 正确；取消时 `ignore=8`；2.6 s 抱怨窗口正确。
- 证据：`docs/reports/longrun/feel33-mischief-rate.json`

> 任务书写“700 px 安全距离”，当前代码与 FEEL-24 报告一直是 **340 px**。本轮没有把 340 改成 700——那是设计参数变更，不是这次的概率 BUG；需要 Producer 单独确认。

### 2.2 教学期间触发 MISCHIEF（本轮 MCP 新发现）

- 现象：教学 step1 停留约 10 s，乌龟翻肚皮，中央出现“开始拽绳子了……”并压住大表哥台词；教学变成惩罚局。
- 复现：MCP 启动 `tutorial.tscn`，只按一次 Shift，等待约 10 s；截图 `04-tutorial-after-shift.png`。
- 根因：教学只设了 `test_no_finish / test_no_coop_hint / test_no_lessons`，没有关闭 `_tick_ignore / _maybe_start_mischief`。
- 修改：
  - `race.gd:259` 新增 `test_no_mischief`；
  - `race.gd:3879` / `3986` 在抱怨累积和 MISCHIEF 入口直接返回；
  - `scripts/test/tutorial.gd:47` 教学设置 `race.test_no_mischief = true`。
- 验证：`stage33_tutorial_safety` 3/3 PASS（教学标志、无抱怨累积、无 MISCHIEF）。
- 证据：`docs/reports/longrun/feel33-tutorial-safety.json`

### 2.3 旧测试过时，不是 BUG

- `stage4_core_experience`：仍期待自动 combo/Showtime 和 ≥3.5 s 反应；这些机制已在 FEEL-24/28 取消/压缩。
- `stage4_shift_feel`：仍期待 HUD 文本 “TURTLE” 和旧同帧 leap 语义；英文角色名现为 BITT。
- `stage11_shift_relay` 的 `3_dive_to_jump_clever`：仍期待“切走后乌龟继续下潜”；该行为已在 FEEL-22 主动移除。
- `stage4_menu_input`：headless 下鼠标点击失败，窗口运行 PASS；是环境限制，不是游戏缺陷。

本轮没有为了这些旧断言恢复已取消的设计。

### 2.4 设计规则，不是 BUG

- SHIFT 晚 0.30 s + 提前量 140/160 px 仍会 `TURTLE_DIVE_LATE`；这是 FEEL-29/32 已确认的时序规则。
- CloudBase 默认测试域名强制风险提示；不是游戏 BUG。
- 灰盒剪影、无音效、测试场面板遮挡部分赛道：已知表现/工具限制。

## 3. 完整运行与回归

### 自动化

| 项目 | 结果 |
|---|---|
| `stage3_playtest` | 两圈 **55/55**，270.7 / 270.6 s，每圈 1 次事故，max_stuck 0.0 |
| `stage32_shark_timing` | 测试场 10/10 轮；Z3 时间轴 PASS；order `leader,fat,thin`；warn 0.95/0.95/1.05；safety 0.70/0.70；max_attacks=1 |
| `stage31_arena` | 25/25（窗口运行+鼠标）：8 类生成/碰撞、连续生成、清除、看台、介入、SHARK6 三只攻击、菜单/重启/返回、best 不变 |
| `stage21_shark_pack` | 10/10：T→R→T、瘦鲨仅下潜安全、救援清理、Z3 组/介入 |
| `stage22_coupling` | exit 0 |
| `stage15_oxygen_fail` / `stage15_mischief` | exit 0 |
| `stage19_bird_behavior` | exit 0 |
| `stage4_hud_score` | PASS，28/28 |
| `stage29_tutorial_layout` / `stage29_dive_handoff` | PASS / rows=18 bad=0 |
| `stage33_tutorial_safety` | 3/3 PASS |

### 真实窗口 / MCP

- 菜单→漫画→教学→比赛：MCP 实际走通（截图 01–04、07）。
- 测试场：MCP 鼠标点击生成 SURFACE_ROCK，滑条选 SHARK6 并生成；SHARK6 截图 06。
- 比赛按键：Right/Space 注入成功，赛程 2/55；FPS 151。
- 没有真人完整 55 组试玩。

## 4. 未解决 / 能力边界

1. **Web 掉帧与清晰度**没有本轮用 MCP 量到；MCP 只证明编辑器 play 窗口 151–165 FPS。需要 Edge/CDP 在 CloudBase 链接上单独 profiling。
2. 没有真人完整流程；教学、菜单、测试场是 MCP/窗口，55 组是自动驾驶。
3. MCP `read_property` 超时、4.7 栈帧不可用，限制了逐属性/逐帧调试。
4. MISCHIEF 的 340 px vs 任务书 700 px 参数不一致，未擅自改。
5. 测试场面板遮挡左侧赛道；仅测试工具。
6. 灰盒美术、音效缺失。
7. 项目里现在有 `addons/godot_mcp` 和 `MCPRuntimeProbe` autoload；正式交付前需要决定是否移除测试探针。

## 5. 下一阶段改进建议（按优先级）

### P0-1 首次 60 秒没有建立“双人管理”的核心感
- 当前问题：教学可跳过/可失败继续；第一个真正的双人障碍（高墙）在 x≈10000、约 40 s；55 组里只有 11 组真正需要两人。
- 证据：`stage3` 55/55 自动驾驶；MCP 教学截图；障碍表。
- 影响：新玩家前 40 秒体验的是单人跑酷，SHIFT 像换皮肤，不是核心幻想。
- 方向：把一组简化 BRO DIVE/高墙提前到 20 秒内；教学第三步强制一次真实接力，失败不进入下一段。
- 范围：1–2 天，不改关卡总数。

### P0-2 Web 首屏与运行性能
- 当前问题：MCP 桌面 151–165 FPS，但 CloudBase Web 仍被反馈掉帧/糊；尚未在 Web 上量 FPS。
- 证据：MCP profiling；CloudBase 实测 wasm 2.3 s 下载；用户反馈。
- 影响：链接打开第一分钟决定队友是否继续。
- 方向：固定/DPR 感知 canvas 分辨率、减少每帧 HUD 重建与绘制调用、Edge/CDP 在真实链接上量 FPS；必要时再评估多线程。
- 范围：2–3 天。

### P1-1 中段障碍答案重复
- 当前问题：7 类障碍对应 5 个答案；Z2/Z3 主要是速度/密度变化，缺少双解或叠加题。
- 证据：55 组分布；11/55 双人；stage3 全程自动驾驶答案稳定。
- 影响：学会 5 个答案后，中后段变成执行而不是判断；容易关掉。
- 方向：3–4 组双解障碍（同一障碍两种代价）、2 组强制跳→SHIFT→潜连招、动态障碍叠加。
- 范围：3–5 天。

### P1-2 失败与 SHIFT 压力的因果可见性
- 当前问题：落水/撞击/氧气/呛水主要靠文字和气泡；SHIFT 压力 2.6 s 抱怨 + 32% 概率，玩家可能仍觉得随机。
- 证据：MCP 教学里直接出现翻肚皮 + 中央大字；FEEL-29 概率偏差历史。
- 影响：失败不知道为什么，惩罚像随机税，不愿意再试。
- 方向：SHIFT 压力在触发前 1–2 s 做角色身上的物理预兆；事故在碰撞点显示原因图标；教学/菜单不用中央大字。
- 范围：1–2 天。

### P2-1 特殊音效缺失
- 当前问题：只有 SHIFT 程序化电击；鲨鱼三拍、BRO DIVE/OLLIE、捣乱、呛水都没有声音。
- 证据：MCP 运行无音频反馈；`shift_fx` 是唯一 AudioStreamGenerator。
- 影响：动作没有重量，Boss 没有压迫感，失败没有“疼”。
- 方向：先做 6–8 条特殊音效（SHIFT、鲨鱼三拍、DIVE 接住、OLLIE、翻肚皮、呛水），音乐后置。
- 范围：3–5 天。

### P2-2 测试债
- 当前问题：3 个旧测试仍按已取消机制断言，真实回归被假失败淹没。
- 证据：FEEL-33 §2.3。
- 方向：更新旧断言到当前设计；用 MCP 场景测试补菜单/教学/测试场的真实输入路径。
- 范围：1 天。

## 6. 新玩家最影响“好玩/愿意继续”的三个问题

1. **前 60 秒没让我感到“我在管两个人”。** 教学可以跳过，真正的双人障碍又出现得太晚；第一印象更像单人跑酷。
2. **学会 5 个答案后，中段开始重复。** 障碍数量多，但新的判断少；玩家会从“想再试一次”变成“再跑一遍”。
3. **失败和 SHIFT 压力的因果不够清楚。** 不知道为什么被撞、为什么另一个兄弟突然翻肚皮；没有声音和物理预兆时，惩罚像随机。

Web 首屏性能是第四个问题，但更像交付门槛；上面三个是决定“游戏本身好不好玩”的问题。

## 7. 停止

- 未导出 EXE、未打包、未覆盖公开 Web。
- 未新增玩法、未做美术/音效。
- 等待 Producer 审核。
