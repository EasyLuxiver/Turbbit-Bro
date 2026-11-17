# FEEL-22 核心机制 DEBUG、耦合审计与体验一致性修复

- 日期：2026-11-15
- 阶段：`STAGE=4`
- 模式：CONTROLLED_WRITE
- **未导出测试包/候选包/EXE，未执行 Godot Export，未复制 EXE。**
- **未宣布内容冻结，未宣布游戏完成。**
- 真人操作：**未进行真人操作验证**；本报告中的难度/手感结论只来自引擎内探针与自动驾驶，不等同于真人试玩。

## 1. 结论

本批先统一玩家可见文本，再处理四个真实的状态耦合问题：

1. 氧气失败当帧继续跑碰撞/攻击/连击；
2. OVERDRIVE 预兆/冲刺会穿过事故、救援、SHOWTIME；
3. 鸟攻击在救援/落水时残留，恢复后可能凭空命中；
4. 自动回壳在氧不足回壳航程时仍先播“自动救援”，随后同段失败。

对应修复后，耦合矩阵 16/16；55 组解法审计四个分片均为 `no_solution=[]`；两圈自动驾驶仍为 55/55。文本侧删除了 `px`、`0/55 组`、`这不是普通结算`、`BRO METER/BRO COMBO/BRO DIVE` 等出戏/开发语言，并把硬编码在世界里的 `CURRENT / SAFE ABOVE / SAFE BELOW / 绞盘 ↑ / 网低 / 无解 / 720!` 收进 Locale。

## 2. 约束遵守

| 约束 | 结果 |
|---|---|
| 不导出/打包/复制 EXE | 未做 |
| 不改 best.json | 未读写；MD5 保持 `067DEB9A71A19C2F6F9F6DC41FEABF09` |
| 不大改 race.gd | 仅加状态优先级守卫、清理和少量绘制文本切换 |
| 不新增障碍/玩法/惩罚/角色/按键/资源条 | 未新增 |
| 不做美术/音频 | 未做 |
| 不用单条 PASS 代替组合测试 | 另建 16 条耦合矩阵 |
| 不用自动驾驶事故当真人难度证据 | 报告明确标注 |

## 3. 玩家可见文本统一

### 3.1 删除的开发/元语言

| 位置 | 修改前 | 修改后 |
|---|---|---|
| 失败页副标题 | `氧气耗尽 · 这不是普通结算` | `氧气见底了。\nBITT 没能把他捞回来。` |
| HUD 赛程 | `进度 42%   23/55 组` | `赛程 23/55` |
| HUD 待命 | `待命 · 稳定` | `待命` |
| HUD 操控 | `操控 · 骑乘` / `SHIFT 当前控制：TUBO` | `骑乘` / `操控 TUBO · SHIFT 换人` |
| HUD 走神后果 | `巡航 90% · 壳晃 18px`、`空中修正 55% · 身偏 12px` | `速度 90% · 壳在晃`、`空中修正 55% · 落点偏`；刚起步时统一说 `开始走神` |
| 失败提示 | `换人间隔 0.2 秒` | `刚换过人，稍等一下` |
| 结算标题 | `训练完成` | `训练结束`，并加 `大表哥把解药丢过来：喝了。下次别让我下水捞你们。` |
| 结算快捷键 | `R - 重开 M - 主菜单 Enter - 选中的按钮` | `R 再来一次    M 回主菜单    Enter 确认` |

### 3.2 中文里不再堆英文黑话

| 修改前 | 修改后 |
|---|---|
| `BRO METER TUBO 2/3` | `TUBO 过载 2/3` |
| `BRO COMBO 0/3` | `兄弟连击 0/3` |
| `BRO DIVE / BRO OLLIE` | `兄弟下潜 / 兄弟蹬墙` |
| `SHOWTIME！` / `SHOWTIME 3.2s 剩` | `好戏开场！` / `表演时间 3.2s` |
| `BITT TURBO！加速中` | `BITT 加速中！` |
| `触发 OVERDRIVE` | `按 SHIFT 换人，让他弹出去 / 旋出去` |
| `TUBO CARROT GUARD` 等旧护盾文本 | 删除 |

