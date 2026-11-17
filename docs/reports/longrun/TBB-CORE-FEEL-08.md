# TBB-CORE-FEEL-08｜核心体验与第二区域场景结构调整

日期：2026-11-13
阶段：`STAGE=4`（未推进）
任务类型：CONTROLLED_WRITE

本轮只做三件事：让神游真的影响控制、把事故做成一定能恢复、给第二区域建立可分层的室内木质码头结构。
没有进入 STAGE 5，没有改多结局系统，没有大规模重写 `race.gd`，没有批量新增障碍物，也没有覆盖任何旧审计证据。

---

## 1. 本轮实际完成内容

### 1.1 收尾上一批 BUG（前置）

- 浮木双扣修复、乌龟失败文案、满格文案：已随 `f9b4006` 提交，本轮未回退。
- 回归用 `best.json` 在开工前、收工后都校验过 MD5，见 §8.5。
- `docs/STAGE.md` 保持 `STAGE=4`。

### 1.2 P0-A｜神游必须真的影响控制

旧版神游只改位置偏移、速度和空中修正，玩家依旧“按了就好”。现在：

- 四档（CALM / DISTRACTED / RESTLESS / MISCHIEF）只对**按下沿**加延迟，按住不放不受影响。
- 延迟一定执行、不丢键、不锁输入；不会反向控制、不会强制换人、不会产生事故。
- 两个角色手感不同：BITT 起身慢、TUBO 反应更慢；BITT 会自己趴一下，TUBO 的壳会自己漂一点深度。
- 有可见反馈（“BITT 自己趴下了！”“兔子回过神了”），恢复过程 4.9–5.0 s，渐变清零。

参数与实测见 §3，探针 `stage8_drift_control` 全绿。

### 1.3 P0-B｜所有事故可恢复、分轻/重、同一事件只记一格

- 轻事故（`RABBIT_STUN`）：0.8 s 硬直后自己回 RIDING，不丢骑乘，恢复后立刻能跳。
- 重事故（`RABBIT_WATER` / `OXYGEN_OUT` / `BRO_BREAK`）：玩家什么都不按也会被冲回壳上 / 自动上浮回气 / 演出结束清空 BRO METER。
- 乌龟失误（浮木、鲨鱼、拱岩、高墙）：只记一格、不进入事故状态、1.8 s 内回正且仍能下潜。
- 同一障碍同一事件只记一次：第二笔照常播硬直/落水表现，但不再扣分。
- 真碰撞保留、判定框没有缩小：装载后 55 条判定框尺寸与 `LevelData` 定义逐条相同。

规则与实测见 §4，探针 `stage8_accident_recovery` 全绿。

### 1.4 P1-C｜每个障碍物回答“它是什么、为什么在这里、为什么这样动”

- 55 个障碍实例全部补齐 `identity` 字段（数据层，不动 `kind` 与物理）。
- 设计案里说的“两块移动石头”，实际清点是 **9 块** `tide_rock`（不是 2 块）：Z1 一块、Z2 三块、Z3 五块。
- 9 块全部按“海洋动物 / 码头机械”改写身份，**机制、位置、位移量、周期、计分一格未动**：
  - Z1 `rock3` → 系泊浮标 `buoy`（锚绳拴在海底，随涌浪起落）
  - Z2 `rock4/rock5/rock7` → 吊装货箱 `dock_crate`（挂在码头吊钩上，随吊臂升降）
  - Z3 `rock8–12` → 漂流货箱 `drift_crate`（被大浪推着浮沉）
- 每类身份有自己的画法（浮标带锚绳与红白顶、吊箱带吊钩与绳、漂流箱带浪花），并配了底栏运动提示（中英双语）。
- 完整身份/区域/运动来源/对策表见 §5。

### 1.5 P1-D｜第二区域（室内木质码头）分层结构

- 新增 `scenes/zone2_dock.tscn`，实例化进 `race.tscn` 的 `Zone2Dock` 节点。
- 六个独立层节点：`BG_Far / BG_Mid / BG_Props / Gameplay_Canal / FG_Near / FG_Overhead`，各自的 `parallax`、`fade_lag`、`z_index` 都能在编辑器里改。
- 中央水渠贯穿画面；对岸有仓库、楼梯、货物；上方有木梁、立柱、吊臂、绳网；近景有木桩、绳索、波浪。
- 背景层零碰撞体；近景/顶梁不进入判定带（130–450 世界 y）。
- 横向滚动时远景慢、近景快；边界处按层淡入淡出，不出现“屋顶浮在第一区域海面上”。
- 节点结构、视差参数与截图见 §7。

### 1.6 P2｜整体验证

- 神游四阶段响应、恢复、轻/重事故恢复、障碍完整性、9 块石头前后对照、Z2 分层与横向滚动、遮挡顺序、30/60/120 Hz、菜单/暂停/重开/结算、`best.json` MD5，全部执行，结果见 §8。
- 30/60/120 Hz 是本轮新写的探针 `stage8_hz_regression`：同一段玩法三种步长各跑一遍，判“行为按秒一致”而不是“按帧一致”。

---

## 2. 修改文件和场景清单

