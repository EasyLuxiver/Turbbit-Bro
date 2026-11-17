# TBB-CORE-FEEL-12 BRO OVERDRIVE 核心定型与全局精致化

- 日期：2026-11-14
- 阶段：`STAGE=4`（不推进 Stage 5）
- 执行范围：BRO OVERDRIVE、双角色 SPACE 技能、神游/电流走火重做、文本、氧气气泡、教学、结尾、菜单、55 组审计。
- 结论：机制与文本已接入并有自动化验证；**角色独立美术未完成**，55 组全量 audit 未完成；趣味性不宣称通过。

## 1. BRO OVERDRIVE

### 触发

- 只在当前受控角色进入 `MISCHIEF`（高阶段电流走火）时出现 **0.30 s 预兆**（`_od_phase="PRE"`，HUD 黄色警告）。
- 预兆内按 SHIFT **换走当前角色** → `_activate_overdrive(true)`：
  - 电击闪光、镜头脉冲、角色残影、夸张动作；
  - 控制权交给另一个角色；
  - 原角色继续完成过载动作。
- 不按 SHIFT → 原角色自己完成过载动作（`shifted=false`），无额外奖励，也不重罚。
- **按补充指令 B：不做全局慢镜头**。`Engine.time_scale` 保持 1；0.70 s 是视觉强调/残影时间，不冻结物理或输入。
- 0.2 s 基础防连点锁保留，但预兆开始时清掉锁，保证窗口可用；慢镜头中再次 SHIFT 允许正常换人，但同一事件不重复奖励。

### TUBO：SPRING OVERDRIVE

- 预兆：耳朵竖起、身体压缩、电火花（`_start_overdrive` + `_draw_rabbit`）。
- 动作：`rabbit.launch(..., height_scale=1.55)`，真实改变跳跃弧线；空中继续受物理/操控。
- 玩家换到 BITT 后，TUBO 继续空中动作；BITT 可下潜/跃起，形成接力。
- 未按 SHIFT 时也会弹，但只是夸张动作，不直接制造事故。

### BITT：SHELL OVERDRIVE

- 预兆：龟壳旋转、水流/电弧。
- 动作：`turtle.speed = base + 160` 并保持 0.55 s，真实前冲；壳的旋转只改画法/速度，不改碰撞体。
- **不再用自动下潜作为主要捣乱动作**；下潜仍是玩家正常动作。
- 玩家换到 TUBO 后，BITT 继续旋壳前冲；TUBO 可跳跃/护盾。

### 慢镜头/输入

- 无全局时间缩放；`_overdrive_tick_real` 只维护 `_od_emphasis_t`（0.70 s）和残影，不改 `Engine.time_scale`。
- 慢镜头中 ↑/↓/SPACE/SHIFT 都由正常 Input 处理；测试 `4_slowmo_inputs` 验证 BITT 下潜立即生效。
- 测试 `9_emphasis_30/60/120Hz`：视觉强调结束约 0.70–0.73 s，`Engine.time_scale=1`。

### 奖励与风险

- 启动慢镜头/动作本身不加分。
- 只有预兆换手后，另一个角色在窗口内完成实际动作、且产生干净通过/组合，才走既有 `relay_clever` +50 / `relay_perfect` +100。
- 碰撞取消奖励；救援/事故中不启动；1.2 s 冷却；一次换人只判一次。
- 未按 SHIFT 的过载动作只做轻微失衡/速度变化，不强制严重事故。

### 正式接入

- `race.gd` 的 `_tick_overdrive` 在正式 55 组物理里运行；`stage12_overdrive` 15/15 PASS。
- 自动化跑圈关闭过载（`test_no_overdrive`），用于验证普通路线；过载由独立测试和 SHIFT 实验室覆盖。

## 2. 角色美术与动画（未完成，如实列出）

**本轮没有完成 ComfyUI 独立拆件生成。**

- 现有 `art_test/tubo_parts` 是 FEEL-10 从 v2 整图上切出的部件，**不满足**本轮“禁止从完整角色成图裁切”的规则；我没有把它冒充成本轮独立生成。
- 本轮没有新增 TUBO/BITT/大表哥的独立透明部件，也没有新的 Skeleton2D/Bone2D 组装；角色仍是 `race.gd` 的原生绘制 + 过载/护盾/救援的额外姿态。
- 已生成/保留的视觉证据是**占位级**：
  - `docs/reports/longrun/feel12/overdrive-tubo.png`
  - `overdrive-bitt.png`
  - `carrot-guard.png`
  - `bro-catch.png`
  - `oxygen-*.png`
