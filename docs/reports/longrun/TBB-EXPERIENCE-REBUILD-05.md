# TBB-EXPERIENCE-REBUILD-05 — 交付报告

日期：2026-11-13（02:19 开始，04:2x 首版；07:00–08:56 续做 G18–G21 后定稿；
11:56–12:2x 按制作人要求续做 G22 收尾优化）
范围：任务书 A–H；**STAGE 保持 4**，未进入 STAGE 5。
细分报告：`REBUILD05-B3.md`（BRO DIVE）、`REBUILD05-C.md`（引导条）、
`REBUILD05-D.md`（SHIFT 正向）、`REBUILD05-E1.md`（海鸟）、`REBUILD05-E2.md`（动态原型）、
`REBUILD05-E3.md`（三区节奏）、`REBUILD05-F.md`（GDD 复核）、`REBUILD05-G.md`（G 段优化）、
`REBUILD05-G2.md`（松手提示）、`REBUILD05-G3.md`（擦水原因提示）、`REBUILD05-G4.md`（成功弹跳）、
`REBUILD05-G5.md`（接人/救回弹跳）、`REBUILD05-G6.md`（动态障碍首次提示）、
`REBUILD05-G7.md`（「好接！」只给真接住）、`REBUILD05-G8.md`（接人提示环可见）、
`REBUILD05-G9.md`–`REBUILD05-G17.md`（壳下沉/教学顺序/取证/暂停面板/结算页「亲手喂到」/
「下次试试」等，见各篇）、`REBUILD05-G18.md`（救援探针）、`REBUILD05-G19.md`（撞错角色时换人提示）、
`REBUILD05-G20.md`（20 个探针补清 `hit_roles`）、`REBUILD05-G21.md`（撞过的类型下一组再教）、
`REBUILD05-G22.md`（补教封顶 + log5 浪涌 + 运动时钟归零）。

## 一句话结论

修掉两处会让玩家“做对了却被判错”的判定 BUG，把 BRO DIVE 的问题从“窗口太窄”
改判为“松手时机不可读”，并把 SHIFT 从“换个人”变成有三种可测收益的选择；
动态障碍从 0 组扩到 14/55。教学也补了三处缺口：撞错角色时第一次说“按 SHIFT 换兔子”
（G19），撞过的障碍类型下一组再教一次（G21），补教每类最多一次（G22）。
**两圈全流程自动驾驶全绿、0 事故，
但这不是“好玩”的证明**——本轮没有任何真人试玩数据（见 §12）。

## 1. 修了的 BUG 与原因（H1）

| # | 症状 | 原因 | 改法 |
|---|---|---|---|
| B1 | 兔子落水后接应成功，事故仍被记一次 | 接应成功事件与事故收尾共用一条路径，事故状态在成功帧之前就已记账，且没有“撤销”入口 | `_trigger_accident` 改为返回“是否真的记账”；接应成功把 3 s 冷压回 1.2 s，成功与失败在账本上分开 |
| B2 | 控兔子撞障碍时，同时撞上的乌龟不记、只被浪冲开 | 碰撞判定按“当前控制者”一条线走，非受控角色只有景深冲开，没有独立判定 | `_check_hazards()` 按角色分别记账（`hit_roles`）；接应期间乌龟照常判障碍；同一次事故不重复叠加；不同障碍不合并 |
| F | 首次教学会“教错人”：已控乌龟时提示“SHIFT + ↓”，照着按反而切走控制权 | `_update_lessons()` 6 个分支直接取固定文案，没读 `current_control` | 新增 `_lesson_prompt(kind)`，按控制者取词；新增 6 条中英文案（`REBUILD05-F.md` §1） |
| A2 | SHIFT 电流音效仍在播 | —（上一阶段遗留开关） | `shift_fx.gd` `SFX_ENABLED := false`：连 `AudioStreamPlayer` 都不创建，音频帧增量恒为 0；视觉电弧/闪光保留 |

B3 不是 BUG：标准时机下三组浮木各 7/7 干净通过，窗口 178/180（0.99）。
真问题在“松手时机不可读”——一直按住 ↓ 会擦水白记一次事故，画面只有水花差别。
本轮没有放宽窗口（放宽会让“一直按住”更安全，抹掉唯一技巧点），
把这条输入交给 C（引导条）和 D（下潜是有终点的动作）。

## 2. 双角色碰撞 / 联合判罚规则与回归证据（H2）

规则现状（`race.gd` `_check_hazards()`）：

| 障碍 | 判谁 | 特例 |
|---|---|---|
| SURFACE_ROCK | 兔子（乌龟在壳下） | `JUMPING` 且上升帧不比（起跳帧豁免） |
| SHARK / DIVE_GATE | 只判乌龟 | 兔子在壳上视为安全 |
| LOW_BEAM / LOW_BIRD | 只判兔子 | `CROUCHING` 时不判 |
| FLOATING_LOG / HIGH_WALL | 两人都判 | 连招成功则整组免判 |

回归：`stage5_b_probe`（`rebuild05-b-probe.json`）5 个场景 + 2 个 B1 场景全 PASS：
单兔撞、单龟撞、双撞、先后撞同一障碍、浪涌干扰；接应成功后事故结束、接应过程真实碰撞仍生效、
不抹掉接应前独立事故、一次事故只记一笔。
`stage3_selftest`、`stage4_core_experience` 在本轮回归中仍 PASS（§10）。

## 3. BRO DIVE 三组窗口与成功证据（H3）

组：log1（Z1 x=6400）、log3（Z2 x=30550）、log8（Z3 x=64560）。

