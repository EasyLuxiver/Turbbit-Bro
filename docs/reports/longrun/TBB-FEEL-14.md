# TBB-FEEL-14 制作人试玩准备

- 日期：2026-11-14
- 阶段：`STAGE=4`
- 目标：准备制作人实际试玩；不开发新功能，不宣布内容冻结。
- 结论：**试玩版本、启动方式、试玩模板、回归证据已准备好。停止，等待制作人试玩。**

## 1. 当前版本保护

### Git / Godot

- Git HEAD：`f9b40067b00599ce70a4905cdf5ab20eacb11862`
- 工作区：准备开始时 **939** 条修改/未跟踪；准备完成时 **969** 条（新增试玩准备文件、导出配置、回归报告；`TURBBIT/build/` 已加入 `.gitignore`，避免二进制误提交）。未提交、未重置、未清理现有证据。
- Godot：`4.7.stable.official.5b4e0cb0f`，Forward+，主场景 `res://scenes/menu.tscn`，基准视口 1600×900（canvas_items 拉伸）。
- 基线记录：
  - `_attic/2026-11-14/feel14-baseline/HEAD.txt`
  - `_attic/2026-11-14/feel14-baseline/git-status.txt`
  - `_attic/2026-11-14/feel14-baseline/project.godot`
  - 用户设置 `settings.json`（`{"language":"zh"}`）
- 可运行源码快照：
  - `_attic/2026-11-14/feel14-baseline/turbbit-src-f9b4006.zip`
  - SHA-256：`de8c53586e0aa42ff04f0454a2ae297246112511ba2c212d0225dc96cc989b6c`
  - 含 `project.godot`、`icon.svg`、`scripts/`、`scenes/`、`tools/`；不含 `.godot`、`_attic`、`art_test`。

### best.json

- 真实纪录备份：`_attic/2026-11-14/feel14-baseline/best.json`
- 当前 MD5：**067DEB9A71A19C2F6F9F6DC41FEABF09**
- 备份 MD5：**067DEB9A71A19C2F6F9F6DC41FEABF09**
- 内容：`best_score=9870, best_time=239.796160000161, best_accidents=0, best_streak=54`
- 回归跑圈写入的 12250 已由 `_restore_best` 还原；没有把自动成绩当玩家纪录。

## 2. 试玩版本

### 导出包

- 路径：`build/FEEL-14/TurbbitBro.exe`
- 大小：106 MiB
- SHA-256：`b41e37e88672bbdc9dced110c927bda9c9e6c1a0396bea72726dba93e66eeaf2`
- 构建：Godot 4.7 Windows Desktop release，`binary_format/embed_pck=true`
- 冒烟：`TurbbitBro.exe --headless --quit` 退出码 0，无脚本错误；`--headless -- --autoplay` 实际加载 race 场景并输出 9 条食物抽签，无报错（`feel14/logs/_f14_exe_autoplay.log`）。
- 导出排除：`art_test/`、`docs/`、`_attic/`、`screenshots/`、`stage*/p0*/feel1*/producer*/font_probe/tubo_cutout*/rescue_air_probe` 测试场景。
- 构建说明：`build/FEEL-14/README.txt`

### 直接运行项目

```powershell
D:\Godot_v4.7-stable_win64_console.exe --path D:\GAMESTUDIO\TURBBIT
```

- 1920×1080：`--resolution 1920x1080`
- 全屏：`--fullscreen`

### 正式入口

- 主菜单代码只建 **开始游戏 / 设置 / 退出** 三个主按钮；设置里只有语言/返回，退出有二次确认。
- `menu.gd` 里仍留有一个未接线的 `_on_producer()` 死函数，但 `_build_ui()` 没有创建制作人按钮；玩家菜单和导出包都没有入口。
- 截图：
  - `screenshots/feel14-menu-window.png`（1600×900）
  - `screenshots/feel14-menu-1920.png`（1920×1080）
  - `screenshots/feel14-menu-fullscreen.png`（2560×1440）