### 2.1 修改（已跟踪文件）

| 文件 | 改动 |
|---|---|
| `TURBBIT/scripts/race.gd` | 神游按下沿延迟、自主动作、恢复反馈；身份画法（浮标/吊箱/漂流箱/浪头）；底栏运动提示；`_update_dock()` 喂相机；Z2 跳过旧背景绘制 |
| `TURBBIT/scripts/systems/tuning.gd` | P0-A 参数：`DRIFT_REACT_*`、`BITT_AUTOCROUCH_*`、`TUBO_AUTODRIFT_PX` |
| `TURBBIT/scripts/systems/level_data.gd` | 9 块潮汐岩的 `identity`；`IDENTITY_BY_KIND` 默认表；`build_group` 输出 `identity` |
| `TURBBIT/scripts/autoload/locale.gd` | 3 条运动提示（中英）：`hint.motion_buoy/hoist/cargo` |
| `TURBBIT/scripts/autoload/game_manager.gd` | 事故分级表与 `accident_severity()` |
| `TURBBIT/scripts/ui/banner.gd` | 横幅按轻/重事故换样式与停留时间 |
| `TURBBIT/scripts/actors/rabbit_controller.gd` | 神游偏移/晃动/空中修正读取统一上限；姿态与自主动作配合 |
| `TURBBIT/scripts/actors/turtle_controller.gd` | 壳自动漂移让位给玩家输入 |
| `TURBBIT/scenes/race.tscn` | 实例化 `zone2_dock.tscn` |
| `TURBBIT/scripts/test/stage1_selftest.gd` | 新参数下的自检口径 |
| `TURBBIT/scripts/test/stage3_playtest.gd` | 蹲低领先量补偿（跟随神游延迟） |
| `TURBBIT/scripts/test/stage6_balance_matrix.gd` | D 段接手提前量 `DRIFT_LEAD = 60 px`（把神游延迟算进剧本，判定项不变） |

### 2.2 新增

| 文件 | 用途 |
|---|---|
| `TURBBIT/scripts/world/zone2_layer.gd` | Z2 六层共用绘制脚本（按 `layer` 枚举分支） |
| `TURBBIT/scripts/world/zone2_dock.gd` | 分层容器：区域开关、边界淡入淡出、每帧喂相机 |
| `TURBBIT/scenes/zone2_dock.tscn` | 六层节点 + 参数（parallax / fade_lag / z_index） |
| `TURBBIT/scripts/test/stage8_drift_control.gd` + 场景 | P0-A 探针 |
| `TURBBIT/scripts/test/stage8_accident_recovery.gd` + 场景 | P0-B 探针 |
| `TURBBIT/scripts/test/stage8_obstacle_identity.gd` + 场景 | P1-C 探针 |
| `TURBBIT/scripts/test/stage8_dock_layers.gd` + 场景 | P1-D 探针 |
| `TURBBIT/scripts/test/stage8_hz_regression.gd` + 场景 | P2-8 探针 |

### 2.3 证据文件

- `docs/reports/longrun/core-feel-08-p0a-drift-control.json`
- `docs/reports/longrun/core-feel-08-p0b-accident-recovery.json`
- `docs/reports/longrun/core-feel-08-p1c-obstacle-inventory.json`（55 行）
- `docs/reports/longrun/core-feel-08-p1c-rock-before-after.json`（9 行）
- `docs/reports/longrun/core-feel-08-p1d-dock-layers.json`
- `docs/reports/longrun/core-feel-08-p2-hz.json`
- `screenshots/core-feel-08-dock_*.png`（6 张）、`screenshots/core-feel-08-id_*.png`（7 张）
- `docs/reports/stage3-run.log`（本轮重跑的两圈真实赛道）

---

## 3. 神游四阶段：行为差异与参数

### 3.1 参数（`scripts/systems/tuning.gd`）

| 参数 | 值 | 作用 |
|---|---|---|
| `DRIFT_CALM_END` | 3.0 s | 0–3 s 不分心 |
| `DRIFT_DISTRACTED_END` | 6.0 s | 3–6 s 分心 |
| `DRIFT_RESTLESS_END` | 9.0 s | 6–9 s 坐不住 |
| `DRIFT_CAP` | 12.0 s | 封顶；永远到不了落水/翻肚皮 |
| `DRIFT_RECOVER_RATE` | 2.0 /s | 受控 0.5 s 后开始收回 |
| `DRIFT_REACT_MIN` | 0.04 s | 分心起步延迟 |
| `DRIFT_REACT_RABBIT_MAX` | 0.22 s | BITT 恶作剧上限 |
| `DRIFT_REACT_TURTLE_MAX` | 0.26 s | TUBO 恶作剧上限 |
| `BITT_AUTOCROUCH_PERIOD / LEN` | 2.6 s / 0.35 s | BITT 自己趴一下 |
| `TUBO_AUTODRIFT_PX` | 14 px | 壳自己漂的深度上限 |
| `DRIFT_MAX_OFFSET` | 22 px | 兔子最大偏移；仍站在 92 px 宽的壳上 |

### 3.2 延迟表（探针读出的配置值）

