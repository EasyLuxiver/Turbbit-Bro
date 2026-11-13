# REFINE-06 P1：双角色状态 HUD 与动态平衡测试场景

日期：2026-11-13 · 阶段：STAGE=4 · 状态：P1 完成（证据见下），P2–P6 未开始

## 1. 目标

制作人两条要求：

1. 重做双角色状态 HUD：一眼分清兔子 / 乌龟、当前控制谁、伙伴在恶化到哪一档；
   不用倒计时施压，不新增状态等级。
2. 建一个可重复运行的动态平衡测试场景：覆盖连续兔子专属、连续乌龟专属、交替、
   伙伴失控中组合、高压力后恢复五类，并逐帧记录状态变化、当前控制、SHIFT 与恢复
   时间、进障碍时双方状态、碰撞原因、以及是否存在无解组合。

补充指令（`MISSION-REFINE-06-SUPPLEMENT.md`）同时约束：动态平衡是核心 SHIFT 机制，
不改成无风险自动跟随，不自动清空失常、不让伙伴免疫；只调累积/效果/恢复/顶端后果/间距。

## 2. 改了什么

只动 UI 与测试工具，不动判定、分数、`best.json`、美术/字体/音效：

- `scripts/ui/role_glyph.gd`（新增）：原生 `_draw` 画兔子（头+两耳）与乌龟（壳+头）。
  等级越高图形越大（每级 +12%），颜色白青→琥珀→橙→红，最高级轻微脉动；
  受控角色外套金色弧。
- `scripts/ui/hud.gd`：左上改成两行角色行——图形 + 名称 + “操控/待命” + 分档文案
  （稳定 / 开始神游 / 坐不住了 / 要惹麻烦）；当前控制有 `▶` 箭头 + 金色 glyph 环；
  神游条按 `drift/12` 填充并按档位换色。没有倒计时数字。
- `scripts/race.gd`：世界内的神游标记从“孤零零的 ?”改为“角色图形 + ?/!?/!”，
  并加深色半透明“想法泡”底。白图形直接压在浅色天空/水面和背景装饰上几乎看不见
  （首版截图要放大 10 倍才分得清，还和背景鱼糊在一起）。
- 反馈沿用既有文本：换手时 `换手 - {角色}开始收心`，回到 CALM 时 `{角色}回过神了`。
- `scripts/test/stage6_balance_matrix.gd` + `scenes/stage6_balance_matrix.tscn`（新增）：
  三段独立实跑（AB / C / DE），全部加载正式 `race.tscn`，逐帧驱动
  `race._physics_process(1/60)`，真实输入走 `Input.action_press/release` 与
  `GameManager.toggle_control()`；不直接改事故状态、不关判定。

## 3. 七条验收标准

### 3.1 两个角色各有图形+名称，当前控制有第二个非文字标识

窗口化实跑截图：`screenshots/refine06-p1-hud.png`（兔子受控趴低、乌龟 MISCHIEF）。
左上两行分别是🐰“兔子 操控·趴低”和🐢“乌龟 待命·要惹麻烦”；当前控制同时有
`▶` 箭头和 glyph 上的金色环。世界内神游标记也带乌龟壳图形（`?/!?/!` 随档位变化）。

### 3.2 四档变化时 HUD 和世界各至少两处增强

四张同位置对照截图（`screenshots/refine06-p1-hud-{calm,distracted,restless,mischief}.png`，
直接设 `turtle_brain.drift` 只为截到各档画面；状态自然累积与回落由 3.4 的逐帧记录证明）：

| 档位 | HUD 文案 | HUD 颜色 | HUD 条 | 世界标记 |
|---|---|---|---|---|
| CALM (drift 1.5) | 待命·稳定 | 绿 | 12% | 不显示（`drift < 3`） |
| DISTRACTED (4.5) | 待命·开始神游 | 琥珀 | 38% | 琥珀 `?` + 乌龟图形 |
| RESTLESS (7.5) | 待命·坐不住了 | 橙 | 63% | 橙 `!?` + 乌龟图形 |
| MISCHIEF (10.5) | 待命·要惹麻烦 | 红 + 脉动 | 88% | 红 `!` + 乌龟图形 |

没有新增状态等级，也没有“还剩几秒”的倒计时数字。

### 3.3 SHIFT 接手后 0.75 s 内反馈；受控 0.5 s 后才回落；回 CALM 再报一次

逐帧记录（`shift_traces`，1/60 s 采样，6 条 drift0≥3 的接管）：

| run | 角色 | 接手 drift | 0.45 s 时 | 1.20 s 时 |
|---|---|---|---|---|
| AB | 乌龟 | 8.10 | 8.10 | 6.70 |
| AB | 兔子 | 8.03 | 8.03 | 6.63 |
| C | 兔子 | 5.10 | 5.10 | 3.70 |
| C | 乌龟 | 7.72 | 7.72 | 6.32 |
| DE | 乌龟 | 12.00 | 12.00 | 10.60 |
| DE | 兔子 | 5.02 | 5.02 | 3.62 |

0.45 s 内完全不动（`CONTROL_RECOVER_DELAY=0.5`），之后按 2.0/s 回落。
反馈文本与时间：AB 换手 t=8.10 同帧 `换手 - 乌龟开始收心`，t=11.15 `乌龟回过神了`
（从 8.10 到 CALM 恰好 3.05 s = 0.5 s 缓冲 + 2.55 s 回落）；DE 两条 `回过神了`
分别在 20.27（乌龟）和 21.78（兔子）。换手反馈延迟实测 0.00 s，判据 0.75 s。

