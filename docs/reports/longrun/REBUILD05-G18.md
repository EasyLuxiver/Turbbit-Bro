# G18 — 救援窗口探针一直只测到每组第一例

日期：2026-11-13（06:20 起）
改动：`scripts/test/stage4_rescue_boost.gd`（探针，两处；产品代码 0 行）
QC：`tbb-exp05-g18-rescue-boost`（标准 06:24 先写，改动 06:26 起）

## 为什么做这一条

主报告的 P3 里记着 `stage4_rescue_boost` 的 z3（beam8）8 例 `crash=no_hit`，
当时的判断是“探针自身前提失效”。这一轮把它查到底：不是探针的跳跃时机失效，
是**探针忘了复位碰撞记账**。

## 根因

B2 起碰撞按“角色 × 障碍组”各记一次（`hit_roles`）。`_check_hazards()` 里：

```gdscript
var roles: Dictionary = hit_roles.get(key, {})
if roles.size() >= 2:
    continue
...
rabbit_hit = rabbit_can_hit and not roles.has("rabbit") and ...
```

正式流程由 `start_race()` → `_arm_rescue_proto()` 清 `hit_roles`；探针直接调
`race.load_level()`，不经过那条路，`_reset()` 里清了 `hit_groups` 却漏了
`hit_roles`。后果：**同一个障碍组第一次撞上之后，整个进程里它对该角色永久免疫**。
于是 25 例里 beam1 只有 `boost_none` 真撞、beam8 只有 `z3_none` 真撞，其余 23 例
`crash=no_hit`——看起来像“下潜之后不再落水”，实际是探针自己的洞。

复现与定位证据：`reg-g18-rescue-boost-before.log`（修复前，exit 1）。
单跑 `boost_dive_0.0` 一例 → `crash=RABBIT_WATER result=caught`；先跑
`boost_none` 再跑它 → `crash=no_hit`。加临时 trace 看到第二次试次里兔子照样跳到
`ry=93`（比横梁还高），只是碰撞不再记账。

## 第二处：汇总判定从来没进退出码

`_run()` 只数 `row.pass` 决定 exit code，`_evaluate()` 写进 `checks` 的 8 条
汇总判定一条都不影响结果。修复前 `checks.base_matches_phase_f=false`，
`DONE` 依然 `fails=0` 并 `quit(0)`——和 G15 修过的“静默红”是同一类问题：
“探针跑得绿”和“窗口真的没坏”被混成了一件事。
现在退出码 = 行失败 + 汇总 checks 失败，输出 `red=N` 并列出红项。

## 证据

| 验收点 | 证据 |
|---|---|
| 同组连续试次都能触发落水 | `reg-g18-rescue-boost.log`：25/25 行 `crash=RABBIT_WATER`（修复前 2/25）；`phase-r-rescue-boost.json` 全行为真 |
| TURBO 窗口 ≥1.6 s | `boost_dive_0.0/0.4/0.8/1.2/1.6` 全部 caught，catch 1.38–1.85 s |
| 基速对照没坏 | `base_dive_0.0/1.6/2.0` caught（1.23/1.85/2.33 s）、`base_none` missed（4.37 s） |
| Z3 最坏尾巴 | `z3_dive_0.0/0.8/1.2` caught（2.07 s），`z3_none` missed（4.42 s） |
| 一次事故、逐帧恢复 | 25 行 `accident_delta_at_recovery=1`；`max_return_step` 最大 9.33 px（阈值 12） |
| 汇总判定真的会红 | 退出码改为 `fails==0 and red.is_empty()`；本轮 `DONE rows=25 fails=0 checks=8 red=0` |
| 两圈回归没动 | `fullrun-g18.log` 与 `fullrun-g17.log` 的 FINISH/SCORE/PASS 行 diff 为空 |
| `best.json` 没动 | 退出后 md5 `c322f9a20321c5b618f98db7e4120969` |

## 标准勘误

第 3 条我写的是“0.0/1.6/2.0 caught、2.4 missed”，前半对、后半错：实测
`base_dive_2.4` 是 caught（2.85 s 接上）。这不是回归——探针行内注释和 §6 重写
记录都写明基速窗口已变宽、2.4 s 属容错变好且在行内只记录不断言；真正同一份文件
里自相矛盾的是 `_evaluate()` 那条仍然写着 2.4 missed 的旧断言。本轮把它改成与
行内一致的判据（`base 0.0/1.6/2.0 caught + base_none missed`），失败边界仍由
`base_none` 与 `stage4_water_rescue` 负责。QC 记录按“基速没被改坏”的实义判 pass，
并在 evidence 里写明了这一句标准本身写错。

## 顺带发现（未修）

20 个探针都清了 `race.hit_groups` 但没清 `hit_roles`：`stage4_bird_routes`、
`stage4_bro_dive_matrix`、`stage4_collision_feedback`、`stage4_combo_windows`、
`stage4_experience_rework`、`stage4_hud_score`、`stage4_partner_neglect`、
`stage4_playful_bro_dive_audit`、`stage4_playful_joint_verdict`、
`stage4_playful_rescue_continuity`、`stage4_playful_shift_reward`、`stage4_proto`、
`stage4_snack_draw`、`stage4_snack_rush`、`stage4_snack_zones`、
`stage4_solution_audit`、`stage4_surfboard`、`stage4_window_audit`、
`stage4_z3_warning`、`stage5_c_hud`。

这些探针大多每个 case 用不同起点、同一障碍组不重复撞，所以可能一直没暴露；
但只要哪个 case 在同一个组上撞第二次，它就在测一段免疫了的赛道。没有一并改：
一次改 20 个探针会让它们的既有期望同时变色，需要逐个重跑判读，属于单独的清扫轮，
不该在没有证据的情况下塞进这一条。建议下一轮连同“探针复位公共函数”一起处理。

## 已知限制

- 探针驱动仍然是“引擎按键代理”，不是真人试玩；窗口数字只说明代码允许，
  手感仍要真人确认。
- 2.0–2.4 s 的加速档只记录不断言，是因为 §6 之后窗口上界本身不稳定（接上时间
  随速度线性变长）；真正的失败边界靠 `boost_none` / `base_none`。