- `stage4_menu_input`（窗口化）：PASS（Start / Retry / Main Menu / Play Again 鼠标路径）。
- HUD 1920/全屏实际截图：`screenshots/feel14-race-1920.png`、`screenshots/feel14-race-fullscreen.png`。

## 3. 试玩记录模板

- 中文逐轮表：[FEEL-14-PLAYTEST-TEMPLATE.md](../../playtest/FEEL-14-PLAYTEST-TEMPLATE.md)
- 汇总 CSV：[feel14-playtest-log.csv](../../playtest/feel14-playtest-log.csv)
- 制作人指南：[FEEL-14-PRODUCER-GUIDE.md](../../playtest/FEEL-14-PRODUCER-GUIDE.md)

模板覆盖：轮次/角色/操作方式；事故位置与组编号/类型；SHIFT；CARROT GUARD；BITT 救援方向/开始位置/成功失败；OVERDRIVE 触发与效果；不自然/重复/难懂/无聊 30 秒/特别有趣；1–5 评分与自由备注。只记录，不改游戏。

## 4. 快捷测试入口（不在玩家菜单）

`res://scenes/feel14_probe.tscn`：

| 参数 | 用途 | 验证 |
|---|---|---|
| `--z3` | Z3 末段 G43–G55 快速起点（x≈52000，正式 55 组不变） | PASS |
| `--catch-front` | BITT 从 TUBO 前方接近救援 | PASS |
| `--catch-back` | BITT 从 TUBO 后方追赶救援 | PASS |
| `--guard` | 低梁前 TUBO 护盾练习 | PASS |

启动示例：

```powershell
... --path D:\GAMESTUDIO\TURBBIT res://scenes/feel14_probe.tscn -- --z3
```

这些场景**不在玩家菜单**，也没有进入导出包；只摆起点，不改障碍、数值、键位或角色能力。

## 5. 试玩前回归

- 两圈完整自动跑圈：run1 **55/55、0 事故**；run2 Retry **55/55、0 事故**；`STAGE3 PLAYTEST: PASS`。
  - 证据：`docs/reports/stage3-run.log`、QA 记录 `feel14/logs/_f14_playtest.log`。
- 全量 solution audit：55/55 设计答案正确、`no_solution=[]`（FEEL-13 证据，本次未改赛道）。
- 氧气 1920×1080：3/2/1/0 全对，`OXYGEN 1920: PASS`。
- 菜单/流程：`stage4_menu_input` PASS；`stage4_flow` PASS；主菜单三按钮截图为证。
- 关键操作与 HUD：正式比赛 HUD 在 window/1920/fullscreen 启动截图中正常；氧气气泡随 TUBO。

## 6. 改动边界

本轮只做试玩准备：

- 新增 `export_presets.cfg`、`build/FEEL-14/`（导出包 + README）。
- 新增 `docs/playtest/` 模板与指南。
- 新增 `scenes/feel14_probe.tscn` + `scripts/test/feel14_probe.gd`（仅命令行调试入口，不在玩家菜单/导出包）。
- 新增 `_attic/.gdignore`：FEEL-13 把旧版 `level_data-before.gd` 备份在 `_attic`，Godot 扫描到第二个 `class_name LevelData`，正式菜单会编译失败；`.gdignore` 让 Godot 不再扫描 `_attic`。这是运行修复，不改比赛逻辑。
- 未修改 55 组、角色能力、数值、键位、正式菜单按钮、结算逻辑。
- 若后续试玩发现必须改比赛逻辑：停止并报告原因，不自行继续。

## 7. 停止状态

- 试玩版本已准备，**立即停止，等待制作人试玩**。
- 不推进 Stage 5，不宣布内容冻结。
- 自动化回归通过不等于趣味性通过；趣味性结论留给制作人。
