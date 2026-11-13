# STAGE 4 — 双语 UI、HUD 修复、受限驾驶与玩法内容审计

`STAGE=4`（未进入阶段 5）。素材冻结继续有效。
详细的逐项审计在 `docs/reports/STAGE-4-GAMEPLAY-AUDIT.md`；本文件只留阶段结论与证据索引。

## 结论一览

| 交付项 | 状态 |
|---|---|
| 简体中文首次启动、可切英文、立即生效、重启保持 | PASS |
| 玩家可见文本统一走 Locale ID，中英文无缺字 | PASS |
| 主菜单/设置/暂停/结算流程完整 | PASS |
| 中文完整流程 / 英文完整流程 | PASS / PASS |
| HUD：控制角色、双方状态、氧气、计时、连击/Showtime、障碍预警、底部提示 | PASS |
| Showtime / 教学提示不再盖住下一障碍预警 | PASS（真机截图 + 回归） |
| 加速带首次进入提示 | PASS（逻辑 + 双语键） |
| 最佳纪录事故数口径与计分一致 | PASS（代码；结算回归） |
| 组间空档（Phase H/J 后重测） | PASS：54 个空档最小 3.85 s、中位 4.44 s、最长 5.55 s；旧的 8.68 s 已作废（`logs/phase-j/phase-j-summary.json`） |
| 自动驾驶审查 A / B / C | A 完成；B 完成（12 轮，工程代理）；C NOT TESTED |
| 数值基线（≥10 项，可复现） | PASS |
| 回归（STAGE0–3 + STAGE4） | PASS |
| best.json 不被测试污染 | PASS（哈希 6af317c2…；round 12 的测试写入已还原，见 §6） |
| 素材零新增 | PASS |
| 有趣性自评 | 有保留 |
| 非对称冲浪板（取消手动控深） | PASS（工程证据；真人手感 NOT TESTED） |
| 五段失衡 / 事故链（兔 + 龟各自独立） | PASS（工程证据；真人手感 NOT TESTED） |
| 障碍空间重映射 + 组合漂浮木 + 高墙（七类，见 `STAGE-4-SPACE.md`） | PASS（工程证据；真人试玩 NOT TESTED，闸门 NOT_VERIFIED） |
| 主菜单原生按钮与鼠标全流程 | PASS（窗口化真实鼠标事件） |

本轮（2026-11-11 核心体验 + 菜单交互）的完整交付说明见
`docs/reports/STAGE-4-DELIVERY.md`；下文 §0/§5 里被本轮改写的数值已就地更新。

障碍空间重映射与龟兔协同（五类障碍、组合漂浮木、55 组重分类、预警时间）见
`docs/reports/STAGE-4-SPACE.md`。那一轮改写了障碍几何与主赛道分类，
真人验收仍未做，交付闸门保持 `NOT_VERIFIED`。

## 2026-11-12 STAGE 4 追加指令：核心操作、连招、事故与评分

一句话：**让跳/趴/潜/跃各自成为至少一类障碍的必需解（鲨鱼只认跃、门只认潜、
浮木只认跳后潜、高墙只认跃后蹬），新增 BRO DIVE / BRO OLLIE 两套双人连招、
三格共享事故槽和新分数表。主流程两圈 55/55、0 事故、9500 分。**
`STAGE=4` 未变；氧气、Showtime、事故演出、双语、赛道系统全部保留。

本节数字优先于本文件前文的旧描述（跳跃参数、障碍类别、SHIFT 灰盒）。

