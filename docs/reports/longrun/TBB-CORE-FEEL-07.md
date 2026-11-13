# TBB-CORE-FEEL-07 — 核心玩法可读性与跑酷节奏重构

日期：2026-11-13
阶段：STAGE 4（未推进）
性质：玩法规则与可读性重构。素材继续冻结：没有新增任何图片、音频、字体。

> 本轮**没有任何真人试玩**。下面所有“通过”都是自动驾驶探针在正式 `race.tscn`
> 里用真实按键跑出来的物理可行结果，不等于人玩得动、更不等于好玩。

## 0. 制作人试玩反馈 → 本轮处理

| 反馈 | 处理 |
|---|---|
| BRO DIVE 太难（要卡“按住 ↓ 到木尾再松手”） | P0-A 辅助下潜：SHIFT 后自动潜过整段并自动上浮 |
| 一次失败扣两次（联合判罚） | P0-B 事故事件表：同一障碍同一时间窗只罚一次 |
| 看不懂食物是干什么的 | P1-C 食物出现即预告两种效果、点名谁吃、吃到即有可见反馈 |
| 神游条说“要惹麻烦”但看不到后果 | P1-D 按角色显示程度与具体代价，满值有可辨认姿态，恢复可见 |
| 障碍单调 | P1-E 分段标注 + 两处站位调整，四种节奏各 ≥1 段 |

## 1. 真实 BUG

### 1.1 一次失败扣两次（联合判罚）

兔子撞浮木、乌龟紧接着同一个障碍各记一笔，`mistakes` 一次失败加 2。
根因是 `_turtle_contact` 直连 `note_mistake`，而兔子那条路径已经记过。

改法：事故按“障碍事件”结算（`scripts/race.gd`）：

- 事件字段 `id / group / kind / t / roles / settled / penalty_role / rescue / settled_t`；
- 同一障碍、`Tuning.ACCIDENT_JOINT_WINDOW`（1.5 s，取自正式关卡实测同组双撞间隔
  1.334 s）内的碰撞并进同一事件；
- 事件同时含 `rabbit` 和 `turtle` → 联合事故，仍只罚一次；
- 结算后同组再来碰撞只补表现（闪屏、音效），不再记账；
- 不同障碍是不同事件，各自独立结算。

证据：`scripts/test/stage7_joint_penalty.gd` 8 例矩阵全 PASS
（`docs/reports/logs/core-feel-07-p0b.log`、`core-feel-07-joint-penalty.json`）。
c3 同帧双撞与 c4 间隔 1.33 s 先后双撞都是 `mistakes=1 / -100 / HUD 1/3`。

**补丁（同日晚，制作人追问后）：事件表还漏了兔子落水这条路。**
制作人复现：兔子起跳撞浮木 → 乌龟下潜接兔子 → 仍出现「联合惩罚」。
实测：壳撞木记 1 格（事件结算于 0.35 s），壳被浮木顶住后兔子这一跳没有壳可落，
1.45 s 落水时走的是 `_tick_rabbit` 里的 `_trigger_accident("RABBIT_WATER")`，
完全绕开事件表，再记 1 格——一次失败两格。修复前扫参 25 条能接住的失败里
19 条被记两笔（`core-feel-07-brodive-fail-before-fix.json`）。

改法（`scripts/race.gd`）：事件创建时记 `rabbit_air`；落水前查
`_fall_consequence_event()`——最近一次已结算事件是 `FLOATING_LOG`、含 `turtle`、
兔子当次在空中、且距结算 ≤ `ACCIDENT_JOINT_WINDOW`，则落水视为同一次失败的
下游后果：物理后果（`RABBIT_WATER` / 救援）照常，BRO METER 不再加格，并在该事件
`followups` 里留一条 `{reason: RABBIT_WATER, role: rabbit, t}`。窗口外的再落水、
其它障碍、开阔水域单独落水都照常记账。

证据：`scripts/test/stage7b_bro_dive_charge.gd` 13 条断言全 PASS
（`docs/reports/logs/core-feel-07b-bro-dive-charge.log`、
`core-feel-07b-bro-dive-charge.json`）；修复后同一扫参 0/25 条多记
（`core-feel-07-brodive-fail.json`）；七条既有回归全部 PASS
（`docs/reports/logs/core-feel-07b-regress-*.log`）。

