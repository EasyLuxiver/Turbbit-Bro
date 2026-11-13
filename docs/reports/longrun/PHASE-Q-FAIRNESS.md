# PHASE Q — §七-6 修正不公平的预警时间

日期：2026-11-12
阶段：STAGE 4（未进入 STAGE 5）
性质：**只移动 Z3 的 9 个障碍组 x**；不动车速、不动视野、不动跳跃/下潜参数、
不动障碍几何、不动随机池。

> 证据类型：设计值核算（真实物理积分）+ headless 真实物理探针（引擎按键代理）。
> **不是真人试玩**；真人仍 `NOT TESTED`。

## 1. 一句话结论

食物遭遇里唯一低于 4 s 的预警是 **shark8 → beam8 的连锁加速**：上一段的 TURBO
尾巴还在，下一段障碍已经进入 1100 px 视野，最坏抽法下首次可见 → 碰撞只有
**3.833 s**。把 shark8 之后的组右移 110–420 px 后，9 段全部 **≥4.017 s**，
其余规则（55 组、间距、55/55 有解、两个种子 18/18）全部保持。

## 2. 问题：视野 1100 px 比组间距更长

- 摄像机在 `turtle.x + 300`，视口 1600 宽 → 前方可见 **1100 px**。
- Z3 的组间距原本是 1070 px（shark8 53550 → beam8 54620）。
- 于是 beam8 在乌龟还在 shark8 前面 100 px 时就已可见；若玩家吃了 shark8 的食物，
  TURBO 一直到 `shark8 尾端 + 180 px` 才结束，**前 280–380 px 的接近段是 299 px/s**。
- 按 1.15× 实际速度积分，最坏（shark8 抽到 LOW_BEAM 宽 170）：
  首次可见 → 碰撞 **3.833 s**，低于 §二 的“普通障碍 ≥~4 s”。

这是**间距**问题，不是加速尾巴的问题：即使把尾巴设为 0，shark8 的碰撞框尾端
（53620）仍在 beam8 的首次可见点（53520）之后，重叠仍有 100 px。

## 3. 改动：只移 Z3 组坐标

| 组 | 改前 x | 改后 x | 位移 |
|---|---|---|---|
| shark8 | 53550 | 53550 | 0 |
| beam8 | 54620 | **55040** | +420 |
| rock10 | 55800 | **56180** | +380 |
| log7 | 57270 | **57640** | +370 |
| bird8 | 58410 | **58640** | +230 |
| shark9 | 59540 | **59720** | +180 |
| beam9 | 60610 | **60820** | +210 |
| rock11 | 61780 | **61940** | +160 |
| gate8 | 62930 | **63040** | +110 |
| log8 | 64460 | **64560** | +100 |
| bird9 / rock12 | 65600 / 66720 | 不变 | 0 |

- 结果：shark8 最宽抽法尾端 53720 + TURBO 尾巴 180 = 53900，
  beam8 首次可见点 53940 —— 加速尾巴不再烧掉下一段的视野。
