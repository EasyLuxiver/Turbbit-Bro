# FEEL-09 CHECKPOINT P3 — SHIFT 锁定与 Showtime 奖励（00:12）

## SHIFT 0.20 s 锁定

- `GameManager.SHIFT_LOCK_TIME = 0.20`；`toggle_control()` 成功后置锁，
  锁期内按键直接返回（不排队、不延迟补发），并 emit `feedback.shift_lock`。
- 首次切换仍在同一调用内生效；事故/救援旧规则未改。
- 探针 `stage9_shift_showtime.gd` 实测：
  - 30 Hz：解锁 0.233 s（误差 0.033 s = 一个物理步长）
  - 60 Hz：解锁 0.217 s（误差 0.017 s）
  - 120 Hz：解锁 0.208 s（误差 0.008 s）
  - 立即二次被挡、到期后不按不换人、普通事故挡住、主动救援允许。
- 证据：`docs/reports/longrun/core-feel-09-p0cd-shift-showtime.json`

## Showtime 奖励

- 正常完成：`+100` 分、**实际氧气增量**（最多 +1.5，满氧显示“氧气已满”）、
  `showtime_count + 1`，只发一次。
- 中断（SHIFT / completed=false）：不发奖。
- HUD：完成时 `feedback.showtime_reward`（+100 分 / 实际氧气），停留 1.8 s；
  满氧走 `feedback.showtime_reward_full`。
- 结算页：新增 `result.showtime` 行（`表演次数 N`）。
- 探针 9/9 PASS：单次、无重复、中断不发、HUD 文本、结算行。
- 截图：`screenshots/core-feel-09-showtime-reward.png`。

## 最终复核（06:00）

- `stage4_bro_dive_matrix` 三组数值与基线相同（0/100、36/100、38/100）；
  `stage6_balance_matrix` PASS；两圈 `stage3_playtest` 55/55、0 事故、Retry。
- `stage4_shift_feel` 按新规格更新（立即二次被挡、锁后第二发 FX）；
  `stage4_shift_graybox`、`stage5_d_shift` 均 PASS。
- 真人手感仍未验证。
