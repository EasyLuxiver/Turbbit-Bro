# PHASE SHIFT CORE — TBB-SHIFT-CORE-02 交付报告

日期：2026-11-12
阶段：STAGE 4（**未进入 STAGE 5，未宣布最终完成**）
任务原文：`docs/reports/longrun/MISSION-SHIFT-02.md`
QC：`tbb-shift-core-02`（14 条）

> 证据类型（分开列，不混写）：
> - **自动化（headless）**：单元/探针场景，引擎内 `Input.action_press`。
> - **自动驾驶**：`stage3_playtest.tscn` 按本局实际障碍跑完整赛道。
> - **窗口化自动输入**：真实 Vulkan 窗口下跑完整赛道并截图（不是 OS 键位注入）。
> - **制作人试玩：已进行**（自述 3–4 次；书面意见见 `PRODUCER-PLAYTEST-NOTES.md`，
>   最近一条 2026-11-11）。**正式验收未完成；本轮新增机制没有拿到新的真人意见。**

---

## 1. 一句话结论

SHIFT 从“换一个人”变成“管理一个会自己动、会添麻烦、也值得照顾的伙伴”：
海鸟四路线有真实取舍，BRO DIVE 窗口从 0.15 s 抬到 0.30 s 且帧率无关，
兔子落水不再瞬移到乌龟前方、必须真的下潜接，完整赛道中英文各两圈仍是
55/55、0 事故、stderr 0 行。**制作人已试玩并留过意见，但本轮新增机制未获新的真人验证；
STAGE 保持 4。**

---

## 2. 逐项改动与证据

### 2.1 未被控制的一半会自己动（§1–§3）

- `scripts/systems/bro_brain.gd`：CALM 0–3 / DISTRACTED 3–6 / RESTLESS 6–9 /
  MISCHIEF 9+ s；封顶 `DRIFT_CAP`；连续受控 0.5 s 后才按速率恢复；切走保留；
  不写 BRO METER、不自己触发事故。
- 兔子：待命不累积滑落；神游偏移最多 22 px + 1.5–7 px 晃动，直接进碰撞矩形；
  MISCHIEF 空中修正 170.9→144.9 px（air_scale 0.55）。
- 乌龟：待命不持续下沉（12 s 内 y 325.4–341.3 上下晃）；巡航掉速到 0.90×；
  头随 `drift_look_px` 张望/盯食物。
- 证据：`docs/reports/stage4-bro-brain.json`、`screenshots/brain-rabbit-*.png`、
  `brain-turtle-*.png`；headless + 窗口化均 `STAGE4 BRO BRAIN: PASS`。
  12 s 无人管：兔子 mount=RIDING、accident=NONE、最大位移 25.7 px；
  SHIFT 后 drift 10.0 不减、0.4 s 仍 10.0、1.0 s 降 9.0、切走保留 9.5、
  2–7 s 逐步归零；10 次快速 SHIFT 只 10.0→10.5。

### 2.2 食物：控制兔子时也按乌龟真实位置触发（§3）

- 判定只看乌龟位置（|dx|≤70、巡航深度 ±40），与当前操控者无关；
  吃到后 1.15× 当前区速、窗口 2.02 s、0.12 s 平滑回落；不叠加。
- 实测：操控兔子时乌龟在 x≈3337 吃下；253 = 220×1.15；连吃两次仍 253；
  clean_pass 0→0、BRO METER 0。吃前 turtle drift=6.0（DISTRACTED），
  吃下当帧 calm 到 0.0，HUD 从 STANDBY·DRIFTING 回 STABLE。
- 证据：`docs/reports/stage4-snack-contact.json`、
  `screenshots/snack-eat-rabbit-driving.png`；`stage4_snack_zones` 18/18、
  `stage4_snack_rush` 3/3。

### 2.3 海鸟：四路线有取舍，不放大碰撞盒（§4）

三只海鸟 × 四路线各 2.4k 次真实按键代理：

| 路线 | 结果 | 预警/窗口 | 氧气 | 失败形态 |
|---|---|---|---|---|
| crouch（主解） | **42/42** | 1.58–1.86 s | 0 | 无 |
| dive | 59–60/62 | 2.23–2.68 s | 1.13–4.02 | lead≤30 的 2–3 次下潜太晚被撞 |
| jump | 0/42 | — | — | 24 rabbit_hit + 18 rabbit_water@bird1 |
| leap | 0/42 | — | — | rabbit_hit 全部 |

- 做法：LOW_BIRD 改两段几何（打击带 y200 h40 + 俯冲空域 y96 h104），
  兔子/乌龟身体矩形未改；`_draw_bird` 按距离分段给预警/方向/俯冲/拉升。