### 3.3 清理的死文本与旧机制文案

- 删除 `SPACE WATER POP / 拍水跃浪`、`state.POPPING`、`prompt.pop`、`feedback.pop`。
- 删除旧 `WIDE WAVE / 宽浪`、`lesson.wave`。
- 删除 `TUBO 胡萝卜护盾`、`prompt.guard`、`feedback.guard_ready`。
- 删除旧救援 `按住 ↓ 接住` 说法；`prompt.rescue_*`、`result.try_rescue` 统一为 `SPACE 去救`。
- 删除不再显示的旧结算键：`result.snacks/showtime/streak/rescues/joint/casualties/engine/accidents`。
- 删除未使用的 `hud.air/clean/clean_best/brotherhood/warn`。
- 删除重复的旧 `feedback.burst_*`（实际走 `feedback.od_*`）。

### 3.4 世界内硬编码文字收进 Locale

| 位置 | 修改前 | 修改后 |
|---|---|---|
| 浮木上下安全区 | `SAFE ABOVE` / `SAFE BELOW` | `跳上面` / `潜下面` |
| 强水流 | `CURRENT` | `急流` |
| 水流浮木动作 | `下潜` / `起跳` / `无解` | `潜下去` / `跳过去` / `过不去` |
| 状态吊网 | `绞盘 ↑` / `网低` | `网升起 ↑` / `网压低了` |
| SHOWTIME 世界字 | `720!` | `好戏！` |
| 连招世界字 | `BRO DIVE` / `BRO OLLIE` | Locale `兄弟下潜 / 兄弟蹬墙` |

### 3.5 密度与可读性

- 底部键帽只显示这条提示真正要按的键；不再常驻 `SHIFT ↑ ↓` 三个键帽。
- 右下另一个角色的过载条在 0 格时隐藏；只在真的积累时出现。
- 结算页深色底板从画面高度 58% 提高到 68%，并把 `最佳时间/快捷键` 加描边，避免压在沙地、木板和彩旗上。
- 开场加一句海藻说明；暂停页补回海藻规则，同时保留 `SPACE` 救援说明。

## 4. 四类耦合审计

### 4.1 时序/顺序耦合

审计对象：`race.gd::_physics_process` 的固定顺序。

| 顺序 | 阶段 | 读/写 | 风险 |
|---|---|---|---|
| 1 | 状态守卫、开场、终点演出 | `GameManager.state`、`opening_active`、`finishing` | 终点演出期间仍允许输入 |
| 2 | 输入缓存、SHIFT 锁、事故时钟 | `_buf_*`、`shift_lock_t`、`accident_event_time` | 同帧输入归属 |
| 3 | 区域/速度/各种计时器 | `current_zone`、`hazard_clock` | 动态障碍相位 |
| 4 | `_tick_recovery` | `mount.state`、`rabbit.state`、`GameManager.oxygen`（读） | 救援先于氧气结算 |
| 5 | `_tick_overdrive` / `_update_true_joint` | `_od_*`、`joint_show_t` | 演出优先级 |
| 6 | 控制标志、BRAIN、MISCHIEF、输入 | `current_control`、`rabbit_brain`、`turtle_brain`、`_mischief_*` | 控制权/走神/捣乱同帧 |
| 7 | 乌龟 tick、接人、`_update_oxygen` | `turtle.*`、`_catch_*`、`GameManager.oxygen` | 氧气失败同帧 |
| 8 | SHOWTIME/兔子 tick | `showtime_active`、`rabbit.*` | 表演优先级 |
| 9 | 伏击鲨、鸟行为/攻击、鲨群/攻击 | `_ambush`、`_bird_*`、`_shark_pack`、`_shark_attacks` | 动态攻击清理 |
| 10 | `_check_hazards` / `_resolve_turtle_solid` | `hit_groups`、`hit_roles` | 攻击与实体障碍同帧 |
| 11 | 连击、接力、教学、显示、终点 | `passed_groups`、`combo`、HUD | 显示与结算 |

