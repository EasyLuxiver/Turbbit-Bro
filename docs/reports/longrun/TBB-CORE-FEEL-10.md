# TBB-CORE-FEEL-10 核心体验问题集中修复

- 日期：2026-11-14
- 阶段：`STAGE=4`（未推进 5；未做音频；未下载模型/训练 LoRA/升级 ComfyUI）
- 性质：CONTROLLED_WRITE，集中修 P0-A/B/C/D 与 P1-A/B，P2 回归
- 结论：**技术验收按 QC 逐条判定；有趣性只写“有保留”，等制作人试玩，不宣称通过**

## 1. 范围与硬约束

只改核心体验层，不动正式 55 组的判定几何，不重写 `race.gd`，不覆盖历史产物。
`best.json` 开工前备份在 `_attic/2026-11-14/feel10-baseline/best.json`，MD5
`E3C001086339EAF22E906D531821D30A`；收尾复核仍为同一 MD5，测试入口不写正式纪录。

## 2. P0-A｜联合判罚语义

**规则**

- 单角色失误只记该角色：扣 100、只喂该角色的 BRO；满 3 格只让“本次失误的角色”
  进入 0.5–1 s 捣乱，另一角色保持可操作。
- 真联合只在 TUBO 与 BITT 都在真实危险里、且进入危险时刻相差 ≤0.6 s 时触发。
  兔子危险 = 落水/昏迷/救援空中；乌龟危险 = 翻壳/缺氧/被实心障碍持续顶住。
- 救援流程本身不喂 BRO、不触发联合、不冻结全员；救援成功不记事故，失败走独立后果。

**修掉的根因**

`_trigger_accident()` 原先先写 `GameManager.accident_state = reason`，再读
`_rescue_context()`；读到的永远是刚写进去的 reason，于是**所有事故都被当成
“救援中的二次事故”而不记账**。改为先取救援上下文再写状态。这一条是回归里
`accidents 0→0` 的来源，已由 `rescue_success_initial` 锁住。

**证据**

- `docs/reports/longrun/core-feel-10-p0a-joint.json`：10/10
  - 单角色：`pending=true role=rabbit/turtle joint=0`
  - 真联合：`joint=1 show=1.40 state=BRO_BREAK`
  - 救援：初始 `accidents=1`，成功/失败后 `1→1`，BRO `1→1`
  - 窗口外：`joint=0 show=0.00`
  - 另一角色可操作：`other_role_operable` 通过
- `stage7_joint_penalty`：PASS（救援成功 `joint=0`；同帧双撞仍只记一笔）
- 8 例验收矩阵在探针里展开为 10 条断言，全部判 pass。

## 3. P0-B｜神游改成真实控制干扰

**规则**

- 四个阶段保留：CALM 0 / DISTRACTED 0.05 / RESTLESS 0.17 / MISCHIEF 0.22 s
  反应延迟（兔子）；乌龟的自漂在 RESTLESS 半幅、MISCHIEF 全幅。
- MISCHIEF 不再只是延迟：0.35 s 前摇 → 0.70 s 单角色拒绝输入/自主动作 →
  3 s 冷却，随后恢复；另一角色始终不被锁。
- 关键障碍前 600 px 内不突然夺权，等空档再起；不无限延迟、不永久损失。

**证据**

- `docs/reports/longrun/core-feel-10-p0b-drift.json`：8/8
- 30 Hz：telegraph 0.37 / duration 0.70；60/120 Hz：0.35 / 0.70；`other_locked=false`；`cd=3.00`
- 四段延迟严格递增，`stage_delays` 通过
- 实机入口 C/D 的状态栏可看到 `drift R/T`、`burst=who/phase`、`refuse R/T`；
  C/D 探针日志：`rabbit/TELEGRAPH 0.22 s → BURST 0.55 s → 结束 1.25 s`，
  乌龟同拍。

## 4. P0-C｜两个新动词

不是正式 55 组，是两个独立试玩段。

**水流改道（E）**

- 浮木随水流上下，amp 100 / period 6 s；高到跳跃顶点以上时只能下潜，低到下潜
  壳层时只能起跳；水线、流动箭头、`下潜/起跳` 状态字都画在浮木旁。
- 48 相位采样：无解 0；both 22、jump-only 17、dive-only 9。
- 底栏文案改为与机制一致的“浮木高→下潜 / 浮木低→起跳”，并关掉正式 55 组的
  `BRO DIVE` 协作条，避免相反指令。

**状态吊网（F）**

- 控兔子时网在低位：站着撞、趴低过；切到乌龟，绞盘 0.475 s 把网拉高 95 px，
  兔层直接让开；回落 1.0 s 回到 0 px。
- 网体改成真的半透明网眼 + 绞盘/吊索/`网低`/`绞盘↑` 状态字。

**证据**

- `docs/reports/longrun/core-feel-10-p0c-verbs.json`：7/7
- `docs/reports/longrun/feel10-p0c/`：4 张实机截图（高/低水流、低/高吊网）
- 55 组未加这两组；E/F 是独立场景 `p0c_current_test.tscn` / `p0c_net_test.tscn`

