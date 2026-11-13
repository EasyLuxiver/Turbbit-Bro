# PHASE P — 食物后障碍的随机抽取与种子复现

任务：`TBB-LONGRUN-PLAYABILITY-02` §二（随机障碍系统）/ §七-4
日期：2026-11-12
阶段：STAGE 4（未进入 STAGE 5）
性质：**接入正式赛道**（`race.tscn` 的 55 组关卡），不是独立测试场景。

> 证据类型：
> - 自动化测试：`stage4_snack_draw.gd`（结构检查 + 真实物理 + 引擎按键代理，headless）
> - 窗口化自动输入：`--capture-snack ... --seed 424242 --snack-index 2` 截图，**不是真人试玩**
> - 真人试玩：`NOT TESTED`
>
> **流程偏差（R009）**：本阶段的验收标准是在实现之后才用 `qc.py start` 登记的
> （任务 `tbb-stage4-snack-draw`），不符合“动手前写验收标准”。判定记录保留这次
> 偏差，不追溯修改时间戳；证据本身可复核。

## 0. 一句话结果

9 个食物遭遇里，第 1 个保持固定（Z1 教学用梁），其余 8 个在**关卡装载时**按
`LEVEL SEED` 从本区池抽取，日志逐条打印；同种子两次装载完全一致。
抽到的种类只换“这一格是什么”，组起点不动，55 组仍 55/55 有解。
实测：吃下食物后在抽到的障碍处仍加速，按该种类设计答案通过，预警 4.30 / 4.70 s。

## 1. 实现

| 文件 | 改动 |
|---|---|
| `scripts/systems/level_data.gd` | `SNACK_DRAW_POOL`；`taught_kinds_before()`；`is_complex_kind()`；`plan_snack_draws()`（纯函数）；`apply_snack_draws()` |
| `scripts/race.gd` | `DEFAULT_LEVEL_SEED=20261112`、`level_seed`、`snack_draws`；`--seed N`；装载时抽定并打印；`--snack-index N` 让截图能拍任意一段 |
| `scripts/test/stage4_snack_draw.gd` + `scenes/stage4_snack_draw.tscn` | 23 项检查：结构 + 两个真实物理案例 |

### 池子与“复杂障碍不进加速遭遇”

制作人 §二 的原池保留在 `ZONE_OBSTACLE_POOL`。实际抽取用 `SNACK_DRAW_POOL`
（去掉了高墙/浮木），依据是 PHASE-N §6 的实测：

| 种类 | 加速 ×1.15 后第一段窗口 | 能否进抽取 |
|---|---|---|
| 低飞鸟 / 码头梁 | 整个接近段（按住即可） | ✅ |
| 水面岩 | 0.534 s | ✅ |
| 礁门 | 整个接近段（按住下潜） | ✅ |
| 鲨鱼 | 0.585 s | ✅ |
| 浮木（BRO DIVE） | 0.33 s | ❌ |
| 高墙（BRO OLLIE） | 0.23 s | ❌ |

复杂连招仍在固定关卡里出现 16 次（巡航速度、前面留 5.19 s 准备段），
所以“复杂组合”这一课没有消失，只是不作为食物加速的随机结果。
Z3 剔除墙/木后只剩岩，补进梁/鲨两种**已教学**单角色障碍，保证抽取有变化：

```gdscript
const SNACK_DRAW_POOL := {
	1: ["LOW_BIRD", "LOW_BEAM", "SURFACE_ROCK"],
	2: ["DIVE_GATE", "SHARK"],
	3: ["SURFACE_ROCK", "LOW_BEAM", "SHARK"],
}
```

### 抽取规则（全部在 `plan_snack_draws` 里一次性定完）

