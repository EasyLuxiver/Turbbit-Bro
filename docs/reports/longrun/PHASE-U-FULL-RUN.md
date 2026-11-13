# PHASE U — §七-10 完整赛道回归 + §七-11 恢复点与验收入口

日期：2026-11-12
阶段：STAGE 4（**未进入 STAGE 5，未宣布最终完成**）
性质：完整赛道回归 + 收尾。玩法数值、关卡几何、物理未改；
只修了测试探针的“读错障碍种类”和结算/菜单残留的固定总分展示。

> 证据类型（分开列，不混写）：
> - **自动化（headless）**：15 个场景 + 2 个补充场景，exit=0、stderr 0 字节。
> - **自动驾驶**：`stage3_playtest.tscn` 按本局实际障碍种类跑完整赛道两圈。
> - **代理驾驶（引擎内输入）**：`Input.action_press` / `Input.parse_input_event`，
>   不是 OS 键位注入，也不是真人。
> - **窗口化自动输入**：真实窗口渲染下跑完与截图。
> - **真人试玩：`NOT TESTED`。**

## 1. 一句话结论

中英文各在真实窗口（非 headless）跑完整赛道两圈：**每圈 55/55、0 事故、0 卡死、
S 评级、三区全到**，stdout 47 条断言全 ok、0 FAIL、stderr **0 行**；
`best.json` 跑前备份、跑后逐字节还原（md5 `1CAC4067611D1B059374F4E1379C4C24`）。
回归中发现并修掉两处测试契约残留（自动驾驶读原始障碍种类、菜单仍显示最高分），
二者都不是玩法改动。

## 2. 首次运行失败与根因（如实记录）

第一次窗口化中文全程跑出 4 条 FAIL：

```
RESULT  run1 time=275.0 score=8450 grade=S passed=55 accidents=3
FAIL  run 1 every passed group is scored (passed=55 scored=52)
FAIL  run 1 has no hazard contacts (["gate3", "rock6", "gate8"])
（run 2 同）
```

`gate3`、`rock6`、`gate8` 正是默认种子 `20261112` 下被换过种类的三组：
`gate3: DIVE_GATE→SHARK`、`rock6: SURFACE_ROCK→DIVE_GATE`、`gate8: DIVE_GATE→LOW_BEAM`。
根因：自动驾驶遍历的是 `LevelDataScript.groups()` 的**原始种类**，
而正式赛道实际装的是 `race.hazard_groups`（Phase P 按种子改写过种类）。
探针按旧动作过新障碍，于是必然撞上。**这是探针缺口，不是正式玩法回归**：
正式赛道本身已经按抽到的种类生成判定框与提示（日志 `SNACK DRAW` 九行可对照）。

该次失败日志在后续复跑中被同名文件覆盖，未单独留存；原始输出已在上方逐行抄录。
修复前 `scored=52/55` 与 `hit_groups=[gate3, rock6, gate8]` 一一对应，可复算。

### 修复

`scripts/test/stage3_playtest.gd`：

- 新增 `_live_groups()`：优先返回 `race.hazard_groups`，为空才退回 `LevelDataScript.groups()`；
- `_autopilot()` 与 `_intersecting_groups()` 都改用 `_live_groups()`；
- 结算页断言补上“时间 + 评级”两项（原断言只查六项统计）。

`scripts/test/stage3_selftest.gd`：结算断言从 `TOTAL SCORE` 改为
`RESCUE SAVES` + “不出现 TOTAL SCORE”。

`scripts/menu.gd` / `scripts/autoload/locale.gd`：回归日志里菜单仍显示
`BEST ... SCORE 100 STREAK 7`，属于 §六“玩家界面的固定总分数字”残留；
改为只显示最佳时间与最长连击（`best_score` 仍保存、仍计算，只是不展示）。

`scripts/menu.gd` / `scripts/ui/pause_menu.gd`：菜单、设置页、退出确认、暂停菜单
仍有 14/15/16 设计字号（1280×720 下实际 11.2–12.8 px），与 §六“解决实际字号仅
12px”冲突；统一抬到 **18 设计 = 14.4 实际**。`stage4_menu_input` 增加 1280×720
真实窗口下的最小字号断言（主菜单 / 退出确认 / 设置 / 暂停 / 结算共 5 处），
并把 push_input 的鼠标坐标按 0.8 缩放到窗口坐标。3 张 1280×720 截图已逐张打开查看：
无截断、无溢出，菜单不再出现最高分。

## 3. 完整赛道结果（窗口化，非 headless）

