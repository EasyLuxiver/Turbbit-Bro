# FEEL-09 CHECKPOINT P2 — 9 个动态障碍（00:05）

## 完成

- 探针 `stage9_dynamic_rocks.gd`：9/9 存在；x/w/两段判定矩形/amp/period
  与 FEEL-08 冻结基线逐项相同；9/9 有运动来源。
- 证据：`docs/reports/longrun/core-feel-09-p0b-dynamic-rocks.json`
- 表内字段：`obstacle_id / zone / old_identity / new_identity /
  motion_source / visual_behavior / collision`。
- 截图（峰/谷各一张，`TURBBIT/screenshots/`）：
  - `core-feel-09_buoy_crest/trough.png`
  - `core-feel-09_dock_crate_crest/trough.png`
  - `core-feel-09_drift_crate_crest/trough.png`
- 物理没有改动：碰撞矩形仍是 `SURFACE_ROCK` 模板的 220/42 主带 +
  368/50 反下潜段；没有为截图缩框。

## 运动来源

- buoy：锚绳拴海底，随涌浪起落；画面有绳、浪鼓、水线。
- dock_crate：吊索汇聚到屋顶滑轮，随吊点升降；画面有吊索/滑轮。
- drift_crate：从码头冲出的货，随大浪浮沉；画面有浪鼓/水花。

## 未完成

- 9 块里只有 3 种身份；其余 6 块与对应身份共用同一画法，因此只拍了
  3 组峰谷图。逐个实例的参数一致性由 JSON 覆盖。

## 最终复核（05:xx）

- `stage9_dynamic_rocks` 多次复跑仍 3/3 PASS；两圈 `stage3_playtest`
  55/55、0 事故，说明动态障碍路线未被身份/画法改动破坏。
- 后续节奏改动只动了 log6/bird7/shark8 等非动态障碍，未改 9 块 tide_rock 的 x/w。
