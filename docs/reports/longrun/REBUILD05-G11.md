# G11 — Showtime 截图取证修复：截图里终于真的是 SHOWTIME

日期：2026-11-13（05:50 起）
改动：`scripts/race.gd`（`_capture_showtime()`：先关判定、传送点 5100→5300）
探针：`scripts/test/stage5_g11_showtime_capture.gd` + `scenes/stage5_g11_showtime_capture.tscn`（新）
数据：`rebuild05-g11-showtime.json`
截图：`screenshots/rebuild05-showtime.png`、`rebuild05-showtime-b.png`（修后两次独立运行）

## 为什么做这一条

本轮按“出图先自己打开看”的规矩复查 Showtime 截图时发现的：`--capture-showtime`
截出来的图里没有 SHOWTIME，只有「咚！兔子被撞晕」。

根因在截图工具自己身上：`_capture_showtime()` 把乌龟传送到 **x=5100**，
那里正是 rock2（Phase M 加了水下段、会下沉的礁）的正中间；传送后 0.2 s 内就撞上，
`start_showtime()` 有 `accident_state != "NONE"` 的门槛，于是整段表演被拒，
截到的是事故帧。文件名写着 showtime，内容却是事故——这就是“没打开看”的证据链漏洞
（本次没有把它当证据用，但同一条命令以后还会被用到）。

## 做了什么

`_capture_showtime()` 两行：

1. 传送前 `test_disable_hazards = true`——截图工具只拍表现，不带判定。
2. 传送点 `x=5100 → 5300`——rock2 组尾 5240 之后的空档，画面里不出现“壳嵌在礁里”。

**没有动玩法**：`start_showtime()` 的门槛（事故中不启动）一行没改，
探针专门断言它仍然拒绝。

## 探针读数（`rebuild05-g11-showtime.json`，全部 PASS）

| 断言 | 读数 |
|---|---|
| 事故状态下 `start_showtime()` 仍拒绝 | `refused_in_accident=true` |
| 修后的条件能启动 | `showtime_active=true`，中心横幅 `SHOWTIME！` |
| 0.45 s 时兔子离壳 | `rabbit_offset_px=51.4`（阈值 ≥40） |
| 这 0.45 s 内不产生新事故 | `accident_state=NONE` |

截图二次运行（`rebuild05-showtime-b.png`）内容与第一次一致（md5 不同，差异只来自
水花/装饰粒子的帧间随机），都拍到 `SHOWTIME！` 与离壳兔子——固定条件，不是偶然拍到的一次。

## 截图（修前 / 修后）

- 修前：`--capture-showtime` 的输出与 `check_showtime` 一样——「咚！兔子被撞晕」、
  BRO METER 1/3、进度 8%（该文件已按只搬不删规则进 `_attic/2026-11-13/`）。
- 修后 `rebuild05-showtime.png`：顶部金色 `SHOWTIME！`、兔子离壳 720° 旋转、
  右下 `SHOWTIME 1.4s 剩` 三段条、左上「兔子 操控·表演」、BRO METER 0/3。

两张都打开看过：HUD 布局、字号、对比度没有变化。

## 回归

- 两圈 `stage3_playtest`（`fullrun-g11.log`）与 `fullrun-g10.log` 逐字一致：
  `FINISH run=1 time=272.9 … run=2 time=272.8 … STAGE3 PLAYTEST: PASS`，
  55/55、0 事故、0 SCRIPT ERROR。
- 退出后 `best.json` md5 仍是 `c322f9a20321c5b618f98db7e4120969`（测试自还原）。
- 批量回归 21 个场景（G10 后那 20 个 + `stage5_g11_showtime_capture`）见主报告 §10.1。

## 已知限制

- 这是取证工具修复，**不改变玩家看到的表演**。表演本身（1.8 s、720°、收尾 pose）
  没有评价——本轮没有真人反馈。
- `docs/reports/STAGE-2.md` 引用的 `stage2_showtime.png` 是 Phase 2 的历史截图，
  未重新生成，也没有被本轮当作证据。
