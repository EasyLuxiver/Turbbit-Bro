# FEEL-35 核心玩法整合完善

- 模式：CONTROLLED_WRITE
- 未导出 EXE、未打包、未覆盖公开 Web；`best.json` 未修改（MD5 `067DEB9A71A19C2F6F9F6DC41FEABF09`）。
- 执行方式：先规划，再连续执行六个阶段，最后统一自检；没有中途 STOP。

## 1. 总体规划与执行顺序

1. FEEL-34 收尾：教学/正式 log1 几何统一、首 60 秒两条路径。
2. 现有障碍组合：7 组组合（2 个紧接力、4 个角色交替、1 个双解）+ 4 个补充 relay。
3. SHIFT 正向价值：复用现有 relay 分数/反馈，不做新分数体系。
4. 事故因果与可读性：碰撞/反馈回归，修过期测试。
5. SHARK6：只做回归，不改基线。
6. 全关卡节奏：55 组 audit、长跑、MCP 实跑。

## 2. 阶段一：FEEL-34 收尾

- 教学 `tut_log1` 高度从 200 统一为 **240**，与正式 `log1` 一致。
- 教学仍需真实 relay gate；`stage34_tutorial_relay`：
  - 只控制乌龟下潜：不产生 relay，教学停在 step2；
  - 兔子跳 → 真 SHIFT → 乌龟下潜：产生 `perfect` relay，step 2→3。
- 正式 `stage34_first60`：
  - log1 在 **24.0 s**；
  - 兔子只跳失败、乌龟只潜失败、BRO DIVE 成功；
  - wall1 仍 43.7 s；第一个真接力 24.0 s。
- 跳过教学路径仍使用原 lesson prompt；没有新增说明面板。

## 3. 阶段二：7 组组合障碍 + 4 个补充 relay

没有新增障碍类型，也没有改 55 组总数。组合通过“相邻组角色交替 + 2 组紧接力 + 1 组双解”实现。

| # | 组 | 类型 | 前一组 | 间隔 | 组合方式 | 类别 |
|---|---|---|---|---:|---|---|
| 1 | gate4 | 乌龟潜 | rock6 | 1054 px≈4.4 s | 兔子跳 → SHIFT 乌龟潜 | 角色交替 |
| 2 | bird4 | 兔子趴/乌龟潜 | gate4 | 1180 px≈4.9 s | 乌龟潜 → SHIFT 兔子趴 | 角色交替 |
| 3 | log5 | BRO DIVE | gate6 | 1065 px≈4.1 s | 乌龟潜 → SHIFT 兔子跳 + 乌龟潜 | 角色交替 |
| 4 | rock10 | 兔子跳 | log7 | **529 px≈2.0 s** | BRO DIVE 落壳 → 紧接兔子跳 | 连续接力 |
| 5 | bird8 | 兔子趴/乌龟潜 | shark9 | 1113 px≈4.3 s | 乌龟跃 → SHIFT 兔子趴 | 角色交替 |
| 6 | bird9 | 兔子趴/乌龟潜 | gate8 | **594 px≈2.3 s** | 乌龟潜 → SHIFT 兔子趴 | 连续接力 |
| 7 | beam4 | LOW_BEAM | 无 | — | 兔子趴（无氧耗）或乌龟潜（耗氧） | 双解 |

另外 4 个不改几何的 relay 入口：`rock2`（gate1 后）、`gate3`（rock4 后）、`gate5`（log4 后）、`gate6`（rock8 后）；它们把相邻的兔/龟答案串成必须换人的序列，但没有新增组合碰撞。

- 双解 beam4：`build_group` 支持 `no_anti_dive`，只移除这一组的反下潜矩形；其他 LOW_BEAM 不变。
- `stage35_combo_audit`：
  - 双角色参与 **19 组**（9 个基础 log/wall + 10 个 relay；其中 15 组在预期路线上需要换人，4 组是双解/选择）；
  - 7 组组合，间隔 400–1300 px；
  - beam4 双解：兔子趴通过且不耗氧，乌龟潜通过且耗氧。

**为什么是 19 而不是继续加：** 19 已在任务参考上限；再增加会滑向“每个障碍都按 SHIFT”的机械感。保留 4 组双解/选择来提供主动判断，而不是继续堆强制切换。

## 4. 阶段三：SHIFT 正向价值

- 没有新增分数体系，复用现有 relay：
  - `perfect` +100，`clever` +50；已有 `feedback.relay_perfect/clever`。
- 通过 7 组组合 + 4 个 relay 让玩家提前看到“下一段属于谁”：
  - 紧接力组（rock10、bird9）要求落壳后马上换人；
  - 角色交替组让玩家在 4–5 秒内决定先处理哪一段；
  - beam4 让“兔子趴”与“乌龟潜”成为不同代价的选择。
- 未增加随机惩罚逼迫 SHIFT；MISCHIEF 基线保持。

## 5. 阶段四：事故因果与可读性

- `stage4_collision_feedback` 修复为当前设计：
  - landing 从旧岩石坐标改到空档；
  - turtle_wave 的旧 `bro_meter==1` 改为 `last_mistake_role=="turtle"`；
  - dive_fx 从旧固定坐标改为实际 log1 位置 + 真 BRO DIVE。