| 角色 | CALM | DISTRACTED | RESTLESS | MISCHIEF |
|---|---|---|---|---|
| BITT（兔子起跳） | 0 ms | 70 ms | 140 ms | 213 ms |
| TUBO（乌龟下潜） | 0 ms | 90 ms | 165 ms | 255 ms |

### 3.3 实测（真实按键路径，`Input.action_press`）

| 实测 | CALM | DISTRACTED | RESTLESS | MISCHIEF |
|---|---|---|---|---|
| BITT 起跳延迟 | 17 ms | 83 ms | 150 ms | 217 ms |
| TUBO 下潜延迟 | 17 ms | 100 ms | 167 ms | 267 ms |

- 四档严格递增；延迟后按键**仍然执行**（每档都记录到动作生效）。
- 按住不放：CALM 立即下潜，神游涨满也不会重新计时。
- 自主动作：BITT 8 s 内自己趴 3 次（间隔 2.62 s）；TUBO 恶作剧时壳漂 18 px（自动漂移峰值 14 px），不会潜到底，按住 ↓ 立即让位。
- 恢复：从满值回到延迟 0 用 5.02 s，期间报“兔子回过神了”，不换手。
- 不会反向（按 ↓ 不会上浮）、不会强制换人、8 s 内 BRO/事故增量均为 0。

---

## 4. 事故恢复规则和测试结果

### 4.1 分级

| 事故 | 分级 | 线上来源 | 处理 | 恢复 |
|---|---|---|---|---|
| `RABBIT_STUN` / `RABBIT_HIT` | 轻 | 兔子层障碍（低梁/海鸟/岩）撞到，仍在壳上 | 0.8 s 硬直 | 计时结束自动回 RIDING |
| `RABBIT_WATER` | 重 | 空中撞落水 / 落壳擦水线 | 下落→水花→3.2 s 救援窗 | 自己潜过去接；不接也会被冲回壳上 |
| `OXYGEN_OUT` | 重 | 潜太深太久，氧气 8→0 | 2 s 紧急上浮演出 | 自动回巡航水深，氧气回 5.0 |
| `BRO_BREAK` | 重 | BRO METER 三格 | 1.8 s 联合惩罚演出 | 演出结束清空 BRO、恢复巡航 |
| `TURTLE_WAVE / TURTLE_DIVE_LATE` | 轻 | 乌龟层障碍（浮木/鲨鱼/拱岩/高墙） | 90 ms 停顿+震动+下沉/掀翻+龟速×0.6 | 1 s 内回正，操控一直可用 |
| `RABBIT_SLIP` / `TURTLE_REEF` / `RABBIT_AIR` | — | **无线上入口**（历史/截图入口） | 保留分支与文案 | 不在本轮证据范围内，如实单列 |

### 4.2 实测结果

| 用例 | 结果 |
|---|---|
| 真撞岩 → `RABBIT_STUN` | 记 1 格；0.80 s 后回 RIDING；控制人未变；恢复后按 ↑ 真的离地 |
| 空中撞岩 → `RABBIT_WATER` | 记 1 格（下游落水不追罚）；4.35 s 后回到壳上；全程不按键也能恢复；救援窗内乌龟仍可下潜 |
| 潜到没气 → `OXYGEN_OUT` | 记 1 格；0.32 s 紧急上浮结束；氧气回 5.05；不进入事故状态 |
| 第三格 → 联合惩罚 | `BRO_BREAK` 演出 5.15 s，结束后 METER 清零、回骑乘、不锁控制 |
| 浮木撞壳 | 不进入事故状态；记 1 格；下沉可见后果；1.82 s 回正且仍能下潜 |
| 同一事件第二笔 | 不记账；硬直/落水表现照常播；整件事只记一格，记录升级为 joint |
| 判定框 | 两次装载尺寸完全相同；主带高度仍为数据原值（岩 42 / 梁 100 / 木 218） |
| 真碰撞 | 龟壳仍被浮木顶住（没有穿过去），撞上照常记 1 格 |

---

## 5. 全部障碍物身份及区域归属表

清点口径：`LevelDataScript.groups()` 的 55 个障碍实例；区域按实例起点所在 zone 判定。
18 个动态障碍（9 潮汐岩 + 3 swell_log + 6 ambush_shark）全部有运动来源说明。

