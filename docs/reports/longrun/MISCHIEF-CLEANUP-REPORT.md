# 旧 MISCHIEF 代码清理报告

- 日期：2026-11-18
- 范围：只清理旧 MISCHIEF 独占代码；走神度、Q 弹碰撞、Showtime、救援、氧气等现有机制不改。
- 未导出、未打包、未部署；`best.json` 跑前备份、跑后还原。

## 1. 删除清单

### race.gd

| 项目 | 当前调用者 | 状态 | 旧 MISCHIEF | 风险 | 处理 |
|---|---|---|---|---|---|
| `_tick_mischief()` | 无生产调用；旧 stage22/29 已删 | 无引用 | 是 | 低 | 删除 |
| `_maybe_start_mischief()` | 仅旧 state machine / 旧测试 | 无引用 | 是 | 低 | 删除 |
| `_apply_mischief_action()` | 仅 `_tick_mischief` | 无引用 | 是 | 低 | 删除 |
| `_end_mischief()` | 仅 `_tick_mischief` / 旧测试 | 无引用 | 是 | 低 | 删除 |
| `_mischief_predicted_kind()` | 仅 `_draw_mischief` | 无引用 | 是 | 低 | 删除 |
| `_mischief_clear_of_hazards()` | 仅 `_maybe_start_mischief` | 无引用 | 是 | 低 | 删除 |
| `_draw_mischief()` | `_draw()` 中调用，但 role 永远为空 | 无实际表现 | 是 | 低 | 删除调用与函数 |
| `_draw_complaint()` | 无调用 | 无引用 | 是 | 低 | 删除 |
| `_draw_ignore_mood()` | 无调用 | 无引用 | 是 | 低 | 删除 |
| `_tick_ignore()` | `_physics_process` 调用，但只写死状态 | 无表现 | 是 | 低 | 删除 |
| `MISCHIEF_TELEGRAPH/ACTION/END/CD/REACTION_DELAY` | 旧 state machine | 无引用 | 是 | 低 | 删除 |
| `_mischief_*` 变量、`mischief_log`、`_ignore_t` | 旧 state machine / 旧测试 | 无引用 | 是 | 低 | 删除 |
| 电弧抵消 3 个分支（`_check_bird_attacks`） | 旧 MISCHIEF shock 窗口 | 无引用 | 是 | 低 | 删除；鸟攻击本身保留 |

### game_manager.gd

| 项目 | 当前调用者 | 状态 | 旧 MISCHIEF | 风险 | 处理 |
|---|---|---|---|---|---|
| `take_role_mischief()` | 无调用 | 无引用 | 是 | 低 | 删除 |
| `reset_role_meter()` | 无调用 | 无引用 | 是 | 低 | 删除 |
| `role_meter()` | 无调用 | 无引用 | 是 | 低 | 删除 |
| `tick_complaint()` | 仅 `_tick_mischief` / 已删 stage29 | 无引用 | 是 | 低 | 删除 |
| `relieve_pressure()` | 无调用 | 无引用 | 是 | 低 | 删除 |
| `role_mischief_pending/role`、`bro_meter_role`、`bro_meter_max`、`mischief_lock_role`、`BRO_METER_SLOTS` | 旧 state machine / 旧测试 | 无生产引用 | 是 | 低 | 删除 |
| `bro_meter_full` 信号 | 无连接、无 emit | 无引用 | 是 | 低 | 删除 |
| `toggle_control()` 里同步 `bro_meter` 的两行 | 旧 HUD 槽 | 无表现 | 是 | 低 | 删除 |

### 其他文件