## 5. P0-D｜Z2 码头入场

- 远景从 12400 开始出现；15000 边界时 `bg_far/mid/props/canal=1.0`，
  `fg_overhead=0.727`、`fg_near=0.636`；第一组 Z2 障碍 shark3 在 15800，
  六层全部 `1.0`，环境先读完再见障碍。
- 可见节拍：14600–15200 的渐变带 600 px / 220 = **2.7 s**，区名 15000 落在
  节拍中段；15200 环境实心 → 15800 第一组障碍还有 600 px（2.7 s）的读图余量。
- 15000 的旧硬边不是“淡入”能解决的：Z1 平色背景正好在 15000 结束，Z2 六层
  从 15000 开始，接缝是几何断层。现在把 Z1 背景提前到 14600 结束，14600–15200
  用 256×1 alpha 渐变纹理把 Z1 颜色化开，Z2 的水面也从 14600 起铺，接缝消失。
- 入场不冻结玩法：速度 220→220，障碍组 55→55；区名/教学在 15000 同拍。

**证据**

- `docs/reports/longrun/core-feel-10-p0d-entry.json`：5/5
- `docs/reports/longrun/feel10-p0d/`：14000 远景 / 14800 接近 / 15000 边界 /
  15500 已入场 / 15800 第一组障碍
- 50 px 连续采样的最大 alpha 跳变 0.023（阈值 0.12）

## 6. P1-A｜TUBO 独立拆件动画

**产物**

- `art_test/tubo_parts/`：10 个透明 PNG
  `tail / rear_far / rear_fin / front_far / neck / carapace / rim / front_fin / head / lid`
- `pivots.json`：每个部件的 pivot_source、pivot_local、bbox、order
- `anim_nodes.json`：节点父子（neck→head→lid）、z_index、纹理路径
- 场景 `scenes/tubo_parts_anim_test.tscn`：IDLE / CRUISE / JUMP / LANDING
  各 3 s，12 s 循环；头/颈反相点头、四鳍相位错开、尾滞后摆动、壳呼吸/落地压扁、
  每 3.4 s 眨眼
- `tubo_parts_preview.gif`（360 帧 @30 fps）、`tubo_parts_states.png`、
  `pivot_map.png`、`parts_contact_sheet.png`

**说明**

TUBO 是乌龟，没有耳朵；任务书里的“耳朵”按 N/A 记录，不为了凑清单造一对假耳朵。
`rear_far` 是近侧后鳍的暗化缩小版（同向，不镜像），`tail` 是合成的三角尾；
这两个是拆件原型的补件，不是最终美术。

**优点 / 问题**

- 优点：每个部件独立绕 pivot 动，四状态的动作差异一眼可分；落地压扁/回弹和
  四鳍错拍比“整张图转一转”明显更像活物；`lid` 的 pivot 已从 v2 的额头位置
  改到眼心 (853,389)，眨眼真的合在眼上。
- 问题：远侧前鳍/后鳍的基部大多被壳和近侧鳍遮住，只在某些角度露出尖端，
  静态帧会读成“游离的小片”；颈部在头壳之间的可见面积仍偏大。真正接入游戏前
  需要按镜头角度补遮罩或重画远侧鳍。尾巴目前是几何三角，缺少鳍状分叉。

## 7. P1-B｜8 个制作人测试入口

主菜单新增“制作人测试 / PRODUCER TESTS”按钮 → `scenes/producer_menu.tscn`。

| 入口 | 场景 | 观察点 | 重置 |
|---|---|---|---|
| A 单角色/联合事故 | `producer_case` mode A | 撞海鸥只扣兔子；J 演示真联合 | R |
| B 救援免疫 | mode B | 落水救援；K 演示救援中碰撞不记账 | R |
| C TUBO 神游 | mode C | 控兔子，乌龟 RESTLESS→自漂/前摇→不服从 | R |
| D BITT 神游 | mode D | 控乌龟，兔子 RESTLESS→前摇→不服从 | R |
| E 水流改道 | `p0c_current_test` | 浮木高/低与安全路 | R |
| F 状态吊网 | `p0c_net_test` | 网低趴低 / 切乌龟升网 | R |
| G Z1→Z2 入场 | mode G | 14200 起跑看渐变与第一组障碍 | R |
| H TUBO 拆件动画 | `tubo_parts_anim_test` | 四状态循环 | R |

每个入口都有标题、可观察点、H 展开/收起说明、R 重置、F10 回测试菜单。
`GameManager.test_no_best` 在进入测试时置真，`finalize_run()` 跳过 `_update_best/_save_best`；
主菜单“开始游戏”会把它复位。A/B 的 J/K 是手动演示键，不是自动驾驶脚本；
C/D/G/E/F/H 都是真实物理/输入。

**证据**

