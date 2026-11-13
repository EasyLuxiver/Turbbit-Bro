# STAGE 4 — 障碍空间重映射与龟兔协同（2026-11-11 补充指令）

`STAGE=4`（未进入阶段 5）。素材零新增，仍只用现有占位与原生 Control。

本报告对应制作人 2026-11-11《障碍空间设计与龟兔协同操作补充指令》。核心修正已落地：
**乌龟下潜是正式的主动避障动作，不是惩罚机制；兔子跳跃与乌龟下潜可以同时存在。**

2026-11-12 追加指令再改：跳跃降到 183.8 px / 1.18 s，FLOATING_LOG 收紧到
192–410（宽 32），新增 3 组 HIGH_WALL，SHARK 由 9 组降为 6 组。下表已按当前
`KIND_SPEC` 更新；连招、评分与事故槽见 `STAGE-4.md` 的 2026-11-12 节。

## 1. 七类空间模型

判据是“占哪一层空间、谁来处理”，不是旧名字。判定框与画法出自同一份 `KIND_SPEC`
（`scripts/systems/level_data.gd`，世界 y 已含 `WORLD_Y_SHIFT=34`）。

| 类别 | kind（组数） | 判定框 y | 谁过 / 怎么做 | 安全通道 |
|---|---|---|---|---|
| A 兔子层·趴低 | LOW_BIRD (9) / LOW_BEAM (9) | 234–274 / 174–274 | 兔子趴下（crouch 284–300，让开 10 px） | 龟壳巡航 306–362 完全不动 |
| A 兔子层·跳跃 | SURFACE_ROCK (12) | 254–296 | 兔子跳（站立 252–300 与下蹲 284–300 都压线） | 岩檐底 296，龟壳顶 306，让开 10 px |
| B 组合 | FLOATING_LOG (8) | 192–410 | 兔子跳过上沿 **并** 乌龟潜下下沿，两条路线同时成立 | 上：兔弧线；下：壳顶 >410 |
| C 水下攻击 | SHARK (6) | 274–480 | SHIFT 乌龟 + ↑ 跃起 160 px，整组带高 | 跃起后整组离开 274–480 |
| D 水下通道 | DIVE_GATE (8) | 204–384 | SHIFT 乌龟 + 按住 ↓；松开后浮力回浮 | 壳顶 >384（下潜 ≥78 px，兔顶 402） |
| B 组合·高墙 | HIGH_WALL (3) | 墙楣 120–136；墙身 240–520；门洞 136–240 | 乌龟跃起 + SHIFT + 兔子二段蹬踏 | 只有跃起+蹬踏能把兔身抬过墙楣、壳从门洞穿过 |

组合漂浮木是招牌障碍：上沿 192 压站立兔、下沿 410 压巡航龟壳，**只跳、只潜或只跃都
过不去**（8/8 组 `dive_only=false` / `jump_only=false` / `leap_only=false`，
见 `stage4-solution-matrix.json` 的 `logs_falsification`）。

## 2. 原型段（先做独立原型，再改 55 组）

入口：`res://scenes/stage4_proto.tscn`，命令
`D:/Godot_v4.7-stable_win64_console.exe --path D:/GAMESTUDIO/TURBBIT res://scenes/stage4_proto.tscn -- --shots`。

七类各一组，实机 1600×900 截图（`screenshots/`）：

- `tbb_proto_bird.png` / `tbb_proto_debug_bird.png`
- `tbb_proto_rock.png` / `tbb_proto_debug_rock.png`
- `tbb_proto_beam.png` / `tbb_proto_debug_beam.png`
- `tbb_proto_shark.png` / `tbb_proto_debug_shark.png`
- `tbb_proto_gate.png` / `tbb_proto_debug_gate.png`
- `tbb_proto_log.png` / `tbb_proto_debug_log.png`

F3 层标出：真实判定框、`TRIGGER 1100` 预警线、组合的 `SAFE ABOVE` / `SAFE BELOW`
两块可通行空间，以及类别与责任角色（A/RABBIT-CROUCH、A/RABBIT-JUMP、B/COMBINED、
C/TURTLE-LEAP、D/TURTLE-DIVE）。

**组合序列**（`screenshots/stage4-combo-dive-1-jump.png` → `2-under` → `3-clear` → `4-land`）：
兔子 `↑` 起跳 → 空中 SHIFT 给乌龟 → 玩家按住 `↓` 下潜（兔子仍在空中，画面里一个在上、
一个在下）→ 浮木下沿通过 → 松开 `↓` → 浮力回浮 → 兔子落回壳上。四条不可妥协项：

| 要求 | 证据 |
|---|---|
| 切乌龟不取消跳跃 | proto：`SHIFT` 后兔子仍处 AIRBORNE；`2-under` 截图兔在木上、壳在木下 |
| 下潜必须玩家主动输入 | 只跳 0/8、只潜 0/8；`-3-clear` 只在按住 `↓` 的窗口出现 |
| 合体不瞬移 | 落地 `mount=RIDING`；主赛道 8/8 组 `dive_jump` 通过、0 次 RABBIT_WATER |
| 尾端能回巡航 | 松开 `↓` 后浮力回 334；落地后继续巡航（`stage4_proto` 断言 turtle_y 回巡航） |

## 3. 55 组：分类前后