### 1.2 神游晃壳让 `is_rising()` 在巡航中误报（P1-D 引入，P1-E 发现）

P1-D 给壳加了 3–18 px 的上下晃。`is_rising()` 只看 `_vy < 0`，于是巡航里的
正弦上升也被当成“壳在水下、正在浮上来”：普通岩跳下落时被提前 115 px 深接，
抬升路径正好横穿岩檐，A4/A5 段出现本不该有的事故。

改法（`scripts/actors/turtle_controller.gd`）：

```gdscript
func is_rising() -> bool:
    return _vy < -1.0 and position.y > Tuning.NEUTRAL_DEPTH + 24.0
```

`24 = 最大晃幅 18 + 6`，只有壳确实低于巡航水深才算上浮。
修后 A4/A5 及全部 10 段 × 2 条路线 0 事故（`core-feel-07-rhythm.json`）。

### 1.3 测试工装自己的问题（不是游戏 BUG，但会骗人）

| 问题 | 表现 | 修法 |
|---|---|---|
| `stage7_rhythm_segments._check_types` 读错键 | 读的是 `LevelData` 原始段，metrics 全是 null，脚本中断但退出码仍 0 → **假 PASS** | 改为遍历 `data["segments"]`，并把 8 条 A/B/C/D 检查逐条确认执行 |
| `stage4_combo_windows` 写死组下标 | Phase H 之后下标 8 已是 HIGH_WALL、10 是海鸟，结果 `pass=0/273` | 改为按组名解析，log1 恢复 74/273 |
| `stage5_g2_release` / `stage5_g3_hint` 沿用旧预期 | P0-A 之后自动上浮，不再出现“松开 ↓”提示，两探针 FAIL | 用例先 `_clear_dive_assist()` 明测手动下潜那条路；辅助本身由 `stage7_bro_dive_assist` 验收 |
| `stage4_window_audit` 写死下标 | 同 combo 一样过期：08 被当成浮木、10 被当成高墙，量出 0 px 窗口 | 改为按 kind+zone 在装载后的真实关卡里解析 |
| `stage4_window_audit._run_case` 同一帧内先松后按 | 起手的跳/跃起、高墙的蹬踏都被吃掉“按下沿”，高墙 `leap_jump` 三组全 0、岩跳也大面积 0——与 `solution_audit` 直接矛盾 | 起手前补一帧沉降、蹬踏前补一帧；高墙恢复 11/16/15 通过、岩跳 3/5/7 通过（`core-feel-07-window-audit-walls.log` / `-rocks.log`） |
| 浮木落壳窗口在 coop 路线里整个错过 | 探针的 `exit=150` 把 ↓ 按到兔子落壳之后，壳停在 483 px 没浮回来 | 探针改为木尾 +40 px 就松开；逐帧 `landing` 采样留在 JSON 里 |

**事故记录（数据丢失）**：`stage4_window_audit` 的旧脚本把 Phase C 的
`docs/reports/longrun/phase-c-windows.json` 覆盖了。覆盖前没有备份，
2026-11-12 02:16 那一版的逐 lead `trials` 明细已不可恢复；
它的汇总数字仍可在 `docs/reports/logs/window-audit.log` 与
`PHASE-C-AUDIT.md` 的引用里查到。覆盖后的文件已搬进
`_attic/2026-11-13/phase-c-windows.stale-index-run-2026-11-13.json`，
现文件由修正后的脚本重跑生成（`generated_at` 为 2026-11-13，自带出处）。

## 2. 规则改动

### 2.1 P0-A 浮木辅助下潜

状态机 `OFF → ARMED（兔子起跳、前方有浮木）→ ACTIVE（SHIFT 到乌龟）→
SURFACING（越过浮木）→ OFF`。玩家仍然要自己起跳、自己 SHIFT；
省掉的只有“按住 ↓ 到右缘再松手”。

