# G4 — 连招成功时，角色本体也动一下

日期：2026-11-13（04:36 起）
改动：`scripts/race.gd`（`celebrate_t` 计时器 + `celebration_offset()` 画法偏移；
只在 `_trigger_action_fx()` 里开始计时，只在 `_draw_rabbit()` 里使用）
探针：`scripts/test/stage5_g4_cheer.gd` + `scenes/stage5_g4_cheer.tscn`（新）
数据：`rebuild05-g4-cheer.json`

## 为什么做这一条

事故端的灰盒表演已经有了（落水耳朵打转 + X 眼 + 水花圈、翻肚皮 + 晃动、
第三格原地抖 + 闪白），但**成功端只有特效环和文字**：BRO DIVE / BRO OLLIE
做成时，环亮一下、字飘一下，两只角色本体一动不动。
连招是这游戏的核心幻想，做成了却只有 UI 在庆祝，角色像没参与。

这条只补角色本体的一下弹跳——不改判定、不加音效、不加新素材。

## 做了什么

```gdscript
# race.gd
const CELEBRATE_TIME := 0.34
const CELEBRATE_HOP_PX := 12.0

func _trigger_action_fx(kind, p):   # 连招成功时已有的入口
    ...
    celebrate_kind = kind
    celebrate_t = 0.0               # 重新成功会重新计时

func celebration_offset() -> Vector2:
    var k := celebrate_t / CELEBRATE_TIME
    return Vector2(0.0, -sin(PI * k) * CELEBRATE_HOP_PX)   # 零 → 峰值 → 零
```

`_draw_rabbit()` 把它和已有的 SHIFT 抖动偏移加在一起：

```gdscript
var pos := rabbit.position + _shift_jolt_offset("rabbit") + celebration_offset()
```

`rabbit.position` 完全不动，所以物理、碰撞、接应、自动驾驶读数都不受影响。

## 探针读数（`rebuild05-g4-cheer.json`）

| 案例 | 触发 | 峰值位移 | 非零帧 | 归零 | 事故 |
|---|---|---|---|---|---|
| BRO DIVE（log1，跟提示松手） | `kind=dive` | **12.0 px** | 19 帧 | 第 21 帧（0.35 s） | 0 |
| BRO OLLIE（wall1，墙前 60 px 蹬踏） | `kind=ollie` | **12.0 px** | 19 帧 | 第 21 帧（0.35 s） | 0 |

对照：

| 不该触发 | `celebrate_t` | 峰值 |
|---|---|---|
| 普通跳跃 | −1.0 | 0.0 px |
| 礁拱干净下潜（不是连招） | −1.0 | 0.0 px |

- 只改画法：连续调用 `celebration_offset()` 前后 `rabbit.position` 逐位相同
  （`position_unchanged_by_offset=true`）；
- 重新成功会重新计时：第一次触发后 0.1 s 再触发，计时回到 0.0（`reset=true`）。
- `G4 CHEER: PASS`（9 条断言全过）。

## 这条表演改变了什么

以前“做成了连招”的证据在屏幕边缘：一个环、一行字、分数跳一下。
现在两只角色在成功的那 0.34 s 里真的弹一下——玩家视线在角色身上时也能收到
“这一下做对了”的反馈，不用回头读 UI。它很便宜（两行画法偏移、零新素材），
也不会把失败演成成功：只有连招成功才触发，普通跳跃与干净通过都不动。

## 回归

带 G4 的两圈全流程（`stage3_playtest`，正式 `race.tscn`，13 组动态，`fullrun-g4.log`）：

```
FINISH run=1 time=272.9 score=9770 grade=S passed=55/55 casualties=0
FINISH run=2 time=272.8 score=9770 grade=S passed=55/55 casualties=0
STAGE3 PLAYTEST: PASS
```

`best.json` 跑前跑后 md5 均为 `c322f9a20321c5b618f98db7e4120969`
（`best_score 3150 / best_time 283.961389 / best_accidents 0 / streak 54`）。
另复跑 `stage5_e3_ollie`、`stage5_g2_release`、`stage4_core_experience` 全 PASS。
QC：`tbb-exp05-g4` 5/5 pass。

## 已知限制

- 只有连招成功（浮木/高墙）有；普通跳跃、吃海藻、接人成功没有对应表演。
- 位移固定 12 px，没有按体型/速度缩放；乌龟本体不参与（只有兔子弹）。
- 没有截图（0.34 s 的瞬时动作，headless 截不到）；证据是探针读数与两圈回归。
- 没有真人验证——见交付报告 §12。
