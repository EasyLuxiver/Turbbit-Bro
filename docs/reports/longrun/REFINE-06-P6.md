# REFINE-06 P6 — 55 组节奏复审与重排

状态：**两处换位完成，节奏探针 PASS，两圈整圈回归 PASS**（见下表）；阶段仍是 `STAGE=4`，
未进入 STAGE 5，不宣布完成。

## 一句话

把整条赛道展开成 55 组一张表，按任务书 §八 的指标复算后只做两处换位、没有增删任何障碍：
Z1 的 35–50 s 三连兔子中间插进 wall1（乌龟跃起 + 兔子蹬踏），Z2 入口的三连兔子用 shark3
打断；高操作占比 Z1 0.33 → Z2 0.58 → Z3 0.63，最长空档 5.46 s，同角色三连只剩一处且合规。

## 复审方法

`scripts/test/stage4_p6_rhythm.gd`（只读，不改游戏状态）用正式关卡数据和默认种子食物抽取，
把 55 组展开成一行一组：序号 / 组名 / 区 / 种类 / 所需角色 / 起点 x / 与上一组间距（px、秒）/
动态运动名，再从这张表复算：

| 指标 | 定义 |
|---|---|
| 连续同类 | 相邻组 `kind` 相同 |
| 连续同角色 | 相邻组所需角色相同；BOTH（HIGH_WALL / FLOATING_LOG）算打断 |
| 静态无操作段 | 连续 ≥3 组“静态 + 单角色 + 同一角色”；角色交替（鸟→岩→门）不算 |
| 刚切又切回 | X→Y→X 且两段间距合计 ≤6.0 s |
| 空档 | 组间距离 ÷ 该区基础速度（Z1 220 / Z2 240 / Z3 260），上限 6.0 s |
| 高操作 | 动态（有 motion）或 BOTH 的组占比 |

t 从起跑线 x=400 起按各区基础速度积分（不含食物加速），只用于排节奏。探针在判定前先做一次
检测器自检：喂一段合成的“三连兔子静态”必须报 1 条，避免 `static_streaks=[]` 时无法区分
“真没有”和“检测器坏了”。

## 改动

| # | 位置 | 改前 | 改后 | 理由 |
|---|---|---|---|---|
| 1 | Z1 | rock3 8400 → beam2 9600 → **bird2 10860** → gate2 12000 → **wall1 13300** | rock3 8400 → beam2 9600 → **wall1 10860** → gate2 12000 → **bird2 13300** | 35–50 s 原本是三连兔子（跳、趴、趴），没有配合、没有换手；把 BOTH 的高墙放进窗口中段 |
| 2 | Z2 入口 | bird2 13300(兔) → beam1 14550(兔) → **beam3 15800(兔)** → shark3 17000(龟) | **shark3 15800(龟)** → **beam3 17000(兔)** → rock4 18200(兔) | 刚做完 wall1 的配合又连吃三组兔子；把水下伏击提前，拆成 2+2 |

只换位置，不增删障碍：组数仍 55，所有 `x` 仍是原集合，宽度 / 类型 / 运动参数 / 食物锚点未动。
没有新机制、没有新障碍、没有改碰撞体或判定。

**没动的三连**：beam9(250.3 s) → rock11(254.6) → gate8(258.8) 是兔子三连。gate8 是 9 个
食物锚点之一，默认种子把它抽成 SURFACE_ROCK（兔），挪动会改食物链和 snack 探针的锚点；
任务书写的是“连续同一角色不超过 3 组”，三连本身合规，保留并作为 advisory 记录。

## 被点名的无聊段（改前 / 改后）

| | 35–50 s 窗口 | 角色 | 玩家在做什么 | 换手 |
|---|---|---|---|---|
| 改前 | rock3 36.4 / beam2 41.8 / bird2 47.5 | 兔 / 兔 / 兔 | 跳、趴、趴 | 0 |
| 改后 | rock3 36.4 / beam2 41.8 / **wall1 47.5** | 兔 / 兔 / **BOTH** | 跳、趴、**乌龟跃起 + 兔子蹬踏** | 2（龟起跳 → 兔蹬踏 → 龟落地） |

窗口内新增的是“跃起类”障碍（wall1），BOTH 动作要求玩家在窗口内至少换一次手；紧接着的
gate2（52.7 s）是乌龟下潜，窗口结束后马上又是一次角色确认。三组间距 4.91 / 4.91 / 5.05 s，
没有靠缩短反应时间制造紧张。

整圈实测（两圈都走正式赛道）：

```
ok  wall ollie at x=10860 lands back on shell (accident=NONE mount=RIDING)   ← run 1
ok  wall ollie at x=10860 lands back on shell (accident=NONE mount=RIDING)   ← run 2
```

