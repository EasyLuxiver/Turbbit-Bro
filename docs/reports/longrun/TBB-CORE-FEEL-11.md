# TBB-CORE-FEEL-11 SHIFT 核心乐趣与叙事教学重构

- 日期：2026-11-14
- 阶段：`STAGE=4`（未推进 5）
- 边界：只做 SHIFT 原型、7 格开场、60–90 s 教学、文本清理与接入；没有新增正式美术/音频/赛道量产。
- 结论：技术闭环按 QC 逐条判定；趣味性**不宣称通过**，等制作人试玩。

## 1. 本轮完成

### SHIFT

- **B1 基础切换**：沿用既有电击电弧/闪光；从旧角色位置拉弧到新角色。换人期间不冻结物理，0.2 s 锁只拒绝“下一次 SHIFT”，不锁新角色的输入。实测正常巡航换人后速度 220 不重置、位置继续前进。
- **B2 待命角色参与**：
  - 乌龟被切出时，把当前下潜再维持 0.55 s（`standby_dive_t`），不会一切换就上浮；空水里能看见“它继续潜”。
  - 兔子被切出时，把趴低再维持 0.35 s（`standby_crouch_t`）。
  - 但玩家切回兔子、前方 600 px 内是兔子层障碍（岩/梁/海鸟/浮木/高墙）时，主动取消乌龟的下潜尾，让壳回水面；否则兔子连起跳条件都不满足。这是“公平优先于自主”。
  - 跳跃/跃起本来就完整播放；待命速度/巡航不因换人清零。
- **B3 电流接力**：新增 `_relay` 观测窗口 1.4 s：
  - 普通交接：只换人，无奖励。
  - 巧妙交接：切出角色继续手里的动作 + 切入角色在窗口内做了另一个动作（跳/趴/跃/潜），+50，青色环。
  - 完美交接：在巧妙基础上，窗口内完成一次干净通过或 BRO DIVE/OLLIE，+100，金色环 + “完美接力”。
  - 不允许只按 SHIFT 拿奖励；同一次换人只判一次；1.2 s 冷却；事故会取消奖励；救援中不判接力。
- **B4 测试段**：`shift_lab.tscn`：10 组短赛道，覆盖直线巡航、兔子跳、乌龟潜、两种切换、浮木/高墙组合、按 J 手动演示救援/接管；顶部状态行显示两人状态、接力结果、分数和 SHIFT 锁。
- **B5 判定矩阵**：`stage11_shift_relay.tscn` 10 例全过（正常、跳→潜、潜→跳、快速双切、切出继续、碰撞取消、救援、神游、完美、不刷分）。

### 叙事

- 新 `opening_comic.tscn`：7 格连环画，每格 3.5 s，总 24.5 s；任意键下一格，ESC 跳过。
- 故事按任务书：上次比赛 → 错失胜利 → 大表哥登场 → 电击蛋糕 → 意外 → 共享意识 → 训练开始。
- 旁白/角色气泡全部走 Locale；只画原生形状，不引入新美术。
- 主菜单改为大表哥的训练邀请：“兄弟俩，准备好接受训练了吗？” + “大表哥的水上训练挑战” + “开始挑战”；移除阶段/区域/调试文本。

### 教学

- 新 `tutorial.tscn`：接在连环画之后、正式 55 组之前；约 60 s 赛道（13200 px / 220）。
- 4 步：TUBO 跳/趴 → SHIFT 到 BITT 跃/潜 → 第一次电流接力 → 自己过组合。
- 每步只给一个短提示；成功/到达步点才推进；没做到则 900 px 后放行并给 `tutorial.fail` 补充，不卡关。
- 大表哥只在教学覆盖层出现；按 K 可跳过；完成后调用 `GameManager.start_race()`。
- 正式比赛不再出现大表哥；旧 6 s 开场卡只在 `--force-opening` 调试时保留。

### 文本

- `center.bro_full` 改为“两人同时出事 —— 一起翻船！”，不再归因 BRO 槽满。
- `hint.dive_late` 改为“按住 ↓ 下潜；过木后松手上浮”。
- 食物规则：开场/暂停保留完整规则，HUD/hint 缩短成必要信息。
- 术语：失误槽 = `BRO 槽`；干净通过 = `默契`；换人动作 = `换人`；故事用 TUBO/BITT，即时提示用兔子/乌龟。
- `prompt.*` 去掉长句，统一“角色 + 一个动作 + 按键”；`hint.*` 负责失败后的“为什么”。
- 更新 `FEEL11-TEXT-INVENTORY.md` / `feel11-text-inventory.csv`：348 条（343 Locale + 5 条硬编码）。

