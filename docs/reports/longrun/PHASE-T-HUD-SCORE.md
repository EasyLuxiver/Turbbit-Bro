# PHASE T — §七-9 HUD 与评分表现审核

日期：2026-11-12
阶段：STAGE 4（未进入 STAGE 5）
性质：**单系统改动**（HUD / 结算 / 文案），玩法数值、关卡几何、物理一行没动。

> 证据类型：
> - **自动化**：`stage4_hud_score` 44 条断言、`stage4_hud_layout` / `stage4_hud_priority` /
>   `stage4_bilingual` / `stage4_flow` headless 回归。
> - **代理驾驶 / 引擎内输入**：救援段用真实物理撞梁落水，SHIFT 走 `InputEventKey`，
>   ↓ 走 `Input.action_press`。
> - **窗口化自动输入**：1280×720 真实窗口渲染与截图；**不是真人试玩**。
> - **真人试玩：`NOT TESTED`。**

## 1. 一句话结论

固定数字总分已经从玩家界面（HUD 与结算）退出，计算与 `score_log` 原样保留；
结算改为时间 / 干净通过 / 连招 / 救援成功 / 失误 / 联合事故 / 评级七项；
HUD 四要素（当前角色、BRO METER、氧气、加速状态）齐全，`TURBO！` 只在加速时短暂出现；
1280×720 下中英文最小实际字号从 **12 px（部分 10.4 px）** 提到 **14.4 px**，
四角面板合计仍只有 **4.52%（中文）/ 6.10%（英文）**，没有恢复大面积面板。

## 2. 改了什么（`TURBBIT/` 未被 git 跟踪，逐文件列出）

| 文件 | 改动 |
|---|---|
| `scripts/ui/hud.gd` | 删除右上角 `score_label`（固定总分）；HUD 最小设计字号 13/15/16/17 → **18**；只保留角色/时间/氧气/BRO METER/默契/反馈 |
| `scripts/result.gd` | 删除大号总分行；统计行加“救援成功”；最佳纪录行去掉最高分；`_fill_sample()` 补救援样例 |
| `scripts/autoload/game_manager.gd` | 新增 `rescue_success_count`，`_reset_run()` 清零 |
| `scripts/race.gd` | `_rescue_catch()` 里 `rescue_success_count += 1`；连招里程碑 `BRO COMBO` 改到同帧最后发出（原先被“干净通过”当场覆盖） |
| `scripts/autoload/locale.gd` | `hud.turbo` → `TURBO！加速中` / `TURBO!`；新增 `result.rescues`；删除 `hud.score`、`result.score`、`result.new_score`；`result.best` 去掉最高分 |
| `scripts/test/stage4_hud_score.gd` + `scenes/stage4_hud_score.tscn` | 新增窗口化审核探针（44 条断言 + 4 张截图 + JSON） |
| `scripts/test/stage4_bilingual.gd`、`scripts/test/stage4_flow.gd` | 断言跟着新契约走：不再要求总分，改为要求七项且断言总分不出现 |

### 2.1 为什么总分“关掉”而不是“弱化”

指令允许“弱化或关闭”。HUD 上任何持续显示的总分都会被玩家当成核心进度；
`score_log` 与 `total_score` 仍在后台逐笔累计（探针实测 12345 → 12495，且
`score_log` 最后两笔为 `probe_retained` / `probe_retained_2`），分析能力没有丢。
`best.json` 的 `best_score` 字段与 `new_best_score` 判定也保留，只是不再出现在界面上。

### 2.2 顺手修掉的一个真实反馈 bug

`_update_combo()` 原来先发 `BRO COMBO`、再发 `干净通过`，同一帧后者把前者覆盖，
玩家永远看不到连招里程碑。现在里程碑最后发。探针走真实 `_update_combo` 路径
（combo 2 → 越过 bird1 → combo 3），HUD 实际读到 `BRO COMBO！`。

## 3. 逐条验收（11 条）

### 3.1 固定总分退出 HUD，计算保留（#1）

- `total_score = 12345` 后 HUD 全部可见 Label 不含 `12345` / `分数` / `SCORE`。
- `add_score(100)` + `add_score(50)` → 12495；`score_log` 末笔 `probe_retained_2`。
- 证据：`docs/reports/longrun/phase-t-hud-score.json` 的 `checks`、`score_log_last`。

