# RESUME — TBB-LONGRUN-PLAYABILITY-01 / -02 / TBB-EXPERIENCE-REBUILD-05

> **当前任务（2026-11-13 13:40 起）**：`TBB-EXPERIENCE-REFINE-06`。
> 制作人原文在 `MISSION-REFINE-06-SUPPLEMENT.md`：动态平衡是核心 SHIFT 机制，
> 保留压力/不取消失控；P1 状态 HUD 要明确角色归属与当前控制。
> 进度：P0（乌龟实心碰撞/联合判罚）已完成并留证，见 `REFINE-06-P0.md`；
> 下一步 P1，然后 P2–P6。`STAGE=4` 不变。
>
> 以下是上一轮 `TBB-EXPERIENCE-REBUILD-05` 的记录，保留作背景：
> **上一轮任务（2026-11-13）**：`TBB-EXPERIENCE-REBUILD-05`，截止 2026-11-13 10:00 UTC+8。
> 先读 `MISSION-05.md` 与 `LONGRUN_STATE.md` 顶部进度清单，从第一个未勾选项继续。
> 进度（08:56，收尾完成）：A–H 与 G2–G21 全部完成，交付报告 `TBB-EXPERIENCE-REBUILD-05.md` 已定稿；
> G2–G11（松手提示、擦水原因、成功弹跳、接人弹跳、动态首次提示、「好接！」、
> 接人提示环、壳下沉、教学先来后到、取证修复）、G12–G17（暂停面板、结算页
> 「亲手喂到」与「下次试试」等）、G18（救援探针两个洞）、G19（撞错角色时提示换人）、
> G20（20 个探针补清 `hit_roles`，改正三处假绿）、G21（撞过的障碍类型下一组再教）
> 均已实现并验证：两圈 `fullrun-g21.log` 272.9/272.8 s、9770、S、55/55、0 事故，
> 关键行与 `fullrun-g20.log` diff 为空；24 场景批量全绿；窗口化
> `stage4_hud_score` 44/44、`stage4_menu_input` PASS；`best.json` md5 未变。
> 08:52 收尾已完成：`fullrun-final.log` 与 g21 关键行 diff 为空、25 场景批量全绿、
> 窗口化 HUD 44/44 + 菜单 PASS、`best.json` md5 未变，报告已定稿（§11 列八条未完成项）。
> 12:32 G22 按制作人“把可优化的部分优化完”续做三项：补教封顶（每类首次 + 一次）、
> log5 浪涌（动态 14/55）、`load_level()` 归零 `hazard_clock`；`fullrun-g22.log`
> 272.9/272.8、9770、S、55/55、0 事故，26 场景全绿，窗口化 44/44 + 菜单 PASS，
> `best.json` md5 未变，`STAGE=4`。见 `REBUILD05-G22.md`。
> 下一步是制作人真人质检；不要自行开新机制。
> QC：22 份 `tbb-exp05-*` 记录，G22 起全部复核 ALL PASS（`tbb-exp05-g22-polish` 7/7）。
> 边界：不加美术/音效、SHIFT 音效保持关闭、不覆盖 best.json、不重构 race.gd、不进 STAGE 5。

把这个文件的内容直接交给新的 Claude 会话即可续跑。

---

你在 `D:/GAMESTUDIO/TURBBIT` 继续执行 `TBB-LONGRUN-PLAYABILITY-01` 与追加的
`TBB-LONGRUN-PLAYABILITY-02`。

先做这四件事，不要跳过：

1. 读 `docs/reports/longrun/LONGRUN_STATE.md`、`MISSION.md`、`MISSION-02.md`。
2. 检查 `docs/reports/longrun/.lock`：
   - 若 PID 仍存活，说明另一轮还在跑，停止，不要并行修改。
   - 若 PID 已死，记录“stale lock”，删除后继续。
3. 检查 `git -C D:/GAMESTUDIO status --short -- TURBBIT`。注意 TURBBIT 未被 git 跟踪；
   回退只能取 `docs/reports/longrun/baseline-2026-11-12-P02.zip`（`-02` 开工基线）
   或更早的 `baseline-2026-11-12-0205.zip`。
4. 从状态文件的 `NEXT:` 一行继续；每完成一个子任务立即更新
   `LONGRUN_STATE.md`（`STATUS:` / `LAST_UPDATED:` / `NEXT:` 三行保持可解析）。

硬约束：

- 保持 `STAGE=4`，禁止进入 STAGE 5；本轮不宣布最终完成。
- 不跑 `LESSONS/CHECKS/preflight.py`。
- 素材冻结：不加图片/字体/音效/音乐；反馈用现有占位或原生 Control。
- 自动测试不得写成真人试玩；自动化、自动驾驶、代理驾驶、窗口化自动输入分开标注；
  真人反馈单独记录在 `PRODUCER-PLAYTEST-NOTES.md`。
