# FEEL-29 CORE LOGIC STABILIZATION

- 基线：FEEL-28
- 模式：CONTROLLED_WRITE
- 本轮未导出 EXE、未打包、未覆盖交付版本；`best.json` 未修改（MD5 `067DEB9A71A19C2F6F9F6DC41FEABF09`）。
- 测试污染的 `user://settings.json`（被改成 en）已恢复为 `{"language":"zh"}`。
- 不宣布下一阶段，不标记 Producer 候选。

## 1. 任务A：教学 SHIFT 换行

### 根因

教学面板的文本列是 `VBoxContainer`，宽度由列内最长子控件决定。`_hint` 在 SHIFT 后换成更长的提示（例如 `兔子：↑ 跳 / ↓ 趴低` → `SHIFT 回 兔子：↑ 跳 / ↓ 趴低`），把整列从 **135 px 撑到 203 px**。`_line` 是 `AUTOWRAP_WORD_SMART`，列变宽后主台词从 **2 行变 1 行**，面板高度从 **189 变 162**——玩家看到的就是“一切换角色，大表哥台词就跳一下”。

### 修改

`scripts/test/tutorial.gd`：

- 文本列固定宽度：`box.custom_minimum_size = Vector2(702, 0)`、`SIZE_EXPAND_FILL`。
- `_hint` 允许在列内换行：`autowrap_mode = AUTOWRAP_WORD_SMART`。
- 标题、台词、提示的文本内容和教学流程未改。

### 修改前后

| 指标 | 修改前（兔→龟） | 修改后（10 次来回） |
|---|---|---|
| 主台词宽度 | 135 → 203 | 702 → 702 |
| 主台词行数 | 2 → 1 | 1 → 1 |
| 面板高度 | 189 → 162 | 162 → 162 |
| 面板宽度 / x | 880 / 360 | 880 / 360 |

证据：

- `python` 测试 `stage29_tutorial_layout`：`TUTORIAL LAYOUT: PASS`，10 次 SHIFT 全部稳定。
- JSON：`docs/reports/longrun/feel29-tutorial-layout.json`
- 实机窗口截图：`docs/reports/longrun/feel29/tutorial-rabbit-1920.png`、`tutorial-turtle-1920.png`
- 教学流程窗口化：`stage13_tutorial_flow` PASS，截图在 `docs/reports/longrun/feel13/`。

## 2. 任务B：BRO DIVE 接应卡顿

### 根因

1. **兔子会甩开壳。** `rabbit.launch()` 的水平初速是 `turtle_speed + 15`，而空中按 → 的目标是 `air_base + AIR_MAX`，`AIR_MAX = 150`。玩家按住加速起跳时，兔子空中水平速度可以到 **390 px/s**；乌龟下潜时速度仍在 **220–260 px/s**，不会跟着兔子加速。两者差距很快超过接人窗口 `PICKUP_DX = 120`，`can_pickup()` 失败，兔子落水。
2. **落水后只能被拉回。** 兔子落水后进入救援/接应流程，位置从落水点被搬回壳上；玩家看到的就是“先冲出去，再被拽回来”的卡脚感。
3. **接住时也可能往左拽。** `_tick_carry()` 原来把兔子从接住点直接 lerp 到“当前壳心”；如果兔子落在壳前面，x 会往回走（本探针基线最大 4.7 px，速度更高时更大）。

### 修改

- `scripts/actors/rabbit_controller.gd`
  - 新增 `air_speed_cap`（默认 `INF`），`tick_air()` 在受控/失控两种情况下都把水平速度收向该上限。
  - `reset()` / `attach()` / `launch()` 复位上限。
- `scripts/race.gd`
  - 新增 `_near_bro_dive_log()`：兔子在空中、壳接近任一未摧毁 `FLOATING_LOG`（前 320 px / 后 80 px）时为真。
  - `_tick_rabbit()` 在该条件下把上限设为 `turtle.speed + 12`。**从起跳就生效**，所以 SHIFT 早或晚都不会先把兔子甩出去；只限水平速度，不改跳跃高度、下潜速度、接人窗口或评分。事故状态（`accident_state != "NONE"`）下不启用，避免救援过程被限速。
  - `_tick_carry()`：`next.x = maxf(next.x, rabbit.position.x)`；x 只允许保持或向前，等壳自己追上来；x 进入 `CARRY_SNAP_DIST`（24 px）内才完成接住。y 曲线不变，没有瞬移、没有提高吸附速度。

### 修改前后（18 个时序组合）

| 指标 | 修改前 | 修改后 |
|---|---|---|
| 落水事故 | 右方向键按住时 6/9 组合落水 | 0/18 |
| 接应期间 x 回拉 | 最大 4.7 px | 0.0 px |
| 接住时横向差 | 最大 35.6 px | 最大 19.4 px |
| 成功通过得分 | 250（成功组合） | 250（成功组合） |
| 事故/扣分 | 落水后转救援 | 成功接住无事故、无扣分 |

证据：

- `stage29_dive_handoff`：`rows=18 bad=0`，JSON `docs/reports/longrun/feel29-dive-handoff.json`。
- 实机窗口截图：`docs/reports/longrun/feel29/dive-catch-1920.png`、`dive-carry-mid-1920.png`、`dive-after-1920.png`。
- `stage4_bro_dive_matrix`：`log3` 通过数 57/100 不变；失败构成从“35 incomplete + 8 rabbit_water”变为“39 incomplete + 4 turtle_hit”，**落水类失败清零**。