- 未完成项：TUBO 头/躯干/双耳/四肢/尾巴/表情层独立生成；BITT 头/颈/躯干/壳/四肢/尾/表情独立生成；大表哥开场/教学/终点素材；pivot 表、节点图、关键动作 GIF、Godot 组装截图。
- 这使本轮**不满足**“角色动作真正流畅、不是占位动画”的最终要求；需要下一轮专门完成 ComfyUI 部件与组装，不能把原生绘制称为独立拆件。

## 3. 文本清单

- 旧版 343 条 → 新版 **366 条**；每条都有处置结果：
  - 保留 202；重写 88；新增 23；仅开发/不使用 49；仅调试旧开场 4。
- 清单：[FEEL12-TEXT-INVENTORY.md](FEEL12-TEXT-INVENTORY.md) / [feel12-text-inventory.csv](feel12-text-inventory.csv) / `core-feel-12-text.json`。
- 角色称呼：玩家可见值中 `兔子/乌龟/RABBIT/TURTLE` 扫描为 0；统一 TUBO/BITT；故事/教学用 TUBO/BITT；大表哥只在开场/教学/结尾。
- 术语：`BRO METER`（失误槽）、`BRO COMBO`（连招/默契）、`SHIFT 换人`；旧“换手/交给”清理。
- 旧 SPACE/Water Pop：`prompt.pop`、`action.water_pop` 等标为仅开发/不使用；正式 SPACE 改为 TUBO 护盾/BITT 主动救援。
- 主菜单文案：“兄弟俩，准备好接受训练了吗？”+ 开始游戏/设置/退出；移除最佳纪录面板、阶段/区域/调试说明。
- 硬编码扫描：`producer_menu`、P0-C 测试提示、`race.gd` 的 BRO DIVE/OLLIE 等仍是内部/调试文本，不进入正式菜单；未删除 QA 场景。
- 键帽：`prompt.*` 保留 ↑/↓/SHIFT，`hud.gd` 键帽识别回归通过（`stage4_bilingual`、`stage4_menu_input`）。

## 4. HUD：三颗氧气气泡

- `race._draw_oxygen_bubbles()`：按 `oxygen / OXYGEN_MAX` 归一化：
  - >0.66：3 颗；>0.33：2 颗；>0.01：1 颗（橙红闪烁）；0：3 个空轮廓。
- 跟随 TUBO 世界坐标（`rabbit.position + (0,-62)`），移动/跳跃/落水/回壳都跟随。
- 左下角 `oxygen_label` / `oxygen_status` / 氧气条已删除；左下只保留食物加速状态，没食物时整块面板隐藏。
- 截图：`feel12/oxygen-full.png`、`oxygen-mid.png`、`oxygen-low.png`、`oxygen-empty.png`。
- 未验证：1920×1080 实际窗口；世界坐标气泡随相机缩放，未做屏幕空间恒定字号。

## 5. 教学

- 4 步：TUBO 跳/趴 → SHIFT 到 BITT 跃/潜 → 第一次电流接力 → 自己过组合。
- 状态表：

| 步 | 进入 | 提示 | 完成条件 | 失败 | 下一步 |
|---|---|---|---|---|---|
| 1 | x≥0 | TUBO ↑/↓/SPACE | `_jumped && _crouched` 且 x≥2700 | 900 px 超时放行 + 失败句 | 2 |
| 2 | x≥2700 | SHIFT BITT ↑/↓/SPACE | `_leaped && _dived` 且 x≥4800 | 同上 | 3 |
| 3 | x≥4800 | ↑→SHIFT→↓ | `_relay_seen` 且 x≥7100 | 同上 | 4 |
| 4 | x≥7100 | 自己来 | x≥13200 | 无（只提示） | 结束→正式比赛 |

- `_set_step` 同一逻辑帧清空 `GameManager.prompt/hint` 并设置新文案；`race.test_no_lessons=true`，避免旧 55 组教学抢字；不再依赖旧 Timer 回调。
- 截图：`feel12/tutorial-step1.png` / `tutorial-step3.png`。
- 已补 `stage12_tutorial_state` **4/4 PASS**：step2 立即替换 step1、提前 leap/dive 进入 step3、无旧提示回写（`core-feel-12-tutorial.json`）。
- **未完成**：失败/重开/跳过的真人流程仍未逐条试玩。

## 6. 终点与结尾

