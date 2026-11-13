# G5 — 接人与救回成功时，角色也弹一下

日期：2026-11-13（04:5x 起）
改动：`scripts/race.gd`（`_celebrate(kind)` 抽成共用函数；`_apply_carry_result` 的
pickup / rescue 两条成功分支各调一次）
探针：`scripts/test/stage5_g5_carry.gd` + `scenes/stage5_g5_carry.tscn`（新）
数据：`rebuild05-g5-carry.json`

## 为什么做这一条

G4 只让连招成功有角色本体的反应。盘了一遍成功端还剩下什么：

| 事件 | 已有的反馈 | 角色本体动吗 |
|---|---|---|
| 连招（BRO DIVE / OLLIE） | 环、文字、分数、G4 弹跳 | 是 |
| 吃海藻 | 食物飞进乌龟嘴、泡泡翻倍、TURBO 行、速度线 | 不用加——食物本身在动，再加就重复 |
| 接人成功 | 横幅「好接！」、落地水花 | **不动** |
| 救回落水兔子 | 横幅、重聚文字、+50 | **不动** |

接人和救回是这游戏最“兄弟”的两个瞬间，却只有屏幕上的字。补上同一套 0.34 s
弹跳，不新增素材、不改判定。

## 做了什么

```gdscript
func _celebrate(kind: String) -> void:   # G4 的两行抽出来，G5 复用
	celebrate_kind = kind
	celebrate_t = 0.0

# _apply_carry_result("pickup")
_celebrate("pickup")
# _apply_carry_result("rescue")
_celebrate("rescue")
```

弹跳只落在「抬升结束、真正算成功」的那一帧：落水被抓回的当帧兔子还在水里，
不动；没接住的 `rescue_return` 恢复路径也不庆祝。

## 探针读数（`rebuild05-g5-carry.json`）

抬升走的是真实 `_begin_carry`（兔子放在离壳 200 px，逐帧插值 25 帧才落壳）：

| 案例 | 触发种类 | 峰值 | 非零帧 | 归零 | 计数变化 | 事故 |
|---|---|---|---|---|---|---|
| 接人 | `pickup` | 12.0 px | 19 帧 | 第 21 帧 | pickup +1 | 0 |
| 救回 | `rescue` | 12.0 px | 19 帧 | 第 21 帧 | rescue +1 | 0 |

对照（都不动，峰值 0.0 px）：普通跳跃、礁拱干净下潜、没接住的 `rescue_return`。
`position_unchanged_by_offset=true`；`G5 CARRY: PASS`（13 条断言）。

## 补记：日常落壳不弹（第一版漏了）

第一版把所有 `_apply_carry_result("pickup")` 都当成功：但普通跳跃落回壳上走的也是
这条记账路径（`_tick_rabbit` 的 AIRBORNE→RIDING 分支），于是每次跳跃落地都会多弹一下。
当时探针的“普通跳跃”对照只跑了 40 帧，而跳跃滞空约 72 帧（2×630/1050 s），
落地发生在对照结束之后，所以没测出来。

修法：`_apply_carry_result(kind, real_catch := true)`，只有日常落壳那一处传 `false`；
真正的接住（深接、抬升回壳）与救回仍然庆祝。探针的对照延长到 150 帧并断言
`jumped=true /\ landed=true /\ peak=0`（`plain_jump` 现已覆盖整段滞空与落地）。
（这个参数随后在 G7 里一并接管了「好接！」横幅的触发，见 `REBUILD05-G7.md`。）

## 这条表演改变了什么

以前接住和救回只体现在横幅和分数上；现在抱回壳上的那一下角色本体会弹起 12 px，
和 G4 的连招成功是同一个语言。接人、救回、连招三种成功现在都有“本体动了一下”，
吃海藻用食物飞进嘴里表达，不再额外加。

## 回归

带 G5 的两圈全流程（`stage3_playtest`，正式 `race.tscn`，13 组动态，`fullrun-g5.log`）：

```
FINISH  run=1 time=272.9 score=9770 grade=S passed=55/55 casualties=0 engine=0 show=17 streak=55
FINISH  run=2 time=272.8 score=9770 grade=S passed=55/55 casualties=0 engine=0 show=17 streak=55
STAGE3 PLAYTEST: PASS
```

`best.json` 跑前跑后 md5 均为 `c322f9a20321c5b618f98db7e4120969`
（`best_score 3150 / best_time 283.961389 / best_accidents 0 / streak 54`）。
QC：`tbb-exp05-g5` 5/5 pass。

## 已知限制

- 只有兔子弹；乌龟不动。
- 弹跳幅度固定 12 px，未按事件轻重区分（救回和接人同幅度）。
- 无截图（0.34 s 瞬时动作，headless 截不到）。
- 没有真人验证——见交付报告 §12。