### 仍存在的时序边界

SHIFT 晚 0.30 s、起跳提前量 140/160 px 时，乌龟会撞到浮木，记 `TURTLE_DIVE_LATE`（-100）。这是原有的“下潜太晚”规则，不是接应回拉；180 px 提前量 + 0.30 s 延迟可通过。本轮没有改这个窗口。

## 3. 任务C：核心状态回归与 MISCHIEF 审计

### 回归结果

| 项目 | 结果 |
|---|---|
| 两圈 55/55（stage3_playtest） | PASS：270.7 s / 270.6 s，55/55，每圈 1 次事故，max_accident 0.80 s，max_stuck 0.0 |
| 耦合（stage22_coupling） | exit 0，全部 ok |
| 氧气耗尽（stage15_oxygen_fail） | exit 0，OXYGEN_OUT 正确进 FAILED |
| 捣乱（stage15_mischief） | exit 0，含 30/120 Hz |
| 鲨群（stage21_shark_pack） | exit 0：三波顺序、胖小弟目标兔子、老大目标乌龟、救援回 CIRCLE |
| 海鸟（stage19_bird_behavior） | exit 0：只有 dive/poop，种子可复现 |
| HUD 分数（stage4_hud_score） | PASS，28/28 |
| 流程（stage4_flow） | PASS，best.json 逐字节还原 |
| 菜单输入（stage4_menu_input，实机窗口） | PASS；headless 下鼠标点击无效是环境限制，不是游戏缺陷 |
| 教学（stage13_tutorial_flow，实机窗口） | PASS，含 4 步、失败提示、K 跳过 |
| 技能（stage12_skills） | 9/9 PASS |
| SHIFT 接力（stage11_shift_relay） | 9/10；`3_dive_to_jump_clever` 期望“切走后乌龟继续下潜”，该行为已在 FEEL-22 主动移除（`turtle_controller.gd:205-208`），属过期断言 |
| SHIFT 手感（stage4_shift_feel） | 失败项为过期断言：期望 HUD 文本 “TURTLE”（现为 BITT）和旧同帧 leap 语义；未计入本轮回归门 |
| 核心体验（stage4_core_experience） | 失败项为过期断言：期望自动 combo/Showtime 与 ≥3.5 s 反应（现已取消/压缩到 3.18 s） |

### MISCHIEF 审计

实现的既定规则与代码一致的部分：

- 未受控时间 `+delta * 1.10`，12 s 进入抱怨；20 s 封顶。
- 抱怨 2.6 s；不在障碍前 340 px 内启动；救援/Showtime 优先。
- SHIFT 到捣乱角色立即 `_end_mischief("shifted")`，冷却清零。
- 没有 3 格计数、没有 HUD 计数；事件式。

**发现一处规则偏差，本轮按要求只记录、不修改：**

`scripts/race.gd:3788`：

```gdscript
if float(_ignore_t.get(who, 0.0)) >= 12.0 and randf() > 0.68:
    # 取消抱怨、ignore 退回 8、return（不启动）
...
# 否则启动 MISCHIEF
```

分支写反了：`randf() > 0.68`（约 32% 的值）走的是“**不启动**”，实际启动概率约 **68%**。行为计数：

```
MISCHIEF_RATE who=rabbit starts=707/1000 = 70.7%
MISCHIEF_RATE who=turtle starts=679/1000 = 67.9%
```

既定规则是“12 s 后约 32% 概率动手”。这与之前确认的事件式规则不一致，也会让玩家感觉“刚没人管就频繁被搞”。按任务书要求，本轮没有自行改触发规则；下一轮只需把两个分支对调，并补一条 1000 次触发率断言。

另有两处死代码：`GameManager.role_mischief_pending / role_mischief_role` 已无人置 true，`relieve_pressure()` 在计数删除后无调用；不影响行为，列为清理项。

## 4. 已知未解决

1. **MISCHIEF 实际触发率 68% vs 约定 32%**（见上），是当前仍影响核心体验的逻辑缺陷。
2. SHIFT 晚 0.30 s + 提前量 140/160 px 仍会撞浮木（原有窗口，未改）。
3. 没有真人完整 55 组试玩；两圈是自动驾驶，窗口测试只覆盖教学、菜单、BRO DIVE 接应。
4. `stage4_core_experience`、`stage4_shift_feel`、`stage11` 的个别断言已过期，建议下一轮统一修测试而不是改游戏。

## 5. 有趣性判断

实际在窗口里跑教学和 BRO DIVE：修改前按住 → 起跳再 SHIFT 下潜，兔子会冲过壳落水再被拉回；修改后同样输入能接住，画面出现 “NICE SAVE!”，得分 +250，没有回拉。判断：**有保留**——接应这一拍现在干净了，但晚 0.3 s 仍会撞木，且 MISCHIEF 触发率偏差还在，整体还不能说“稳定有趣”。

## 6. 验收

`python LESSONS/CHECKS/qc.py status --task tbb-feel29-core-stability`：6/6 通过（R009 PASS）。证据文件：

- `docs/reports/longrun/feel29-tutorial-layout.json`
- `docs/reports/longrun/feel29-dive-handoff.json`
- `docs/reports/longrun/feel29/*.png`
- `docs/reports/stage3-run.log`

## 7. 停止

- 未导出、未打包、未覆盖 Web/EXE 交付。
- 未修改关卡、评分、救援、氧气、障碍类型。
- 等待 Producer 亲自体验后决定下一轮。
