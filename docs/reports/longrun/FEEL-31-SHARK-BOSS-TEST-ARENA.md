# FEEL-31 SHARK BOSS + DYNAMIC OBSTACLE TEST ARENA

- 基线：FEEL-29
- 模式：CONTROLLED_WRITE
- 未导出 EXE、未构建交付包、未覆盖 GitHub 公开 Web/EXE；按 Producer 要求另行部署了 CloudBase 国内试玩：
  **https://turbbit-bro-d9g2a2xh1229108f2-1463989963.tcloudbaseapp.com/**
- `best.json` 未修改（MD5 `067DEB9A71A19C2F6F9F6DC41FEABF09`）。
- 不宣布下一阶段；等待 Producer 质检。

## 1. Z3 鲨鱼群小头目

### 三只鲨鱼的分工

| 角色 | 位置 | 攻击 | 目标 | 解法 | 判定 |
|---|---|---|---|---|---|
| 老大 | 最前 | 正面破水（沿用 `_ambush`） | 乌龟 | 乌龟跃起 | 原 SHARK 框 |
| 瘦小弟 | 中间 | 贴水面横扫 | 乌龟 | 下潜或跃起 | `Rect2(x-45, 300, 90, 66)` |
| 胖小弟 | 最后 | 身后低扑 | 兔子 | 趴低 | `Rect2(x-58, 246, 116, 92)` |

节奏：`CIRCLE → LEAD_LUNGE → GAP1 → THIN_LUNGE → GAP2 → FAT_LUNGE → RETREAT → DONE`。
（FEEL-32 已把实际顺序改为老大 → 胖 → 瘦，见 `FEEL-32-SHARK6-TIMING-READABILITY.md`。）

- GAP1 有 0.95 s 预警，屏幕上给乌龟 `!`；GAP2 有 1.05 s 预警，给兔子 `!!`。
- 三只鲨鱼现在都有实际攻击体；瘦小弟不再只是跟随绘制。
- `_shark_pack_log` 记录 `leader / thin / fat` 的 attack/hit，供测试与回归读取。
- 成功躲避不扣分；被瘦鲨命中走乌龟接触，被胖鲨命中走兔子接触，原有事故/救援链不变。

代码：`scripts/race.gd:4593`（`_tick_shark_pack`）、`4675`（介入）、`4734`（`_spawn_shark_follower`）。

### 看台行为

- 鲨群打完 `DONE` 后进入 12 s 看台：三条鲨影沉到屏幕下方，随浪轻晃，每隔约 2.6 s 换 `?` / `!` 气泡。
- 看台没有碰撞、没有攻击、不锁控制；测试场“看台行为”按钮可独立触发。
- 代码：`race.gd:4829`（`show_shark_stands`）、`4844`（`_draw_shark_stands`）。

### 动态赛道干预

- 触发条件：鲨群结束后，前方 500–900 px 内出现 `LOW_BEAM` 或 `LOW_BIRD`。
- 流程：1.2 s 预警（鲨影 + 落点圈 + 文案）→ 原障碍 `destroyed_groups` → 在同一 x 生成胖鲨低扑（life 6 s）。
- **答案不变**：原障碍是“兔子趴低”，替换后仍是“兔子趴低”，不会突然换题；
- 没有被替换的障碍类型本轮不处理（任务要求先实现一种可靠流程）。
- 代码：`race.gd:4675`（`trigger_shark_intervention`）。

## 2. 动态障碍测试场

### 修改文件

- `scripts/race.gd`：鲨群三拍/日志、看台、介入、测试场生成与清除。
- `scripts/menu.gd`：主菜单 TEST ARENA 入口。
- `scripts/autoload/locale.gd`：测试场、瘦鲨、介入文案。
- `scripts/test/test_arena.gd` + `scenes/test_arena.tscn`：测试场场景与鼠标面板。
- `scripts/test/stage21_shark_pack.gd`：三只鲨鱼/看台/Z3 介入回归。
- `scripts/test/stage31_arena.gd` + `scenes/stage31_arena.tscn`：测试场自动/窗口验收。

