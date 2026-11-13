# PHASE J — 难度 / 舒适度 / 可重复游玩

任务：`TBB-LONGRUN-PLAYABILITY-01`
日期：2026-11-12
阶段：STAGE 4（未推进 STAGE 5）
性质：**本轮零玩法改动**。只加测量工具、跑只读探针，把“难度是不是逐步掌握”拆成可判定的数。

> 证据类型：真实物理的自动驾驶探针（引擎 InputMap 代理按键）+ 窗口化实跑。
> 本机 OS 级键位注入被系统拒绝，**这不是真人按键，也不是真人试玩**。
> 第 7 条（难度曲线要真人感受）保持 pending，闸门因此记 `NOT_VERIFIED`。
> 也**不能**用“自动驾驶零事故”证明难度合适——它只证明存在解，不证明人玩得动。

> **后续更新（2026-11-12 16:45）**：本文的 `dive 38/55` 是 Phase J 当时的快照。
> Phase M 按制作人选择收窄了关卡几何（岩/梁加水下阻挡），下潜已降到 17/55；
> 容差/反应/恢复三项逐组不变。见 `PHASE-M-DIVE.md`。

## 0. 一句话结论

55 组障碍里，最紧的一组仍有 **0.154 s** 输入容差、**3.54 s** 反应预算，组间最紧空档
**3.85 s**；7 类障碍全部在 Z1 前 60 s 内各教一次，提示距障碍 **≥3.72 s**（含零输入
乱撞、38 次事故干扰的对抗工况）。没有任何单一方案能过全程（最高是下潜 38/55）。
“只有自动驾驶才能过的窗口”在这套判据下不存在——但“玩起来是不是逐渐变难”仍要真人。

## 1. 方法（全部可复现）

| 探针 | 覆盖 | 分辨率 | 产物 |
|---|---|---|---|
| 密扫 `stage4_solution_audit --tolerance` | 55 组 × 设计答案方案 | lead 40–60 px 一档 | `docs/reports/stage4-tolerance-scan-*.json`、`logs/phase-j/tol-{a,b,c}.log` |
| 二维连招窗 `stage4_combo_windows --indices` | 8 块浮木 + 3 面高墙 | lead 10 px × delay 0.05 s | `docs/reports/longrun/phase-j-log-windows.json`、`logs/phase-j/logs-combo.log` |
| 首次教学 `stage4_lesson_prompt` | 55 组，7 类 | 每物理帧 | `logs/phase-j/lesson-prompt{,-hazards}.log`、`lesson-prompts*.json` |
| 汇总 `logs/phase-j/summarize.py` | 以上全部 | — | `logs/phase-j/phase-j-summary.json` |

口径（与 `Tuning.PROMPT_RANGE` 一致）：

- 前方可见 1100 px = 镜头在 `turtle.x+300`、1600 宽视口。
- **反应预算** = (1100 − 最晚仍能起手的 lead) / 区速。区速 Z1/Z2/Z3 = 220/240/260。
- **输入容差** = 同一方案连续可过的 lead 宽度 / 区速。浮木、高墙是二维操作，
  一维密扫会把第二段延迟钉死、低估窗口，因此这两类改用二维扫描的 lead 跨度。
- **恢复时间** = (下一组起点 − 本组终点) / 下一组区速。

## 2. 验收判定

| # | 标准 | 判定 | 证据 |
|---|---|---|---|
| 1 | 反应预算 ≥0.35 s | **pass** | 最小 **3.54 s**（wall3，Z3）；55 组无一 <0.35 s（`phase-j-summary.json`） |
| 2 | 输入容差 ≥0.15 s | **pass** | 最小 **0.154 s**（shark6/8/9，Z3 leap）；0 组 <0.15 s；浮木 0.182–0.231 s、高墙 0.318–0.375 s |
| 3 | 组间恢复 ≥1.0 s | **pass** | 最小 **3.85 s**（shark6→beam6）；54 个空档无一 <1.0 s |
| 4 | 每种障碍首次出现都教一次，且距障碍 ≥1.0 s | **pass** | 7/7 类，最小 **3.74 s**；零输入乱撞（38 次事故 / 49.2 s）下仍 7/7、最小 3.72 s |
| 5 | 没有单一方案覆盖 55/55 | **pass** | dive 38、leap 27、dive_jump 22、jump 21、crouch 18、leap_jump 3；无解 0 |
| 6 | 本轮改动后窗口化实跑完整赛道 + 回归，0 SCRIPT ERROR，`best.json` 前后一致 | **pass** | §7：两圈 55/55、0 事故、0 SCRIPT ERROR；4 个回归 PASS；`best.json` 与备份逐字节一致 |
| 7 | 难度是逐渐掌握而不是突然变难 | **NOT TESTED** | 需要真人试玩；自动数据不能代替 |

