# FEEL-22 核心机制统一、旧逻辑清理与全流程 DEBUG

- 日期：2026-11-15
- 阶段：`STAGE=4`
- 模式：CONTROLLED_WRITE
- **未导出/打包/复制 EXE；未修改 best.json。**
- 不宣布游戏完成或内容冻结。

## 1. 本轮结论

把两套失控逻辑收敛成一条：**每个角色的三格惩罚条是唯一失控来源**。旧时间驱动神游、旧自动下潜、旧 OVERDRIVE 自动链、跨 SHIFT 输入继承均已停用。救援统一为「接触即接住，SPACE 只追近」。动态浮标/吊箱/漂流箱删除了无法用画面解释的水下碰撞段。海鸟特殊攻击暂时关闭，只保留普通俯冲；shark6 鲨群保留。

## 2. 旧逻辑清理

### 2.1 停用的时间驱动神游

`_physics_process()` 不再调用：

- `rabbit_brain.tick()` / `turtle_brain.tick()`
- `_tick_drift_feedback()`
- `_tick_drift_impair()`
- `_tick_drift_autonomy()`
- `_tubo_autodrift()`
- `_tick_dive_assist()`

同时：

- `rabbit.drift` / `turtle.drift` 每帧固定 0，HUD 旧神游行不会显示。
- `rabbit_controller` 的位置不再叠加 `drift_offset_px()/drift_bob_px()`，起跳 `air_scale=1.0`。
- `turtle_controller` 速度不再乘 `drift_speed_scale()`，目标深度不再加 `drift_bob_px()`。
- `_tick_overdrive()` 不再根据 brain 状态自动启动；旧“神游到 MISCHIEF → 自动弹簧/旋壳”链停用。
- `_turtle_refuse_t` / `_rabbit_refuse_t` / `_bitt_autocrouch_left` 不再参与输入或垂直运动。

### 2.2 惩罚条

保留 `BRO_METER_SLOTS = 3`，不增加资源条。

- 有效失误仍按角色 `bro_meter_role` +1。
- 0 格正常。
- 1 格：HUD 琥珀色，仅视觉提示，不改操作。
- 2 格：HUD 橙色，仅视觉提示，不改操作。
- 3 格：只有该角色**未受控**时才进入 MISCHIEF；SHIFT 到它可立即制止；救援优先级最高。

本轮没有在 1/2 格加入输入延迟或自动动作——任务书允许“无法可靠实现时优先只保留视觉反馈”，避免再造一套独立计时。

HUD 的两个 0/3 不是同一种东西：

- `TUBO 失误 0/3`：当前角色的失误/惩罚条，红色系；每格来自有效失误，满 3 且该角色未受控才会 MISCHIEF（电另一个兄弟/拽绳子）。
- `兄弟连击 0/3`：连续干净通过，金色系；每次事故/碰撞清零，满 3 触发一次 SHOWTIME（兄弟合拍）。

## 3. SHIFT 与输入

- `turtle_controller.standby_dive_t` 不再保留 0.55 s 下潜尾；切走当帧 `diving=false`，下潜只由当前受控 + 当前按住 ↓ 成立。
- `_tick_dive_assist()` 不再调用；BRO DIVE 不再因为靠近浮木自动接管下潜，必须自己按 ↓。
- SHIFT 时清空 `_buf_action`、`_buf_age`、`_buf_delay`、`_down_delay`；旧 ↑ 缓存不会交给新角色。
- 落地 `buffered_jump` 仍保留，但只在没有跨 SHIFT 的正常连续跳跃里生效。
- SHIFT 的旧控制权/救援/表演优先级保持原规则；已结算后 `finished` 守卫阻止再换人。

## 4. 救援规则

正式规则：

1. TUBO 落水，氧气显示并消耗。
2. SHIFT 到 BITT，正常下潜靠近。
3. 满足合法接触条件即自动接住，不要求 SPACE。
4. 够不到时按 SPACE 让 BITT 主动追近；追近后仍要满足接触条件。
5. 超时自动回壳已删除，不再与主动救援竞争。
6. 氧气归零仍走真实失败。

HUD/教学/暂停/结算提示同步为“下潜靠近，够不到按 SPACE 追”。

## 5. 动态障碍与海鸟/鲨鱼

- `buoy` rock3、`dock_crate` rock4/5/7、`drift_crate` rock8/9/10/11/12 共 9 组，删除 `ANTI_DIVE` 水下段；碰撞只保留画面上的主物体。
- 静止岩和低梁保留原反下潜段。
- 海鸟特殊攻击（poop/return/chase）关闭，只保留普通俯冲；原因：特殊攻击由独立纸片体判定，无法与本体动画统一。
- shark6 鲨群保留：单组、单攻击体、救援清空，9/9 专项通过。

## 6. 状态优先级与所有权

执行顺序基线（实际代码仍按依赖调用，不机械重排）：