本批修复的时序问题：

1. **氧失败同帧停机**：`_update_oxygen()` 判失败后，`GameManager.state` 已变 `FAILED`，但原来的 `_physics_process` 继续跑 `_tick_showtime/_tick_rabbit`、鸟/鲨攻击、`_check_hazards`、`_update_combo`。现在 `_update_oxygen()` 后立即检查状态并 `return`。
2. **OVERDRIVE 穿过高优先级状态**：`_tick_overdrive` 原来在 `PRE/ACTIVE` 分支直接推进，不看事故/救援/表演/联合演出。现在进入这些状态时调用 `_cancel_overdrive()`，清 `_od_phase/_od_role/_od_afterimages/_od_spring_t/_od_shell_t`，不发完成奖励。
3. **鸟攻击在救援中残留**：`_check_bird_attacks` 原来只在命中时看 `accident_state == NONE`，但空中的攻击体一直保留到 life 结束。现在救援上下文或兔子落水时直接清空。
4. **自动回壳的氧气承诺**：`_tick_recovery` 的自动回壳条件只要求 `oxygen > 0`，可能在 0.1 s 氧气时先启动 0.8 s 回壳，然后在同一段回壳里失败。新增 `AUTO_RESCUE_MIN_AIR = RESCUE_RETURN_TIME + 0.15`；氧气不足时不启动自动回壳，但玩家仍可用 `SPACE` 主动接住。
5. **终点后 SHIFT**：`GameManager.toggle_control()` 增加 `finished` 守卫，冲线结算开始后不再改控制权；重开仍走 `start_race()`。

### 4.2 状态字段归属

| 字段 | 唯一权威 | 写入点 | 读取点 | 结论 |
|---|---|---|---|---|
| `GameManager.accident_state` | race（运行中） | `_trigger_accident`、`_tick_recovery`、`_start_joint_show`、`_end_joint_show` | HUD、碰撞、救援、氧气 | 运行中只有 race 写；GameManager 只负责重置 |
| `mount.state` | `mount_controller` | `mark_riding/mark_airborne/mark_rescuing/mark_rescue_*` | 氧气、碰撞、HUD、救援 | race 不直接赋值，边界清楚 |
| `rabbit.state` | rabbit_controller + race 事故/表演 | controller 的普通状态；race 的 `FALLING_WATER/STUNNED/PASSED_OUT/SHOWTIME` | 碰撞、氧气、HUD | 事故状态由 race 接管，普通状态由 controller 管；有交叉但均在事故分支 |
| `turtle.state` | turtle_controller + race 事故/紧急 | controller 的 `CRUISING/DIVING/...`；race 的 `UNCONSCIOUS/CRUISING` | 碰撞、HUD | 同上 |
| `showtime_active` | race + `GameManager.showtime_active` 镜像 | `start_showtime/_end_showtime/_trigger_accident/_end_joint_show` | race/HUD/debug | 两处手动同步，当前所有写入点成对；仍是 P2 技术债 |
| `_od_phase/_od_role` | race | `_start_overdrive/_activate_overdrive/_end_overdrive/_cancel_overdrive` | race/HUD | 本批补了取消路径 |
| `_mischief_role` | race | `_maybe_start_mischief/_end_mischief` | 鸟电弧、HUD、日志 | 与 `GameManager.mischief_lock_role` 成对清 |
| `GameManager.bro_meter` | GameManager | `note_mistake/toggle_control/reset_role_meter/clear_bro_meter` | HUD | 当前角色镜像；`bro_meter_role` 才是每角色真值 |
| `GameManager.oxygen` | race 的 `_update_oxygen`（运行中） | `_splash_water` 回满、`_update_oxygen` 扣/回 | 救援、HUD、失败 | 单一写入函数，除入水重置外 |
| `rescue_auto_disabled` | race | `_splash_water` 清、`_cancel_auto_return` 置 | `_tick_recovery` | 只影响自动兜底，不影响主动 SPACE |
| `_bird_states/_shark_pack/_shark_attacks` | race | `load_level` 初始化、tick/spawn/clear | 攻击判定/绘制 | 救援/落水统一清理 |