| 组 | 标准时机 7 次 | 兔子最小余量 | 乌龟最小余量 | 5×60 Hz 一致 | 30/120 Hz |
|---|---|---|---|---|---|
| log1 | 7/7 | 74.0 px | 44.6 px | 是 | PASS / PASS |
| log3 | 7/7 | 75.8 px | 43.7 px | 是 | PASS / PASS |
| log8 | 7/7 | 75.8 px | 42.8 px | 是 | PASS / PASS |

有效窗口（每组 180 例，178 通过）：起跳提前量 80–300 px、SHIFT 延迟 0–0.6 s、
松手位置（越过右缘）−80–+180 px。两类失败（起跳太早 / 切人太晚）都可从操作解释。
证据：`rebuild05-b3-repeat.json`、`playful04-bro-dive-audit.json`。

## 4. 接应完整空间轨迹与无瞬移证据（H4）

`RABBIT_WATER` 不再把兔子放到 `turtle.x+520`。`RESCUE_FALLING` 保留离壳时的世界坐标与速度，
按 1050 重力下落（终端 950），穿水线 340 才起水花并进 `RESCUE_ACTIVE`。

- 事故当帧兔子相对乌龟 0.7 / 5.3 px（旧值 520）；
- 下落 1.25 s，最大单帧位移 12.6 px，`teleports = 0/14`；
- 水花与穿水前一帧差 7.5 px，`splash_matches_entry` 14/14；
- 接人：有效区 140 px / dy[−95,+40]，先过 `RESCUE_CLOSING_MIN=-60`；
  吸附只在外圈 165 / dy[−105,+50]，160 px/s（巡航高度不触发，必须真下潜）；
- 下潜延迟 0–1.2 s 全部 caught（0.38–1.63 s），1.6/2.0 s 与完全不切控制 missed，
  原因 `turtle_too_shallow`。

证据：`shift02-water-rescue.json`（`PHASE-SHIFT-CORE.md` §2.5–2.6）。

## 5. 引导条正式运行截图（H5）

长在左上角既有状态区里，不新建面板：兔子行/乌龟行（受控/待命/落水·等接应）、
协作机会行（`BRO DIVE 准备/现在！/已错过`，高墙在乌龟行 `BRO OLLIE`）、一根时机条（灰蓝/金/浅红）。

截图：`screenshots/rebuild05-coop_coop_prepare.png`、`..._now.png`、`..._missed.png`
（`--capture-coop` 在正式 `race.tscn` 里截）。
探针 `stage5_c_hud`：600 px 不出现、500 准备、300/200/80 现在、60 已错过；
通过后立刻消失；双向控制与落水行正确；中英文不溢出；提示可见时面板 ≤ 8%。

## 6. 三种动态障碍行为与接入情况（H6）

| 原型 | 样板 | 参数 | 运动规律 |
|---|---|---|---|
| 周期运动 | rock3（Z1 x=3900）、rock10、rock4、rock7、rock11、rock12 | y ±52 px / 3.6 s | 正弦上下，考通过时机 |
| 扫掠 | shark3 / shark5 / shark6 | x ±30 px / 4.5 s | 水平巡游，危险区随时间横移 |
| 环境变化 | log6 / log2 / log5（G22） | y −18 ± 22 px / 5.0 s | 浪涌，安全空间在变 |

接入：`level_data.gd` 的 `motion` 字段 + `race.hazard_offset()` / `hazard_rect_live()`，
画与判同源。**14/55 组有运动**（Z1 1/12、Z2 6/19、Z3 7/24），全部不是食物锚点。
E2 探针十四组：振幅/周期/轴/偏移跟随全对表，岩 7 组 × 8 相位、鲨 3 组 × 8 相位、
浮木 3 组 × 5 相位 = 0 命中，`E2 MOTION: PASS`。
G22 给 Z3 第一处浮木（log5）加了同规格浪涌（相位错开 0.35），两处“浮木/鸟”
不再是同一张静态图；实测振幅 21.9、范围 −39.9…+3.9、上沿跨度 41.1 px。

## 7. SHIFT 正向体验变化（H7）

| 动机 | 动作 | 得到 | 读数 |
|---|---|---|---|
| 障碍协作 | 兔跳 → SHIFT → 龟↓ | `BRO DIVE！` +250（高墙 `BRO OLLIE！` +300） | 既有连招 |
| 食物 | SHIFT 到乌龟亲手喂 | `TURBO！` +30，加速与不切同值（253.0） | `score_delta=+0`（不切） |
| 救援 | 落水 → SHIFT → 追接 | 回壳 `兄弟回来了！` +50，两人神游清零 | `drift_after=0.0/0.0` |

只加不减：不亲手喂只少 30 分、不追接没有新增罚项。

**G2（B3 结论的落地）**：BRO DIVE 的第二步“松开 ↓”以前没有任何提示。
现在兔子还在空中、壳仍在浮木右侧下潜时，正式 HUD 的乌龟行出现金色
`松开 ↓ 上浮接人！`；松手即消失。探针（`rebuild05-g2-release.json`）：
跟提示松手 0 事故，一直按住仍记 1 次（提示让代价可读，不消灭代价）；
礁拱下潜与接应下潜不出现（各 120 帧 0 次）；中英文都放得下，面板总面积 6.0%。
配套把 `lesson.log` 的第三步补上（“越过木尾松开 ↓ 上浮接人”）。
带这条提示的两圈回归仍是 272.9/272.8 s、55/55、0 事故；QC `tbb-exp05-g2` 5/5 pass。
神游沿用四态，两只各 12 s 无人控制 0 事故、BRO METER 0 格。
保留一处有意例外：兔子 MISCHIEF 靠近低梁/海鸟会探头擦梁 3 px（上一阶段定稿的“疏忽有代价”）。