| 优先级 | 状态 | 权威 |
|---|---|---|
| 1 | 失败/场景切换 | GameManager + `_update_oxygen` 当帧 return |
| 2 | 救援/氧气 | `mount.state`、`accident_state`、`GameManager.oxygen` |
| 3 | 控制权/SHIFT | `GameManager.current_control` |
| 4 | SHOWTIME | race `showtime_active`（GameManager 镜像） |
| 5 | MISCHIEF | race `_mischief_*` + 每角色惩罚条 |
| 6 | 动态攻击 | `_bird_attacks` / `_shark_attacks` |
| 7 | 普通碰撞 | `hit_groups` / `hit_roles` |
| 8 | HUD/表现 | 只读上面状态 |

清理规则：救援/落水清空鲨/鸟攻击；失败当帧停止后续模拟；SHIFT 清输入缓存和下潜尾；Retry 重新加载场景，旧攻击体/旧惩罚值/旧缓存不残留。

## 7. 教学与文本

- tutorial 不再在 13200 画假终点：`race.world_end = END_X + 4000`，终点标记移出画面。
- 结束时先显示 `tutorial.done`，等待 1.4 s 再进入正式比赛。
- `STEP 1 / 4` 已移除（空文本）。
- 教学底栏提示改为按“当前控制的是谁”实时切换：在 TUBO 上显示 TUBO 键，切到 BITT 后显示 BITT 键，不会一直教错角色。
- 文本替换：
  - `捣乱结束，惩罚条清零` → `行了行了，我不闹了。`
  - HUD 的 `过载 0/3` → `失误 0/3`
  - `未受控的 BITT 开始捣乱` → `BITT 等烦了，开始搞事！`
  - `表演时间 就绪` → `兄弟俩对上眼了`
  - `操控 BITT · SHIFT 中止` → `BITT 在演，SHIFT 换人`
  - `表演完成 +100 分` → `漂亮！这下配合上了！`
  - `好戏开场！` → `兄弟合拍！`
  - `表演结束！` → `漂亮，收工！`
- 救援/暂停/教学提示统一为“下潜靠近，够不到按 SPACE 追”。

## 8. 验证

实机 HUD 证据：`docs/reports/longrun/feel22/hud-unified-zh.png`

动态障碍证据：`dynamic-buoy-dip.png`、`dynamic-dock-crate.png`、`dynamic-drift-crate.png`（三种身份都只保留主物体；无独立深色判定块）

窗口教学证据：`docs/reports/longrun/feel22/tutorial-window.png`

| 项目 | 结果 |
|---|---|
| 55 组 solution audit（4 分片） | 全部 `AUDIT no_solution=[]` |
| 两圈自动驾驶 | 两圈 55/55；每圈 1 次擦碰（rock2），非无解 |
| 耦合矩阵 `stage22_coupling` | 19/19 |
| `stage4_flow` | PASS |
| `stage4_bilingual` | PASS |
| `stage4_hud_layout` | PASS |
| `stage4_hud_score` | 41/41 PASS |
| `stage4_opening_pause` | PASS |
| `stage5_c_hud` | PASS |
| `stage13_catch_matrix` | PASS |
| `stage15_oxygen_fail` | 8/8（自动回壳已删除） |
| `stage15_mischief` | 13/13 |
| `stage21_shark_pack` | 9/9（含 30/60/120） |
| `stage12_tutorial_state` | PASS |
| `stage13_tutorial_flow`（窗口化） | PASS（含结束跳过/过渡） |
| `stage4_collision_feedback` | PASS（Ollie no_contact/ollie_fx） |
| `best.json` MD5 | `067DEB9A71A19C2F6F9F6DC41FEABF09` 未变 |

已失效/不再适用的旧专项：

- `stage8_hz_regression`：断言旧神游延迟。
- `stage12_overdrive`：断言旧神游自动 OVERDRIVE。
- `stage19_bird_behavior`：断言已关闭的特殊鸟攻击。

这些测试没有作为本轮通过依据；对应旧行为已按任务书停用。

## 8.1 窗口内按键试跑（非真人）

用真实窗口启动游戏，通过 Windows 键盘注入走菜单 → 漫画 → 教学：

- 菜单 ENTER 进入；
- 漫画可跳过；
- 教学 overlay 正常出现，`STEP 1/4` 已消失；
- 教学提示会随当前控制角色更新；
- 未走到教学终点，未完成一次完整真人流程。

这是 OS 键盘注入的冒烟，不是“真人玩过”，仍不能替代制作人手感判断。

## 9. 未完成 / 风险

- **未进行真人操作验证**；手感、文本、救援是否自然需制作人试玩。
- 惩罚条 1/2 格目前只有颜色梯度，没有行为梯度（按任务书安全回退）。
- 海鸟特殊攻击已关闭；如果后续要恢复，必须先让本体动画和攻击判定同源。
- 两圈自动驾驶在 rock2 有一次擦碰，说明自动驾驶没有适配“取消自动下潜”；真人可正常按 ↓/跳，但需要试玩确认。
- 教学 headless 截图不可用；窗口化 `stage13_tutorial_flow` 已通过，仍需真人完整走一遍。
- `showtime_active` 仍有 race/GameManager 两处镜像，属 P2 技术债。

## 10. 停止

- 18:00 前停止代码写入。
- 未导出、未打包、未复制 EXE。
- 未修改 best.json。
- 不宣布完成，等待制作人试玩。
