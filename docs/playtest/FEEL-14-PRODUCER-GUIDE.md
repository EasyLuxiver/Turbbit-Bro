# TURBBIT BRO! — FEEL-14 制作人试玩指南

> 这是试玩准备，不是内容冻结。正式入口仍然只有 **Start Game / Settings / Exit**。
> `art_test` 技术样没有接进正式比赛；55 组、角色能力、数值、键位都没有改。

## 1. 启动

项目目录：`D:\GAMESTUDIO\TURBBIT`

### 直接运行（推荐先试）

```powershell
D:\Godot_v4.7-stable_win64_console.exe --path D:\GAMESTUDIO\TURBBIT
```

- 1920×1080 窗口：

```powershell
D:\Godot_v4.7-stable_win64_console.exe --path D:\GAMESTUDIO\TURBBIT --resolution 1920x1080
```

- 全屏：

```powershell
D:\Godot_v4.7-stable_win64_console.exe --path D:\GAMESTUDIO\TURBBIT --fullscreen
```

导出试玩包（如果已生成）：`build/FEEL-14/TurbbitBro.exe`。双击后仍然从正式主菜单开始。

## 2. 正式流程

1. 主菜单只有 **开始游戏 / 设置 / 退出**。
2. 开始游戏 → 7 格开场连环画 → 4 步教学 → 正式 55 组比赛。
3. 比赛中：↑ 跳/跃起，↓ 趴低/下潜，SHIFT 换人，SPACE = TUBO 胡萝卜护盾 / BITT 主动救援。
4. 终点结算 → R Retry / M 主菜单；Retry 会从正式比赛起点重开。

## 3. 快速测试入口（不在玩家菜单里）

这些是**命令行调试入口**，只摆状态，不改关卡数值；正式菜单里看不到，也不会出现在导出试玩包的玩家入口。

```powershell
# Z3 末段 G43–G55 快速起点（从正式赛道 x≈52000 开始）
... --path D:\GAMESTUDIO\TURBBIT res://scenes/feel14_probe.tscn -- --z3

# BITT 从 TUBO 前方接近救援（按 SPACE 开始）
... --path D:\GAMESTUDIO\TURBBIT res://scenes/feel14_probe.tscn -- --catch-front

# BITT 从 TUBO 后方追赶救援
... --path D:\GAMESTUDIO\TURBBIT res://scenes/feel14_probe.tscn -- --catch-back

# TUBO 胡萝卜护盾练习（低梁前；靠近后按 SPACE）
... --path D:\GAMESTUDIO\TURBBIT res://scenes/feel14_probe.tscn -- --guard
```

## 4. 重点看什么

| # | 看什么 | 怎么到 |
|---|---|---|
| 1 | Z3 最后 13 组的实际节奏 | `--z3`，或正式跑完 Z2 |
| 2 | BITT 从前方接近并救援 | `--catch-front`，按 SPACE |
| 3 | BITT 从后方追赶并救援 | `--catch-back`，按 SPACE |
| 4 | TUBO 护盾精准窗口 | `--guard`，在低梁靠近时按 SPACE |
| 5 | 普通路线 vs 技巧路线 | 正式比赛；同一段先不按 SPACE，再按 SPACE |
| 6 | SHIFT / BRO OVERDRIVE | 正式比赛；或 `res://scenes/shift_lab.tscn` 的 O 触发演示 |

### Z3 最后 13 组（从 G43 起）

`G43 shark8 → G44 bird7 → G45 beam8 → G46 log7 → G47 rock10 → G48 shark9 → G49 bird8 → G50 beam9 → G51 log8 → G52 rock11 → G53 gate8 → G54 bird9 → G55 rock12`

重排后的意图：不再有 `bird7→beam8→rock10` 三连兔子；`shark8` 直接接 `bird7`；`log7` 插在 `beam8` 与 `rock10` 之间；尾段改成 `log8→rock11→gate8→bird9`。

## 5. 记录

用两个文件：

- [FEEL-14-PLAYTEST-TEMPLATE.md](FEEL-14-PLAYTEST-TEMPLATE.md) — 每轮复制一份，写主观感受。
- [feel14-playtest-log.csv](feel14-playtest-log.csv) — 汇总一行一轮，方便对照。

至少记：

- 轮次、角色、操作方式、窗口；
- 事故发生位置 / 障碍组编号 / 事故类型；
- SHIFT 时机、护盾时机；
- BITT 救援开始位置、方向、成功/失败；
- OVERDRIVE 触发和实际效果；
- 不自然 / 重复 / 难懂 / 无聊 30 秒 / 特别有趣的位置；
- 1–5 评分与自由备注。

只记录，不要为了“跑通”改游戏。若发现必须改比赛逻辑，先停下并报告原因。

## 6. 试玩前已知

- 55 组全量 audit：55/55 无解组 0；两圈自动跑圈 55/55、0 事故（自动驾驶代理，不是人）。
- 氧气 3/2/1/0 在 1920×1080 和全屏下已验证。
- 角色独立拆件只有 `art_test` 技术样，**没有接进正式比赛**；正式比赛仍是原生绘制。
- 自动化通过 ≠ 有趣性通过；请以实际手感为准。
