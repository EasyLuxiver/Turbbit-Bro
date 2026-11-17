# FEEL-09 证据覆盖说明（2026-11-14）

## 已覆盖

- `docs/reports/longrun/core-feel-08-p1c-obstacle-inventory.json`
  - 该文件在 FEEL-09 的 `stage8_obstacle_identity` 探针重跑时被重新生成。
  - 它是未跟踪文件，开工时没有备份；旧内容（FEEL-08 的 10 种身份表）不可恢复。
  - FEEL-08 报告第 5 节的 55 行表格仍是历史记录。
  - FEEL-09 的新清单在 `core-feel-09-p1c-obstacle-inventory.json`。

## best.json

- 本轮开始：`C499C2DCE8E33B4F24744CB7486B1F06`
- 探针写入后：`07002183E6D976F0DB7761A578766324`
- 无 `c499…` 备份；当前文件已另存为
  `_attic/2026-11-14/pre-feel09-evidence/best.json.after-probes`。
- 从 2026-11-14 01:56 起设为只读，防止继续被探针覆盖。

## 其它

- 开工前已把 `docs/reports/longrun/` 下 91 个证据文件复制到
  `_attic/2026-11-14/pre-feel09-evidence/`。