| 追加指令交付项 | 状态 | 证据 |
|---|---|---|
| 55 组×7 方案真实输入审计 | PASS | `stage4-solution-matrix.json`、`logs/solution-audit4-a..d.log` |
| 8 组浮木逐组证伪（只跳/只潜/只跃全失败） | PASS | 同上 `logs_falsification`：8/8 仅 `dive_jump` |
| 兔子跳跃 180–200 px / 1.1–1.2 s | PASS | `logs/stage4-metrics-b.log`：183.8 px / 1.18 s |
| BRO DIVE 原型 + 连续截图 | PASS | `logs/stage4-proto-shots-d.log`、`screenshots/stage4-combo-dive-1..4` |
| BRO OLLIE 原型 + 连续截图 | PASS | 同上、`screenshots/stage4-combo-ollie-1..3` |
| 高墙必须二段动作 | PASS | `by_kind.HIGH_WALL`：仅 `leap_jump` 3/3；`must_ollie=3` |
| BRO METER 三格 + 联合演出 + 重复触发 | PASS | `logs/stage4-bro-meter-b.log`（28 项） |
| 分数表 / 结算行 | PASS | `logs/playtest-stage4-score4.log`：9500 逐笔回放；`screenshots/stage3_result.png` |
| HUD 三格 + 分数 + 连招提示，中英双语 | PASS | `logs/bilingual-stage4-c.log`、组合截图 |
| 主流程回归 + 三类证据标注 | PASS（人工 NOT TESTED） | 见 §10；`logs/playtest-stage4-score4.log` |
| Phase H 三区节奏/空间：Z1 连招顺序、高墙窗口、鲨鱼画法 | PASS（人工 NOT TESTED） | `longrun/PHASE-H-ZONE-SPACE.md`；`logs/phase-h/*` |
| Phase I HUD / 菜单 / 双语：对比度修复、两尺寸×两语言截图、菜单键鼠 | PASS 6 条 + 1 条待真人（`NOT_VERIFIED`） | `longrun/PHASE-I-HUD-INTERACTION.md`；`logs/phase-i/*` |
| Phase J 难度 / 舒适度：容差 ≥0.154 s、反应 ≥3.54 s、恢复 ≥3.85 s、7 类各教一次、无单一万能解 | PASS 6 条 + 1 条待真人（`NOT_VERIFIED`） | `longrun/PHASE-J-DIFFICULTY.md`；`logs/phase-j/*` |
| Phase M ② 惩罚只有一套持续事故机制（复核未被 I/J 破坏） | PASS（自动层）；`stage4_penalty` 37/37、单链 `note_mistake`、`best.json` 未变 | `logs/phase-m/penalty.log`；`logs/phase-m/best.before.json` |
| Phase M ① 下潜不再是只潜就能过的万能解 | PASS（自动层）：下潜 38/55→17/55，岩/梁共 21 组下潜全失败；55/55 仍有解、设计答案全过、窗口逐组不变 | `longrun/PHASE-M-DIVE.md`；`logs/phase-m/*`；`screenshots/phase-m_*_block.png` |
| 有趣性（真人） | pending | QC 第 11 条；没有真人试玩 |

### 1. 55 组解法矩阵（自动代理，2026-11-12 01:10）

每组 7 种真实输入：只跳 / 只趴 / 只潜 / 只跃 / 跳后潜 / 跃后二段跳 / 不操作。
55 组、0 无解。当前通过集合（`by_kind`）：

| kind | 组 | 只跳 | 只趴 | 只潜 | 只跃 | 跳后潜 | 跃后二段 |
|---|---|---|---|---|---|---|---|
| LOW_BIRD | 9 | 9 | 9 | 9 | 9 | 8 | — |
| SURFACE_ROCK | 12 | 12 | — | 12 | 12 | 6 | — |
| LOW_BEAM | 9 | — | 9 | 9 | — | — | — |
| SHARK | 6 | — | — | — | **6** | — | — |
| DIVE_GATE | 8 | — | — | **8** | — | — | — |
| FLOATING_LOG | 8 | — | — | — | — | **8** | — |
| HIGH_WALL | 3 | — | — | — | — | — | **3** |

**下潜不是万能解**：只潜能过 38/55（鸟、岩、梁、门），但 6 组鲨鱼、8 组浮木、
3 组高墙共 17 组必须换别的动作；8 组浮木的 `dive_only_pass` 全为 false。
只潜的代价是必须 SHIFT 给乌龟（失去兔子层控制）且水下消耗氧气。可见的残余偏差：
“从上方障碍下面潜过去”在物理上成立，所以只潜仍覆盖 69%，本轮没有为了压这个数
去加不合理的碰撞体。

### 2. 兔子跳跃（改前 → 改后）

| | 旧 | 新 |
|---|---|---|
| 初速 / 重力 | 560 / 900 | **630 / 1050** |
| 滞空 | 1.23 s | **1.18 s**（理论 1.20） |
| 最高点 | 169.6 px | **183.8 px**（理论 189） |
| 220 px/s 前进 | 271 px | 260 px |

改后全量重跑：55/55 通过、0 接触；所有依赖跳跃的组与 8 组浮木在 audit4 重验。
腾空截图里兔子仍在主游戏区（HUD 以下）。

### 3. BRO DIVE（浮木）

输入链：兔子 `↑` 起跳 → 空中 `SHIFT` 给乌龟 → 玩家按住 `↓` 下潜 → 浮木下沿通过
→ 松开 `↓` → 浮力回浮、兔子落回壳上。`SHIFT` 不取消跳跃。

