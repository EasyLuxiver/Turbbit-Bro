# PHASE F — 主动救援原型（兔子落水，乌龟去接）

日期：2026-11-12
任务：`TBB-LONGRUN-PLAYABILITY-01` / Phase F
状态：**工程验证完成；真人试玩 NOT TESTED**
结论：**选“下潜接住水面兔子”接入主流程；“空中跃起接住”保留为对比原型，不进主流程。**

---

## 1. 这一步要解决什么

Phase C 审计里，救援是最大的“两个身体没有真正分工”的缺口：

- 旧行为：兔子落水 → 1.6 s 计时器自动放回壳上，玩家零输入。
- 后果：落水不是玩家要处理的事故，只是一段等待；乌龟没有“必须由它来做”的动作，
  兔子和乌龟的价值仍然可以被单乌龟覆盖。

Phase F 要验证的是：**兔子落水后仍然存在，乌龟必须主动过去，玩家在有限时间内做一个
位置/深度判断；成功有可见反馈，失败有有限恢复，不产生无限连锁。**

---

## 2. 方案对比

两个原型都用独立入口，不改正常赛道数值：

| 方案 | 入口 | 玩家动作 | 接住窗口 | 结果 |
|---|---|---|---|---|
| 1. 下潜接住水面兔子 | `--rescue-proto` | SHIFT 到乌龟 + 按住 ↓ | 开始下潜 0.0–2.0 s；接住 1.82–2.65 s | **选中** |
| 2. 跃起接住空中兔子 | `--rescue-proto-air` | SHIFT 到乌龟 + 按 ↑ | 开始跃起 0.0–1.0 s；接住 0.53–1.05 s | 保留为对比，不进主流程 |

### 2.1 方案 1：下潜接住（选中）

几何（冲浪板物理，`tuning.gd` + `mount_controller.gd`）：

- 巡航落点 `mount y = 276`；满潜落点 `426`。
- 兔子落水点：乌龟前方 `RESCUE_RABBIT_AHEAD = 520 px`，深度 `RESCUE_RABBIT_DEPTH = 460`。
- 接人框沿用普通接人：横向 120 px，纵向 `−60..+90`。
  `460 − 426 = 34`，满潜够得着；`460 − 276 = 184`，巡航够不着。
- 兔子在水里以 `12 px/s` 缓慢下沉；窗口 `RESCUE_ACTIVE_TIME = 3.2 s`。
- 失败后 `RESCUING 0.8 s`，兔子被“冲回壳上”，不是瞬移，也不再触发第二次事故。

状态流：

```
RABBIT_WATER
  → mount = RESCUE_ACTIVE, 兔子在 (turtle.x + 520, 460)
  → 玩家 SHIFT（若还在兔子身上）+ 按住 ↓
  → 乌龟下沉；横向进入 120 px 且纵向进入 −60..90
  → _rescue_catch：attach、mark_riding、accident=NONE、补氧、清提示、反馈“接住了！兄弟！”
  → 或 3.2 s 到期 / 乌龟越过兔子 280 px
  → _rescue_miss：mark_rescuing(0.8)、反馈“没接住……兔子被冲回壳上”
  → 0.8 s 后自动回壳，accident=NONE；只发生一次
```

### 2.2 方案 2：跃起接住（对比后不采用）

几何：兔子在乌龟前方 240 px、从 y=40 以 500 px/s² 下落；只有乌龟 `leap_active` 时
才判定接住，越过水面线 460 判失败。

数据（`phase-f-rescue-air.json`）：

```
none        missed 1.27 s
dive_only   missed 1.27 s
leap_0.0    caught 0.53 s
leap_0.2    caught 0.55 s
leap_0.4    caught 0.65 s
leap_0.6    caught 0.73 s
leap_0.8    caught 0.85 s
leap_1.0    caught 1.05 s
leap_1.2+   missed 1.27 s
```

不采用的理由（工程判断，不是真人结论）：

1. 可用输入窗只有 1.0 s，比下潜的 2.0 s 窄；而且“早跳”比“晚跳”更容易成功，
   玩家学到的规则是“看到就立刻跳”，不是一个位置判断。
2. 与鲨鱼/高墙已有的“乌龟跃起”动作重叠，乌龟没有获得新的专属动词。
3. 落水救援的因果更直观：“兔子在水里 → 壳沉下去接”；空中版本要求玩家理解
   “兔子为什么在空中”，灰盒阶段解释成本更高。
