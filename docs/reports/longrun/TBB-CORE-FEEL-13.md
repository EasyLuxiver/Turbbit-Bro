# TBB-CORE-FEEL-13 未完成项闭环与内容冻结准备

- 日期：2026-11-14
- 阶段：`STAGE=4`（不推进 Stage 5）
- 范围：只收 FEEL-12 未完成项；不加新技能、新按键、新资源条、新障碍类型/区域/组。
- 结论：**P0-A / P0-B / P0-C / P1-B 完成；P1-A 只完成“独立拆件 + 组装 + 9 个动作技术样”，没有接进正式比赛，也没有大表哥关键姿态，因此内容冻结条件仍未全部满足。**
- 趣味性自评：**有保留**。自动化两圈 55/55 不等于是人觉得好玩；需要制作人实际试玩。

## 1. P0-A：BITT 主动救援闭环

### 真实链路

`stage13_catch_matrix` 用正式 `race.gd` 物理逐帧推进，11 个 case 全部 `caught + RIDING`：

| case | 结果 | 最大单帧位移 |
|---|---|---|
| 前方 280 / 800 px | caught → RIDING | 15.7 px |
| 后方 240 px | caught → RIDING | 17.8 px |
| 浅水 40 / 深水 220 / 水下 260 | caught → RIDING | 14.9 px |
| 从水面开始 | caught → RIDING | 11.7 px |
| 障碍路径（LOW_BEAM 在中间） | caught → RIDING | 14.9 px |
| 救援窗口只剩 0.9 s | caught → RIDING | 12.1 px |
| 30 Hz / 120 Hz | caught → RIDING | 27.1 / 7.8 px |
| TUBO 安全（无救援） | 不启动、不接 | 3.7 px |

- 没有传送：所有 case 最大单帧位移 ≤ 27.1 px，低于 80 px 阈值。
- 接住后走真实 `_begin_carry("rescue")`，逐帧抬回壳上，再回 `RIDING`；不是一帧吸附。
- 30 Hz 第一版失败，原因是上一 case 留下的 `emergency_timer` 到期把 `rabbit.state` 写成 `RIDING`，中途取消救援；case 隔离已补齐（`emergency_timer/rabbit_stun/grace` 清零）。这不是放宽判定。
- 证据：
  - `scripts/test/stage13_catch_matrix.gd` + `scenes/stage13_catch_matrix.tscn`
  - `docs/reports/longrun/core-feel-13-catch-matrix.json`
  - `docs/reports/longrun/feel13/bro-catch-chain.gif`（55 帧，接近→接住→抬回→RIDING）
  - `_attic/2026-11-14/feel13-catch-frames/`（原始逐帧）

### 仍然不是

- 没有真人手指完整跑一遍 9 个 case；矩阵是物理代理。
- GIF 里 BITT 的接近路线是直线目标追踪；遇到真实障碍仍由玩家自己下潜/跃起，未做自动绕障。

## 2. P0-B：G01–G55 实际重排

不是填表：`scripts/systems/level_data.gd` 的 55 组 x 全部按“上一组末端 + 反应时间”重算；Z3 末段 13 组顺序实际打乱；10 个动态组的 phase 改为错开值。

### 实际改动

- 55 组全部重算 x；其中 Z1 前 6 组保持 FEEL-12 位置（保护 `stage5_g10` 的 log1/shark1 教学顺序），其余 49 组 x 都变了。
- 顺序改动：
  - Z3 末段由 `bird7→shark8→beam8→rock10→log7→bird8→shark9→beam9→rock11→gate8→log8→bird9→rock12`
    改为 `shark8→bird7→beam8→log7→rock10→shark9→bird8→beam9→log8→rock11→gate8→bird9→rock12`。
  - 这样消掉 `bird7→beam8→rock10` 三连兔子，也让 log8/rock11/gate8 不再按原顺序堆在一起。
- 运动相位：rock4 0.18、log2 0.22、rock5 0.47、rock7 0.63、rock8 0.31、rock9 0.52、log6 0.14、rock10 0.71、rock11 0.27、rock12 0.58；log5 保留 0.35。
- 间距按障碍宽度算，最小反应时间 **3.58 s**（要求 ≥3.5 s），不是只看组中心到组中心。

### 硬指标（`_feel13_groups_table.py` 现场计算）