实测（`stage4-proto-shots-d.log`）：`dive alone` 被下沿挡住（410 > 402），
`jump alone` 被上沿挡住；只有 `dive_jump` 通过。落地 `mount=RIDING`、无事故。
HUD 在通过瞬间发 `BRO DIVE!`（信号断言）。连续图：
`stage4-combo-dive-1-jump`（起跳）/ `-2-under`（兔在上、壳在下）/ `-3-clear`
（BRO DIVE! + SCORE 250）/ `-4-land`。自动跑 8/8 组浮木。

“不是纯动画冒充”：下潜必须玩家按住，未按 `↓` 或只按一下都过不去；物理判定
用龟壳/兔子真实矩形，原型与主赛道同一套 `race.tscn`。

### 4. BRO OLLIE（高墙）

输入链：乌龟 `↑` 跃起 → `SHIFT` 给兔子 → 兔子在跃起窗口再蹬一次 `↑` →
越过高墙墙楣 → 落回壳上。

实测：`wall leap-only` 撞墙（hit=true，兔失衡 3.2）；二段蹬踏后兔身高于墙楣、
壳从门洞 136–240 穿过、落回 `RIDING`。HUD 发 `BRO OLLIE!`。连续图：
`stage4-combo-ollie-1-kick` / `-2-window` / `-3-land`。主赛道 3/3 高墙。

### 5. BRO METER 与“独立失衡”的关系（偏差说明）

可见的共享槽只有 BRO METER 三格：有效失误 +1（一次连续碰撞只记一次），
第三格触发 `BRO_BREAK` 联合演出，演出中壳停住，结束后复位到巡航水深、
槽清零、双人 1.5 s 保护、本局继续；再满三格可第二次触发。

**偏差（已于 2026-11-12 Phase G 消除）**：此前角色内部的 `daze_time` 五段失衡
仍在碰撞时累加，并由 9.5 阈值独立触发 `RABBIT_SLIP` / `TURTLE_REEF`，与三格槽并存。
Phase G 把 `daze_time` 降级为短硬直/姿态/物理恢复，封顶 `DAZE_CAP = 3.6`，
不再触发任何事故；所有有效失误当场记 1 格，第三格播联合事故。
详见 `longrun/PHASE-G-PENALTY.md`，回归 `logs/stage4-penalty-phaseg.log`。

### 6. 分数与结算

| 事件 | 分 |
|---|---|
| 普通干净通过 | +100 |
| 精准跳/趴/潜/跃 | +150 |
| BRO DIVE | +250 |
| BRO OLLIE | +300 |
| 有效失误 | −100 |
| 三格联合事故 | −200 |

同一组只记一笔；连招整段完成才给分，半套不给。等待/拖延不加分（`finalize_run`
只评级，不再按时间重算）。

两圈实测 `SCORE clean=0 precise=44 dive=8 ollie=3 mistake=0 joint=0 -> 9500`，
逐笔按表回放等于总分，且 `pass_entries == 55`。结算页显示
总分 / 干净通过 / 连招 / 失误 / 联合事故 / 评级，中英文均有断言；
`stage3_result.png` 为中文实跑结算。

`best.json` 计分模型升到 `SCORE_MODEL=2`：旧最高分与新表不可比，加载时只丢弃
`best_score`，最佳时间/事故/连胜保留。自动跑写入的测试纪录已还原为
`best_time 296.63 / best_streak 54 / score_model 2 / best_score -1`，不把测试成绩
当玩家纪录。

### 7. HUD

角落小面板：左上 BRO METER 三格、右上 SCORE、底部连招/精准提示
（BRO DIVE! / BRO OLLIE! / CLEAN! / BRO COMBO!）、氧气只在深潜相关时出现。
没有恢复四块大面板。中英文均 PASS（含 HUD 分数、BRO METER 标签、结算四行）。

### 8. 主流程回归与证据分类

- **自动（Godot 场景，headless/窗口化）**：`playtest-stage4-score4.log` 两圈
  55/55、`failures=0`、0 条 SCRIPT ERROR；`stage3-selftest-score5`、
  `stage4-bro-meter-b`、`stage4-proto-shots-d`、`stage4-metrics-b`、
  `bilingual-stage4-c`、`stage4-flow`、`stage4_core_experience`、
  `stage4_hud_priority`、`stage4-shift-graybox-rev2`、
  `stage4-menu-input-rev2-windowed` 均 PASS。