- 不改碰撞体（log 32×218、turtle 96×56、rabbit 32×48 与旧矩阵一致）；
- 不关碰撞、不自动换手、不替玩家按 ↑/SHIFT；
- 辅助期间 `dive_release_ready()` 返回 false，不再出现“松开 ↓”提示。

证据：3 组浮木 ×（10 次标准 + 10 次 SHIFT 延迟 0.5 s）+ 6 次变速，共 66 跑 0 失败；
最小余量 rabbit 20.8 px / turtle 23.2 px。控制组 `no_input / shift_only /
jump_only / shift_then_jump / late_shift(1.0 s)` 全部命中，说明辅助没有替玩家过关
（`docs/reports/logs/core-feel-07-p0a.stdout.log`、`core-feel-07-brodive-assist.json`）。

### 2.2 P1-C 食物可读

- 出现时第二行同时写两种效果：`兔子吃 ↑ 下一跳更高     乌龟吃 » 加速`；
- 第一行点名“现在谁吃”，SHIFT 后即时改口；够不到时写原因而不是沉默；
- 世界里食物上方同时画 ↑ 与 »，吃者头顶画绿色“吃”标；
- 兔子吃到跳力 1.15×，乌龟吃到速度 ×1.15（253 = 220×1.15），均有 HUD 与反馈；
- 跳过不扣分；
- 开场画面与暂停页都写了规则（暂停页是唯一能停下来读的地方）。

证据：`stage7_food_readability` 全项 PASS（`core-feel-07-food-readability.json`），
窗口化截图 `screenshots/core-feel-07-food{,_gulp,_turbo}.png`、
`core-feel-07-opening.png`、`core-feel-07-pause.png`。

### 2.3 P1-D 神游可见

每条神游条旁直接显示控制器此刻的生效值（空中修正 55% / 身偏 29 px /
巡航 90% / 壳晃 18 px），不是另抄一份文案；越过 6 s / 9 s 各报一次并写出具体代价；
满值标记 `!` → `!!`，兔子耳朵下垂、乌龟开始划水；受控后 0.5 s 开始回落，5 s 回满消失。
不强制换手、不锁输入、不复位：24 s 完全不干预 `bro_delta=0`、`accident_delta=0`。
证据：`stage7_drift_visible`（headless + 窗口化各一次），
`screenshots/core-feel-07-drift-full-{zh,en}.png`。

### 2.4 P1-E 节奏分段与两处站位

`scripts/systems/level_data.gd` 新增 `RHYTHM_SEGMENTS`（数据，不是注释）：
10 段 A/B/C/D，覆盖全部 55 组。两处站位：

- `bird2` 13300 → 12850：`gate2 → bird2 → beam1` 从两拍同速变成
  3.05 s 突变 + 7.23 s 长呼吸（C 段）；
- `gate5` 38000 → 37480：`log4` 落壳后 2.91 s 就要过礁拱，
  下潜姿态还没收回——这是连招（B 段），不是两个单点。

其余 53 组位置、类型一律未动。

## 3. 正式场景集成

| 项目 | 结果 | 证据 |
|---|---|---|
| 正式 `race.tscn` 全程跑通 | safe / coop 两条脚本路线都跑到 `x=67582.4`（终点 67600），55 组，`hits=[]`、`accidents=0`、`mount=RIDING`，模拟 293.2 s | `docs/reports/logs/core-feel-07-p2-fullrun.log`、`core-feel-07-fullrun.json` |
| 失败边界 | 同样全程、完全不按键：`x=3755` 处已记 3 次事故（bird1 / rock1 / gate1），未完成 | 同上 `FULL none` 行 |
| 暂停 / 重开 / 回菜单 | 中英各 15 项：菜单、进入比赛、HUD、ESC 暂停/继续、结算页各字段、R 重开、暂停中 M 回菜单 | `docs/reports/logs/core-feel-07-p2-flow.log`（`STAGE4 FLOW: PASS`） |
| best.json | 跑前跑后内容逐字节一致，MD5 `c322f9a20321c5b618f98db7e4120969` | 同一 flow 日志 `flow test restores best.json byte for byte` |
| 帧率一致 | 30 / 60 / 120 Hz 的 10 段 × 2 路线全部同样通过、事故数全 0；终点位置最大差 5.3 px（D1） | `core-feel-07-rhythm-hz{30,120}.json` |
| STAGE | `docs/STAGE.md` = `STAGE=4` 未动 | — |

