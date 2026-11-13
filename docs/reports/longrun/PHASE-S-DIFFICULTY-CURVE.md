# PHASE S — §七-8 三区难度曲线复核

日期：2026-11-12
阶段：STAGE 4（未进入 STAGE 5）
性质：**只做复核与重算，不改任何生产玩法代码**。组表、区速、随机池、连招几何一行没动。
新增的只有：一个只读重算脚本、六组 5 px 细扫数据、本报告。

> 证据类型：自动化（Python 从 `level_data.gd` 与已存扫描文件重算）+ 自动驾驶
> （`stage4_solution_audit` 的设计答案逐档试跑，引擎按键代理）+ 代理驾驶。
> **不是真人试玩**；真人仍 `NOT TESTED`。窗口化完整赛道回归留给 §七-10。

## 1. 一句话结论

三区曲线是**可量的**：密度 10.6 → 11.4 → 13.1 组/分钟，单动作窗口在 Z3 没有变窄
（岩 0.432 → 0.458 → 0.462 s，鲨 0.386 → 0.458 → 0.500 s），双角色连招第一段
0.182 → 0.208 → 0.231 s（浮木）与 0.318 → 0.375 → 0.308 s（高墙），也不比 Z2 更紧；
加速遭遇的每类障碍窗口都 ≥0.534 s。**Z3 不是靠“逐帧手速”加压**，但仍有一部分压力
来自间距/密度：Z3 的连招占比（20.8%）与 Z2（21.1%）持平，没有新增连招类型。
这一条按 §五 是“有保留”，作为制作人决策项记录，未擅自改关卡。

## 2. 方法

### 2.1 重算脚本（只读）

`docs/reports/longrun/phase-s-curve.py` 读三样东西，输出
`docs/reports/longrun/phase-s-difficulty-curve.json`：

1. `scripts/systems/level_data.gd` 的 `GROUPS`（55 组）与 `ZONES`（区速 220/240/260）；
2. `docs/reports/stage4-tolerance-scan-fine-*.json` 的 5 px 细扫（单动作窗口）；
3. `phase-e-combo-windows.phaseh-after.json`（连招基速网格）与
   `phase-n-*-x115.json`（连招 ×1.15 网格）。

跑法：`python docs/reports/longrun/phase-s-curve.py`
（末行打印三区摘要；同种子同结果，不依赖游戏运行）。

### 2.2 本轮补测的 5 组窗口

Phase J 的 40 px 网格只能给下界（0.154 s 就是这么来的，见 `PHASE-N-0154.md`）。
本轮补测 5 px 细扫，逻辑与 Phase N 相同：

| 组 | 区 | 目的 | 日志 |
|---|---|---|---|
| rock8 | Z3 | Z3 岩石的精确窗口（旧数据只有 0.308 s 下界） | `logs/phase-s/tol-rock8.log` |
| rock8 ×1.15 | Z3 | 加速遭遇的岩石窗口 | `logs/phase-s/tol-rock8-x115.log` |
| rock4 | Z2 | 三区岩石对照 | `logs/phase-s/tol-rock4.log` |
| rock4 ×1.15 | Z2 | 加速遭遇的岩石窗口 | `logs/phase-s/tol-rock4-x115.log` |
| shark3 | Z2 | 三区鲨鱼对照 | `logs/phase-s/tol-shark3.log` |
| shark1 | Z1 | 三区鲨鱼对照 | `logs/phase-s/tol-shark1.log` |

六条 stderr 均为 0 字节，退出码 0。

## 3. 三区曲线

### 3.1 总表

| 指标 | Z1 | Z2 | Z3 |
|---|---:|---:|---:|
| 区速（px/s） | 220 | 240 | 260 |
| 障碍组数 | 12 | 19 | 24 |
| 密度（组/分钟） | 10.6 | 11.4 | **13.1** |
| 双角色连招组 | 2（log1、wall1） | 4（log2/3/4、wall2） | 5（log5/6/7/8、wall3） |
| 连招占比 | 16.7% | 21.1% | **20.8%** |
| 需要换人的组 | 5（41.7%） | 9（47.4%） | 11（45.8%） |
| 组间空档 min / 中位 / max（s） | 4.36 / 4.95 / 5.55 | 4.25 / 4.61 / 5.17 | **3.65 / 3.85 / 5.46** |
| 最长空段（s） | 5.91（区起点→bird1） | 5.17（bird4→log3） | 5.46（shark8→beam8） |
| 视距上限（1100 px / 区速） | 5.00 | 4.58 | 4.23 |
| 最小加速预警（设计值） | 4.75 | 4.35 | **4.017** |
| 最紧单动作窗口（基速） | 鲨 0.386 s | 岩/鲨 0.458 s | 岩 0.462 s |
| 最紧连招第一段（基速） | 浮木 0.182 s | 浮木 0.208 s | 浮木 0.231 s |
| 加速遭遇最小窗口（×1.15） | 岩 0.534 s | 岩 0.543 s | 岩 0.552 s |

