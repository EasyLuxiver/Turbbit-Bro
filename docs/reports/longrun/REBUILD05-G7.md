# G7 — 「好接！」只给真正的接住

日期：2026-11-13（05:0x 起）
改动：`scripts/race.gd`（`_apply_carry_result(kind, real_catch := true)`；
日常落壳那一处传 `false`：不再发 `pickup_success`、不再弹 G5 的庆祝跳；
`pickup_count` 仍照旧 +1，统计与结算语义不变）
探针：`scripts/test/stage5_g7_banner.gd` + `scenes/stage5_g7_banner.tscn`（新）
数据：`rebuild05-g7-banner.json`

## 为什么做这一条

G5 修“日常落壳不该弹一下”时发现了同一个根因的第二处：普通跳跃落回壳上走的也是
`_apply_carry_result("pickup")`，而它会 `emit(pickup_success)`，横幅接上这个信号
就显示 2 s 的「好接！」。

也就是说：**每跳一次，右上角就会说一次“好接”**。接人本来是稀有、值得骄傲的一刻，
被日常落地的刷屏稀释成背景噪音；真正的接住和普通跳跃在反馈上完全一样。

## 做了什么

```gdscript
func _apply_carry_result(kind: String, real_catch := true) -> void:
	if kind == "pickup":
		GameManager.pickup_count += 1          # 计数语义不变（stage1 的验收依赖它）
		_spawn_land_splash(rabbit.position)    # 落地水花保留，这是“落地”的反馈
		if real_catch:
			GameManager.pickup_success.emit()  # 「好接！」
			_celebrate("pickup")               # G5 的弹跳
```

只有日常落壳一处传 `false`；深接抬升回壳、救回都不变。

## 探针读数（`rebuild05-g7-banner.json`）

| 案例 | 横幅 | `pickup_success` | `pickup_count` |
|---|---|---|---|
| 普通跳跃（整段滞空 + 落地） | 空 | 0 次 | +1（不变） |
| 真正的接住（离壳 200 px 抬升） | 「好接！」 | 1 次 | +1 |
| 救回 | 「获救」 | —（rescue_done 1 次） | — |

`G7 BANNER: PASS`（8 条断言）。

## 这条改动改变了什么

以前“好接”是对落地说的，现在只对“接住”说。信息量变了：看到「好接！」就意味着
刚才确实救回了一次，而不是又跳了一下。落地本身还有水花，动作反馈没有丢。

## 回归

带 G7 的两圈全流程（`stage3_playtest`，正式 `race.tscn`，13 组动态，`fullrun-g7.log`）：

```
FINISH  run=1 time=272.9 score=9770 grade=S passed=55/55 casualties=0 engine=0 show=17 streak=55
FINISH  run=2 time=272.8 score=9770 grade=S passed=55/55 casualties=0 engine=0 show=17 streak=55
STAGE3 PLAYTEST: PASS
```

`best.json` 跑前跑后 md5 均为 `c322f9a20321c5b618f98db7e4120969`
（`best_score 3150 / best_time 283.961389 / best_accidents 0 / streak 54`）。
另跑 17 场景批量回归：16 个 exit 0；`stage1_selftest` exit 1，失败在
“pickup window shown during landing”——与本条改动无关（G7 只动 `real_catch` 与计数），
是 PLAYFUL-04 落壳分支把 `pickup_window` 同帧清掉导致的旧回归，见 `REBUILD05-G8.md`。
QC：`tbb-exp05-g7` 5/5 pass。

## 已知限制

- 只改了横幅与庆祝的触发点；`pickup_count` 仍把日常落壳算作一次 pickup，
  所以结算/统计里的“pickups”含义仍是“落回壳上的次数”，不是“救援次数”
  （救援另有 `rescue_success_count`）。
- 没有真人验证——见交付报告 §12。