**G3（同一技巧点的后半句）**：玩家没跟上 G2 的提示、照样按住 ↓ 时，
事故文案原来只有“兔子落水”，和跳早了共用一句。现在同一条落壳判定在
`turtle.diving` 为真时多发一句 `壳停得太深 - 越过木尾就该松开 ↓ 上浮接人`
（走底部提示行，2.2 s，中英）。探针（`rebuild05-g3-hint.json`）三组：
擦水（越过木尾 90.3 px）有提示并进正式 HUD；非下潜落水、被撞下水两条快路径
0 次；三组事故数都是 1，判定与扣分未改。两圈回归仍 272.9/272.8 s、55/55、
0 事故；QC `tbb-exp05-g3` 5/5 pass。

**G4（成功端的角色反应）**：连招成功以前只有环、文字和分数，角色本体不动。
现在 `_trigger_action_fx()` 起一个 0.34 s 的计时器，`_draw_rabbit()` 加 12 px
的弹跳画法偏移；`rabbit.position` 不动。探针（`rebuild05-g4-cheer.json`）：
BRO DIVE 与 BRO OLLIE 各 12.0 px、19 帧非零、第 21 帧归零；普通跳跃与礁拱
干净下潜 0 px；重新成功会重新计时。两圈回归仍 272.9/272.8 s、55/55、0 事故；
QC `tbb-exp05-g4` 5/5 pass。

**G5（接人与救回也弹一下）**：盘成功端时发现吃海藻已有食物飞进嘴的表演（不重复加），
但接住和救回落水兔子只有横幅和分数。现在 `_apply_carry_result` 的 pickup / rescue
两条成功分支各起一次同一套 0.34 s 弹跳（抬升结束、真正算成功的那一帧，落水被抓回
的当帧兔子还在水里，不动）。探针（`rebuild05-g5-carry.json`）走真实 `_begin_carry`：
抬升 25 帧后触发，两类各 12.0 px、19 帧非零、第 21 帧归零，`pickup_count`/`rescue_count`
各 +1；普通跳跃（含真正落回壳上）、礁拱干净下潜、没接住的 `rescue_return` 全 0
（第一版漏了日常落壳也走 pickup 记账，会让每次跳跃都弹一下；已改为落壳路径不庆祝，
对照延长到整段滞空 150 帧）。两圈回归仍
272.9/272.8 s、55/55、0 事故；QC `tbb-exp05-g5` 5/5 pass。

**G6（会动的障碍第一次露面时说一句）**：13 组动态此前没有任何教学，第一组会动的
岩在 Z1 上下起伏，玩家只会以为判定飘了。现在每区第一组带 `motion` 的障碍进入
560 px 时底栏报一句 `这组会动 - 看准空隙再上`（英 `THIS ONE MOVES - GO THROUGH THE GAP`），
同区不再重复，事故期间让位。探针（`rebuild05-g6-motion.json`）：Z1 rock3 在 556.3 px、
Z2 rock4 在 560.0 px 各 1 次；Z2 一程连跑 rock4→shark3 仍只有 1 次；静态组 0 次；
事故中 0、解除后补 1；正式 HUD 可见、中英都放得下。两圈回归仍 272.9/272.8 s、
55/55、0 事故；QC `tbb-exp05-g6` 5/5 pass。

**G7（「好接！」只给真正的接住）**：修 G5 时发现同一个根因：普通跳跃落回壳上也走
`_apply_carry_result("pickup")`，于是每跳一次都会喊 2 s「好接！」——把真正稀有的
接住稀释成背景噪音。现在只有真实接住才发 `pickup_success` 与庆祝弹跳，日常落壳
保留水花与 `pickup_count` 计数（统计语义不变）。探针（`rebuild05-g7-banner.json`）：
普通跳跃（整段滞空 + 落地）横幅为空、0 次信号、count +1；离壳 200 px 的真实接住
「好接！」1 次；救回「获救」1 次。两圈回归仍 272.9/272.8 s、55/55、0 事故；
QC `tbb-exp05-g7` 5/5 pass。

**G8（接人提示环看得见）**：批量回归跑出 `stage1_selftest` 一直红着的那一条——
PLAYFUL-04 的落壳分支把 `pickup_window` 在设置它的同一帧清掉，绿色提示环与
「接住了！」实际只存在 16 ms，等于从来没露过面。现在把“显示”和“收人”拆开：
落壳走廊从 -150 px 起亮环（约 0.3 s 提前量），收人判定与当帧吸附、深接抬升一行没动；
文字仍在进吸附区（-60）后出现。探针（`rebuild05-g8-corridor.json`）：普通跳跃窗口
连续 14 帧、上升段 0 帧；壳下潜未上浮时 0 帧且仍记 RABBIT_WATER；深接抬升 11 帧
不瞬移。`stage1_selftest` 恢复 exit 0。两圈回归见 §10；
QC `tbb-exp05-g8` 见 `REBUILD05-G8.md`。