### 3.2 结算七项（#2、#3）

样例：时间 296.63 / 干净通过 55 / 连招 11 / 救援成功 4 / 失误 2 / 联合事故 1 / S。
中英文逐项从页面可见文字里读回；页面不含 `总分` / `TOTAL SCORE` 与 `12460`。
截图见 §5。

### 3.3 HUD 四要素与 TURBO（#4）

| 要素 | 中文实测 | 英文实测 |
|---|---|---|
| 当前角色 | `SHIFT   当前控制：兔子` | `SHIFT   CONTROL: RABBIT` |
| BRO METER | `BRO METER 0/3` | `BRO METER 0/3` |
| 氧气 | `氧气 8.0s` | `AIR 8.0s` |
| 加速状态 | `TURBO！加速中` | `TURBO!` |

食物加速状态来自真实 `race.snack_boost_active()`；探针把它打开后 HUD 才出现该行，
关闭后整行消失（不常驻空行）。中文用全角 `！`，英文用 ASCII `!`。

### 3.4 连招 / 救援反馈（#5）

| 反馈 | 路径 | HUD 实际文字 |
|---|---|---|
| 连招里程碑 | 真实 `_update_combo()`，combo 2→3 | `BRO COMBO！` |
| 救援成功 | 真实撞梁 → `RABBIT_WATER` → SHIFT + 按住 ↓ → `_rescue_catch()` | `接住了！兄弟！` |

救援这一段是正式赛道物理：乌龟先吃下 beam1 的食物（`SNACK eaten x=3250
obstacle=beam1 boost_until=4050 speed=253`），切兔子在梁前 45 px 起跳（错误动作），
撞梁落水，再切回乌龟下潜接住。`rescue_success_count` 0 → 1，只加一次。
证据事件序列：`干净通过！|clean → BRO COMBO！|bro → TURBO！吞下去了！|pop →
接住了！兄弟！|pop`。

### 3.5 1280×720 字号（#6）

真实窗口 `1280×720`，逻辑视口 1600×900，`canvas_items` 缩放 0.8。

| 位置 | 改前设计字号 / 实际 | 改后设计字号 / 实际 |
|---|---|---|
| HUD 提示行（原 15） | 15 / **12.0** | 18 / **14.4** |
| 氧气状态行（原 13） | 13 / **10.4** | 18 / **14.4** |
| 角色行 / 区域 / 进度 / BRO METER（原 16–17） | 16–17 / 12.8–13.6 | 18 / **14.4** |
| 结算最佳纪录行（原 18） | 18 / 14.4 | 18 / 14.4 |
| HUD 其余（时间 25、氧 18、默契 18、反馈 26、预警 22） | ≥14.4 | 不变 |
| 结算其余（58/40/22/24） | ≥17.6 | 不变 |

判定：HUD 与结算页**所有可见文字**（Label + Button）最小实际字号 **14.4 px**，
中文与英文各测一次，均在 1280×720 真实窗口下。

### 3.6 面板面积（#7）

| 语言 | 改前 | 改后 | 阈值 |
|---|---|---|---|
| 中文 | 4.167% | **4.523%** | ≤8% |
| 英文 | 5.281% | **6.101%** | ≤8% |

`stage4_hud_layout` 在 1600×900 与 1280×720 两个窗口尺寸下重跑均 PASS：
面板在视口内、彼此不重叠、不压底部文字、没有 Label 被截断。

### 3.7 窗口化截图（#8）

四张 1280×720 真实窗口截图，我已逐张打开查看：

| 文件 | 看什么 | 结论 |
|---|---|---|
| `screenshots/phase-t-hud-zh-1280x720.png` | 中文 HUD | 三行左上、右上时间/区域/进度、左下氧气+TURBO、右下 BRO METER/默契；无总分；无截断 |
| `screenshots/phase-t-hud-en-1280x720.png` | 英文 HUD | 同上；最长行 `PROGRESS 1% 0/55 GROUPS` 完整 |
| `screenshots/phase-t-result-zh-1280x720.png` | 中文结算 | 七项竖排 + S 评级 + 三个按钮；无总分 |
| `screenshots/phase-t-result-en-1280x720.png` | 英文结算 | 同上；`JOINT ACCIDENTS` 一行完整 |

底部中央的障碍预警（`↓ 趴低`）仍直接压在画面上，没有加回大面板。

### 3.8 回归与纪录保护（#9）

