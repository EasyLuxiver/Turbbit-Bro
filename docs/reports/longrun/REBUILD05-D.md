# D — SHIFT 正向体验

日期：2026-11-13
改动：`scripts/race.gd`（接回壳上的那一拍加奖励与重聚反馈）、
`scripts/systems/tuning.gd`（`RESCUE_SWITCH_BONUS`）、`scripts/autoload/locale.gd`（一句新文案）。
探针：`scripts/test/stage5_d_shift.gd` + `scenes/stage5_d_shift.tscn`
数据：`rebuild05-d-shift.json`

## 结论先说

三种正向切换都成立，而且**各有各的一拍**，不是同一句“好棒”：

| 动机 | 玩家做的动作 | 拿到什么 | 探针读数 |
|---|---|---|---|
| 障碍协作 | 兔子起跳 → SHIFT → 乌龟 ↓ | `BRO DIVE！` + 250 分 + 青色环；高墙是 `BRO OLLIE！` + 300 分 | 既有连招逻辑，本轮未改 |
| 食物 | SHIFT 到乌龟亲手喂 | `TURBO！亲手喂到！乌龟很满足！` + 30 分；不切也照样吃、照样 ×1.15 | 两例 `boost_speed` 同为 253.0，只差那 30 分 |
| 救援 | 兔子落水 → SHIFT → 按住 ↓ 追接 | `接住了！兄弟！` → 回壳那一拍 `兄弟回来了！` + 50 分，两人神游清零 | `score_reasons=[mistake:RABBIT_WATER, rescue_switch]`，`drift_after=0.0/0.0` |

**只加不减。** 不亲手喂：少 30 分，加速与吞食反馈不变（`score_delta=+0`、无负项）。
不追接：落水那一次事故照记，但没有新增任何“没换人”的罚项——
失败的 BRO DIVE 只记 `mistake:TURTLE_DIVE_LATE` 一条。

## 本轮真正改的一处

以前接回壳上是“事故结束”，没有奖励，也没有“兄弟回来了”这一拍。
现在 `_apply_carry_result("rescue")` 里加三样：

1. `+50`（`RESCUE_SWITCH_BONUS`，`score_reasons` 里叫 `rescue_switch`）。
2. 一句 `兄弟回来了！右边这口气补上了`（zh）/ `BRO'S BACK! BOTH OF YOU CALM DOWN`（en）。
3. 两人 `brain.calm()`——重聚本身就把神游清掉，这是有玩法意义的正反馈。

`rescue_return`（没接住、被冲回壳上）**不加**奖励，也不改账：失败就是失败。

## 神游（D3）

沿用四态，没有第五个状态。两只角色各跑 12 s 无人控制（乌龟钉在原地，
只观察“神游本身会不会记账”）：

| 角色 | 四态到达 | 事故 | BRO METER | 负分项 |
|---|---|---|---|---|
| 乌龟 | 0.02 / 3.02 / 6.02 / 9.00 s | 0 | 0 | 无 |
| 兔子 | 0.02 / 3.02 / 6.02 / 9.00 s | 0 | 0 | 无 |

**一处有意保留的例外**：兔子在 MISCHIEF 且接近低梁/海鸟时会站起来探头，
会擦到梁 3 px（`stage4_partner_neglect` 断言、`PHASE-SHIFT-CORE` 定稿）。
这是上一阶段定下的“疏忽有代价”，只记失衡/硬直、不落水，本轮按任务书 A7
“不删除现有系统”保留，没有改成纯视觉。它与 D2 的“不切换不额外惩罚”
有张力：我的判据是“D2 管的是奖励与高光，伙伴自主与后果是另一根支柱”，
两者都在，且都能从 HUD 行读到。

## 没做的事

- 没有真人试玩；以上全部是探针读数。
- 没有新增音效/美术（素材仍冻结）；重聚反馈是 HUD 文字，不是演出。
- 没有改神游四态的时长与阈值。