## 2. 实际接入情况

| 文件 | 改动 / 接入点 |
|---|---|
| `scripts/race.gd` | 电流接力 `_start_relay/_tick_shift_relay/_finalize_relay` + 金色/青色环；待命下潜在兔子障碍前取消；`story_seen` 时不再播旧开场 |
| `scripts/actors/turtle_controller.gd` | `standby_dive_t`：被切出后继续下潜 0.55 s |
| `scripts/actors/rabbit_controller.gd` | `standby_crouch_t`：被切出后继续趴低 0.35 s |
| `scripts/autoload/game_manager.gd` | `story_seen/tutorial_done`；`start_game_flow()`、`start_tutorial()`；`start_race()` 跳过故事/教学 |
| `scripts/menu.gd` | 开始挑战 → `start_game_flow()`；大表哥邀请；移除阶段文本；制作人测试移到设置页 |
| `scripts/ui/opening_comic.gd` + `scenes/opening_comic.tscn` | 7 格连环画，完成/跳过 → 教学 |
| `scripts/test/tutorial.gd` + `scenes/tutorial.tscn` | 4 步教学，完成/跳过 → 正式比赛 |
| `scripts/test/shift_lab.gd` + `scenes/shift_lab.tscn` | 60–90 s SHIFT 实验室 |
| `scripts/test/stage11_shift_relay.gd` + scene | 10 例接力判定矩阵 |
| `scripts/test/stage11_story_flow.gd` + scene | 连环画→教学→比赛→Retry 流程 |
| `scripts/autoload/locale.gd` | 连环画/教学/菜单/接力文本 + FEEL-10 文本清理 |
| `scripts/ui/producer_menu.gd` | 新增 I：SHIFT 实验室 |
| `scripts/test/stage4_*.gd`、`stage3_playtest.gd` | 更新旧文本/旧联合语义/接力计分；不改变产品逻辑 |

## 3. 验证结果

### 代码 / 逻辑验证

- `stage11_shift_relay`：**10/10 PASS**（`docs/reports/longrun/core-feel-11-shift-relay.json`）。
  - 正常换人：`relays=0 score_delta=0 speed=220 dx=330`。
  - 跳→潜：`clever` +50；潜→跳：`clever` +50。
  - 快速双切：只 1 条记录，第二次被 0.2 s 锁拒绝。
  - 切出继续：兔子空中 + 乌龟 `diving` + `standby=0.55`。
  - 碰撞取消：`normal`，接力分 0。
  - 救援中换人：control=turtle，`relays=0`。
  - 完美：`perfect` +100（测试用真实 `note_precise_pass` 条件）。
  - 冷却内再切：不重复计分。
- `stage11_story_flow`：**4/4 PASS**（`docs/reports/longrun/core-feel-11-flow.json`）：首次→连环画；连环画完成→教学；教学完成→比赛；Retry 不再播放故事/教学。
- `stage4_bro_meter`：**PASS**（按 FEEL-10 新语义重写：三格满只武装本次角色，不触发联合；真联合另测）。
- `stage4_menu_input`（窗口化）：**PASS**；主菜单/设置/暂停/重开/结算/键盘焦点均正常。
- `stage4_bilingual`：**PASS**；中文/英文 HUD、菜单、结算无残留混排。
- `stage4_flow`、`stage4_hud_score`：**PASS**。

### 自动化测试

- `stage3_playtest`：**两圈 PASS**：run1 274.0 s / run2 273.9 s，两圈 55/55，0 事故，0 危险接触；
  score 12610、grade S；91 条计分记录全部对表、重放等于总分；`best.json` 复核后已还原。
  两圈都有 `relay_*` 计分记录，说明接力判定在实际 55 组里被触发；`perfect` 是否在
  自动圈里出现未单独计数，见风险 1。
- `stage8_hz_regression`：**PASS**（30/60/120 Hz）。
- `stage4_proto`：**PASS**（浮木/高墙动作与判定未变）。
- `stage7_joint_penalty`：**PASS**。
- `stage4_collision_feedback`：**PASS**。
- `stage4_water_rescue`：**DONE**（主动/自然接与不接都有记录）。
- `stage4_opening_pause`：**PASS**（旧开场卡调试路径与暂停仍可用）。
- `stage4_lesson_prompt`：55 组全部装载，13 个教学键，0 事故。