| 语言 | 圈次 | 完成时间 | 通过组 | 事故 | 卡死 | 评级 | 区域 | 断言 |
|---|---|---|---|---|---|---|---|---|
| 中文 | run1（Enter） | 272.9 s | 55/55 | 0 | 0.0 s | S | 1,2,3 | 47 ok / 0 FAIL |
| 中文 | run2（Retry） | 272.8 s | 55/55 | 0 | 0.0 s | S | 1,2,3 | 47 ok / 0 FAIL |
| 英文 | run1（Enter） | 272.9 s | 55/55 | 0 | 0.0 s | S | 1,2,3 | 47 ok / 0 FAIL |
| 英文 | run2（Retry） | 272.8 s | 55/55 | 0 | 0.0 s | S | 1,2,3 | 47 ok / 0 FAIL |

两圈合并的关键断言（两个语言一致）：

```
ok  run N every passed group is scored (passed=55 scored=55)
ok  run N has no hazard contacts ([])
ok  run N result shows clean/combos/rescues/mistakes/joint, no score
ok  run N result shows time and grade
ok  run N result shows best records
ok  run 2 started from result Retry
ok  no accident lasts >=5s (max 0.00s)
ok  no unrecoverable stall (max 0.0s)
```

内部账本 `score=9500` 仍然按组累计、可回放（`run N replayed score log equals total`），
但玩家界面不再显示固定总分。

## 4. 食物加速在正式赛道里的证据

两圈、九次遭遇都真实触发（`SNACK eaten` 每圈 9 次，每份日志 18 次），
加速速度为赛段基础速的 1.15 倍，日志同时记录 `tur=BOOSTING`：

| 遭遇 | 组 | 区 | 抽到种类（原始） | 加速速度 |
|---|---|---|---|---|
| #1 | beam1 | 1 | LOW_BEAM（固定） | 253 = 220 × 1.15 |
| #2 | rock3 | 1 | SURFACE_ROCK（同） | 253 |
| #3 | gate3 | 2 | SHARK（原 DIVE_GATE） | 276 = 240 × 1.15 |
| #4 | rock6 | 2 | DIVE_GATE（原 SURFACE_ROCK） | 276 |
| #5 | shark5 | 2 | SHARK（同） | 276 |
| #6 | shark8 | 3 | SURFACE_ROCK（原 SHARK） | 299 = 260 × 1.15 |
| #7 | beam8 | 3 | LOW_BEAM（同） | 299 |
| #8 | shark9 | 3 | SURFACE_ROCK（原 SHARK） | 299 |
| #9 | gate8 | 3 | LOW_BEAM（原 DIVE_GATE） | 299 |

两圈、两种语言都是同一张表；日志首行 `LEVEL SEED 20261112`，可原样复现。
这是随机障碍池第一次在**完整赛道自动驾驶**下被真实通过：
修复后的自动驾驶按抽到的种类换动作，#3/#4/#9 全部零接触。

## 5. 逐条验收（9 条）

| # | 标准 | 结果 | 证据 |
|---|---|---|---|
| 1 | 真实窗口两圈，run1 Enter / run2 Retry，每圈 ≥40/55、三区、S–D | **pass** | 上方 §3 表；`fullrun-zh.stdout.log` / `fullrun-en.stdout.log` |
| 2 | 结算页七项且无固定总分 | **pass** | `result shows time and grade`、`... no score`、`... best records`（两语言 × 两圈） |
| 3 | 无 ≥5 s 事故、无不可恢复卡死 | **pass** | `max_accident=0.00s  max_stuck=0.0s` |
| 4 | 正式赛道食物加速真实触发 | **pass** | 每份日志 18 条 `SNACK eaten`、9 条 `tur=BOOSTING`、`LEVEL SEED 20261112`；§4 表 |
| 5 | 无 SCRIPT ERROR，stderr 行数如实记录 | **pass** | `fullrun-*.stderr.log` 各 **0 行**；stdout 中 ERROR/WARNING 0 条 |
| 6 | best.json 备份/逐字节还原 | **pass** | 备份与现文件 md5 均为 `1CAC4067611D1B059374F4E1379C4C24` |
| 7 | 证据类型分清，真人 NOT TESTED | **pass** | 本文件页首分类；全文未把自动输入写成真人 |
| 8 | 有趣性结论 + 最无聊 30 秒 | **pass** | §7：**有保留**；最无聊仍是 Z1 开场 0–30 s |
| 9 | 更新 LONGRUN_STATE / RESUME_PROMPT / 验收入口，不进入 STAGE 5 | **pass** | 三处已更新；`STAGE=4` 未动；见 §8 |

## 6. 回归

### 6.1 headless（15 项，全部 exit=0、stderr 0 字节）

`stage4_metrics` / `stage4_penalty` / `stage4_snack_rush` / `stage4_snack_draw` /
`stage4_snack_zones` / `stage4_rescue_boost` / `stage4_bro_meter` /
`stage4_bilingual` / `stage4_hud_layout` / `stage4_hud_priority` /
`stage4_core_experience` / `stage4_flow` / `stage3_selftest` /
`stage4_shift_graybox` / `stage4_proto`。

日志：`docs/reports/logs/phase-t/regress/*.log`。

