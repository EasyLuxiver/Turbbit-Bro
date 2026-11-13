# PHASE R — §七-7 加速状态下的主动救援重验

日期：2026-11-12
阶段：STAGE 4（未进入 STAGE 5）
性质：**只加探针，不改任何生产代码**。救援状态机、加速、关卡几何一行没动。

> 证据类型：headless 真实关卡物理 + 引擎按键代理（SHIFT 走 `InputEventKey` →
> `GameManager._unhandled_input`，↓ 走 `Input.action_press`）。
> **不是真人试玩**；真人仍 `NOT TESTED`。

## 1. 一句话结论

`TBB-LONGRUN-PLAYABILITY-02` 的三件新玩法（吃食物加速、随机障碍、Phase Q 右移几何）
都没有破坏主动救援：在正式赛道上“吃下食物 → TURBO 中撞进低梁 → 兔子落水”是真实
触发的，玩家必须自己 SHIFT + 下潜才接得住；Z1 加速后仍有 **≥2.0 s** 的起始窗口、
Z3 最坏尾巴下仍有 **≥1.6 s**；没接住是 0.78 s 的逐帧冲回（单帧最大 9.33 px，
不是瞬移），全程只记一次事故。

## 2. 为什么这一步要重验

Phase F 的救援数据是 2026-11-12 早些时候在 `--rescue-proto` 的**合成入口**上取的
（`race.start_rescue_proto()` 直接把场景摆到“兔子刚掉水里”）。之后 -02 追加了：

- TURTLE SNACK RUSH：碰撞时可能正在 TURBO，乌龟横向速度 1.15×；
- 随机障碍：Z3 的 beam8 等组会被抽成别的种类（默认种子里 beam8 仍是 LOW_BEAM）；
- Phase Q：Z3 后半段 9 个组的 x 全部右移。

原有测试没有一条覆盖“加速中落水”，而加速正好改变救援里唯一的变量——**乌龟横向前进
的速度**：兔子落水点固定在乌龟前方 520 px，横向接人带宽 ±120 px，越过兔子 280 px 判失败，
所以速度越快，“够得着”的时间越短。

## 3. 方法：在正式赛道上把落水撞出来

探针 `scripts/test/stage4_rescue_boost.gd`（场景 `scenes/stage4_rescue_boost.tscn`）：

1. `GameManager.start_race()` 进正式赛道，`load_level()` 装默认种子 20261112；
2. 操控乌龟路过食物**自动吃下**（`SNACK eaten x=… boost_until=… speed=…` 由 `race.gd`
   自己打印）→ TURBO 生效；
3. 切兔子，在梁前 45 px 按 ↑（**错误动作**：梁的正确解法是趴低）→ 兔子离地撞梁
   → `_rabbit_contact()` → `RABBIT_WATER`。全程使用生产代码的碰撞路径，没有直接调用
   救援函数；
4. 事故后按延迟 SHIFT（真实按键事件）+ 按住 ↓，记录接住/失败、时刻、恢复耗时、
   事故计数、失败恢复期间兔子的逐帧位移；
5. 恢复后再跑 1.0 s，看是否会连锁出第二次事故。

对照组同一份探针跑“不吃食物”（食物前 200 px 就切兔子，乌龟不会吃）：基速 220。

## 4. 结果

### 4.1 Z1 · beam1（区速 220 → TURBO 253）

| 试次 | 撞击速度 | 结果 | 接住/失败时刻 | 回到骑乘 | 单帧最大位移 |
|---|---|---|---|---|---|
| 不输入 | 253 | missed | 3.22 s | 4.00 s | 9.33 px |
| 只 SHIFT 不潜 | 253 | missed | 3.22 s | 4.00 s | 9.33 px |
| 0.0 s 开始下潜 | 253 | **caught** | 1.62 s | 立即 | — |
| 0.4 s | 253 | **caught** | 1.62 s | 立即 | — |
| 0.8 s | 253 | **caught** | 1.62 s | 立即 | — |
| 1.2 s | 253 | **caught** | 1.73 s | 立即 | — |
| 1.6 s | 253 | **caught** | 2.20 s | 立即 | — |
| 1.8 s | 253 | **caught** | 2.43 s | 立即 | — |
| 2.0 s | 253 | **caught** | 2.67 s | 立即 | — |
| 2.2 s | 253 | missed | 3.22 s | 4.00 s | 9.33 px |
| 2.4 s | 253 | missed | 3.22 s | 4.00 s | 9.33 px |

**加速窗口：0.0–2.0 s 开始下潜都能接住，2.2 s 起失败。** 失败由 3.2 s 计时器触发。

### 4.2 Z1 基速对照（不吃食物，220）

| 试次 | 结果 | 时刻 |
|---|---|---|
| 不输入 | missed | 3.22 s |
| 0.0 / 1.6 / 2.0 s | caught | 1.85 / 2.20 / 2.67 s |
| 2.2 s | caught | 2.90 s |
| 2.4 s | missed | 3.22 s |