| 文件 | 删除内容 | 理由 |
|---|---|---|
| `turtle_controller.gd` | `TUG_DEPTH`、`TUG_SPEED_SCALE`、`tug_t` 及减速/下沉后果 | 只有旧 MISCHIEF 拽绳会写；`zap_stun_t` 保留给走神漏电 |
| `systems/tuning.gd` | `MISCHIEF_POSE_NEAR` | 无引用；`MISCHIEF_POSE_LIFT` 保留给 Overdrive |
| `autoload/locale.gd` | 11 个 `mischief.*` 键 | 删除函数后无引用 |
| `scenes/`、`scripts/test/` | `stage29_mischief_audit.*`、`stage34_mischief_distance.*`、`stage33_tutorial_safety.*`、孤立的 `stage17_mischief_readability.gd.uid` | 只测已删除的旧机制 |
| `stage22_coupling.gd` | `_case_shift_mischief`、`_mischief_*` 重置、`role_mischief_*` 断言 | 旧用例；其余耦合用例保留 |
| `stage19_bird_behavior.gd` | `_arc_block()` 用例 | 电弧抵消已随 MISCHIEF 删除 |
| `stage3_playtest.gd` | `MISCHIEF_LOG` 输出 | 日志字段已删除 |
| `stage10_joint_semantics.gd` / `stage12_overdrive.gd` | `role_mischief_*` 初始化行 | 字段已删除 |

## 2. 保留清单（不是“完全未使用”）

| 项目 | 为什么保留 |
|---|---|
| `test_no_mischief` | 名字沿用旧测试，但现在只控制 `_tick_sleep` / `_draw_sleep_fx`；大量现有测试会设置它 |
| `rabbit.mischief_pose` + `MISCHIEF_POSE_LIFT` | 仍被 Overdrive 的 `_start_overdrive` / `_end_overdrive` 使用，不是 MISCHIEF 独占 |
| `turtle.zap_stun_t` | 走神漏电命中后 0.25 s 不能下潜，当前机制在用 |
| `GameManager.bro_meter` / `bro_meter_changed` | 历史探针和测试读写；正式流程只清零/记录，不再充能，也不再显示 |
| `complaint_role/t` + `note_mistake()` 的抱怨写入 + `clear_bro_meter()` | `stage3_selftest`、`stage10_joint_semantics`、`stage46_showtime_small` 仍读取；现在只作为兼容状态，不驱动任何行为 |
| `clear_bro_meter()` | 联合事故、Showtime、重开仍在调用；同时清 `waterlogged` |
| `bro_joint_pending` / 联合事故字段 | 当前联合惩罚机制 |
| `hud.drift_mischief`、`feedback.drift_warn_mischief`、`bro_brain.gd` 的 `MISCHIEF` 阶段、HUD/字形颜色 | 这是走神度的第 3 阶段，不是旧 MISCHIEF 状态机 |
| stage4/5/6/7 等历史测试 | 仍引用 `bro_meter` / `mischief_pose`，但不在本次验收范围；未删除、未伪改 |

## 3. 回归结果

| 测试 | 结果 |
|---|---|
| `stage53_soft_pressure` | **PASS**（12 项，两种漏电/头像/无事故/可切回） |
| `stage45_bounce_recovery` | **PASS**（含第 6 次 `BONK_OUT`） |
| `stage46_showtime_small` | **PASS** |
| `stage3_playtest` | **PASS**：238.3 / 238.3 s，53/53，3 accidents，max_stuck=0，grade B |
| `stage10_joint_semantics` | **PASS** 10/10 |
| `stage19_bird_behavior` | **PASS** 15/15（电弧抵消用例随机制删除） |
| `stage22_coupling` | **PASS** 20/20（旧 MISCHIEF 用例删除后其余全过） |
| `stage3_selftest` | **PASS** |
| `stage19_p0_readability` | PASS（3 项） |

`best.json`：跑前备份、跑后还原，玩家纪录仍为
`239.796160000161 s / 9870 分 / 0 事故 / 54 连`。

### 已知的遗留失败

- `stage12_overdrive`：失败项是 `2a_tubo_pre` 等，测试仍假设“漂移 12 后 `_tick_overdrive` 自动进入 PRE”。FEEL-22 已明确停用这条自动触发链，属于旧测试过期，不在本任务的删除范围内；本次没有改 Overdrive 规则。
- stage4/5/6/7 等历史测试仍可能因 `bro_meter` 不再充能而失败；它们是旧 BRO METER 时代的资产，本次只保证不因删除而缺函数/缺字段。

## 4. 约束遵守

- 走神度参数、触发、切换、硬直、冷却未改；
- Q 弹后退距离、弹簧时长、squash 时长、6 次 `BONK_OUT` 未改；
- 未新增按键、敌人、障碍、资源；
- 未改本轮无关文本；仅删除旧 MISCHIEF 文本键；
- 未导出、未打包、未部署，未覆盖 Web/EXE。
