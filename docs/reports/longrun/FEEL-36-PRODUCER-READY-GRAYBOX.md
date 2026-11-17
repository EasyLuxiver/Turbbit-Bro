# FEEL-36 · Producer-Ready Graybox 完整体验

- 基线：FEEL-35
- 模式：AUTONOMOUS CONTROLLED ITERATION
- 未导出 EXE、未打包、未覆盖公开 Web；`best.json` 未修改（MD5 `067DEB9A71A19C2F6F9F6DC41FEABF09`）。

## 1. 本轮做了什么

1. **第二组双解障碍**：`beam5` 也支持“兔子趴低（不耗氧）/ 乌龟下潜（耗氧）”，与 `beam4` 形成两个明确选择点。
2. **双解提示**：首次遇到双解低梁时，lesson prompt 改为“低梁：兔子趴低，或 SHIFT 乌龟下潜（耗氧）”；不是新 UI，只复用现有 prompt 通道。
3. **跳过教学的首次 BRO DIVE 提示**：在 log1 前 760–200 px、当前控制兔子时，给一次 “BRO DIVE：先跳，再 SHIFT 到乌龟按住 ↓”；教学里仍由 `test_no_lessons` 关闭。
4. **事故反馈测试对齐当前设计**：landing 改到空档、旧 meter 断言改为 `last_mistake_role`、dive 测试改用真实 log1 + BRO DIVE。
5. **关卡组合保持 FEEL-35 的 19 组双角色参与、8 组组合**；没有新增障碍/敌人/按键。

## 2. 当前双角色体验

- 教学：`tut_log1` 高度与正式 log1 统一为 240；必须真实 relay 才能 step2→3。
- 正式：log1 **24.0 s**；兔子只跳失败、乌龟只潜失败、BRO DIVE 成功。
- 组合：
  - 紧接力 2 组：`rock10`（2.0 s）、`bird9`（2.3 s）；
  - 角色交替 4 组：`gate4`、`bird4`、`log5`、`bird8`；
  - 双解 2 组：`beam4`、`beam5`；
  - 补充 relay 4 个：`rock2`、`gate3`、`gate5`、`gate6`。
- 双角色参与 **19/55**；其中约 **15/55** 在预期路线上需要换人，4 组是双解/选择。

## 3. 关卡与节奏

| 区域 | 组数 | 时长 | 威胁占比 | 最大空档 |
|---|---:|---:|---:|---:|
| Z1 | 12 | 68.2 s | 44.0% | 5.87 s |
| Z2 | 19 | 100.0 s | 43.2% | 5.62 s |
| Z3 | 24 | 105.4 s | 49.2% | 5.94 s |

- 55 组，`no_solution_groups=0`。
- 两圈 **55/55**，270.7 / 270.6 s，每圈 1 次事故，max_stuck 0.0。
- 仍然保留 5 组 4–5 s 的“角色交替”组合，而不是全部压成 2 s 连招；这是为了保留观察和规划空间，避免每段都变成背时序。

## 4. SHIFT 与反馈

- 未新增分数体系；沿用 `relay_perfect +100`、`relay_clever +50` 和现有反馈。
- 双解低梁现在有明确文案，玩家知道乌龟下潜是合法选择，而不是猜。
- 跳过教学后，第一根浮木前有一次动作提示；不是新的教学面板。
- 未用随机 MISCHIEF 强迫 SHIFT；MISCHIEF 保持 32%、2.6 s、700 px、冷却、SHIFT 中断、救援优先、教学关闭。

## 5. SHARK6

- 未改 T→R→T、0.95/0.95/1.05 预警、0.70/0.70 安全间隔、单攻击体、看台、介入。
- `stage32` 10/10 + Z3 时间轴；`stage21` 10/10；`stage31` 25/25。
- 鲨鱼在 Z3 的编排没有因组合调整而冲突。

## 6. 事故与可读性