- 前后对照：`phase-c-windows.shift02-before.json` / `.after.json`；
  原始 `shift02-bird-routes.json`，日志 `logs/phase-shift/bird-routes.log`。
- 结论：crouch 是零成本安全解；dive 能过但要付氧气；jump/leap 必中——
  “其他解存在但不等价无风险”。

### 2.4 BRO DIVE：窗口抬宽，帧率无关（§5）

- `tuning.gd` 新增 `DIVE_GAIN=5.0`，只在主动下潜时使用；目标深度 484、
  上浮 420 未变；没有降自动驾驶速度。
- 最长可用 SHIFT 延迟：Z1 **0.15→0.30 s**（lead 170）、Z2 **0.20→0.35 s**
  （lead 190）、Z3 **0.25→0.35 s**（lead 210）；通过数 11→29、17→39、23→48（/273）。
- 多因子矩阵：3 浮木 × lead 140–220 × delay 0–0.4 × release −40/0/+40/+80
  = 300 次；落点 51–131 px、接人吸附 82–133 px、跳跃与下潜并行 ≥47 帧；
  30/60/120 Hz 同一 lead/delay 下通过/失败逐条一致（各 6/12）。
- 纠错方向：release −40/0 会 turtle_hit，保持到 +40/+80 通过。
- 证据：`shift02-combo-baseline.json` / `shift02-combo-after.json`、
  `shift02-bro-dive-matrix.json`，日志 `combo-baseline.log` / `combo-after.log` /
  `bro-dive-matrix.log`。

### 2.5 兔子落水：真实坐标、真实水花、不瞬移（§6）

- `RABBIT_WATER` 不再把兔子设到 `turtle.x+520 / y=460`；新 `RESCUE_FALLING`
  保留离壳时的世界坐标、水平速度和方向，按 1050 重力下落（终端 950），
  穿过水线 340 才进水花与 `RESCUE_ACTIVE`。
- 逐帧连续性：事故当帧兔子相对乌龟 **0.7 / 5.3 px**（旧值 520）；下落 1.25 s；
  最大单帧位移 12.6 px；**teleports=0/14**；水花与穿水前一帧差 7.5 px，
  `splash_matches_entry` 14/14；入水时兔子真实位于乌龟前方 113–159 px。
- 触发路径两条都测：原型起跳全弧、以及跳起后经 `_rabbit_contact`
  （鸟/浪把空中兔子打下去的同一条代码）。
- 状态区分：`RESCUE_FALLING`（真实下落、不计时）→ `RESCUE_ACTIVE`
  （水花 + 3.2 s 计时 + HUD）→ `RESCUING`（没接住的 0.8 s 有限回壳，
  不是救援成功）。
- 证据：`shift02-water-rescue.json`，日志 `water-rescue.log`。

### 2.6 接人：相对位置 + 速度 + 扫掠容错（§6）

- `can_rescue_catch` 只在 `RESCUE_ACTIVE` 有效；有效区 140 px / dy[−95,+40]；
  先过 `RESCUE_CLOSING_MIN=-60`（乌龟还没追上时不算接住）；
  每帧 prev→now 分 6 段扫掠，低帧率不穿框。
- 吸附只在外圈 165 / dy[−105,+50]，160 px/s；实测巡航高度 dy=64 不触发
  ——必须真下潜。
- 窗口：从现在的水花起算，下潜延迟 0.0/0.2/0.4/0.6/0.8/1.0/1.2 s **全部 caught**
  （0.38–1.63 s）；1.6/2.0 s 与完全不切控制 **missed**，原因
  `turtle_too_shallow`（min_dy 56–67 > 40，兔子已沉到壳顶以下）；
  自然路径不下潜 `too_far_x`。
- 成功：`feedback.rescue_ok` + HUD 计时；失败原因写 `race.rescue_last_reason`
  并输出到窗口化结果行（`result reason mode timestamp`）。
- 证据：`shift02-water-rescue.json`、`rescue-boost.log`（25/25）。

### 2.7 SHIFT 电击只做事件（§8）

- `game_manager.gd`：`signal shift_shocked(from_who, to_who)`，只在
  `toggle_control()` 完成换人那一帧同步 emit；无订阅者、无视觉、无冷却、
  无输入延迟。
- `stage4_shift_graybox` 实测：`events=1`、`same_frame=true`、
  `from/to=turtle→rabbit`；`set_control()` 追加 0 发（`direct_events=0`）。