### 人工操作测试

- 窗口化截图：
  - 7 格连环画：`docs/reports/longrun/feel11/opening-1..7.png`
  - 教学：`tutorial-step1.png` / `tutorial-step3.png`
  - SHIFT 电击与接力：`shift-shock.png` / `shift-relay.png`
  - SHIFT 实验室：`shift-lab.png`
  - 主菜单/设置：`screenshots/feel11-main-menu.png` / `feel11-settings.png`
  - 制作人菜单（A–I）：`docs/reports/longrun/feel10-p1b/producer-menu.png`
- 没有真人 30 分钟试玩；截图和自动化不能替代趣味性判断。

### 尚未验证

- 完美接力只在判定矩阵里用真实条件触发，未在自动跑圈中出现；需要制作人/人类在 SHIFT 实验室里实际做一次 BRO DIVE/OLLIE 验证手感。
- 教学 4 步的真人节奏、跳过/失败补充是否舒服，未做真人测试。
- 连环画/大表哥/角色是原生形状占位，不是正式美术；商业观感未验证。
- 全量 55 组 solution audit 未跑；55/55 结论来自两圈 playtest。

## 4. 风险与未完成项

1. **完美接力的真实手感**：判定条件正确，但自动跑圈只出现 `clever`；`perfect` 需要窗口内干净通过/组合，人类可能觉得太难或太晚才提示。
2. **待命自主的边界**：乌龟下潜尾在兔子障碍前会被取消；这是为了不让“自主”变成“兔子不能跳”。代价是待命行为不是无条件连续。
3. **教学是引导式而非完全自适应**：步骤按动作门 + 900 px 超时推进；不会根据每个失败自动换教法。
4. **美术仍是占位**：连环画/大表哥/角色形状都是原生绘制，没有新增素材；商业观感不足。
5. **分数膨胀**：接力 +50/+100 让自动跑圈从上一轮约 9000 涨到 12610（同时精准通过数也增加）；需要真人确认这是“更聪明更高分”还是“刷分”。
6. **旧调试入口**：旧 6 s 开场卡仍在 `--force-opening` 调试路径；制作人测试移到设置页。
7. **55 组自动跑圈**：见第 3 节；若 final playtest 不过，以失败为准，不把本轮描述为完成。

## 5. 制作人试玩入口

### 正式流程

1. 主菜单 → **开始挑战**。
2. 7 格连环画：任意键下一格，**ESC 跳过**。
3. 教学：按提示操作；**K 跳过教学**。
4. 正式 55 组比赛；暂停/重开/返回菜单沿用原流程。

### SHIFT 实验室（60–90 s）

- 主菜单 → **设置** → **制作人测试** → **I SHIFT 实验室**。
- 直接场景：`res://scenes/shift_lab.tscn`。
- 操作：`↑` 兔子跳、`↓` 兔子趴低、`SHIFT` 换人、乌龟 `↑` 跃起 / `↓` 下潜。
- 看接力：兔子跳起后 SHIFT 给乌龟下潜；或乌龟潜着时 SHIFT 给兔子跳。顶部状态行会显示 `clever/perfect` 与得分，角色身上出现青/金环。
- `R` 重置，`J` 手动演示一次兔子落水救援，`F10` 回制作人菜单。

### 其他制作人入口

制作人菜单 A–I：A 单角色/联合、B 救援免疫、C TUBO 神游、D BITT 神游、E 水流改道、F 状态吊网、G Z1→Z2 入场、H TUBO 拆件、I SHIFT 实验室。

## 6. 状态声明

- `STAGE=4`，未推进 Stage 5。
- 不宣称趣味性已通过；SHIFT 的“巧妙/完美”是否好玩，必须由制作人真人试玩判断。
- 未新增正式美术、音乐、音效或赛道量产；连环画/教学/实验室使用原生占位表现。
- `best.json` 开工备份在 `_attic/2026-11-14/feel11-baseline/best.json`，MD5 `F2D3A6C5DC879B293CCCA17BFB30814B`；playtest 写入 12610 分后已恢复并复核为同一 MD5。
- 完成后停止，等待制作人试玩反馈。