- `result.gd` 现在画出 TUBO/BITT/大表哥，不再只有评分表。
- 大表哥台词按 S/A/B/C/D；TUBO/BITT 反应按 S/B/D fallback；结算只保留比赛时间/失误/干净通过/BRO COMBO 四行，其他统计退出。
- 截图：`screenshots/feel12-result-S.png`、`feel12-result-B.png`、`feel12-result-D.png`。
- Retry/返回主菜单沿用原按钮和快捷键。
- 未完成：没有真人完整通关录屏；结尾动作仍是原生形状，未接 ComfyUI 素材。

## 7. 菜单

- 正式主菜单只有 **开始游戏 / 设置 / 退出**；无最佳纪录/阶段/区域/调试/制作人入口。
- 截图：`screenshots/feel12-main-menu.png`。
- 设置页只有语言/返回；制作人测试场景仍保留在项目内部（`producer_menu.tscn`），没有玩家入口。
- `stage4_menu_input` 窗口化 PASS。

## 8. 回归结果

### 代码/自动化

- `stage12_overdrive`：**15/15 PASS**（`core-feel-12-overdrive.json`）。
- `stage12_tutorial_state`：**4/4 PASS**。
- `stage12_skills`：**8/8 PASS**（`core-feel-12-skills.json`）：护盾精准/普通/非万能/换手，BITT 前后主动接近、安全时不触发；**完整接住成功未验证**。
- `stage11_shift_relay`：10/10 PASS；`stage11_story_flow`：4/4 PASS。
- `stage8_hz_regression`：PASS（30/60/120）。
- `stage4_bilingual`：PASS；`stage4_flow`：PASS；`stage4_menu_input`（窗口化）：PASS；`stage4_bro_meter`：PASS；`stage10_joint_semantics`：10/10 PASS；`stage10_drift_burst`：2/2（只保留阶段延迟）。
- 氧气截图 4 张；主菜单/结算截图；护盾/救援/过载截图。
- **55 组全量 audit**：本轮未跑完（最后停在 g=11；不是 FAIL，是没有结论）。
- **55 组 playtest**：run1 **55/55、0 事故、0 接触**，结算四行断言全部通过（score 12610、S）；run2 在 66.8 s 被手动停止用于收尾，**不算第二圈通过**。
- 结论：**不能声明 55/55 全量回归通过**；普通路线有一个 55/55 单圈证据 + Retry 启动，但没有两圈 + 全量 audit。
- 55 组设计表：[FEEL12-55-GROUPS.md](FEEL12-55-GROUPS.md) / `feel12-55-groups.csv`；指标：
  - 最大连续同节奏 2；最大连续同主角色 2；
  - 双角色 12、动态 18、护盾机会 30、救援机会 6、缓冲 10；
  - 任意连续 5 组 ≥3 种节奏：51/51。
  - **注意**：这是对现有 55 组顺序/间隔的分类与技能机会标注；没有重新移动障碍位置或新增障碍。物理节奏仍是原 55 组，不能仅凭标签说“节奏已重构完成”。

### 实际运行/人工

- 窗口化截图见各节；没有真人 30 分钟试玩。
- 未完成：ComfyUI 独立拆件、Godot 部件组装动画、完整接住成功、55 组逐组真人验证、1920×1080 氧气气泡、结尾真人流程。

## 9. 本轮总结

- 已完成并接入：BRO OVERDRIVE（无慢镜头、TUBO 弹簧/BITT 旋壳、真实动作）、TUBO 胡萝卜护盾、BITT 主动接近救援（移动验证）、TUBO/BITT 统一文本、氧气三气泡、主菜单三按钮、教学步骤即时更新、结尾大表哥。
- 未完成：ComfyUI 独立部件/骨骼动画、完整救援接住、55 组逐组全量验证/真正几何节奏重构。
- 需制作人试玩：护盾精准窗口、BITT 主动救援路径、OVERDRIVE 触发是否可读、55 组是否仍单调。
- **未达到内容冻结条件**；Stage 4 保持，不推进 Stage 5，不宣称趣味性通过。
- QC：10 条中 8 条 pass；第 8 条（55 组全量 audit/几何节奏）与第 9 条（两圈完整回归）为 FAIL，不能把本轮描述为完成。
- `best.json` 开工备份 `_attic/2026-11-14/feel12-baseline/best.json`，MD5 `067DEB9A71A19C2F6F9F6DC41FEABF09`；测试后需复核并还原。