### 3.4 可重复运行的动态平衡场景

`stage6_balance_matrix.tscn` 三次运行、五类段落；结果 JSON：
`docs/reports/longrun/refine06-p1-balance.json`（31 条判定全过，`failed=0`）。

| 段 | 覆盖类型 | 组的组合 | 结果 |
|---|---|---|---|
| A | 连续兔子专属 | beam2 → bird2，全程控兔 | 2 组通过，0 撞；乌龟 CALM→DISTRACTED→RESTLESS，末 drift 8.10，速度 202/220（0.92） |
| B | 连续乌龟专属（接 A） | gate2 → wall1，立刻切龟 | 2 组通过，0 撞；接手时乌龟 RESTLESS 8.10，gate2 进组已降到 1.13；wall 进组乌龟 CALM 0.03、兔子 RESTLESS 8.03，BRO OLLIE 仍成 |
| C | 交替 | gate1 → rock2 → log1 → shark1 | 4 组通过，0 撞；两次换手（t=5.10 龟→兔，t=12.82 兔→龟）；浮木进组时控兔、兔 JUMPING（lead 135.3 px） |
| D | 伙伴失控中组合 | beam2 → bird2 → gate2 | 3 组通过，0 撞；接手时乌龟 MISCHIEF drift 12.00，gate2 进组仍 MISCHIEF 10.70，照样潜过 |
| E | 高压力后恢复 | 开阔水域，先收乌龟再收兔子 | 乌龟 2.33 s 回 CALM，兔子 1.52 s 回 CALM；收兔子时乌龟已重新开始神游（20.32 CALM→DISTRACTED）——恢复必须分配注意力 |

JSON 每条记录都含：状态变化时间/角色/前后档位/drift/当时控制、每次 SHIFT 的
from/to/x/drift 采样、进组时双方完整快照（brain/drift/state/x/y/speed）、
碰撞与失误的组名/角色/原因（`mistake:RABBIT_STUN` / `RABBIT_WATER` 等，
本次五段为 0 笔）、以及 `verdict.unwinnable_found=false`。

无解组合判定：五段里每个动作窗口都允许“当前控制角色做该做的事”，没有任何一组
要求两个角色同时做动作；`D` 证明 MISCHIEF 顶端也只是更难、不是必死。

### 3.5 只用原生 UI

`role_glyph.gd` 只用 `draw_circle/draw_line/draw_arc`；HUD 只用
`Control/Label/ProgressBar/PanelContainer`。没有新美术、字体、音效；
没有失败倒计时或全局计时器。

### 3.6 回归

- `stage4_hud_score`：`PASS checks=44`
- `stage4_menu_input`：`PASS`
- 两圈 fullrun（窗口化，`--zh`）：run1 272.9 s / run2 272.8 s，9770 分，S，
  55/55 组，0 事故，`STAGE3 PLAYTEST: PASS`；stderr 0 行
  （`docs/reports/logs/refine06-p1-fullrun.stdout.log`）
- `best.json` md5 前后一致：`c322f9a20321c5b618f98db7e4120969`
- `docs/STAGE.md` 仍为 `STAGE=4`

### 3.7 有趣性判断：有保留

“看伙伴状态 → 决定何时 SHIFT”在一局里是**看得见的选择**，但这次五段矩阵里
它还不是**必须做的选择**：

- 可感：不控制的角色 9 s 到 MISCHIEF，HUD/世界四档变化 + 换手/回过神反馈；
  代价可测——乌龟 RESTLESS 受控时速度 0.92（202/220）。
- 有收益：B 段接手后 gate2 进组 drift 从 8.10 降到 1.13；E 段两个角色各自
  2.33 s / 1.52 s 能收回，但只能一个一个收。
- 保留的原因：矩阵里所有段落用“按障碍类型换角色”的标准打法就能 0 撞通过，
  drift 从未成为失败原因；D 段乌龟以 MISCHIEF 10.70 仍能潜过 gate2。
  也就是说当前压力是“更慢、更晃、更难”，而不是“不换就过不去”。
- 风险：熟悉关卡后，玩家可能把 SHIFT 只当“切换角色”用，神游退化成背景噪声。
  这需要 P6 的 55 组节奏复盘来判断：站距是否让某个角色被迫闲置 >9 s。
  真人试玩仍未做，以上不是手感结论。

## 4. 复现

```bash
# 五段矩阵（headless，约 30 s）
D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage6_balance_matrix.tscn

# 窗口化截图（HUD 总览 + 四档对照）
D:/Godot_v4.7-stable_win64_console.exe --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage6_balance_matrix.tscn -- --capture-p1

# 回归
D:/Godot_v4.7-stable_win64_console.exe --path D:/GAMESTUDIO/TURBBIT res://scenes/stage4_hud_score.tscn
D:/Godot_v4.7-stable_win64_console.exe --path D:/GAMESTUDIO/TURBBIT res://scenes/stage4_menu_input.tscn
D:/Godot_v4.7-stable_win64_console.exe --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage3_playtest.tscn -- --zh
```

## 5. 未做 / 已知问题

- 真人试玩未做；3.7 是机制读数，不是手感结论。
- 四档截图为状态渲染对照（直接设 drift），不是自然演化截图；自然演化见 3.4。
- 静止鲨鱼仍会把壳无限顶住（P0 遗留，P3 给上浮拦截的通过窗口）。
- 矩阵只覆盖 10 组代表障碍；55 组全量通过性仍由 fullrun 55/55 证明（自动驾驶，
  不等于人玩难度）。