- `stage4_collision_feedback` PASS：兔撞岩、龟撞拱、落壳水花、BRO DIVE、BRO OLLIE 五段。
- 现有事故原因仍由 `feedback/hint` 给出；没有新增统计面板。
- 未发现新的“视觉躲开但判定命中”；MISCHIEF 没有误触发或与正式障碍冲突。

## 7. 测试

| 测试 | 结果 |
|---|---|
| `stage3_playtest` | 两圈 55/55，270.7 / 270.6 s，1 accident/lap |
| `stage35_combo_audit` | PASS：coop=19、combos=8、dual=2、双解提示、两种答案公平 |
| `stage34_first60` | PASS：24.0 s 真接力，单角色失败，BRO DIVE 通过 |
| `stage34_tutorial_relay` | PASS：教学真实 relay，step2→3 |
| `stage34_mischief_distance` | PASS：699/700 阻止、701 放行、31.9% |
| `stage36_hint` | PASS：跳过教学后首次 BRO DIVE 提示只出现一次 |
| `stage4_collision_feedback` | PASS |
| `stage4_level_audit` | PASS：no_solution=0，最大空档 <6 s |
| `stage32` / `stage31` / `stage21` | PASS / 25/25 / PASS |
| `stage22` / `stage15` / `stage19` / HUD | exit 0 / 28/28 |
| `stage13_tutorial_flow`（窗口） | PASS |

## 8. Godot MCP 实测

- bridge_connected=true，addon 2026.10.20.1。
- 实跑菜单 → 漫画 → 教学 → K → 比赛；测试场鼠标生成 SURFACE_ROCK、滑条切 SHARK6 并生成。
- 读运行场景树（Tutorial/Race/Turtle/Rabbit/MountController/HUD）、游戏输出、FPS 151–165。
- MCP 截图：`docs/reports/longrun/feel33/01-menu.png` … `07-race-play.png`。
- 边界：MCP 只覆盖编辑器 play，不覆盖 Web；`read_property` 多次超时；没有真人完整试玩。

## 9. 仍是问题 / 需要真人

1. 5/8 组组合仍是 4–5 s 的观察窗口，只有 2 组是真正的紧接力；这是有意的节奏保留，但需要真人判断是否够“连续”。
2. 双解只有 2 组低梁；其余多数障碍仍单答案。
3. 海鸟、环境交互、音效、美术未动——超出本轮范围。
4. 失败原因仍主要靠文字/气泡，不是音画级反馈。
5. 没有真人 55 组完整体验；MCP/自动驾驶不能替代。
6. CloudBase/Web 链接未更新；MCP 插件/运行时探针仍在项目里。

## 10. 自评与交付判断

**完整体验自评：7/10。**

- 比 FEEL-35 更清楚：教学/正式 log1 统一、24 s 首接力、跳过教学也有提示、双解有两组且文案明确。
- 但还不是“只差美术”：5 组组合偏松、双解仍少、失败/音画反馈不足。

**是否值得交给制作人质检：是，作为灰盒首次完整 QA。**  
理由：从新玩家视角，前 60 秒能形成“要换人”的认知；中段有 19/55 双角色参与、8 组组合和 2 个双解选择；55 组可解、无死锁、无长空档。  
但我不认为它已经是最终体验，尤其不是“好玩到可以发布”的版本。

**新玩家能否理解并享受同时管理龟兔？**  
能理解，前半能享受；中段仍有部分单角色执行，只有约 15/55 会真正逼他换人，19/55 把两位角色放进决策。他大概率会懂，但不一定一直觉得必须管。

**现有机制是否充分利用？**  
没有：SHIFT 仍主要是正确答案的钥匙；双解只有 2 组；海鸟/环境/音效未参与。  
不添加新系统的前提下，真正影响体验的是：组合窗口、双解数量、失败因果和音画反馈。

## 11. 停止

- 未新增敌人/障碍/按键/环境系统。
- 未改 MISCHIEF 基线、SHARK6 顺序、评分/救援/氧气规则。
- 未导出、未打包、未覆盖公开 Web/EXE。
- 等待 Producer 首次完整 QA。