4. 下潜版本强制乌龟改变深度，和“水面巡航”的默认状态形成对照，更能体现两个身体的分工。

方案 2 的代码留在 `--rescue-proto-air` 后面，仅作对比复现；正常流程不会触发
`RABBIT_AIR`。

---

## 3. 自动探针数据（方案 1）

文件：`docs/reports/longrun/phase-f-rescue.json`
日志：`docs/reports/logs/rescue-probe.log`
场景：`scenes/rescue_probe.tscn`（真实按键 `Input.action_press`，自动驾驶代理）

| 试次 | 结果 | 判失败/接住时刻 | 恢复 |
|---|---|---|---|
| none（不输入） | missed | 3.18 s | 3.97 s 回 RIDING/NONE |
| shift_only（只切乌龟） | missed | 3.18 s | 3.97 s |
| dive_0.0 … dive_1.2 | caught | 1.82 s | 立即 |
| dive_1.4 | caught | 1.95 s | 立即 |
| dive_1.6 | caught | 2.18 s | 立即 |
| dive_1.8 | caught | 2.42 s | 立即 |
| dive_2.0 | caught | 2.65 s | 立即 |
| dive_2.2 / 2.6 | missed | 3.18 s | 3.97 s |
| shift_then_dive（先 SHIFT 再 ↓） | caught | 1.82 s | 立即 |

每个试次：`accident_count = 1`、`bro_meter = 1`，没有第二次事故。
接住时氧气恢复到 `OXYGEN_RECOVERED`（8.0）。

**读法：**

- “不潜”和“只切人不潜”都失败 → 不是计时器自动放回。
- 先切乌龟再潜也成立 → 玩家在兔子身上落水时，SHIFT 就是救援第一步。
- 窗口很宽（2.0 s 内开始下潜都能接住），这是有意的：救援是事故后的第二次机会，
  不是第二个高难度障碍。代价是它目前偏宽容，见 §6。

---

## 4. 接入主流程

改动文件：

- `scripts/race.gd`
  - `RABBIT_WATER` 不再走 1.6 s 自动放回，改为 `RESCUE_ACTIVE`；
  - `_tick_recovery` 增加救援分支：兔子下沉、计时、接住/失败；
  - `_rescue_catch` / `_rescue_miss`：成功反馈、补氧、清空提示、有限恢复；
  - `_update_lessons` 在事故期间不弹首次教学，避免顶掉救援提示；
  - `_tick_rabbit` 的 `RESCUING` 改为 `move_toward`，兔子被冲回而不是瞬移。
- `scripts/autoload/game_manager.gd`
  - 事故中只允许 `RABBIT_WATER` 期间 SHIFT（救援必须能换到乌龟）。
- `scripts/autoload/locale.gd`
  - `hud.rescuing`、`hud.rescue_return`、`feedback.rescue_ok`、`feedback.rescue_miss`、
    `prompt.rescue_shift`、`prompt.rescue_dive`。
- `scripts/ui/hud.gd`
  - 救援状态显示剩余秒数；失败恢复阶段显示“兔子回壳中”，不再误报“潜到兔子下面”。

主流程触发条件没有新增：仍是现有的 `_trigger_accident("RABBIT_WATER")` 路径
（兔子空中落水、空中撞击落水）。区别只是后续从计时器变成了玩家动作。

---

## 5. 证据与测试分层

### 5.1 自动探针（headless，引擎内输入代理）

- `docs/reports/longrun/phase-f-rescue.json`
- `docs/reports/logs/rescue-probe.log`
- `docs/reports/longrun/phase-f-rescue-air.json`
- `docs/reports/logs/rescue-air-probe.log`

### 5.2 窗口化运行（引擎内输入代理，非 OS 真实按键）

- `docs/reports/logs/rescue-demo-catch.log` → `screenshots/rescue_demo_catch.png`
- `docs/reports/logs/rescue-demo-miss.log` →
  `screenshots/rescue_demo_miss.png`、`screenshots/rescue_demo_miss_late.png`

截图能看到：乌龟带操控圈下潜、兔子贴回壳上、中央“获救”、底部“接住了！兄弟！”；
失败路径看到“没接住……兔子被冲回壳上”，0.8 s 后兔子回到壳上。

### 5.3 窗口化真实按键：**本机无法执行**