**G9（壳终于有重量反应）**：制作人 2026-11-11 原话第 4 条一直标着“未解决”——
“兔子起跳乌龟接住，但是乌龟只是切换过来了，并没有做什么动作”。G5/G7/G8 补的是
兔子弹跳、横幅和提示环，壳本身从来没为“有人落在背上”动过。现在日常落壳 / 真接住 /
救回分别给壳 7 / 11 / 14 px 的下沉脉冲，0.26 s 内“下沉 → 小幅回弹 → 归零”，
只加在 `_draw_turtle` 的画法偏移上（位置与判定框不动）。探针
（`rebuild05-g9-shell-dip.json`，20 条断言 PASS）：落壳帧 7.0 px、第 16 帧归零、
回弹在第 6 帧出现；真接住 11.0 px、救回 14.0 px；干净下潜与纯巡航 0；
只改画法在区基速置 0 的对照里位置/判定框逐字未变。截图
`screenshots/rebuild05-g9-shell-dip.png` 与对照帧实测壳下移 6 px。
QC `tbb-exp05-g9` 见 `REBUILD05-G9.md`。

**G10（首次教学先来后到）**：看正式场景截图时发现，第一次 BRO DIVE 逼近 log1 时，
下一组 shark1 也在 1100 px 教学范围内，旧循环让“后发的更远类型”盖掉先发的，
底栏显示 `SHIFT + ↑ 乌龟跃起`，和左上 `BRO DIVE 现在！` 方向相反。
现在一帧只发最近的一组，且最近的障碍组尾 +80 px 之前不发更远的新类型。
探针（`rebuild05-g10-lesson-order.json`，正式场景 5 px 步进扫描）：
5300→6500 段鲨鱼教学 0 次、组合教学仍在 1080 px 提前量发出；越过 log1 后
鲨鱼教学只发一次（6515，距鲨鱼 735 px）；旧循环在 x=6150 重放仍会发——探针对
修复前后可区分；全赛道七类各教一次。QC `tbb-exp05-g10` 见 `REBUILD05-G10.md`。

**G11（Showtime 截图取证修复）**：复查 Showtime 截图时发现 `--capture-showtime`
截的是「咚！兔子被撞晕」——工具把乌龟传送到 x=5100，正好是 rock2 的正中间，
0.2 s 内撞上，`start_showtime()` 因事故被拒。改成先关判定、传送点移到 5300
（rock2 组尾之后），连续两次独立运行都拍到金色 `SHOWTIME！` + 兔子离壳 720°。
玩法一行没改：探针（`rebuild05-g11-showtime.json`）断言事故状态下启动仍被拒
（`refused_in_accident=true`）、修后条件能开、0.45 s 时离壳 51.4 px、期间无事故。
QC `tbb-exp05-g11` 见 `REBUILD05-G11.md`。

**G12（暂停界面补操作对照）**：查暂停截图时发现，玩家唯一能停下来“我该按哪个键”
的界面只有 `ESC 继续 R 重开 M 主菜单`——SHIFT / ↑ / ↓ 各自做什么一个字没有；
开局那 6 s 的说明忘了就没处查。`locale.gd` 里其实早有一条双语的 `menu.hint`
（逐角色分工），但全项目没有界面引用它。现在在按钮和快捷键行之间挂上这一行，
1280×720 中英文各拍一张确认不裁切；`stage4_opening_pause` 窗口化 7/7 PASS
（原有标题 / 呼吸语 / 三按钮 / 继续恢复都在）。只改 `pause_menu.gd` 一个文件，
没加字符串、没加素材。QC `tbb-exp05-g12` 见 `REBUILD05-G12.md`。

**G13（事故截图真的拍到事故）**：把剩下的反馈面挨个拍了一遍，发现 `--capture-accident`
截出来的是“鸟在飞、没有事故”——P1-4 把 bird1 挪到 1560 后，工具还停在
“传送到 1290 等 0.4 s”，这段只走 88 px，根本到不了鸟。改成传送到鸟前 160 px、
**等到 `accident_state` 真的变化**再拍（3 s 兜底）。修后两张独立运行都拍到
`咚！兔子被撞晕` + BRO METER 1/3。QC `tbb-exp05-g13` 见 `REBUILD05-G13.md`。

**G14（截图工具不再覆盖历史证据）**：G13 扫描时我拿 `--capture-boost` 拍临时图，
它不认文件名（写死 `stage2_boost.png`），把 2026-11-10 Phase 2 的证据图覆盖了。
改成和其他钩子一样认 `-- --capture-boost <文件名>`；原图从 `.godot/imported/*.ctex`
（lossless）恢复，md5 与 `.ctex` 里记录的 `source_md5` 一致——是同一个文件，不是“差不多”。
QC `tbb-exp05-g14` 见 `REBUILD05-G14.md`。

**G15（窗口化 HUD 回归的过期断言）**：`stage4_hud_score` 需要真实窗口，不在 21 场景
批量里，上次跑是 Phase T。补跑发现 43/44：它等 `rescue_success_count` 变了才读 HUD，
可救援早就变成两拍——抓到时 `接住了！兄弟！`、抬回壳上才 `兄弟回来了！`，HUD 后写覆盖
前写，读到的永远是第二拍，断言还写死中文。改成同时断言两拍（接住发过 + HUD 最后是重聚），
`PASS checks=44`、exit 0，产品代码 md5 未变。**以后每轮收尾要单独补跑
`stage4_hud_score` 与 `stage4_menu_input`。**

**G16（结算页记住「亲手喂到」）**：亲手喂到是“我在照顾搭档”的动作（HUD 闪
`TURBO！亲手喂到！`、+40 分），但结算页完全不留痕，玩家看不到这条路径被认可。
加 `GameManager.snack_switch_count`（只在操控乌龟吃到 +1），结算页「救援成功」下
多一行「亲手喂到」/ `HAND-FED SNACKS`。计分与文案分人逻辑一行没动。证据：
`stage4_snack_rush` 三例 fed_count 1/0/1 全 PASS；真实窗口化通关结算页读数
`272.89 / 55 / 11 / 救援 0 / 亲手喂到 9 / 失误 0 / 联合 0`，与同局 `snack=9` 对得上。
QC `tbb-exp05-g16` 见 `REBUILD05-G16.md`。