### 4.3 数据耦合

- `current_control` 同时驱动：输入、BRAIN 的 `controlled`、HUD 当前行、接人目标、过载触发角色。它是全局数据耦合中心；本批只在 `toggle_control` 加 `finished` 守卫，未改语义。
- `mount.state` 同时被氧气、碰撞、HUD、接人读取；`RESCUING` 同时表示主动接住和自动回壳，靠 `carry_kind` 区分是否耗氧。
- `_mischief_role` 同时驱动鸟电弧抵消和 HUD 可读性；救援/表演会先结束捣乱，避免“捣乱中救援”的显示冲突。
- `passed_groups/hit_groups/entered_groups` 同时驱动连击、结算和 HUD；没有为了显示另造一套计数。
- 新增 `AUTO_RESCUE_MIN_AIR` 常量，没有新增状态字段或资源条。

### 4.4 测试/显示耦合

- HUD 仍然直接读 race/GameManager 的实时字段，不存副本；文字改动后，测试改为读同一批 Locale ID，不另写死中文。
- 文本改动导致以下测试期望同步更新：`stage4_bilingual`、`stage4_flow`、`stage4_hud_score`、`stage4_opening_pause`、`stage5_c_hud`、`stage7_drift_visible`、`stage7_food_readability`、`stage17_mischief_readability`。
- `stage4_hud_score` 的截图函数在 headless 下直接跳过（`frame_post_draw` 不会到达），因此 headless 能跑完 41 条 HUD/结算检查；有窗口时仍会截图。
- `stage4_collision_feedback` 的 Ollie 探针原先写死 `wall1=10860`，与当前关卡数据 `10716` 脱节，导致探针在错误位置起跳/蹬踏，记录到墙接触、动作反馈不成立。本批改为读本局实际组起点，并把蹬踏点从 90 px 调到 70 px、每例重置神游；现在 `no_contact=true / ollie_fx=true`，测试 PASS。

## 5. 状态交叉矩阵

新增 `scripts/test/stage22_coupling.gd` / `scenes/stage22_coupling.tscn`，16/16 通过。证据：`docs/reports/longrun/core-feel-22-coupling.json`。

| # | 组合 | 断言 | 结果 |
|---|---|---|---|
| 1 | MISCHIEF 起始 | 未受控满格角色进入 `TELEGRAPH` | PASS |
| 2 | SHIFT 进入捣乱角色 | 事件取消、该角色条清零 | PASS |
| 3 | SHIFT 离开旧捣乱角色 | 新的未受控满格角色接管 | PASS |
| 4 | SHOWTIME 起始 | race/GameManager 两处都 active | PASS |
| 5 | SHIFT × SHOWTIME | 换控制不取消表演，兔子仍 `SHOWTIME` | PASS |
| 6 | SHOWTIME × OVERDRIVE | 表演期间不启动过载 | PASS |
| 7 | OVERDRIVE 预兆 | 当前兔子进入 `PRE` | PASS |
| 8 | SHIFT 离开预兆 | 旧角色完成过载，控制权在新角色 | PASS |
| 9 | OVERDRIVE × 救援 | 冲刺被取消，残影清空 | PASS |
| 10 | 低氧自动回壳 | 氧 0.5 s 时不启动，保持 `RESCUE_ACTIVE` | PASS |
| 11 | 氧够回壳航程 | 氧 2.0 s 时自动回壳启动 | PASS |
| 12 | 救援 × 鸟/鲨攻击 | 攻击体清空、事故数不变 | PASS |
| 13 | 失败/重开全局重置 | 事故、捣乱、表演、SHIFT 锁、finished、氧气复位 | PASS |
| 14 | 失败页文本 | 有“氧气”，无“结算/普通” | PASS |
| 15 | 结算文本 | `训练结束` + 解药句 | PASS |
| 16 | HUD 文本 | `赛程 12/55`、无 `px`、`壳在晃` | PASS |

