# G19 — 撞上“只有兔子能躲”的障碍时，第一次告诉你换人

日期：2026-11-13（06:20 起，06:40 收尾）
改动：`locale.gd`（8 条教学文案点名 SHIFT + 1 条 `hint.take_rabbit`）、
`race.gd`（`_rabbit_contact` 里一次提示 + `_wrong_role_hinted` 复位）
探针：`scripts/test/stage5_g19_wrongrole.gd` + `scenes/stage5_g19_wrongrole.tscn`
QC：`tbb-exp05-g19-wrongrole`（标准 06:32:08 先写，代码 06:32:22 起改）

## 为什么做这一条

低梁 / 海鸟 / 岩檐（A 类）只在兔子那一层判定。玩家在操控乌龟时撞上，
画面上看起来就是“我什么都没按就撞了”：乌龟的 ↓ 是下潜，不是趴低，
玩家当时根本没有可用的躲法。G3 已经为“壳停太深”补过一句具体原因，
A 类这一侧一直只有一句“操作错了有没有后果”的结果，没有“为什么会错”。

这条只做两件事，都不改判定、不加惩罚：

1. 首次教学文案把 SHIFT 点名出来（以前只说“兔子按 ↓”，没说怎么变成兔子）。
2. 当局第一次在乌龟控制下撞上 A 类障碍时，底栏说一句
   `按 SHIFT 换兔子 - 这个只有兔子能躲` / `PRESS SHIFT FOR THE RABBIT - ONLY IT CAN DODGE THIS`。

## 做了什么

- `_rabbit_contact(kind)` 在事故之前判断：`kind in [LOW_BEAM, LOW_BIRD,
  SURFACE_ROCK] and current_control == "turtle"`，且本局没说过 → 发一次 hint。
  `_wrong_role_hinted` 是 race 节点上的普通变量：正式重开走
  `change_scene_to_file(RACE_SCENE)`，节点重建就归零；另在 `_arm_rescue_proto()`
  里显式清零，照顾救援原型场景这条复用同一节点的入口。
  不改事故判定、不改计分、不改 BRO METER。
- 教学文案：beam / rock / bird / dock_beam / gate / shark / wall / log 八条中英都写明
  按 SHIFT；`lesson.wave` 也一并补上（同样是换人动作）。

## 证据

| 验收点 | 证据 |
|---|---|
| 乌龟控制撞低梁/海鸟/岩檐时出现一次 | 探针 `G19 WRONGROLE: PASS checks=9 failures=0`；`turtle_hit` 的 hint 流与 HUD 文本都等于 locale 同一句 |
| 兔子控制撞同一组不出现 | 同一障碍、同一物理，只换操控权：`rabbit_hit_first` 的 hints 为空 |
| 一局最多一次 | `turtle_hit_again` 再撞同组，hint 流为空（`_wrong_role_hinted` 已置位） |
| 文案点名 SHIFT | 8 条教学 × 中英 16 串全部含 `SHIFT`（探针另量最宽 `lesson.dock_beam` en = 668 px，行宽上限 1568 px） |
| 正式场景看得到、中英都对 | `screenshots/rebuild05-g19-wrongrole-zh.png`、`-en.png`：底栏提示行一行放下，下面另起一行救援提示不重叠 |
| 判定没被改 | 两圈回归、22+1 场景批量、两个窗口化测试、`best.json` md5（见下） |

## 回归

- 两圈 `fullrun-g19.log`：272.9 / 272.8 s、9770、S、55/55、0 事故；
  FINISH / SCORE / PASS 行与 `fullrun-g18.log` `diff` 为空。
- 23 场景批量（22 个原有 + 本轮 `stage5_g19_wrongrole`）：全部 exit 0、0 条失败行、
  0 条 SCRIPT ERROR。
- 窗口化 `stage4_hud_score`：`PASS checks=44`；`stage4_menu_input`：`STAGE4 MENU INPUT: PASS`。
- `best.json`：退出后 md5 `c322f9a20321c5b618f98db7e4120969`。

## 已知限制

- 提示只在“乌龟控制 + A 类 + 本局第一次”出现。玩家如果第一次是兔子控制下撞的
  （例如自己起跳撞梁），不会补这句——那时问题不是“该换谁”，而是时机，
  由已有的动态障碍提示/教学负责。
- 一句话改变不了“第一次就撞”的成本：这一撞仍然记 1 格 BRO METER、扣时间。
  它只是把“不知道为什么”变成“知道该按 SHIFT”。
- 文案变长后只在 headless 视口（1600 宽）与 1280×720 窗口上量过；
  更窄的分辨率没有验证。
- QC 标准第 3 条我写的是“连续两组 A 类障碍”，探针实测用的是**同一组重复两次**
  （同一物理、只是第二次已置位）。对“一局一次”的机制验证更严，但这句标准与
  实际步骤不完全一致，如实记在这里。
