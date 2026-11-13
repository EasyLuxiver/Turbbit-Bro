# _superseded — Phase H 中间产物

这些分片来自 2026-11-12 Phase H 复测解法矩阵时的**并行分片试跑**，不是最终数据。

- 问题：`stage4_solution_audit.gd` 的 `_reset()` 当时没有清空 `GameManager` 的
  BRO METER / 联合惩罚排队，导致某个 case 开场就播 1.4 s 联合演出（速度钉 0），
  探针把它记成“无解”。g=27（shark5）是唯一被读成无解的组。
- 处理：`_reset()` 补清 `bro_meter` / `accident_count` / `joint_show_t` / `accident_flash`
  之后，用 00-13 / 14-27 / 28-40 / 41-54 四个分片**顺序重跑**，结果为 55/55 有解、
  0 条 no_solution，并与 `stage4-solution-matrix.json`（Phase C 基线）逐组比对 0 差异。
- 这些文件只保留作“假无解从哪里来”的证据，不参与任何统计。引用数据请用
  `docs/reports/stage4-solution-matrix-{00-13,14-27,28-40,41-54}.json`。
