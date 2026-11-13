# G3 — 擦水不只是“兔子落水”，会说“为什么”

日期：2026-11-13（04:23 起）
改动：`scripts/race.gd`（落壳判定 `else` 分支里加一次 `hint.emit`，判定不变）、
`scripts/autoload/locale.gd`（`hint.dive_deep` 中英各一条）
探针：`scripts/test/stage5_g3_hint.gd` + `scenes/stage5_g3_hint.tscn`（新）
数据：`rebuild05-g3-hint.json`

## 为什么做这一条

B3 的实测：BRO DIVE 标准时机下一直按住 ↓ 也能落回壳上，但会擦水记一次 −100。
G2 已经把“该松手了”做成正式 HUD 上的一行金色提示；但玩家如果没跟上提示、
照样按住，**事故文案仍然只有“兔子落水”**——结果和“跳早了”“没跳”共用一句话，
玩家看不出这次是自己“壳停得太深”，也就无从改起。

按 CLAUDE.md 的有趣性检查第 3 问（操作错了有没有可见后果），
原来的后果只有分数 −100 和一次水花；G3 把原因也说出来。

## 做了什么

只加一次提示调用，判定、扣分、冷却、BRO METER 全部不动：

```gdscript
# race.gd：兔子在空中、落壳判定失败、越过水线 —— 与旧判定同一分支
elif rabbit.position.y > SURFACE_Y + 40.0 and rabbit.velocity.y > 0.0:
    if turtle.diving:
        GameManager.hint.emit(Locale.t("hint.dive_deep"))
    _trigger_accident("RABBIT_WATER")   # 不变
```

文案（zh / en）：

- `壳停得太深 - 越过木尾就该松开 ↓ 上浮接人`
- `SHELL TOO DEEP - RELEASE ↓ PAST THE LOG TO CATCH`

走的是既有 `GameManager.hint` 通道，落在左上状态区之外的底部提示行
（18 px、2.2 s），不新建面板、不加音效。

## 探针读数（`rebuild05-g3-hint.json`）

| 案例 | 构造 | `turtle.diving` | 事故 | 提示 |
|---|---|---|---|---|
| 下潜擦水 | log1 标准时机，一直按住 ↓（B3 场景） | true（擦水帧） | 1（RABBIT_WATER） | 有，HUD 文本 `壳停得太深 - 越过木尾就该松开 ↓ 上浮接人` |
| 非下潜落水 | 兔子被撞离壳，落在壳侧 220 px 外掉水 | false（全程 0 帧） | 1（RABBIT_WATER） | 无 |
| 被撞下水 | 海鸟/障碍的 `_rabbit_contact` 快路径，调用时 diving=true | true（同步设置） | 1（RABBIT_WATER） | 无 |

- 擦水发生在越过木尾 **90.3 px** 处，与 B3 的实测位置一致；
- 提示确实进了正式 HUD：`hud_visible=true`、`hud_text` 含关键词；
  中文、英文都在 1280 宽内放得下（`hud_fits / hud_fits_en = true`）；
- 第三列是关键的负向证据：`_rabbit_contact` 这条快路径根本不经过落壳判定，
  所以即使壳在主动下潜也不会说“壳停得太深”——提示只属于“落壳擦水”这一种失败。

`G3 HINT: PASS`（8 条断言全过）。

## 这条提示改变了什么

它把一次“兔子又掉水里了”变成一次可归因的失败：
玩家按住 ↓ 不放的代价从“−100 + 水花”变成“−100 + 一句告诉他下潜有终点的原因”。
和 G2 配对——G2 在越线前告诉玩家该松手，G3 在没松时告诉玩家为什么被罚，
同一个技巧点前后都有话说。它不降低难度：事故照记，提示不替代操作。

## 回归

带 G3 的两圈全流程（`stage3_playtest`，正式 `race.tscn`，13 组动态）：

```
FINISH run=1 time=272.9 score=9770 grade=S passed=55/55 casualties=0
FINISH run=2 time=272.8 score=9770 grade=S passed=55/55 casualties=0
STAGE3 PLAYTEST: PASS
```

`best.json` 跑后 md5 仍 `c322f9a20321c5b618f98db7e4120969`（制作人成绩未被覆盖）。
另复跑 `stage5_g2_release`、`stage5_f_lessons`、`stage4_bilingual` 全 PASS。
QC：`tbb-exp05-g3` 5/5 pass。

## 已知限制

- 只覆盖“壳主动下潜、兔子落壳擦水”这一种失败；其它落水（撞飞、氧气耗尽）
  仍是通用文案——这是有意的，它们的正确做法不是“松开 ↓”。
- 提示是一次性的 2.2 s 文本，和事故救援提示可能同时出现两行；
  版面能叠下（底部 VBox），但没做优先级合并。
- 没有真人验证——见交付报告 §12。
