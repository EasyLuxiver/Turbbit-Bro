# G14 — 截图工具不再覆盖历史证据（`--capture-boost` 写死文件名）

日期：2026-11-13（05:54 起）
改动：`scripts/race.gd`（`_capture_boost()` 改为认 `-- --capture-boost <文件名>`）
恢复：`screenshots/stage2_boost.png` 从 `.godot/imported/*.ctex` 还原（lossless）
工具：`tools/restore_ctex.gd`（一次性恢复脚本，见下）

## 为什么做这一条

G13 做取证扫描时，我拿 `--capture-boost` 去拍一张临时图，结果它**不认我传的文件名**：
`_capture_boost()` 里写死 `_save_shot("stage2_boost.png")`。于是这一次运行把
2026-11-10 Phase 2 的证据图直接覆盖成了当前构建的截图——文件名没变、内容变了，
`docs/reports/STAGE-2.md` 引用的还是这张图。这比“拍错画面”更严重：**历史证据被悄悄换掉**。

## 做了什么

1. `_capture_boost()` 改成和其他 capture 钩子一致：
   `_save_shot(_arg_after(args, "--capture-boost", "stage2_boost.png"))`。
2. 恢复原图：`screenshots/stage2_boost.png` 的 Godot 导入缓存在
   `.godot/imported/stage2_boost.png-*.ctex`（mtime 2026-11-10 20:53，`compress/mode=0`，lossless）。
   用 `tools/restore_ctex.gd` 把它读回来存成 PNG。

## 恢复是不是“像”原图

不是相似，是**同一个文件**：`.ctex` 旁边的 `.md5` 记着 `source_md5="96ae3af9..."`，
恢复后的 PNG 计算出来正好是 `96ae3af93b037c46ab6b8a435d1c6137`。
打开看也确认是 Phase 2 的旧 HUD（英文 `CONTROL RABBIT / SPEED 265 px/s BOOST`、
`BOOST LANE - RISK / REWARD`、旧版底部键位行），不是今天的双语面板。

## 证据

| 验收点 | 读数 |
|---|---|
| 认命令行文件名 | `-- --capture-boost rebuild05-boost.png` → `CAPTURE .../rebuild05-boost.png` |
| 不再动历史文件 | 同一命令跑完，`stage2_boost.png` md5 仍是 `96ae3af93b037c46ab6b8a435d1c6137` |
| 原图恢复 | 恢复前 md5 `6daf5408...`（我误拍的），恢复后 `96ae3af9...` = `.ctex` 的 `source_md5` |
| 打开看过 | 是旧 HUD，不是当前构建 |

其他 capture 钩子顺带查了一遍：`_save_shot` 里剩下的写死名字只有
`phase-m_%s_block.png`（参数是 rock/gate 档位，不是文件名）和 `stage4_poseg_%s.png`
（姿态证据固定名），都不是“会被日常取证覆盖的历史文件”。

## 回归

- 两圈 `fullrun-g14.log`：run1 272.9 s / run2 272.8 s、9770、S、55/55、0 事故、
  `STAGE3 PLAYTEST: PASS`，FINISH/总结行与 `fullrun-g12.log` 逐字相同。
- 21 场景批量 `reg-g14-*.log`（stage1_selftest … stage5_g11_showtime_capture）：
  全部 exit=0、0 条失败行、0 条 SCRIPT ERROR。
- `best.json`：批量退出后 md5 `c322f9a20321c5b618f98db7e4120969`（283.961389454381 /
  3150 / 54 / 0）。注意中途会有测试成绩短暂写进去（例如 `stage1_selftest` 的瞬移冲线会
  写 0.02 s），**必须等整个批量退出后**再看 md5；中途读到的不算。

## 已知限制

- 这次能原样恢复，是因为导入缓存还在、且是 lossless。**如果那次覆盖之后又触发过一次
  重新导入**，`.ctex` 会被换成新图，原图就真丢了。以后新增 capture 钩子一律走
  `_arg_after(...)` 取文件名。
- `tools/restore_ctex.gd` 是一次性恢复工具（写死了那一个 `.ctex` 路径），不参与游戏运行；
  留着是为了这条恢复可复现，不是通用功能。
- `--capture-boost` 这个名字本身已经过时：Phase O 之后加速带不再提供“进带自动提速”
  （`scripts/systems/level_data.gd:314`），`BOOST_LANES` 现在只是食物出现的锚点。
  所以这条命令拍到的是路边/食物提示，**不是 TURBO 状态**；要拍加速用 `--capture-snack`。
  本次只修“写死文件名”，没有改它的取景——重做取证脚本是另一件事，没在收尾前顺手改。
