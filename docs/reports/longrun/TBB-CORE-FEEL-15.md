# TBB-CORE-FEEL-15 核心体验修正（修订版）

- 日期：2026-11-14
- 阶段：`STAGE=4`
- 范围：制作人试玩反馈后的定向修改；保留固定赛道、55 组障碍、现有区域和角色基础动作。
- 结论：**第 1–7 项均已接入正式比赛；自动化、截图和 GIF 已产出。仍需制作人实际试玩，不能把自动化结果表述为趣味性通过。**

## 1. SHOWTIME 与 SHIFT

### 已接入

- `GameManager.toggle_control()` 不再在 `showtime_active` 时拒绝 SHIFT。
- `race._unhandled_input` 不再把 SHOWTIME 期间的 SHIFT 当作“中断表演”。
- SHOWTIME 仍由 TUBO 自主完成；玩家可多次 SHIFT，控制对象切换，TUBO 的 `SHOWTIME` 状态和旋转继续。
- 高优先级事故仍由 `_trigger_accident` 结束表演（原有逻辑保留）。

### 证据

- `stage15_showtime_shift`：9 项检查全部通过。
  - 4 次连续 SHIFT 后 `showtime_active=true`，TUBO 仍 `SHOWTIME`。
  - SHIFT 到 BITT 后 `current_control=turtle`，表演继续。
  - 完整结束后 `rabbit=RIDING, mount=RIDING`，控制权留在玩家最后选择的角色。
- 截图：`docs/reports/longrun/feel15/showtime-shift-bitt.png`、`showtime-complete.png`。
- 记录：`core-feel-15-showtime.json`。

## 2. 红白浮标与木质动态障碍

### 已接入

- 红白浮标（`identity=buoy`）、木质吊装货箱（`dock_crate`）、漂流货箱（`drift_crate`）以及所有带 `motion` 的 `SURFACE_ROCK`：
  - TUBO 仍可起跳越过。
  - 当 `hazard_rect_live()` 与 BITT 壳的判定框真实相交时，触发 `_turtle_dynamic_bump()`：
    - 90 ms 表现停顿 + 震动；
    - 壳速 ×0.82；
    - 顶部一句 `BITT 撞上浮标/木箱！` 和提示 `等它落下或跃起`。
- 不把它升级成事故、不扣 BRO 格、不吞“干净通过”：这是“碰撞/减速/节奏损失”，不是第二套惩罚。
- 静态岩仍让壳从下方通过；只有动态实体做接触反馈。
- 判定和画法共用 `hazard_rect_live()`，不会“画着撞、判定没发生”。

### 证据

- `stage15_dynamic_buoy`：6 项检查全部通过。
  - 浮标浪峰：`bumped=true, visual_overlap=true, speed 240→196.8`。
  - 浮标浪谷：`bumped=false, visual_overlap=false`。
  - 木质吊箱浪峰：`bumped=true`，同样减速。
  - 静态岩：不误伤 BITT。
- 截图：`feel15/buoy-tubo-jump.png`（TUBO 跳）、`feel15/buoy-bitt-hit.png`（BITT 接触反馈）。
- 记录：`core-feel-15-dynamic-buoy.json`。

## 3. 正式移除 TUBO 胡萝卜护盾

### 已接入

- `_try_role_skill()` 里 TUBO 的 SPACE 分支直接返回，不再建立护盾窗口、不再判定、不再给分。
- `_check_hazards()` 删除护盾挡碰撞分支。
- `_draw_guard_and_catch()` 删除护盾绘制，只保留 BITT 救援连线。
- 教学 step1 提示改为：`TUBO：↑ 跳 / ↓ 趴低`。
- 暂停帮助改为：`SPACE：BITT 主动救援落水的 TUBO`。
- HUD 底部键帽本来就只有 SHIFT/↑/↓，没有 SPACE 护盾提示。
- 正式按键：SHIFT 换人，↑ 跳/跃起，↓ 蹲伏/下潜，SPACE 仅 BITT 主动救援。

### 验证

- `stage12_skills`：**9/9 PASS**；其中护盾四项已改为验证“SPACE 不建立窗口、不得分、不能挡任何障碍、不影响 SHIFT”。
- `stage12_overdrive` 15/15；`stage11_shift_relay` 10/10；确认 OVERDRIVE、SHIFT、BRO COMBO 不依赖护盾逻辑。
- 旧的 guard 文案键仍留在 Locale 作为未使用文本，但没有任何正式 HUD/教学/判定路径引用；没有误删无关资源。

## 4. BITT 主动救援与自动恢复

### 主动救援

沿用并重新回归：TUBO 落水 → SHIFT 到 BITT → SPACE → BITT 实际朝 TUBO 移动 → 接住 → `_begin_carry("rescue")` 抬回壳上 → `RIDING`。

`stage13_catch_matrix` **11/11 PASS**：前方/后方、远距、浅水/深水/水下、水面开始、障碍路径、窗口将尽、30/60/120 Hz、TUBO 安全。最大单帧位移 27.1 px，无传送。证据：`core-feel-13-catch-matrix.json`、`feel13/bro-catch-chain.gif`。