| 障碍 ID | 区域 | 身份 identity | 机制 kind | 分类 | 运动来源 | 互动 | 玩家对策 |
|---|---|---|---|---|---|---|---|
| bird1 | Z1 SUNNY COAST | diving_gull | LOW_BIRD | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低（兔子）或下潜（乌龟）从俯冲空域下方过 |
| rock1 | Z1 SUNNY COAST | sea_rock | SURFACE_ROCK | A/RABBIT-JUMP | 静止 | JUMP OVER | 跳跃越过去；乌龟巡航从岩下过 |
| gate1 | Z1 SUNNY COAST | reef_arch | DIVE_GATE | D/TURTLE-DIVE | 静止 | TURTLE DIVE | 按住下潜（乌龟）穿过礁拱 |
| rock2 | Z1 SUNNY COAST | sea_rock | SURFACE_ROCK | A/RABBIT-JUMP | 静止 | JUMP OVER | 跳跃越过去；乌龟巡航从岩下过 |
| log1 | Z1 SUNNY COAST | drift_log | FLOATING_LOG | B/COMBINED | 静止 | JUMP + DIVE | 跳跃→换手→下潜的连招 |
| shark1 | Z1 SUNNY COAST | reef_shark | SHARK | C/TURTLE-LEAP | 巡游/伏击（ambush_shark），按距离状态机上下 | TURTLE LEAP | 跃起（乌龟）从鲨鱼上方过 |
| rock3 | Z1 SUNNY COAST | buoy | SURFACE_ROCK | A/RABBIT-JUMP | 锚绳拴在海底，随涌浪上下 | JUMP OVER | 跳跃越过去；系泊浮标随涌浪起落，等它落到低点再跳 |
| beam2 | Z1 SUNNY COAST | dock_beam | LOW_BEAM | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低从梁下过；梁柱扎在海底，链上看得出高低 |
| wall1 | Z1 SUNNY COAST | high_wall | HIGH_WALL | B/COMBINED | 静止 | LEAP + KICK | 跃起→换手→踢墙的连招 |
| gate2 | Z1 SUNNY COAST | reef_arch | DIVE_GATE | D/TURTLE-DIVE | 静止 | TURTLE DIVE | 按住下潜（乌龟）穿过礁拱 |
| bird2 | Z1 SUNNY COAST | diving_gull | LOW_BIRD | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低（兔子）或下潜（乌龟）从俯冲空域下方过 |
| beam1 | Z1 SUNNY COAST | dock_beam | LOW_BEAM | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低从梁下过；梁柱扎在海底，链上看得出高低 |
| shark3 | Z2 CORAL CHAOS | reef_shark | SHARK | C/TURTLE-LEAP | 巡游/伏击（ambush_shark），按距离状态机上下 | TURTLE LEAP | 跃起（乌龟）从鲨鱼上方过 |
| beam3 | Z2 CORAL CHAOS | dock_beam | LOW_BEAM | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低从梁下过；梁柱扎在海底，链上看得出高低 |
| rock4 | Z2 CORAL CHAOS | dock_crate | SURFACE_ROCK | A/RABBIT-JUMP | 挂在码头吊钩上，随吊臂升降 | JUMP OVER | 跳跃越过去；吊装货箱随吊臂升降，看准它升起的那拍 |
| gate3 | Z2 CORAL CHAOS | reef_arch | DIVE_GATE | D/TURTLE-DIVE | 静止 | TURTLE DIVE | 按住下潜（乌龟）穿过礁拱 |
| bird3 | Z2 CORAL CHAOS | diving_gull | LOW_BIRD | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低（兔子）或下潜（乌龟）从俯冲空域下方过 |
| log2 | Z2 CORAL CHAOS | drift_log | FLOATING_LOG | B/COMBINED | 随浪涌整体起伏（swell_log） | JUMP + DIVE | 跳跃→换手→下潜的连招 |
| rock5 | Z2 CORAL CHAOS | dock_crate | SURFACE_ROCK | A/RABBIT-JUMP | 挂在码头吊钩上，随吊臂升降 | JUMP OVER | 跳跃越过去；吊装货箱随吊臂升降，看准它升起的那拍 |
| beam4 | Z2 CORAL CHAOS | dock_beam | LOW_BEAM | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低从梁下过；梁柱扎在海底，链上看得出高低 |
| wall2 | Z2 CORAL CHAOS | high_wall | HIGH_WALL | B/COMBINED | 静止 | LEAP + KICK | 跃起→换手→踢墙的连招 |
| rock6 | Z2 CORAL CHAOS | sea_rock | SURFACE_ROCK | A/RABBIT-JUMP | 静止 | JUMP OVER | 跳跃越过去；乌龟巡航从岩下过 |
| gate4 | Z2 CORAL CHAOS | reef_arch | DIVE_GATE | D/TURTLE-DIVE | 静止 | TURTLE DIVE | 按住下潜（乌龟）穿过礁拱 |
| bird4 | Z2 CORAL CHAOS | diving_gull | LOW_BIRD | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低（兔子）或下潜（乌龟）从俯冲空域下方过 |
| log3 | Z2 CORAL CHAOS | drift_log | FLOATING_LOG | B/COMBINED | 静止 | JUMP + DIVE | 跳跃→换手→下潜的连招 |
| rock7 | Z2 CORAL CHAOS | dock_crate | SURFACE_ROCK | A/RABBIT-JUMP | 挂在码头吊钩上，随吊臂升降 | JUMP OVER | 跳跃越过去；吊装货箱随吊臂升降，看准它升起的那拍 |
| beam5 | Z2 CORAL CHAOS | dock_beam | LOW_BEAM | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低从梁下过；梁柱扎在海底，链上看得出高低 |
| shark5 | Z2 CORAL CHAOS | reef_shark | SHARK | C/TURTLE-LEAP | 巡游/伏击（ambush_shark），按距离状态机上下 | TURTLE LEAP | 跃起（乌龟）从鲨鱼上方过 |
| bird5 | Z2 CORAL CHAOS | diving_gull | LOW_BIRD | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低（兔子）或下潜（乌龟）从俯冲空域下方过 |
| log4 | Z2 CORAL CHAOS | drift_log | FLOATING_LOG | B/COMBINED | 静止 | JUMP + DIVE | 跳跃→换手→下潜的连招 |
| gate5 | Z2 CORAL CHAOS | reef_arch | DIVE_GATE | D/TURTLE-DIVE | 静止 | TURTLE DIVE | 按住下潜（乌龟）穿过礁拱 |
| shark6 | Z3 MUSCLE MAYHEM | reef_shark | SHARK | C/TURTLE-LEAP | 巡游/伏击（ambush_shark），按距离状态机上下 | TURTLE LEAP | 跃起（乌龟）从鲨鱼上方过 |
| beam6 | Z3 MUSCLE MAYHEM | dock_beam | LOW_BEAM | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低从梁下过；梁柱扎在海底，链上看得出高低 |
| rock8 | Z3 MUSCLE MAYHEM | drift_crate | SURFACE_ROCK | A/RABBIT-JUMP | 被大浪推着浮沉，随浪谷起伏 | JUMP OVER | 跳跃越过去；漂流货箱随大浪浮沉，看准浪谷再跳 |
| gate6 | Z3 MUSCLE MAYHEM | reef_arch | DIVE_GATE | D/TURTLE-DIVE | 静止 | TURTLE DIVE | 按住下潜（乌龟）穿过礁拱 |
| log5 | Z3 MUSCLE MAYHEM | drift_log | FLOATING_LOG | B/COMBINED | 随浪涌整体起伏（swell_log） | JUMP + DIVE | 跳跃→换手→下潜的连招 |
| bird6 | Z3 MUSCLE MAYHEM | diving_gull | LOW_BIRD | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低（兔子）或下潜（乌龟）从俯冲空域下方过 |
| wall3 | Z3 MUSCLE MAYHEM | high_wall | HIGH_WALL | B/COMBINED | 静止 | LEAP + KICK | 跃起→换手→踢墙的连招 |
| beam7 | Z3 MUSCLE MAYHEM | dock_beam | LOW_BEAM | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低从梁下过；梁柱扎在海底，链上看得出高低 |
| rock9 | Z3 MUSCLE MAYHEM | drift_crate | SURFACE_ROCK | A/RABBIT-JUMP | 被大浪推着浮沉，随浪谷起伏 | JUMP OVER | 跳跃越过去；漂流货箱随大浪浮沉，看准浪谷再跳 |
| gate7 | Z3 MUSCLE MAYHEM | reef_arch | DIVE_GATE | D/TURTLE-DIVE | 静止 | TURTLE DIVE | 按住下潜（乌龟）穿过礁拱 |
| log6 | Z3 MUSCLE MAYHEM | drift_log | FLOATING_LOG | B/COMBINED | 随浪涌整体起伏（swell_log） | JUMP + DIVE | 跳跃→换手→下潜的连招 |
| bird7 | Z3 MUSCLE MAYHEM | diving_gull | LOW_BIRD | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低（兔子）或下潜（乌龟）从俯冲空域下方过 |
| shark8 | Z3 MUSCLE MAYHEM | reef_shark | SHARK | C/TURTLE-LEAP | 巡游/伏击（ambush_shark），按距离状态机上下 | TURTLE LEAP | 跃起（乌龟）从鲨鱼上方过 |
| beam8 | Z3 MUSCLE MAYHEM | dock_beam | LOW_BEAM | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低从梁下过；梁柱扎在海底，链上看得出高低 |
| rock10 | Z3 MUSCLE MAYHEM | drift_crate | SURFACE_ROCK | A/RABBIT-JUMP | 被大浪推着浮沉，随浪谷起伏 | JUMP OVER | 跳跃越过去；漂流货箱随大浪浮沉，看准浪谷再跳 |
| log7 | Z3 MUSCLE MAYHEM | drift_log | FLOATING_LOG | B/COMBINED | 静止 | JUMP + DIVE | 跳跃→换手→下潜的连招 |
| bird8 | Z3 MUSCLE MAYHEM | diving_gull | LOW_BIRD | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低（兔子）或下潜（乌龟）从俯冲空域下方过 |
| shark9 | Z3 MUSCLE MAYHEM | reef_shark | SHARK | C/TURTLE-LEAP | 巡游/伏击（ambush_shark），按距离状态机上下 | TURTLE LEAP | 跃起（乌龟）从鲨鱼上方过 |
| beam9 | Z3 MUSCLE MAYHEM | dock_beam | LOW_BEAM | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低从梁下过；梁柱扎在海底，链上看得出高低 |
| rock11 | Z3 MUSCLE MAYHEM | drift_crate | SURFACE_ROCK | A/RABBIT-JUMP | 被大浪推着浮沉，随浪谷起伏 | JUMP OVER | 跳跃越过去；漂流货箱随大浪浮沉，看准浪谷再跳 |
| gate8 | Z3 MUSCLE MAYHEM | reef_arch | DIVE_GATE | D/TURTLE-DIVE | 静止 | TURTLE DIVE | 按住下潜（乌龟）穿过礁拱 |
| log8 | Z3 MUSCLE MAYHEM | drift_log | FLOATING_LOG | B/COMBINED | 静止 | JUMP + DIVE | 跳跃→换手→下潜的连招 |
| bird9 | Z3 MUSCLE MAYHEM | diving_gull | LOW_BIRD | A/RABBIT-CROUCH | 静止 | CROUCH DOWN | 蹲低（兔子）或下潜（乌龟）从俯冲空域下方过 |
| rock12 | Z3 MUSCLE MAYHEM | drift_crate | SURFACE_ROCK | A/RABBIT-JUMP | 被大浪推着浮沉，随浪谷起伏 | JUMP OVER | 跳跃越过去；漂流货箱随大浪浮沉，看准浪谷再跳 |

