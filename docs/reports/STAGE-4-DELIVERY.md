# STAGE 4 交付说明 — 核心体验完善 + 主菜单交互

日期：2026-11-11（截止 15:00 前完成）
阶段：`STAGE=4`，未进入阶段 5。
素材：继续冻结，本轮零新增美术 / 字体 / 音频。

## 直接启动

```
D:\Godot_v4.7-stable_win64_console.exe --path D:\GAMESTUDIO\TURBBIT
```

（主场景 `res://scenes/menu.tscn`：进游戏先看到主菜单，点「开始游戏」或按 Enter 进入赛道。）

## 结论一览

| 交付项 | 状态 | 证据 |
|---|---|---|
| 主菜单三按钮、鼠标点击、悬停/按下/焦点反馈 | PASS | `logs/stage4_menu_input.log`、`screenshots/stage4_menu{,_en}.png` |
| 退出二次确认（默认焦点在取消） | PASS | `logs/stage4_menu_input.log` L14-19、`logs/stage4_menu_quit_smoke.log`（确认后进程 exit 0） |
| 暂停 继续 / 重新开始 / 主菜单 | PASS | `logs/stage4_menu_input.log` L28-38 |
| 结算 再玩一次 / 主菜单，R/M 仅作辅助 | PASS | 同上 L39-44、`logs/stage3_selftest.log` L79/L82 |
| 中英双语四处完整、语言持久化 | PASS | `logs/stage4_bilingual.log`、四组中英截图 |
| 兔子五段失衡（稳 → 滑 → 边缘 → 临界 → 落水） | PASS | `logs/stage4_core_experience.log` L11、四张姿态截图、`stage4_fall.png` |
| 乌龟五段下沉（稳 → 缓沉 → 明显 → 临界 → 翻肚皮） | PASS | 同日志 L18（8.47 s 到事故、y=741）、`stage4_flip.png` |
| SHIFT 自由且真实（不清零、不加值、无控制锁） | PASS | 同日志 L25、`logs/stage4_shift_graybox.log` |
| 连按 5 次 SHIFT 不能免费消风险 | PASS | 同日志 L31（6.03 → 7.43） |
| 深壳不能绕过兔子层障碍（水下暗流） | PASS | 同日志 L55（34 条 rect，最差缺口 0.00 px） |
| 完整赛道两场零事故、9 门 18 条 `acc=NONE` | PASS | `docs/reports/stage3-run.log` |
| STAGE0–4 回归（12 个场景）、双语全流程 | PASS | `logs/*.log`，全部 exit 0 |
| best.json 不被测试污染 | PASS | sha256 `6af317c2…a7ba6`（收尾复核） |
| 真人试玩 | NOT TESTED | 由制作人执行 |

无 FAIL、无 BLOCKED 项。

## 1. 本轮工作

1. **双方失衡链条独立实现**，五段：稳定 0–1.5 s / 轻微 1.5–4.5 s / 明显 4.5–7.5 s /
   临界 7.5–9.5 s / 事故。兔子以「晃动」为主要预警，位移到边缘才明显；乌龟以「下沉」
   为预警，有最大深度与危险线。
2. **夺回控制不等于清零**：切换立即生效，0.5 s 站稳后按 2.5/s 恢复；连按 SHIFT
   不会把双方风险一起磨掉。
3. **姿态反馈可视化**：兔子 lean 0.04/0.10/0.26/0.42 rad、wobble 1.5/2.5/5/8 px；
   乌龟 tilt 0.02/0.05/0.12/0.22 rad；两张事故演出互不相似（落水 vs 翻肚皮）。
4. **水下暗流**：兔子握权且壳沉到 y>410 时，兔子层障碍的水下部分仍然生效
   （34 条 rect 逐条审计，最差缺口 0.00 px），堵住「一直下沉绕过跳/趴」的免费路线；
   把控制交回乌龟，浮力抬壳即解除。
5. **菜单交互全面改原生 Control 按钮**（开始游戏 / 设置 / 退出游戏；退出确认；
   暂停三项；结算两项），鼠标可达、键盘焦点可走、Enter/Space 可确认；
   快捷键 R/M 保留为辅助路径。
