# PHASE G — 惩罚统一（BRO METER 三格是唯一持续事故系统）

日期：2026-11-12
任务：`TBB-LONGRUN-PLAYABILITY-01` / Phase G
状态：**工程验证完成；真人试玩 NOT TESTED**
结论：`daze_time` 降为短硬直/姿态/物理恢复，封顶 `DAZE_CAP = 3.6`；
所有有效失误当场记 1 格 BRO METER，第三格播一次联合事故，演完复位、清格、给 1.5 s 宽限，
本局继续。没有第二套“攒到 9.5 就翻船”的倒计时。

---

## 1. 这一步要解决什么

Phase C 审计 P2 列的已知偏差：**同一场游戏里并存两套失衡惩罚。**

- `daze_time`：撞一下加一截，攒到 `SLIP_FALL_TIME / SINK_DANGER_TIME = 9.5` 自动触发
  `RABBIT_SLIP` / `TURTLE_REEF`。
- BRO METER：三格，第三格播联合事故。

后果不是“惩罚多”，而是**因果错位**：

1. 玩家撞上障碍时，可能既不扣格也不扣分，只看到“失衡 40%”；
2. 几秒后什么都没再做，角色却自己掉水里/翻壳——玩家找不到自己刚刚做错了什么；
3. 乌龟撞浪只加失衡、不当场记账，事故被推迟到下一段空档才出现；
4. 同一次碰撞可以在两个时刻各产生一次后果，叠加成“无法挽救的连锁”；
5. HUD 的“倾覆风险”条永远只到 38%，但它承诺的是一个会致命的风险。

Phase G 只做一件事：**把持续惩罚收敛成一套，并且让每一次失误在发生当下就有确定的账。**

---

## 2. 新模型

### 2.1 分工

| 系统 | 职责 | 边界 |
|---|---|---|
| `daze_time` | 短硬直、姿态刻度、滑移/下沉的视觉与物理恢复 | 封顶 `DAZE_CAP = 3.6`，**不触发任何事故状态** |
| BRO METER | **唯一**持续事故惩罚 | 3 格；每格 −100；第三格联合事故 −200 |
| 事故状态（`RABBIT_WATER` / `RABBIT_STUN` 等） | 单次事件的表现与恢复流程 | 进入时记 1 格，不额外记第二笔 |

`DAZE_CAP = 3.6` 是旧落水线 9.5 的 38%。取值要卡在两件事之间：
一次兔子撞击 3.2 不能直接顶到上限，一次乌龟撞击 4.4 会被截到 3.6。
姿态停在“明显摇晃”，`phase_name()` 永远到不了 `EDGE` / `CRITICAL`，
`is_falling()` 永远为 false。

### 2.2 一次有效失误的完整账

```
碰撞判定（hit_groups 去重）
  → add_imbalance(...)        # 只做短硬直/姿态，封顶 3.6
  → note_mistake(reason)      # accident_count += 1、−100、BRO METER +1
  → 若第三格：bro_joint_pending、−200、BRO_BREAK 演出
```

去重靠 `hit_groups`：同一个障碍组的判定框在离开前只记一次。
测试里对同一个鲨鱼矩形连续调用两次 `_check_hazards()`，BRO METER 只 +1。

### 2.3 第三格联合事故

| 阶段 | 行为 |
|---|---|
| 开始 | `BRO_BREAK`、闪白 0.8、乌龟停速、清掉底部提示与海浪建议 |
| 演出 | 1.4 s 原地抖动，中央“BRO METER 满 —— 联合惩罚！” |
| 结束 | 乌龟复位到水面巡航深度、兔子回壳、BRO METER 清零、双方 1.5 s 宽限、`hazard_cooldown = 2.6 s` |
| 文案 | “重新出发！”——**不是**“获救”，联合惩罚不是被谁救了一命 |
| 之后 | 本局继续；三格可以再次填满并再次触发 |

### 2.4 两种身体的事故表现

| | 兔子 | 乌龟 |
|---|---|---|
| 触发 | 撞低梁/岩石/鸟、空中撞 | 撞浪、撞礁 |
| 表现 | `RABBIT_STUN` → `STUNNED` 0.8 s，滑移按 `daze_time` | 短暂下沉（dunk）、短失衡、速度 ×0.6 |
| 累积 | 封顶 3.6，不会自己滑进水里 | 封顶 3.6，不会自己翻壳 |
| 记账 | 1 格 | 1 格 |