- 开场 Intro 与暂停界面：`SHIFT02-INTRO-PAUSE.md`（设计稿，见 §4）。

---

## 3. 完整赛道窗口化回归（§7 第 9 步）

窗口化（真实 Vulkan 窗口，非 headless），`stage3_playtest.tscn`：

| 语言 | 圈次 | 时间 | 通过 | 事故 | 卡死 | 评级 | 断言 |
|---|---|---|---|---|---|---|---|
| 中文 | run1 Enter | 272.9 s | 55/55 | 0 | 0.0 s | S | 47 ok / 0 FAIL |
| 中文 | run2 Retry | 272.8 s | 55/55 | 0 | 0.0 s | S | 47 ok / 0 FAIL |
| 英文 | run1 Enter | 272.9 s | 55/55 | 0 | 0.0 s | S | 47 ok / 0 FAIL |
| 英文 | run2 Retry | 272.8 s | 55/55 | 0 | 0.0 s | S | 47 ok / 0 FAIL |

- `STAGE3 PLAYTEST: PASS`；`zones=[1,2,3]`、`max_accident=0.00 s`、
  `max_stuck=0.0 s`、`failures=0`；stderr 各 **0 行**；
  `SNACK eaten` 每份 18 次（两圈 × 九次遭遇）。
- 日志：`docs/reports/logs/phase-shift/fullrun-{zh,en}.{stdout,stderr}.log`。
- `best.json` 跑前备份、每圈后还原：md5 前后均
  `c322f9a20321c5b618f98db7e4120969`，内容未变。
  测试当次写出的 272.8 s / 9500 已逐字节还原，没有进正式纪录。

### 3.1 回归中发现并修掉的两处测试契约

1. **beam7 事故（每圈 1 次）**：新神游偏移（最多 22+7 px）加滑移把兔子整体后拖，
   旧自动驾驶按乌龟 x 在 `end+24` 松开趴下，兔子带偏移站起，身体左缘刮梁尾 9 px。
   修法（只动测试司机）：趴下结束判据从乌龟 x 改为兔子真实位置
   （`race.rabbit.position.x < end+24`）。重跑两语言各两圈归零。
   **这是新机制的诚实后果，不是物理回归**：玩家若在伙伴偏移时松开趴下也会刮到，
   但可以看见偏移并选择多趴一会儿或先 SHIFT 稳住。
2. **两处旧测试假设**：
   - `stage2_selftest` 的“加速带自动提速 >340”测的是被 Phase O 食物系统替换掉的
     旧机制；改为“带内食物吃下 → 1.15×（253）→ 越过后回落”。
   - `stage4_rescue_boost` 的基速对照靠“切兔子躲开食物”，而 §3 已让食物按乌龟
     真实位置触发；改为清空 `boost_lanes` 真正关闭食物。基速 2.4 s 延迟现在
     也能接住（2.85 s，属 §6 容错变好），断言从“2.4 必须失败”改为
     “0–2.4 全接住；失败边界由 base_none 与 water-rescue 的 1.6/2.0 s 证明”。
   - 修后：`stage2_selftest` PASS、`stage4_rescue_boost` 25/25 PASS、
     `stage4_shift_graybox` PASS、`stage4_bilingual` PASS。

### 3.2 headless 回归批（16 场景）

`stage0/1/2/3_selftest`、`stage4_bilingual`、`stage4_flow`、`stage4_hud_priority`、
`stage4_shift_graybox`、`stage4_gear_ab`、`stage4_level_audit`、`stage4_metrics`、
`rescue_probe`、`rescue_air_probe`、`stage4_rescue_boost`、`stage4_penalty`、
`stage4_surfboard`：修完上述契约后全部 exit=0、0 FAIL、0 SCRIPT ERROR。
（`rescue_probe` / `rescue_air_probe` 按各自脚本约定输出，无 FAIL 行。）

---

## 4. 开场与暂停设计稿（§8）

- `docs/reports/longrun/SHIFT02-INTRO-PAUSE.md`：
  - Intro 6 镜 6.6 s（硬上限 8.0 s），逐镜画面/镜头/占位/音效；
    Enter/Space/Esc 跳过，跳过与自然结束同一入口，8.0 s 超时强制进赛道；
    Intro 期间 `GameState=MENU`，不推进氧气/BRO BRAIN/事故。
  - Pause：兔子撑桌手托脸、乌龟旁休息/啃蛋糕；固定主句
    `Take a breath, bro.` / `喘口气吧，兄弟。`；逐元素呼吸/眨眼/耳朵/啃食循环；
    占位只用原生 Panel/Label 文案，不新增图片/字体/图标。
