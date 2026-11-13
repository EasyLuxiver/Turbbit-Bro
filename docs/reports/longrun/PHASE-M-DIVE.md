# PHASE M — 下潜不再是“只潜就能过”的万能解

任务：`TBB-LONGRUN-PLAYABILITY-01`
日期：2026-11-12
阶段：STAGE 4（未推进 STAGE 5）
性质：**关卡几何改动，零机制改动**。判定规则、状态机、输入、奖励、惩罚全部没动。

> 证据类型：真实物理的自动驾驶探针（引擎内 InputMap 代理）+ 窗口化实跑。
> **不是真人试玩**；本机 OS 级键位注入被系统拒绝。下面所有“能过/不能过”都是自动结论。

## 0. 一句话结论

给岩和梁各加一段**水下阻挡**（世界 y 402～452）后，单靠“按住 ↓ 下潜”的覆盖率从
**38/55 降到 17/55**——只剩 8 个本来就该下潜的礁门和 9 只水面上方的海鸟；
岩与梁共 21 组，下潜通过数 **0**。55 组仍全部有解、设计答案仍全部成立，
所有难度窗口逐组不变，窗口化实跑两圈 55/55、0 事故。

## 1. 改了什么（`scripts/systems/level_data.gd`）

`KIND_SPEC` 与判定规则没变，只在 `build_group()` 里给 `SURFACE_ROCK` / `LOW_BEAM`
各追加一段矩形：

```gdscript
const ANTI_DIVE_Y := 368.0   # 关卡空间；装载 +34 → 世界 402
const ANTI_DIVE_H := 50.0    # 世界 402～452
if kind == "SURFACE_ROCK" or kind == "LOW_BEAM":
    rects.append(Rect2(spec["x"], ANTI_DIVE_Y, w, ANTI_DIVE_H))
```

为什么是 402～452（全部来自实测几何，不是估的）：

| 位置 | 数值（世界 y） | 说明 |
|---|---|---|
| 巡航龟壳 | 306～362 | 从水下阻挡**上方**过，不碰 |
| 巡航兔身 | 252～300 | 原障碍仍然只压它（岩/梁的设计答案） |
| 下潜龟壳 | 456～512 | 从水下阻挡**下方**过，不碰 |
| 下潜兔身 | 402～450 | **正好被 402～452 压住** |
| 趴低兔身 | 284～308 | 在阻挡上方，梁仍按状态直接放行 |

所以视觉上壳永远不穿模：壳从“上层障碍”和“水下段”之间的缝里过，只有兔子不能
再把身体压进水里躲开。判定路径一行没改——A 类仍只判兔子，趴低仍按状态放行。

`LOW_BIRD` 故意**不加**：海鸟只在水面上，下潜躲鸟在物理上说得通，保留这条合法路线。

## 2. 验收判定（QC `tbb-stage4-dive-dominance`）

| # | 标准 | 判定 | 证据 |
|---|---|---|---|
| 1 | 12 组岩 + 9 组梁，下潜全部失败 | **pass** | `stage4-solution-matrix.json`：SURFACE_ROCK dive 0/12、LOW_BEAM dive 0/9 |
| 2 | 55/55 仍有解，设计答案全过 | **pass** | `no_solution_groups=[]`；design_correct 55/55 |
| 3 | 下潜覆盖 38→≤17，只剩门与鸟 | **pass** | 17 = DIVE_GATE 8 + LOW_BIRD 9（`logs/phase-m/coverage.json`） |
| 4 | 无单一方案 >27/55 | **pass** | 最大 leap 27/55；下潜 17 |
| 5 | J 三项门槛不破 | **pass** | 三片容差扫描重跑，55/55 组通过区间**逐组完全一致**；反应 3.54 s、容差 0.154 s、恢复 3.85 s 不变 |
| 6 | 窗口化两圈 + best.json | **pass** | 55/55×2、0 事故、S、0 SCRIPT ERROR；`best.json` 已还原且逐字节一致 |
| 7 | 回归 | **pass** | 16 个 headless 场景全 exit=0、0 FAIL、stderr 0 字节 |
| 8 | 水下阻挡可见 | **pass** | `screenshots/phase-m_rock_block.png`、`phase-m_beam_block.png`（窗口化 + 引擎内代理） |
| 9 | 结构没退化 | **pass** | 相邻组无同种；7 类全在；本文件与 STAGE-4 §8 自评 |

## 3. 前后对照

| 方案 | 改前 | 改后 | 变化 |
|---|---|---|---|
| dive | 38 | **17** | −21（岩 12、梁 9） |
| leap | 27 | 27 | — |
| dive_jump | 22 | 22 | — |
| jump | 21 | 21 | — |
| crouch | 18 | 18 | — |
| leap_jump | 3 | 3 | — |
| 无解组 | 0 | 0 | — |

逐组差异只有一条：23 行变化里，21 行是“去掉 dive”，另外 2 行（log1 / wall1）
是旧合并文件的索引错位（旧矩阵来自 Phase H 之前的 Z1 位置：墙在 10800、浮木在 13300）。
新矩阵是**一次全量重跑**（2026-11-12T16:33），不是分片合并，Z1 位置与当前
`LevelData.GROUPS` 一致。

## 4. 视觉证据

- `screenshots/phase-m_rock_block.png`：乌龟下潜，兔子撞在水面岩下方那段岩体上，
  “BONK! RABBIT IS STUNNED”、BRO METER 1/3；壳从水下段下面过。
- `screenshots/phase-m_beam_block.png`：码头梁变成“上横梁 + 两根立柱 + 下横梁”的框架，
  兔子埋头撞下横梁；HUD 提示 `↓ CROUCH`，壳在下横梁下面。

两张都是窗口化（非 `--headless`）+ 引擎内按键代理，**不是 OS 真实按键**。

## 5. 没做什么 / 限制

- **没有改任何机制**：判定、状态机、输入、氧气、惩罚、计分都没动；只改了关卡矩形的数量。
- 下潜仍能过 9 只鸟。这是有意的：鸟在水面上，下潜躲鸟物理成立；要堵死它得新增
  水下元素，属于内容设计而不是几何收窄。
- `leap` 仍是覆盖率最高的单方案（27/55）。它是**有时机的动作**（最紧窗口 0.154 s），
  不是“按住不放”的零成本解，因此本轮不继续压缩。
- 难度曲线没有变难：所有设计答案的窗口逐组不变（容差扫描逐组相等），
  新增水下段只删掉“下潜”这条旁路，不改变必须动作的时机。
- 真人试玩仍是 `NOT TESTED`；自动数据只证明“存在解、旁路被堵”，不证明好玩。
- 本机 OS 键位注入被拒（`SendInput=0`），窗口化证据都是引擎内代理。

## 6. 复现

```sh
# 全量解法矩阵（约 3 分钟，headless）
D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
    res://scenes/stage4_solution_audit.tscn

# 容差扫描三片（-- 之后的参数才进 OS.get_cmdline_user_args）
... res://scenes/stage4_solution_audit.tscn -- --tolerance --from 0 --to 18
... -- --tolerance --from 19 --to 36
... -- --tolerance --from 37 --to 54

# 窗口化全流程
... --path D:/GAMESTUDIO/TURBBIT res://scenes/stage3_playtest.tscn

# 水下阻挡截图
... --path D:/GAMESTUDIO/TURBBIT res://scenes/race.tscn -- --capture-dive-block rock
... -- --capture-dive-block beam
```

证据目录 `docs/reports/logs/phase-m/`（`before/` 是改动前的矩阵与容差扫描备份）。