### 2.5 落水救援与三格的关系

- `RABBIT_WATER` 进入时记 1 格；`_rescue_catch` 成功**不退还**这一格；
- `_rescue_miss` 不追加，0.8 s 后兔子被冲回壳上，只发生一次；
- 救援期间 `bro_joint_pending` 仍可被第三次失误填满 → 联合事故照常接管。

“无法挽救的连锁”在两个地方被挡住：救援失败只恢复一次；联合事故结束后
`hazard_cooldown = 2.6 s` + 双方 1.5 s 宽限，期间不能再被同一段障碍追罚。

### 2.6 正常动作不记账

跳（↑）、潜（↓）、跃、SHIFT 切换、正常巡航：0 格、0 分。
`stage4_penalty` §5 用真实输入路径逐项验证。

---

## 3. 参数

| 参数 | 值 | 位置 | 说明 |
|---|---|---|---|
| `DAZE_CAP` | 3.6 | `tuning.gd` | 新增；daze 硬上限 |
| `SLIP_FALL_TIME` / `SINK_DANGER_TIME` | 9.5 | `tuning.gd` | 保留为不可达的旧线，只作对照 |
| `RABBIT_HIT_IMBALANCE` | 3.2 | `tuning.gd` | 一次兔子撞击 |
| `TURTLE_HIT_IMBALANCE` | 4.4 | `tuning.gd` | 一次乌龟撞浪 |
| `STUN_TIME` | 0.8 | `tuning.gd` | 兔子短硬直 |
| `HAZARD_COOLDOWN` | 3.0 | `tuning.gd` | 失误后的免判窗口 |
| `JOINT_SHOW_TIME` | 1.4 | `race.gd` | 联合演出 |
| 联合后宽限 | 1.5 s | `race.gd` | 大于 QC 要求的 1.4 s |
| 失误 / 联合扣分 | −100 / −200 | `game_manager.gd` | 与 `SCORE_MODEL=2` 一致 |

---

## 4. 改动文件

- `scripts/systems/tuning.gd`
  - 新增 `DAZE_CAP`；阶段注释改为“三格唯一”。
- `scripts/actors/rabbit_controller.gd` / `scripts/actors/turtle_controller.gd`
  - `add_imbalance()` 改为 `minf(daze_time + amount, DAZE_CAP)`，不再能越过临界；
  - 乌龟的旧五段下沉代码留在 `SURFBOARD_PHYSICS=false` 分支，生产不可达。
- `scripts/autoload/game_manager.gd`
  - `note_mistake()` 成为唯一记账入口：`accident_count`、`perfect_streak`、−100、
    BRO METER +1、第三格 `bro_joint_pending` 与 −200；
  - `note_accident()` 只做分类统计（兔子事故/乌龟事故），再转 `note_mistake()`。
- `scripts/race.gd`
  - 删除 `_check_hazards()` 之后“daze 超线 → 自动事故”的整块分支；
  - 删除骑乘中 `is_falling()` → `RABBIT_SLIP` 的延迟分支；
  - `_turtle_contact()` 当场 `note_mistake("TURTLE_WAVE")`；
  - `_trigger_accident()` 不再自己 +1，避免与 `note_mistake()` 双记；
  - `_start_joint_show()` 清底部提示与海浪建议（旧提示会和联合演出互相矛盾）；
  - `_end_joint_show()` 不再发 `rescue_done`（会误显示“获救”），改用
    `center.bro_recover`；
  - 新增 `--capture-penalty <prefix>` 窗口化取证入口。
- `scripts/autoload/locale.gd`
  - 新增 `center.bro_recover`（“重新出发！”/“BACK IN ACTION!”）；
  - `hud.rabbit_risk` / `hud.turtle_risk` / `hud.standby_risk` 从“失衡/倾覆风险”
    改为“晃动/不稳”——daze 已不判事故，旧文案承诺的是一个不存在的结果。
- `scripts/race.gd`（HUD 数据来源，不改布局）
  - `rabbit_imbalance_pct()` / `turtle_imbalance_pct()` 的归一化分母从旧事故线 9.5
    改为 `DAZE_CAP`：条现在能真正走满，最大档就是封顶档。
