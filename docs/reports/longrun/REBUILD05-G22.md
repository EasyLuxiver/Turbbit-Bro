# G22 — 收尾优化：补教上限、又一组会沉的浮木、运动时钟归零

日期：2026-11-13（11:56 先写验收标准，12:00 起改，12:30 前回归收尾）
改动：`scripts/race.gd` 两处（补教上限 + `load_level` 归零运动时钟）、
`scripts/systems/level_data.gd` 一处（log5 加浪涌）；
探针 `stage5_g21_relesson.gd` 新增 F 用例、`stage5_e2_motion.gd` 扩到 log5
QC：`tbb-exp05-g22-polish`（7 条标准，11:56 写入）

## 1. 补教只给一次（G21 留的尾巴）

G21 让“撞过的类型下一组再教”，但没设上限：同一类型连着撞三组会补教三次。
第三遍同一句话不会让人更懂，只会占住底栏、盖掉别的提示。G22 加一个上限：

```gdscript
# _check_hazards() 记账分支
if not lesson_retaught.has(kind):
    lesson_retaught[kind] = true
    lesson_seen.erase(kind)
```

- 首次教学 + 一次补教，之后同一类型不再重新武装；
- `lesson_retaught` 与 `lesson_seen` 同生命周期（一局一份，换关不串）；
- 干净通过、被冷却挡下的碰撞都不进这里（沿用 G21 的口径）。

探针 `stage5_g21_relesson` 新增 F 用例：撞 beam3 → beam4 前补教一次 →
再撞 beam4 → beam5 前必须没有第三条提示，且第二次碰撞后 `lesson_seen`
里仍保留 LOW_BEAM（说明没有被重新武装）。

反向对照：把上限去掉（无条件 `erase`）后重跑，恰好 F6 / F7 变红，
F1–F5 仍绿——两条断言确实在测上限，不是复述前面的用例。

## 2. Z3 的 log5 也会沉浮（动态从 13/55 到 14/55）

F 段记下的“Z3 两对两连重复”里，浮木/鸟这一对在两个位置都是静态浮木。
不动位置、不动种类、不碰食物锚点，只给第一处浮木加和 log6/log2 相同的浪涌
（−18 ± 22 px / 5.0 s，相位错开 0.35 个周期）：

```gdscript
{"group": "log5", ..., "motion": {"name": "swell_log", "axis": "y",
    "amp": 22.0, "period": 5.0, "bias": -18.0, "phase": 0.35}},
```

log5 不在食物锚点链上（Z3 锚点是 shark8 / beam8 / shark9 / gate8），也不在加速带里。
E2 探针扩到 log5：

- 运动本身：实测振幅 21.9（规格 22）、偏置 −18.0、范围 −39.9…+3.9、
  周期重复误差 0、判定框跟随偏移；
- 标准 BRO DIVE 扫 5 个相位：`hits 0`、`riding_after` 全 true，
  浮木上沿从 154.7 到 195.8（跨度 41.1 px，证明确实在动）。

## 3. 运动时钟在装载关卡时归零

G20 发现 `snack_zones` 的多行探针会因为 `hazard_clock` 行间漂移而时红时绿，
当时只在那一个探针里归零。其余多行探针同样会把上一例走过的物理时间带进下一例，
同一个断言的位置/相位就跟着变。收口放在 `load_level()`：

```gdscript
hazard_clock = 0.0
```

正式赛局本来就从头开始（构造时是 0），`load_level` 在比赛中不重复调用，
所以对玩家行为是 0 变化；探针每重装一次关卡就从同一相位起跑。

## 4. 读数

探针 `stage5_g21_relesson`（正式 `race.tscn`，`_physics_process` 驱动）：

- A–E 原有用例全部仍 PASS；新增 F：撞 beam3 → beam4 前补教一次 → 再撞 beam4 →
  beam5 前 **0 条提示**；F 行读数 `accidents=2`、`prompts_at_beam5=[]`、
  `retaught=[LOW_BEAM]`、第二次碰撞后 `lesson_seen` 仍含 **LOW_BEAM**。
- 反向对照（无条件 `erase`）：`G21 RELESSON: FAIL`，恰好 F6 / F7 两条变红；
  改回上限后重跑 `PASS`。

E2 探针（log5）：

| 检查 | 读数 |
|---|---|
| 运动振幅 / 偏置 | 实测 21.9 / 规格 22；偏置 −18.0；范围 −39.9…+3.9 |
| 周期重复误差 | 0.0 |
| 判定框跟随偏移 | true；跨轴 false |
| 标准 BRO DIVE × 5 相位 | `hits 0`、`riding_after` 全 true，上沿 154.7…195.8（跨度 41.1 px） |

`STAGE4 METRICS: PASS`（G22 后重跑）：Z1/Z2/Z3 10.6 / 11.4 / 13.1 组每分，
单角色最小 3.65 s、组合前 5.13 s——与加动态前一致（运动不改位置）。
`STAGE4 Z3 WARNING: PASS`（Z2 不出现 Z3 预警）。

## 5. 回归（最终工作树）

- 两圈 `fullrun-g22.log`：run1 `272.9 s / 9770 / S / 55/55 / 0 事故`，
  run2 `272.8 s` 同；`STAGE3 PLAYTEST: PASS`；FINISH / SCORE / PLAYTEST 关键行
  与 `fullrun-final.log` `diff` 为空。
- 26 场景批量（`/tmp/g22-<scene>.log`，含 `stage5_e2_motion`、`stage5_g21_relesson`）：
  全部 `exit=0`、0 条失败行。
- 窗口化：`stage4_hud_score` `PASS checks=44`；`stage4_menu_input` `PASS`。
  （第一次菜单测试与两圈全赛道并发跑，`best.json` 比对被全赛道跑动中的临时写入干扰，
  失败行只有 `menu tests do not touch best.json`；等全赛道退出后单独重跑 PASS，
  两次取样 md5 均为 `c322f9a20321c5b618f98db7e4120969`。）
- `best.json`：两圈跑前 / 跑后 md5 `c322f9a20321c5b618f98db7e4120969`，
  内容 `best_score 3150 / best_time 283.961389 / best_accidents 0 / best_streak 54`。
- `STAGE=4` 未动；未跑 `preflight.py`。

## 6. 没做的事

- 仍然没有真人试玩。
- “Z3 两对两连”的**顺序**没动：换顺序会改组合节奏，收益不抵一次全回归，
  留给制作人试玩时判断。
- 主动换人的收益仍靠奖励；本轮没有改评分/速度模型。
