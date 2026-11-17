# FEEL-24 GAMEPLAY EXPERIENCE REFINEMENT · 玩法体验重设计与第二轮质检

- 基线：`FEEL-23-FULL-GAME-QA-ROUND1`
- 模式：CONTROLLED_WRITE
- **未导出/打包/复制 EXE；best.json 未修改。**
- 不宣布游戏完成或内容冻结。

## 1. 结论

按 Producer 决定，删除了右下角两个 0/3 及关联的常驻计数逻辑：

- `捣乱压力 0/3` 不再存在。
- `兄弟配合 0/3` 不再存在。
- HUD 右下角不再创建任何计数面板。
- 自动“连续 3 组干净通过 → SHOWTIME”已取消；`start_showtime()` 只保留给显式演出/测试，不再由比赛自动触发。
- MISCHIEF 改为一次失误 → 一次抱怨/预兆事件，不再有 3 格压力或隐藏累计。

## 2. MISCHIEF 最终机制

1. 一次有效失误给该角色生成一个 **2.6 秒抱怨窗口**。
2. 角色通过文字/行为嘟囔，不修改输入。
3. 如果该角色**未受控**、不在救援/演出中、附近没有 700 px 内的障碍，且冷却结束，就进入 MISCHIEF：
   - TELEGRAPH 预兆；
   - ACTION：BITT 电 TUBO，TUBO 拽绳让 BITT 减速；
   - END 后冷却。
4. 玩家 SHIFT 到该角色，立即制止并清空抱怨。
5. 没有 3 格计数、没有随机概率、没有自动跳/潜。
6. 捣乱动作不会直接造成碰撞/落水/失败；附近有障碍时不启动。
7. 同一时间只允许一个 MISCHIEF。

## 3. SHOWTIME 最终机制

- 删除“3 组干净通过自动积累 → 自动 SHOWTIME”。
- `combo` 不再在 HUD 显示，也不再自动触发 `start_showtime()`。
- `start_showtime()` 和现有表现/奖励代码保留，但只作为显式演出/测试入口；正式比赛当前不会自动开演。
- 这是按任务书“宁可暂时取消自动 SHOWTIME，也不强行制造无意义进度条”的暂缓决定。

## 4. HUD 修改前后

| 修改前 | 修改后 |
|---|---|
| 右下角 `TUBO 捣乱压力 0/3` | 删除 |
| 右下角 `兄弟配合 0/3` | 删除 |
| 右下角三段/三格条 | 删除 |
| 右下角面板常驻 | 不创建 |

修改前证据：`docs/reports/longrun/feel22/hud-unified-zh.png`  
修改后证据：`docs/reports/longrun/feel22/hud-feel24.png`

HUD 现在只保留：当前控制、两个角色状态、时间/区域/赛程、氧气气泡、按键提示、短暂反馈。

## 5. 海鸟 / 鲨鱼群

- 海鸟特殊攻击恢复：排泄、回马枪、追逐、普通俯冲。
- 预兆 `0.55 → 0.80 s`。
- ACTION 期间不再同时画本体和独立纸片鸟；只画攻击体，避免双鸟。
- `stage19_bird_behavior` 17/17。
- shark6 鲨群保留，`stage21_shark_pack` 9/9。
- 救援/落水时鸟/鲨攻击清理保持。

## 6. 全流程与回归

| 项目 | 结果 |
|---|---|
| `stage4_flow`（菜单→比赛→结算） | PASS |
| `stage4_bilingual` | PASS |
| `stage4_hud_layout` | PASS |
| `stage4_hud_score` | 30/30 PASS（已删除旧计数检查） |
| `stage4_opening_pause` | PASS |
| `stage13_tutorial_flow`（窗口化） | PASS |
| `stage13_catch_matrix` | PASS |
| `stage15_oxygen_fail` | 8/8 |
| `stage15_mischief` | 13/13 |
| `stage19_bird_behavior` | 17/17 |
| `stage21_shark_pack` | 9/9 |
| `stage22_coupling` | 18/18 |
| 55 组 solution audit | 四片全部 `no_solution=[]` |
| 两圈自动驾驶 | 55/55；每圈 2 次事故；rock2 擦碰；show=0 |

## 7. 未解决 / 风险

- 没有完整人手试玩到结算；窗口化教学和引擎两圈已完成，但仍需 Producer 手测。
- 自动驾驶在 rock2 有擦碰，且 bird 恢复后每圈 2 次事故；不能当真人难度。
- 海鸟攻击体仍是原生纸片风格，已避免双鸟/脱节但非最终动画。
- 鲨群只有 shark6，跟随剪影仍是占位。
- 自动 SHOWTIME 已取消，当前正式比赛不会触发 SHOWTIME；这是暂缓，不是完成。
- 未做长时间性能/内存剖析。
- `stage8_hz` / `stage12_overdrive` / `stage17_mischief_readability` 测旧计数/旧神游/旧 HUD，已不适用。

## 8. 自判

**还不具备 Producer 最终验收条件。**  
本轮完成了 Producer 明确要求的两个 0/3 删除、MISCHIEF 去计数化、自动 SHOWTIME 取消、HUD 清理、海鸟恢复和主要回归；但完整真人体验、攻击体最终表现、rock2 自动驾驶擦碰仍未解决。

## 9. 证据文件

- HUD 前后：`hud-unified-zh.png` / `hud-feel24.png`
- 海鸟：`docs/reports/longrun/feel19/bird-poop-telegraph.png`
- 动态障碍：`dynamic-buoy-dip.png`、`dynamic-dock-crate.png`、`dynamic-drift-crate.png`
- 测试 JSON：`docs/reports/longrun/` 下对应文件

## 10. 停止

- 未导出、未打包、未复制 EXE。
- 未修改 best.json。
- 等待 Producer 试玩；不宣布完成或内容冻结。