30/60/120 Hz 由既有 `stage8_hz_regression`、`stage19_bird_behavior`、`stage21_shark_pack` 覆盖；本批未改时间常数。

## 6. SHIFT 响应/锁定/归属优化

- 保留 0.20 s SHIFT 锁；锁定期内仍给 `刚换过人，稍等一下`，不再说“换人间隔 0.2 秒”。
- SHIFT 进入捣乱角色：立即取消旧 MISCHIEF，条清零，不追加惩罚。
- SHIFT 离开旧捣乱角色：新的未受控满格角色在下一帧接管；同一时刻仍然只有一个捣乱事件。
- SHIFT × SHOWTIME：只换控制权，表演继续；不取消、不补奖励。
- SHIFT × OVERDRIVE 预兆：这是设计允许的“换走让他自己弹/旋”，慢镜头与奖励仍走原路径。
- SHIFT 在终点结算开始后被 `finished` 守卫挡住，避免冲线演出中途换人。
- 没有新增按键、没有新增资源条、没有强制玩家多按 SHIFT。

## 7. BroBrain / MISCHIEF 可读性

- 左上：`操控 TUBO · SHIFT 换人`；每个角色行只显示自己的动作/待命；走神时显示 `电流不稳/电流发麻/电流过载` 与具体后果。
- 后果文字改为玩家语言：`速度 90% · 壳在晃`、`空中修正 55% · 落点偏`；刚起步说 `开始走神`，不再显示 `px`。
- 右下：当前角色 `TUBO 过载 0/3`；另一个角色只在 >0 时显示 `BITT 过载 2/3`，满格加 `!`。
- 连击与过载分开：`兄弟连击` 是连招，`过载` 是失误槽；两者不再共用英文缩写。
- 没有新增“未受控兄弟持续惩罚”系统；只是把既有 BroBrain/MISCHIEF 的状态、来源和后果说清楚。

## 8. FEEL-19/20/21 保留/修复/回退决定

**决定：保留，修复清理，不扩展。**

| 系统 | 证据 | 决定 |
|---|---|---|
| FEEL-19/20 海鸟行为 | `stage19_bird_behavior` 17/17；55 审计 `no_solution=[]`；两圈 55/55 | 保留 |
| FEEL-21 shark6 鲨群 | `stage21_shark_pack` 9/9；单组审计通过；两圈 55/55 | 保留，仅 shark6 |
| 鸟攻击救援清理 | 本批新增矩阵 #12 PASS | 修复 |
| 鲨群救援清理 | 既有实现 + 矩阵 #12 PASS | 保留 |

理由：

- 没有新增障碍组、没有改 44/55 单角色障碍结构；shark6 仍只改一组。**44/55 单角色组不是缺陷，本批没有为了凑双角色比例去改它们。**
- SHIFT 的主用途仍是“换对角色处理眼前的障碍”，没有新增“必须 SHIFT”的障碍，也没有提高 SHIFT 频率要求。
- 鸟/鲨都只有明确预兆窗口，同一时刻最多一个鲨攻击体；救援优先级高于攻击。
- 自动驾驶每圈 1 次事故，是“自动驾驶没有适配新攻击”，不是玩家无解；不能当真人难度证据。
- 艺术工作量没有增加：仍是原生剪影/占位，正式美术不在本批。

