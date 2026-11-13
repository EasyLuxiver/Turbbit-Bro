# G6 — 会动的障碍第一次出现时，说一句

日期：2026-11-13（05:0x 起）
改动：`scripts/race.gd`（`_update_motion_lesson()` + `motion_lesson_zone`，
在 `_update_lessons()` 的事故早退之后调用；`load_level()` 里复位）
文案：`scripts/autoload/locale.gd` `hint.motion`（中英）
探针：`scripts/test/stage5_g6_motion.gd` + `scenes/stage5_g6_motion.tscn`（新）
数据：`rebuild05-g6-motion.json`

## 为什么做这一条

G 段把动态障碍从 7 组扩到 13/55，但**没有任何教学**：Z1 的 rock3 是第一组会动的
障碍，玩家第一次看到它，是它正在上下起伏的时候——只会以为“刚才那下判定飘了”。
REBUILD05-F 的自评里“普通礁/梁/门上没有持续提示，新手第一次靠失败学会”说的就是这一类。

E3 记录过 Z3 的两对两连重复、但没有改（改顺序会挪掉食物锚点）。所以这一轮不做
排布微调，改做“让已有的 13 组动态被读懂”：不改任何位置、不改判定，只加一条说清
“这组会动”的提示。

## 做了什么

```gdscript
const MOTION_HINT_RANGE := 560.0     # Z1 速度下约 2.5 s，提示 2.2 s 正好跟到跟前
var motion_lesson_zone := -1

func _update_motion_lesson() -> void:
	for g in hazard_groups:
		var moved: Dictionary = g.get("motion", {})
		if moved.is_empty():
			continue
		# 进入 560 px 且这一区还没讲过 → 底栏报一句，然后本区不再出现
```

- 按区一次：Z1 rock3、Z2 rock4、Z3 shark6 各一句（Z3 事故控制里读的就是 shark6）。
- 事故期间走 `_update_lessons()` 的早退，不抢救援提示；事故结束后那一组还在范围内
  就补一句。
- 文案：`这组会动 - 看准空隙再上` / `THIS ONE MOVES - GO THROUGH THE GAP`（底栏 2.2 s）。

## 探针读数（`rebuild05-g6-motion.json`）

| 案例 | 结果 |
|---|---|
| Z1 第一组动态（rock3） | 进入 556.3 px 时出现 1 次，指向 rock3 |
| Z2 第一组动态（rock4） | 进入 560.0 px 时出现 1 次，指向 rock4 |
| Z2 一程连跑 rock4 → shark3 | 只有 1 次，且来自 rock4（shark3 不再报） |
| 静态组（bird1） | 0 次 |
| 事故期间经过 shark6 | 事故中 0 次；事故解除后补 1 次 |
| 正式 HUD | `visible=true`，中文 「这组会动 - 看准空隙再上」；英文模板宽度放得下 |

`G6 MOTION: PASS`（11 条断言）。

## 这条提示改变了什么

13 组动态障碍以前是“动起来了，但没人告诉你它会动”。现在每区第一组进入视野时底栏
会说一句，玩家的第一反应从“判定有问题”变成“等它让开”。提示只说一次、只在每区第一次，
不常驻、不重复刷屏。

## 回归

带 G6 的两圈全流程（`stage3_playtest`，正式 `race.tscn`，13 组动态，`fullrun-g6.log`）：

```
FINISH  run=1 time=272.9 score=9770 grade=S passed=55/55 casualties=0 engine=0 show=17 streak=55
FINISH  run=2 time=272.8 score=9770 grade=S passed=55/55 casualties=0 engine=0 show=17 streak=55
STAGE3 PLAYTEST: PASS
```

`best.json` 跑前跑后 md5 均为 `c322f9a20321c5b618f98db7e4120969`
（`best_score 3150 / best_time 283.961389 / best_accidents 0 / streak 54`）。
QC：`tbb-exp05-g6` 5/5 pass。

## 已知限制

- 只说“会动”，不说是哪一种节奏（正弦上下 / 水平巡游 / 浪涌），全靠观察。
- 按区一次，玩家如果正好在看别处，2.2 s 过去就没了。
- 没有真人验证——见交付报告 §12。