需要说明：全流程跑是**自动驾驶**，路线是探针写死的（safe 提前 260 px，
coop 提前 400 px 并带换人）。它证明关卡在当前规则下可通、失败确实会失败，
不证明人能在同样时机按键。

## 4. 自动化结果

### 4.1 P1-E 逐段读数（60 Hz，真实按键）

| 段 | 类型 | 组数 | 空跑 s | 恢复 s | 单点 | 连招 | 持续状态 s | 间隔比 | 高压 s |
|---|---|---|---|---|---|---|---|---|---|
| A1 开场呼吸 | A | 4 | 5.27 | 5.27 | 4 | 0 | 2.00 | 1.45 | 19.2 |
| A2 先认单点 | A | 3 | 5.27 | 4.91 | 3 | 0 | 1.50 | 1.32 | 12.1 |
| C1 节奏突变 | C | 5 | 4.91 | 4.91 | 3 | 1 | 9.68 | 2.37 | 25.8 |
| A3 二区门口 | A | 1 | 4.50 | 4.71 | 1 | 0 | 1.38 | — | 2.6 |
| B1 趴低接跳 | B | 2 | 4.71 | 6.29 | 0 | 1 | 1.79 | 1.00 | 6.0 |
| A4 珊瑚单点 | A | 14 | 6.29 | 5.13 | 14 | 0 | 1.83 | 1.22 | 69.5 |
| B2 下潜连招 | B | 2 | 5.13 | 6.42 | 0 | 1 | 1.83 | 1.00 | 6.1 |
| A5 三区单点 | A | 9 | 5.92 | 3.85 | 9 | 0 | 1.69 | 1.35 | 38.9 |
| D1 长隧道 | D | 2 | 3.85 | 4.30 | 0 | 1 | 3.92 | 1.00 | 8.2 |
| A6 终段单点 | A | 13 | 4.30 | 2.92 | 12 | 0 | 1.69 | 1.49 | 57.5 |

A 段有孤立单点且前后 ≥3.5 s 空跑；B 段连招间隔 ≤3.2 s；C 段间隔比 2.37；
D 段同一持续状态 3.92 s。四种节奏各 ≥1 段（A：A1–A6；B：B1、B2；C：C1；D：D1）。
每段两条路线 0 事故、结束时都在骑乘（`core-feel-07-rhythm.json`）。

### 4.2 旧机制回归

- **55 组 × 7 方案粗审计**：`AUDIT no_solution=[]`，55 组的设计动作全部在通过列表里；
  8 组浮木全部能过 `dive_jump`（log2 另有 `dive` 一条也能过），
  `design_correct` 七类合计 55/55（`SOLUTION AUDIT: DONE`）。
- **25 场景批量**：22 个短场景通过（g2 / g3 在批量里判 FAIL 是因为沿用 P0-A 之前的
  预期，按新规则改判后单独重跑 PASS）；3 个长审计超时，其中 solution_audit 重跑完成
  （590 s），window_audit 修下标与按键沿后重跑，combo_windows 见下。
- **连招窗口**（6 例 × lead × 动作延迟全扫，`COMBO: DONE`）：

  | 组 | 类型 | 通过/总跑 | 有解的 lead 数 | 最宽的一档（lead / 最晚 SHIFT） |
  |---|---|---|---|---|
  | log1 | 浮木 z1 | 74/273 | 13 | lead 220 / 跳后 0.50 s |
  | log3 | 浮木 z2 | 95/273 | 14 | lead 250 / 跳后 0.55 s |
  | log8 | 浮木 z3 | 107/273 | 16 | lead 260 / 跳后 0.55 s |
  | wall1 | 高墙 z1 | 40/285 | 7 | lead 210 / 跳后 0.40 s |
  | wall2 | 高墙 z2 | 52/323 | 9 | lead 240 / 跳后 0.45 s |
  | wall3 | 高墙 z3 | 53/285 | 9 | lead 260 / 跳后 0.40 s |

  浮木的连招宽度随区域变宽（跳后最多可等 0.50→0.55 s 再 SHIFT）；
  高墙仍只有 7–9 个 lead 有解、跳后 0.40–0.45 s 内必须 SHIFT——这是 P0-A
  之后最窄的一类，也是制作人下一轮最可能要反馈的地方。
