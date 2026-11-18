# 走神度 + Q 弹碰撞 · 实施报告

- 日期：2026-11-18
- 范围：轻压力“走神度”、漏电软强制切换、Q 弹碰撞、HUD 小条、旧 MISCHIEF 退场。
- 未导出、未部署；`best.json` 保持
  `067DEB9A71A19C2F6F9F6DC41FEABF09`。

## 1. 走神度（替换旧 MISCHIEF）

### 规则

- 兔子/乌龟各自独立走神度，0–100；
- 未控制的身体增长；被控制的身体缓慢恢复；
- 切换只停止增长，**不瞬间清零**；再次切走从当前值继续；
- 满值前不影响速度、碰撞、氧气、位置、输入；
- 满值：0.65 s 预兆；切回漏电身体 = 接地/取消；
- 不取消：漏电打到当前控制的身体，0.2–0.3 s 硬直，意识被电回漏电身体
  （软强制切换）；硬直结束可立刻切回；
- 不记事故、不扣氧、不改碰撞；只有短输入中断；
- 3 s 冷却，不连续触发；附近 160 px 有障碍时不启动，避免贴脸偷袭。

### 当前参数

| 参数 | 值 | 位置 |
|---|---:|---|
| 满值时间（中压力） | ~16 s | `SLEEP_GROW` |
| 恢复 | ~40 s 从满到 0 | `SLEEP_RECOVER` |
| 阶段阈值 | 40 / 70 | `SLEEP_DOZE` / `SLEEP_PRE` |
| 预兆 | 0.65 s | `SLEEP_TELEGRAPH` |
| 硬直 | 0.25 s | `_apply_sleep_event` |
| 冷却 | 3 s | `SLEEP_COOLDOWN` |

轻/强档只需改 `SLEEP_GROW`：轻 18–22 s、强 10–13 s。

### 动作池（每角色两个）

| 角色 | 走神/耍宝前 | 满值漏电 |
|---|---|---|
| 兔子 | 打哈欠（Zzz） | 电乌龟：乌龟硬直 0.25 s，控制跳到兔子 |
| 乌龟 | 发呆（Zzz） | 电兔子：兔子硬直 0.25 s，控制跳到乌龟 |

- 满值动作是**蛋糕残留电荷的漏电**，不是恶意攻击；
- 不做“偷吃海藻回氧/加分”的正收益；
- 旧 MISCHIEF 的抱怨、拽绳、电击调用链已停用；`stage15_mischief` 退役。
  旧函数保留为回滚备份，不再被主循环调用。

### HUD / 表现

- 每个角色行右侧一条 42×4 的小条；不显示数字，不做 0/3 面板；
- 走神阶段青、耍宝前琥珀、满值红；
- 角色头顶 Zzz；预兆冒火花；命中时电弧；
- 底部文字：“兔子/乌龟开始走神……”“兔子/乌龟漏电！……被电了一下”。

## 2. Q 弹碰撞

- 撞击后不再瞬移：位置用 ease-out-back 弹簧，0.42 s 退到目标；
- 壳做 squash/stretch：18% 阻尼摆动（约 3 次）；
- `BOING!` 字 + 冲击弧 + 镜头抖；
- 碰撞判定不变；动画期间暂停再判，避免同一帧重复吃；
- 同组后续仍只弹回不重复扣分；连续 6 次 `BONK_OUT`；
- 当前后退 **140 px**（`BONK_BACK`），可调到 120/180；
  视觉时长 `BONK_ANIM_TIME=0.42`、`BONK_VISUAL_TIME=0.55`；
- 制作人可按 0.7（轻）或 1.3（夸张）整体缩放。

## 3. 验证

| 测试 | 结果 |
|---|---|
| `stage3_playtest` | **PASS**：238.3 / 238.2 s，53/53，3 accidents，max_stuck=0，grade B |
| `stage3_selftest` | PASS |
| `stage53_soft_pressure` | PASS（10 项：增长/恢复/不干扰/预兆取消/强制切换/无事故/可切回） |
| `stage45_bounce_recovery` | PASS（含 spring 启动、无瞬移、6 次 BONK_OUT） |
| `stage35_combo_audit` | PASS |
| `stage34_first60` / `stage34_tutorial_relay` | PASS / PASS |
| `stage13_catch_matrix` | PASS |
| `stage42_shark_fairness` | PASS |
| `stage31_arena` | PASS（窗口模式） |
| `stage10_joint_semantics` | PASS |
| `stage19_bird_behavior` | PASS |
| `stage21_shark_pack` | PASS（no_stands） |
| `stage32_shark_timing` | PASS |
| `stage46_showtime_small` | PASS |
| `stage48/49/50` | PASS |
| `stage15_fail_flow` | exit 0 |

截图：

- `screenshots/sleep_telegraph.png`：乌龟走神预兆 + HUD 红条
- `screenshots/sleep_zap.png`：乌龟漏电，控制跳到乌龟
- `screenshots/qbounce_00.png` / `10` / `22` / `40.png`：Q 弹四帧

## 4. 尚未验证 / 需要制作人调

- **没有真人试玩**；走神频率、漏电是否烦、Q 弹幅度需要你实际看；
- 走神阶段目前只有 Zzz/火花/电弧的代码表现，正式美术动作还没接；
- Q 弹截图是在灰盒礁拱前拍的，正式障碍视觉下需要再看；
- 旧 MISCHIEF 函数仍留在文件里（已不调用），提交后可做一次删除清理；
- 未导出、未打包、未部署。

## 5. 可调位置

- `scripts/race.gd` 顶部 `SLEEP_*`：走神增长/恢复/阶段/预兆；
- `scripts/race.gd` 顶部 `BONK_*`：后退距离、动画时长、视觉时长；
- `scripts/ui/hud.gd` `_sleep_bar`：条宽/位置；
- `scripts/autoload/locale.gd` `sleep.*`：文案。