---

## 6. 两块移动石头的最终处理方式

### 6.1 事实澄清

设计案写的是“两块移动石头”。按当前关卡数据实际清点，`tide_rock` 机制共有 **9 个实例**：

| 区域 | 实例 |
|---|---|
| Z1 | `rock3` |
| Z2 | `rock4`、`rock5`、`rock7` |
| Z3 | `rock8`、`rock9`、`rock10`、`rock11`、`rock12` |

报告按“9 块”处理，不把 9 块说成 2 块。

### 6.2 处理选择

保持机制、改身份与画法（把“石头在动”改成“它本来就是会动的东西”）：

- Z1 `rock3` → 系泊浮标 `buoy`
- Z2 `rock4/5/7` → 码头吊装货箱 `dock_crate`
- Z3 `rock8–12` → 漂流货箱 `drift_crate`

没有把机制搬到 Z2 室内，也没有删除任何一块——删除会改变 55 个障碍的节奏与计分统计，超出本轮授权。

### 6.3 机制对照（修改前 / 修改后）

`core-feel-08-p1c-rock-before-after.json` 对 9 块逐项比对：zone、x、w、motion 名、amp（52 px）、period（3.6 s）**完全相同**，`physics_identical` 全部为 `true`；变化的只有 `identity`（null → buoy / dock_crate / drift_crate）、画法和底栏提示。

