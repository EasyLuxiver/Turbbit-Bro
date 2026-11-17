# TBB-CORE-FEEL-09 · P0 基线 checkpoint

- 时间：2026-11-13 23:45（本地）
- 阶段：STAGE=4（`docs/STAGE.md` 仍为一行 `STAGE=4`）
- Git HEAD：`f9b40067b00599ce70a4905cdf5ab20eacb11862`
- 工作树：212 条变更（上一轮 FEEL-08 的产物尚未提交；本轮不提交、不覆盖）
- `best.json` MD5：`C499C2DCE8E33B4F24744CB7486B1F06`
  - 路径：`C:\Users\26549\AppData\Roaming\Godot\app_userdata\Turbbit Bro!\best.json`
- 上一轮报告：`docs/reports/longrun/TBB-CORE-FEEL-08.md`（32,106 B，2026-11-13 23:13）
- 当前可运行入口：`D:\Godot_v4.7-stable_win64_console.exe --path D:\GAMESTUDIO\TURBBIT`

## 本轮开始前已核对

- 55 组障碍全部存在（`LevelDataScript.groups()`）。
- Z2 六层码头场景已存在：`scenes/zone2_dock.tscn`。
- 错位清单（8 个）：bird3/4/5（diving_gull）、shark3/5（reef_shark）、gate3/4/5（reef_arch）。
- 9 个 tide_rock：rock3（buoy）、rock4/5/7（dock_crate）、rock8/9/10/11/12（drift_crate）。
- QC 验收标准已在动手前写入：`LESSONS/REPORTS/qc/tbb-core-feel-09.json`（12 条）。

## 本轮不做

- 不推进 STAGE 5，不做多结局/剧情结算。
- 不生成、不导入、不改引用任何音乐/音效。
- 不下载新模型、不训练 LoRA、不升级 ComfyUI。
- 不批量生产正式美术，不覆盖原始场景/历史证据。