- **代理（脚本探针）**：55 组×7 方案矩阵与下潜/跳跃证伪。
- **人工试玩**：`NOT TESTED`。
- 环境备注：`stage4_menu_input` 在 `--headless` 下没有真实鼠标，鼠标项必然 FAIL，
  窗口化重跑 PASS；`stage4_shift_graybox` 原 `y_shift<1.0` 阈值按旧“匀速下沉”模型，
  当前冲浪板浮力模型下 1/60 s 最多 7 px，已改为“不瞬移回 334 + daze 保留”。
- 报告式场景不作为验收：`stage4_gear_ab` 仍报 `NO CONCLUSION`（旧换挡实验），
  `stage4_experience_rework` 仍是旧规则灰盒，`stage4_surfboard` / `stage4_level_audit`
  只打印实验数/矩阵。

### 9. 已知问题 / 未验证

- 真人试玩 `NOT TESTED`；有趣性 QC 第 11 条保持 pending，不宣布阶段完成。
- 只潜仍能过 38/55 组（物理上合理），下潜不是“必须换人”的最强压力来源；
  真正强制换人的是 17 组鲨鱼/浮木/高墙。
- ~~`daze_time` 与 BRO METER 并存~~ **Phase G 已消除**：daze 封顶 3.6、只做硬直，
  BRO METER 三格是唯一持续惩罚，见 §5 与 `longrun/PHASE-G-PENALTY.md`。
- `stage4_gear_ab` 无可比结论；换挡未接入正式关卡（沿用旧结论 REMOVE）。
- 三条高墙/浮木的自动通过窗口较紧（Z3 260 px/s），真人手感未验证。

### 10. 有趣性自评（本轮）

仍为 **有保留**，结论只覆盖自动代理：新增了两个真正的判断点——
“起跳后什么时候按 ↓ 切乌龟”和“跃起窗口里什么时候再蹬一次”，
错了有碰撞/失衡/扣分的可见后果。最有力的一条自动证据是原型里
`leap-only → hit=true` 与 `dive-only/jump-only → 不过`，说明连招不是自动完成。
但“我做了判断并成功”的瞬间仍来自脚本编排，不是真人；最无聊的 30 秒仍候选
Zone 1 后段（x≈7600–13000）。

## 0. 非对称冲浪板（2026-11-11 制作人指令）

一句话：**兔子站在龟壳上冲浪；乌龟负责前进，兔子负责平衡。乌龟不再接受玩家的上下控深。**

已完成：

- `Tuning.SURFBOARD_PHYSICS = true`。乌龟受控时用自动浮力回到 `NEUTRAL_DEPTH=334`
  （壳体略低于水面），失控时按 90 → 110 → 160 px/s 三段下沉，重新受控自动上浮；
  **本轮已改为 35 → 40 → 55 → 80 px/s 四段（见交付说明 §4）**；
  位置由速度积分，切换瞬间不清零、不瞬移。SHIFT 的 0.5 s 站稳 + 2.5/s 恢复、
  2.5 s 危险冷却、4.0 s 乌龟冷却、1.8 s Showtime 全部未改。
- 障碍/加速带整体下移 34 px（`WORLD_Y_SHIFT`），**x 坐标不变**，连击、密度与
  旧审计可直接比较。
- 教学文案与按键说明去掉“上浮/下潜”：JUMP OVER / CROUCH DOWN / STAY HIGH /
  TAKE THE RABBIT / DON'T JUMP。UP 只跳，DOWN 只趴。
- 旧解法冲突已在 `docs/reports/stage4-surfboard-design.md` 1.3 列表逐条核对：
  切乌龟会**上浮**，所以“跳起后切乌龟下潜躲低岩”作废；低岩/低梁只能跳或趴。

代价模型（平衡的核心，自动驾驶实测）：

```
出墙深度 ≈ 换人时的壳深 + (提前量 − 0.5 s 意识延迟 × 速度) × 沉速
```

兔子握权时乌龟失控、速度掉到约 110 px/s，过一道门（墙 100 + 身位 96 px）要 2.2 s，
壳一路沉约 280 px。**换人点必须按壳深自适应**：壳浅（<420）提前 220 px 换，
壳深（≥420）拖到墙前 60 px 再换。门前还要 ≥700 px 让乌龟整段抬壳。

证据索引：

- 完整赛道（正式关卡，自动驾驶）：`docs/reports/stage4-fullrun-round13.log`
  （round 12 为零事故首跑，代码在“开局水深”“恢复高度”两处小改后重跑见 round 13）。