自动驾驶用标准输入（↑ 跃起 → SHIFT 兔子 → ↑ 蹬踏）完成了新的中段配合。

## 复审数字

| 指标 | 数值 | 判定 |
|---|---|---|
| 组数 | 55 | pass |
| 连续同类 >3 | 0（`same_kind_runs = []`） | pass |
| 连续同角色 >3 | 0；三连 1 处（beam9→rock11→gate8，250.3 s） | pass（三连合规） |
| 刚切又切回（≤6 s） | 0（`switch_backs = []`） | pass |
| 组间空档 >6.0 s | 0；最大 Z1 5.41 / Z2 5.17 / Z3 5.46 s | pass |
| 静态同角色无操作段 ≥3 | 0（`static_streaks = []`，检测器自检通过） | pass |
| 动态运动 | 3 种：tide_rock 9 / ambush_shark 7 / swell_log 3；同运动名三连 0 | pass |
| 高操作占比 | Z1 0.33 (4/12) / Z2 0.58 (11/19) / Z3 0.63 (15/24) | pass，逐区递进 |
| 食物 | 9 份：Z1 2 / Z2 3 / Z3 4；相邻两份之间最少 1 组障碍 | pass |
| BOTH 组 | Z1 2 / Z2 4 / Z3 5 | pass |
| 救援入口（浮木 / 鲨鱼） | 浮木 Z1 1 / Z2 3 / Z3 4；鲨鱼 Z1 1 / Z2 3 / Z3 3 | pass，不集中 |

## 七段节奏在时间轴上的位置

边界按“这一段时间里最突出的玩法”划分；同一组只归一段。

| 段 | 时间 | 区 | 组（起止秒） | 依据 |
|---|---|---|---|---|
| 1 轻松进入 | 0–20 s | Z1 | bird1 5.3 / rock1 9.5 / gate1 15.5（食物 13.0） | 三组单动作，间距 5.27 / 3.73 / 5.41 s，无动态、无 BOTH |
| 2 熟悉动作 | 20–40 s | Z1 | rock2 21.4 / log1 27.3（BRO DIVE）/ shark1 31.1（伏击）/ rock3 36.4（潮汐岩） | 跳、潜、预警、第一块动岩各一次；教学区不堆新机制 |
| 3 产生配合 | 40–65 s | Z1 | beam2 41.8 / wall1 47.5（BOTH）/ gate2 52.7 / bird2 58.6 / beam1 64.3（食物 62.3） | 47.5 s 跃起+蹬踏，52.7 s 乌龟下潜，25 s 内换手两次 |
| 4 动态挑战 | 65–165 s | Z2 | shark3 69.7 … gate5 162.2（19 组） | 动态 7/19、BOTH 4、三种运动全出现、食物 3（82.8 / 113.7 / 144.5）；平均间距 4.69 s |
| 5 欢乐互动 | 165–232 s | Z3 | shark6 167.1 … rock10 232.4（15 组） | 三组 BOTH（log5 186.0 / wall3 194.7 / log6 213.6）+ 最近的两份食物（220.6 / 226.3，相隔 5.7 s）+ 两次水下伏击 |
| 6 操作展示 | 232–260 s | Z3 | rock10 232.4 / log7 238.1 / bird8 241.9 / shark9 246.1（食物 244.3）/ beam9 250.3 / rock11 254.6 / gate8 258.8（食物 257.1） | 7 组 / 26.4 s，间距 3.65–5.15 s；4 组动态、1 组 BOTH、2 份食物，是全程最密的一段 |
| 7 恢复和收尾 | 260–274.6 s | Z3 | gate8 258.8 / log8 264.7（BOTH）/ bird9 268.7 / rock12 273.0（潮汐岩）/ 终点 ≈274.6 | 无鲨鱼、无食物；gate8→log8 是 Z3 最大空档 5.38 s；仍保留一次浮木组合和一块动岩 |

## 证据

- 复审表：`docs/reports/logs/refine06-p6-rhythm.stdout.log`（88 行，`P6 RHYTHM: PASS`，
  0 条 SCRIPT ERROR）；逐组 JSON `docs/reports/longrun/refine06-p6-rhythm.json`
  （与打印表同源于 `rows` / `zones`）。
- 整圈：`docs/reports/logs/refine06-p6-fullrun.stdout.log`（586–590 行 RESULT / PLAYTEST）。
- 视觉取证（窗口化，逐张打开看过）：
  - `screenshots/refine06-p6-z1-run-up.png`（x=9151，前方是 beam2 与更远的 wall1）
  - `screenshots/refine06-p6-z1-wall1.png`（x=10520，10860 的高墙 + HUD「BRO OLLIE 准备」、
    底栏「↑ 跃起 → SHIFT 兔子 → ↑ 蹬踏」）
  - `screenshots/refine06-p6-z1-bird2.png`（x=13201，13300 的俯冲海鸟与 14100 的食物）
  - 取证脚本 `scripts/test/stage4_p6_layout_capture.gd` + 场景；日志
    `docs/reports/logs/refine06-p6-capture.log`（三次 `ADV` 的 x 与 `SHOT` 行）。