基速窗口 0.0–2.2 s。**与 PHASE-F 的“0.0–2.0 接住”一致**：PHASE-F 在 2.2 s 记的是
失败，本探针在正式赛道上 2.2 s 仍能接住（2.90 s 接住）。差别来自测试入口——PHASE-F
是合成摆位，本探针是真实赛道 + 事故当下就 SHIFT。**保底窗口仍是 2.0 s**，这一点两边相同。

### 4.3 Z3 · beam8（区速 260 → TURBO 299，最坏的一段加速尾巴）

| 试次 | 结果 | 接住/失败时刻 | 备注 |
|---|---|---|---|
| 不输入 | missed | 2.90 s | 早于 3.2 s 计时器：被“越过兔子 280 px”截断 |
| 0.0 / 0.8 s | caught | 1.37 s | |
| 1.2 s | caught | 1.73 s | |
| 1.6 s | caught | 2.20 s | |
| 1.8 / 2.0 / 2.2 s | missed | 2.90 s | 与“不输入”同一时刻，说明是距离判失败 |

**Z3 的窗口比 Z1 窄（≥1.6 s vs ≥2.0 s），而且失败由距离而不是计时器触发**：
299 px/s 下乌龟在 2.68 s 就跑完 800 px，兔子还没漂到 3.2 s 就被甩在身后。
这是加速机制的真实代价，不是 bug——但它意味着 **Z3 吃食物后落水，反应时间比 Z1 短
约 0.4 s**。本阶段只记录，未改救援参数。

## 5. 其它验证

| 检查 | 结果 |
|---|---|
| 撞击时确实在 TURBO 中 | Z1 speed 253 = 220×1.15；Z3 speed 299 = 260×1.15，`boost_active=true` |
| 兔子落水点 | 全部 `rabbit_ahead = 520 px`、`RESCUE_ACTIVE_TIME = 3.2 s`，与 Phase F 相同 |
| 事故只记一次（到恢复为止） | 25 个试次全部 `+1` |
| 失败恢复 | 0.78 s（3.22→4.00 / 2.90→3.68），与 `RESCUE_RETURN_TIME = 0.8` 一致 |
| 不是瞬移 | `RESCUING` 期间兔子单帧最大位移 **9.33 px** = 560 px/s ÷ 60，逐帧 move_toward |
| 恢复后状态 | 全部 `RIDING` + `accident=NONE`，氧气 8.0，控制权停在乌龟可继续操作 |
| SHIFT 走的是真实输入路径 | 除“不输入”外全部 `switch_via=action`（`InputEventKey` → `_unhandled_input` → `toggle_control`） |

**关于“尾巴里的第二次事故”**：Z3 的失败试次里，恢复后再跑 1 s 会撞上下一组 rock10
（56180），事故计数从 +1 变成 +2。这不是救援连锁——探针恢复后就不再有输入，乌龟
自己开进下一组障碍，是“没接住 → 继续往前开”的真实后果。判定只取“恢复到 RIDING
那一刻”的事故计数（`accident_delta_at_recovery`），另记尾部计数备查。

## 6. 回归与未测

- 没有改任何生产脚本；本轮只新增 `scripts/test/stage4_rescue_boost.gd` 与
  `scenes/stage4_rescue_boost.tscn`。
- 完整赛道窗口化回归（§七-10）仍未跑，本轮证据全部是 headless。
- 只测了“撞进低梁”这一种落水来源（`_rabbit_contact()` 的空中分支）。其它落水/事故
  入口（氧气耗尽、乌龟撞礁）的救援不在本轮范围。
- 没测 Z2（240 → 276）——Z1/Z3 已经覆盖窗口的两端，Z2 必在两者之间。
- **真人试玩 `NOT TESTED`。**

## 7. 已知问题

| 问题 | 现状 | 影响 |
|---|---|---|
| 救援窗口偏宽 | Z1 2.0 s / Z3 1.6 s 内开始下潜都能接住 | 失误后的惩罚仍偏“按一下就好”，是 PHASE-F §6 的同一项，本阶段未改 |
| Z3 加速后窗口更短 | 299 px/s 下 2.68 s 跑完 800 px，距离判失败先于计时器 | 玩家在 Z3 吃食物后落水，实际反应时间比 Z1 短；若日后要统一，应改救援计时或落水点，而不是降速 |
| 只验证了“梁” | 落水来源单一 | 其它来源的兔子入水深度/位置相同（`RESCUE_RABBIT_DEPTH` 固定），风险低但未实测 |
| 无音频 | 接住/失败只有文字与位移 | 音频冻结 |

## 8. 复现

```bash
D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage4_rescue_boost.tscn \
  > docs/reports/logs/phase-r/rescue-boost.log 2>&1
```

- 日志：`docs/reports/logs/phase-r/rescue-boost.log`（`RESCUE-BOOST: DONE rows=25 fails=0 checks=8`，
  stderr 0 字节）
- 数据：`docs/reports/longrun/phase-r-rescue-boost.json`
- 跑前备份：`docs/reports/logs/phase-r/best.before.json`（跑完 `best.json` 未变）

## 9. QC

任务 `tbb-stage4-rescue-boost`：1–6 `pass`（证据见 §4/§5），7（真人）`pass` 仅表示
**报告如实写了 `NOT TESTED`**，不代表做过真人试玩。
