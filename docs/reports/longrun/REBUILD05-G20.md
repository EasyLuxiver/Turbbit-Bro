# G20 — 20 个探针补清 `hit_roles`：不再在免疫赛道上测

日期：2026-11-13（06:38 起，08:00 收尾）
改动：`scripts/test/` 下 20 个探针（只加一行复位 + 注释；`snack_zones` 另有
起点/相位两处探针侧修正），产品代码 0 行。
QC：`tbb-exp05-g20-probe-roles`（标准 06:38 先写，代码 06:41 起改）

## 为什么做这一条

G18 修 `stage4_rescue_boost` 时发现：B2 起碰撞按“角色×障碍组”记账（`hit_roles`），
探针的 `_reset()` 只清 `hit_groups`。后果不是少记，而是**该组从第二次命中起整组免疫**：
`_check_hazards()` 看到 `roles.size() >= 2` 直接 `continue`。

G18 只修了当轮那个探针，顺带记下另有 20 个探针同样只清 `hit_groups`。这一轮把它们全部补上：

```
race.hit_groups.clear()
race.hit_roles.clear()   # G20
```

20 个文件、25 处调用点（`experience_rework` / `surfboard` 各 2 处，
`playful_joint_verdict` 4 处，其余各 1 处）。

## 重跑结果：哪些“绿”是假的

| 探针 | 修前 | 修后 | 判读 |
|---|---|---|---|
| `stage4_bird_routes` | jump 41/42、leap 42/42 通过 | jump 0/42、leap 0/42 全部 `rabbit_hit`；dive 60/62 | **修前是假的**：低飞海鸟只压兔子那一层，跳/跃起把头送进鸟里本来就该撞；只有趴低（crouch 42/42）才是正解。E1 文档引用的旧数字已改正 |
| `stage4_playful_joint_verdict` | PASS | 8 条断言 FAIL | **探针预期过时**：断言写于 B2 之前（“双撞合并成一格”）。B2 规格是“两个角色各记一笔”（`stage5_b_probe` s3）。按下述方式改成 B2 口径后 PASS |
| `stage4_snack_zones` | 18/18 | 1 行 FAIL | **探针起点/相位问题**：见下节；改成确定性起点后 18/18，连跑两次一致 |
| `stage4_playful_bro_dive_audit` | log1 9–13/180、log5/8 23/180 | log1 18/180、log5/8 36/180 | 通过率反而上升：修前先命中的试次把同组封住，失败被记成 `hit_unknown_role`；修后归到真实原因（`rabbit_hit_arc` / `turtle_hit_dive_late`） |
| `stage4_bro_dive_matrix` | 旧日志 log1 7/100 | log1 0/100、log3 18/100、log8 25/100 | 旧日志早于 E2/G 的赛道改动，不能直接对比；log1 的 0/100 是**采样网格没覆盖到窗口**（5 档起跳×5 档延迟×4 档松手），标准时机由 `stage5_b3_repeat` 7/7、窗口 178/180 与两圈回归负责 |
| 其余 14 个 | — | 全部 exit 0、无断言失败 | 差异只在汇总行文字（`fail={...}`），不是失败 |

## snack_zones 的两处探针侧修正

1. **起点贴着上一组动态障碍的扫掠边**。gate3 那行的起点是 `prev_end + 60`，
   而前一组 shark3 是 `patrol_shark`（±30 px、4.5 s）。乌龟一出生就蹭到它，
   记一笔 `TURTLE_WAVE`，`skip` 行的 “不吃不惩罚” 判红——修前 shark3 的
   `hit_roles` 还留着，所以这一蹭被静默吃掉。改为
   `prev_end + 60 + 前一组运动振幅 + 40`。
2. **动态障碍相位在行与行之间漂移**。`hazard_clock` 是物理时间累加，
   前一行多跑几十毫秒，后一行的巡逻鲨相位就整个挪开（同一行时过时不过）。
   正式比赛每局重建场景、clock 从 0 起；探针也按这个口径在 `_reset()` 里归零。

修正后 `SNACK ZONES: DONE rows=18 fails=0`，连跑两次结果一致。

## joint_verdict 改成 B2 口径

规格源：`stage5_b_probe` s3（“同一组障碍两个角色都撞，两笔都要记”）与
MISSION-05 §B2“双撞”回归。改动只在探针：

- `_case_both`：BRO 1 格 → 2 格，两条记账（`RABBIT_WATER` + `TURTLE_DIVE_LATE`）；
  同帧第二次判定仍是 2 格。
- `_case_different` / `_case_while_dazed`：乌龟摆到浮木下方（`deep`）。
  B2 起乌龟同帧在框里也会记账，会把“兔子事故窗口内合并”这件事遮掉；
  这两个用例只想看兔子，另一角色必须离开危险区。

结果：`JOINT VERDICT: PASS`。

## 回归

- 两圈 `fullrun-g20.log`：272.9 / 272.8 s、9770、S、55/55、0 事故；
  FINISH / SCORE / PASS 行与 `fullrun-g19.log` `diff` 为空。
- 23 场景批量（`$TEMP/reg-g20-*.log`，含 `stage4_snack_zones`）：全部 exit 0、0 条失败行。
- 窗口化 `stage4_hud_score`：`PASS checks=44`；`stage4_menu_input`：`PASS`。
- `best.json`：跑前跑后 md5 `c322f9a20321c5b618f98db7e4120969`。
- 重跑明细：20 个场景第一次全跑后，`joint_verdict` 与 `snack_zones` 判红 →
  按上文修正后单独重跑通过（`joint_verdict` PASS，`snack_zones` 18/18 连跑两次）；
  其余 18 个场景第一次即 exit 0。

## 已知限制

- `stage4_bro_dive_matrix` 的 log1 采样矩阵 0/100，不代表 log1 过不去
  （标准时机 7/7、两圈回归 55/55 都过）；是该探针的固定网格没有落在窗口里。
- 这 20 个探针不在每轮的 23 场景批量和两张窗口化测试里，属于“平时不跑”的
  一次性审计探针。本轮只保证它们能真跑、判读正确，没有把它们并进常规回归。
- `hazard_clock` 归零只加在 `snack_zones`。别的多行探针若同样依赖动态障碍相位，
  仍可能在长时间跑动后翻面——这是探针设计问题，未逐一测量。
