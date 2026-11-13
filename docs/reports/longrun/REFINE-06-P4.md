# REFINE-06 P4 — 食物争夺

状态：**实现完成，验收见下表**；阶段仍是 `STAGE=4`，未进入 STAGE 5，不宣布完成。

## 一句话

食物从“乌龟碰到就吃”改成“**控制谁就谁吃**”：操控乌龟 → 原有 TURBO 加速 + 冷静 +
亲手喂到奖励；操控兔子 → 兔子吃到，下一跳初速 ×1.15（实测峰值 ×1.33），乌龟不加速、
不冷静、不加分。两个人都会伸手（320 px 内出现伸手小点 + 想吃一方头顶 “!”），
SHIFT 就是这一口的归属决定；不吃不扣任何东西。

## 设计

| 项 | 值 | 位置 |
|---|---|---|
| 归属判定 | `_snack_eater()`：控制谁就谁；控制者必须够得着（不跃起、巡航深度 ±40、兔子在壳上且不晕） | `race.gd` |
| 争抢提示 | 320 px（Z1 1.45 s / Z2 1.33 s / Z3 1.23 s 反应时间） | `Tuning.SNACK_INTEREST_PX` |
| 乌龟吃 | TURBO：区速 ×1.15，到该组末尾 +180 px；冷静；+30 分（亲手喂到计数） | 原有机制不动 |
| 兔子吃 | 普通跳初速 ×1.15；窗口同长（到该组末尾 +180 px）；乌龟不加速 | `Tuning.RABBIT_SNACK_JUMP_SCALE` / `RABBIT_SNACK_TAIL` |
| 没吃到 | 不扣分、不记事故、不加 BRO METER、不给反馈 | 原有的“无惩罚”继续成立 |
| 展示 | 0.45 s gulp（从吃到那张嘴冒出）+ 一行文字；HUD 显示当前生效的强化 | `feedback.snack_rabbit` / `feedback.turbo_switch` / `hud.rabbit_boost` |

兔子跳跃强化的实测：同一段 `tick_air`，普通跳峰值 **183.8 px**，强化跳 **244.0 px**
（×1.33）；“先吃到、再原地起跳”的探针同样得到 **244.0 vs 183.8（×1.33）**，
`jump_boost_after_eat=1.15`。理论值 189 / 249.9（×1.32）。

## 新增/修改

- `scripts/systems/tuning.gd`：`SNACK_INTEREST_PX` / `RABBIT_SNACK_JUMP_SCALE` /
  `RABBIT_SNACK_TAIL` 与推导注释。
- `scripts/actors/rabbit_controller.gd`：`jump_boost`（默认 1.0）；`launch()` 的
  默认初速乘它，BRO OLLIE 的显式初速不受影响。
- `scripts/race.gd`：`_snack_eater()` / `_nearest_snack_ahead()` / `_eat_snack(enc, by)`；
  `snack_last_by` / `rabbit_boost_until_x` / `snack_interest_x`；争抢与伸手的绘制
  （`_draw_snack_contest` / `_draw_reach` / `_draw_want_mark`）；兔子强化的上浮箭头
  （`_draw_rabbit_boost_fx`，画在兔子之后）；gulp 从兔子/乌龟的嘴边冒出。
- `scripts/autoload/locale.gd`：`hud.rabbit_boost`、`feedback.snack_rabbit`；
  `hint.snack` / `hud.snack_ahead` / `world.snack` 改成“两个人吃”的说法（中英）。
- `scripts/ui/hud.gd`：兔子强化优先显示在 HUD 食物行。
- `scripts/test/stage4_snack_contest.gd` + 场景：P4 探针（见下）。
- `scripts/test/stage4_snack_contest_capture.gd` + 场景：五张取证截图。
- `scripts/test/stage4_playful_shift_reward.gd`：按新规则更新断言（旧断言写的是
  “操控兔子时乌龟照样吃”，那正是 P4 要改掉的契约）。
- `scripts/test/stage3_playtest.gd`：自动驾驶增加一条食物选择策略（按遭遇序号轮换
  给乌龟/兔子），只为让整圈回归同时覆盖两种吃法；**这是测试输入策略，不是游戏规则**。

## 探针（`stage4_snack_contest`）

输出 `docs/reports/longrun/refine06-p4-snack-contest.json`，直接调用正式 race.gd：

