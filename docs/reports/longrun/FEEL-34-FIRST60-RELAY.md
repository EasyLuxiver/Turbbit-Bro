# FEEL-34 前 60 秒双角色体验强化

- 基线：FEEL-33
- 模式：CONTROLLED_WRITE
- 未导出 EXE、未打包、未覆盖 CloudBase/GitHub 公开 Web；`best.json` 未修改（MD5 `067DEB9A71A19C2F6F9F6DC41FEABF09`）。

## 1. 修改前的前 60 秒

用真实 race 场景 + 物理/输入探针（`stage34_first60`）审计：

| 时间 | 障碍 | 性质 |
|---:|---|---|
| 9.0 s | rock1 | 兔子跳 |
| 13.0 s | gate1 | 乌龟潜 |
| 18.3 s | rock2 | 兔子跳 |
| **24.0 s** | **log1** | 名义上是 BRO DIVE，但**乌龟单潜可绕过** |
| 28.4 s | shark1 | 乌龟跃 |
| 33.0 s | rock3 | 兔子跳 |
| 37.9 s | beam2 | 兔子趴 |
| **43.7 s** | **wall1** | 第一次真正双人（BRO OLLIE） |

- 修改前 log1 的判定底边太浅：只控制乌龟下潜，兔子身体从浮木下方通过，**不需要兔子跳**。
- 因此第一条真正“必须两个人”的障碍是 43.7 s 的 wall1，晚于目标 20–35 s。
- 教学路径：教学第一根浮木在 5000 px（约 22.7 s），step3 gate 依赖 `_relay_seen`；但障碍本身仍可被单龟绕过，只有 gate 在阻止跳过。

## 2. 修改后

### 2.1 第一根浮木改成真正的 BRO DIVE

`scripts/systems/level_data.gd`：

- `build_group()` 支持每组可选 `h`，不再所有浮木共用模板高度。
- `log1` 设 `h: 240`（原模板 200），底边加深；乌龟单潜时兔子身体会撞到底部。
- 障碍类型、位置、宽度、后续组顺序都没变；没有新增障碍。

结果（`stage34_first60`）：

- 兔子只跳：**失败**
- 乌龟只潜：**失败**
- 兔子跳 + SHIFT + 乌龟潜：**通过**，无事故
- log1 仍在 **24.0 s**，wall1 仍 43.7 s；第一次真接力从 43.7 s 提前到 **24.0 s**。

### 2.2 完整教学路径

`stage34_tutorial_relay` 在真实 tutorial 场景里跑：

- 负例：只控制乌龟下潜，`relay_log` 为空，教学 step 仍为 2，不前进。
- 正例：兔子跳 → 真 SHIFT → 乌龟下潜，产生 `perfect` relay，教学 step 前进到 3。
- 结论：教学不能靠文字/单角色通过；必须亲自完成一次真实龟兔接力。

### 2.3 跳过教学路径

- 正式 race 的 log1 在 24.0 s，已是真接力；
- 原有首次障碍 lesson prompt 仍会在接近时给出 “JUMP, SWITCH, DIVE” 提示；没有新增按键、没有新增说明面板。
- 没有为了提前展示而连续塞高难度障碍：Z1 前 60 秒仍是 rock → gate → rock → log → shark → rock → beam → wall，只加高了第一根浮木。

## 3. MISCHIEF 700 px 对齐

- 原代码只检查前方最近障碍 `distance <= 340`；任务基线是 700。
- 修改：`race.gd` 新增 `_mischief_clear_of_hazards()`，只有最近障碍距离 **> 700 px** 才允许进入 MISCHIEF；`_maybe_start_mischief` 使用该函数。
- 保留：32% 概率、2.6 s 抱怨窗口、冷却、SHIFT 中断、救援优先。

边界测试（`stage34_mischief_distance`）：

| 距离 | 允许 MISCHIEF |
|---:|---|
| 699 px | 否 |
| 700 px | 否 |
| 701 px | 是 |

- 699 px 内 500 次尝试：**0 次启动**。
- 701 px 外 2000 次：**637 次 = 31.9%**，仍约 32%。
- `stage29_mischief_audit` 复测：兔子 31.9%、乌龟 31.3%，2.6 s 窗口通过。

## 4. 验证结果

| 项目 | 结果 |
|---|---|
| `stage34_first60` | PASS：log1=24.0s，单角色均失败，BRO DIVE 通过 |
| `stage34_tutorial_relay` | PASS：教学必须真实接力，step 2→3 |
| `stage34_mischief_distance` | PASS：699/700 阻止、701 放行，701 外 31.9% |
| `stage3_playtest` | PASS：两圈 55/55，270.7 / 270.6 s，每圈 1 次事故，max_stuck 0.0 |
| `stage32_shark_timing` | PASS：10/10 轮 + Z3；T→R→T、预警 0.95/0.95/1.05、安全 0.70/0.70、无重叠 |
| `stage31_arena` | 25/25（窗口）：测试场、8 类、SHARK6、菜单/重启/返回、best 不变 |
| `stage21_shark_pack` | 10/10 |
| `stage22` / `stage15` / `stage19` / `stage4_hud_score` | 全 exit 0；HUD 28/28 |

MCP 实测（与自动化分开）：

- `godot_health_check` bridge connected；菜单→漫画→教学→K→比赛实际跑通；教学 SHIFT 后布局稳定。
- 测试场鼠标生成 SURFACE_ROCK；滑条切 SHARK6 后生成成功。
- 截图：`docs/reports/longrun/feel33/01-menu.png` … `07-race-play.png`。
- MCP 编辑器 play FPS 151–165；没有用它测 Web 版本。
- 没有真人完整 55 组试玩。

## 5. 未解决

1. 教学第一根浮木仍用模板高度 200；它靠 step3 的 `_relay_seen` gate 强制真实接力，不是几何强制。两条路径都能成立，但教学与正式关卡的 log1 手感不完全一致。
2. 跳过教学路径依赖原有 lesson prompt，没有新增专门的“第一次 BRO DIVE”重提示；真人是否看懂仍需试玩。
3. log1 加高是可见变化，需 Producer 看画面是否仍像“浮木”而不是墙。
4. MCP 仍未覆盖 Web 掉帧/清晰度；那需要 Edge/CDP 在 CloudBase 链接上 profile。
5. 项目里保留 `addons/godot_mcp` 和 `MCPRuntimeProbe`；正式交付前决定是否移除。

## 6. 停止

- 未新增按键、技能、障碍类型、远程攻击或环境互动。
- 未改 SHARK6、测试场、评分/救援/氧气规则。
- 未导出、未打包、未覆盖公开 Web。
- 等待 Producer 质检。