## 3. 输入容差（判据 2）

最紧的 8 组：

| 组 | 区 | 种类 | 方案 | 可通过 lead | 容差 |
|---|---|---|---|---|---|
| shark6 / shark8 / shark9 | Z3 | SHARK | leap | 160–200 px | **0.154 s** |
| rock6 | Z2 | SURFACE_ROCK | jump | 40–80 px | 0.167 s |
| rock1 / rock2 | Z1 | SURFACE_ROCK | jump | 40–80 px | 0.182 s |
| log1 | Z1 | FLOATING_LOG | dive_jump | 140–180 px（delay ≤0.15 s） | 0.182 s |
| shark1 | Z1 | SHARK | leap | 120–160 px | 0.182 s |

**这个 0.154 s 是下界，不是精确值**：Z3 的密扫一档就是 40 px（40/260 = 0.154 s），
shark6 在第 160 和 200 两档通过、相邻档失败，所以真实窗口落在 0.154–0.46 s 之间。
判据问的是“至少 0.15 s”，下界已满足；要更精确得再密一档，本轮没做。

浮木是全场最需要练的一组——但它的窗口是二维的：

| 组 | lead 窗口 | 最佳延迟窗口 | 通过格子 / 总格子 |
|---|---|---|---|
| log1 | 140–180 px（0.182 s） | 0–0.15 s | 11 / 152 |
| log2–log4 | 0.208 s | 0–0.20 s | 17 / 152 |
| log5–log7 | 0.231 s | 0–0.25 s | 23 / 152 |
| log8 | 0.231 s | 0–0.25 s | 23 / 152 |
| wall1–wall3（Phase H 数据） | 0.308–0.375 s | 0.40–0.85 s | 43–57 / 285–323 |

连招的第二段延迟从 0 到 0.25 s 都能过，说明它不是“卡帧连打”，而是允许先起跳、
再找时机换角色——有练习价值，但没有被自动数据证明“好玩”。

## 4. 反应预算（判据 1）

最紧的 5 组（预警 1100 px → 最晚还能起手）：

| 组 | 区 | 种类 | 最晚 lead | 反应预算 |
|---|---|---|---|---|
| wall3 | Z3 | HIGH_WALL | 180 px | **3.54 s** |
| shark6 / shark8 / shark9 | Z3 | SHARK | 160 px | 3.62 s |
| log5–log8 | Z3 | FLOATING_LOG | 160 px | 3.62 s |

要判 0.35 s，实测最紧 3.54 s——多出一个数量级。反过来说，**当前不是“反应不过来”**，
而是“有大量时间可以发呆”；难度不来自反应速度。

## 5. 恢复时间与空档（判据 3）

- 54 个组间空档：最小 **3.85 s**（shark6→beam6，Z3），中位 4.44 s，最长 5.55 s（wall1→rock3）。
- 没有空档 <3 s，也没有“连续多次操作而没有恢复时间”的段落。
- 开场从 x=400 到第一组 bird1（1300）是 **4.09 s** 的空跑道，但第一次教学提示
  在开局 0.35 s 内就出现——等待感主要来自“没有输入”，不是“没有信息”。

## 6. 首次教学（判据 4）

`lesson-prompt.log`，零输入、关碰撞：

| 种类 | 首次组 | 距离 | 到障碍时间 | 提示文本 |
|---|---|---|---|---|
| LOW_BIRD | bird1 | 823 px | 3.74 s | ↓ CROUCH |
| SURFACE_ROCK | rock1 | 1098 px | 4.99 s | ↑ JUMP |
| LOW_BEAM | beam1 | 1100 px | 5.00 s | ↓ CROUCH |
| SHARK | shark1 | 1098 px | 4.99 s | SHIFT + ↑ TURTLE LEAP |
| DIVE_GATE | gate1 | 1099 px | 5.00 s | SHIFT + HOLD ↓ TURTLE DIVE |
| FLOATING_LOG | log1 | 1097 px | 4.98 s | ↑ RABBIT JUMP → SHIFT → ↓ TURTLE DIVE |
| HIGH_WALL | wall1 | 1097 px | 4.99 s | SHIFT + ↑ LEAP → SHIFT RABBIT → ↑ KICK |

两个说明：

- bird1 的 823 px 是**测量晚启动**的结果：比赛从 x=400 开始，探针在场景切完、
  跑了几帧后才开始记录（x=477）。真实值约 900 px / 4.09 s，比记录更宽松。
- 对抗工况（`--hazards`，零输入，撞了 38 次、累计 49.2 s 处于事故中）跑了一遍：
  rock1 的提示被前一次事故压到 995 px / 4.52 s，其余不变，7 类仍全部教到。
  即“失误不会吃掉教学预算”在自动层面成立。

## 7. 完整赛道 + 回归（判据 6）

