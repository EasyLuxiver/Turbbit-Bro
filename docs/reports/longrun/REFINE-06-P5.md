# REFINE-06 P5 — 角色反馈与喜剧表现

状态：**实现完成，验收见下表**；阶段仍是 `STAGE=4`，未进入 STAGE 5，不宣布完成。

## 一句话

兔子落水已经是一条完整的可见链路（真实落点水花 → 乌龟下潜靠近 → 接住 → 抬回壳上，
全程无瞬移）；这次补上乌龟被浪掀翻的**肚皮朝天**表现：翻过去 0.18 s、四肢乱蹬、
0.9 s 内自己翻回来，全是画法，位置/碰撞/判定不动，不叠加第二套惩罚。

## 设计

| 项 | 值 | 位置 |
|---|---|---|
| 兔子落水 | 穿水那一帧在真实落点出水花圈（0.6 s） | 原有 `_splash_water` / `rescue_splash_pos` |
| 兔子下落 | 保留世界坐标/方向/速度，重力 1050，最大 950 px/s | 原有 `RESCUE_FALL_*` |
| 兔子救援 | 乌龟必须真的潜到兔子下面；靠近 → 接住 → 抬回壳上 | 原有 `RESCUE_CATCH_*` / `_begin_carry` |
| 乌龟掀翻 | 浪击（鲨鱼/礁体等 `_turtle_contact`）触发 `flip_t = 0.9 s` | `Tuning.FLIP_TIME` |
| 掀翻表现 | 0.18 s 翻过去 → 肚皮朝天、四肢乱蹬（相位不同）→ 最后 0.25 s 翻回来 | `_draw_turtle` |
| 掀翻冷却 | 0.9 s 翻 + 0.6 s 缓冲；贴着鲨鱼连拍不会整段卡在肚皮朝天 | `flip_lock` |
| 碰撞 | 掀翻只是画法：壳的判定框、`_resolve_turtle_solid`、`_check_hazards` 全部照常 | — |
| 惩罚 | 掀翻不记账：事故计数/BRO METER/扣分只记浪击那一次（`note_mistake`） | — |

## 新增/修改

- `scripts/systems/tuning.gd`：`FLIP_TIME := 0.9`（含“不要拖长”的推导注释）。
- `scripts/actors/turtle_controller.gd`：`flip_t` / `flip_lock`；`tick()` 顶部只走表现计时；
  `start_flip()`；`reset()` 清零。
- `scripts/race.gd`：`_turtle_contact()` 里 `turtle.start_flip()`；
  `_draw_turtle()` 里掀翻的肚皮/四肢/头被压住的画法。
- `scripts/test/stage4_char_feedback.gd` + 场景：P5 探针。
- `scripts/test/stage4_char_feedback_capture.gd` + 场景：五张取证截图。

兔子侧没有改玩法代码：落水、水花、救援、抬回壳上都是 Phase F / PLAYFUL-04 已有的链路，
本次用探针复核并补截图。

## 探针（`stage4_char_feedback`）

输出 `docs/reports/longrun/refine06-p5-character-feedback.json`：

- 落水水花：兔子从水线上方 15 帧掉下来，穿水点 (4954.0, 344.0)，水花位置
  (4954.0, 344.0)，误差 **0.8 px**；比水线高 4 px（一帧的落速）。
- 救援连续性：全程最大单帧隐含速度 **944.4 px/s**（上限 1000）；水里 58 帧、
  抬升 16 帧、第 75 帧回到 RIDING；`last_result=caught`。
- 掀翻：`flip_t_at_hit=0.9`、53 帧走完（0.9 s）、掀翻期间乌龟照常前进 142.2 px；
  掀翻后事故计数 +0、BRO +0；3.13 s 回到 `CRUISING`、速度 220、控制权仍是乌龟、
  兔子仍在壳上。