## 验收（qc: `tbb-refine06-p6-rhythm`）

| # | 判定 | 证据 |
|---|---|---|
| 1 | pass | 工具 exit 0、55 行；每行含区/种类/角色/起点/间距 px·s/运动名，三区汇总齐全；JSON 与打印表同源 |
| 2 | pass | `same_kind_runs=[]`；`same_role_runs` 仅 1 条 length=3；>3 为 0 |
| 3 | pass | `long_gaps=[]`，最大 5.41/5.17/5.46 s；`static_streaks=[]`，检测器自检通过 |
| 4 | pass | 改后窗口 rock3 36.4 / beam2 41.8 / wall1 47.5（BOTH 跃起+蹬踏）；整圈日志两次 `wall ollie at x=10860` |
| 5 | pass | 0.33 / 0.58 / 0.63，单调上升 |
| 6 | pass | 3 种运动（潮汐岩 / 伏击鲨 / 浪涌浮木）；每区动态 2 / 7 / 10 组；`motion_streaks=[]` |
| 7 | pass | 9 份食物 2/3/4；相邻两份之间最少 1 组；BOTH 2/4/5；浮木与鲨鱼三区都有 |
| 8 | pass | 274.6 / 274.6 s，55/55，0 事故，S，9650 分，`STAGE3 PLAYTEST: PASS`，SCRIPT ERROR 0；md5 前后一致 |
| 9 | pass | 七段表可逐段指认；结论 **有保留**（见下），附未做真人试玩说明 |

## 回归

| 项 | 结果 |
|---|---|
| `stage4_p6_rhythm` | PASS，55 行，0 SCRIPT ERROR |
| `stage6_balance_matrix` | PASS，31 条判定 failed=0（P6 换位后重锚 A/B/DE） |
| `stage5_d_shift` | PASS（顺手修了两条与 P4 定案相反的过期断言；产品代码未动） |
| `stage4_collision_feedback` | PASS（ollie 用例起点跟着 wall1 移到 10860） |
| `stage6_p0_collision` | PASS（wall1 用例的传送点跟着移到 106–10860） |
| `stage5_e3_ollie` | PASS |
| `stage4_level_audit` / `stage4_snack_draw` / `stage4_snack_zones` | exit 0，0 SCRIPT ERROR |
| `stage4_z1_rhythm` / `stage4_z3_warning` | PASS |
| `stage6_bro_dive_robust` / `stage6_shark_ambush` | PASS |
| `stage4_hud_score` | PASS，44 项检查（窗口化） |
| `stage4_menu_input` | PASS（窗口化） |
| 两圈 `stage3_playtest` | run1 274.6 s / run2 274.6 s，9650 分，S，55/55 组，事故 0，最大停摆 0.0 s，SCRIPT ERROR 0，`STAGE3 PLAYTEST: PASS` |
| 食物线 | 18 条“吃掉”，乌龟 5 / 兔子 4 交替（每圈 9 份） |
| `best.json` | md5 前后一致 `c322f9a20321c5b618f98db7e4120969` |
| `docs/STAGE.md` | 仍为 `STAGE=4` |

**已知问题（不是本轮引入）**：`stage5_g4_cheer` 的 BRO DIVE 欢呼在第 32 帧才归零（阈值 ≤25 帧，
ollie 21 帧）。该用例按组名取 log1 / wall1，P6 换位不影响它的行为；没有为了让测试变绿去放宽
阈值或改表现代码，留待下一轮单独查“第二次 `_celebrate("pickup")` 是否重启了跳跃”。

## 有趣性判断

**有保留。**

- 七段现在能逐段指认，已点名的 35–50 s 无聊段被一次真实的两人配合打断，Z2 入口也不再是
  三连同一个答案。
- 但“恢复和收尾”只有约 16 s，且最后仍有一块会动的岩（rock12 273.0），它更像“最后一个组合
  + 两个安全动作 + 终点”，不是整段放空；Z2 本身长 97 s，内部变化主要是障碍类型轮换，
  连续玩第二圈时仍可能觉得长。
- 自动化只证明布局、距离、角色分布和两圈可跑通；**没有真人试玩**，不能据此说“好玩”。

## 下一步

写最终交付 `TBB-EXPERIENCE-REFINE-06.md`（10 问自评 + 七段映射 + P3 字面 FAIL 的说明），
等制作人质检；`STAGE=4` 不动。
