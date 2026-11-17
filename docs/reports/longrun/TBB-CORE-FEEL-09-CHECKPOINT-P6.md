# FEEL-09 CHECKPOINT P6 — 综合回归（最终）

## 已跑（代码冻结后）

- 22 项 gate：`docs/reports/longrun/gate-feel09e.txt`（另见 c/d）。
- 两圈真实赛道：`stage3_playtest` **PASS**：274.0 / 273.9 s，55/55，0 事故，
  Retry，zones [1,2,3]；另 3 个种子与 2 次 soak 同样 PASS。
- 30/60/120 Hz：`stage8_hz_regression` **PASS**。
- 设计门槛：`stage4_metrics` **PASS**；`stage4_core_experience` **PASS**；
  `stage3_selftest` **PASS**；`stage6_balance_matrix` **PASS**。
- 菜单 / 重开 / 结算：`stage4_flow` PASS、`stage4_opening_pause` PASS；
  `stage4_menu_input` **窗口化 PASS**。
- 对比度：`stage4_hud_contrast` **窗口化 PASS**（worst 5.08）。
- 身份 / 动态 / 机制：`stage9_*` 6+3+9+7 项全 PASS；跨 13 个种子。
- 路线矩阵：`stage4_bro_dive_matrix` 三组数值与基线相同（0/100、36/100、38/100）。
- stage5 功能探针全部 PASS（含 G4 0.75 s 容差）。

## 与基线的差异（都已解释）

| 探针 | 基线 | 最终 |
|---|---|---|
| stage0_selftest | PASS | PASS |
| stage1_selftest | PASS | PASS |
| stage2_selftest | 9 fail | 9 fail（同基线，旧阶段自检） |
| stage3_selftest | 3 fail | PASS（tail-gap + CAPSIZES） |
| stage4_metrics | 5 fail | PASS（节奏重排） |
| stage4_core_experience | 2 fail | PASS |
| stage4_menu_input | 18 fail | 窗口化 PASS（headless 15 条指针） |
| stage4_opening_pause | 1 fail | PASS |
| stage4_bro_dive_matrix | PASS | PASS（standalone <180 s） |
| 其余 | 同 | 同 |

## 未完成 / 已知

- `best.json` MD5 未保持：`C499…` → `0700…`（开工无备份，无法还原）；
  当前 0700 已还原并保持可写。
- `stage4_solution_audit` 的 log6/log7/log8 在审计模型里 `passing=[]`；
  这是审计没有补偿 FEEL-08 的神游反应延迟，两圈真实驱动 55/55 通过。
- 真人试玩未做。

## 现场

- STAGE=4；`settings.json` 语言 zh；项目内 0 个音频文件。