- 所有组间距保持 **≥930 px（3.58 s）**；组合前保持 **≥1340 px（5.15 s）**。
- 最后一个障碍 rock12（66720）与终点（67600）的距离不变。
- 文件头与 Z3 段落注释已同步写明原因，见
  [level_data.gd:144-170](../../../scripts/systems/level_data.gd#L144-L170)。

## 4. 验证

### 4.1 预警（设计值，最坏抽法）

脚本 `docs/reports/longrun/phase-q-warning-audit.py` 读 `level_data.gd` 现场积分
（accel 420/300，1.15×，60 Hz），并把“上一段吃下的 TURBO 尾巴”算进去：

| 段 | 障碍 | 区速 | 预警 | 判定 |
|---|---|---|---|---|
| 1 | beam1 | 220 | 4.750 | PASS |
| 2 | rock3 | 220 | 4.750 | PASS |
| 3 | gate3 | 240 | 4.350 | PASS |
| 4 | rock6 | 240 | 4.350 | PASS |
| 5 | shark5 | 240 | 4.350 | PASS |
| 6 | shark8 | 260 | 4.017 | PASS |
| 7 | beam8 | 260 | **4.017**（改前 3.833） | PASS |
| 8 | shark9 | 260 | 4.017 | PASS |
| 9 | gate8 | 260 | 4.017 | PASS |

- 改后：`MIN 4.017 s FAILS 0` → `docs/reports/logs/phase-p/warning-audit-after-q.log`
- 改前（`--legacy` 放回旧坐标）：`MIN 3.833 s FAILS 1` →
  `docs/reports/logs/phase-p/warning-audit-before-q.log`

### 4.2 操作窗口（随机池内五类，1.15×）

沿用 `PHASE-N-0154.md` §5 的 5 px 细扫，本轮未改任何几何/速度：

| 种类 | 1.15× 窗口 | 结论 |
|---|---|---|
| SHARK | 0.585 s | ≥0.5 |
| SURFACE_ROCK | 0.534 s | ≥0.5（单侧窗） |
| LOW_BEAM / LOW_BIRD | 按住即成立（整个接近段） | ≥0.5 |
| DIVE_GATE | 按住下潜，窗口很宽 | ≥0.5 |

- 基速下的岩石是 0.432 s（单侧窗），PHASE-N 已记录并接受；随机池里的岩石
  只出现在“已加速”的遭遇，因此按 0.534 s 计。

### 4.3 关卡与回归

| 检查 | 结果 | 日志 |
|---|---|---|
| 55 组、无无解组、设计答案 55/55 | `no_solution=[]`；7 类 design_correct 合计 55 | `solution-audit-after-q.log` |
| 组间距 | `min 3.65 s single / 5.13 s combo`，PASS | `metrics-after-q.log` |
| 关卡审计 | 55 组、9 条加速带、Z3 24 组 | `level-audit-after-q.log` |
| 种子抽取回归 | 默认种子 18/18、种子 424242 18/18 | `zones-after-q.log`、`zones-seed424242-after-q.log` |
| 随机池结构 | `SNACK DRAW: DONE checks=23 fails=0` | `draw-after-q.log` |

## 5. 仍未解决：Z3 双角色复杂障碍 ≥5 s

- Z3 视野上限 = **1100 px / 260 px/s = 4.231 s**，这是任何 Z3 障碍的物理上限；
  §二 的“双角色复杂障碍 ≥~5 s”在现有机位/车速下**做不到**。
- 现有处理：高墙 / 漂浮木**不放进随机抽取池**（PHASE-N §7），只作为固定教学组；
  固定组本身仍在 4.2 s 以内可见，不满足 5 s。
- 这是制作人决策项，三个选项：
  1. 把镜头前瞻从 1100 px 加到 ≥1300 px（会改变画面构图与后方可见量）；
  2. 接受 4.2 s 的 Z3 上限，把“5 s”只当设计目标；
  3. 降低 Z3 车速——**违反 §二“不允许通过降低速度掩盖窗口问题”，不建议**。
- 本轮不擅自改镜头或车速，只记录。

## 6. 已知问题

- `scripts/test/stage4_experience_rework.gd` 里 Phase D 的实验点写死
  `55000 / 55800`（旧 beam8/rock10 附近），改坐标后它们不再对应具体组；
  该实验不在本轮验收链上，未改，读数需按新坐标重取。
- 本轮只动 Z3 后半段；Z1/Z2 的预警本来就 ≥4.34 s，未动。
- 窗口化完整赛道回归（§七-10）还没跑；本轮证据全是 headless。

## 7. 复现

```bash
python docs/reports/longrun/phase-q-warning-audit.py            # 改后 4.017 s
python docs/reports/longrun/phase-q-warning-audit.py --legacy   # 改前 3.833 s

D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage4_snack_zones.tscn -- --seed 20261112
```
