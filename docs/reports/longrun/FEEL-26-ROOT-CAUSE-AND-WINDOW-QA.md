# FEEL-26 · ROCK2 ROOT CAUSE & FULL WINDOW PLAYBACK

- 基线：FEEL-25-FULL-PLAY-EXPERIENCE-QA
- 模式：CONTROLLED_WRITE
- **未导出/打包/复制 EXE；best.json 未修改。**
- 不宣布游戏完成。

## 1. rock2 速度异常

### 现状日志

两圈自动驾驶都在 rock2 前得到：

```
JUMP x=5092 rock=5100-5240 y=334 spd=132 ctl=rabbit
WARN jump did not launch
ACCIDENT RABBIT_STUN
```

### 已确认

- rock2 的可见岩石与碰撞体没有发现分离。
- 起跳前龟速是 132，而该区基速是 220。
- 已排查 `turtle_controller` 的待命分支：旧“离开控制时间掉速/下沉”已移除，待命保持巡航速度和水深。
- 已尝试去掉 MISCHIEF 的直接 `speed *= 0.80`。
- **仍未定位到第一次 220→132 的完整调用链**；日志中没有对应的 `ACCIDENT`，速度下降不是 rock2 碰撞体直接造成的。

### 结论

P1 未解决。没有为了迎合自动驾驶改 rock2 碰撞、扩大容错或强制速度 220。两圈仍 55/55，但 rock2 擦碰存在。

## 2. Windows 输入链路

实际启动窗口，使用 Windows 键盘注入：

- 菜单 ENTER 进入。
- 漫画 ESC 推进。
- 教学进入，`STEP 1/4` 已消失，提示会随当前控制角色切换。
- 单独启动 `race.tscn` 窗口，HUD/角色/第一组障碍正常。

限制：窗口焦点/键盘注入不能稳定把教学完整跑到结算；曾出现输入发到非游戏窗口。没有伪造完整流程。

## 3. 完整流程

- 真实窗口：菜单→漫画→教学（部分）。
- 自动化：`stage4_flow` 菜单→比赛→结算 PASS。
- 真实窗口完整 55 组：**未完成**。
- 未用内部函数跳过流程冒充完整试玩。

## 4. 敌人/MISCHIEF

- 海鸟四种攻击恢复；`stage19_bird_behavior` 17/17；预兆 0.80 s；ACTION 不再同屏双鸟。
- 鲨鱼群 shark6 `stage21_shark_pack` 9/9。
- MISCHIEF 事件式；`stage15_mischief` 13/13；`stage22_coupling` 18/18。
- 真人识别/躲避体验未完成。

## 5. 回归

- 55 组 audit：四片全部 `no_solution=[]`
- `stage4_flow`、`stage4_bilingual`、`stage4_hud_layout`、`stage4_hud_score`（30/30）、`stage4_opening_pause`、`stage13_catch_matrix`、`stage15_oxygen_fail`（8/8）、`stage15_mischief`（13/13）、`stage19_bird_behavior`（17/17）、`stage21_shark_pack`（9/9）、`stage22_coupling`（18/18）通过。
- 两圈 55/55；每圈 2 次事故；rock2 擦碰。
- best.json MD5 未变。

## 6. 未解决

1. rock2 220→132 的第一次速度变化调用链未完成定位。
2. 窗口输入链路无法稳定完成教学→结算。
3. 完整 55 组真人试玩未完成。
4. 海鸟攻击体仍纸片；鲨鱼剪影占位。
5. 自动 SHOWTIME 保持关闭。

## 7. 自判

**不具备 Producer 最终验收条件。** 本轮确认了 rock2 不是碰撞体分离，而是起跳前速度异常；但根因未完全定位，未做掩盖式修改。

## 8. 停止

- 未导出、未打包、未复制 EXE。
- 未修改 best.json。
