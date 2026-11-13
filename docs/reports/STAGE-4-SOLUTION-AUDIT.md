# STAGE 4 — 55 组解法空间审计（真实输入探针）

日期：2026-11-12 · `STAGE=4` · 只审计，未改玩法。

## 方法

- 对现有 55 组障碍逐组传送至 `组起点 − lead`，用真实按键（`Input.action_press`）操作，
  `GameManager` 控制权切换与正式比赛一致；每组每方案扫 1–3 个时机（lead 320/240/160 px）。
- 7 种方案：只跳（兔子）、只趴（兔子）、只潜（乌龟，最早时机）、只跃（乌龟，3 个时机）、
  跳后潜（兔子跳→空中 SHIFT→乌龟 ↓）、跃后二段跳（乌龟跃→SHIFT→兔子 ↑）、不操作。
- 加速带全部关闭（审计基速 220/240/260）；每个 case 前重置事故、氧气、接人、判定脏标记。
- 记录：是否通过、兔撞/龟撞（按判定框相交通道判定）、落水、接人失败、操作时间、氧气消耗、终态。
- 运行：4 个分片并行，`Engine.time_scale=8`、480 ticks/s（每步 1/60 s），
  日志 `docs/reports/logs/solution-audit-a..d.log`，矩阵 `docs/reports/stage4-solution-matrix.json`。
- **这是自动驾驶代理，不是真人**；时序余量按 1/60 s 物理步长测量。

## 结论（先看这里）

1. **乌龟下潜是万能解：55/55 组全过。** 每组最好时机都在 `start−320`，
   最深 483–484 px（`DIVE_DEPTH=150` 打满），氧气按组消耗 0.3–2.8。
2. **乌龟跃起接近万能：46/55。** 只在 5 组低梁（梁顶 174 太高）和 5 组浮木上失败；
   成功组里兔子被带到 y≈26–74，已经贴近/进入 HUD 区。
3. **8 组漂浮木不必须“跳跃+下潜”**：8/8 只下潜就能过（0.3–0.45 氧气），
   3/8（Z3 的 35/46/52）只跃起也能过；只跳 0/8。设计标签被实测证伪。
4. **没有任何一组“必须”用设计答案**：设计答案总在可行集里，但从未是唯一解；
   DIVE_GATE 也只有“下潜/跳后潜”两种，后者本质仍是下潜。
5. **BRO OLLIE 目前不是连招**：`leap_jump` 的兔子二段跳一次都没触发
   （`second_jump=false`，被 `leap_active` 锁死）；它能过的组都是乌龟跃起单独过的。
6. **接人/落水**：所有失败 case 的落水都发生在跳跃后没有可接的壳；
   组合浮木的成功 case 全部依赖尾端自动上浮，玩家在“接人”阶段没有主动输入。

## 表 1 · 按类别汇总（通过组数 / 组数）

| 类别 | 组数 | 设计答案 | 只跳 | 只趴 | 只潜 | 只跃 | 跳后潜 | 跃后二段 | 不操作 |
|---|---|---|---|---|---|---|---|---|---|
| LOW_BIRD | 9 | crouch | 9 | 9 | 9 | 9 | 0 | 9 | 0 |
| LOW_BEAM | 9 | crouch | 9 | 9 | 9 | 4 | 0 | 4 | 0 |
| SURFACE_ROCK | 12 | jump | 12 | 0 | 12 | 12 | 0 | 12 | 0 |
| SHARK | 9 | leap | 0 | 0 | 9 | 9 | 0 | 9 | 0 |
| DIVE_GATE | 8 | dive | 0 | 0 | 8 | 0 | 8 | 0 | 0 |
| FLOATING_LOG | 8 | dive_jump | 0 | 0 | 8 | 3 | 8 | 3 | 0 |

## 表 2 · 55 组逐组可行解