（表中单动作窗口均为 5 px 细扫实测；潜水门只有 gate1 一组的实测，Z2/Z3 是按同 px
窗口换算的派生值，已在 §3.4 注明。）

### 3.2 Z1：教什么、按什么顺序

| 首次出现 | 组 | 教学文案 | 首次看到时距离 / 时间 |
|---|---|---|---|
| 1 | bird1 | `↓ CROUCH` | 823 px / 3.74 s |
| 2 | rock1 | `↑ JUMP` | 1098 px / 4.99 s |
| 3 | beam1 | `↓ CROUCH`（同一判断复用到梁） | 1100 px / 5.00 s |
| 4 | shark1 | `SHIFT + ↑ TURTLE LEAP` | 1098 px / 4.99 s |
| 5 | gate1 | `SHIFT + HOLD ↓ TURTLE DIVE` | 1099 px / 5.00 s |
| 6 | log1 | `↑ RABBIT JUMP → SHIFT → ↓ TURTLE DIVE` | 1097 px / 4.98 s |
| 7 | wall1 | `SHIFT + ↑ LEAP → SHIFT RABBIT → ↑ KICK` | 1097 px / 4.99 s |

- 七类判断全部在 Z1 首次出现，且都在首次进入视野时给出提示（`lesson-prompt.log`）。
- 乌龟的**跃起**（shark1，x=7200）先于**下潜**（gate1，x=8400）出现；两者都在
  Z1 前半段，之间有 1130 px / 5.14 s。顺序与任务书“逐步认识下潜和跃起”一致。
- **“约 8 秒空档”不复存在**：当前最长空段是区起点→bird1 的 **5.91 s**，其后
  bird1→rock1 4.45 s、rock1→beam1 5.41 s；全关卡没有任何空段 ≥6 s。

**第一次食物事件（§五）**：

| 检查 | 证据 |
|---|---|
| 固定 | `SNACK DRAW #1 group=beam1 zone=1 kind=LOW_BEAM (fixed)`（`draw-after-q.log`） |
| 简单 | 正确答案是 CROUCH（按住 ↓），不是双角色连招 |
| 宽容 | 5 px 细扫 beam1：lead 0–300 px 全过（扫到扫描上限仍成立）= 1.364 s；按住就成立 |
| 加速后预警 | 4.75 s（`warning-audit-after-q.log` 第 1 段），>4 s |
| 实跑 | `zones-after-q.log` #1：吃下后 253 px/s 过梁，`hit=false acc=NONE ride=true` |

### 3.3 Z2：随机 + 双角色组合

- 随机池（`SNACK_DRAW_POOL`）：Z2 = `DIVE_GATE`、`SHARK`；复杂连招
  `FLOATING_LOG` / `HIGH_WALL` 被排除（PHASE-N §7：×1.15 后连招窗口 0.23/0.33 s，
  低于 0.5 s 目标）。
- 两个固定种子都跑过 9 段 × 吃/不吃：
  - `20261112`：`SNACK ZONES: DONE rows=18 fails=0`（`zones-after-q.log`）
  - `424242`：同样 18/18（`zones-seed424242-after-q.log`），且抽签结果不同：
    #6 shark8 从 `SURFACE_ROCK` 变成 `LOW_BEAM`，#7 beam8 从 `LOW_BEAM` 变成 `SHARK`。
- 双角色组合 4 组：log2、log3、log4、wall2（代表组 log3：0.208 s 起手 / 0.20 s 二段；
  wall2：0.375 s 起手 / 0.45 s 二段）。与 Z1 教学组（log1 0.182 / 0.15、wall1 0.318 / 0.40）
  同量级，没有“第一次见就更紧”。
- 加速遭遇的最小窗口是岩石 0.543 s（Z2 实测），鲨鱼 0.585 s（Z3 实测），门/趴低更宽；
  没有低于 0.5 s 的随机结果。

### 3.4 Z3：连招窗口没有变窄，压力在密度

| 组 | 连招 | 第一段窗口（基速） | 第二段 delay 窗 | 第一段（×1.15） | 二段（×1.15） |
|---|---|---:|---|---:|---|
| log1（Z1 教学） | BRO DIVE | 0.182 s | 0.00–0.15 s | — | — |
| log3（Z2） | BRO DIVE | 0.208 s | 0.00–0.20 s | — | — |
| log8（Z3） | BRO DIVE | **0.231 s** | 0.00–0.25 s | 0.301 s | 0.00–0.30 s |
| wall1（Z1 教学） | BRO OLLIE | 0.318 s | 0.40–0.80 s | — | — |
| wall2（Z2） | BRO OLLIE | 0.375 s | 0.40–0.85 s | — | — |
| wall3（Z3） | BRO OLLIE | **0.308 s** | 0.40–0.80 s | 0.234 s | 0.45–0.75 s |