6. **修正下沉门余量**：失控首段下沉 25 → 35 px/s，解决全跑中两个门在「墙前 300 px
   换人」时差 8 px 撞墙的问题（门内第二段仍 40 px/s，不会变成快沉）。
7. **测试工具修正**：真实按键同时带 `keycode` 与 `physical_keycode`；结算页回主菜单
   改测 M（Enter 现在是「确认当前焦点」）；倾角采样最后一点改 7.9 s（8.5 s 会跨过
   8.45 s 的翻肚皮事故边界）。

## 2. 菜单结果

- 主菜单：3 个可见原生按钮，`start.get_global_rect()` 在 1600×900 视口有真实矩形，
  悬停触发 `is_hovered()`，点击进入 `race.tscn`，状态 RUNNING。
- 退出确认：出现「取消 / 退出」，焦点默认在「取消」；点取消回菜单、进程不退出；
  确认后进程以 exit 0 结束（`stage4_menu_quit_smoke.log`）。
- 设置：语言按钮点击立即切换并写入 `user://settings.json`，返回回主菜单。
- 暂停：继续 / 重新开始 / 主菜单三项全部鼠标点通；重开场景重建、计时归零。
- 结算：再玩一次 / 主菜单两项点通；R、M 仍可用，但不是唯一路径。
- 键盘：进入页面即有按钮焦点，DOWN/UP 移动焦点，SPACE 触发；Enter 在菜单启动
  比赛（`stage3_selftest` L53）。
- 所有菜单操作不写 best.json（测试内逐字节断言 + 收尾哈希复核）。

## 3. 双语回归

`stage4_bilingual` 枚举全部文本 ID（含菜单、设置、暂停、结算、事故、Showtime、
区域、提示）全部有 zh/en；`stage4_flow` 中英文各走完 菜单→比赛→暂停→继续→终点→
结算→重开/返回菜单。四处页面截图逐张看过：无缺字、无溢出、无中英混排残留。

## 4. 关键参数（改前 → 改后）

| 参数 | 改前 | 改后 | 原因 |
|---|---|---|---|
| 兔子滑落计时 | 0.8 / 2.4 / 3.6 s | 1.5 / 4.5 / 7.5 / 9.5 s（五段） | 约 10 s 宽容窗口；晃动先行、位移后至 |
| 乌龟下沉分段 | 90 / 110 / 160 px/s | 35 / 40 / 55 / 80 px/s | 失权即快沉改成「看得见、来得及」 |
| 首段下沉（SINK_RELAX） | 25 px/s | 35 px/s | 25 时全跑两个门差 8 px 撞墙 |
| 暗流判定线 | 无（深壳可白嫖） | y>410（`UNDERTOW_MARGIN=76`） | 堵绕行，同时给正常过梁留余量 |
| 事故演出 | 硬直 0.8 / 救援 2.2 / 修理 2.0 | 救援/修理 1.6 s、闪白 0.15 s | 短、夸张、马上回到玩法 |
| 同源保护 | 2.5 s | 3.0 s | 指令要求 3 s 内不二连 |
| 菜单 | 文本 + 快捷键 | 原生按钮 + 焦点 + 退出确认 | 本条指令 |
| 结果页快捷键 | R / Enter 回菜单 | R 重开、M 主菜单、Enter 确认焦点 | Enter 与按钮焦点语义统一 |

## 5. 完整流程实测

自动驾驶跑正式关卡两场（`docs/reports/stage3-run.log`）：

- run 1：302.8 s，55/55 组，S，0 事故，16 次 Showtime；
- run 2：302.9 s，55/55 组，S，0 事故；
- 9 个下沉门共 18 条出墙记录，全部 `acc=NONE`；
- 跑前备份、跑后写回 best.json，收尾 sha256 `6af317c2…a7ba6`。

说明：这是确定性自动驾驶，只证明关卡可解、事故链不会误触，**不代表真人难度或手感**。

## 6. 自查发现并修掉的问题

1. 主菜单鼠标点在 headless 下永远无效（dummy display）→ 所有鼠标验证改为真实窗口；
   并在脚本头写清楚，避免以后又「绿」在假环境里。
2. 截图捕获一直挂起：命令行参数少了 `--`，`OS.get_cmdline_user_args()` 为空 →
   统一写成 `... --path . -- --capture-menu x.png`。