**G17（结算页「下次试试」）**：结算页只有七行数字，从没打出过连招的新手看不出
自己漏了什么。加 `GameManager.next_try_key()` 纯函数：没连招 → 提示 BRO DIVE；
有连招没亲手喂到 → 提示换乌龟喂海藻；都做到但有事故没救回 → 提示 SHIFT 追接；
都做到就不显示这一行。只读计数、不加奖励、不改难度。探针
`stage5_g17_trynext` 7 条断言 PASS（含刷新前后状态逐项相等、只有一个 `TryNext` label）；
中英文 1280×720 截图都看过不压按钮。QC `tbb-exp05-g17` 见 `REBUILD05-G17.md`。

**G18（救援窗口探针的两个洞）**：`stage4_rescue_boost` 的 23/25 例 `crash=no_hit`
不是产品改了手感，是探针 `_reset()` 漏清 `hit_roles`——B2 起碰撞按“角色×障碍组”
记账，同组第二次撞时角色已被标记，整组静默免疫；修前 beam1 只有 `boost_none`、
beam8 只有 `z3_none` 真撞上。第二处：`_evaluate()` 的 8 条汇总判定从不进退出码，
`base_matches_phase_f` 红着也照样 `quit(0)`（与 G15 同一类“静默绿”）。两处都只改
测试文件、产品代码 0 行；修后 25/25 `crash=RABBIT_WATER`、8/8 checks、`red=0`，
两圈 `fullrun-g18.log` 与 g17 关键行 diff 为空。另记一笔：另有 20 个探针同样只清
`hit_groups` 不清 `hit_roles`，建议单独一轮清扫（名单与理由见 `REBUILD05-G18.md`）。

**G19（撞上“只有兔子能躲”的障碍时，第一次告诉你换人）**：低梁 / 海鸟 / 岩檐
只在兔子那一层判定，玩家在操控乌龟时撞上，画面就是“我什么都没按就撞了”——乌龟的
↓ 是下潜，不是趴低，当时根本没有可用躲法。G3 已为“壳停太深”补过一句原因，A 类
这一侧一直只有结果没有原因。这一轮做两件小事、都不改判定：`race.gd` 在
`_rabbit_contact()` 里，若 A 类且控制在乌龟且本局没说过，底栏发一次
`按 SHIFT 换兔子 - 这个只有兔子能躲`（`_wrong_role_hinted`，重开新场景自然归零，
另在 `_arm_rescue_proto()` 显式清零）；8 条首次教学文案中英全部点名 SHIFT
（以前只说“兔子按 ↓”，没说怎么变成兔子）。探针 `stage5_g19_wrongrole` 9/9：
同一组障碍、同一物理，兔子操控不提示、乌龟操控提示且文本与 locale 逐字一致、
再撞不重复；中英 1280×720 正式 HUD 截图各一张，提示行一行放下、救援提示另起一行。
两圈 `fullrun-g19.log` 与 g18 关键行 diff 为空，23 场景批量全绿。
QC `tbb-exp05-g19-wrongrole` 6/6，见 `REBUILD05-G19.md`。

**G20（探针不再在“免疫赛道”上测）**：G18 发现探针 `_reset()` 只清 `hit_groups`
不清 `hit_roles`，同组第二次起整组免疫。把 G18 记下的 20 个探针全补上（25 处，
只改测试文件）。重跑暴露的数据变化说明此前不少“绿”是假的：`stage4_bird_routes`
的 jump/leap 从“41/42、42/42 通过”变成 0/42（低飞海鸟只压兔子层，跳/跃起本该撞，
只有趴低能过；E1 文档已加勘误）；`joint_verdict` 8 条断言写于 B2 之前，按
`stage5_b_probe` s3 的“各记一笔”口径改写后 PASS；`snack_zones` 起点蹭到上一组
巡逻鲨的扫掠边、且 `hazard_clock` 在行间漂移，补起点余量与每行归零后 18/18 连跑两次一致。
两圈 `fullrun-g20.log` 与 g19 关键行 diff 为空，23 场景批量全绿，QC `g20` 6/6。

**G21（撞过的类型，下一组再教一次）**：首次教学一局每类只发一次。第一组海鸟没躲过，
后面三组同类型再没人提醒——玩家知道“这里有东西”，但不知道“该怎么办”。
`_check_hazards()` 里一次碰撞**真的记了账**（`applied`）时把该类型从 `lesson_seen`
拿掉，下一组同类型进入提示范围时会按同一 locale 文案再说一遍；干净通过不清
（看懂的人不被打扰），冷却/事故期被挡下的碰撞也不算（没吃亏就不补课），其他类型不受影响。
另加一条：`_update_lessons()` 跳过已经撞过的组——乌龟碰撞不产生事故状态，
不挡的话会在刚撞上的那一组原地复读，下一组反而没补教。
探针 `stage5_g21_relesson` 五组：撞完补教文本逐字一致且同组不连教；趴低干净通过后
bird4 前 0 条提示；预置冷却撞上不重新武装；DIVE_GATE 仍只教一次；乌龟撞完不在原地
复读、补教落在 shark5 前。两处改动各做了反向对照（把那两行分别换成 `pass`），
分别只有 A 组四条、E 组三条断言变红，证明探针不是恒真。窗口化截图
`screenshots/rebuild05-g21-relesson.png`：补教 `↓ 趴低` 与区域提示各占一行、
不重叠。两圈 `fullrun-g21.log` 与 g20 关键行 diff 为空，24 场景批量全绿，
QC `g21` 6/6，见 `REBUILD05-G21.md`。

