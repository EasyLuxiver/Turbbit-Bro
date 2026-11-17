# TBB-FEEL-17 体验闭环与整合推进

- 日期：2026-11-14
- 阶段：`STAGE=4`
- 目标：解决 FEEL-16 遗留问题，提升 MISCHIEF 可读性，推进美术/音频任务与正式交付可靠性。
- 结论：**P0 氧气闭环、P1 MISCHIEF 可读性已完成并接入正式比赛；P2 美术/音频任务已拆单，但没有素材可接入，仍在等待团队交付。最终候选包已生成；不宣布内容冻结或游戏完成。**

## 1. P0：氧气失败机制闭环

### 修改前

- 氧气上限 8.0 s；自动恢复从落水 3.2 s 后开始，实测 **4.58 s** 完成。
- 自动恢复无条件触发，因此从满氧状态几乎不可能走到氧气耗尽失败。

### 修改后（正式流程）

1. **主动救援最快**：真实 `SPACE` 接近/接住/抬回，约 1–2 s；测试 `active_rescue_fastest` 到 RIDING。
2. **自动恢复是最后兜底**：3.2 s 后，只有同时满足：
   - BITT 与 TUBO 距离 ≤ `AUTO_RESCUE_RANGE=850 px`；
   - 氧气 > 0；
   - 本轮没有被高优先级事件禁用自动回壳；
   
   才启动。否则 `_rescue_auto_blocked()` 报“BITT 太远，自动回壳失败”，保持 `RESCUE_ACTIVE`，玩家仍可按 SPACE，氧气继续消耗。
3. **氧气优先于未完成自动回壳**：
   - 氧气在 `RESCUE_ACTIVE / RESCUING(rescue_return) / CARRYING(rescue_return)` 都继续消耗；
   - `_update_oxygen` 移到抬回/接人之前结算；
   - 抬回最后一帧若氧气为 0，`_tick_carry` 直接 `finish_failure`，不会先变 RIDING。
4. **高优先级中断**：
   - 自动抬升途中 BITT 撞到真实障碍（`_turtle_contact`）→ `_cancel_auto_return()`：清 carry、回到 `RESCUE_ACTIVE`、`rescue_auto_disabled=true`，本轮不再自动续命；玩家仍可 SPACE。
   - 不会卡在半个抬升；状态可继续被 SPACE 接住，或氧气耗尽失败。
5. 失败场景/文案保持 **“我弄丢了我的兄弟”**。

### 验证（`stage17_oxygen_closure`）

| 检查 | 结果 |
|---|---|
| 主动救援最快 | PASS（caught → RIDING） |
| 近距自动恢复成功 | PASS（auto → RIDING，4.58 s） |
| 远距自动恢复失败 | PASS（保持 RESCUE_ACTIVE，blocked=1.0） |
| 氧气真实耗尽 | PASS（FAILED / OXYGEN_OUT，oxygen=0） |
| 自动恢复同帧 vs 氧气 | PASS（氧气优先，FAILED，不进入 RIDING） |
| 30/60/120 Hz 自动恢复 | PASS（4.60 / 4.58 / 4.60 s） |
| 自动回壳被高优先级碰撞中断 | PASS（RESCUE_ACTIVE，disabled=true，可继续 SPACE） |

### 实际可达性

- 玩家正常不操作时：BITT 自动巡航约 704 px，仍在 850 px 内 → 自动恢复成功。
- 玩家把 BITT 潜深/拉远（或撞上真实障碍）→ 自动回壳不成立；氧气 8 s 耗尽 → 独立失败。
- 这不是改用测试数据造失败：`stage17_oxygen_closure` 通过正式 race 的 `_update_oxygen/_tick_recovery/_tick_carry` 推进到 `FAILED`。

## 2. P1：BRO MISCHIEF 可读性

### HUD

- 主控角色：保留原 `BRO METER {角色} n/3` 主条 + 三格。
- 未受控兄弟：新增**一行文字** `TUBO/BITT n/3`（不是第二条资源条、不加新节点类型）。
- 2/3：琥珀色 + `·` 预警。
- 3/3：红色 + `!`，并在事件开始时中心提示/反馈点名捣乱者。
- SHIFT 后主条和副行同一帧切换；不改变惩罚积累/清零/优先级。

### 验证（`stage17_mischief_readability`）

- `BITT 2/3 ·` 琥珀预警；
- `BITT 3/3 !` 红字；
- SHIFT 后 `BRO METER BITT 3/3 | TUBO 0/3`；
- 面板面积 5.711% ≤ 8%；
- 没有新增资源条节点。

### MISCHIEF 行为

- 仍为 FEEL-15 的单角色状态机：TELEGRAPH 0.45 / ACTION 0.70 / END 0.22，CD 1.8。
- BITT 电 TUBO、TUBO 拽绳减速；前摇/动作/结束反馈；SHIFT 当帧取消旧角色。
- `stage15_mischief` 13/13；`stage4_bro_meter` PASS。
- 仍需真人判断事件频率、前摇是否足够、1.8 s CD 是否合适。