- `scripts/test/stage2_selftest.gd`
  - §2/§3 改为断言新模型（封顶、不自动事故、三格、复位）。
- `scripts/test/stage4_penalty.gd` + `scenes/stage4_penalty.tscn`（新增）
  - 37 条断言覆盖本阶段全部规则。

---

## 5. 证据分层

### 5.1 自动断言（headless）

- `docs/reports/logs/stage4-penalty-phaseg.log`：37 条 `ok`、0 条 `FAIL`、
  `STAGE4 PENALTY: PASS`。
  覆盖：
  1. 手动把 daze 设到 11.5（旧线以上）→ 无事故、兔子仍在骑乘；
  2. `add_imbalance` 连加 5 次 → 兔子/乌龟都停在 `DAZE_CAP`；
  3. 一次乌龟撞浪 = 1 格 + −100 + `NONE` + dunk，且只标乌龟；
  4. 一次兔子撞击 = 1 格 + `RABBIT_STUN` + `STUNNED`；
  5. 第三次 = 3/3 + `BRO_BREAK` + 分数 1000→500；
  6. 联合结束后：格清零、双方宽限 > 0、乌龟回到 `NEUTRAL_DEPTH`、状态回到 RUNNING；
  7. `RABBIT_WATER` 记 1 格；接住不退；没接住不追加；
  8. 同一鲨鱼矩形连判两次只 +1；
  9. 跳/潜/跃/SHIFT 0 格 0 分。
- 其余回归：`stage2_selftest`、`stage3_selftest`、`stage4_bro_meter`、`stage4_flow`、
  `stage4_core_experience`、`stage4_bilingual`、`stage4_hud_priority`、
  `stage4_shift_graybox`、`stage4_proto` 全部 PASS。
- 完整赛道两圈：`docs/reports/logs/playtest-stage4-penalty.log`，
  `passed=55/55`、`accidents=0`、`score=9500`、`failures=0`。

### 5.2 窗口化脚本重放（直接调用游戏自己的碰撞入口，不是按键）

命令：

```
D:/Godot_v4.7-stable_win64_console.exe --path . res://scenes/race.tscn -- --capture-penalty phase-g
```

日志 `docs/reports/logs/penalty-demo.log`，截图：

| 截图 | 看到什么 |
|---|---|
| `screenshots/phase-g_hit_turtle.png` | 第一格：乌龟 dunk、BRO METER 1/3、−100 |
| `screenshots/phase-g_hit_rabbit.png` | 第二格：兔子 `STUNNED`、顶部“咚！兔子被撞晕”、2/3、900 分 |
| `screenshots/phase-g_meter_full.png` | 第三格：3/3、中央“联合惩罚！”、底部旧提示已清空 |
| `screenshots/phase-g_recovered.png` | 演出后：0/3、乌龟回水面、中央“重新出发！”、分数保持 600 |

分数链（日志 `penalty-demo.log` 的 `PENALTY DEMO` 行）：
`1000 −100 浪 +100 干净通过 −100 兔 −100 浪 −200 联合 = 600`。
中间那笔 +100 是演示时乌龟自动巡航真正越过一组障碍得的，不是脚本补贴；
三笔失误与联合扣分逐笔都在 `score_log` 里，截图上的 900/900/600 由此而来。

失衡姿态取证（`--capture-imbalance`，日志 `docs/reports/logs/imbalance-demo-phaseg.log`）：

| 截图 | daze | HUD |
|---|---|---|
| `screenshots/stage4_poseg_relaxed.png` | 1.0 | 兔子晃动 28% |
| `screenshots/stage4_poseg_sliding.png` | 2.5 | 兔子晃动 69% |
| `screenshots/stage4_poseg_capped.png` | 3.6（封顶） | 兔子/乌龟晃动 100%，但仍是骑乘、无事故 |

旧的 `stage4_pose_edge.png` / `stage4_pose_critical.png` 对应的 6.0 / 8.4 失衡已不可达，
已移入 `_attic/2026-11-12/`。

### 5.3 OS 级真实按键：**本机无法执行**

与 Phase F 相同：`SendInput` 返回 0，`keybd_event` 在自建文本框里也收不到字符
（`logs/input-injection-sendinput.log`、`logs/input-injection-keybd.log`）。
5.2 是脚本直接调用 `_turtle_contact()` / `_rabbit_contact()` 重放，HUD 与演出走真实主流程，
但既不是 OS 按键，也不是人玩的；不能描述成真人键位测试。