**窗口化实跑**（真实窗口，非 `--headless`，13:00:32 完成）：

```
D:\Godot_v4.7-stable_win64_console.exe --path D:\GAMESTUDIO\TURBBIT \
    res://scenes/stage3_playtest.tscn
```

| 项 | 结果 |
|---|---|
| run 1 | passed 55/55，accidents 0，score 9500，grade S，time 268.9 s |
| run 2（从结算 Retry） | passed 55/55，accidents 0，score 9500，grade S，time 268.8 s |
| 三区 | zones=[1,2,3]，max_accident 0.00 s，max_stuck 0.0 s，failures=0 |
| SCRIPT ERROR | stdout 0 条，stderr 0 字节 |
| 结论行 | `STAGE3 PLAYTEST: PASS`（`logs/phase-j/playtest-windowed.log`，同时写到 `docs/reports/stage3-run.log`） |

这个跑通是**自动驾驶**：按固定时序驱动，零事故。它只证明“主流程能从头跑到尾、
关卡数据没被本轮弄坏”，**不证明难度合适**。

**回归**（headless，各自 stderr 0 字节）：

| 场景 | 结果 |
|---|---|
| `stage4_flow` | `STAGE4 FLOW: PASS` |
| `stage4_hud_priority` | `STAGE4 HUD PRIORITY: PASS` |
| `stage4_bilingual` | `STAGE4 BILINGUAL: PASS` |
| `stage4_bro_meter` | `STAGE4 BRO METER: PASS` |

**`best.json`**：跑前备份（`logs/phase-j/best.before.json`），
测试把它改成 `best_time=268.84 / best_score=9500 / best_streak=55`，
跑完已还原，`cmp` 与备份逐字节一致：

```json
{"score_model":2,"best_time":296.63,"best_accidents":0,"best_score":-1,"best_streak":54}
```

## 8. 普通失误可挽救（任务书 J 的一项，Phase F 已做，本轮只复核没被破坏）

- 坠水不是即死：兔子落水后有 **3.2 s** 主动救援窗口，2.0 s 内开始下潜都能接住；
  没接住也只在 0.8 s 后被“冲回壳上”，本局继续，不叠加第二次事故。
- 其它失误（撞鸟/岩/梁/鲨）走 BRO METER：当场记 1 格 + −100，第三格才播 1.4 s
  联合惩罚，随后复位、清格、1.5 s 宽限。也就是说三次普通失误才抵一次“大事故”。
- 本轮的两圈窗口化实跑里 `max_accident=0.00 s`、`failures=0`，说明这条链没被
  Phase I/J 的改动碰坏；但它是自动驾驶跑的，不能当作“真人失误后救得回来”的证据。
- 细节与截图见 `PHASE-F-RESCUE.md`、`PHASE-G-PENALTY.md`。

## 9. 结构（为什么说“逐步掌握”，但仍需真人）

- 7 类障碍在 Z1 全部登场，顺序是 鸟 → 岩 → 梁 → 鲨 → 门 → 浮木 → 高墙，
  位置 1300–13300 px（从 x=400 起算约 59 s），每类都先教一次。
- 组数按区递增：Z1 12 组、Z2 19 组、Z3 24 组；区速 220 → 240 → 260。
- 连招从 log1（Z1 末）开始，贯穿到 Z3；高墙只在每区一面，出现频率低于浮木。
- 每一区都同时混着 7 类，不存在“整段只用一种操作”的章节；55 组里**没有任何两个
  相邻组是同一种类**，不会出现“同一操作连按五六次”的段落。
- **单键通关不成立**：单独按住下潜只覆盖 38/55，剩下 17 组要么必须跳/趴/跃，
  要么必须连招；**持续等待也不成立**：54 个空档都 ≥3.85 s 但没有任何一段需要
  “等很久才轮到输入”。
- 这套结构在自动数据上符合“先教、再重复、再加密”，但是否**感觉**逐渐变难，
  第 7 条仍为 NOT TESTED。

## 10. 本轮没做什么 / 限制

- **没有任何玩法、关卡、参数改动**；`scripts/` 下只新增/修改测试探针。
- 所有“能不能过”都是自动驾驶探针结论；`NOT TESTED` 的部分不能用它们代填。
- 下潜覆盖 38/55 是全场最高覆盖率。本轮只把它当判据 5 的数据，不改——
  真正给下潜加成本会动 GDD 核心规则，属于制作人决策（`PHASE-H-ZONE-SPACE.md` §9 同结论）。
- 密扫分辨率：Z3 一档 40 px，容差 0.154 s 恰好是一档，属于下界。
- 720p 窗口下 15 px 字号实际按 0.8 缩放到 12 px（Phase I 遗留，未改）。
- 本机 OS 键位注入被拒，窗口化实跑仍是引擎内代理，不是真人按键。
