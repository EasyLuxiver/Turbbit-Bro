# G10 — 首次教学按“先来后到”：更远的障碍不再抢底栏

日期：2026-11-13（05:22 起）
改动：`scripts/race.gd`（`_update_lessons()`：一帧只发最近的一组，且最近的障碍
组尾 +80 px 之前不发更远的新类型）、`scripts/systems/tuning.gd`（`LESSON_CLEAR_BEHIND`）
探针：`scripts/test/stage5_g10_lesson_order.gd` + `scenes/stage5_g10_lesson_order.tscn`（新）
数据：`rebuild05-g10-lesson-order.json`
截图：`screenshots/rebuild05-coop_audit_{prepare,now,missed}.png`（修前）、
`screenshots/rebuild05-coop_g10_{prepare,now,missed}.png`（修后）

## 为什么做这一条

看正式场景的截图时发现的：Z1 的 log1（x=6400，第一次 BRO DIVE）逼近时，
下一组 shark1（x=7250）也在 1100 px 教学范围内、同样“没教过”。
旧 `_update_lessons()` 在同一帧给范围内每个没见过的类型都发一次教学，
**后发的（更远的）盖掉先发的**，于是：

- 左上引导条：`BRO DIVE 现在！`
- 底部底栏：`SHIFT + ↑ 乌龟跃起` ← 鲨鱼的教学，方向正好相反

两句话同屏、动作相反。按底栏照做的玩家会按 ↑，直接错过 log1 的下潜。
修前截图 `rebuild05-coop_audit_now.png` / `_missed.png` 都拍到了这一幕。

## 做了什么

`_update_lessons()` 两点变化：

1. **一帧只发一组**：发完 `return`，不再让后面的更远类型覆盖（原来按
   `hazard_groups` 的时间顺序遍历，最后一组就是最远的一组）。
2. **最近的那组没过完就不教更远的**：先求 `frontier`（所有组里
   `group_end + LESSON_CLEAR_BEHIND − turtle.x` 的最小正值），只有候选组的同一个量
   `<= frontier` 才允许发教学。`LESSON_CLEAR_BEHIND = 80 px`。

事故期间的让位（`GameManager.accident_state != "NONE"` 直接 return）保持原样。

## 探针读数（`rebuild05-g10-lesson-order.json`，全部 PASS）

在正式 race 场景里把乌龟按 5 px 步进扫过：

| 段 | 读数 |
|---|---|
| 5300→6500（log1 接近 + BRO DIVE 窗） | 组合教学 5320 发一次（rock2 组尾 5240+80 让出，1080 px 提前量）；**鲨鱼教学 0 次** |
| 6500→7310（越过 log1 后） | 鲨鱼教学 6515 发一次（= log1 组尾 6432 + 83），距鲨鱼 735 px；文案仍是 `prompt.leap` |
| 对照：旧循环在 x=6150 重放 | 仍会发鲨鱼教学 —— 证明探针能区分修复前后 |
| 全赛道 0→终点 5 px 扫描 | 七类各教一次，共 7 条（教学没被门禁吞掉） |

## 截图（修前 / 修后）

- 修前 `rebuild05-coop_audit_now.png`：`BRO DIVE 现在！` + 底栏 `SHIFT + ↑ 乌龟跃起`。
- 修后 `rebuild05-coop_g10_now.png`：`BRO DIVE 现在！` + 底栏 `↑ 兔子跳 → SHIFT 乌龟 → ↓ 潜`，
  同向。真实跑动里底栏此时已到期消失，也不会再出现相反动作。

两张都打开看过：其余 HUD 位置、颜色、占比没有变化。

## 回归

- 两圈全流程 `docs/reports/longrun/fullrun-g10.log`：
  ```
  FINISH run=1 time=272.9 score=9770 grade=S passed=55/55 casualties=0 show=17 streak=55
  FINISH run=2 time=272.8 score=9770 grade=S passed=55/55 casualties=0 show=17 streak=55
  STAGE3 PLAYTEST: PASS
  ```
  与 G9 后的读数一致（272.9 / 272.8），教学改动没有影响跑动时间与打分。
- `best.json` md5 `c322f9a20321c5b618f98db7e4120969`，跑前后未变。
- 批量回归 20 个场景（含新探针 `stage5_g10_lesson_order`）全部 exit 0，
  逐条见 `TBB-EXPERIENCE-REBUILD-05.md` §10.1。

## 已知限制

- 这是“不再说错”，不是“说得更早”：真实跑动里第一次 BRO DIVE 的下潜段底栏是空的，
  靠左上引导条的 `BRO DIVE 现在！` 带节奏。
- `LESSON_CLEAR_BEHIND = 80 px` 是选的：短了会在还在浮木下面时弹下一句，
  长了会把鲨鱼教学压到接近 600 px（2.7 s）。80 px 实测留下 735 px。
  QC 标准写在动手前，里面写的是“越过 log1 后（group_end+60）”，实现多留了 20 px 余量，
  鲨鱼教学实际在 group_end+83 发出——仍然满足“越过之后才发、只发一次”。
- 没有真人验证——见交付报告 §12。