- 9 个下沉门逐门数据（两场 18 条，全部 `acc=NONE`）：
  `docs/reports/stage4-gates-round13.txt`，由 `python tools/parse_gates.py` 生成。
- 灰盒 A–G 改前/改后对照：`docs/reports/stage4-surfboard.json`。
- 设计结论、状态转移表、接入步骤：`docs/reports/stage4-surfboard-design.md`。

未验证 / 风险（需要制作人裁决或真人试玩）：

- **真人手感仍然是 `NOT TESTED`**。所有“通过”都来自确定性自动驾驶，它不会犯错，
  也不代表好玩。
- 门后净空：自动驾驶靠抢兔子段把壳抬回来；真人能否在 2.2 s 门后同时照顾两边未验证。
- 深壳（> 约 340）能让兔子从岩石下方“漂过去”，属于设计漏洞；堵法（兔子 rect 低于
  水面 20 px 判落水）会改变判定，未擅自实施。

## 1. 本轮修复

1. **HUD 预警优先级**（`scripts/ui/hud.gd`）
   Showtime 横幅占第一行时，下一个障碍预警退到新增的第二行；教学提示改走底部常驻行，不再抢预警位置；切语言时清掉旧提示。
   证据：`stage4-hud-priority.log`（PASS）、`screenshots/stage4_showtime_hudfix.png`。
2. **加速带一次性教学**（`scripts/race.gd` + `locale.gd`）
   第一次进入加速带发 `hint.boost`：「加速带 - 按住 RIGHT 加速；兔子滑落更快」。不改布局，不自动加速。
3. **最佳纪录事故口径**（`scripts/autoload/game_manager.gd`）
   `best_accidents` 改用 `accident_count`，与 GDD 12.4 计分同口径，补上原先漏掉的 `RABBIT_STUN`。
4. **新增 HUD 回归**：`stage4_hud_priority.gd/.tscn`，在真实 `race.tscn` 里断言三个 Label 的实际文本。
5. **SHIFT 恢复规则回到 GDD 6.3**（P0，本轮最高优先级）。夺回控制权不再把 `daze_time` 清零：先 0.5 s 站稳，再按 2.5/s 衰减；切换瞬间的 x/y、滑落位置、下沉速度都保留。快速连按 SHIFT 不能同时清掉双方风险。
   证据：`docs/reports/logs/stage4-shift-graybox-rev2.log`（固定 1/60 步长）——兔子交接 daze 2.900→2.900、滑移 0.163→0.163、位移 0.00 px；乌龟交接 daze 2.900→2.900，y 519.83→518.00（浮力回浮 1.83 px，`_vy` −10→−110，不是瞬移回 334）；10 次 0.1 s 连按后双方 daze 2.900、事故 NONE；受控恢复从 3.3 到 0 用 1.83 s。旧版的 `y_shift<1.0` 是按匀速下沉模型写的，冲浪板物理下一帧最多 7 px。
6. **游戏内文字克制**（`locale.gd` / `hud.gd`）。删除底部常驻操作说明书（`hud.hint`）、暂停页的 F1 判定框与 R 重开提示、主菜单的 F1/H/R；HUD 速度/乌龟/Showtime 行改短；保留“按住 RIGHT 加速；兔子滑落更快”的一次性就地提示。底部行只在 1.2 s 内有内容。
   证据：`stage4_bilingual` / `stage4_hud_priority` 改为断言“空闲时底部行为空”。
7. **B 驾驶器改为物理帧时钟**（`stage4_driver.gd`）。判断时间从渲染帧累加的 `race_time` 改为 `sim_time += delta`：同一份代码两次运行从“事故数 0–7 漂移”变成逐字节一致。另修两处模型缺陷：救援切回兔子后握住 0.9 s（原计划每帧抢回乌龟，救人无效）、Showtime 期间不按“上”（原来会把兔子当起跳扔进水里）。
8. **换挡灰盒实验，结论 REMOVE**（`stage4_gear_ab.gd/.tscn`）。同一段 7300 px 真实关卡对比固定 240 / 策略换挡 / 加 SLOW / 全程 320：全程 320 快 24.5%、事故同为 0、同时状态数最低，三档退化成单档。正式关卡没有接入换挡代码，速度也未改。证据 `stage4-gear-ab.json/.log`。

未改：Showtime 触发规则、赛道布局、物理/判定常量、乌龟基础速度、换挡未接入。

## 2. 双语与流程（沿用并复跑）

