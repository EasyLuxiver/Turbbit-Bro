# PHASE-P-ZONES — 三区 9 段食物遭遇逐段实测

结论：默认种子 `20261112` 下 18/18 通过（9 段 × 吃 / 不吃两条路径）；
换种子 `424242` 同样 18/18，抽到种类有变化。吃下会按设计提速并干净过障碍、
之后回到当前区巡航；不吃不扣任何东西，两条路径都能过。

- 探针：`scripts/test/stage4_snack_zones.gd`（`scenes/stage4_snack_zones.tscn`）
- 数据：`docs/reports/longrun/phase-p-zones.json`（默认种子）、
  `phase-p-zones-seed20261112.json`、`phase-p-zones-seed424242.json`
- 日志：`docs/reports/logs/phase-p/zones.log`、
  `zones-seed424242.log`（stderr 均为空）
- 证据类型：**自动化测试 / 引擎按键代理**，不是真人试玩。真人仍 `NOT TESTED`。
- QC：`tbb-stage4-snack-zones`，6/6 pass（`python ../LESSONS/CHECKS/qc.py status --task tbb-stage4-snack-zones`）。

## 1. 测法

探针在 `GameManager.start_race()` 产生的**正式 race 场景**上跑，不建假关卡：

1. `race.load_level(LevelData.groups(), LevelData.boost_lanes())`——和正式开局同一入口，
   `--seed` / 默认种子在这里生效，日志先打印 `LEVEL SEED` 和 9 行 `SNACK DRAW`。
2. 从障碍组表里读该遭遇的 `obstacle_group` 的起止 x，起点取
   `min(food_x − 320, 首次可见 x − 40)`，并保证不早于上一组结束 + 60 px。
3. 两条路径：
   - **eat**：乌龟受控经过食物（自动吃下）→ 食物后 +10 px 切到该种类的设计操控者
     → 按 PHASE-N 实测窗口中段的 lead 按键。
   - **skip**：兔子受控经过食物（不吃）→ 食物后 +120 px 切回设计操控者 → 同样按键。
4. 到障碍组末 +260 px 停，等 TURBO 真正结束，再等速度落回**当前区**巡航速
   （最多 1.5 s；跨 Z1→Z2 时 base 从 220 变 240，探针按当前 base 判，不写死）。
5. 记：吃没吃、到障碍时速度 / 是否仍在 TURBO / 最高速、事故、氧气、BRO、
   是否仍骑乘、出遭遇后速度、预警。

## 2. 结果（默认种子 20261112）

| # | 区 | 组 | 抽到 | eat 到障碍速度 | eat 出遭遇 | skip 到障碍速度 | 预警设计/实测 (s) | 结论 |
|---|---|---|---|---|---|---|---|---|
| 1 | Z1 | beam1 | LOW_BEAM | 253（×1.15） | 220 | 220 | 4.73 / 4.70 | PASS |
| 2 | Z1 | rock3 | SURFACE_ROCK | 253 | 220 | 220 | 4.73 / 4.70 | PASS |
| 3 | Z2 | gate3 | SHARK | 276 | 240 | 240 | 4.34 / 4.30 | PASS |
| 4 | Z2 | rock6 | DIVE_GATE | 276 | 240 | 240 | 4.34 / 4.32 | PASS |
| 5 | Z2 | shark5 | SHARK | 276 | 240 | 240 | 4.34 / 3.87* | PASS |
| 6 | Z3 | shark8 | SURFACE_ROCK | 299 | 260 | 260 | 4.00 / 3.37* | PASS |
| 7 | Z3 | beam8 | LOW_BEAM | 299 | 260 | 260 | 4.02 / 3.20* | PASS |
| 8 | Z3 | shark9 | SURFACE_ROCK | 299 | 260 | 260 | 4.00 / 3.37* | PASS |
| 9 | Z3 | gate8 | LOW_BEAM | 299 | 260 | 260 | 4.00 / 3.37* | PASS |

- `*` 实测值偏小是因为探针起点被**上一组障碍**占住了首次可见位置（起点被
  `prev_end + 60` 抬高），它不是“玩家看到障碍的时长”。验收用设计值：
  从障碍首次进入 1100 px 视野算起，按巡航段 + 加速段实际速度积分。
  设计值最小 4.005 s（Z3），Z1 4.73 s，Z2 4.34–4.58 s。
- 9 段 eat 全部：吃到、过障碍时仍在 TURBO、最高速 > 巡航 ×1.08、干净通过、回巡航。
- 9 段 skip 全部：未吃到、到障碍仍是巡航速、跳过食物瞬间氧气 = 8.0 / BRO = 0 /
  无事故、干净通过。**氧气的采样点是“食物飘过那一刻”**：之后的主动下潜
  （如 DIVE_GATE 的答案是下潜）本来就耗氧，那是玩法不是不吃的惩罚。
- 18 行全部 `hit=false`、`accident=NONE`、`riding=true`。

## 3. 换种子

`--seed 424242`：同样 18/18 通过；Z3 #6 抽到 `LOW_BEAM`（默认种子是
`SURFACE_ROCK`），#7 抽到 `SHARK`（默认是 `LOW_BEAM`）。说明随机确实改变结果，
且每种结果都有可过解法。日志 `docs/reports/logs/phase-p/zones-seed424242.log`。

## 4. 这一步没有改游戏

本步只新增探针与测量口径，`race.gd` / `level_data.gd` / 物理参数均未改。
食物遭遇在上一步（#4）已经接入正式关卡；这一步是把它逐段跑通、量出数。

## 5. 已知问题 / 留给下一步

- **Z3 的 “双角色复杂障碍 ≥5 s” 仍不成立**：Z3 车速 260，1100 px 视野最多
  4.23 s；设计值上限 4.00–4.02 s。这个口径与物理上限冲突，属制作人决策项，
  已在 `PHASE-P-DRAW.md` 记录（当前做法：随机池排除 `HIGH_WALL` / `FLOATING_LOG`）。
- 实测预警低于设计值只出现在探针起点被前一组占位时；下一步（§七-6）若要把
  “实测”也做到 ≥4 s，需要让探针从前一组障碍之前起跑并全程记录，而不是改游戏。
- 本步只覆盖**单段**遭遇；连续多段的体力/注意力负担留给 §七-8 难度曲线。

## 6. 复现

```
D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
    res://scenes/stage4_snack_zones.tscn -- --seed 20261112 \
    > docs/reports/logs/phase-p/zones.log 2>&1
```

末行应为 `SNACK ZONES: DONE rows=18 fails=0`（换 `--seed 424242` 同样）。
