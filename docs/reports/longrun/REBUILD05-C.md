# C — 双角色引导条与协作时机提示（接入正式 HUD）

日期：2026-11-13
改动：`scripts/ui/hud.gd`（正式 HUD，`race.tscn` 每局都会挂）、
`scripts/autoload/locale.gd`（中英文案）、`scripts/race.gd`（只加一个取证入口）。
探针：`scripts/test/stage5_c_hud.gd` + `scenes/stage5_c_hud.tscn`
数据：`rebuild05-c-hud.json`；截图 `screenshots/rebuild05-coop_*.png`

## 做了什么

**没新建 UI 层，也没加新面板。** 全部长在左上角原有的紧凑状态区里：

1. **兔子行 / 乌龟行**：受控方显示 `操控 · 动作`，待命方显示 `待命 · 稳定 / 不稳 / 神游`。
   落水时兔子行固定显示 `落水 · 等接应`（红色），**即使当前控的是乌龟**——
   以前这里会显示“待命 · 稳定”，等于告诉玩家兔子还好好待在壳上。
2. **协作机会行**（每个角色一行、16 px、缩进）：只在该角色确实是行动方时出现。
   - 浮木 → 兔子行 `BRO DIVE 准备 / 现在！ / 已错过`
   - 高墙 → 乌龟行 `BRO OLLIE 准备 / 现在！ / 已错过`
   - 另一方在有效窗口内只标 `配合`，不给金色。
3. **时机条**：一行细条，随距离填满；灰蓝=准备、金色=有效、浅红=错过。

## 时机窗口（有实测依据，不是拍脑袋）

| 连招 | 预警开始 | 有效窗口 | 依据 |
|---|---|---|---|
| BRO DIVE | 520 px | 80–300 px | `REBUILD05-B3.md`（178/180） |
| BRO OLLIE | 520 px | 150–260 px | `playful04-combo-windows.json` |

520 px 在 Z1/Z2/Z3 基速下约 2.0–2.4 s，够看清再决定；再远就属于提前剧透。

## 三条硬约束的落实

- **不持续闪烁、不倒计时**：只有三态文字 + 一根条，没有任何闪烁动画或惩罚计时。
- **不遮挡**：落在左上角既有面板内。提示出现时四块面板实测占屏 ≤ 8%（探针内断言）。
- **错过明确结束**：距离 < 有效下界时显示“已错过”；该组被记账（通过/碰撞）后整行消失。

## 探针结果

`C HUD: PASS`

- 600 px 不出现；500 px = 准备；300/200/80 px = 现在；60 px = 已错过。
- 条形随接近单调增长（4.5 → 50.0 → 72.7 → 100.0）。
- 通过后立刻消失。
- 高墙 200 px = `BRO OLLIE 现在！`，行动方是乌龟，兔子只显示 `配合`。
- 双向控制：兔子受控时兔子行 `操控`、乌龟行 `待命`；切乌龟后互换。
- 落水 + 救援：兔子行 `落水 · 等接应`、乌龟行 `操控 · 救援`，协作条自动收起。
- 中英文都非空，面板宽度 ≥ 文本最小宽度；提示可见时面板总面积 ≤ 8%。

## 正式运行证据

两圈中文主流程（headless，`res://scenes/stage3_playtest.tscn -- --zh`，退出码 0）：

```
RESULT  run1 time=272.8 score=9770 grade=S passed=55 accidents=0
RESULT  run2 time=272.7 score=9770 grade=S passed=55 accidents=0  (Retry)
RESULT  zones=[1, 2, 3]  max_accident=0.00s  max_stuck=0.0s  failures=0
STAGE3 PLAYTEST: PASS
```

`best.json` 跑前跑后 md5 均为 `c322f9a20321c5b618f98db7e4120969`（未覆盖）。

窗口化截图（`res://scenes/race.tscn -- --capture-coop coop`，正式 race 场景）：

| 文件 | 距离 | HUD 读到 |
|---|---|---|
| `screenshots/rebuild05-coop_coop_prepare.png` | 500 px | `BRO DIVE  准备`，条形深色未满 |
| `screenshots/rebuild05-coop_coop_now.png` | 200 px | `BRO DIVE  现在！`，条形金色约 73%，乌龟行 `配合` |
| `screenshots/rebuild05-coop_coop_missed.png` | 60 px | `BRO DIVE  已错过`，条形浅红走满 |

三张都是我自己打开看过的：提示全部落在左上角原面板内，没有盖住赛道中线、
水下区和右下 BRO METER；三种状态的文字与条形颜色可区分。

回归：`stage4_hud_layout` PASS（英文 6.175%）、`stage4_hud_priority` PASS、
`stage4_bilingual` PASS、`stage4_hud_score` 44 项 PASS。
`stage4_hud_contrast` 需要真实窗口采样像素，headless 超时 → 不算回归失败，未在本轮重跑。

## 没做的事

- 没有真人试玩；以上全部是探针 + 截图。
- 没有做音效、插图、新素材（素材仍冻结）。