| | 必须趴 | 必须跳 | 必须跃 | 必须潜 | 必须组合 | 必须 BRO OLLIE | 无解组 |
|---|---|---|---|---|---|---|---|
| 改前（`stage4-content-matrix-pre-space.json`） | 0（只有 9 组可选） | 0（12 组可选） | 0 | 21 | 0（接人 0） | — | — |
| 更早（审计报告 F-1） | 0 | 0 | — | 34 | 0 | — | — |
| 2026-11-12（`stage4-solution-matrix.json`） | **18** | **12** | **6** | **8** | **8** | **3** | **0** |

当前 55 组 = LOW_BIRD 9 + LOW_BEAM 9 + SURFACE_ROCK 12 + SHARK 6 + DIVE_GATE 8 +
FLOATING_LOG 8 + HIGH_WALL 3；加速带 9 条不变。没有任何一组保留“旧碰撞设计”。

“必须”列是关卡的设计答案，不等于其他方案一定失败：LOW_BIRD 与 SURFACE_ROCK
仍接受跳/趴/潜/跃中的多种动作（见 `by_kind.pass_counts`）；真正只有单一通过的
是 SHARK（只跃）、DIVE_GATE（只潜）、HIGH_WALL（只跃后蹬）、FLOATING_LOG（只跳后潜）。

## 4. 实测预警时间（首次可见 → 碰撞）

原型段（`stage4-proto.json` 的 `warning_times`，按 220 px/s 基速折算）：

| 组 | 距离 | 秒 |
|---|---|---|
| bird | 1100 px | 5.00 |
| rock | 1080 px | 4.91 |
| beam | 1090 px | 4.95 |
| gate | 1020 px | 4.64 |
| shark | 1020 px | 4.64 |
| log（组合） | 1100 px | 5.00 |
| wall（组合） | 1100 px | 5.00 |

单角色最小 4.64 s（基线 ≥3.5 s），组合 5.00 s（基线 ≥5 s）。主赛道按尾端间距复核：
Z1 4.36 s / Z2 4.25 s / Z3 3.85 s；浮木前方净空 5.09 / 5.13 / 5.19 s。全部达标。

## 5. 主流程回归

自动验收（工程代理，**不等于真人**）：

- `docs/reports/logs/playtest-stage4-score4.log` — 2026-11-12 主流程完整两圈
  （Enter + Retry），时间倍率 3.0，每圈 `passed=55/55 accidents=0`、
  `score=9500`、`STAGE3 PLAYTEST: PASS`。自动驾驶按七类策略实跑，
  8 组组合漂浮木全部走 `dive_jump`，3 组高墙全部走 `leap_jump`。
- 2026-11-12 自动批：`stage3-selftest-score5`、`stage4-bro-meter-b`、
  `stage4-proto-shots-d`、`stage4-metrics-b`、`bilingual-stage4-c`、`stage4-flow`、
  `stage4_core_experience`、`stage4_hud_priority`、`stage4-shift-graybox-rev2`、
  `stage4-menu-input-rev2-windowed` 全部 PASS。
- `stage4-solution-matrix.json`：55 组×7 方案、`no_solution_groups=0`；
  `logs/solution-audit4-a..d.log` 四片 `SOLUTION AUDIT: DONE`。
- `stage4_menu_input` 窗口化真实鼠标全流程 `PASS`（headless 无鼠标，不可用）。
- 组合时序（自动驾驶）：跳后潜 `dive_jump` 在 Z3 260 px/s 下只剩约 0.21–0.99 s
  的空中窗口；高墙 `leap_jump` 的蹬踏窗口同样紧。

**报告式场景没有 PASS 字样，不能算回归通过**：`stage4_surfboard` 打印实验数，
`stage4_level_audit` 打印矩阵，`stage4_experience_rework` 与 `stage4_gear_ab` 是
旧规则灰盒实验（前者报 “C: 接人 3/5”，后者报 “NO CONCLUSION”），其 arms 仍假设
“下潜躲低梁/跳跃后立刻下潜接人”，与当前七类规则冲突。它们不作为验收证据，
保留原样供历史对照。

## 6. 未解决 / 未验证

- **真人试玩 NOT TESTED。** QC 第 9 条（有趣性）留 `pending`，交付闸门仍是
  `NOT_VERIFIED`。按指令，本文不宣布完成。
- Z3 组合的自动驾驶时序很紧（空中且高于上沿的窗口约 0.21–0.99 s）；真人能否在
  260 px/s 下稳定跳过上沿、空中换人、及时按住 ↓，未验证。若制作人试玩失败，
  优先放宽 Z3 浮木前方净空或降 Z3 基础速度，而不是改回旧机制。
- **只潜仍能过 38/55 组**（9 鸟 + 12 岩 + 9 梁 + 8 门）。这在物理上说得通，但
  “下潜”仍是最宽的单动作；强制换人压力来自鲨鱼 6、浮木 8、高墙 3。若制作人
  要求更窄，下一步应改关卡组合（例如更多浮木夹层），而不是加不合理碰撞体。
- 角色内部 `daze_time` 五段失衡与 BRO METER 三格并存，见 `STAGE-4.md` §5，
  标为**部分偏差待裁决**。
- `stage4_driver`、`stage2_playtest` 已退役；旧 `SURFACE_WALL` 相关灰盒场景
  只作历史对照（见上）。
- 有趣性自评：**有保留**（基于自动代理，不是真人）。最有把握的一句是
  “跳→换人→按住 ↓→松开回浮→落回壳”在组合漂浮木上形成了连续的判断与后果；
  最可能不好玩的地方是 Z3 组合要求的手速。

## 7. 下一阶段

保持 `STAGE=4`。下一步是制作人真人验收本轮原型与主赛道，给出四问回答与
“最无聊的 30 秒”；在此之前不进入阶段 5，也不以自动测试通过代替验收。