- **细窗审计**：旧下标版本量错了 8 例（0 px），已改脚本重跑，见 §4.3。

### 4.3 窗口宽度（修正后的 window audit）

`scripts/test/stage4_window_audit.gd` 改为按 kind+zone 解析、并补掉两处
“同一帧先松后按”的按键沿问题后重跑，21 例 `WINDOW: DONE`。
它回答的是“物理可行窗口有多宽”，不是“人舒不舒服”。

| 类型（设计动作） | z1 | z2 | z3 |
|---|---|---|---|
| 低鸟（趴低） | bird2 1.73 s | bird4 1.58 s | bird8 1.46 s |
| 礁石（跳 / 跃起） | rock2 0.18 / 0.55 s | rock5 0.83 / 0.67 s | rock11 0.31 / 0.85 s |
| 低梁（趴低） | beam2 1.73 s | beam4 1.58 s | beam8 1.46 s |
| 鲨鱼（跃起） | shark1 1.00 s | gate3 1.00 s | shark8 1.08 s |
| 礁拱（下潜） | gate2 2.36 s | gate4 2.17 s | gate7 1.08 s（760 px 长廊型） |
| 浮木（跳+SHIFT） | log1 0.55 s | log3 0.56 s | log7 0.48 s |
| 高墙（跃起+蹬踏） | wall1 0.23 s | wall2 0.31 s | wall3 0.27 s |

读法：

- 表里只写该类型的设计解（次选解在 JSON 里；鸟的 `jump`、梁/礁的 `dive`
  仍有 0 通过，那是“这个动作本来就不该过”，不是缺解）。
- 最窄的是礁石 `jump`（rock2，0.18 s）和高墙（0.23–0.31 s）；
  浮木在 P0-A 之后是 0.48–0.56 s。Phase C 报告里浮木的 0.18–0.25 s
  来自有按键沿缺陷的旧探针版本，不能当作 P0-A 前后对比。
- 鲨鱼 1.00–1.08 s 明显宽于 Phase C 的 0.18–0.31 s：这来自 SHIFT 核心改动后
  “跃起保持”的时间变长，本轮没有改鲨鱼；若要拿它做人类舒适度结论，仍需真人验。
- `gate7`（760 px 长廊）被按 x 居中的规则选成 z3 代表，1.08 s 不能代表
  180 px 门的窗口（z1/z2 是 2.17–2.36 s）。

## 5. 真人体验结果

**本轮没有任何真人试玩。** 没有制作人或其他人实际拿手柄/键盘玩过这一版。

因此本轮**不能**回答 CLAUDE.md 的四个有趣性问题，也不写“有趣 / 有保留 / 不有趣”
的结论。自动驾驶能过 55 组、能 0 事故跑完全程，只能说明物理上可解；
它不会犹豫、不会看错、不会按晚。真正要验的是：

1. 看到浮木时，玩家是否知道“先跳再 SHIFT”，而不是继续找松开 ↓ 的时机；
2. 食物的两行预告是否在一眼之内读懂谁吃、吃什么效果；
3. 神游数字和满值姿态是否让人意识到“我现在很危险”，而不是当作背景装饰；
4. A/B/C/D 四种节奏是否摸得出来，而不是全程同一种节拍。

## 6. 未解决问题

- **没有真人试玩**（见 §5），这是本轮最大的未验证项。
- 连招窗口是物理可行窗口：高墙只有 7–9 个 lead 有解，自动化能过不等于人按得准。
- **细窗审计的旧文件无法恢复**：Phase C 的 2026-11-12 02:16 版逐 lead 明细被本轮
  误覆盖，只剩汇总日志。修正脚本的重跑结果只代表 2026-11-13 的关卡状态
  （P1-E 移动过 bird2 / gate5、P0-A 改变浮木操作），不能直接与 Phase C 报告里的
  旧数字逐项对比。