- `docs/reports/longrun/feel10-p1b/`：`producer-menu.png` 与 A–G 实机截图
- A 演示：`DEMO A joint=1 accidents=0 show=1.10`
- B 演示：`DEMO B accidents 1->1 bro 1->1 mount=RESCUE_ACTIVE`
- C/D 实机：`rabbit/TELEGRAPH 0.22 → BURST 0.55 → end 1.25`，乌龟同拍
- best.json 收尾 MD5 仍为 `E3C001...D30A`

## 8. P2 回归与数据

**通过**

- `stage4_menu_input`（窗口化）：PASS（新增按钮后 4 个按钮，键盘/鼠标/退出确认均过）
- `stage10_joint_semantics`：10/10 PASS
- `stage10_drift_burst`：8/8 PASS
- `p0c_verify`：7/7 PASS
- `p0d_entry`：5/5 PASS
- `stage8_hz_regression`：CORE-FEEL-08 P2-8 PASS
- `stage4_collision_feedback`：PASS
- `stage7_joint_penalty`：PASS（修了测试 reset 里 FEEL-10 计时器泄漏）
- `stage4_water_rescue`：跑完，自然入水/主动下潜的接与不接都有记录
- `stage4_proto`：PASS（浮木/高墙的完整动作与判定未被改动）
- `stage5_g2_release`：G2 RELEASE PASS
- `stage4_lesson_prompt`：13 个教学键 / 55 组全部装载，0 事故
- `stage3_playtest`（两圈）：**PASS**：274.0 / 273.9 s，两圈 **55/55**、0 事故、
  Retry 正常、zones [1,2,3]、failures=0（日志 `docs/reports/stage3-run.log`）
- `stage4_solution_audit`：55 组安全解矩阵本轮全量重跑**未跑完**，在 g=36 手动停止
  （不是 FAIL，是没有结论）；已完成段每组至少一条 safe 路线，与改前一致。55 组
  可解性以两圈 playtest 的 55/55 为准，不拿未跑完的 audit 冒充全过。

**QC 判定：11/11 pass**（`LESSONS/REPORTS/qc/tbb-core-feel-10.json`）。
唯一没有跑完的是全量 solution audit；55/55 的路线结论来自两圈 playtest，不来自 audit。

**未验证 / 风险**

- 全量 55 组 solution audit 尚未跑完（两圈 playtest 已给出 55/55、0 事故的路线证据）；
  `stage4_proto`/`g2_release` 已覆盖浮木、高墙、菜单/暂停/重开/结算等主干
- 本轮没有做真人 30 分钟连续试玩，也没有测帧时间/长时间稳定性
- P0-C 的两个动词只在独立测试段，没有并入正式 55 组；并入前要重新排节奏
- P0-D 的渐变带是平色近似，Z2 的远景/仓库细节在过渡中还做不到逐像素 crossfade；
  但接缝已从“一刀”变成连续色带
- P1-A 的远侧鳍/颈/尾仍是原型级，不满足正式角色动画的完成度
- 音频、音乐、正式美术仍冻结

## 9. 未解决项清单

1. 远侧前/后鳍的遮挡和“游离小片”感，需要按游戏镜头重画或加基部遮罩。
2. 尾巴只有三角剪影，没有鳍状分叉；需要和头部同级的细节。
3. 颈部在头/壳之间的露出面积偏大，需要缩短或在壳内加遮挡。
4. P0-C 的水流/吊网还没有进入 55 组，缺少与既有节奏的合流验证。
5. Z1→Z2 的过渡带以平色近似，极限分辨率下仍可能看出色带。
6. 全量 solution audit 未跑完（手动停在 g=36）；后续若跑出某组无解，按 FAIL 重做。
7. 无真人试玩数据；有趣性只能写到“有保留”。

## 10. 有趣性自评

按 TURBBIT 规则先实际跑本阶段内容再回答：

1. **新增操作能否一句话说清用途？** 能。水流=看浮木高低选跳/潜；吊网=网低趴低、
   切乌龟升网；神游=满值会短暂夺走该角色的操作。
2. **有没有“我做了判断，然后成功了”的瞬间？** 有，但只在测试段：E 的 48 相位里
   jump-only/dive-only 各 17/9 段，选对路能过；F 的网低趴低/切乌龟升网都能过。
   正式 55 组里还没有这两个动词，所以不能算正式关卡的判断瞬间。
3. **操作错了有没有可见后果？** 有：单角色失误只让该角色捣乱、联合事故有冻结演出、
   救援成功不额外罚、失败有独立后果；E/F 撞上会落水/被网压。
4. **比上一阶段多了一个想再试一次的理由吗？** 有保留：联合判罚终于“谁错罚谁”，
   神游从数值延迟变成可读的 0.35 s 前摇 + 0.70 s 不服从，值得再试；但新动词还
   没进正式赛道，重复游玩的理由仍主要来自旧 55 组。

**结论：有保留。** 不宣称“有趣性通过”，等制作人用 A–H 入口真人试玩后再定。
本阶段最无聊的 30 秒：C/D 测试段开头等神游从 8.5 涨到 9.0 的空转（约 1 s，
不是正式赛道内容）；正式赛道本阶段未新增空档。