- 任何会冲线的测试前备份 `best.json`，测试后校验并还原；不得把测试成绩写成玩家纪录。
- 一次只改一个系统；改完窗口化实跑 + 相关回归 + 记录前后差异。
- 连续失败就回退到基线/稳定版，记录失败原因，不硬推。
- 本机 OS 级键盘注入被系统拒绝（`SendInput` 返回 0），只能用引擎内输入代理；
  不得写成“真人试玩”或“窗口化真实按键”。

## 当前状态（2026-11-12 19:11）

`-02` 的 §七 11 步全部完成：
- 1 恢复点、2 0.154 s 解释、3 食物加速、4 随机池与种子、5 三区遭遇、
  6 公平碰撞/预警、7 主动救援、8 难度曲线、9 HUD/评分、
  10 完整赛道回归、11 状态与验收入口。
- 报告依次见 `PHASE-N-0154.md`、`PHASE-O-SNACK.md`、`PHASE-P-DRAW.md`、
  `PHASE-P-ZONES.md`、`PHASE-Q-FAIRNESS.md`、`PHASE-R-RESCUE.md`、
  `PHASE-S-DIFFICULTY-CURVE.md`、`PHASE-T-HUD-SCORE.md`、`PHASE-U-FULL-RUN.md`。
- 最新完整回归（2026-11-12 22:40，`TBB-SHIFT-CORE-02` 后）：中英文各两圈
  55/55、0 事故、S、三区、`failures=0`，stdout 47 ok / stderr 0 行；
  `best.json` md5 `c322f9a20321c5b618f98db7e4120969` 前后一致。
- 制作人验收入口：`PRODUCER-ACCEPTANCE.md`。

### TBB-SHIFT-CORE-02（已完成待复核）

- 报告：`PHASE-SHIFT-CORE.md`；任务原文：`MISSION-SHIFT-02.md`；
  QC：`tbb-shift-core-02`（14 条）。
- BRO 神游四态、海鸟四路线、BRO DIVE 窗口（Z1 0.15→0.30 s）、
  兔子真实落水坐标 + 下潜接人、开场/暂停设计稿全部落地。
- `game_manager.gd` 新增 `shift_shocked(from,to)` 事件接口（无视觉、无延迟）。
- 制作人已试玩（自述 3–4 次；2026-11-11 意见与逐条处置见
  `PRODUCER-PLAYTEST-NOTES.md`），本轮新机制未获新的真人验证；STAGE=4。

### TBB-SHIFT-FEEL-03（Phase V，已完成待复核）

- 报告 `PHASE-V-FEEL.md`；QC `tbb-shift-feel-03` 17 条全 PASS。
- 七项：SHIFT 电击表现、输入宽容（120/100 ms，含前后对照）、伙伴自主与后果、
  Z1 开场节奏（5.15 / 9.45 / 15.00 / 26.10 s）、碰撞/动作反馈（hitstop 50/90 ms、
  震动 2.5/6.5 px）、Z3 5 s 预警、6 s 可跳过开场 + `Take a breath, bro.` 暂停页。
- 回归：中文两圈 PASS（272.8/272.7 s、S、55/55、0 事故）、30/60/120 Hz PASS、
  `stage4_hud_score` 44 项 PASS、正式组 55 + 调试组 7；`best.json` md5 前后一致。
- 美术/音效冻结；新增 UI 全是原生 Control；未做新的美术或音频。
- 本轮新手感尚未经过真人试玩。

## 下一轮第一件事

**把 Phase V 交付给制作人复核**：先让他实际跑一遍新手感
（撞低岩的停顿/震动、Z3 右缘预警、6 s 开场与暂停页），再决定是否调参。
Z1 前 35 s 空跑问题已由 P1-4 改掉，不需要再改；若制作人觉得 Z3 预警过易，
优先调预警距离/图标信息量，而不是取消预警。
（另外：神游偏移会让兔子在低梁尾巴多探出最多 29 px，趴下松手过早会刮到；
是否加“趴下时禁用偏移”留给制作人决策。）

## 仍未验证

- 真人结构化验收：未完成。制作人已试玩并留过意见，但 Phase V 新增的
  hitstop / 镜头震动 / Z3 预警 / 开场暂停没有逐条真人判定（自动证据不能代替）。
- Z3 预警实测 lead 4.95–4.97 s（1300 px），预警是否让 Z3 过易待制作人判断。
- Z3 连招占比 20.8% 是否达到“组合判断”目标，待制作人判断。
