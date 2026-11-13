# G17 — 结算页给一条「下次试试」

日期：2026-11-13（06:13 起）
改动：`game_manager.gd`（纯函数 `next_try_key()`）+ `locale.gd`（三条双语）+ `result.gd`（一行 Label、`--trynext` 取证开关）
探针：`scripts/test/stage5_g17_trynext.gd` + `scenes/stage5_g17_trynext.tscn`
QC：`tbb-exp05-g17`（标准 06:13 先写，代码 06:14 起改）

## 为什么做这一条

结算页此前只有七行数字。一个从没打出过 BRO DIVE 的新手，看完
`比赛时间 / 干净通过 / 连招 / 救援成功 / 亲手喂到 / 失误 / 联合事故` 也
**不知道自己漏了什么、下一局该试什么**。任务书的有趣性检查第 4 条是
“比上一局多一个想再试一次的理由”，结算页原先一条都没给。

这条不新增机制、不加奖励、不改难度：只是把“本局没做到的、下一局做得到的”
一句话说出来。三种文案对应三个已有系统，按“最能改变下一局”的顺序挑**一条**：

1. 一次连招都没打出来 → `下次试试：兔子跳起来后按 SHIFT 让乌龟下潜（BRO DIVE）`
2. 有连招、但没亲手喂到 → `下次试试：按 SHIFT 换到乌龟，亲手把海藻喂给它`
3. 都做到过、但有事故且没救回 → `下次试试：兔子落水时按 SHIFT 换乌龟，按住 ↓ 追下去接它`
4. 三条都不缺 → 整行不显示

## 做了什么

- `GameManager.next_try_key()` 是**纯函数**：只读 `combo_*_count` /
  `snack_switch_count` / `accident_count` / `rescue_success_count`，返回 locale key 或空串。
- `result.gd` 在「最佳时间」下面加一个 `Label`（name `TryNext`，18 px，浅绿），
  `_refresh()` 里按 key 决定 `visible` 与文本；语言切换时同一路径刷新。
- `-- --trynext` 取证开关：`--capture-result` 的样本改成“有连招、没亲手喂到”的那一局，
  只拍这一行的样子，不写 `best.json`。

## 证据

| 验收点 | 证据 |
|---|---|
| 三种条件各出对应一条，都不缺时不出 | `reg-g17-trynext.log`：`G17 TRYNEXT: PASS checks=7 failures=0`；JSON 五行：`no_combo→try_combo`、`combo_no_snack→try_snack`、`missed_rescue→try_rescue`、`clean_run→""(hidden)`、`did_rescue→""(hidden)` |
| 只有一行 | 探针数 `TryNext` 节点恰 1 个；截图里只出现一条 |
| 只读、不改状态 | 每个 case 在设置输入后、调用前快照 `total_score / finish_time / 四类计数 / score_log 大小 / grade`，调用 `next_try_key()` + `_refresh()` 后逐一比对，全部相等（无 “state mutated” 失败） |
| 中文截图 | `rebuild05-result-trynext.png`（1280×720）：`下次试试：按 SHIFT 换到乌龟，亲手把海藻喂给它`，在「最佳时间」与快捷键行之间，不压按钮 |
| 英文截图 | `rebuild05-result-trynext-en.png`（1280×720）：`NEXT TRY: SHIFT TO THE TURTLE AND FEED IT THE SEAWEED`，一行到底，右侧留白 |
| 结算页原有 44 项没坏 | 窗口化 `stage4_hud_score`：`PASS checks=44`、exit 0 |

## 回归

- 两圈 `fullrun-g17.log`：run1 272.9 s / run2 272.8 s、9770、S、55/55、0 事故、
  `STAGE3 PLAYTEST: PASS`；FINISH / SCORE / PASS 行与 `fullrun-g16.log` `diff` 为空。
- 22 场景批量 `$TEMP/reg-g17-<scene>.log`（21 个原有场景 + 本轮新探针
  `stage5_g17_trynext`）：全部 exit 0、0 条失败行、0 条 SCRIPT ERROR。
- 两个窗口化测试：`stage4_hud_score` `PASS checks=44`、`stage4_menu_input` PASS。
- `best.json`：批量退出后 md5 仍 `c322f9a20321c5b618f98db7e4120969`。

## 已知限制

- 文案是“建议”，没有埋点知道玩家下一局是不是真的去做了；它只能降低“不知道还能怎么玩”
  这一层门槛，验证仍要靠真人试玩。
- 三条建议的优先级是我定的（连招 > 喂食 > 救援）。依据是连招最容易在任何一区打出、
  也最能代表双人协作；如果制作人认为救援更该先说，改 `next_try_key()` 的顺序即可。
- 判定只看“本局有没有”，不看比例：9 次连招里有 1 次没喂到也会提示喂食——
  这是故意的，喂食每区都有机会，提示不嫌多。
