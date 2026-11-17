# 体验修复总状态（2026-11-18）

范围：Z2 坐标债、海鸟离屏、乌龟弹回/六次失败、便便螺旋、教学过渡、
鲨群专场/流畅度/准星、乌龟叹号、Showtime 小奖励、文本与小头像。
未导出、未打包、未部署；`best.json` 保持
`067DEB9A71A19C2F6F9F6DC41FEABF09`。

## P0

### Z2 码头/背景

- `zone2_dock.gd` / `zone2_layer.gd`：`ZONE_START/END` 15000/39000 → **10000/34000**；
- `_draw_zone2_blend`：14600–15200 → **9600–10200**；
- Z1/Z3 图层不再在边界 `return` 硬裁剪，前后 600 px 按 alpha 淡出；
- 第一组 Z2 障碍 `shark3` 10162.5 → **10600**，给码头 2.7 s 读环境时间；
- `p0d_entry` PASS（5/5），新截图在 `docs/reports/longrun/feel10-p0d/`。

### 海鸟离屏

- 鸟组离开镜头左侧 0.55 屏宽：整组 `DONE`，清掉该组投射物；
- 发射前也检查鸟是否在屏内；
- 新增 `stage48_bird_offscreen` PASS（4 项）。

### 乌龟弹回 / 连续六次失败

- 乌龟层障碍（礁拱/高墙/浮木下段/普通伏击鲨）撞上后退 **140 px**，
  速度归零 0.25 s 后自动回 base；
- 第一次撞同组扣分/记事故；后续弹回不再重复扣分/扣氧，但计入连续撞击；
- 连续 **6** 次且期间没有干净通过 → `BONK_OUT`；
- 乌龟 1–6 级“囧”表情；失败页显示“我让我的兄弟晕过去了。”+ 兔子头像；
- 第 2 次弹回由另一个兄弟说“别硬顶！先换人！”；
- `stage45_bounce_recovery` PASS（8 项）。

## P1

- **便便**：螺旋/卷曲飞行；落点改到水面 `SURFACE_Y + 10`；落水后停转、下沉、淡出；
  只在落水溅射判伤；`stage19` PASS（`poop_hit_rabbit`、`poop_splash`）。
- **教学→正赛**：1.4 s 台词后 0.35 s 黑场，正赛再 0.35 s 淡入；
  `stage50_tutorial_fade` PASS。
- **鲨群专场**：`LEAD_LUNGE`…`RETREAT` 期间 `shark6 ±1500` 普通障碍不画/不判/不弹教学；
  `stage49_arena_exclusive` PASS。
- **鲨群流畅度**：RISE 0.12→0.26 s、HOLD 0.55→0.60 s、RETREAT 0.45→0.55 s；
  上冲 12 px 过冲、队形 0.08 s 阻尼、准星从 WARN 保持到 HOLD；
  `stage32` / `stage21` PASS。
- **乌龟叹号**：神游标记抬到壳上方 96 px，气泡/字号与兔子同级。
- **Showtime**：0.7 s；兔子小跳后空翻，乌龟小 ollie + 转一下；
  清空 BRO 槽/抱怨/捣乱状态；+100 分、+0.5 氧；精准动作 15% 触发，
  18 s 冷却、一局最多 3 次；不恢复 0/3 计数器；`stage46` PASS。
- **文本**：`comic.6`“换着来？”、`干净通过`→“漂亮！”、
  胖鲨→“胖鲨盯上兔子了！”+乌龟说“趴下！”、瘦鲨→“瘦鲨压过来了！”+兔子说“往下！”；
  `stage4_bilingual` PASS。

## P2

- 新增 `scripts/ui/bro_portrait.gd`，HUD 角色行改用小头像；
- 新增 `GameManager.bro_say(who, text)`；HUD 显示说话者头像 + 短句；
- 失败页 BONK_OUT 配兔子头像；
- 其余出戏文本尚未全量改写，后续可按清单继续。

## 验证

| 测试 | 结果 |
|---|---|
| `stage3_playtest` | **PASS**：238.3 / 238.2 s，53/53，3 accidents，max_stuck=0，grade B |
| `stage3_selftest` | PASS |
| `p0d_entry` | PASS 5/5 |
| `stage19_bird_behavior` | PASS |
| `stage21_shark_pack` | PASS |
| `stage32_shark_timing` | PASS |
| `stage35_combo_audit` | PASS（10 组双解 ×2 路线） |
| `stage10_joint_semantics` | PASS |
| `stage13_catch_matrix` | PASS |
| `stage42_shark_fairness` | PASS |
| `stage31_arena` | PASS（窗口模式，60 s 内） |
| `stage34_first60` | PASS |
| `stage34_tutorial_relay` | PASS（测试内补 pump；游戏逻辑不变） |
| `stage15_mischief` / `stage15_fail_flow` | PASS / exit 0 |
| `stage45/46/48/49/50` | PASS |
| `stage4_bilingual` | PASS |

## 未验证 / 已知

- **没有真人试玩**：以上是自动代理和探针，不证明手感/趣味；
- `stage13_tutorial_flow` 是窗口截图探针，headless 会卡在截图；本轮未跑；
- 准星、便便螺旋、乌龟囧脸、小头像目前只有代码和边界截图，未逐项截图验收；
- 美术、音频仍未接入；未导出、未打包、未部署。
