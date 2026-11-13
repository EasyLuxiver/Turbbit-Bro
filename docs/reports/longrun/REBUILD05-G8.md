# G8 — 接人提示环真正看得见（落壳走廊）

日期：2026-11-13（05:0x 起）
改动：`scripts/race.gd`（AIRBORNE 段把“显示”与“收人”拆开；`_draw` 的
「接住了！」文字只在吸附区出现）、`scripts/systems/tuning.gd`（新增
`PICKUP_HINT_DY_MIN := -150.0`）
探针：`scripts/test/stage5_g8_corridor.gd` + `scenes/stage5_g8_corridor.tscn`（新）
数据：`rebuild05-g8-corridor.json`

## 为什么做这一条

09:00 前的 17 场景批量回归里 16 个 exit 0，`stage1_selftest` exit 1，唯一失败项是
`pickup window shown during landing`。

根因不在这一轮的 G5/G6/G7：PLAYFUL-04 把落壳改成“进 `PICKUP_DY_MIN`（-60 px）
当帧吸附”，同时把 `GameManager.pickup_window` 清成 false。于是：

- 窗口在落壳那一帧才第一次为 true，同一帧就被消费；
- 探针/自检在帧后读，永远读到 false；
- 更要紧的是玩家：绿色提示环和「接住了！」只画 1 帧（16 ms），**等于不存在**。

也就是说这个提示环在 PLAYFUL-04 之后就没被人看见过，只是没人跑 stage1。

## 做了什么

显示与判定分开，判定一行没动：

```gdscript
var caught := not turtle.leap_active and mount.can_pickup(...)   # 原判定
GameManager.pickup_window = not turtle.leap_active \
    and rabbit.velocity.y >= 0.0 \
    and (turtle.is_at_surface() or turtle.is_rising()) \
    and absf(rabbit.position.x - mp.x) <= Tuning.PICKUP_DX \
    and dy >= Tuning.PICKUP_HINT_DY_MIN and dy <= Tuning.PICKUP_DY_MAX
if caught:
    if dy >= Tuning.PICKUP_DY_MIN:  # 当帧吸附（原样）
    else:                           # BRO DIVE 深接，连续抬升（原样）
```

- 环：下落中对准壳就从 -150 px 亮起，约 0.3 s 的提前量，用来“对着壳落”。
- 文字「接住了！」：仍只在进吸附区（-60）时出现，不提前报喜。
- 壳在水下且没上浮时两个条件都不成立，环不亮（否则等于骗玩家能接）。

## 探针读数（`rebuild05-g8-corridor.json`）

| 案例 | 读数 | 断言 |
|---|---|---|
| 普通跳跃 | 窗口连续 14 帧、起点 dy -148.8、上升段 0 帧、落壳 +1 | 走廊可见且不误报 |
| 壳下潜未上浮 | 窗口 0 帧，第 13 帧记 RABBIT_WATER | 不骗人 |
| 深接（壳水下上浮） | 深接从第 0 帧开始、抬升 11 帧落到 0 px、+1 | 判定与抬升未变 |

`G8 CORRIDOR: PASS`（8 条断言）。

## 顺带恢复的东西

`stage1_selftest` 重新 exit 0，`pickup window shown during landing` 通过
（`land -> picked=true window=true`）。这条自检从 PLAYFUL-04 起一直是红的，
本轮首次跑出来。

## 回归

带 G8 的两圈全流程（`stage3_playtest`，正式 `race.tscn`，13 组动态，`fullrun-g8.log`）：

```
FINISH  run=1 time=272.9 score=9770 grade=S passed=55/55 casualties=0 engine=0 show=17 streak=55
FINISH  run=2 time=272.8 score=9770 grade=S passed=55/55 casualties=0 engine=0 show=17 streak=55
STAGE3 PLAYTEST: PASS
```

`best.json` 跑前跑后 md5 均为 `c322f9a20321c5b618f98db7e4120969`。
18 场景批量回归（含 stage1_selftest、stage5_g5_carry、stage5_g7_banner）全部 exit 0。
QC：`tbb-exp05-g8` 6/6 pass。

## 截图（`screenshots/rebuild05-g8-corridor.png`）

`stage5_g8_capture.tscn` 把兔子摆进走廊（壳上方 100 px、正在下落）抓的一帧：
绿环画在龟壳上、兔子在环上方，`pickup_window=true dy=-95.1`。这是“对着壳落”的
提示，不是判定框。截图自己看过，环位置与壳对齐、不挡角色。

## 已知限制

- 环只是画法提示，不改变吸附；玩家不看环也照样落壳。
- 提前量固定 -150 px，没有按速度自适应；高速下落时可见时间更短。
- 没有真人验证——见交付报告 §12。