首次批跑 `stage3_selftest` FAIL（`result shows TOTAL SCORE`）——旧契约；
按 §七-9 改为六项 + 救援成功 + 断言不出现总分后重跑 **PASS**。
菜单/暂停字号改动是最后一次生产改动，之后又重跑了
`stage3_selftest` / `stage4_flow` / `stage4_bilingual` / `stage4_menu_input`：
全部 PASS、stderr 0 行、`exit=0`。

### 6.2 窗口化补充

| 场景 | 结果 | 日志 |
|---|---|---|
| `stage4_menu_input` | **PASS**（41 ok；窗口 1280×720、scale 0.8；5 处最小字号均 18 设计 / 14.4 实际） | `regress/stage4_menu_input.log` |
| `stage4_hud_contrast` | **PASS**（65 行，最差仍 ≥4.5:1） | `regress/stage4_hud_contrast.log` |

`ui-menu-zh.png` / `ui-pause-zh.png` / `ui-result-zh.png`（均 1280×720）已逐张查看：
文字完整、面板不溢出，菜单纪录行只有 `最佳 296.63 秒 连击 54`。

### 6.3 玩家纪录

所有会冲线的场景跑前从 `best.before-phase-t.json` 还原，跑后再还原；
最终 `best.json` 内容仍是
`{"score_model":2,"best_time":296.63,"best_accidents":0,"best_score":-1,"best_streak":54}`，
md5 与备份一致。测试成绩（272.9 s / 9500）没有写进正式纪录。

## 7. 有趣性

**有保留。**

- 改善：随机障碍在本局真正生效且可被正确应对（自动驾驶 9/9 食物遭遇零接触），
  `TURBO!` 状态与结算七项都在正式流程里出现；菜单不再用最高分做进度暗示。
- 没改善：**本阶段最无聊的 30 秒仍是 Z1 开场 0–30 s**（x≈0–6600）：
  前 5.91 s 无输入，第一个连招在 t≈49.6 s。Phase S 与 Phase T 已连续两次
  指到同一处；按 `TURBBIT/CLAUDE.md`，下一轮必须**先改这一段**，不能直接推进。
- 本轮没有真人手感数据，以上只代表自动/代理运行。

## 8. §七-11 收口

- `LONGRUN_STATE.md`：LAST_UPDATED 与本轮结果已写；#10、#11 标 DONE；
  NEXT 指向“下一轮先解决 Z1 开场空跑；真人试玩仍 NOT TESTED；不进入 STAGE 5”。
- `RESUME_PROMPT.md`：已改为 `-02` 当前状态（原文仍可直接交给新会话）。
- 制作人验收入口：`PRODUCER-ACCEPTANCE.md`（启动命令、看什么、哪些结论未验证）。
- `docs/STAGE.md` 仍是 `STAGE=4`；**没有进入 STAGE 5，也没有宣布最终完成。**

## 9. 已知问题 / 未验证

| 项 | 现状 |
|---|---|
| 真人试玩 | `NOT TESTED`；所有手感、难度、有趣性结论都没有真人数据 |
| Z1 开场空跑 | 5.91 s 无输入；连续两阶段同一处，下一轮先改 |
| Z3 “复杂障碍 ≥5 s 预警” | 与 1100 px 视野上限冲突（Phase Q 已列制作人决策项），未改 |
| 组合判断占比 | Z3 连招占比 20.8% vs Z2 21.1%，是否达标需制作人判断（Phase S） |
| 14.4 px 最小字号 | HUD / 结算 / 菜单 / 设置 / 暂停均已覆盖；这是 720p 可读下限，不是大字号 UI |
| 测试探针契约 | 本次修掉两处（autopilot 种类、菜单总分）；其他旧断言未做全库重写 |

## 10. 复现

```bash
# 中文全程（真实窗口，非 headless；两圈）
D:/Godot_v4.7-stable_win64_console.exe --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage3_playtest.tscn -- --zh \
  > docs/reports/logs/phase-t/fullrun-zh.stdout.log \
  2> docs/reports/logs/phase-t/fullrun-zh.stderr.log

# 英文全程
D:/Godot_v4.7-stable_win64_console.exe --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage3_playtest.tscn \
  > docs/reports/logs/phase-t/fullrun-en.stdout.log \
  2> docs/reports/logs/phase-t/fullrun-en.stderr.log

# headless 回归（15 项）
D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage4_metrics.tscn   # 其余场景同理，见 §6.1
```

跑前/跑后都执行：

```bash
cp "$APPDATA/Godot/app_userdata/Turbbit Bro!/best.before-phase-t.json" \
   "$APPDATA/Godot/app_userdata/Turbbit Bro!/best.json"
```

## 11. QC

任务 `tbb-stage4-full-run`，9 条验收标准动手前已写入
（`LESSONS/REPORTS/qc/tbb-stage4-full-run.json`，创建于 2026-11-12 18:43）。
逐条判定与证据见 §5。