| 指标 | 要求 | 实测 |
|---|---|---|
| 连续同节奏 | ≤2 | **2** |
| 连续同主角色 | ≤2 | **2** |
| 双角色组 | ≥12 | **33** |
| 动态组 | ≥10 | **18** |
| 护盾机会 | ≥8 | **30** |
| 救援机会 | ≥4 | **11** |
| 缓冲/学习 | ≥8 | **15** |
| 任意 5 组 ≥3 种节奏 | 全部 | **51/51** |
| 普通路线不按 SPACE | ≥一半 | **44/55** |
| 最小反应时间 | ≥3.5 s | **3.58 s** |
| 全量 audit 无解组 | 0 | **0** |
| 设计答案正确 | 55 | **55** |

- 表格：[FEEL13-55-GROUPS.md](FEEL13-55-GROUPS.md) / [feel13-55-groups.csv](feel13-55-groups.csv) / `core-feel-13-groups.json`
- 每行含：结构、节奏、决策、普通/进阶路线、SHIFT/SPACE、**实际修改**、audit 验证。
- 注意：表格的“障碍”是基础种类；实际开局的食物抽签会把 7 个组换成另一种类（如 beam1→LOW_BIRD、gate3→SHARK），audit 列同时记录“实际种类”和“抽签替换”，没有把两者混在一起。

## 3. P0-C：全量回归

### 全量 solution audit

- `AUDIT groups=55 schemes=7` → `AUDIT no_solution=[]` → `SOLUTION AUDIT: DONE`。
- 七类障碍的设计答案全部 55/55 通过：LOW_BIRD 8/8、SURFACE_ROCK 11/11、DIVE_GATE 8/8、FLOATING_LOG 8/8、SHARK 8/8、LOW_BEAM 9/9、HIGH_WALL 3/3。
- 证据：`feel13/logs/_f13_audit_new.log`、`docs/reports/stage4-solution-matrix.json`（generated 2026-11-14T21:12:55）。

### 两圈完整跑圈

- 第一圈：`time=275.1 score=12250 grade=S passed=55/55 accidents=0`。
- 第二圈：结算按 `R` Retry 进入，`time=275.0 score=12250 grade=S passed=55/55 accidents=0`。
- `max_accident=0.00s`、`max_stuck=0.0s`、`failures=0`、`STAGE3 PLAYTEST: PASS`。
- 第一版第二圈在 13 个组出事，根因是 Retry 后的新 race 实例没有继承 `test_no_overdrive/test_no_lessons`；补齐后两圈条件一致。这不是把事故判宽。
- 证据：`feel13/logs/_f13_playtest2.log`、`docs/reports/stage3-run.log`。

### 技能与帧率

- `stage12_overdrive`：**15/15**，含 30/60/120 Hz、`Engine.time_scale=1`、0.70 s 视觉强调。
- `stage12_skills`：**9/9**，护盾精准/普通/非万能/换手；BITT 前/后接近；安全不接；完整接住 `caught/CARRYING`。
- `stage13_catch_matrix`：30/60/120 Hz 均 caught→RIDING。
- `stage8_hz_regression`：PASS。
- `stage11_shift_relay` 10/10；`stage11_story_flow` 4/4；`stage4_bro_meter`、`stage4_bilingual`、`stage4_flow` PASS；`stage4_menu_input` 窗口化 PASS。

## 4. P1-A：ComfyUI 独立透明部件（部分完成，未闭环）

### 已完成

- 用 ComfyUI / Anima 生成 **拆件图**，不是从完整角色成图裁切：
  - `art_test/feel13/source/tubo_parts_sheet.png`
  - `art_test/feel13/source/bitt_parts_sheet.png`
  - 工作流：`art_test/feel13/workflow_tubo_parts_v2.json`、`workflow_bitt_parts_v2.json`
- 拆出并命名 17 个透明 PNG：TUBO 头/双耳/躯干/双臂/双腿/尾，BITT 壳/头/四鳍/连接件。
  - `art_test/feel13/parts/TUBO/`、`art_test/feel13/parts/BITT/`
  - pivot 表：`art_test/feel13/parts_meta.json`
- Godot 部件组装：`scenes/feel13_part_assembly.tscn`、`scripts/test/feel13_part_rig.gd`。
- 9 个动作技术样：Idle / Cruise / Jump / Leap / Landing / Guard / Catch / Spring Overdrive / Shell Overdrive。
  - 截图：`docs/reports/longrun/feel13/assembly-*.png`
  - 总览：`assembly-contact.png`
  - GIF：`assembly-clips.gif`（72 帧）
  - 记录：`feel13/core-feel-13-assembly.json`

### 没完成 / 不能声称