读法：
- 浮木的起手窗从 Z1 到 Z3 是**变宽**的（0.182 → 0.208 → 0.231 s）；
  高墙 Z3 比 Z2 窄 0.067 s，但仍宽于 Z1 教学组。Z3 没有把连招窗口压到 Z2 以下。
- 第二段 delay 窗 Z3 是 0.25 s（浮木）/0.40 s（高墙），与 Z2 的 0.20/0.45 s 同量级。
- 加速后连招第一段只有 0.301/0.234 s，所以连招**不进入加速抽取池**；
  加速遭遇全部是单角色障碍。

单动作窗口（5 px 细扫，基速）：

| 种类（代表组） | Z1 | Z2 | Z3 |
|---|---:|---:|---:|
| 岩石（rock1 / rock4 / rock8） | 0.432 s | 0.458 s | 0.462 s |
| 鲨鱼（shark1 / shark3 / shark8） | 0.386 s | 0.458 s | 0.500 s |
| 潜水门（gate1，换算） | 0.886 s | 0.812 s | 0.750 s |
| 趴低（beam1/bird1） | 整个接近段（≥300 px / 1.36 s） | 同 | 同 |

- 岩石几乎持平，鲨鱼反而在 Z3 最宽（0.500 s，PHASE-N 改鲨鱼上沿后）。
- 只有潜水门的窗口随速度下降（0.886→0.750 s），但它仍是 0.75 s，且“按住下潜”
  不要求精确点位。
- **结论：Z3 没有靠缩短窗口加压。** 它增加的是：13.1 组/分钟（Z2 11.4）、
  24 组（Z2 19）、5 个连招（Z2 4）、中位空档 3.85 s（Z2 4.61 s）。

**顺带发现的度量缺口**：`stage4_metrics` 的“组合 ≥5 s”只把 `FLOATING_LOG`
当组合（`min 5.13`）。按同一把尺子量 `HIGH_WALL`，墙前空档是
**wall1 5.09 s / wall2 4.25 s / wall3 3.85 s**——Z2/Z3 的高墙低于 5 s。
这与 PHASE-Q §5 已记录的制作人决策（Z3 视野上限 4.23 s）是同一件事，
但说明“组合 ≥5 s”目前并非对所有双角色连招都成立；本步只记录，不改测量脚本、
不改关卡。

加速遭遇仍“看组合”而不是“拼 timing”：

| 障碍 | ×1.15 窗口 | 读法 |
|---|---:|---|
| LOW_BEAM / LOW_BIRD | ≥1.18 s（按住） | 无时机压力 |
| DIVE_GATE | 0.751 s（按住） | 宽松 |
| SURFACE_ROCK | 0.534–0.552 s | 单侧窗，≥0.5 |
| SHARK | 0.585 s | ≥0.5 |

## 4. §五 逐条判定

| 区域 | 要求 | 判定 | 证据 |
|---|---|---|---|
| Z1 | 新手学会基础操作 | **满足** | 7 类首现全有提示；顺序 bird→rock→beam→shark→gate→log→wall |
| Z1 | 逐步认识乌龟下潜和跃起 | **满足** | shark1 leap @7200，gate1 dive @8400，间隔 5.14 s |
| Z1 | 第一次食物固定、简单、宽容 | **满足** | fixed beam1；按住 CROUCH 全过；加速预警 4.75 s |
| Z1 | 约 8 秒空档 | **已消除** | 最长空段 5.91 s（起点→bird1），全关卡无 ≥6 s |
| Z2 | 加入随机障碍 | **满足** | 2 种池 + 固定种子；两种子结果不同且各 18/18 |
| Z2 | 加入两角色组合 | **满足** | 4 组连招（log2/3/4、wall2） |
| Z2 | 增加选择但不缩短到无法反应 | **满足** | 加速遭遇最小 0.543 s（Z2 岩石实测；Z1 岩石 0.534 s）；连招不进加速池 |
| Z3 | 使用已掌握的连招和复杂组合 | **满足** | 5 组连招 + 11 组需换人；全部类型已在 Z1 教过 |
| Z3 | 挑战来自组合判断，不是逐帧手速 | **有保留** | 窗口不窄于 Z2（见 §3.4），但连招占比与 Z2 持平（20.8% vs 21.1%），无新连招类型 |
| Z3 | 不允许单纯用速度、减少反应时间加压 | **有保留** | 单动作窗口持平/更宽；压力增量一半来自密度与间距（13.1 组/分钟、中位空档 3.85 s） |

