# PHASE O — TURTLE SNACK RUSH 单一原型

任务：`TBB-LONGRUN-PLAYABILITY-02` §一 / §二（首个固定遭遇）/ §七-3
日期：2026-11-12
阶段：STAGE 4（未进入 STAGE 5）
性质：**接入正式赛道**（`race.tscn` 的 55 组关卡），不是独立测试场景。
本轮只做 Zone 1 的第一个固定遭遇；随机抽取池留给 §四（Phase P）。

> 证据类型：
> - 自动化测试：`stage4_snack_rush.gd`（真实物理 + `Input` 引擎代理，headless）
> - 代理驾驶：同一个探针按脚本在接触窗口内控制乌龟/兔子
> - 窗口化自动输入：`--capture-snack` 截图为窗口化引擎内部自动输入，**不是真人试玩**
> - 真人试玩：`NOT TESTED`

## 0. 一句话结果

赛道第一段加速带（x 2550–3250）变成了 **能量海藻团 @ x=3250**，
它后面 450 px 就是本遭遇已确定的障碍 `beam1`（3700–3870）。
操控乌龟经过 → 自动吃下（无新按键）→ `TURBO!` + 1.15× 整组加速 → 过梁 +180 px 后
平滑回巡航；全程操控兔子 → 食物正常飘过，不扣氧、不计事故、不填 BRO METER。
加速期间碰撞判定照常生效（吃下后不操作会撞梁）。

## 1. 实现位置

| 文件 | 改动 |
|---|---|
| `scripts/systems/level_data.gd` | `SNACK_LEAD/SNACK_BOOST_SCALE/SNACK_CONTACT_PX/SNACK_BOOST_TAIL`；`snack_encounters()`；`ZONE_OBSTACLE_POOL`（Phase P 用） |
| `scripts/race.gd` | 食物遭遇缓存、接触窗口判定、进食/加速/收尾、吞食与 TURBO 绘制、`--capture-snack`；删除旧的“进带自动提速” |
| `scripts/actors/turtle_controller.gd` | TURBO 改为整组事件：`if boosting: target = boost_target`（换兔子过障碍时仍继续） |
| `scripts/ui/hud.gd` | 左下新增一行：`TURBO 加速中` / `前方海藻 - 换乌龟去吃`（不常驻空行） |
| `scripts/autoload/locale.gd` | `hint.snack` / `feedback.turbo` / `hud.turbo` / `hud.snack_ahead` / `world.snack` |
| `scripts/test/stage4_snack_rush.gd` + `scenes/stage4_snack_rush.tscn` | 三个 case 的自动化验证 |
| `scripts/test/stage4_metrics.gd` | 旧 `BOOST_LANE_SPEED` 指标改为 `SNACK_BOOST_SCALE`（不再断言已删除的进带提速） |

### 食物位置怎么算

每段旧加速带 → 它前方第一组固定障碍，食物放在障碍前 `SNACK_LEAD=450 px`，
再夹回带内。9 段带的结果：

| 带 | 带范围 | 障碍 | 食物 x | 食物→障碍 |
|---|---|---|---|---|
| 1 | 2550–3250 | beam1 3700 | **3250** | 450 |
| 2 | 13700–14400 | rock3 14550 | 14100 | 450 |
| 3 | 18400–19100 | gate3 19400 | 18950 | 450 |
| 4 | 25800–26500 | rock6 26800 | 26350 | 450 |
| 5 | 33400–34100 | shark5 34200 | 33750 | 450 |
| 6 | 53000–53500 | shark8 53550 | 53100 | 450 |
| 7 | 54200–54900 | beam8 54620 | 54200 | 420 |
| 8 | 58900–59400 | shark9 59540 | 59090 | 450 |
| 9 | 62100–62600 | gate8 62930 | 62480 | 450 |

本轮只验证第 1 段；其余 8 段是 §五“实测每个区域的食物遭遇”的输入。

## 2. 实测（headless，真实物理，60 Hz，8× 墙钟）

命令与日志：`docs/reports/logs/phase-o/snack-rush.log`，数据：
`docs/reports/longrun/phase-o-snack.json`。

三个 case 都从 x=2560（rock1 尾端之后）跑到 x≈4400：

| case | 驱动 | 吃到 | 最高速 | 加速到障碍 | 预警 | 结果 |
|---|---|---|---|---|---|---|
| eat | 乌龟吃 → 3300 换兔子趴低 | ✅ x=3250 | 253.0 | ✅ | **4.70 s** | 过梁、无事故、仍骑乘 |
| skip | 全程兔子，3300 趴低 | ❌ | 220.0 | — | 5.00 s | 过梁、无惩罚、仍骑乘 |
| hit | 乌龟吃下后不操作 | ✅ | 253.0 | ✅ | — | `beam1` 命中（RABBIT_STUN） |

判定项：

- `ate` / `boost_at_obstacle` / `speed_raised` / `single_boost`（253 = 220×1.15，一次）
  / `back_to_cruise`（出遭遇后 ≤3 px/s 回到 220）/ `warning_ge_4s` / `passed_clean`；
- skip：`not_eaten` / `cruise_speed`（3400 处仍是 220）/ `no_penalty`
  （氧气 8.0 满、BRO METER 0、事故 NONE）/ `passed_clean`；
- hit：`collision_alive`。

## 3. 预警时间怎么算

食物在障碍前 450 px，所以吃下时障碍已经进入 1100 px 视野：

```
Z1 220 → 253：(1100−450)/220 + 450/253 = 2.95 + 1.78 = 4.73 s   （实测 4.70）
Z2 240 → 276：650/240 + 450/276 = 2.71 + 1.63 = 4.34 s
Z3 260 → 299：650/260 + 450/299 = 2.50 + 1.50 = 4.00 s
```