| 回归 | 结果 | 日志 |
|---|---|---|
| `stage4_hud_layout` | **PASS**（4.523% / 6.101%） | `logs/phase-t/stage4_hud_layout.log` |
| `stage4_hud_contrast` | **PASS**（最差 5.08:1，窗口化） | `logs/phase-t/stage4_hud_contrast.log` |
| `stage4_hud_priority` | **PASS**（feedback 0.74 / hint 2.19 / prompt 2.99 s） | `logs/phase-t/stage4_hud_priority.log` |
| `stage4_bilingual` | **PASS** | `logs/phase-t/stage4_bilingual.log` |
| `stage4_flow` | **PASS**（含 `flow test restores best.json byte for byte`） | `logs/phase-t/stage4_flow.log` |
| `stage4_hud_score`（新增） | **PASS** 44/44 | `logs/phase-t/hud-score.log` |

`best.json` 跑前备份为 `best.before-phase-t.json`，跑后 md5
`1CAC4067611D1B059374F4E1379C4C24` 与备份一致，内容仍是
`{"score_model":2,"best_time":296.63,"best_accidents":0,"best_score":-1,"best_streak":54}`。
所有探针都没有冲线（`test_no_finish = true`），`stage4_flow` 自带的备份/还原也通过。

### 3.9 真人试玩（#10）

`NOT TESTED`。上面的“窗口化”是自动运行脚本生成的画面与输入，不是人坐在键盘前玩。

### 3.10 有趣性（#11）

**有保留。**

- 改善了：HUD 不再用一路跳动的总分干扰注意力；`TURBO！`、`BRO COMBO！`、
  `接住了！兄弟！` 都在同一块反馈行出现，玩家能看见“自己做对了什么”。
- 没改善：这一步没有改任何节奏。**本阶段最无聊的 30 秒仍是 Z1 开场 0–30 s**
  （x≈0–6600）：前 5.91 s 没有任何输入，第一个连招在 t≈49.6 s（Phase S 实测），
  HUD 再清楚也填不满这段空跑。连续两个阶段同一处无聊，按 `TURBBIT/CLAUDE.md`
  必须在下一阶段先改再继续——已列入 §七-10 之后的待办，本轮不动关卡。
- 真人手感仍无数据；结论只代表自动/代理运行。

## 4. 已知问题

| 问题 | 现状 | 影响 |
|---|---|---|
| 反馈只显示 0.75 s | 沿用 Phase I 的时长，未改 | `接住了！` 在 1280×720 下可读，但节奏快时容易错过；改时长会牵动 HUD 优先级测试，本轮不动 |
| 最小字号 14.4 px | 设计 18 px × 0.8；再大面板会明显变宽 | 14.4 px 在 720p 属于可读下限，不是“大字号 UI” |
| 总分仍存在后台 | `total_score` / `score_log` / `best_score` 保留 | 玩家界面看不到；分析、评级仍可用 |
| 结算“最佳事故 0”显示 | 一直显示纪录，不区分本局 | 既有行为，未改 |
| Z1 开场空跑 | 5.91 s 无输入，第一个连招 ≈49.6 s | 本轮只做 HUD，不解决；见 §3.10 |

## 5. 复现

```bash
# 主探针：必须窗口化（headless 不渲染，截图会挂起）
D:/Godot_v4.7-stable_win64_console.exe --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage4_hud_score.tscn \
  > docs/reports/logs/phase-t/hud-score.log 2>&1

# 回归
D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage4_hud_layout.tscn
D:/Godot_v4.7-stable_win64_console.exe --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage4_hud_contrast.tscn
D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage4_hud_priority.tscn
D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage4_bilingual.tscn
D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage4_flow.tscn
```

- 数据：`docs/reports/longrun/phase-t-hud-score.json`
- 日志：`docs/reports/logs/phase-t/`
- 截图：`screenshots/phase-t-*.png`
- 跑前纪录：`%APPDATA%/Godot/app_userdata/Turbbit Bro!/best.before-phase-t.json`

## 6. QC

任务 `tbb-stage4-hud-score`，11 条验收标准动手前已写入。
1–9 `pass`（证据见 §3.1–§3.8），10 `pass` 仅表示**报告如实写了 `NOT TESTED`**，
11 `pass` 仅表示**给出了有趣性结论与最无聊 30 秒位置**。