“有保留”不是失败判定，而是**当前曲线没有把 §五 的“组合判断”做得比“密度/速度”更突出**。
这两条已列入 §6 的制作人决策项，未擅自改关卡。

## 5. 有趣性判断（数据推断，非真人）

**结论：有保留。**

依据（全部来自实测节奏，不是玩家报告）：

1. 三区密度确实在涨（10.6 → 11.4 → 13.1 组/分钟），起伏存在。
2. 高点是 11 组双角色连招（8 浮木 + 3 高墙）；它们分布在全程，不是集中在某一段。
3. **本阶段最无聊的 30 秒：Z1 开场 0–30 s（x≈0–6600）**——只有 5 次单动作
   （bird1、rock1、beam1、rock2、bird2），前 **5.91 s 没有任何输入**，直到
   log1（t≈49.6 s）才出现第一次连招。
4. 四个 Z3 食物遭遇抽到的全是单角色障碍（岩/梁/鲨/门），加速段不考组合判断；
   组合判断只发生在未加速的固定组。
5. 最空的完整 30 s 窗口：Z1/Z2/Z3 各有 5 组的窗口；最满：Z1 6、Z2 6、Z3 7。

真人试玩仍 `NOT TESTED`；以上只能说明“节奏数据支持有保留”，不能替代试玩。

## 6. 制作人决策项（未改关卡）

**Z3 的“组合判断”要不要再加重？** 三个选项，互相有约束：

1. **接受现状**：Z3 的压力来自密度（13.1 组/分钟）+ 更长的持续段 + 5 组连招；
   单动作与连招窗口都不比 Z2 紧。改动最小，但连招占比与 Z2 持平。
2. **提高 Z3 连招占比**：把 Z3 的趴低组改成浮木/高墙。约束是“复杂组合前 ≥5 s”
   （浮木目前 min 5.13；高墙 Z2/Z3 已是 4.25/3.85）与 Z3 视野上限 4.23 s——
   需要把相邻组再拉开，赛道变长，并要重跑 55/55 与 18/18。
3. **加镜头前瞻**：把 1100 px 提到 ≥1300 px，恢复 Z3 复杂障碍 ≥5 s；会改变画面构图
   与后方可见量，属美术/构图决策。

**不建议**降低 Z3 车速（§二 明确禁止用降速掩盖窗口问题）。
本轮保持 `STAGE=4`，不擅自选 1/2/3。

## 7. 证据分级与改动清单

| 证据 | 类型 |
|---|---|
| 三区曲线表 | 自动化重算（`phase-s-curve.py`，只读 `level_data.gd` + 扫描文件） |
| 单动作窗口 | 自动驾驶（`stage4_solution_audit` 设计答案，引擎按键代理，5 px 网格） |
| 连招窗口 | 自动驾驶（2D lead×delay 网格，Phase E/N 已存数据） |
| 随机种子 / 18/18 | 自动驾驶 + 代理驾驶（`stage4_snack_zones`，Phase P/Q 已存日志） |
| 真人试玩 | **NOT TESTED** |
| 窗口化完整赛道 | 本轮未跑，留给 §七-10 |

生产玩法代码改动：**无**。`TURBBIT/` 整体未被 git 跟踪（`git ls-files TURBBIT` 为 0），
不能用 `git diff` 列改动；用 mtime 核对：`scripts/` 与 `scenes/` 下
`find -newermt '2026-11-12 18:20'` 为空（本步从 18:20 后开始）。
本步新增的文件：`docs/reports/longrun/phase-s-curve.py`、`phase-s-difficulty-curve.json`、
`docs/reports/stage4-tolerance-scan-fine-{rock8,rock8-x1.15,rock4,rock4-x1.15,shark3,shark1}.json`、
`docs/reports/logs/phase-s/*`、本报告。没有改 `level_data.gd` / `race.gd` / `game_manager.gd`。

## 8. 复现

```bash
python docs/reports/longrun/phase-s-curve.py

# 本轮补测的 5 px 细扫（其余已存）
D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage4_solution_audit.tscn -- \
  --tolerance --group rock8 --lead-min 0 --lead-max 300 --lead-step 5
D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage4_solution_audit.tscn -- \
  --tolerance --group rock8 --lead-min 0 --lead-max 300 --lead-step 5 --speed-scale 1.15
```

- 数据：`docs/reports/longrun/phase-s-difficulty-curve.json`
- 细扫日志：`docs/reports/logs/phase-s/tol-*.log`（stderr 均为 0 字节）
- 本轮没有运行会写 `best.json` 的流程（`stage4_snack_zones` / `solution_audit` 不写），
  未触碰正式纪录。

## 9. QC

任务 `tbb-stage4-difficulty-curve`：8/8 `pass`（R009 PASS，标准写于产物之前）。
逐条证据见 `python ../LESSONS/CHECKS/qc.py status --task tbb-stage4-difficulty-curve`。