截图：`core-feel-08-id_sea_rock_static.png`、`core-feel-08-id_buoy_crest/trough.png`、`core-feel-08-id_dock_crate_crest/trough.png`、`core-feel-08-id_drift_crate_crest/trough.png`（峰/谷两拍各一张，能看出浮体跟着浪走）。

---

## 7. 第二区域场景分层：节点结构、参数与截图

### 7.1 节点结构

`scenes/race.tscn` → `Zone2Dock`（实例 `scenes/zone2_dock.tscn`）：

```
Zone2Dock (Node2D, zone2_dock.gd)
├── BG_Far          z=-100  parallax=0.30  fade_lag=0    远处墙、拱窗、光柱、远桩
├── BG_Mid          z=-90   parallax=0.50  fade_lag=300  对岸仓库、屋顶、门、窗、平台、五级台阶
├── BG_Props        z=-80   parallax=0.70  fade_lag=600  木箱、货桶、小船与缆绳（压暗）
├── Gameplay_Canal  z=-70   parallax=1.00               中央水渠、水面、岸沿、区域两端闸门
├── FG_Near         z=50    parallax=1.15  fade_lag=1500 近景木桩、绳索、底部波浪
└── FG_Overhead     z=60    parallax=1.08  fade_lag=1300 顶部横梁、立柱、吊臂、滑轮、绳网
```

- 背景三层与玩法空间彻底分开：`Zone2Dock` 子树里碰撞节点数 = **0**。
- 近景/顶梁不进入判定带：顶梁最低 `y=104`（<130），近景最高 `y=678`（>450）。
- 视差锚定在区域起点（`ZONE_START=15000`），镜头走 1200 px 时六层屏幕位移：
  `-360 / -600 / -840 / -1200 / -1380 / -1296` px（严格“远慢近快”）。
- 区域外（`<15000-1600` 或 `>39000+1600`）整组隐藏；边界按层 `fade_lag` 淡入淡出，水渠层不淡入并把水面裁到区域范围内，避免边界露洞或双水。

### 7.2 截图

| 截图 | 内容 |
|---|---|
| `screenshots/core-feel-08-dock_entry.png` | 刚进区域：闸门、水渠开始、层次淡入 |
| `screenshots/core-feel-08-dock_inside.png` | 区域内：对岸仓库/台阶、顶梁、近景桩 |
| `screenshots/core-feel-08-dock_mid.png` | 中段：完整六层 |
| `screenshots/core-feel-08-dock_mid_plus240.png` | 中段再前进 240 px：验证横向滚动与视差 |
| `screenshots/core-feel-08-dock_far.png` | 后段：纵深与远景窗光 |
| `screenshots/core-feel-08-dock_exit.png` | 出口：闸门、层次淡出 |

截图由 `race.gd` 的 `--capture-dock` 在真实比赛场景里按世界位置定点拍摄，不是独立测试场景。