- **没有接进正式 `race.tscn`**；正式比赛仍用原生绘制，拆件只在独立预览场景。
- **不是 Skeleton2D/Bone2D 蒙皮**：尝试过 Bone2D，但子 Sprite 在 Bone2D 下不渲染；最终用 Node2D 关节层级组装。这只能算“部件组装”，不能算“骨骼蒙皮”。
- 没有大表哥关键姿态（结尾/教学）。
- 部件来自 AI 拆件图，描线/配色/比例只在单张图内一致，**不等于正式角色美术**；动作是程序化关节旋转，不是逐帧动画。
- 因此 P1-A 未达到任务要求的“真正流畅、不是占位动画”。

## 5. P1-B：1920 / 教学 / 菜单 / 流程

### 氧气气泡

- `stage13_oxygen_1920`：物理窗口 **1920×1080**，3/2/1/0 四态全对，气泡中心始终在视口内。
- 全屏：**2560×1600**，同样 3/2/1/0 全对。
- 截图：`feel13/oxygen-1920-*.png`、`oxygen-1920-*-fullscreen.png`。
- 记录：`core-feel-13-oxygen-1920.json`。

### 教学

- `stage13_tutorial_flow` **8/8**：step1 文案、大表哥标题、step2 同帧替换、提前动作直接进 step3、旧提示不回写、失败提示 2.2 s 消失、重开回 step1、K 跳过。
- 修正：1920 下教学面板原来从 x=280 起，压住左上 HUD；已移到 x=344。
- 截图：`feel13/tutorial-step1/2/3/fail-1920.png`；开场 7 格：`feel13/opening-1..7.png`。
- 正式流程：`stage11_story_flow` 4/4（开场→教学→55 组）。

### 菜单与结算

- 主菜单只有 **开始游戏 / 设置 / 退出**；无最佳纪录、阶段、区域、制作人入口。
- 截图：`screenshots/feel13-menu-1920.png`。
- 结算：大表哥 + TUBO/BITT 反应，只有比赛时间/失误/干净通过/BRO COMBO 四行，无总分/旧开发文字。
- 截图：`screenshots/feel13-result-B-1920.png`。

## 6. best.json

- 开工备份：`_attic/2026-11-14/feel13-baseline/best.json`，MD5 **067DEB9A71A19C2F6F9F6DC41FEABF09**，score 9870。
- 两圈回归时自动化曾写入 12250；`_restore_best` 已还原，收工复核 MD5 **完全一致**。
- 没有把自动成绩当玩家纪录。

## 7. QC

`tbb-core-feel-13` 10 条全部判 **pass**：

1. 救援链路 11/11 + GIF；
2. 55 组实际 x/顺序/phase + 硬指标；
3. 全量 audit 无解组 0；
4. 两圈 55/55、Retry；
5. 技能/帧率；
6. 菜单/结算；
7. 1920/全屏氧气；
8. 教学/流程；
9. best.json；
10. 实际运行 + 趣味性“有保留”。

记录：`LESSONS/REPORTS/qc/tbb-core-feel-13.json`。

## 8. 未完成 / 已知问题

- **P1-A 未闭环**：拆件未接正式比赛、无 Skeleton2D 蒙皮、无大表哥关键姿态、动作是程序化技术样。
- 部件视觉质量只到“能看懂是 TUBO/BITT”的技术验证，不满足正式角色美术；四肢有分离感，BITT 鳍片接点还需人工修。
- 没有真人 30 分钟试玩；两圈 55/55 是自动驾驶代理，不能证明“人觉得有趣”。
- 55 组重排后，食物抽签会换掉 7 组种类；表格已记录，但正式平衡仍需制作人试玩确认。
- 教学失败/重开/跳过是状态机验证 + 截图，不是真人逐条点过。

## 9. 给制作人的试玩建议

1. 从主菜单开始，完整看 7 格开场 → 4 步教学 → 正式比赛，重点看教学面板是否还挡 HUD。
2. 跑 60–90 秒，感受新间距：Z3 末段是否从“匀速单点”变成有快有慢。
3. 故意让 TUBO 落水，按 SPACE 试 BITT 主动救援：前方/后方各一次，看接近是否可读、接住后抬回是否顺。
4. 在低梁/海鸟前按 SPACE 试胡萝卜护盾，确认精准/普通两种反馈。
5. 看 `assembly-clips.gif` 与 `bro-catch-chain.gif`，判断拆件技术样是否值得继续投入正式美术。

## 10. 结论

- P0-A/P0-B/P0-C/P1-B 已闭环，并有自动化与截图证据。
- **P1-A 未闭环**，所以不能写“内容冻结完成”，也不能推进 Stage 5。
- 阶段保持 `STAGE=4`，停止并等制作人试玩/决定美术是否继续。
- 趣味性：**有保留**（不是“有趣”，也不是“不有趣”）。
