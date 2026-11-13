# G9 — 兔子落回壳上时，壳终于有重量反应

日期：2026-11-13（05:15 起）
改动：`scripts/race.gd`（`shell_dip_t/amp` + `_shell_dip()` / `shell_dip_offset()`，
`_apply_carry_result` 的 pickup / rescue 两个分支各触发一次，`_draw_turtle` 画法偏移）、
`scripts/systems/tuning.gd`（`SHELL_DIP_TIME` 与三档幅度）
探针：`scripts/test/stage5_g9_shell_dip.gd` + `scenes/stage5_g9_shell_dip.tscn`（新）
截图：`scripts/test/stage5_g9_capture.gd` + `scenes/stage5_g9_capture.tscn`（新）
数据：`rebuild05-g9-shell-dip.json`

## 为什么做这一条

制作人 2026-11-11 16:09 的原话第 4 条（`PRODUCER-PLAYTEST-NOTES.md`）：

> 兔子起跳乌龟接住，但是乌龟只是切换过来了，并没有做什么动作

这一条一直标着“未解决”。G5/G7/G8 补的是**兔子**的庆祝弹跳、横幅和接人提示环——
**壳本身**从头到尾没有为“有人落在它背上”做过任何动作。日常跳跃落回壳上也一样：
只有水花（`_spawn_land_splash`），没有承重。

## 做了什么

兔子每一次回到壳上（日常落壳 + 真接住 + 救回）都走 `_apply_carry_result`，
在那里给壳一个下沉脉冲：

| 情形 | 幅度 | 判定 |
|---|---|---|
| 日常跳跃落壳（`real_catch=false`） | 7 px | 每次跳都有，所以轻 |
| 真接住（离壳抬升回来） | 11 px | 比日常重 |
| 救回 | 14 px | 最重的一拍 |

`shell_dip_offset()`：当帧最大下沉，`0.26 s` 内 `下沉 → 小幅回弹（约 1/3 幅度）→ 归零`。
**只加在 `_draw_turtle` 的 `pos.y` 上**：`turtle.position`、`get_body_rect()`、
接应距离、`can_pickup` 全部不读它。和 G4/G5 的兔子弹跳（0.34 s）错开，不同步晃。

## 探针读数（`rebuild05-g9-shell-dip.json`，20 条断言 PASS）

| 案例 | 读数 |
|---|---|
| 普通跳跃落壳 | 落壳帧即 7.0 px，第 6 帧回弹（负值），第 16 帧归零；之后 30 帧恒 0；`pickup_count` +1 |
| 真接住（200 px 抬升 25 帧） | 峰值 11.0 px，16 帧可见，有回弹，`pickup_count` +1 |
| 救回 | 峰值 14.0 px，`rescue_count` +1，事故态清空 |
| 干净下潜过礁拱 | 0.0 px（160 帧） |
| 纯巡航 | 0 帧非零 |
| 只改画法 | 触发后 12 帧位置/判定框逐字未变（区基速临时置 0 后仍不变） |

## 截图（`screenshots/rebuild05-g9-shell-dip{,_rest}.png`）

真实起跳、真实落壳，落壳后第一帧存盘；`rest` 是同场景骑乘静止的对照帧。
像素测量（绿壳区域 y 范围）：

- `_rest.png`：459–511
- 落壳帧：465–517 —— **壳整体下移 6 px**（探针读数 7.0 px，差值是采样帧的衰减）

两张图都打开看过：兔子没有跟着沉（它停在壳上方的落点），下沉的是壳和头。

## 回归

两圈全流程（`stage3_playtest`，真实 `race.tscn`，13 组动态，headless，`fullrun-g9.log`）：

```
FINISH run=1 time=272.9 score=9770 grade=S passed=55/55 casualties=0 show=17 streak=55
FINISH run=2 time=272.8 score=9770 grade=S passed=55/55 casualties=0 show=17 streak=55
STAGE3 PLAYTEST: PASS
```

`best.json` 跑后 md5 `c322f9a20321c5b618f98db7e4120969`：内容仍是
`best_score 3150 / best_time 283.961389 / best_accidents 0 / streak 54`。
批量回归 19 个场景（18 + 本项 `stage5_g9_shell_dip`）结果见
`TBB-EXPERIENCE-REBUILD-05.md` §10.1。

## 已知限制

- 是画法偏移，不是物理弹簧：壳不会真的被压扁，只是一段位移 + 回弹。
- 只看得到下沉，没有声音（音频冻结）。
- 没有真人验证——见交付报告 §12；这一项解决的是“壳没有任何动作”，
  不代表制作人会因此觉得“配合更有趣”。