- 文本：`scripts/autoload/locale.gd`，稳定 ID → `{zh,en}`；首次启动中文；切换立即生效并写 `user://settings.json`。
- 覆盖菜单、设置、HUD、暂停、结算、事故、Showtime、等级、能力名、区域名、障碍提示、世界标签。
- `stage4_bilingual` 枚举全部文本 ID，含新增 `hint.boost`；PASS。
- `stage4_flow` 中英文各走一遍 菜单→比赛→暂停/恢复→终点→结算→重开/菜单；PASS。
- 截图：`screenshots/stage4_menu_{zh,en}.png`、`stage4_race_*`、`stage4_pause_*`、`stage4_showtime_*`、`stage4_result_*`。

## 3. Zone 1 空档

| 指标 | 调整前 | 调整后 |
|---|---|---|
| 组数 | 11 | 12 |
| 最长真实空档 | 17.77 s | 8.68 s |
| 密度 | 9.68 组/分钟 | 10.56 组/分钟 |
| 尾部空档 | 17.77 s | 8.55 s |

调整：x=12950 补一组 `LOW_BEAM`，在第一条加速带（13200）前形成“下潜 → 是否加速”的选择。
保留：Zone 1 仍是最低密度；x≈7600–13000 仍有四段 8.3–8.7 s 空档，按“有保留”处理，见已知问题。

## 4. 自动驾驶 A / B / C

**A 理想自动驾驶**（`stage3_playtest.gd`）：读全表 `LevelData.groups()`，按精确 start/end 提前 170 px 下潜、end+80 上浮，每 1.2 s 换人，事故时等待恢复，`time_scale=3`。
结果：303.7 / 303.6 s，55/55，S，0 事故、0 卡死。比上一轮（297.1 / 297.7 s）慢约 6 s——SHIFT 恢复不再免费，A 按固定 1.2 s 换人也要为恢复付时间。**只证明关卡可解，不是玩家难度。**

**B 受限驾驶器**（`stage4_driver.gd`）：只看 380–430 px，反应 0.18–0.45 s，输入延迟 0.08–0.25 s，2–18% 选错，无预设路线；三档各 4 轮，固定种子。
结果（救援保持修正后重跑）：12/12 完赛；新手平均 9.75 事故（9–10），普通 2.75（2–4），熟练 0；每轮换人 173–239 次，救援换人 26–43 次；0 次接人尝试。50 起事故 = RABBIT_STUN 27 + TURTLE_REEF 17 + RABBIT_SLIP 5 + OXYGEN_OUT 1；44 起是下潜时机/深度失败，滑落与氧气耗尽各来自“兔子真的会长时间无人控制”和“新手第 4 轮”。
按分钟归一化：新手峰值在 Zone 1（2.25 起/分钟），普通峰值在 Zone 3（0.93），熟练三区 0。**“Zone 3 最难”只对普通档成立；对新手，教学墙 `wall1` 4 轮 4 次是更确定的失败点。**
旧版 12 轮（43 起、普通峰值 Zone 2）因驾驶器“宣布救援后立刻抢回乌龟”被取代，不可复现，不再引用。
这是工程代理，不是人工试玩；细节与位置表见审计报告 D 节。

**C 真实人工试玩**：`NOT TESTED`。唯一的人工反馈仍是阶段 2 的「太难了」，本轮没有拿 A/B 的数据去反驳或确认它。

A/B/阶段 2 的赛道、信息、延迟、控制参数都不同，**不能合并计算“玩家难度”**。

## 5. 数值基线（`stage4-metrics.json` 已按冲浪板模型重跑）

| 项目 | 实测值 |
|---|---|
| 兔子跳跃（2026-11-12 改） | 初速 630、重力 1050，滞空 1.18 s，最高 183.8 px；220 px/s 前进 260 px |
| 兔子滑落 | 五段：稳定 1.5 / 轻微 4.5 / 明显 7.5 / 临界 9.5 s 事故；姿态 lean 0.04→0.42、wobble 1.5→8 px |
| 乌龟基础速度 | Z1 220 / Z2 240 / Z3 260 px/s |
| 乌龟加速 | 220→330，0.27 s；加速带 380 px/s |
| 乌龟深度 | 无手动控深；巡航 334、危险 740；失控 35/40/55/80 px/s 四段，实测翻肚皮 8.47 s（y=741）；姿态 tilt 0.02→0.22 |
| 接人窗口 | dx 120、dy −60~90、吸附 70；220 px/s 下约 1.09 s |
| 氧气 | 8 s 满额，1/s 消耗；出水 3/s 回充；事故后回 5 s；低 5、危 2.5 |
| 障碍反应时间 | 430 px：Z1 1.95 s / Z2 1.79 s / Z3 1.65 s；加速时 1.30 s |
| 事故恢复 | 救援/修理 1.6、闪白 0.15、同源冷却 3.0、乌龟冷却 4.0 s |
| Showtime | 3 连击触发，1.8 s；A 每轮 18 次；B 每轮 11–17 次 |

