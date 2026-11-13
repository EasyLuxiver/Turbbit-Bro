# PHASE V — SHIFT FEEL & GAMEPLAY POLISH

任务：`TBB-SHIFT-FEEL-03`（STAGE 4）  
日期：2026-11-12 → 2026-11-13  
状态：**P0 / P1 / P2 全部实现并验证；STAGE=4；交付制作人复核，不宣布最终完成。**

## 0. 范围与冻结令

本轮七项：P0-1 SHIFT 表现、P0-2 输入宽容、P0-3 伙伴自主与后果、
P1-4 Z1 开场节奏、P1-5 碰撞/动作反馈、P1-6 Z3 远距预警、P2-7 开场与暂停占位。

执行中途收到制作人指令：**任务里的美术和音效全部冻结**。此后：

- P1-5 / P1-6 / P2-7 只写玩法逻辑与 Godot 原生 Control / Label / Button，
  没有新增任何图片、字体、音效、音乐或动画素材。
- Opening / Pause 完全是原生控件占位，无音频。
- SHIFT 的程序化电流音是冻结令**之前** P0-1 已接入的（可替换 `burst_stream`），
  未再扩展；若要严格执行冻结，可单独关掉，不影响玩法。

## 1. 逐项结果

### P0-1 SHIFT 电击表现（QC 2–4）

- 正式 `race.tscn` 订阅 `GameManager.shift_shocked`；一次 SHIFT 同一调用内
  恰好 1 发表现 + 1 段音效；电弧、闪光、受激抖动只落在新角色；
  换人当帧位置不变、无冷却、无输入阻塞。
- 证据：`docs/reports/stage4-shift-feel.json`（`subscribed=true`、
  `fx_delta=2`、`sfx_delta=2`、`frames_per_burst=7056`、
  `hud_text='SHIFT   CONTROL: TURTLE'`）。
- 视觉：`screenshots/phase-v-shift.png` —— 正式赛道真实换人当帧的黄色电弧，
  HUD 已同步“当前控制：乌龟 / 乌龟 操控·巡航”。

### P0-2 输入宽容（QC 5–8）

- 兔子跳跃缓冲 120 ms、离壳宽限 100 ms、SHIFT 交接缓冲 120 ms；
  同帧 SHIFT+动作只由新角色执行一次；连续快速 SHIFT 不追发。
- **前后对照（同一次提前 100 ms 按下）**：

| 规则 | 结果 |
|---|---|
| 旧规则（无缓冲，窗口 0 s） | 不跳（按了等于没按） |
| 新规则（窗口 0.12 s） | 落地当帧自动起跳，`buffered_jump age=0.100` |
| 提前 133 ms | 不跳，缓冲过期后也不补发 |

- 30 / 60 / 120 Hz 三档逐条一致：`near=true / far=false`、
  coyote `early=true / late=false`、同帧 `leap=true` 且旧角色 `jumped=false`。
- 证据：`stage4_shift_feel` 本轮复跑 PASS，JSON 中 `jump_buffer.before / near / far`。

### P0-3 伙伴自主与后果（QC 10–11）

- 同一低梁 `beam1`：完全忽略 → 兔子 MISCHIEF drift 封顶、擦梁
  `RABBIT_STUN`、连击清零、BRO METER +1、错误姿势 70 帧，不落水；
  提前 420 px 接管并趴低 → 0 撞击、0 BRO。
- 只神游不失误：12 s drift 封顶，BRO METER +0、事故 +0、仍 RIDING。
- 证据：`docs/reports/stage4-partner-neglect.json`。

### P1-4 Z1 开场节奏（QC 12）

正式赛道从 `RACE_START_X=400` 实跑：

- 0–5 s 无强制输入；5.15 s 第一次趴低（bird1）；9.45 s 第一次跳（rock1）；
  15.00 s 第一次 SHIFT（gate1 下潜）；26.10 s 第一次协同（log1）。
- 不出现大段居中文字；只重排站位，正式组仍 55。
- 证据：`docs/reports/longrun/phase-v-z1-rhythm.json`。

### P1-5 碰撞 / 动作反馈（QC 9、13）

- 兔子碰撞 50 ms 表现停顿、乌龟 90 ms；镜头震动 2.5 px / 6.5 px，
  实测峰值就是 2.5 / 6.5；**只冻结画出来的位置**，物理、碰撞框、输入时序不变。
- 实测判定与改动前一致：兔子 `RABBIT_STUN` + stun 0.80 + 壳速 132=220×0.6；
  乌龟 `TURTLE_WAVE` + dunk>0 + BRO METER +1。
- 落地水花落在兔子真实落点（dx=0.0），0.4 s 消失；
  BRO DIVE 青环、BRO OLLIE 金环分别触发。
- 证据：`docs/reports/longrun/phase-v-collision-feedback.json`；
  截图 `screenshots/phase-v-collision.png`（正式赛道撞低岩：“咚！兔子被撞晕”、
  晃动条、BRO METER 1/3）与 `screenshots/phase-v-rescue.png`
  （接住落水兔子：“接住了！兄弟！”、BRO METER 1/3、水花环）。