- 辅助下潜只覆盖浮木；高墙的 BRO OLLIE 仍要求“跃起后 SHIFT + 蹬踏”的精确时机，
  制作人若觉得同样难，需要单独一轮。
- 食物与神游的所有结论来自探针和窗口化截图，没有真人验证“看得懂”。
- 关卡仍然是 55 组同一套地形逻辑；本轮只调整了 bird2 / gate5 两处站位，
  没有新增障碍类型（素材与关卡美术冻结）。

## 7. 证据索引

| 内容 | 位置 |
|---|---|
| P0-A | `docs/reports/logs/core-feel-07-p0a.stdout.log`、`longrun/core-feel-07-brodive-assist.json` |
| P0-B | `docs/reports/logs/core-feel-07-p0b.log`、`longrun/core-feel-07-joint-penalty.json` |
| P0-B 补丁 | `docs/reports/logs/core-feel-07b-bro-dive-charge.log`、`longrun/core-feel-07b-bro-dive-charge.json`；修复前后对比 `longrun/core-feel-07-brodive-fail{,-before-fix}.json` + `logs/core-feel-07b-brodive-fail.log` |
| P1-C | `docs/reports/logs/core-feel-07-p1c.log`、`longrun/core-feel-07-food-readability.json` |
| P1-D | `docs/reports/logs/core-feel-07-p1d{,-windowed}.log`、`longrun/core-feel-07-drift-visible.json` |
| P1-E | `docs/reports/logs/core-feel-07-p1e{,-hz30,-hz120}.log`、`longrun/core-feel-07-rhythm{,-hz30,-hz120}.json` |
| P2 全程 | `docs/reports/logs/core-feel-07-p2-fullrun.log`、`longrun/core-feel-07-fullrun.json` |
| P2 流程 | `docs/reports/logs/core-feel-07-p2-flow.log` |
| 回归 | `docs/reports/logs/core-feel-07-regress-p1e-*.log`、`logs/p1e-regress-summary.txt`；P0-B 补丁后 7 条：`logs/core-feel-07b-regress-*.log` |
| 窗口审计 | `docs/reports/logs/core-feel-07-window-audit-fixed.log`、`longrun/phase-c-windows.json`（2026-11-13 重跑） |

## 8. 追加：乌龟失败文案（07C）与满格文案（07D）

制作人试玩反馈：乌龟撞鲨鱼/拱岩/高墙后，画面已经肚皮朝天，HUD/反馈/提示
却一律说“被浪冲下去”。07C 把反馈与提示按障碍拆开（浮木/鲨鱼/拱岩/高墙），
掀翻期间头顶与 HUD 显示“翻肚皮”，翻完还在水里才切“被浪压进水里”；
提示改成该障碍的下一步动作，并删掉与当前操控矛盾的“换回乌龟稳住”。

07D：共享三格规则经制作人确认**不改**，但“联合惩罚”字面像在说两个人都有错。
中央提示改为“BRO METER 满 —— 一起翻船！”（en: BOTH CAPSIZED），
结算页同步为“翻船次数 / CAPSIZES”；满格记账（100/100/300、演出后清零）不变。

| 内容 | 位置 |
|---|---|
| 07C 探针 | `docs/reports/logs/core-feel-07c-turtle-copy.log`、`longrun/core-feel-07c-turtle-copy.json`、截图 `screenshots/core-feel-07c-shark-flip.png` |
| 07C 回归 | `docs/reports/logs/core-feel-07c-regress-*.log`（9 条） |
| 07D 探针 | `docs/reports/logs/core-feel-07d-capsize-copy.log`、`longrun/core-feel-07d-capsize-copy.json` |
| 07D 回归 | `docs/reports/logs/core-feel-07d-regress-*.log`（15 条） |
| QC | `LESSONS/REPORTS/qc/tbb-core-feel-07c-turtle-flip-copy.json`、`tbb-core-feel-07d-capsize-copy-r2.json` |