尝试用 `keybd_event` / `SendInput` / `PostMessage` 把 ↓ 送进真实游戏窗口。
窗口能被设成前台（`GetForegroundWindow` 与游戏 HWND 相同），但游戏收不到任何
`InputEventKey`；同一个注入方式在自建 WinForms 文本框里也收不到字符：

- `docs/reports/logs/input-injection-keybd.log`：`TEXT=[]`
- `docs/reports/logs/input-injection-sendinput.log`：`SENT=0 TEXT=[]`
  （`SendInput` 返回 0，系统拒绝注入）

结论：**这个执行环境不允许 OS 级合成键盘输入**。因此本次没有“窗口化真实按键”证据；
窗口化截图来自引擎内输入代理。不能把 5.2 描述成真人键位测试。

### 5.4 真人试玩

**NOT TESTED。** 没有制作人实际坐在键鼠前完成一次“看到落水 → 切乌龟 → 下潜 → 接住”。

### 5.5 回归

- 完整赛道两圈：`docs/reports/logs/playtest-stage4-rescue.log`
  `passed=55/55`、`accidents=0`、`score=9500`、`failures=0`。
- 自检：`stage2_selftest`、`stage3_selftest`、`stage4_bro_meter`、`stage4_flow`、
  `stage4_core_experience`、`stage4_bilingual`、`stage4_hud_priority`、
  `stage4_shift_graybox` 全部 PASS。
- 回归写入了测试用 `best.json`，已按备份还原为
  `{"score_model":2,"best_time":296.63,"best_accidents":0,"best_score":-1,"best_streak":54}`。

---

## 6. 已知问题与风险

| 问题 | 现状 | 影响 | 下一步 |
|---|---|---|---|
| 救援偏宽容 | 2.0 s 内开始下潜都能接住；横向 `absf(dx) <= 120` 允许从兔子身后 120 px 接住 | 失误后的惩罚更像“按一下就好”，紧张感不足 | Phase G/J 决定是否改成有符号横向窗（只允许前方/正下方），或缩短窗口到 2.6 s |
| 触发频率 | 每次 `RABBIT_WATER` 都进入 3.2 s 救援 | 连续失误时节奏被拉长 | 用真人节奏判断；必要时只对“高价值落水”启用，普通落水仍快速恢复 |
| 提示语言 | 落水瞬间提示“按住 ↓ 潜下去接住兔子”；若玩家在兔子身上，提示先 SHIFT | 已按控制权分流 | 真人确认第一眼是否看懂 |
| 失败文案 | “兔子被冲回壳上”与实际 0.8 s 回壳一致 | 可读 | 观察是否需要更明显的动作 |
| 无音效 | 成功/失败只有文字与位移 | 反馈强度有限 | 音频冻结，留到解冻后 |
| 空中对比原型 | `--rescue-proto-air` 与 `RABBIT_AIR` 只在原型入口可达 | 生产代码多一条死路径 | 制作人确认不需要对比后可删 |

---

## 7. 有趣性自评（仅工程视角）

- 能否一句话说清：**能**——“兔子落水了，切乌龟潜下去接它”。
- 有没有“我做了判断然后成功”的瞬间：**有，但弱**。探针里“不潜失败 / 潜了接住”
  的因果成立；窗口很宽，判断成分低于操作成分。
- 操作错了有没有可见后果：**有**——3.2 s 后没接住，兔子被冲回壳上，事故计数 +1。
- 是否多了一个想再试一次的理由：**有保留**。救援本身是第二次机会，不是可练习的技巧；
  真正的重复游玩理由仍要等 Phase G/H 的惩罚统一与关卡节奏。

判定：`有保留`。不是“不有趣”，但也不足以单独支撑重复游玩。

---

## 8. QC

任务 `tbb-longrun-rescue`：

- 1–5：`pass`（证据见上）。
- 6（有趣性/第一眼可读）：**pending**，需要真人试玩；当前只能写“有保留”。

因此该 QC 任务整体仍是 `NOT_VERIFIED`，不得描述为已完成验收。

---

## 9. 下一阶段

Phase G：惩罚统一与“下潜不是万能解”。

- 把 `daze_time` 从第二套失衡倒计时降为短硬直/动画；
- BRO METER 三格作为唯一持续事故系统；
- 检查救援计入事故后是否与三格冲突；
- 用 Phase C 的 38/55 数据处理“只潜覆盖”，优先改需要两个身体配合的组，而不是加新障碍。