**G22（补教封顶 + 又一组会沉的浮木 + 运动时钟归零）**：G21 的补教没有上限，
同一类型连撞三组会把同一句话说到第三遍。上限加在记账分支：首次教学之后只允许
一次补教，之后不再重新武装；探针新增 F 用例（撞 beam3 → beam4 补教 → 再撞 beam4 →
beam5 前无第三条提示、`lesson_seen` 仍保留），去掉上限后恰好 F6/F7 变红。
另有两条收尾：Z3 的 log5 浮木改成和 log6/log2 同规格的浪涌（动态 13/55→14/55，
E2 扩到 14 组、5 相位 0 命中）；多行探针的相位漂移收口到 `load_level()`
（装载关卡时 `hazard_clock = 0.0`，正式赛局行为不变，探针每例同相位起跑）。
见 `REBUILD05-G22.md`，QC `g22` 见下。

## 8. 三区节奏复核（H8）

| | Sunny Coast | Coral Chaos | Muscle Mayhem |
|---|---|---|---|
| 基速 / 时长 | 220 / 68.2 s | 240 / 100.0 s | 260 / 110.0 s |
| 组数·密度 | 12 · 10.6/min | 19 · 11.4/min | 24 · 13.1/min |
| 动态（G22 后） | 1/12 | 6/19 | 7/24 |
| 最长空跑（start→start） | 5.91 s | 5.63 s | 5.92 s |
| 最长连段 | 4 | 6 | 6 |

E3 把 Z1 两处 6.36/6.00 s 空跑压到 5.91/5.73 s；G 段把动态 5→13 组、
G22 再加一组到 14 组，Z2/Z3 每约三组有一组会动。已知取舍：Z3 仍有两对两连
各出现 4 次（G22 只让第一处浮木会沉浮，顺序没动）。
密度/间距在 G22 后重跑 `stage4_metrics`：Z1/Z2/Z3 10.6/11.4/13.1 组每分、
单角色最小 3.65 s、组合前 5.13 s，与加动态前一致（运动不改变位置）。

## 9. GDD 自评与仍不够好玩之处（H9）

读完 GDD 全文后的 10 问（`REBUILD05-F.md` §2，逐问带依据）。摘要：
理解关系、躲避直观、熟练提升、三区差异、目标感 → **够**；
何时值得 SHIFT → **够但有门槛**（44/55 组不切也能过，动机主要来自奖励）；
主动想按 SHIFT 的意愿 → **有保留**；
动态节奏 → **够，但量仍少**（G 段已从 7 补到 13）；
失败恢复 → **恢复够，“有趣”未知**（无真人数据）；
空跑 → 有改善，Z3 两对重复仍在。

**仍不够好玩的诚实清单**（不改 GDD 规则的前提下，本轮做不到的）：

1. 主动换人的动机是“+30/+50/+250”，不是“不换就不行”——44/55 组乌龟方案能过。
2. 普通礁/梁/门没有持续提示，新手第一次靠失败学会；会动的障碍已有 G6 的一句提示，
   类型教学在 G21 之后会“撞一次、下一组再教一次”，G22 起**每类最多补教一次**
   （首次 + 一次，之后不再复读）；两句的频率是否仍然啰嗦，未经真人检验。
3. 反馈有灰盒表演（落水：耳朵打转 + X 眼 + 水花圈；翻肚皮 + 晃动；第三格：原地抖 + 闪白；
   成功：连招的环 + 文字 + 弹跳，接人与救回的横幅 + 弹跳），但**没有声音**（A1 冻结）。
4. 最无聊 30 秒仍有：开场最多 6 s 的交代段（任意键/点击可立即跳过，不算死时间，
   但对“完全不按”的玩家仍是 6 s）。
5. 14/55 动态是“看得见在动”，不是“更考验”；G22 只重跑了 `stage4_metrics`
   与 `stage4_z3_warning`（读数不变/PASS），**55 组解法矩阵没有重跑**，
   所以“难度曲线”仍只有间距层面的证据。

## 10. 修改文件清单、回归结果、best.json 校验（H10）

改动文件（本轮 02:15 后，`find -newermt` 实测）：

