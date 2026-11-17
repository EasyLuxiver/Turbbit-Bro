# FEEL-42 · Shark Fairness & Gameplay Validation

- 基线：FEEL-41（自评 8.4/10）
- 模式：AUTONOMOUS CONTROLLED ITERATION
- 未导出、未打包、未覆盖 Web/EXE；`best.json` MD5
  `067DEB9A71A19C2F6F9F6DC41FEABF09` 未变。

## 1. 本轮结论

FEEL-41 已让鲨群三拍真实发生，但自动驾驶不会做躲避，正式跑 4 accidents/lap
无法说明“攻击是否公平”。

本轮建立了**真实按键/真实 race.tscn 的鲨群测试**，结论分三层：

1. **正确操作可以躲开三拍**：即时/0.2/0.35 s 的 fat/thin 输入都通过；
   leader 的**正确起跳点**是预警后约 0.35 s，过早跳会中招。
2. **错误角色/过晚动作会中招**：leader 不跳、fat 不趴、thin 不潜、fat 晚 1.1 s、
   thin 晚 1.2 s 分别命中。
3. **当前 4 accidents/lap 不是不可躲**：其中 1 次是 Z1 自动驾驶旧事故，
   3 次是鲨群/介入；自动驾驶不会读提示，也不会按阶段换人。

因此没有削弱鲨群，也没有把“自动驾驶被命中”当成不公平证据。

## 2. 真实输入测试方法

新增 `scenes/stage42_shark_fairness.tscn`：

- 复用 `test_arena.tscn` 的 `race.tscn`；
- 通过 `spawn_test_group("SHARK6")` 生成正式鲨群；
- 所有躲避都通过真实 `Input.action_press/release` 和 SHIFT 的
  `InputEventKey` 进入游戏；没有直接改 `_shark_pack` 阶段或 `current_control`
  来伪造结果；
- 只对测试开始前的局面做 reset，并读取 `_shark_pack_log` / `accident_event_log`
  作为事实记录。

`stage42` 结果：**10/10 PASS**。

## 3. 三拍成功率

### 正确操作

| 试验 | leader | fat | thin | 结果 |
|---|---|---|---|---|
| correct delay 0.00 | 预警后 0.35 s 起跳 | 即时 | 即时 | 无命中 |
| correct delay 0.20 | 预警后 0.35 s 起跳 | +0.20 s | +0.20 s | 无命中 |
| correct delay 0.35 | 预警后 0.35 s 起跳 | +0.35 s | +0.35 s | 无命中 |

- **正确躲避成功率：3/3。**
- Fat/thin 三档输入均通过，说明 0.95/1.05 s 预警对这两拍是够用的。
- Leader 的“立即起跳”和“+0.20 s 起跳”都会中招：
  - 这两个试验记录了 `leader_leaped=true`，但 leader 命中；
  - 说明**看到了预警就立刻跳**会跳得太早，正确点是约 0.35 s 后。
- 已把 leader 文案改成“等它冲上来再跃起”，不再暗示预警瞬间起跳。

### 错误角色 / 过晚动作

| 试验 | 操作 | 结果 |
|---|---|---|
| wrong leader | 不跳 | leader hit |
| wrong fat | 不换兔子/不趴 | fat hit |
| wrong thin | 不换乌龟/不潜 | thin hit |
| late fat | 预警后 1.10 s 才趴 | fat hit |
| late thin | 预警后 1.20 s 才潜 | thin hit |

- **错误操作 5/5 都产生对应命中**，不是“怎么都打不到”。
- 三拍结束后 `phase=DONE`，无残留攻击；下一轮 reset 不继承状态。

## 4. 空间关系

- `fat` 生成：`turtle.position.x + 95 px`，矩形 `Rect2(x-58, 246, 116, 92)`。
- `thin` 生成：`turtle.position.x + 75 px`，矩形 `Rect2(x-45, 130, 90, 236)`。
- 两者都按**当前乌龟位置**生成，不再刷在 shark6 的旧位置；
  `leader` 仍是 shark6 的本体伏击。