## 3. P2：美术与音频整合

已按 FEEL-16 清单拆成可直接派单的任务：

- 美术：[FEEL-17-ART-TASKS.md](../../delivery/FEEL-17-ART-TASKS.md)
  - 19 个角色部件/状态、3 区域、9 类障碍外观、UI/菜单/失败/结算。
  - 每项含用途、状态映射、格式、pivot、接入位置、验收。
- 音频：[FEEL-17-AUDIO-TASKS.md](../../delivery/FEEL-17-AUDIO-TASKS.md)
  - 8 首 BGM（菜单/开场/教学/Z1/Z2/Z3/终点/失败）。
  - 22 个核心 SFX（SHIFT、跳/落、下潜/上浮、救援三段、自动回壳、氧气、碰撞、浮标、MISCHIEF、OVERDRIVE、SHOWTIME、终点、失败）。
  - UI/流程 5 个 SFX；格式/命名/音量/同帧验收。

**接入进度：0。** 当前项目没有正式美术/音频文件；`art_test/feel13` 只是技术样，不接正式比赛，不标最终。OS 负责资源到位后的接入与验证，不代替团队制作最终素材。

## 4. P2：正式交付可靠性

### 干净目录

- 只把 `build/FEEL-17/TurbbitBro.exe` 复制到 `D:\GAMESTUDIO\_feel17_clean\`（无 `project.godot`、无脚本、无 `.godot`）。
- `--headless --quit` 退出 0。
- `--headless -- --autoplay` 实际加载 race 场景，输出食物抽签，无脚本/资源错误。
- 结论：不依赖本机项目文件；仍是同一台机器/同一 Windows 用户目录，未做另一台机器验证。

### 显示 / UI

- 1920×1080 与全屏菜单/HUD/氧气截图；
- `stage4_hud_layout` 1920 PASS；HUD 面板面积 5.711%；
- 双语气泡/提示 PASS；`stage4_bilingual` PASS；
- 菜单输入/暂停/Retry：`stage4_menu_input`、`stage4_flow` PASS。

### 成绩与重开

- 两圈：55/55、0 事故；Retry 从结算进入第二圈。
- 失败：FAILED → fail.tscn → R → race。
- `best.json` MD5 前后一致：`067DEB9A71A19C2F6F9F6DC41FEABF09`；没有自动成绩覆盖。

### 性能/异常

- `stage8_hz_regression` PASS（30/60/120）。
- 两圈无 stuck、max_accident=0、failures=0。
- 未做独立 GPU/长时间性能基准；只确认正式场景无资源/脚本错误和 HUD 每帧更新量很小。

## 5. 现有回归

- `stage17_oxygen_closure`：10/10。
- `stage17_mischief_readability`：6/6。
- `stage13_catch_matrix`：11/11。
- `stage12_skills`：9/9。
- `stage15_oxygen_fail`：9/9；`stage15_fail_flow`：3/3。
- `stage15_mischief`：13/13；`stage15_showtime_shift`：9/9。
- `stage4_bro_meter`：PASS。
- `stage12_overdrive`：15/15；`stage11_shift_relay`：10/10；`stage8_hz_regression`：PASS。
- `stage4_hud_layout` 1920 PASS；`stage4_hud_score` 41 checks PASS。
- 两圈 `STAGE3 PLAYTEST: PASS`（55/55、0 事故）。
- 菜单/流程/双语 PASS。

## 6. 尚未解决

1. **真人趣味性**：自动跑圈、自动测试不能证明好玩；需制作人试玩 SHIFT/MISCHIEF/救援/终点。
2. **正式美术**：0 接入；当前仍是原生图形占位。
3. **正式音频**：0 接入；当前完全静音。
4. **干净机器**：只在同机空目录验证，未在另一台机器/新用户目录验证。
5. **氧气数值手感**：自动 4.58 s、氧气 8 s、850 px 范围是当前最小改动方案；制作人可能觉得自动兜底太容易或太难。
6. **MISCHIEF 频率/前摇**：HUD 可读性已提升，仍需真人确认是否“可预判、可应对”。
7. **结果页标题**仍为“训练完成”，是否改成“抵达终点”由制作人定。

## 7. 最终候选包

- 路径：`build/FEEL-17/TurbbitBro.exe`
- 大小：约 106 MiB
- SHA-256：`7348a774b2128ccb2d5df3abd14522303cff1af66fbc110dd8a9584be2bb5460`
- 干净目录验证：`D:\GAMESTUDIO\_feel17_clean\TurbbitBro.exe`（只此一个文件）

**停止自主开发，等待制作人最终验收。不宣布内容冻结，不自行宣布游戏完成。**