### 5.4 真人试玩

**NOT TESTED。** 没有制作人实际坐在键鼠前完成一次“撞三次 → 联合事故 → 重新出发”。

---

## 6. 前后对比

| 场景 | 旧行为 | 新行为 |
|---|---|---|
| 兔子撞低梁 | 只加失衡；攒到 9.5 后某刻自动落水 | 当场 1 格 + −100 + 0.8 s 硬直 |
| 乌龟撞浪 | 只加失衡 + dunk；事故推迟 | 当场 1 格 + −100 + dunk |
| 连续贴住同一障碍 | 取决于判定与计时，存在多记风险 | `hit_groups` 保证一次只记一次 |
| 失衡条 | 条只走到 38%，但文案声称“倾覆风险” | 条走满 100% 即封顶档，文案改为“晃动” |
| 三格满 | 演出后显示“获救” | 演出后“重新出发！”，清格、复位、1.5 s 宽限 |
| 失误后的提示 | 海浪建议与联合演出同时出现 | 联合演出开始时清空底部提示 |
| 落水救援 | 自动放回（Phase F 前）/ 记 1 格（Phase F 后） | 记 1 格，接住不退，失败不追加 |

---

## 7. 已知问题

| 问题 | 现状 | 影响 | 下一步 |
|---|---|---|---|
| ~~HUD 失衡条永远不到 40%~~ | **已修**：分母改为 `DAZE_CAP`，封顶拍出 100%；文案改为“晃动/不稳” | 条不再承诺“掉下去” | 观察真人是否把 100% 误读为“要出事” |
| 旧下沉模型仍在 | `SURFBOARD_PHYSICS=false` 分支保留五段下沉 | 生产不可达，但读代码会误会 | 制作人确认后删除 |
| 死代码 | `is_falling()` / `can_sink_danger()` 无生产调用者 | 只被测试引用 | 与上一条一起清理 |
| 救援偏宽容 | Phase F 未改：2.0 s 内开始下潜都能接住 | 失误后的惩罚偏轻 | 真人反馈或 Phase J |
| 无音效 | 失误/联合只有文字与位移 | 反馈强度有限 | 音频冻结 |
| 联合演出时长 | 1.4 s 固定 | 连续失误时节奏被拉长 | 真人节奏判断 |

---

## 8. 有趣性自评（仅工程视角）

- 能否一句话说清：**能**——“三次有效失误 = 三格 = 联合事故”。
- 有没有“我做了判断然后成功”的瞬间：**有，但它是防守性的**。撞一次后看到 1/3，
  玩家知道还剩两次机会，可以主动降速挑安全线，而不是被一个看不见的计时器判死。
- 操作错了有没有可见后果：**有，而且是即时的**——1 格、−100、短硬直、HUD 立刻变。
- 是否多了一个想再试一次的理由：**有保留**。这次改的是“输得服不服”，不是“想不想再来”；
  真正的重复游玩理由仍要靠 Phase H 的节奏与 Phase J 的难度。
- 本阶段最无聊的 30 秒：没有新增；空档问题仍在 Zone 1 起点（最长 5.91 s）。

判定：`有保留`。公平性和可读性明显提升，乐趣本身没有新增。

---

## 9. QC

任务 `tbb-stage4-penalty`：

- 1–6：`pass`（证据见 §5）。
- 7（一句话规则 + 真人 NOT TESTED）：机械部分可判，但“玩家能否一句话说清”必须有真人；
  保持 `pending`。

因此该任务整体 `NOT_VERIFIED`，不描述为已完成验收。

---

## 10. 下一阶段

Phase H：三区节奏与障碍空间。

Phase G 留下的边界条件：

- 只潜覆盖 38/55、必须 SHIFT 仅 11/55（`PHASE-C-AUDIT.md` §2.1–2.2）没有改动；
- 鲨鱼判定上沿 34 px 隐形带、Z3 高墙前距 2.94–3.25 s 起手仍在；
- 惩罚统一之后，“下潜是万能解”的问题才第一次可以被单独测量——
  先重跑解法矩阵，再决定改哪一类组，不要凭旧数据直接动几何。