1. 第 1 个遭遇固定为关卡原种类（§五：第一次食物加速用固定、简单、宽容的障碍）。
2. 其余从本区 `SNACK_DRAW_POOL` 抽；过滤掉“该 x 之前还没教过”的种类。
3. 同区不连续抽到同一种（“不许连着两次同一种高压障碍”）。
4. 不含高墙/浮木（见上）。
5. 结果在**装载时**就定死，不随玩家吃不吃改变；玩家只改变到达时的速度。
6. 种子固定默认 `20261112`，可用 `-- --seed N` 或 `race.level_seed = N` 换一套；
   日志第一行 `LEVEL SEED <n>`，下面 9 行是逐条结果。

### 宽度与间距

组的起点 x 不动；宽度优先用该种类的自然宽度（判定与画面对得上），
若自然宽度会让“下一组”的间距低于 3.5 s 基线，就退回原槽位宽度。
55 组、组名、组起点都不变。

## 2. 实测

日志：`docs/reports/logs/phase-p/draw.log`；数据：`docs/reports/longrun/phase-p-draw.json`。

```
SNACK DRAW: DONE checks=23 fails=0
```

### 种子与序列

| seed | 9 次抽取（#1 固定） |
|---|---|
| 424242 | BEAM, ROCK, **SHARK**, **GATE**, SHARK, **BEAM**, **SHARK**, **ROCK**, **BEAM** |
| 7 | BEAM, ROCK, **SHARK**, **GATE**, SHARK, **BEAM**, **SHARK**, **BEAM**, **SHARK** |
| 20261112（默认） | BEAM, ROCK, **SHARK**, **GATE**, SHARK, **ROCK**, **BEAM**, **ROCK**, **BEAM** |
| 99 | BEAM, **BIRD**, **GATE**, **SHARK**, **GATE**, SHARK, **ROCK**, **BEAM**, **SHARK** |

（粗体 = 与关卡原种类不同；池子只有 2–3 个候选，所以有的格子会抽回原种类。）

### 真实物理（两个方向都覆盖）

| seed | 遭遇 | 抽到 | 吃下 | 到障碍时加速 | 最高速 | 预警 | 结果 |
|---|---|---|---|---|---|---|---|
| 424242 | #3 gate3 | SHARK | ✅ | ✅ | 276.0 | **4.30 s** | 过鲨，无事故，仍骑乘 |
| 99 | #2 rock3 | LOW_BIRD | ✅ | ✅ | 253.0 | **4.70 s** | 过鸟，无事故，仍骑乘 |

两个案例分别在 Z2 / Z1，一个乌龟解法、一个兔子解法，证明抽换后
“吃 → 加速 → 换角色 → 按该种类的答案”整条链在真实物理下成立。

## 3. 截图

- `screenshots/stage4_snack_draw.png` — 食物在 x=18950，后方 450 px 是**抽到的鲨鱼**（原为礁门），
  水里同时能看到它上沿露出水面；HUD 显示 `SNACK AHEAD`，底部提示 `SHIFT + ↑ TURTLE LEAP`。
- `screenshots/stage4_snack_draw_gulp.png` — 吞食瞬间。
- `screenshots/stage4_snack_draw_turbo.png` — `TURBO ACTIVE` / `BOOSTING`，速度线，鲨鱼在前。

## 4. 回归

| 测试 | 结果 |
|---|---|
| `stage4_snack_draw` | **PASS 23/23** |
| `stage4_snack_rush` | **PASS 3/3**（第一个固定遭遇不受抽取影响） |
| `stage3_selftest` | **PASS** |
| `stage4_metrics` | **PASS**（55 组间距门槛不变） |
| `stage4_level_audit` | **PASS**（静态关卡 55 组 / 0 无解） |
| `stage4_solution_audit`（装载默认种子后的**实际关卡**） | `no_solution=[]`；7 类全部 `design_correct` 等于组数 |
| `stage4_lesson_prompt` / `stage4_window_audit` | 跑通，判定与改前一致 |
| `best.json` | 未变（`296.63 / 0 / -1 / 54`，测试前后核对） |

`solution_audit` 的逐类结果（默认种子）：LOW_BIRD 9/9、SURFACE_ROCK 13/13、
LOW_BEAM 10/10、SHARK 5/5、DIVE_GATE 7/7、FLOATING_LOG 8/8、HIGH_WALL 3/3。

