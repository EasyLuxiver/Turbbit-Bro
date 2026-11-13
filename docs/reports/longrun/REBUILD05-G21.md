# G21 — 撞过的障碍类型，下一组再教一次

日期：2026-11-13（08:01 先写验收标准，08:04 起改）
改动：`scripts/race.gd` 两处（各 1 行代码 + 注释）——`_check_hazards()` 记账分支
重新武装，`_update_lessons()` 跳过已经撞过的组；
新增探针 `scripts/test/stage5_g21_relesson.gd` + `scenes/stage5_g21_relesson.tscn`
QC：`tbb-exp05-g21-relesson`（6 条标准，08:01:55 写入）
数据：`rebuild05-g21-relesson.json`

## 为什么做这一条

首次教学（`lesson_seen`）一局里每类障碍只发一次。放到真实跑图里就变成一个死结：

1. 第一组海鸟过来，底栏说“趴低”，玩家没记住（或者正手忙脚乱）→ 撞了。
2. 玩家已经**知道**这里有东西，也知道自己没做对，但下一组同类型（同一条赛道还有
   3–4 组）再也不会提示。剩下几组只能靠猜：蹲？跳？还是换人？

这不是“提示太多”的反面，而是提示**位置**错了：最需要说第二遍的时刻，恰好是
玩家刚吃过一次亏、正准备重来的时刻。E 阶段把同类型障碍加密到每区多组之后，
这个缺口被放大。

## 改法

`_check_hazards()` 里，一次碰撞**真的记了账**（`applied` 为真）时，把这一类型从
`lesson_seen` 里拿掉：

```gdscript
if applied:
    hit_roles[key] = roles
    hit_groups[key] = true
    # G21：撞过就重新武装这一类型的首次教学。
    lesson_seen.erase(kind)
    return
```

三条边界是刻意选的：

- **只认 `applied`**。冷却期/事故期间被挡下的碰撞没有记账（B1/B2 的既有口径），
  不补课——玩家并没有为这一次吃亏。
- **干净通过不清**。`lesson_seen` 只增不减时，“看懂了”的人不会被同一句话反复打扰。
- **只动这一类型**。`kind` 是逐组的，erase 之后其他类型的教学状态原样保留。

补教仍然走原来的 `_update_lessons()`：同一条赛道、同一个 locale 文案、
同一个“最近的未过完障碍优先”的发声规则，没有新增通道，也没有新 UI。

第二处是探针 E 逼出来的：乌龟碰撞**不产生事故状态**（只记一笔 `TURTLE_WAVE`），
重新武装后同一帧就会轮到教学循环；巡逻鲨往回巡 30 px 时接触点可能落在组起点之前，
于是玩家会在**刚撞上的那一组原地**再听一遍同一句话，而真正该补教的下一组反而
被 `lesson_seen` 挡住了。所以 `_update_lessons()` 里加一条：

```gdscript
if hit_groups.has(String(g["group"])):
    continue   # 已经撞过的这一组不再补教——补教是给“下一组”的
```

兔子碰撞走的是事故分支（事故期间教学整体早退），不受这一条影响；
它只为乌龟碰撞这条无事故路径封口。

## 探针读数（正式 `race.tscn`，`_physics_process` 驱动）

| 用例 | 做了什么 | 读数 |
|---|---|---|
| A 撞→补教 | beam3 前 700 px 出教学；不趴低撞上（记 1 笔 `RABBIT_STUN`）；事故自己解开后摆到 beam4 前 700 px | 只在 beam3 教 1 次；撞后 `lesson_seen` 里没有 LOW_BEAM、其余 6 类原样；beam4 前**补教 1 次**，文案与首次完全一致；同一组不会连教两次 |
| B 干净通过 | bird3 前出教学，按住 ↓ 趴低通过（0 记账）；摆到 bird4 前 700 px | `lesson_seen` 仍含 LOW_BIRD；bird4 前**0 条提示** |
| C 被挡下的碰撞 | 预置 `hazard_cooldown = 5 s`，开进 beam5 | 不记账（0 事故），`lesson_seen` 仍含 LOW_BEAM——不重新武装 |
| D 别的类型 | 只留 DIVE_GATE 未教，开到 gate4 前 | DIVE_GATE 仍只出现 **1 次**，没有其他类型被顺带重发 |
| E 乌龟碰撞（无事故状态） | 不跃起，用壳开进 shark3（记 `TURTLE_WAVE`）；再摆到 shark5 前 700 px | 撞后 `lesson_seen` 里没有 SHARK；撞点后 5 帧**没有**原地复读；shark5 前补教 1 次，发声位置 `x >= shark5_start - 1200` |