## 6. 回归与纪录保护

本轮全部用 `Godot_v4.7-stable_win64_console.exe --headless` 重跑；日志在 `docs/reports/`。

| 测试 | 结果 | 关键数据 |
|---|---|---|
| STAGE0 SELFTEST | PASS | — |
| STAGE1 SELFTEST | PASS | 断言已按 GDD 6.3 更新：切换瞬间不清零 + 0.5 s 站稳后恢复 |
| STAGE2 SELFTEST | PASS | — |
| STAGE3 SELFTEST | PASS | 55 组、12/19/24、密度 10.6 < 11.4 < 13.9 |
| STAGE3 完整赛道（round 13） | PASS | 300.0 / 299.9 s，S，55/55，0 事故，`stage4-fullrun-round13.log` |
| STAGE3 过门表（round 13） | PASS | 两场 18 条全 `acc=NONE`，`stage4-gates-round13.txt` |
| STAGE4 BILINGUAL | PASS | 全部文本 ID，含 `hint.boost` |
| STAGE4 FLOW | PASS | 中英文全流程 |
| STAGE4 HUD PRIORITY | PASS | Showtime 时第二行仍显示低杆 |
| STAGE4 DRIVER | PASS | 12/12 完赛；新手 9–10 / 普通 2–4 / 熟练 0 事故，`stage4-driver.json` |
| STAGE4 SHIFT GRAYBOX | PASS | 切换保留位置与计时，10 次连按不清空 |
| STAGE4 GEAR AB | PASS（结论 REMOVE） | 四次运行数值逐字节一致，`stage4-gear-ab.json` |
| STAGE4 LEVEL AUDIT | PASS | 重生成矩阵 totals 不变：55 组、34 下潜 / 21 保持、必须 0/0/0、9 条加速带 |
| STAGE4 METRICS | PASS（冲浪板重跑） | 失控 1 s 沉约 30 px；从 520 浮回巡航 334 用 1.92 s |
| STAGE3 完整赛道（本轮重跑） | PASS | 302.8 / 302.9 s，S，55/55，0 事故，18 条门全 `acc=NONE`，`stage3-run.log` |
| STAGE4 CORE EXPERIENCE | PASS | 兔 9.53 s / 龟 8.47 s 到事故；连按 5 次 6.03→7.43；暗流 34 条 gap 0.00；`logs/stage4_core_experience.log` |
| STAGE4 MENU INPUT | PASS（窗口化） | 三菜单 + 退出确认 + 双按钮结算全鼠标点通；`logs/stage4_menu_input.log` |

`sh tools/run_regressions.sh` 11 个场景全部退出 0；其中 STAGE3 的 1 条 `FAIL` 匹配
是断言文本自身的 “TURTLE ENGINE FAILURE”，不是判定失败（该场景仍打印 `PASS`）。

纪录保护：

- 原始纪录 `{"best_accidents":0,"best_score":12460,"best_streak":54,"best_time":296.63}`。
- 所有会冲线的测试前手动备份 `user://best.json`，结束后原样写回；哈希始终为 `6af317c2…a7ba6`。
- B 驾驶器、flow、bilingual 在脚本内逐字节备份/恢复；A 运行由手动备份/恢复。
- 测试期间的合成成绩（本轮 A 的 12531 分 / 55 连击）未保留为真实纪录；A 跑完后从备份恢复，哈希回到 `6af317c2…a7ba6`。
- 2026-11-11 冲浪板：round 12 的自动驾驶两场曾把 `best_streak` 写成 55
  （哈希 `e8ceecf1…`）。这是**测试写入**、不是玩家成绩，已按原始纪录写回 54，
  哈希回到 `6af317c2…a7ba6`；此后完整赛道测试统一用 `tools/run_fullrun.sh`
  （跑前备份、跑后原样写回）。

## 7. 已知问题（未解决）