- 测试中 fat/thin 的 `attack` 事件和 `hit` 事件来自同一攻击体，
  预警后 0.95/1.05 s 生成，命中区域与绘制矩形一致。
- 正确操作下 `leader_overlap` 在早期/晚期跳的差异可见；没有“玩家背后
  出现攻击”的情况；生成点在玩家前方 75–95 px。
- `leader` 的预警窗口实际上比一次跃起更早；**立即跳会太早**，这是本轮
  发现的可读性问题，已用文案修复提示，但没有削弱攻击。

## 5. 4 accidents/lap 拆分

正式 `stage3` 两圈均为 **4 accidents/lap**：

| 来源 | 次数/圈 | 说明 |
|---|---:|---|
| Z1 普通障碍/自动驾驶 | 1 | `RABBIT_STUN` x≈13600，旧有事故 |
| leader 命中 | 0 | 自动驾驶在正确点跃起 |
| fat 命中 | 1 | x≈40172，自动驾驶没换兔子/趴低 |
| thin 命中 | 1 | x≈40613，自动驾驶没换乌龟/下潜 |
| 介入 fat 命中 | 1 | x≈42946，自动驾驶没趴低 |
| 落水/O₂/救援/其他 | 0 | 本轮未新增 |

`hazard_contacts=0` 只统计**普通障碍命中**；鲨群命中在 `_shark_attacks`
与 `accident_event_log`，所以不能拿 `hazard_contacts=0` 说“没有受到攻击”。
两圈仍 **55/55、无卡死**，但事故数如实保留。

## 6. 鲨群回归

- leader → fat → thin 顺序保持。
- 预警 0.95 / 0.95 / 1.05 s、安全间隔 0.70 s 保持。
- 真实 `stage3` 两圈日志都包含：
  `leader / fat / thin` 三拍。
- `RABBIT_STUN` 不再重置鲨群；真正救援/落水/礁壳/O₂ 仍会打断。
- `stage32` 10/10 + Z3 时间轴 PASS。
- `stage21` 老大/胖/瘦、救援清空、看台、介入全部通过。
- `stage31` PASS。
- 重启后 `_shark_pack` 重新初始化，未继承上一轮。

## 7. Z1/Z2 决策关系

没有新增障碍或连招；用现有关系和真实自动驾驶路径验证：

- prompted 第一圈：55/55。
- `test_no_lessons=true` 的第二圈：55/55。
- Z1：`gate1→rock2` 4.53 s、`bird2` 双解、`rock3` 潮汐双解。
- Z2：`shark3→beam3`、`rock4→gate3`、`gate3→bird3`、`rock6→gate4` 2.93 s、
  `shark5→bird5`。
- `stage35` 的 live prompt 证明提示确实出现；第二圈关闭教学后仍 55/55，
  说明自动驾驶不依赖文字提示也能按障碍类型/前后关系完成。
- **限制**：这是自动驾驶，不知道“提示被关掉”的主观体验；不能替代真人。
  真人是否在无提示下主动选择仍待 Producer。

## 8. 双解与潮汐岩

- 5 组：`bird2`、`beam4`、`beam5`、`rock3`、`rock6`。
- 两种答案在 `stage35` 均通过。
- `rock3` 8 相位：
  - 兔子：**7/8** 通过，1 个相位失败 → 确实是浪谷时机，而不是永远安全；
  - 乌龟：**8/8** 通过 → 稳定、耗氧。
- 抽取后结构保护仍保留 5 个 dual；随机种类不破坏 combo/relay/dual。

## 9. 动态障碍反馈