- 结果：PASS（5/5 案例）。
- 未发现“视觉躲开但判定命中”的新案例；现有预警/判定仍共用同一份 rect。
- MISCHIEF 保持：32%、700 px、2.6 s、冷却、SHIFT 中断、救援优先、教学关闭。

## 6. 阶段五：SHARK6

- 未改 T→R→T、预警 0.95/0.95/1.05、安全 0.70/0.70、单攻击体、看台、介入。
- `stage32_shark_timing`：10/10 轮 + Z3 时间轴 PASS。
- `stage21_shark_pack`：10/10。
- `stage31_arena`：25/25（窗口+鼠标）。

## 7. 阶段六：全关卡节奏

`stage4_level_audit`：

| 区域 | 组数 | 时长 | 威胁占比 | 最大空档 |
|---|---:|---:|---:|---:|
| Z1 | 12 | 68.2 s | 44.0% | 5.87 s |
| Z2 | 19 | 100.0 s | 43.2% | 5.62 s |
| Z3 | 24 | 105.4 s | 49.2% | 5.94 s |

- 55 组，`no_solution_groups=0`，无新增无解组合。
- 最长空档从移动组合时的 10.75 s 收回到 **5.94 s**。
- 总数/障碍种类不变：LOW_BIRD 9、SURFACE_ROCK 12、DIVE_GATE 8、FLOATING_LOG 8、SHARK 6、LOW_BEAM 9、HIGH_WALL 3。
- 长跑：`stage3` 两圈 **55/55**，270.7 / 270.6 s，每圈 1 次事故，max_stuck 0.0。

## 8. 验证汇总

| 测试 | 结果 |
|---|---|
| `stage34_first60` | PASS：24.0 s 真接力，单角色失败，BRO DIVE 通过 |
| `stage34_tutorial_relay` | PASS：教学真实 relay，step2→3 |
| `stage34_mischief_distance` | PASS：699/700 阻止、701 放行，31.9% |
| `stage35_combo_audit` | PASS：coop=19、combos=7、双解通过 |
| `stage3_playtest` | PASS：两圈 55/55，270.7 / 270.6 s |
| `stage4_level_audit` | PASS：no_solution=0，max_gap<6 s |
| `stage32_shark_timing` | PASS：10/10 + Z3 |
| `stage31_arena` | 25/25 |
| `stage21_shark_pack` | 10/10 |
| `stage4_collision_feedback` | PASS |
| `stage22` / `stage15` / `stage19` / HUD | exit 0 / 28/28 |
| `stage13_tutorial_flow`（窗口） | PASS |

## 9. Godot MCP 实际记录

- `bridge_connected=true`，addon 2026.10.20.1。
- 实跑菜单 → 漫画 → 教学 → K → 比赛；测试场鼠标生成 SURFACE_ROCK、滑条切 SHARK6 并生成。
- 截图：`docs/reports/longrun/feel33/01-menu.png` … `07-race-play.png`。
- 场景树读到 Tutorial/Race/Turtle/Rabbit/MountController/HUD；游戏输出无 error/warning；FPS 151–165。
- 限制：MCP 只覆盖编辑器 play，不覆盖 Web；`read_property` 多次 `read_pending` 超时；没有真人 55 组试玩。

## 10. 未解决 / 没做的

1. 5 个角色交替组合的间隔仍是 4–5 s，不是全部“紧接力”；真正紧接力的只有 rock10、bird9 两组。
2. 双解只有 beam4 一组；其他障碍仍以单答案为主。
3. 没有新增环境交互/远程攻击重做——超出本轮授权。
4. 没有音效/美术；失败因果仍主要靠文字和气泡。
5. 没有真人完整试玩；MCP/自动化不能替代。
6. CloudBase 公开链接未更新；项目仍带 MCP 插件/运行时探针。

## 11. 自评与两个问题

**核心机制成熟度：6.5/10。**  
比上一轮好：开局 24 s 有真接力，教学强制 relay，双解/交替组合让 SHIFT 有了决策空间。  
但还不够：双角色参与组只有 19/55（其中 15 组需要换人），5 个组合窗口偏松，双解只有 1 组，失败可读性和音画仍是短板。

**新玩家能否理解并享受同时管理龟兔？**  
**能理解，但还不能持续享受。** 前 60 秒能让他明白“要换人”；中段大部分仍是单角色执行，只有约 15/55 会真正逼他换人，19/55 把两位角色放进决策。他可能会懂，但不一定一直觉得必须管。

**现有机制是否充分利用？**  
没有。SHIFT 仍主要是“正确答案的钥匙”；双解、连招换人、角色交替只覆盖一小段；海鸟/环境/音效未参与。  
不添加新系统的情况下，真正影响体验的是：**组合窗口还不够紧、双解还不够多、失败原因还不够可见。**

## 12. 停止

- 未新增按键、技能、障碍类型、敌人类型或环境系统。
- 未改 SHARK6、测试场、评分/救援/氧气规则。
- 未导出、未打包、未覆盖公开 Web。
- 等待 Producer 验收。