- 本轮没有制作正式素材，没有实现 Intro/暂停插画，只落地了一个
  `shift_shocked` 事件接口（见 §2.7）。

---

## 5. §10 最终证据对照

| 要求 | 证据 |
|---|---|
| 神游四阶段实际运行 | `stage4-bro-brain.json`；12 s 依次 3.02/6.02/9.00 s 进四段 |
| 两种角色不同神游行为 | 兔子 25.7 px 壳边偏移 + 空中修正；乌龟 0.90× 掉速 + 张望 |
| 切换后状态恢复 | drift 10.0 → 1.0 s 9.0 → 切走 9.5 → 2–7 s 归零；快速 SHIFT 不能白嫖 |
| 控制兔子时食物触发 | 乌龟 x≈3337 吃下，control=rabbit；`snack-eat-rabbit-driving.png` |
| 食物对乌龟的影响 | drift 6.0→0、STABLE；1.15×253、2.02 s、平滑回落 |
| 海鸟四路线前后对比 | `phase-c-windows.shift02-{before,after}.json`；crouch 42/42、dive 59–60/62、jump/leap 0/42 |
| BRO DIVE 多窗口 | Z1/Z2/Z3 0.30/0.35/0.35 s；300 次矩阵；30/60/120 Hz 一致 |
| 实际落水坐标与连续运动 | trigger_dx 0.7/5.3（旧 520）、fall 1.25 s、max_step 12.6、teleports 0 |
| 接人容错与失败原因 | 0–1.2 s 接住；1.6/2.0 s `turtle_too_shallow`；不潜 `too_far_x` |
| 完整赛道回归 | 窗口化中英各两圈 55/55、0 事故、stderr 0、best.json 还原 |
| 开场与暂停设计稿 | `SHIFT02-INTRO-PAUSE.md` |

---

## 6. 已知问题 / 未验证

| 项 | 现状 |
|---|---|
| 真人试玩 | **已试玩**（自述 3–4 次）；2026-11-11 书面意见：跳太高 / 切换压力低 / 下潜万能 / 接住无动作，逐条处置见 `PRODUCER-PLAYTEST-NOTES.md`。本轮新增机制**没有新的真人数据**，正式验收未完成 |
| 神游偏移与低梁尾 | 偏移最大 29 px 时，趴下松手过早会刮梁尾；可看见、可 SHIFT 稳住，是否要加“趴下时禁用偏移”属制作人决策，本轮未改玩法 |
| Z1 开场 0–30 s | 仍然没有必须做的判断；Phase S/T/U 已连续三次指出，本轮未改（不属 SHIFT-02 范围） |
| Z3 复杂障碍 5 s 预警 | 受 1100 px 视野上限限制，仍待制作人决策 |
| 海鸟 dive 的氧气账单 | 1.13–4.02 s；是否偏贵需真人判断 |
| Intro/暂停插画 | 只有设计稿，占位未实现 |

---

## 7. 有趣性自评

**有保留。**

1. 新增操作能否一句话说清：能。SHIFT = 换人；↓ = 乌龟下潜 / 兔子趴低；
   吃掉眼前食物 = 1.15× 加速，但会把下一组障碍换进随机池。
2. “我做了判断然后成功”的瞬间：自动证据里存在明确判断点——
   水花后 0–1.2 s 内切乌龟并下潜才接得住（0.38–1.63 s 接上），
   1.6 s 起兔子已沉到壳顶以下；BRO DIVE 提前松 ↓ 会 turtle_hit，
   保持到 +40/+80 才过；海鸟选 crouch 零成本、选 dive 付氧气、跳/跃必中。
3. 操作错了有可见后果：有。落水 → 兔子真实下坠、水花、乌龟减速找人；
   没接住 → 有限回壳 + 失败原因；提前松手 → 龟撞梁。
4. 比上一阶段多一个想再试的理由：有。伙伴会自己晃、自己贪吃，
   SHIFT 从“换视角”变成“管人”；但**本轮没有新的真人验证这句话**（制作人之前的意见见试玩记录）。

**本轮最无聊的 30 秒**：仍是 Z1 开场 0–30 s（x≈0–6600）。
本轮的神游让待命有东西看，但没有必须做的判断；连续第三轮同一位置。

---

## 8. 阶段与交付

- `docs/STAGE.md`：`STAGE=4`，未进入 STAGE 5，未宣布最终完成。
- 真人试玩：**已进行**（见 `PRODUCER-PLAYTEST-NOTES.md`）；结构化正式验收未完成，
  自动测试不能替代制作人验收。
- 交付给制作人复核；不自动推进。
