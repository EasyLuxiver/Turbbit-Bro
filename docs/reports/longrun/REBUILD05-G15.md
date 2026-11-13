# G15 — 窗口化 HUD 回归的过期断言（救援反馈是两拍）

日期：2026-11-13（06:05 起）
改动：`scripts/test/stage4_hud_score.gd`（一条断言），产品代码/文案一行未动
日志：`reg-g15-hud-score-before.log`（修前 FAIL）、`reg-g15-hud-score.log`（修后 PASS）

## 为什么做这一条

21 场景批量回归一直只有 headless 的那 21 个；`stage4_hud_score` 和 `stage4_menu_input`
需要真实窗口，一直不在批量里（`stage4_hud_score` 上次跑是 Phase T）。G14 收尾后把这两个
补跑了一遍，`stage4_menu_input` PASS，`stage4_hud_score` **43/44**：

```
STAGE4 HUD SCORE: FAIL checks=44 failures=1
  - rescue success feedback visible in HUD (got '兄弟回来了！右边这口气补上了')
```

不是玩家侧坏了，是断言过期。救援现在有两拍：

1. 抓到的瞬间 `feedback.rescue_ok` →「接住了！兄弟！」，同时开始 0.42 s 的抬升 carry；
2. carry 完成、`rescue_success_count += 1` 的同一帧 `feedback.rescue_reunion`
   →「兄弟回来了！右边这口气补上了」。

HUD 的反馈行是后写覆盖前写，而测试要等 `rescue_success_count` 变了才去读——那已经是第二拍。
所以从 D2 加重聚文案那天起，这条断言就必挂；它不在 headless 批量里，一直没被发现。

## 做了什么

只换一条断言，仍然只算一项检查（总数仍是 44）：

```gdscript
var catch_msg := Locale.t("feedback.rescue_ok")
var catch_seen := false
for e in _fb_events:
    if String(e).begins_with(catch_msg):
        catch_seen = true
_check(catch_seen and seen == Locale.t("feedback.rescue_reunion"),
    "rescue feedback two beats (catch emitted=%s, HUD last='%s')" % [str(catch_seen), seen])
```

顺带修掉一处语言脆性：旧断言把「接住」写死成中文，测试切到英文时也必挂。

## 证据

| 验收点 | 读数 |
|---|---|
| 修前 | `checks=44 failures=1`，失败项与上面原文一致 |
| 修后 | `STAGE4 HUD SCORE: PASS checks=44`、exit 0 |
| 两拍确实都发生 | `rescue feedback two beats (catch emitted=true, HUD last='兄弟回来了！右边这口气补上了')` |
| 没改产品 | `race.gd` / `locale.gd` / `hud.gd` 的 md5 修前修后完全相同 |
| 另一个窗口化测试 | `stage4_menu_input` 窗口化 PASS（`reg-g15-menu-input.log`） |

## 回归

- 两圈 `fullrun-g15.log`：run1 272.9 s / run2 272.8 s、9770、S、55/55、0 事故、
  `STAGE3 PLAYTEST: PASS`；FINISH / SCORE / PASS 行与 `fullrun-g12.log` `diff` 为空
  （`SCORE clean=0 precise=44 dive=8 ollie=3 snack=9 mistake=0 joint=0 -> 9770` 两圈相同）。
- `best.json`：两圈进程退出后 md5 `c322f9a20321c5b618f98db7e4120969`，内容
  `283.961389454381 / 3150 / 54 / 0` 未变。
- 另一条更新：这次跑窗口化测试把测试自己的输出 `phase-t-hud-score.json` 重写了
  （schema 不变，多了两拍判定的字段）。它是探针输出、每次跑都会重写；Phase T 的
  历史结论请以 `docs/reports/STAGE-4.md` 的文字为准，不要把它当冻结证据。

## 已知限制

- 这条测试必须开窗口跑（headless 的鼠标/字体路径会挂），所以它永远不在 21 场景批量里。
  **以后每轮收尾要单独补跑 `stage4_hud_score` 与 `stage4_menu_input`**，否则同类过期断言
  还会烂在里面。
- 「接住了！兄弟！」在 HUD 上只停留约 0.4 s 就被重聚文案盖掉。这是既有的两拍设计
  （抓到 → 抬回壳上），不是本轮要改的东西；截图取证也拍不到 0.4 s 的停留，
  只有事件列表能证明它发过。