- `stage15_dynamic_buoy` PASS：浮标/吊箱撞乌龟均 `dunk_timer=1.80`。
- 原有 hitstop、震动、减速、文字保留。
- 没有升级为事故、没有写 `hit_roles`、没有扣格；静态岩不误伤。
- 未发现乌龟 dunk 被其他动作立即覆盖。

## 10. 完整回归

| 测试 | 结果 |
|---|---|
| `stage42_shark_fairness` | PASS 10/10 |
| `stage3_playtest` | PASS 260.9 / 260.9 s，55/55，无普通障碍 contact，4 accidents/lap |
| `stage3` 三拍断言 | PASS 两圈 leader/fat/thin |
| `stage32_shark_timing` | PASS |
| `stage21_shark_pack` / `stage31_arena` | exit 0 / PASS |
| `stage15_dynamic_buoy` | PASS |
| `stage35_combo_audit` | PASS：coop21、must14、cont15、dual5、tight5、rock3 7/8 + 8/8 |
| `stage4_level_audit` | PASS：55 组，no_solution=0 |
| `stage4_collision_feedback` / `stage34` / `stage36` | PASS |
| 真实窗口 `stage3 --capture` | PASS |

## 11. MCP

- bridge_connected=true，Godot 4.7-stable，端口 9081。
- 实际流程：菜单 → 连环画（ESC）→ 教学 → K → 比赛；当前构建 0/55 起步。
- probe 在重复 play/stop 后出现过 `max client limits reached`；停止游戏再 play
  恢复。MCP 不覆盖 Web，未重新部署。

## 12. 七维评分

| 维度 | 分数 | 依据 |
|---|---:|---|
| 鲨群可躲性 | 8.5 | 正确 3/3；错误/过晚 5/5 命中；leader 早期跳需文案引导 |
| 空间/预警公平 | 8.0 | fat +95、thin +75；无背后攻击；leader 立即跳太早是遗留 |
| 事故归因 | 8.5 | 4 accidents/lap 已按来源拆分，不再用 hazard_contacts 代替 |
| Z1/Z2 决策 | 8.5 | 15 连续关系；prompted/no-lessons 两圈 55/55 |
| 双解质量 | 8.5 | 5 组；rock3 兔子 7/8、乌龟 8/8 |
| 动态反馈 | 8.5 | dunk 可见；无事故升级 |
| 稳定性/完整度 | 8.0 | 55/55、无卡死；鲨群命中与自动事故仍需真人 |

**综合：8.4/10。**

与 FEEL-41 基本持平/略稳：这轮不是加内容，而是把“鲨群是否公平”从
自动驾驶事故推断，变成真实输入证据。9/10 仍不成立，因为：

- leader 的“预警即跳”会太早，需要玩家理解等待点；
- 4 accidents/lap 中 3 次是 AI 不躲，不是不可躲，但真人未试玩；
- Z1 仍没有强制紧切换；
- 所有反馈仍是文字/姿态级；
- 无美术/音频。

## 13. 仍需 Producer / 真人验证

1. 真人看到“老大来了”后，能否自然等到鲨鱼冲上来再跃起。
2. fat +95 px、thin +75 px 的视觉位置是否足够远，玩家是否能读出击退方向。
3. 4 accidents/lap 在真人手里是否下降；不能以自动驾驶 55/55 代替。
4. Z1/Z2 的 4.17–4.39 s 软连招是否真的促使玩家提前换人。
5. 无提示第二圈是否仍能靠障碍类型/动作关系完成；本轮只有自动驾驶证据。
6. rock3 的 1/8 失败相位是否被读成“时机不对”，而不是随机判定。

## 14. 边界

- 未改 Z3 五组紧接力间隔、SHARK6 T→R→T、MISCHIEF 32%/2.6 s/700 px、
  救援/氧气/事故/评分核心规则。
- 未新增敌人、障碍、按键、技能或环境系统。
- 未导出、未打包、未覆盖公开 Web/EXE。
- `best.json` 未修改。
- 已停在这里，等待 Producer QA。