### 自动恢复

- 新增 `_rescue_auto()`：不按 SPACE 时，救援窗口 3.2 s 结束后：
  - `accident_flash` 闪白 + 震动；
  - `feedback.rescue_auto`：“水流把 TUBO 推回壳上了……下次按 SPACE 更快”；
  - 进入 `RESCUING` → 连续抬回 → `RIDING`。
- 实测自动恢复 **4.58 s**（3.2 s 等待 + 0.8 s 回壳 + 抬升），主动接住约 1–2 s；自动明显更慢。
- 氧气上限 8.0 s，自动恢复在耗尽前完成；氧气耗尽仍是独立失败条件。
- 不瞬移：自动恢复走 `_begin_carry` 的连续抬升。

## 5. 氧气 UI 与失败机制

### 已接入

- 正常骑乘：`oxygen_bubbles_visible()=false`，氧气回满，气泡隐藏。
- TUBO 落水进入 `RESCUE_FALLING/RESCUE_ACTIVE`：显示 TUBO 头顶三颗气泡；`_update_oxygen` 按水下时间消耗。
- 主动救援/自动恢复后：`mount` 离开水下状态，气泡立即隐藏，氧气恢复到至少 5.0。
- 氧气耗尽：`GameManager.finish_failure("OXYGEN_OUT")`，进入独立 `fail.tscn`；不进入普通结算、不写 best。
- 失败画面文案：**“我弄丢了我的兄弟”**，深水气泡 + 下沉 TUBO + 够不着的 BITT，按钮“再来一次 / 主菜单”，R/Enter 重开。

### 证据

- 正常骑乘/水下截图：`feel15/oxygen-riding-hidden.png`、`oxygen-underwater-visible.png`。
- 1920×1080：`oxygen-1920-full/mid/low/empty.png`；全屏：`*-fullscreen.png`；`OXYGEN 1920: PASS`。
- 失败画面：`screenshots/feel15-fail-1920.png`。
- 测试：`stage15_oxygen_fail` 9/9；`stage15_fail_flow` 3/3（FAILED → fail.tscn → R → race.tscn）。
- 记录：`core-feel-15-oxygen.json`、`core-feel-15-fail-flow.json`。

## 6. BRO MISCHIEF

### 状态与优先级

新增单角色事件状态机（`race.gd`）：

```
IDLE
  → 未受控角色惩罚条满
TELEGRAPH 0.45 s（清楚前摇：大字/反馈，不施加干扰）
  → ACTION 0.70 s（只施加一次真实后果）
  → END 0.22 s
  → IDLE（惩罚条 reset，CD 1.8 s）
```

- 两个角色各自有内部 `bro_meter_role = {rabbit, turtle}`（0–3）；HUD 显示当前主控角色的那一条（`BRO METER TUBO 0/3` / `BRO METER BITT 0/3`），SHIFT 时同步切换。
- 满格只标记该角色；**只有它当前未被玩家控制时才启动**。当前主控满格不会自己发疯，等 SHIFT 后由它接管。
- BITT 干扰 TUBO：电击 → TUBO 失衡 + 横向轻推 + 电弧视觉；不锁跳跃/下潜/SHIFT。
- TUBO 干扰 BITT：拽绳 → 壳失衡 + 速度 ×0.80 + 绳/勒颈视觉；不锁输入。
- 失控期间该角色 `mischief_lock_role` 生效：失误仍扣分/计事故，但**不再给它的惩罚条充能**。
- 事件完成：`reset_role_meter` 明确清零，不是缓慢自然恢复。
- SHIFT：**当帧**取消旧角色的动作/牵引/电击；如果新未受控角色已满格，立即由它接管（冷却清零）。不会出现双角色同时干扰。
- 救援优先级：`_rescue_context() != NONE` / TUBO 落水 / SHOWTIME 立即取消 MISCHIEF；BITT 切过来按 SPACE 可正常接住。
- 每次 SHIFT 重新判定；旧角色不会残留失控。

### 证据

- `stage15_mischief` **13/13 PASS**：双向、SHIFT 前摇中断、动作中中断、新角色接管、救援优先级、SPACE 接住、单角色、30/120 Hz、惩罚条 reset。
- 截图：`feel15/mischief-shock.png`（BITT 电 TUBO）、`mischief-tug.png`（TUBO 拽 BITT）、`mischief-shift-cancel.png`（中断后无残留）。
- GIF：`feel15/mischief-both.gif`（76 帧，双向干扰）。
- 记录：`core-feel-15-mischief.json`、`core-feel-15-mischief-capture.json`。
- `stage4_bro_meter` 已按新语义更新并通过：满格 → 标记角色；SHIFT 到另一角色后，未受控满格角色启动 MISCHIEF；完成 reset。

## 7. 终点剧情