| # | 区 | 类别 | 设计答案 | 实测可行方案 | 方案数 |
|---|---|---|---|---|---|
| 00 | Z1 | LOW_BIRD | crouch | jump,crouch,dive,leap,leap_jump | 5 |
| 01 | Z1 | SURFACE_ROCK | jump | jump,dive,leap,leap_jump | 4 |
| 02 | Z1 | LOW_BEAM | crouch | jump,crouch,dive | 3 |
| 03 | Z1 | SURFACE_ROCK | jump | jump,dive,leap,leap_jump | 4 |
| 04 | Z1 | LOW_BIRD | crouch | jump,crouch,dive,leap,leap_jump | 5 |
| 05 | Z1 | SHARK | leap | dive,leap,leap_jump | 3 |
| 06 | Z1 | DIVE_GATE | dive | dive,dive_jump | 2 |
| 07 | Z1 | LOW_BEAM | crouch | jump,crouch,dive | 3 |
| 08 | Z1 | SHARK | leap | dive,leap,leap_jump | 3 |
| 09 | Z1 | DIVE_GATE | dive | dive,dive_jump | 2 |
| 10 | Z1 | FLOATING_LOG | dive_jump | dive,dive_jump | 2 |
| 11 | Z1 | SURFACE_ROCK | jump | jump,dive,leap,leap_jump | 4 |
| 12 | Z2 | LOW_BEAM | crouch | jump,crouch,dive | 3 |
| 13 | Z2 | SURFACE_ROCK | jump | jump,dive,leap,leap_jump | 4 |
| 14 | Z2 | SHARK | leap | dive,leap,leap_jump | 3 |
| 15 | Z2 | DIVE_GATE | dive | dive,dive_jump | 2 |
| 16 | Z2 | LOW_BIRD | crouch | jump,crouch,dive,leap,leap_jump | 5 |
| 17 | Z2 | FLOATING_LOG | dive_jump | dive,dive_jump | 2 |
| 18 | Z2 | SURFACE_ROCK | jump | jump,dive,leap,leap_jump | 4 |
| 19 | Z2 | LOW_BEAM | crouch | jump,crouch,dive | 3 |
| 20 | Z2 | SHARK | leap | dive,leap,leap_jump | 3 |
| 21 | Z2 | SURFACE_ROCK | jump | jump,dive,leap,leap_jump | 4 |
| 22 | Z2 | DIVE_GATE | dive | dive,dive_jump | 2 |
| 23 | Z2 | LOW_BIRD | crouch | jump,crouch,dive,leap,leap_jump | 5 |
| 24 | Z2 | FLOATING_LOG | dive_jump | dive,dive_jump | 2 |
| 25 | Z2 | SURFACE_ROCK | jump | jump,dive,leap,leap_jump | 4 |
| 26 | Z2 | LOW_BEAM | crouch | jump,crouch,dive | 3 |
| 27 | Z2 | SHARK | leap | dive,leap,leap_jump | 3 |
| 28 | Z2 | LOW_BIRD | crouch | jump,crouch,dive,leap,leap_jump | 5 |
| 29 | Z2 | FLOATING_LOG | dive_jump | dive,dive_jump | 2 |
| 30 | Z2 | DIVE_GATE | dive | dive,dive_jump | 2 |
| 31 | Z3 | SHARK | leap | dive,leap,leap_jump | 3 |
| 32 | Z3 | LOW_BEAM | crouch | jump,crouch,dive,leap,leap_jump | 5 |
| 33 | Z3 | SURFACE_ROCK | jump | jump,dive,leap,leap_jump | 4 |
| 34 | Z3 | DIVE_GATE | dive | dive,dive_jump | 2 |
| 35 | Z3 | FLOATING_LOG | dive_jump | dive,leap,dive_jump,leap_jump | 4 |
| 36 | Z3 | LOW_BIRD | crouch | jump,crouch,dive,leap,leap_jump | 5 |
| 37 | Z3 | SHARK | leap | dive,leap,leap_jump | 3 |
| 38 | Z3 | LOW_BEAM | crouch | jump,crouch,dive,leap,leap_jump | 5 |
| 39 | Z3 | SURFACE_ROCK | jump | jump,dive,leap,leap_jump | 4 |
| 40 | Z3 | DIVE_GATE | dive | dive,dive_jump | 2 |
| 41 | Z3 | FLOATING_LOG | dive_jump | dive,dive_jump | 2 |
| 42 | Z3 | LOW_BIRD | crouch | jump,crouch,dive,leap,leap_jump | 5 |
| 43 | Z3 | SHARK | leap | dive,leap,leap_jump | 3 |
| 44 | Z3 | LOW_BEAM | crouch | jump,crouch,dive,leap,leap_jump | 5 |
| 45 | Z3 | SURFACE_ROCK | jump | jump,dive,leap,leap_jump | 4 |
| 46 | Z3 | FLOATING_LOG | dive_jump | dive,leap,dive_jump,leap_jump | 4 |
| 47 | Z3 | LOW_BIRD | crouch | jump,crouch,dive,leap,leap_jump | 5 |
| 48 | Z3 | SHARK | leap | dive,leap,leap_jump | 3 |
| 49 | Z3 | LOW_BEAM | crouch | jump,crouch,dive,leap,leap_jump | 5 |
| 50 | Z3 | SURFACE_ROCK | jump | jump,dive,leap,leap_jump | 4 |
| 51 | Z3 | DIVE_GATE | dive | dive,dive_jump | 2 |
| 52 | Z3 | FLOATING_LOG | dive_jump | dive,leap,dive_jump,leap_jump | 4 |
| 53 | Z3 | LOW_BIRD | crouch | jump,crouch,dive,leap,leap_jump | 5 |
| 54 | Z3 | SURFACE_ROCK | jump | jump,dive,leap,leap_jump | 4 |