## 9. 回归证据

### 9.1 55 组解法审计

四个分片（0–13 / 14–27 / 28–41 / 42–54）全部：

```
AUDIT no_solution=[]
```

### 9.2 两圈正式跑圈

`stage3_playtest`：

```
FINISH run=1 passed=55/55 accidents=1
FINISH run=2 passed=55/55 accidents=1 (Retry)
RESULT zones=[1,2,3] max_accident=0.00s failures=0
STAGE3 PLAYTEST: PASS
```

三面高墙的 `wall ollie` 落壳检查均 PASS；`best.json` 跑前备份、跑后还原，MD5 仍为 `067DEB9A71A19C2F6F9F6DC41FEABF09`。

### 9.3 专项与回归

实机画面证据：

- `docs/reports/longrun/feel22/hud-zh.png`（HUD：赛程、过载、键帽密度）
- `docs/reports/longrun/feel22/result-zh.png`（结算：解药句、最佳行可读）
- `docs/reports/longrun/feel22/fail-zh.png`（失败：无“普通结算”元语言）
- `docs/reports/longrun/feel22/menu-zh.png`（主菜单）
- `docs/reports/longrun/feel22/opening-zh.png`（开场：去重后的副标题与海藻句）

| 测试 | 结果 |
|---|---|
| `stage22_coupling` | 16/16 |
| `stage4_bilingual` | PASS |
| `stage4_flow` | PASS |
| `stage4_hud_layout` | PASS |
| `stage4_hud_score` | 41/41 PASS |
| `stage4_opening_pause` | PASS |
| `stage4_hud_priority` | PASS |
| `stage5_c_hud` | PASS |
| `stage5_g2_release` | PASS |
| `stage7_drift_visible` | PASS |
| `stage7_food_readability` | PASS |
| `stage8_hz_regression` | PASS |
| `stage12_overdrive` | PASS |
| `stage13_catch_matrix` | PASS |
| `stage15_showtime_shift` | 9/9 |
| `stage15_mischief` | 13/13 |
| `stage15_oxygen_fail` | 9/9 |
| `stage15_fail_flow` | 3/3 |
| `stage19_bird_behavior` | 17/17 |
| `stage21_shark_pack` | 9/9 |
| `stage4_bro_meter` | PASS |
| `stage4_collision_feedback` | PASS（含 Ollie `no_contact/ollie_fx`） |
| `stage11_shift_relay` | PASS |

### 9.4 已修正的探针问题

`stage4_collision_feedback` 的 `ollie_fx` 原先写死 `wall1=10860`，当前关卡实际是 `10716`，探针在错误位置起跳/蹬踏，记录到墙接触。修正为读本局实际组起点、蹬踏点 70 px、每例重置神游后：

```
pass=true { leaped=true, passed_wall1=true, no_contact=true,
            clean=true, ollie_fx=true }
STAGE4 COLLISION FEEDBACK: PASS
```

没有改玩法去迁就探针。

## 10. 未验证 / 风险

1. **未进行真人操作验证**：手感、文本是否“出戏”、鸟/鲨的预兆是否读得懂，需要制作人手动试玩。
2. `showtime_active` 仍有 race 与 GameManager 两处镜像；当前所有写入点成对，但没有做成单一 getter/setter，属 P2 技术债。
3. 鸟/鲨的攻击体仍是原生剪影，正式美术未接入。
4. 自动驾驶每圈 1 次事故，不能据此判断真人难度；若真人试玩仍觉得鸟/鲨“无解”，下一批再调预兆/目标选择。
5. 角色正式美术、音频仍冻结。

## 11. 停止

- 未导出、未打包、未复制 EXE。
- 未修改 `best.json`。
- QC 闸门未在动手前建立（本批以任务书方向 + 回归探针为准），因此**不声明阶段验收通过**。
- 未宣布内容冻结，未宣布游戏完成。
- 等待制作人手动质检。