- 主菜单新增独立按钮“动态障碍测试场 / TEST ARENA”（`scripts/menu.gd:132`），点击进入 `scenes/test_arena.tscn`。
- 测试场复用 `race.tscn` 的移动、SHIFT、跳跃/趴低/跃起/下潜、碰撞和动态障碍逻辑；默认 `load_level([], [])`，没有自动障碍。
- 面板（仅测试场，CanvasLayer 60）：
  - 障碍类型下拉框 + 横向 HSlider；
  - 生成（前方 700 px）、清除、重新开始、返回主菜单；
  - 看台行为、赛道介入（没有合适目标时先生成一组 LOW_BEAM 再替换）。
- 可生成 8 项：SURFACE_ROCK、LOW_BIRD、LOW_BEAM、DIVE_GATE、FLOATING_LOG、SHARK、HIGH_WALL、SHARK6。
- SHARK6 复用正式鲨群；再次生成会替换旧鲨群。
- 测试场设置 `GameManager.test_no_best = true`、`race.test_no_finish = true`；不写 `best.json`，返回菜单时恢复 `test_no_best=false`。
- 代码：`scripts/test/test_arena.gd`、`scenes/test_arena.tscn`；生成/清除：`race.gd:676` / `719`。

## 3. 验证

### 自动化

| 项目 | 结果 |
|---|---|
| `stage21_shark_pack` | **10/10**：老大→瘦→胖顺序、瘦鲨目标乌龟且下潜安全/巡航命中、胖鲨目标兔子且趴低安全/站立命中、救援清空、看台、Z3 正式组存在且能攻击、Z3 介入替换 |
| `stage31_arena` | **24/24**（窗口运行，含鼠标点击生成）：默认空场、持续前进、8 类逐个生成+碰撞接线、连续生成、清除、看台无害、介入摧毁并替换、替换后趴低安全/站立命中、SHARK6 三只全出手、best.json 字节不变、菜单入口、重启、返回菜单 |
| `stage3_playtest` | PASS：两圈 55/55，270.7 / 270.6 s，每圈 1 次事故，max_stuck 0.0 |
| `stage22_coupling` | exit 0 |
| `stage15_oxygen_fail` / `stage15_mischief` | exit 0 |
| `stage19_bird_behavior` | exit 0 |
| `stage4_hud_score` | PASS，28/28 |
| `stage13_tutorial_flow`（窗口） | PASS |
| `stage4_menu_input`（窗口） | PASS |
| `stage4_flow` | PASS（best.json 逐字节还原） |
| `stage29_tutorial_layout` / `stage29_dive_handoff` | PASS / rows=18 bad=0 |

### 窗口测试

- 测试场实机窗口 1600×900：`arena-panel.png`、`arena-stands.png`、`arena-intervention.png`、`arena-shark6-thin.png`、`arena-shark6-fat.png`、`arena-shark6.png`、`menu-test-arena.png`。
- 鼠标路径用 `InputEventMouseButton` 真实经过视口：点击“生成”与菜单“动态障碍测试场”均成功。
- 自动化与窗口测试分开记录；没有把自动驾驶写成真人试玩。

## 4. 未解决 / 已知限制

1. 鲨鱼、看台、障碍仍是灰盒剪影；没有新美术/音效。
2. 看台只有轻晃 + 气泡，不是完整的等待/挑衅/争吵动画。
3. 介入只覆盖 `LOW_BEAM` / `LOW_BIRD`（答案同为趴低）；其他障碍类型仍是摧毁后无替换的扩展项。
4. 没有实现“有利通道”分支（任务允许，不强制）。
5. 测试场面板会遮住左侧部分赛道；仅为测试工具，不影响正式 HUD。
6. FEEL-29 的 MISCHIEF 触发率偏差（实测 68–71% vs 约定 32%）仍未修，属于上一轮遗留。
7. 没有真人完整 55 组试玩；窗口测试只覆盖测试场、教学、菜单和 BRO DIVE。

## 5. 有趣性判断

**有保留。** 三只鲨鱼现在是“跃 / 潜 / 趴”三种可读答案，测试场能很快连续验证；但表现仍是灰盒，看台行为比较单薄，且真人连续躲避的爽感未验证。

## 6. 停止

- 未导出 EXE、未构建交付包、未覆盖 GitHub 公开 Web/EXE。
- 按 Producer 要求已部署 CloudBase 国内试玩（测试域名，需点一次“确定访问”）。
- 未修改正式关卡结构、评分、救援、氧气、普通鲨鱼/海鸟规则。
- 等待 Producer 质检。
