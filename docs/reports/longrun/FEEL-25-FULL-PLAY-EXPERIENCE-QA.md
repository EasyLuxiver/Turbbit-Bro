# FEEL-25 FULL PLAY EXPERIENCE QA & REFINEMENT

- 基线：FEEL-24-GAMEPLAY-EXPERIENCE-REFINEMENT
- 模式：CONTROLLED_WRITE
- **未导出/打包/复制 EXE；best.json 未修改。**
- 不宣布游戏完成。

## 1. 真实窗口实际完成的流程

实际启动了 Godot 游戏窗口（1280×720），用 Windows 键盘注入操作：

- 菜单：ENTER 进入游戏。
- 漫画：ESC 推进/跳过。
- 教学：进入教学，确认 `STEP 1/4` 已消失，提示会按当前控制角色切换。
- 单独启动 `race.tscn` 窗口，确认正式比赛 HUD、角色和第一组障碍正常绘制。

证据：

- `docs/reports/longrun/feel22/tutorial-window.png`
- `docs/reports/longrun/feel22/hud-feel24.png`

**限制**：当前环境的窗口焦点/键盘注入不能稳定把教学完整跑到结算；我不能把它写成“完整真人试玩”。这部分没有伪造。

## 2. 通过模拟/自动化完成的检查

| 项目 | 结果 |
|---|---|
| 55 组 solution audit | 四片全部 `no_solution=[]` |
| 两圈自动驾驶 | 55/55；每圈 2 次事故；rock2 擦碰 |
| `stage4_flow` | PASS |
| `stage4_bilingual` | PASS |
| `stage4_hud_layout` | PASS |
| `stage4_hud_score` | 30/30 PASS |
| `stage4_opening_pause` | PASS |
| `stage13_tutorial_flow`（窗口化） | PASS |
| `stage13_catch_matrix` | PASS |
| `stage15_oxygen_fail` | 8/8 |
| `stage15_mischief` | 13/13 |
| `stage19_bird_behavior` | 17/17 |
| `stage21_shark_pack` | 9/9 |
| `stage22_coupling` | 18/18 |

这些只代表回归和模拟，不代表真人体验。

## 3. rock2 根因与处理

现状：两圈自动驾驶都在 rock2（x≈5100）发生 `RABBIT_STUN`。

日志：

```
JUMP x=5092 rock=5100-5240 y=334 spd=132 ctl=rabbit
WARN jump did not launch
ACCIDENT RABBIT_STUN
```

根因判断：

- rock2 的可见岩石与碰撞体没有发现分离；问题不是隐藏碰撞。
- 起跳前龟速只有 **132**，不是该区基速 220；自动驾驶按基速计算 lead，到了岩石前才起跳，导致起跳没发生/太晚。
- 速度下降来自此前状态/自动驾驶时序，不是 rock2 碰撞体单独造成。
- 已尝试去掉 MISCHIEF 的 `turtle.speed *= 0.80`，避免捣乱直接扣速；但两圈仍在 rock2 复现，说明还有别的速度/时序来源，**未解决**。

处理：本轮没有为迎合自动驾驶改 rock2 碰撞或加隐形宽容；记录为 P1 未解决。真人正常速度下是否可过仍需实际试玩。

## 4. 海鸟四种攻击

- 排泄、回马枪、追逐、普通俯冲已恢复。
- 预兆 `0.55 → 0.80 s`。
- ACTION 期间不再同时画本体和独立纸片鸟，避免双鸟。
- `stage19_bird_behavior` 17/17（预兆/动作/恢复、命中目标、电弧、30/60/120、种子可复现）。
- 截图：`docs/reports/longrun/feel19/bird-poop-telegraph.png`、`bird-poop-projectile.png`。

未完成：真人逐项躲避体验；攻击体仍是原生纸片风格，不是最终动画。

## 5. 鲨鱼群

- shark6 保持启用；队形/领头/跟随/单攻击体/救援清空/30-60-120 通过 `stage21_shark_pack` 9/9。
- 跟随鲨仍是原生剪影。
- 未做真人连续追击/脱离体验确认。

## 6. MISCHIEF 体验

- 已删除两个 0/3 HUD 和 3 格累计。
- 一次有效失误 → 2.6 秒抱怨窗口；未受控、安全窗口、冷却满足时才进入 MISCHIEF。
- 预兆 → 电击/拽绳 → 结束 → 冷却；SHIFT 到该角色立即制止。
- 不再直接扣龟速（FEEL-25 修复），避免捣乱把正常起跳变成必然擦碰。
- `stage15_mischief` 13/13；`stage22_coupling` 18/18。
- 未做真人“抱怨是否自然、捣乱是否烦人”的判断。

## 7. HUD/文本

- 右下角两个 0/3 已删除，面板不再创建。
- HUD 只留当前控制、角色状态、时间/区域/赛程、氧气、按键提示、短暂反馈。
- 结算删除兄弟配合计数行。
- 教学 `STEP 1/4` 移除；教学提示随控制角色切换。
- 海鸟/救援/暂停文本已同步。

证据：`hud-feel24.png`。

## 8. 未验证 / 仍存问题

1. **完整真人窗口流程未完成到结算**（环境焦点/键盘注入限制）。
2. **rock2 擦碰未解决**；根因是起跳前速度 132，不是可见碰撞体分离，但速度来源未完全定位。
3. 海鸟攻击体仍是纸片风格；真人躲避窗口未验证。
4. 鲨群只有 shark6，跟随剪影占位。
5. 自动 SHOWTIME 仍取消；正式比赛 show=0。
6. 未做长时间性能/内存剖析。
7. 旧测试 `stage8_hz`、`stage12_overdrive`、`stage17_mischief_readability` 测已删除的旧计数/旧神游/旧 HUD，不再适用。

## 9. 自判

**不具备 Producer 最终验收条件。**  
本轮完成了窗口启动/教学观察、HUD 清理、海鸟恢复、MISCHIEF 去计数、rock2 根因定位和部分速度修复；但完整真人流程、rock2 最终修复、海鸟真人体验仍未完成。

## 10. 停止

- 未导出、未打包、未复制 EXE。
- 未修改 best.json。
- 等待 Producer 决定下一轮。