### P1-6 Z3 远距预警（QC 14）

- 浮木 `log5`：进入 1300 px（260 px/s = 5.0 s）窗口才亮，实测 lead 4.95 s；
  高墙 `wall3` lead 4.97 s，用高墙自己的图标。
- 图标钉在画面右缘（≤1080 px，屏幕右缘 1100）、画在天空层（世界 y=150），
  不压水面操作带；只暴露前方最近一组，通过后立即换组/熄灭；
  Zone 2 里 550 px 的浮木不亮。
- 截图 `screenshots/phase-v-z3-warning.png`。

### P2-7 开场与暂停占位（QC 15）

- 正式开局自动挂 6.0 s 开场（5–8 s 窗口内），状态仍是 RUNNING；
  任意键/左键立即跳过并消费事件；开场期间比赛不推进、不缓冲输入、HUD 隐藏。
- 暂停页显示 `Take a breath, bro.`，继续 / 重新开始 / 返回主菜单三个原生按钮
  全部实测可用（继续回 RUNNING、重开真的重载 `race.tscn`、返回真的回 `menu.tscn`）。
- 测试场景与 `--capture-*` 不会自动挂开场，避免打乱探针时序；
  `--force-opening` 专门验证。
- 证据：`docs/reports/longrun/phase-v-opening-pause.json`；截图
  `screenshots/phase-v-opening.png`、`screenshots/phase-v-opening-pause.png`。

## 2. 回归

| 项 | 结果 |
|---|---|
| 中文完整主流程 + 完整赛道（两圈，第二圈走结算 R Retry） | **PASS**：272.8 / 272.7 s，9500 分，S，55/55，0 事故，三区，`max_accident=0.00 s`，`max_stuck=0.0 s`，`failures=0`。日志 `docs/reports/stage4-fullrun-zh.log` |
| 30 / 60 / 120 Hz | `stage4_shift_feel` PASS，三档结论一致 |
| HUD / 分数（窗口化，1280×720） | `stage4_hud_score` 44 项全 PASS（含连招、真实落水+接救、中英结果页） |
| 关卡组数 | `stage4_level_audit`：Z1 12 + Z2 19 + Z3 24 = **55 个正式组**；另有 7 个 `proto_*` 调试组只在 `--proto` 用。此前报告里的 “61/62” 是统计错误，已更正；本轮未增删正式组 |
| `best.json` | 跑前 md5 `c322f9a20321c5b618f98db7e4120969`，跑后同值；测试已改成自己快照、结束时原样写回，不再覆盖制作人纪录 |

回归暴露并修正了一处**测试驾驶**问题：全量自动驾驶按乌龟 x 判 log1 起跳点，
未受控兔子有约 18 px 神游漂移，弧线整体后移，擦到浮木尾端上角（`RABBIT_WATER`）。
改成按兔子真实 x 判起跳点后两圈 0 事故。只改测试驾驶，不改游戏物理。

## 3. 未完成 / 已知问题

- **本轮新增的手感项还没有新的真人验证。** 制作人此前自述试玩 3–4 次
  （2026-11-11 意见见 `PRODUCER-PLAYTEST-NOTES.md`），但那在 hitstop、镜头震动、
  Z3 预警、开场/暂停之前。自动探针只证明状态与数值，不证明手感。
- SHIFT 电流音是冻结令前接入的；如需严格冻结，一行常量即可静音。
- Z3 预警图标是圆环 + 文字的原生画法，属于占位视觉；美术解冻后再做正式资产。
- hitstop 按设计只冻结画面；若之后解冻音效/粒子，可再加一层“敲击感”。
- 不进入 STAGE 5，不宣布最终完成。

## 4. 有趣性自评（QC 17）

**结论：有保留。**

1. 新增操作能一句话说清：SHIFT 换人，然后由新角色做一个动作；
   判断点是“谁、在什么时候做”。
2. 有一次“我做了判断，然后成功了”的瞬间：log1 在 5 s 预警里看准浮木，
   兔子跳 + 乌龟潜过去，青环和 BRO DIVE 同时出现；自动驾驶与探针都能稳定复现。
   制作人上一轮的原话是“总算有点乐趣了”，但本轮新加的手感层还没经过他的手。
3. 操作错了有可见后果：撞低岩会“咚！兔子被撞晕”、晃动条上升、BRO METER +1、
   壳速掉到 0.6；完全不管伙伴会擦梁并断连击。
4. 比上一阶段多一个想再试的理由：Z3 现在提前 5 s 给出可读的障碍类型与距离，
   玩家可以专门练“这一组能不能零事故过”，完整赛道 55/55 0 事故成为可见目标。

保留点：Z3 预警可能让 Z3 变简单，hitstop/震动是否“够爽”只能真人判断；
这些都需要制作人实际跑一遍再定。