## 5. 设计约束对照（§二）

| 要求 | 落实 |
|---|---|
| 结果在本局遭遇开始前确定 | 装载时一次抽定，日志逐条可查 |
| 固定种子记录 + 同种子复现 | `DEFAULT_LEVEL_SEED` + `LEVEL SEED` 日志；同种子两次 plan 完全一致 |
| 不在同一小节连续重复同一种高压障碍 | 同区不连续同名 |
| 不生成没有合法通行方案的组合 | 只换单组；55/55 有解、设计答案全中 |
| 不把两个复杂障碍连在一起 | 加速遭遇不含复杂障碍 |
| 未教学的障碍不得突然出现 | `taught_kinds_before(x)` 过滤 |
| 首次可见到碰撞 ≥4 s（普通） | 实测 4.30 / 4.70 s；理论最差 Z3 4.00 s |
| 预警按加速后速度重算 | 探针在 276 / 253 px/s 下测 |
| 不通过降速掩盖窗口 | 未改任何速度；抽换与加速独立 |

**未达成 / 由制作人裁决的点**：§二 的“双角色复杂障碍 ≥5 s 预警”在当前
1100 px 视野下数学上不可能（Z3 巡航 260 px/s 上限 4.23 s）。本轮按 PHASE-N §7
的处置：复杂障碍不进加速抽取池；固定关卡里的 16 组复杂障碍沿用 5.19 s 准备段。
这一条需要在制作人处确认口径（Phase Q）。

## 6. 复现命令

```bash
# 结构与真实物理（23 项）
D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage4_snack_draw.tscn > docs/reports/logs/phase-p/draw.log 2>&1

# 换一套抽法 / 窗口化截图（引擎内部自动输入，不是真人）
D:/Godot_v4.7-stable_win64_console.exe --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/race.tscn -- --seed 424242 --capture-snack stage4_snack_draw.png --snack-index 2
```

## 7. 已知问题 / 下一步

1. 默认种子下 Z1 的第 2 个遭遇抽回岩石（与原来相同），Z1 的抽取变化要换种子才看得到；
   这是池子小 + 无连续重复规则的正常结果，不是 bug。
2. “复杂障碍 ≥5 s”口径未决（见 §5）。
3. 其余 8 段食物遭遇还没逐段在“吃 / 不吃”两条路径上实测（§五，下一步）。
4. 食物/障碍美术仍是 `_draw` 灰盒。
5. 真人是否觉得“随机 + 加速”有判断乐趣：`NOT TESTED`。

## 8. QC 判定（`tbb-stage4-snack-draw`）

| # | 标准 | 判定 | 证据 |
|---|---|---|---|
| 1 | 装载时按日志 `LEVEL SEED` 定种类，第一个固定 | **pass** | `draw.log` 的 SEED + 9 行 DRAW；`stage4_snack_draw` first_fixed |
| 2 | 同种子两次一致；换种子变化 | **pass** | same_seed_repro_* 4 条、seeds_vary |
| 3 | 池内 / 已教学 / 不连续重复 / 不含复杂 | **pass** | pool_member、taught_first、no_consecutive_repeat、no_complex_in_snack |
| 4 | 不改组数与组起点；55/55 有解 | **pass** | level_ok_*；`solution-audit.log` `no_solution=[]` |
| 5 | 吃后到障碍仍加速、能过、预警 ≥4 s | **pass** | 两个 physics case（4.30 / 4.70 s） |
| 6 | 回归全过、best.json 不变 | **pass** | §4 表 |
| 7 | 真人觉得随机遭遇公平、可读 | **NOT TESTED** | 需真人 |

## 9. 限制

- 抽取是“按种类换格子”，不是自由生成位置；这是为了避免破坏 55 组已验证的间距。
- 物理探针只验证两条确定性路径（吃 → 过），不验证“边跑边判断”。
- 引擎按键代理不是真人键位；窗口化截图是引擎内自动输入。