全部 ≥4 s。注意这是**视觉上限**：障碍最远只能在 1100 px 视野内出现，
Z3 巡航 260 px/s 时理论最大预警是 `1100/260 = 4.23 s`，所以“双角色复杂障碍 ≥5 s”
若按“首次可见”严格计算，在当前镜头下是不可能达到的（不是本机制造成的）。
本轮的处置（沿用 PHASE-N §7）：

- 随机池里的高墙/浮木只在**没吃食物（巡航）**的遭遇中出现；
- 加速遭遇只抽单角色障碍，实测窗口 ≥0.43 s（鲨鱼 0.50 s）；
- 5 s 这条按“上一组尾端到组合起手”的既有 5.19 s 间距保留，Phase Q 再向制作人确认口径。

## 4. 设计约束的落实

| 要求 | 落实 |
|---|---|
| 不新增进食按键 | 接触窗口 + 控制权，无新 InputMap |
| 不吃不惩罚 | skip case：速度、氧气、BRO METER、事故全部不变 |
| 只服务一次遭遇、不叠加 | `snack_boost_until_x` 单次；再吃需要下一段食物（Phase P） |
| 过障碍后恢复巡航 | 障碍尾端 +180 px 后目标回 `base_speed`，`accel_down=300` 平滑 |
| 加速期间碰撞不失效 | hit case：不操作即撞梁 |
| 兔子轨迹/落脚协调 | 跳跃用 `turtle.speed` 起跳，加速只改水平速度；两个 case 都仍骑乘 |
| 食物可见且后方障碍轮廓可见 | 截图 `stage4_snack_before.png`：海藻团 + 450 px 后的码头横梁同屏 |
| TURBO 提示 | `TURBO! GULP!`（中文 `TURBO！ 吞下去了！`）+ HUD `TURBO ACTIVE` |
| 不吃不是“伪装的惩罚机关” | 食物和障碍独立：不吃只是不加那 15% |

## 5. 截图证据

- `screenshots/stage4_snack_before.png` — 食物 + 后方横梁同屏，HUD 显示 `SNACK AHEAD`。
- `screenshots/stage4_snack_gulp.png` — 吞食瞬间：绿团吸到嘴前，`TURBO! GULP!`。
- `screenshots/stage4_snack_turbo.png` — 加速中：壳后速度线、`TURBO ACTIVE`、状态 `BOOSTING`。

## 6. 回归

| 测试 | 结果 |
|---|---|
| `stage4_snack_rush`（3 case） | **PASS 3/3** |
| `stage3_selftest`（完整流程 + 自动驾驶） | **PASS** |
| `stage4_metrics` | **PASS**（新增 snack boost 断言） |
| `stage4_level_audit` | 跑通，55 组 / 0 无解 |
| `stage4_experience_rework` | 跑通，判定与改前一致 |
| `best.json` | 未变（`296.63 / 0 / -1 / 54`），测试前后核对 |

## 7. 已知问题 / 下一步

1. 其余 8 段食物还没逐段实测（§五），而且它们后面的障碍在当前代码里仍是**固定种类**；
   Phase P 才把“障碍种类”换成按种子抽取。抽到的种类必须复用同一段带后第一组
   的 x/w 槽位（不能新增组，避免破坏 5.19 s 连招间距）。
2. Z3 的 `1100/260 = 4.23 s` 视野上限与“复杂障碍 ≥5 s”冲突，已在 §3 记录；
   要么把复杂障碍排除在加速池外（默认做法），要么由制作人放宽口径。
3. 食物美术是 `_draw` 的原生图形（灰盒），不是正式素材。
4. 真人是否觉得“吃=更快更险”是好选择：`NOT TESTED`。

## 8. QC 判定（`tbb-stage4-snack-rush`）

| # | 标准 | 判定 | 证据 |
|---|---|---|---|
| 1 | 正式赛道 x=3250 有食物，后方 450 px 是 beam1 | **pass** | `stage4_snack_before.png`、`snack-rush.log` |
| 2 | 操控乌龟自动吃、无新键、TURBO + 1.15× | **pass** | eat case；`snack_gulp/turbo.png` |
| 3 | 操控兔子不进食、无惩罚 | **pass** | skip case（氧气满 / BRO 0 / 事故 NONE） |
| 4 | 加速期间碰撞仍生效 | **pass** | hit case（beam1 命中） |
| 5 | 首次可见到碰撞 ≥4 s | **pass** | 4.70 s（eat） |
| 6 | 两种情况过障碍后仍骑乘、兔子没落水 | **pass** | 两个 case `riding=true`、`accident=NONE` |
| 7 | 一次遭遇只加速一次、之后回巡航 | **pass** | `single_boost` / `back_to_cruise` |
| 8 | 玩家不看数字也能感知风险收益选择 | **NOT TESTED** | 需真人 |

## 9. 复现命令

```bash
# 自动化（三个 case）
D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/stage4_snack_rush.tscn > docs/reports/logs/phase-o/snack-rush.log 2>&1

# 窗口化截图（引擎内部自动输入，不是真人）
D:/Godot_v4.7-stable_win64_console.exe --path D:/GAMESTUDIO/TURBBIT \
  res://scenes/race.tscn -- --capture-snack stage4_snack_before
```

## 10. 限制

- 探针只验证“吃/不吃/吃了不操作”三条确定性路径，不验证“边跑边判断”的手感。
- 加速 ramp 是 420 px/s²，吃下后约 0.08 s 到 253；探针记录的是物理步内的真实速度。
- 视觉是灰盒原生绘制；音效、正式美术仍冻结。