`G21 RELESSON: PASS`；连跑两次结果一致。E 组是第二轮加的：第一版只在 A 组
验“撞完补教”，没覆盖乌龟碰撞这条无事故路径，正是它找出了第二处改动。

### 反向对照（证明探针不是恒真）

把 `lesson_seen.erase(kind)` 临时换成 `pass` 再跑：

```
G21 RELESSON: FAIL
  - A5 撞完 LOW_BEAM 重新武装
  - A6 其他六类仍保持已教（只有这一类型被拿掉）
  - A7 下一组同类型（beam4）前重新发教学
  - A8 补教文本与首次一致
```

恰好是 A 组的四条断言失败，B/C/D 仍然通过——说明这四条确实在测 G21 的行为，
其余三组是独立控制项，不是同一个断言的复述。跑完已恢复改动并重跑 `PASS`。

第二处改动同样做了对照：去掉 `hit_groups` 跳过再跑

```
G21 RELESSON: FAIL
  - E3 撞完 SHARK 重新武装
  - E4 刚撞的这一组不会原地复读
  - E5 下一组同类型（shark5）前补教一次，位置在 shark5 前
```

第一版 E 组只有“补教总数 == 2”这一条，去掉改动后仍然通过（同一组复读 + 下一组
没补教，总数恰好也是 2）——于是补了“发声位置在 shark5 前”和“撞点后 5 帧无新提示”
两条，才抓得住。两次对照都在改回后重跑 `PASS`。

## 取证截图（窗口化，正式 `race.tscn`）

`screenshots/rebuild05-g21-relesson.png`（`--capture-relesson`）：撞完 beam3、
硬直解开后摆到 beam4 前 700 px 的那一帧，1280×720。底栏最下一行是补教
`↓ 趴低`，上面一行是区域会动的障碍提示，两条各自成行、没有重叠，也没有压到
氧气/BRO METER 面板。图上 `prompts=2`（beam3 首次 + beam4 补教）。
（图里“咚！兔子被撞晕”是探针瞬移到 beam4 时事故横幅还没走完，不是补教的一部分。）

## 回归（最终代码，两处改动都在）

- 两圈 `fullrun-g21.log`：run1 `272.9 s / 9770 / S / 55/55 / 0 事故`，
  run2 `272.8 s` 同；`SCORE clean=0 precise=44 dive=8 ollie=3 snack=9 mistake=0 joint=0`；
  `STAGE3 PLAYTEST: PASS`。FINISH / SCORE / PLAYTEST 行与 `fullrun-g20.log`
  `diff` 为空——自动驾驶 0 失误，重新武装从不触发，行为不变。
- 24 场景批量（`/tmp/reg-g21-<scene>.log`，含新探针 `stage5_g21_relesson`）：
  全部 `exit=0`、0 条失败行。
- 窗口化 `stage4_hud_score`：`STAGE4 HUD SCORE: PASS checks=44`；
  `stage4_menu_input`：`STAGE4 MENU INPUT: PASS`。
- `best.json`：跑前跑后 md5 `c322f9a20321c5b618f98db7e4120969`。
- QC `tbb-exp05-g21-relesson` 6/6，闸门 `[PASS] delivery_qc_record (R009)`。
- 08:52 收尾再用最终工作树跑一次：`fullrun-final.log` 与 `fullrun-g21.log` 关键行
  `diff` 为空；25 场景批量（含 `stage4_lesson_prompt`）全绿；窗口化 HUD 44/44、
  菜单 PASS；`best.json` md5 仍 `c322f9a2…`。

## 没做的事

- 没有真人试玩；以上是逐帧探针读数。
- 没有限制“撞几次补教几次”。同一类型连续撞三组会补教三次——在赛后总结里观察
  是否显得啰嗦，需要真人反馈；本轮不做上限。
  → G22 已封顶（每类首次 + 一次补教），见 `REBUILD05-G22.md`；
  探针新增 F 用例，去掉上限后恰好 F6/F7 变红。