## 表 3 · 8 组漂浮木逐组证伪

| # | 区 | 只跳 | 只潜 | 只跃 | 跳后潜 | 可行方案 |
|---|---|---|---|---|---|---|
| 10 | Z1 | 不过 | 过 | 不过 | 过 | dive,dive_jump |
| 17 | Z2 | 不过 | 过 | 不过 | 过 | dive,dive_jump |
| 24 | Z2 | 不过 | 过 | 不过 | 过 | dive,dive_jump |
| 29 | Z2 | 不过 | 过 | 不过 | 过 | dive,dive_jump |
| 35 | Z3 | 不过 | 过 | 过 | 过 | dive,leap,dive_jump,leap_jump |
| 41 | Z3 | 不过 | 过 | 不过 | 过 | dive,dive_jump |
| 46 | Z3 | 不过 | 过 | 过 | 过 | dive,leap,dive_jump,leap_jump |
| 52 | Z3 | 不过 | 过 | 过 | 过 | dive,leap,dive_jump,leap_jump |

**关键数**：8 组里只潜 8/8 过，最好时机 lead 320，耗时 2.55–3.00 s，
氧气 0.33–0.45；跳后潜 8/8 过，最好时机 lead 160/240，耗时 1.97–2.23 s，氧气 0。
连招比单纯下潜只快 0.3–0.5 s，没有“必须”的收益。

## 表 4 · 各方案代表耗时 / 氧气（中位数）

| 类别 | 指标 | 只跳 | 只趴 | 只潜 | 只跃 | 跳后潜 |
|---|---|---|---|---|---|---|
| LOW_BIRD | 秒 | 2.15 | 1.97 | 2.63 | 1.97 | - |
| LOW_BIRD | 氧气 | 0.00 | 0.00 | 2.23 | 0.00 | - |
| LOW_BEAM | 秒 | 2.22 | 2.22 | 2.88 | 2.06 | - |
| LOW_BEAM | 氧气 | 0.00 | 0.00 | 2.48 | 0.00 | - |
| SURFACE_ROCK | 秒 | 2.12 | - | 2.68 | 2.02 | - |
| SURFACE_ROCK | 氧气 | 0.00 | - | 2.28 | 0.00 | - |
| SHARK | 秒 | - | - | 2.47 | 1.80 | - |
| SHARK | 氧气 | - | - | 2.07 | 0.00 | - |
| DIVE_GATE | 秒 | - | - | 2.93 | - | 2.27 |
| DIVE_GATE | 氧气 | - | - | 0.53 | - | 0.00 |
| FLOATING_LOG | 秒 | - | - | 2.67 | 1.93 | 2.18 |
| FLOATING_LOG | 氧气 | - | - | 0.41 | 0.00 | 0.00 |

## 对后续步骤的约束（不是本轮改动）

- **步骤 2（跳跃）**：最高点 180–200 px、滞空 1.1–1.2 s 换算 g≈1120、v≈−644。
  但当前 8 组浮木的地形（宽 140、下沿 384、尾端自动上浮 260 px）在 1.15 s 滞空下
  数学上接不上：下潜准备 + 横穿 + 回浮所需时间超过滞空。浮木必须同步改几何
  （下沿抬高、宽度收窄、缩短自动上浮段），否则“降跳跃”会直接破坏组合。
- **步骤 3（BRO DIVE）**：纯下潜已 0 成本通过 8/8；组合要有价值，必须让“只潜”
  在空间上不成立，或让玩家必须主动收潜接人（当前是自动上浮自动接人，玩家没事做）。
- **步骤 4（BRO OLLIE）**：兔子在 `leap_active` 期间完全不能起跳，二段从未触发；
  需要独立输入窗口 + 独立轨迹 + 真正“乌龟单跃过不去”的高墙几何。
- **步骤 5（几何）**：下潜万能解靠“水体无下限 + 障碍不下延”，优先用空间约束
  （水下阻挡/支撑结构/更深的鲨鱼）解决，而不是加氧气代价。

## 证据与限制

- 矩阵：`docs/reports/stage4-solution-matrix.json`（55 行 × 7 方案 × 每个 lead 的逐次记录）。
- 日志：`docs/reports/logs/solution-audit-a.log` … `-d.log`。
- 代理测试，非真人；真人试玩仍 **NOT TESTED**。
- 本审计未改任何玩法参数；所有数字对应审计时的 `HEAD` 物理。