- 不穿墙：贴着浮木（x 6400–6432）掀翻并前进，72 帧里 71 帧与浮木相交、
  壳最右沿只到 6403（浮木左沿 6400），`crossed_without_contact=false`，
  最后停在 x=6355（被顶回去）。
- 正式赛道真实输入：默认布局撞鲨鱼 → 掀翻 **0.9 s**；按 ↑ 撞低梁 → 0.98 s 兔子落水 →
  SHIFT 换乌龟 + ↓ → **0.53 s** 接住回到壳上，结束时事故状态 NONE、RIDING。
- 源码接线：`start_flip()` 被 `_turtle_contact` 调用、`_draw_turtle` 读 `flip_t`、
  `tick()` 递减、水花取兔子真实位置。

## 截图（已逐张打开看过）

`screenshots/refine06-p5-rabbit-splash.png`（穿水点的白色水花圈 + X 眼 / 转耳朵）、
`-rabbit-approach.png`（兔子还在水里，乌龟已经潜到旁边，底部提示“按 ↓ 潜下去接住兔子”）、
`-rabbit-catch.png`（“接住了！兄弟！”，兔子正被抬离水面）、
`-turtle-flip.png`（肚皮朝天、四条腿朝上乱蹬、头被压在壳下，HUD“乌龟晃动 100%”）、
`-turtle-recovered.png`（掀翻与入水都结束，壳回到巡航、兔子在壳上）。

## 验收（qc: `tbb-refine06-p5-character-feedback`）

| # | 判定 | 证据 |
|---|---|---|
| 1 | pass | 穿水点误差 0.8 px ≤ 2；截图中水花圈在兔子身上 |
| 2 | pass | 最大单帧隐含速度 944.4 px/s ≤ 1000；第 75 帧回到 RIDING |
| 3 | pass | 水里 58 帧、抬升 16 帧、接住/回壳都有截图 |
| 4 | pass | 掀翻 0.9 s；截图里肚皮朝天、四肢乱蹬、头被压住 |
| 5 | pass | 贴浮木掀翻 72 帧 71 帧相交、最右沿 6403 < 浮木 6400+3，无“不接触越过” |
| 6 | pass | 掀翻后事故 +0 / BRO +0；3.13 s 回 CRUISING、220、控制不变、兔子在壳上 |
| 7 | pass | 正式布局撞鲨鱼掀翻 0.9 s；撞低梁 0.98 s 落水、0.53 s 救回；整圈 SCRIPT ERROR 0 |
| 8 | 有保留 | 两个失败都一眼可读且有性格（兔子转耳朵 X 眼、乌龟乱蹬），掀翻不挡操作；未做真人试玩 |

## 回归

| 项 | 结果 |
|---|---|
| 无头场景批跑（motion / collision / g_measure / probe / g21 / snack_draw / bro_dive / penalty） | 全部 exit 0，无 SCRIPT ERROR |
| `stage4_hud_score` | PASS，44 项检查 |
| `stage4_menu_input` | PASS |
| `stage4_snack_zones` | 18 行，0 fail |
| `stage4_snack_rush` | exit 0，3 个用例 0 fail |
| `stage4_playful_shift_reward` | PASS |
| `stage4_snack_contest` | PASS |
| `stage4_char_feedback` | PASS（本次新增） |
| 整圈 `stage3_playtest` | run1 274.6 s / run2 274.5 s，9650 分，S，55/55 组，事故 0，最大停摆 0.0 s，SCRIPT ERROR 0，`STAGE3 PLAYTEST: PASS` |
| 食物线 | 18 条，乌龟/兔子交替，与 P4 一致 |
| `best.json` | md5 前后一致 `c322f9a20321c5b618f98db7e4120969` |
| `docs/STAGE.md` | 仍为 `STAGE=4` |

## 下一步

P6 55 组节奏复审（含已命名的无聊段 t≈35–50 s）+ 10 问自评 + 总报告；`STAGE=4` 不动。