### 7.3 占位 vs 可复用

| 部分 | 性质 |
|---|---|
| 六层节点、z 顺序、视差/淡入参数、区域开关 | **可直接复用**：结构已定型，参数在场景里可调 |
| 仓库、台阶、梁架、桩、绳网、闸门的**形状与配色** | **占位**：全部由 `draw_*` 基础图元拼出，没有任何生成/下载素材；正式美术替换时只需换绘制函数，不动节点结构 |
| 水渠波纹、光柱、光斑 | **占位**：程序化绘制，用于验证层次是否读得清 |
| 底栏运动提示文案 | **可复用**：中英双语已进 locale |

---

## 8. 自动化验证结果

### 8.1 本轮新增探针

| 探针 | 判什么 | 结果 |
|---|---|---|
| `stage8_drift_control` | 四阶段延迟、按住不重计、自主动作、恢复、不反向/不锁死 | **PASS**（全绿） |
| `stage8_accident_recovery` | 事故来源表、轻/重恢复、同一事件一次、判定框、真碰撞 | **PASS**（全绿） |
| `stage8_obstacle_identity` | 55/55 有身份、43 条按种类默认、9 块按区域换身份、18 条动态有来源、提示中英 | **PASS**（7/7） |
| `stage8_dock_layers` | 六层齐全、z 顺序、视差分层、背景零碰撞、边界开关、遮挡带 | **PASS**（7/7） |
| `stage8_hz_regression` | 30/60/120 Hz 下延迟/巡航距离/障碍振幅/事故恢复/神游恢复/视差 | **PASS**（7/7） |

### 8.2 30/60/120 Hz 实测

| 指标 | 30 Hz | 60 Hz | 120 Hz | 判定 |
|---|---|---|---|---|
| BITT 起跳延迟 | 0.233 s | 0.233 s | 0.225 s | 极差 0.008 s |
| TUBO 下潜延迟 | 0.300 s | 0.283 s | 0.275 s | 极差 0.025 s |
| 3 s 巡航距离 | 660.0 px | 660.0 px | 660.0 px | 完全一致 |
| 潮汐岩振幅（峰谷） | 104.0 px | 104.0 px | 104.0 px | =2×52 px |
| 轻事故恢复 | 0.83 s | 0.80 s | 0.81 s | 极差 0.03 s |
| 神游恢复 | 4.93 s | 4.97 s | 4.97 s | 极差 0.04 s |
| Z2 六层视差位移 | 六层三次完全相同 | | | 与帧率无关 |

### 8.3 真实赛道两圈（含菜单/重开/结算）

`docs/reports/stage3-run.log`：

```
RESULT  run1 time=274.5 score=9680 grade=S passed=55 accidents=0
RESULT  run2 time=274.4 score=9680 grade=S passed=55 accidents=0  (Retry)
RESULT  zones=[1, 2, 3]  max_accident=0.00s  max_stuck=0.0s  failures=0
```

- 两圈都经结算界面 Retry 重开；三个区域全部经过；55/55 次干净通过；0 事故、0 卡住。
- 这一条只证明“流程没被改坏”，**不证明有趣**（见 §10）。

### 8.4 既有探针回归（与 `f9b4006` 基线逐条对照）

| 探针 | 基线 `f9b4006` | 当前树 | 结论 |
|---|---|---|---|
| `stage0_selftest` | PASS | PASS | 一致 |
| `stage1_selftest` | PASS | PASS | 一致 |
| `stage2_selftest` | FAIL（9 条） | FAIL（9 条，逐条相同） | 一致（既有失败） |
| `stage3_selftest` | FAIL（3 条） | FAIL（3 条，逐条相同） | 一致（既有失败） |
| `stage4_bilingual` | PASS | PASS | 一致 |
| `stage4_flow` | PASS | PASS | 一致 |
| `stage4_hud_priority` | PASS | PASS | 一致 |
| `stage4_shift_graybox` | PASS | PASS | 一致 |
| `stage4_gear_ab` | 无法解析（工作树缺导入缓存，超时） | 跑完，结论 NO CONCLUSION（legacy） | 基线不可跑，无法对照；非本轮改动引起 |
| `stage4_level_audit` | exit=0，TOTALS 55 组 | exit=0，TOTALS 55 组（逐字相同） | 一致（关卡数据未变） |
| `stage4_metrics` | FAIL（5 条） | FAIL（5 条，逐条相同） | 一致（既有失败） |
| `stage4_bro_brain` | PASS | PASS | 一致 |
| `stage4_bro_meter` | PASS | PASS | 一致 |
| `stage4_bro_dive_matrix` | exit=0，hz 30/60/120 全 pass | exit=0，hz 30/60/120 全 pass | 一致 |
| `stage4_menu_input` | FAIL（18 条） | FAIL（17 条） | 当前少 1 条失败（语言持久化这条本轮通过） |
| `stage4_opening_pause` | FAIL（1 条） | FAIL（1 条，逐条相同） | 一致（既有失败） |
| `stage4_playful_joint_verdict` | PASS | PASS | 一致 |
| `stage7_drift_visible` | PASS | PASS | 一致 |
| `stage7_joint_penalty` | PASS | PASS | 一致 |
| `stage7d_joint_copy` | PASS | PASS | 一致 |
| `stage5_f_lessons` | PASS | PASS | 一致 |
| `stage6_balance_matrix` | PASS | PASS（探针提前量已按神游延迟校准） | 校准后一致，见下注 |