- `result.gd` 背景改为明亮海岸 + 终点木台 + 彩旗 + 太阳。
- 大表哥在画面右侧等待，**手举绿色解药瓶**（`_draw_potion`）。
- TUBO/BITT 在画面左侧到达；保留 S/A/B/C/D 评价、时间/失误/干净通过/BRO COMBO 与最佳纪录。
- 大表哥台词与 TUBO/BITT 反应继续由 `result.cousin_*` / `result.tubo_*` / `result.bitt_*` 驱动。
- 截图：`screenshots/feel15-result-B-1920.png`。

## 8. 回归结果

| 项目 | 结果 |
|---|---|
| 两圈完整自动跑圈 | run1 **55/55、0 事故**；run2 Retry **55/55、0 事故**；PASS |
| SHOWTIME + SHIFT | `stage15_showtime_shift` 9/9 |
| 动态浮标/木箱 | `stage15_dynamic_buoy` 6/6 |
| 主动救援 | `stage13_catch_matrix` 11/11 |
| 自动恢复/氧气/失败 | `stage15_oxygen_fail` 9/9；`stage15_fail_flow` 3/3 |
| 双向 MISCHIEF | `stage15_mischief` 13/13 |
| 护盾移除后的按键 | `stage12_skills` 9/9 |
| BRO METER 新语义 | `stage4_bro_meter` PASS |
| OVERDRIVE | 15/15 |
| SHIFT relay | 10/10 |
| 30/60/120 | `stage8_hz_regression` PASS；OVERDRIVE 与 MISCHIEF 含 Hz 用例 |
| HUD 布局 / 字号 / 结果 | `stage4_hud_layout` 1920 PASS；`stage4_hud_score` 41 checks PASS |
| 教学/菜单/Retry/流程 | `stage4_menu_input` 窗口化 PASS；`stage4_flow` PASS；`stage12_tutorial_state` 通过 |
| 1920 / 全屏氧气 | PASS |

两圈日志：`feel14/logs/_f14_playtest.log`（FEEL-14 基线）；本轮 `feel15/logs/_f15_playtest3.log` 结论相同：`run1/run2 55/55 accidents=0`。

## 9. best.json

- 开工备份：`_attic/2026-11-14/feel15-baseline/best.json`
- MD5：`067DEB9A71A19C2F6F9F6DC41FEABF09`
- 收工 MD5：`067DEB9A71A19C2F6F9F6DC41FEABF09`
- 内容仍为 `score=9870, time=239.796160000161`；自动跑圈写入的成绩已由 `_restore_best` 还原。

## 10. 修改文件

**正式比赛逻辑**

- `scripts/race.gd`
- `scripts/autoload/game_manager.gd`
- `scripts/autoload/locale.gd`
- `scripts/ui/hud.gd`
- `scripts/result.gd`
- `scripts/fail.gd`（新增）
- `scenes/fail.tscn`（新增）

**测试/取证**

- `scripts/test/stage12_skills.gd`（护盾移除后的回归）
- `scripts/test/stage4_bro_meter.gd`（新 MISCHIEF 语义）
- `scripts/test/stage4_hud_score.gd`（当前结果四行/键帽字号豁免）
- `scripts/test/stage13_oxygen_1920.gd`（水下气泡）
- `scripts/test/stage15_showtime_shift.gd` + scene
- `scripts/test/stage15_dynamic_buoy.gd` + scene
- `scripts/test/stage15_oxygen_fail.gd` + scene
- `scripts/test/stage15_fail_flow.gd` + scene
- `scripts/test/stage15_mischief.gd` + scene
- `scripts/test/stage15_showtime_capture.gd` + scene
- `scripts/test/stage15_buoy_capture.gd` + scene
- `scripts/test/stage15_oxygen_capture.gd` + scene
- `scripts/test/stage15_mischief_capture.gd` + scene

**试玩包**

- `build/FEEL-15/TurbbitBro.exe`（Godot 4.7 Windows Desktop）
- SHA-256：`6f09350da73f93548b270b5bfda792b06b28ed3ca4561c9bf19e806505c20ba4`

## 11. 完成分类

- **已完成并接入正式比赛**：SHOWTIME + SHIFT、动态浮标/木箱接触反馈、护盾移除、主动救援与自动恢复、氧气与失败画面、双向 BRO MISCHIEF、终点剧情。
- **已完成但未接入**：无。
- **未完成**：真人试玩与趣味性判断；自动恢复/氧气时长的最终手感确认。
- **自动化验证**：见第 8 节；不能替代真人试玩。

## 11. 未完成 / 需制作人判断

- 仍需真人试玩 SHOWTIME + SHIFT 的手感、MISCHIEF 的频率与可读性、氧气/自动恢复的时长、浮标接触反馈是否足够、终点演出是否满意。
- 自动恢复 4.58 s、氧气上限 8.0 s 是先按现有配置测量的结果；若制作人觉得节奏不对，需要再定数值。
- 没有重写 `race.gd`，没有新增角色/按键/资源条/技能树/关卡/障碍类型。
- 自动化通过不等于趣味性通过；不宣布内容冻结。

**停止：等待制作人复测。**