- ~~P0 SHIFT 可重置滑落/下沉计时~~ **本轮已修**：受控恢复改为 0.5 s 站稳 + 2.5/s 衰减，交接保留位置与计时；见 §1-5。
- ~~P0 兔子能力非必需~~ **2026-11-12 已由追加指令解决**：55 组中必须趴 18、
  必须跳 12、必须跃 6、必须潜 8、必须组合 8、必须 BRO OLLIE 3
  （“必须”指设计答案，不是唯一通过手段）；只跳/只趴/只潜/只跃都不能单独通关
  全部组（见 2026-11-12 节 §1）。
- **P1 Zone 1 后段**：四段 8.3–8.7 s 空档，无决策时间占 56.7%。
- **P1 Zone 3**：10 组块 ×2，三元组仅 8 种；比 Zone 2 更可预测。
- **P1 氧气**：不构成路线决策；Showtime 每次回满。
- **P1 Showtime 频率**：每约 16–18 s 一次；本轮只修了预警可见性，未改触发规则。
- 设置页只有语言项；音量/画面不在本阶段范围。
- **P1 深壳可从岩石下漂过**：壳深 > 约 340 时，兔子 rect 低于水面岩石底部，
  乌龟层失误反而让兔子“免撞”。这是非对称模型带出的设计漏洞，是否堵
  （兔子 rect 低于水面 20 px 判落水）需要制作人决定。

## 8. 有趣性自评

**结论：有保留。**

1. **新增操作能否一句话说清用途？** 能。HUD 写明当前控制谁、另一方状态、氧气、下一障碍与动作。
2. **有没有“我做了判断，然后成功了”的瞬间？** A 日志可见（换回乌龟后恢复巡航、连击 +1）；B 里表现为“提前下潜 → 熟练档零事故；新手在同一个 wall1 连续失败”。仍是脚本判断链，不是人工手感。
3. **操作错了有没有可见后果？** 有。事故大字、硬直、滑落条、乌龟三段下沉、氧气三档；中英文截图可见。
4. **比上一阶段多了一个想再试一次的理由吗？** 不明显。本阶段是可读性、护栏与审计，不是新玩法；复玩动机仍来自 Showtime 与纪录。

**最无聊的 30 秒**：Zone 1 后半段 x≈7600–13000（A 实跑 t≈36–66 s）。30 秒里只有三组障碍，组间 8.3–8.7 s。

非对称冲浪板对“有趣性”的影响（仍以自动驾驶为证据，**不是**真人结论）：

- 新增了一个真正的判断点：下沉门里必须**提前按壳深决定何时把控制交回兔子**。
  交早了（提前 220 px）门 4 出墙 733 判暗礁；交晚了（提前 130 px）门 2 入墙 349 撞墙。
  这个判断错了有可见后果，且不是按键快慢能救的（换人后 0.5 s 才恢复）。
- 代价是门前后各要 700 px 净空，自动驾驶靠“抢兔子段”补齐；真人能不能同时
  照顾两边的计时，未验证，所以不把这条算作“更有趣”。

连续两个阶段同一处无聊必须先改；下一阶段若仍保留该段，需要动赛道内容。

**Phase M 追加自评（2026-11-12，自动证据；真人仍 NOT TESTED）**：

- 岩/梁有了水下段以后，“遇事就下潜”不再成立：下潜只能解决 8 个礁门和 9 只鸟，
  岩必须跳、梁必须趴。玩家第一次在梁前下潜会撞到下横梁，后果可见（BONK + BRO METER）。
- 这带来一个新的判断点：同一类“贴水障碍”里，鸟可以潜、梁不能潜——两者的区别
  必须从画面上看得出来（鸟只在水面上，梁有下横梁）。截图已确认可辨，但真人是否
  一眼分得清，未验证。
- 代价：`leap` 仍是覆盖率最高的单方案（27/55）。它是有时机的动作，不是按住不放，
  所以本轮不再压缩。结论仍为 **有保留**。

## 9. 下一阶段

保持 `STAGE=4`，未进入阶段 5。

1. ~~请制作人裁决 SHIFT 失控计时~~ 本轮已按制作人指令恢复 GDD 6.3 并留灰盒证据；换挡假设已由灰盒判 REMOVE。
2. 设计一关“必须跳 + 接人”的验证关，先验证一种新组合。
3. Zone 1 后段改成“保留一段呼吸空间 + 其余用可选加速带/复习组”，改完重跑矩阵、A、B。
4. 人工试玩仍等制作人启动；`PRODUCER_PLAYTEST_CANDIDATE` 当前不满足（见审计报告 H.4）。