注：`stage6_balance_matrix` 的 D 段是“墙前/门前一刻才接手正在神游的乌龟”的剧本。P0-A 让恶作剧档的按键晚 ~0.26 s 生效，原剧本按“瞬时响应”定提前量，因此第一次跑出现 hits=1 / accidents=2。
这不是关卡不公，而是剧本没有把角色反应算进去：本轮按人类反应给该段加了 `DRIFT_LEAD = 60 px`（≈0.26 s × 220 px/s），机制、区间与判定项都不变，重跑 PASS。
本轮 PASS 的输出另存为 `core-feel-08-p2-balance-matrix.json`；`refine06-p1-balance.json` 已还原成提交里的旧版，旧审计证据不被覆盖。其余被回归探针重写过的旧 JSON（`core-feel-07-joint-penalty`、`phase-v-opening-pause`、`playful04-joint-verdict`、`rebuild05-f-lessons`、`shift02-bro-dive-matrix`、`core-feel-07-drift-visible`）同样已逐份还原，本轮只保留新增的 `core-feel-08-*` 证据。

### 8.5 `best.json` 与阶段

| 项 | 开工前 | 收工后 |
|---|---|---|
| `user://best.json` MD5 | `c322f9a20321c5b618f98db7e4120969` | `c322f9a20321c5b618f98db7e4120969` |
| `docs/STAGE.md` | `STAGE=4` | `STAGE=4` |

---

## 9. 尚未解决的问题

1. **“两块”与“九块”的口径**：设计案写两块，数据里是九块。本轮按九块处理并如实记录；如果制作人本意是只改其中两块，需要在下一轮明确。
2. **区名与教学文案**：`Z2 CORAL CHAOS` 这个名字与新方向（室内木质码头）已经不一致，但改区名会连带改 HUD、结算、教学文案，本轮未擅自改，留给制作人决策。
3. **占位美术的完成度**：Z2 目前是程序化基础图元，轮廓与色块能读，但还不是正式画风；正式美术需要替换 `zone2_layer.gd` 的绘制层。
4. **神游延迟的手感区间**：213–267 ms 是“明显但还能按”的折中值；是否再加重/减轻，需要真人试玩。
5. **旧自检的既有失败**：`stage2_selftest` / `stage3_selftest` / `stage4_metrics` / `stage4_menu_input` / `stage4_opening_pause` 在基线与当前树上失败点逐条一致（见 §8.4），属既有状态，本轮未修。
6. **`stage4_gear_ab` 无法在基线工作树解析**（缺导入缓存时该脚本 parse error 并挂起），当前树能跑完但结论是 `NO CONCLUSION`（旧探针的灰盒前状态）。它不是本轮引入的，也没有被当作通过证据。
7. **乌龟失误与事故的文案边界**：乌龟层失误按“失误”处理、不进事故状态，但 HUD 上仍会看到 BRO 变化；是否需要单独的视觉区分，待试玩反馈。

---

## 10. 需要 Producer 真人试玩确认的项目

1. **神游是否“能感觉到但不烦”**：请连续 20 s 不切换角色，体验四档延迟；重点看恶作剧档（0.22–0.26 s）是否过头。
2. **自主动作是否可接受**：BITT 每 2.6 s 自己趴 0.35 s、TUBO 壳漂 ±14 px；会不会被误认为操作失灵。
3. **事故恢复是否“看起来能救”**：特别是落水救援窗（3.2 s）与氧气耗尽（2 s 上浮）。
4. **9 块浮体的身份是否读得懂**：尤其 Z3 的漂流货箱连排 5 块，会不会仍然觉得“石头在乱动”。
5. **第二区域的空间是否成立**：六层结构、视差速度、顶梁/近景是否挡视线；是否需要调整 `parallax` 或边界淡入长度。
6. **有趣性判断**：本轮没有新增玩法循环，自动化只能证明“没坏、可恢复、按秒一致”。有趣性结论需要真人试玩后给出；在此之前本报告不做“更有趣”的结论。

---

## 11. 有趣性自评（TURBBIT 规则）

- 新增操作能否一句话说清用途：能——神游越深，按键越晚生效，切回角色就恢复。
- 有没有“我做了判断，然后成功了”的瞬间：有——看准浮体低点/高点起跳，探针和截图证明了位移窗口，但**是否好按仍需真人确认**。
- 操作错了有没有可见后果：有——延迟、硬直、落水、下沉都有可见表现。
- 比上一阶段多了一个想再试一次的理由吗：待定。本轮的目标是“可感知、可恢复”，不是“更好玩”。
- 结论：**有保留**。最可能无聊的 30 秒：Z2 中段连续浮体只用等待节奏，玩家没有主动选择。

---

生成时间：2026-11-13