3. 结算页标题金字压金太阳读不清 → 太阳让到标题侧后方。
4. 退出确认的「退出」和主菜单的「退出游戏」被 `contains` 匹配混在一起 → 加精确匹配。
5. `stage3_selftest` 的 Enter 失败：测试只发 `physical_keycode`，`ui_accept` 按
   `keycode` 匹配 → 两个都填。
6. 结算页 Enter 行为变了（确认焦点=再玩一次）→ 测试改走 M，屏幕提示同步改对。
7. 下沉门两个 8 px 撞墙 → SINK_RELAX 25→35（见 §4）。
8. 倾角回归在 8.5 s 采样跨过 8.45 s 的翻肚皮事故，读到事故态 → 采样点改 7.9 s，
   事故时序由 `_test_turtle_window` 单独验。

## 7. 已知问题（未解决，需要制作人裁决或真人试玩）

- **真人手感 NOT TESTED**。所有通过都来自脚本与确定性自动驾驶；会不会好玩没被验证。
- 深壳绕行已用暗流堵住，但暗流是半透明柱 + 判定，真人在低帧/低分辨率下是否能看懂，未验证。
- 兔子能力仍非必需：55 组中必须跳跃 0、必须接人 0（`stage4_level_audit` 总量未变）。
- Zone 1 后段仍有 8.3–8.7 s 空档；Zone 3 三元组只有 8 种；氧气不构成路线决策。
- 设置页只有语言项，无音量/画面。
- 菜单视觉是原生 Control 占了位，风格化留给美术解冻后。

## 8. 有趣性自评（实跑后回答）

**结论：有保留。**

1. **新增操作能否一句话说清？** 能。SHIFT = 换人；乌龟负责前进，兔子负责避障；
   失衡用姿态+颜色+下沉表达，不靠读条。
2. **有没有「我做了判断，然后成功了」的瞬间？** 有，日志可见：8.8 s 临界时换回
   乌龟，风险按 2.5/s 收回而不是清零（8.83 → 6.03）；下沉门里按壳深决定换人点，
   早换撞暗礁、晚换撞墙。都是脚本判断链，不是人工手感。
3. **操作错了有没有可见后果？** 有。落水（水花+耳朵打转+X 眼）与翻肚皮（奶白肚皮+
   四肢朝天+红 X）两种演出，1.6 s 救援后带 3 s 同源保护；连续失误不会滚成死循环。
4. **比上一阶段多了一个想再试一次的理由吗？** 不明显。本轮是宽容度与可读性，
   外加菜单可用性；复玩动机仍来自 Showtime 和纪录。

**本阶段最可能无聊的 30 秒**：Zone 1 后段 x≈7600–13000（自动驾驶 t≈36–66 s），
与上一轮同一处；连续两阶段同一处，下一阶段必须先改这段。

## 9. 成熟度（诚实说明）

- 这是**灰盒可玩候选**：玩法、判定、菜单、双语、回归齐全，可直接双击启动试玩。
- 美术仍是占位（原生绘制），音频未接入，动画未做；素材冻结未解除。
- 自动化覆盖的是规则与可达性，不覆盖「好不好玩」「看不看得懂」。
  按指令，这两项由制作人人工验收；当前标记 `NOT TESTED`。

## 10. 证据索引

- 核心体验：`docs/reports/logs/stage4_core_experience.log`、`docs/reports/stage4-core-experience.json`
- 菜单输入：`docs/reports/logs/stage4_menu_input.log`、`logs/stage4_menu_quit_smoke.log`
- 完整赛道：`docs/reports/stage3-run.log`
- 双语 / 流程：`logs/stage4_bilingual.log`、`logs/stage4_flow.log`
- 其余回归：`docs/reports/logs/stage{0,1,2,3}_selftest.log`、`stage4_{hud_priority,shift_graybox,level_audit,metrics,surfboard,experience_rework}.log`
- 截图：`screenshots/stage4_menu{,_en}.png`、`stage4_settings{,_en}.png`、
  `stage4_pause{,_en}.png`、`stage4_result{,_en}.png`、`stage4_race{,_en}.png`、
  `stage4_pose_{relaxed,sliding,edge,critical}.png`、`stage4_fall.png`、`stage4_flip.png`、
  `stage4_accident{,_en}.png`