- SHIFT 决定：同一份食物、同一位置，控乌龟 → `eaten_by=turtle`；控兔子 →
  `eaten_by=rabbit`（同一帧判定）。
- 乌龟吃：TURBO 253（=220×1.15）、boost_until=4160、亲手喂到 +30 分、drift 0.8→0、
  兔子 `jump_boost=1.00`。
- 兔子吃：`jump_boost=1.15`、`rabbit_boost_until=4160`（组末 +180）、乌龟
  `boost_speed=0`、`turtle_boost_active=false`、drift 保持 0.8、得分增量 0、
  反馈 = `feedback.snack_rabbit`、gulp_t=0.45。
- 空中错过：兔子起跳后 20 帧内食物在壳下经过 → 没吃、0 分、0 事故、0 BRO、0 反馈。
- 争抢窗口：320 px 整有提示，321 px 没有；两个角色都具备“想吃”的身体条件；
  Z1 反应时间 1.45 s。
- 正式赛道：默认种子抽取后共 9 份食物（x=3250/14100/18950/26350/33750/53100/
  54590/59270/62590）。
- 源码接线：`_snack_eater()` 被 `_update_snack` 使用；争抢/伸手/“!”/兔子箭头/
  兔子 gulp 的绘制函数都接进 `_draw`。

## 截图（已逐张打开看过）

`screenshots/refine06-p4-snack-interest.png`（控乌龟：兔子伸手 + “!”）、
`-interest-rabbit.png`（控兔子：乌龟“!”）、`-rabbit-gulp.png`
（“兔子吃了！下一跳更高！”）、`-rabbit-boost.png`（兔子身上上浮箭头 + HUD
“兔子！下一跳更高”）、`-turtle-gulp.png`（“TURBO！亲手喂到！乌龟很满足！” +
壳后速度线）。

## 验收（qc: `tbb-refine06-p4-snack-contest`）

| # | 判定 | 证据 |
|---|---|---|
| 1 | pass | 控乌龟吃 → `eaten_by=turtle`、TURBO 253、boost_until 4160、drift 0.8→0、+30 分；兔子 `jump_boost=1.00` |
| 2 | pass | 控兔子吃 → `jump_boost=1.15`、乌龟不加速/不冷静/不得分；下一跳峰值 244.0 vs 183.8 px（×1.33） |
| 3 | pass | 320 px 整提示、321 px 无；两角色同时伸手；同位置换 SHIFT → 吃的一方跟着换；两张截图 |
| 4 | pass | 空中错过：0 分、0 事故、0 BRO、0 反馈；深水下路过同样零惩罚 |
| 5 | pass | 0.45 s gulp + 一行文字；两张吃下截图里文字与 HUD 都写明谁吃、得了什么 |
| 6 | pass | 正式赛道整圈真实输入：9 份食物里乌龟 5 次（253/276/276/299/299）、兔子 4 次（jump 1.15）；第二圈同样成立 |
| 7 | pass（有保留） | 反应窗 1.45/1.33/1.23 s，不操作也有人吃，两个选项结果可感知；但仍是二选一小判断，真人未试玩 |

## 回归

最终代码上重跑（headless，全部 exit 0 或内部 PASS）：

| 套件 | 结果 |
|---|---|
| `stage5_e2_motion` / `stage6_p0_collision` / `stage5_g_measure` / `stage5_b_probe` / `stage5_g21_relesson` / `stage4_snack_draw` / `stage6_bro_dive_robust` / `stage4_penalty` | exit 0 |
| `stage4_hud_score` | PASS，checks=44 |
| `stage4_menu_input` | PASS |
| `stage4_snack_zones` | 18 行，fails=0 |
| `stage4_snack_rush` | 3 例，fails=0 |
| `stage4_playful_shift_reward` | PASS（断言已按 P4 契约更新） |
| `stage4_snack_contest` | PASS，failures=[] |
| `stage3_playtest` 整圈 ×2（正式赛道，自动驾驶） | 55/55 组、0 事故、grade S、`STAGE3 PLAYTEST: PASS`、SCRIPT ERROR 0；两圈时间 274.6 / 274.5 s |

`best.json` 跑前跑后 md5 均为 `c322f9a20321c5b618f98db7e4120969`，未被改写。
`docs/STAGE.md` 仍是 `STAGE=4`。

## 下一步

P5 喜剧反馈、P6 55 组节奏复审 + 10 问自评 + 总报告；`STAGE=4` 不动。
