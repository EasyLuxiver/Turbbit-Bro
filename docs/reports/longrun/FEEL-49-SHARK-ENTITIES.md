# FEEL-49 · 鲨群实体上冲 / 海鸟误判 / 受击状态收口

- 基线：FEEL-48
- 未导出、未打包、未覆盖 Web/EXE；`best.json` 保持基线。
- 目标：先把鲨群改成“三只持续实体、同一只鱼从水下上冲”；同时修海鸟飞过误判、兔子每撞一次永久加一格、以及随机摧毁障碍的鲨群介入。

## 1. 鲨鱼群

### 之前

- 水里画三只鲨鱼剪影；
- leader 走 `_ambush` 的固定组；
- fat/thin 另生成临时攻击体，看起来像“水中三只 + 凭空攻击”；
- 打完后还会随机挑一个低梁/海鸟，标成 destroyed，生成胖鲨；没有稳定后续，还会把低梁画成断木。

### 现在

`shark6` 只保留位置锚点，正式碰撞/绘制由三只持续实体负责：

- `leader`：队形 `bx + 230`
- `fat`：队形 `bx + 60`
- `thin`：队形 `bx - 110`

三只鱼平时在船底跟随。轮到谁：

1. `WARN`：仍在深水，水面背鳍、气泡、目标圈和“!”；
2. `RISE`：同一只鱼从深水向上冲；
3. `HOLD`：到达攻击位置，才开始用它的身体判伤；
4. `RETREAT`：退回深水，回到队形。

`_shark_attacks` 里放的就是 `_pack_actors` 的那一只（测试用 `is_same` 验证），
不再有第二套攻击体。`RISE` 过程不判伤，避免“乌龟正在下潜/跃起时被上冲鱼穿过”
也算一次命中。

三拍仍是：

| 拍 | 目标 | 安全答案 | 预警 |
|---|---|---|---|
| leader | turtle | 看到“现在——跃起”后 `↑` | 0.95 s |
| fat | rabbit | `SHIFT` 兔子 + `↓` 趴低 | 0.95 s |
| thin | turtle | `SHIFT` 乌龟 + `↓` 下潜 | 1.05 s |

安全间隔 0.70 s；同一时间最多一个攻击帧。鲨群只在玩家实际进入 Z3 后开始，
不会因为 shark6 的组坐标在 Z3 就提前从 Z2 露头。

### 删除

- `trigger_shark_intervention`
- `_tick_shark_intervention`
- 由它产生的 `destroyed_groups` 随机替换
- 测试场的“介入”调用改为状态提示；正式流程不再有“障碍突然消失但无事发生”。

## 2. 海鸟

- 旧版固定判定带在鸟飞过、拉起后仍然有效；视觉上鸟已经在左边，兔子还在带里就会挨一下。
- 现在只有 `bird_pose()["phase"] == "DIVE"` 且 `d > -18` 时，LOW_BIRD 才判伤；
  `RECOVER/CIRCLE` 不再伤人。
- 排泄落地改为兔子身体框与落点圆求最近点，不再用 `rabbit.position.distance_to(land)`；
  半径 44 → 30。
- 新增 `stage19` 的 `bird_pass_no_hit`：飞过位置不判、俯冲航程内仍判。

## 3. 受击状态

- 旧版每次 `_trigger_accident` 都 `+1.0`，衰减 `0.035/s`，一格能挂近 29 秒。
- 现在衰减 `0.45/s`，一次撞击约 2 秒内消失；只有短时间连续挨打才到第二/第三段。
- 不再画三格“血条”，改成头顶一次短促的感叹号/摇晃；仍只改画法，不碰数值、碰撞、控制。
- `stage35` 增加 `visual_stress_not_permanent`。

## 4. 验证

| 测试 | 结果 |
|---|---|
| `stage42_shark_fairness` | PASS（正确 0/0.20/0.35；即时/过晚/错误角色命中） |
| `stage32_shark_timing` | PASS（leader→fat→thin；warn 0.95/0.95/1.05；safety 0.70） |
| `stage21_shark_pack` | PASS（三只实体、同一 actor、趴低/下潜几何） |
| `stage31_arena` | PASS（8 种对象、看台、三只鲨鱼、介入已移除） |
| `stage19_bird_behavior` | PASS（飞过不判、DIVE 仍判） |
| `stage13_catch_matrix` | PASS |
| `stage34_first60` | PASS |
| `stage34_tutorial_relay` | PASS |
| `stage35_combo_audit` | PASS（含 `visual_stress_not_permanent`） |
| `stage4_collision_feedback` | PASS |
| `stage3_playtest` | PASS：260.8 s、55/55、5 accidents/圈；两圈一致，无卡死 |

正式 Z3 自动驾驶的鲨群日志：三拍都命中（自动代理不躲），说明三只实体按顺序
从水下上冲；不是“没打中”或“凭空攻击”。

## 5. 已知限制

- 自动驾驶仍不会躲鲨群三拍，正式跑会每拍吃一次；这是自动代理能力问题，不是不可躲证明。
- 没有真人复验“从水下上冲”的方向感；需要制作人看实际窗口。
- 鲨群三只实体仍是画在 `race.gd` 的灰盒图形，没有正式美术。
- 旧测试债（`stage4_snack_contact` / `stage7_food_readability` / 旧 `stage4_combo_windows`）不在本轮主链。
