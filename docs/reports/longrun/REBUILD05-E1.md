# E1 — 海鸟重做：画出来的位置就是判定的位置

日期：2026-11-13
改动：`scripts/race.gd`（`bird_pose()` 成为姿态与判定的唯一来源；`_draw_bird` 改成按 pose 画）
探针：`scripts/test/stage5_e1_bird.gd` + `scenes/stage5_e1_bird.tscn`
数据：`rebuild05-e1-bird.json`

## 原来的问题（不是“不好看”，是“读不出来”）

旧版海鸟有两个互相独立的问题，叠在一起就成了“明明没碰到还是撞了”：

1. **俯冲提前两秒完事**。旧画法按固定时间轴播下潜，玩家还在 400 px 外它就已经
   扎到水面高度悬停；等玩家真的走到那一列，画面上是一只看不出要动的鸟，
   判定却是一堵静止的 144 px 高墙。
2. **画的比判的窄**。鸟身只有 68 px 宽、居中在 120 px 宽的判定带里，
   从带子边缘擦进去的兔子会被一段**画面上不存在**的区域打中。

探针把这两件事直接量了出来：修之前 `hit_but_not_drawn = 10`。

## 改法：一个函数同时喂画和判定

`bird_pose(group, now_t)` 按“鸟离玩家还有多远（d）”返回整只鸟的姿态：
`band / phase / y / tilt / strike_y / high_y / flare / wing_top / wing_bottom / span_x / body_*`。

- 俯冲段（d 240→0）和玩家跨过这一列是**同一段时间**，所以不存在“提前扎完再等”。
- 翅膀的横向张开 `span_x` 在攻击段涨到 `band.size.x / 2 + 2`，展开的两片翼膜
  正好铺满判定带的左右两端和 2 px 内——在带里被撞，画面上一定有一片翅膀盖着你。
- 四段节奏仍然是 CRUISE → TELEGRAPH → DIVE → STRIKE → RECOVER，前摇期高位亮“！”
  并把落点竖线拉到攻击带。

## 探针读数（正式 `race.tscn` 场景，三组海鸟）

| 组 | 节奏顺序 | 隐形墙 | 画了不打 | 蹲下被扫到 | 站立接触采样 |
|---|---|---|---|---|---|
| bird1 | 正确 | 0 | 0 | 0 | 29 |
| bird3 | 正确 | 0 | 0 | 0 | 29 |
| bird4 | 正确 | 0 | 0 | 0 | 27 |

俯冲空域（世界 130～234）沿整段扫过：**最大空洞 0 px**——没有一段是“看不见的墙”。

`E1 BIRD: PASS`

## 证据

- 数据：`docs/reports/longrun/rebuild05-e1-bird.json`
- 截图（窗口化，`--capture-bird`）：`screenshots/rebuild05-bird_{telegraph,dive,strike,recover}.png`
- 回归：`stage2_selftest` PASS（顺带把旧用例 200 px 起跳改成 B3 实测的 160 px，
  旧值会让兔子落回浮木上沿，是真实碰撞不是误判）；
  `stage4_bird_routes` crouch 42/42、jump 0/42、dive 60/62、leap 0/42。

  勘误（G20 重跑）：本文原写 “jump 41/42、leap 42/42” 作废。G20 给探针补清
  `hit_roles` 后发现，旧数字从第二次试次起测的是“已免疫、撞不上”的赛道。
  低飞海鸟只压兔子那一层，跳/跃起把头送进鸟里本来就该撞；只有趴低能过。
  dive 的 62/62 也改为 60/62（两档极端提前量下兔子仍撞鸟）。详见 `REBUILD05-G20.md`。

## 没做的事

- 没有真人试玩；以上全部是逐像素探针读数 + 我自己看过的截图。
- 没有新增美术/音效：鸟仍然是 Polygon/Line 画的灰盒，整段可替换。