```
scripts/race.gd                      B1/B2 判定、C 取证入口、D 回壳奖励、E1 海鸟、
                                     F 教学按控制者、G2 dive_release_ready()、G3 擦水提示、
                                     G4/G5 celebration_offset() 画法偏移、G6 动态障碍首次提示、
                                     G7 日常落壳不报「好接！」、G8 落壳走廊显示、
                                     G9 落壳时壳下沉再回弹（只改画法）、
                                     G10 首次教学先来后到、
                                     G11 --capture-showtime 取证修复（只改截图工具）、
                                     G13 --capture-accident 等到真事故、
                                     G14 --capture-boost 认文件名、
                                     G19 A 类撞错角色提示（hint.take_rabbit）、
                                     G21 撞过重新武装首次教学 + 跳过已撞组、
                                     G22 补教上限（lesson_retaught）、
                                     G22 load_level() 归零 hazard_clock
scripts/systems/tuning.gd            D 的 RESCUE_SWITCH_BONUS 等常量、G8 的 PICKUP_HINT_DY_MIN、
                                     G9 的 SHELL_DIP_TIME/ROUTINE/CATCH/RESCUE、
                                     G10 的 LESSON_CLEAR_BEHIND
scripts/systems/level_data.gd        E3 两处挪位 + 13 组 motion；G22 再加 log5（14 组）
scripts/autoload/game_manager.gd     判罚记账所需的返回/状态
scripts/autoload/locale.gd           C/D/F/G2/G3/G6 新文案（中英）
scripts/ui/hud.gd                    C 双角色引导条 + G2 松手提示
scripts/ui/pause_menu.gd             G12 暂停面板补操作对照（复用 menu.hint）
tools/restore_ctex.gd                G14 一次性恢复工具：从 .ctex 还原被覆盖的截图
scripts/test/stage2_selftest.gd, stage3_playtest.gd, stage4_core_experience.gd,
  stage4_playful_bro_dive_audit.gd, stage4_snack_rush.gd      探针/回归侧适配
scripts/test/stage5_{b_probe,b3_repeat,c_hud,d_shift,e1_bird,e2_motion,e3_ollie,
  f_lessons,g_measure,g2_release,g3_hint,g4_cheer,g5_carry,g6_motion,g7_banner,g8_corridor,
  g9_shell_dip,g10_lesson_order,g11_showtime_capture,g17_trynext,g19_wrongrole,
  g21_relesson}.gd + 对应 scenes/*.tscn
                                                            本轮新增探针（g8_capture/g9_capture 为截图取证）
scripts/test/stage4_*（20 个探针只补 `hit_roles` 复位，G20）      探针侧
```

`docs/reports/longrun/` 下另有各轮记录：`REBUILD05-G9.md`–`REBUILD05-G22.md`、
`rebuild05-g*.json`（探针数据）。

两圈全流程（`stage3_playtest`，真实 `race.tscn`，13 组动态，headless）：

```
FINISH run=1 time=272.9 score=9770 grade=S passed=55/55 casualties=0 show=17 streak=55
FINISH run=2 time=272.8 score=9770 grade=S passed=55/55 casualties=0 show=17 streak=55
STAGE3 PLAYTEST: PASS
```
（G2、G3、G4、G5、G6 改动后又各跑一次两圈，数值逐字相同：`fullrun-g2b.log`、`fullrun-g3.log`、`fullrun-g4.log`、`fullrun-g5.log`、`fullrun-g6.log`；G5 落壳修正后 `fullrun-g5b.log`、G7 后 `fullrun-g7.log`、G8 后 `fullrun-g8.log` 同样逐字相同。G9–G21 再各跑一次，`fullrun-g9.log`…`fullrun-g21.log` 的 FINISH/总结行也全部逐字相同。
08:52 收尾时用最终工作树再跑一次 `fullrun-final.log`，与 `fullrun-g21.log` 关键行 diff 为空。）

批量回归（G11 后 21 个场景；G21 收尾时为 24 个，加了 g17/g19/g21）：见 §10.1。

### 10.1 批量回归

全部退出码 0，日志 `$TEMP/reg-g11-<scene>.log`：

| 场景 | 结果 |
|---|---|
| stage1_selftest | PASS（G8 前断在 pickup window，已修） |
| stage3_selftest | PASS |
| stage4_bilingual | PASS |
| stage4_core_experience | PASS |
| stage4_hud_priority | PASS |
| stage4_level_audit | TOTALS 55 组 / `no_solution_groups=0`，0 条 fail |
| stage4_metrics | PASS |
| stage4_snack_draw | DONE checks=23 fails=0 |
| stage4_snack_zones | DONE rows=18 fails=0 |
| stage4_snack_rush | DONE cases=3 fails=0 |
| stage4_collision_feedback | PASS |
| stage5_e3_ollie | PASS |
| stage5_f_lessons | PASS |
| stage5_g2_release | PASS |
| stage5_g3_hint | PASS |
| stage5_g5_carry | PASS |
| stage5_g7_banner | PASS |
| stage5_g8_corridor | PASS |
| stage5_g9_shell_dip | G9 SHELL DIP: PASS（20 条断言） |
| stage5_g10_lesson_order | G10 LESSON ORDER: PASS（教学按先来后到，七类全教） |
| stage5_g11_showtime_capture | G11 SHOWTIME CAPTURE: PASS（事故中仍拒绝启动，修后条件拍到 SHOWTIME） |
| stage5_g17_trynext | PASS（G17 起加入批量） |
| stage5_g19_wrongrole | PASS（G19 起加入批量） |
| stage5_g21_relesson | G21 RELESSON: PASS（G21 加入批量） |

未跑：`stage4_hud_score`、`stage4_menu_input`（需要真实窗口，headless 会挂）。
G12 之后（`$TEMP/reg-g12-<scene>.log`）与 G14 之后（`$TEMP/reg-g14-<scene>.log`）
各重跑同一批 21 个场景，全部 exit 0、0 条失败行、0 条 SCRIPT ERROR。
G15 之后补跑了两个窗口化测试：`stage4_hud_score` `PASS checks=44`（修前 43/44）、
`stage4_menu_input` PASS；G16 之后同样：`stage4_hud_score` 44/44、`stage4_menu_input` PASS，
21 场景 `$TEMP/reg-g16-<scene>.log` 见 `REBUILD05-G16.md` 的回归一节。
G21 收尾（最终代码）再跑一次：24 场景 `reg-g21-*` 全 exit 0 / 0 条失败行，
窗口化 `stage4_hud_score` 44/44、`stage4_menu_input` PASS。

