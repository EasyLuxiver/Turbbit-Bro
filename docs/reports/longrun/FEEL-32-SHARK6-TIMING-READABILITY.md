# FEEL-32 SHARK6 攻击节奏与可读性

- 基线：FEEL-31
- 模式：CONTROLLED_WRITE
- 未导出 EXE、未打包、未覆盖 CloudBase/GitHub 公开 Web；`best.json` 未修改（MD5 `067DEB9A71A19C2F6F9F6DC41FEABF09`）。
- 当前 CloudBase 国内链接仍是 FEEL-31 构建，未覆盖；本轮结果等 Producer 授权后再发布。

## 1. 攻击顺序

固定顺序已改为 **Turtle → Rabbit → Turtle**：

| 段 | 发动者 | 目标 | 应对 |
|---|---|---|---|
| 1 | 老大（最前） | 乌龟 | 乌龟跃起 |
| 2 | 胖小弟（最后） | 兔子 | 兔子趴低 |
| 3 | 瘦小弟（中间） | 乌龟 | 乌龟下潜 |

实现：`LEAD_LUNGE → SAFE1 → GAP1 → FAT_LUNGE → GAP2 → THIN_LUNGE → RETREAT`。
不是只改日志：实际调度顺序、攻击体生成顺序和阶段名都已调整。

## 2. 时间轴（实测，60 Hz，单位 s）

| 事件 | 实测 |
|---|---:|
| 老大预警开始 → 老大攻击开始 | 0.95 |
| 老大碰撞结束（退回 DOWN）→ 胖鲨预警开始 | 0.70 |
| 胖鲨预警开始 → 胖鲨攻击开始 | 0.95 |
| 胖鲨碰撞结束 → 瘦鲨预警开始 | 0.70 |
| 瘦鲨预警开始 → 瘦鲨攻击开始 | 1.05 |
| 任意时刻攻击体数量上限 | 1 |

- 老大攻击 1.40 s + 退回 0.55 s；胖/瘦攻击体各 0.60 s。
- 预警时间没有用“上一段结束到下一段开始”的间隔冒充；上表分别记录 warn / attack / end 时间戳。
- 测试数据：`docs/reports/longrun/feel32-shark-timing.json`
- 验证：测试场连续 **10/10 轮**通过；正式 Z3 `shark6` 同一时间轴通过。

## 3. 瘦鲨可读性

瘦鲨原来是贴水面横扫，下潜和跃起都能躲，玩家容易猜答案。现在改成 **压顶纵向攻击**：

- 判定框 `Rect2(x-45, 130, 90, 236)`：覆盖跃起路径、巡航壳和站立兔高度；
- 只有乌龟 **下潜** 能稳定让开；
- 跃起会撞进纵向危险区，巡航高度也会被压到；
- 预警 `!` 标在乌龟上方，文案改为「瘦鲨压顶——SHIFT 乌龟 下潜！」；
- 纵向危险区用半透明水墙 + 斜线画出，画和判使用同一份 rect。

`stage21_shark_pack` 验证：`dive=true cruise=true leap=true`（下潜安全，巡航/跃起命中）。

## 4. 修改文件

- `scripts/race.gd`
  - `_tick_shark_pack`：T→R→T 调度、SAFE1/SAFE2 安全间隔、warn/attack/end 日志。
  - `_update_ambush_sharks`：shark6 老大的预警从 0.55 s 提到 0.95 s（普通 SHARK 不变），并记录 leader 的 warn/attack/end。
  - `_spawn_shark_follower`：瘦鲨压顶判定框。
  - `_check_shark_attacks`：攻击结束写 end 时间戳。
- `scripts/autoload/locale.gd`：瘦鲨文案改为下潜。
- `scripts/test/stage21_shark_pack.gd`：新顺序、胖/瘦分工、瘦鲨“仅下潜安全”。
- `scripts/test/stage31_arena.gd`：窗口测试适配新顺序，捕获胖/瘦攻击。
- `scripts/test/stage32_shark_timing.gd` + `scenes/stage32_shark_timing.tscn`：10 轮 + Z3 时间轴验证。

## 5. 验证结果

| 项目 | 结果 |
|---|---|
| `stage32_shark_timing` | 测试场 10/10 轮；Z3 时间轴通过；order=`leader,fat,thin`；warn=`0.95/0.95/1.05`；safety=`0.70/0.70`；max_attacks=1 |
| `stage21_shark_pack` | 10/10：顺序、胖鲨趴低、瘦鲨仅下潜安全、救援清理、看台、Z3 组、Z3 介入 |
| `stage31_arena` | 25/25（窗口运行，含鼠标点击）：测试场功能、SHARK6 三只攻击、菜单入口、重启、返回、best 不变 |
| `stage3_playtest` | PASS：两圈 55/55，270.7 / 270.6 s，每圈 1 次事故，max_stuck 0.0 |
| `stage22` / `stage15` / `stage19` / `stage4_hud_score` | 全部 exit 0；HUD 28/28 |

窗口截图：`docs/reports/longrun/feel31/arena-shark6-fat.png`、`arena-shark6-thin.png`、`arena-shark6.png`。
自动化、窗口和真人试玩分开：本轮没有真人完整试玩。

## 6. 未解决

1. 瘦鲨的纵向危险区目前是半透明水墙占位，不是最终美术。
2. 老大仍然是原有 `_ambush` 攻击，只是 shark6 的预警延长；普通 SHARK 未改。
3. 时间轴是在测试场和自动驾驶 Z3 跑通，没有真人连续躲避 10 轮的体验数据。
4. CloudBase 公开链接尚未更新到 FEEL-32；等 Producer 授权后再发布。

## 7. 停止

- 未导出、未打包、未覆盖公开 Web/EXE。
- 未修改普通 SHARK、其他障碍、得分、事故、救援、氧气、最高分规则。
- 等待 Producer 质检。
