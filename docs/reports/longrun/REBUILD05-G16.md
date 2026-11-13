# G16 — 结算页记住「亲手喂到」次数

日期：2026-11-13（06:05 起）
改动：`game_manager.gd`（一个计数）+ `race.gd`（吃得那一行 +1）+ `locale.gd`（一条文案）
      + `result.gd`（一行 + 样本值）+ `stage4_snack_rush.gd`（两列断言）
QC：`tbb-exp05-g16`（标准 06:04 先写，代码 06:05 起改）

## 为什么做这一条

换到乌龟、亲手把食物喂到兔子嘴里，是这个游戏里最像“我在照顾搭档”的动作：
HUD 会闪「TURBO！亲手喂到！」，一次 +40 分（`SNACK_SWITCH_BONUS`）。但这个动作
**结算页完全不留痕**——玩完只记得救援成功几次，不记得自己喂了几次。
结果就是：玩家看不到这条路径被游戏认可，下一局就没有“再喂几次”的理由。

这条不新增机制、不改平衡，只把已经在记的账显示出来。

## 做了什么

1. `GameManager.snack_switch_count`，`start_race()` 里归零；
2. `race.gd` 的 `_eat_snack()` 在 `fed_by_player` 为真时 `+= 1`
   （只有当前操控乌龟时才算；兔子骑在壳上自动吃的不算）；
3. `locale.gd` 加 `result.snacks`（中「亲手喂到」/ 英 `HAND-FED SNACKS`），
   数值列宽与相邻行一致；
4. `result.gd` 在「救援成功」下面插一行，`--capture-result` 的样本值 `= 3`。

计分与文案分人逻辑一行没动：仍然只有亲手喂到才发 `snack_switch` 那 40 分和
`feedback.turbo_switch` 文案，没切过去照样吃、照样加速，不加任何惩罚。

## 证据

| 验收点 | 证据 |
|---|---|
| 只有操控乌龟吃到才 +1 | `reg-g16-snack-rush.log`：`SNACK: DONE cases=3 fails=0`、exit 0；`phase-o-snack.json` 三行 `fed_count` = eat 1 / skip 0 / hit 1，`fed_count`/`fed_score` 全 true |
| 计分与文案没变 | 同一测试：`fed_score` 数 `score_log` 里 `reason == "snack_switch"` 的条目，eat/hit 恰 1 笔、skip 0 笔；原有 `collision_alive`/`no_penalty` 等断言全 true |
| 中文结算页 | `rebuild05-result-snacks.png`（1280×720）：`救援成功 4` 下面 `亲手喂到 3`、再下面 `失误 0`，不裁切、不压行 |
| 英文结算页 | `rebuild05-result-snacks-en.png`（1280×720）：`HAND-FED SNACKS       3` 一行到底，右侧不越界 |
| **数值与本局实际操作一致** | `rebuild05-result-snacks-real.png`：正式 race 窗口化真跑一圈（`stage3_playtest -- --capture --zh`）后的结算页，读数 `比赛时间 272.89 / 干净通过 55 / 连招 11 / 救援成功 0 / 亲手喂到 9 / 失误 0 / 联合事故 0`；同一局的 `SCORE ... snack=9` 对得上 |
| 结算页原有 44 项没坏 | 改动后窗口化 `stage4_hud_score`：`PASS checks=44`、exit 0；`stage4_menu_input` 也 PASS |

## 回归

- 两圈 `fullrun-g16.log`：run1 272.9 s / run2 272.8 s、9770、S、55/55、0 事故、
  `STAGE3 PLAYTEST: PASS`；FINISH / SCORE / PASS 行与 `fullrun-g15.log` `diff` 为空
  （`SCORE clean=0 precise=44 dive=8 ollie=3 snack=9 mistake=0 joint=0 -> 9770` 两圈相同）。
- 21 场景批量 `$TEMP/reg-g16-<scene>.log`（stage1_selftest … stage5_g11_showtime_capture）：
  全部 exit 0、0 条失败行、0 条 SCRIPT ERROR。
- 两个窗口化测试：`stage4_hud_score` `PASS checks=44`、`stage4_menu_input` PASS。
- `best.json`：批量退出后 md5 仍 `c322f9a20321c5b618f98db7e4120969`。
- 真实通关截图那次运行会短暂刷新 `best.json`（272.89 + 新连击 55），测试在退出前
  逐字节还原；跑完核对 md5 仍是 `c322f9a2…`。截图上「新最佳时间！」是这次自动化跑出来的，
  **不是制作人纪录**。
- 取证时 `stage3_playtest -- --capture` 会重写 `stage3_result/menu/zone*.png` 与
  `docs/reports/stage3-run.log`（2026-11-12 的 Phase 3 证据）。跑前先备份、跑后按 md5
  逐字节还回：`cd41469f…`（result/menu）、`c25e70cf…`、`9e97895c…`、`a3618a94…`、
  `8c3639c2…`（stage3-run.log），全部与备份一致；新图另存为
  `rebuild05-result-snacks-real.png`（`5bd7261b…`）。

## 已知限制

- 这一行是无条件显示的：本局一次都没亲手喂到会显示「亲手喂到 0」。理由是与救援/失误等
  其他行一致（都显示 0），不去做“只在 >0 时才出现”的隐藏逻辑——否则玩家没法知道
  这个动作存在。若制作人觉得 0 像指责，改法是加一句“试试换到乌龟再喂它一口”，
  不属于本轮改动。
- `fed_score` 靠数 `score_log` 的 `snack_switch` 条目，而 `score_log` 只保留最近 240 笔；
  三例 12 s 的短程不会顶到上限（本次三例全过），但**以后若加长单例时长**，
  这条断言的增量算法会因为 `pop_front` 变成负数，需要改成按 `total_score` 差或独立计数。
- 这次把测试自己的输出 `phase-o-snack.json` 重写了（schema 不变，多了 `fed_count` 一列）。