**08:52 收尾的全量回归**（最终工作树，产品代码自 G21 后未再改）：
25 场景批量（上面 21 个 + `stage4_lesson_prompt` + `g17` + `g19` + `g21`，
`/tmp/final-<scene>.log`）全部 exit 0、0 条失败行、0 条 SCRIPT ERROR；
窗口化 `stage4_hud_score` 44/44、`stage4_menu_input` PASS；
两圈 `fullrun-final.log` 见下。G20 那 20 个一次性审计探针不在常规批量里：
它们不读 `prompt` 信号，G21 只改教学发声，因此本轮没有重跑（G20 当天已 18/18 连跑两次）。

`best.json`：跑前跑后 md5 `c322f9a20321c5b618f98db7e4120969`，内容仍是
`best_score 3150 / best_time 283.961389 / best_accidents 0 / streak 54`——
测试在 `_finish_ok()` 里逐字节还原，制作人纪录未被覆盖。
（跑动过程中会短暂写入测试成绩，这是预期行为，只有退出后的 md5 有意义。）

## 11. 未完成与下一步优先级（H11）

| 优先级 | 项 | 理由 |
|---|---|---|
| P1 | 真人试玩 15–30 min，记录“第一次 SHIFT 的动机”和“最无聊的 30 秒” | 本轮全部体验结论来自自动驾驶+探针，缺的就是这一项 |
| P1 | 让“不换人会更难/更慢”有可测形式（例如乌龟单方案多耗时间），不新增惩罚 | 44/55 可单角色通过，主动换人动机弱 |
| P2 | Z3 两对两连重复各 4 次 | F 段已识别；G22 只让第一处浮木会沉浮，顺序未改 |
| P3 | 难度曲线重测（14/55 动态后，55 组解法矩阵）；动态障碍再加种类 | G22 只重跑 `stage4_metrics`（读数不变）与 `stage4_z3_warning`（PASS）；E2 仍只有三个正弦原型 |
| ~~P3~~ | ~~`stage4_rescue_boost` z3（beam8）探针侧 8 例 `crash=no_hit`~~ | G18 已修：不是起跳前提失效，是探针 `_reset()` 漏清 `hit_roles`（同组从第二例起整组免疫），外加汇总判定从不进退出码。修后 25/25 真撞、8/8 checks，见 `REBUILD05-G18.md` |
| ~~P3~~ | ~~20 个探针只清 `hit_groups` 不清 `hit_roles`~~ | G20 已修（20 文件 25 处），重跑暴露并改正了 `bird_routes` 的假通过、`joint_verdict` 的过时预期、`snack_zones` 的起点/相位；见 `REBUILD05-G20.md` |
| ~~P3~~ | ~~其余多行探针仍可能受动态障碍相位漂移影响（只有 `snack_zones` 归零了 `hazard_clock`）~~ | G22 已修：归零放进 `load_level()`，探针每重装一次关卡就从同一相位起跑；正式赛局行为 0 变化。26 场景批量（含 `e2_motion`）全绿 |

**本轮明确没有做 / 没有验证的**（08:52 收尾清单，全部如实列出）：

1. **没有任何真人试玩**。所有“易上手 / 有趣”的结论都来自探针与自动驾驶。
2. 主动换人的收益仍靠加分（+30/+50/+250），没有让“不换就更难/更慢”成立。
3. Z3 两对两连重复各 4 次，顺序未改；55 组解法矩阵在 14/55 动态之后未重跑。
4. 没有任何音频（A1 仍冻结，SHIFT 电流音效保持关闭）。
5. 开场封面默认停 6 s（任意键可跳过），没有缩短。
6. ~~G21 的补教没有次数上限~~ → G22 已封顶（每类首次 + 一次补教）；补教频次是否仍啰嗦未经真人检验。
7. ~~其余多行探针的 `hazard_clock` 相位漂移没有逐一处理~~ → G22 已在 `load_level()` 统一归零。
8. 没有新增动态障碍原型（仍是周期/扫掠/环境三种正弦；G22 只是多一处浪涌浮木）。

勘误（G16 时复核）：本表原写入“开场 6 s 不可操作段”。实际 `scripts/ui/opening.gd`
里任何键 / 鼠标左键都能立刻跳过（`_input` → `_finish()`），headless 测试根本不挂开场。
所以它不是“不可操作段”，只是个默认停 6 s 的占位封面；旧描述作废。

## 12. 代码验证 / 自动驾驶验证 / 真人体验验证（H12）

| 层 | 本轮有什么 | 能证明什么 | 不能证明什么 |
|---|---|---|---|
| 代码验证 | 探针 23 个、断言数百条（B/C/D/E1/E2/E3/F/G2–G11/G19/G21 各自 PASS；G18/G20 为探针修复轮） | 机制按规格实现、状态与记账自洽 | 玩家是否会觉得好玩 |
| 自动驾驶验证 | 两圈 55/55、0 事故、272.9/272.8 s，13 组动态下逐字不变 | 物理/碰撞/输入/时序没有回归 | 难度是否合适——自动驾驶走的是最优路线 |
| 真人体验验证 | **本轮没有**（最近一次制作人试玩 2026-11-11，见 `PRODUCER-PLAYTEST-NOTES.md`；本轮新增机制未获新意见） | — | 一切关于“欢乐/有趣”的判断 |

因此：本报告所有“有趣 / 有保留 / 够”的表述都是**自评**，按任务书 G8 不作为完成证明；
STAGE 保持 4，等制作人真人质检。
