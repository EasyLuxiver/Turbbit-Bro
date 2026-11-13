# G13 — 事故截图必须真的拍到事故（`--capture-accident` 取证修复）

日期：2026-11-13（05:52 起）
改动：`scripts/race.gd`（`_capture_accident()`：传送点 1290→1400，等待方式改成“等真的出事”）
截图：`screenshots/rebuild05-accident.png`、`rebuild05-accident-b.png`（两次独立运行）

## 为什么做这一条

G11 之后按“出图先自己打开看”的规矩把剩下的反馈面挨个拍了一遍。`--capture-accident`
拍出来的图里**没有事故**：鸟在飞、兔子还在骑、HUD 干净——文件名写着 accident。

根因和 G11 同类，这次是关卡挪位把工具落下了：P1-4 把 bird1 从旧位置挪到
**x=1560**，而 `_capture_accident()` 还是“传送到 1290，等 0.4 s”。
0.4 s 只走 88 px（220 px/s），兔子停在 1378，离鸟还有 180 px，根本没撞上。

## 做了什么

```gdscript
turtle.position = Vector2(1400.0, surface_ref())   # 鸟前 160 px
var frames := 0
while GameManager.accident_state == "NONE" and frames < 180:
	await get_tree().physics_frame
	frames += 1
await get_tree().create_timer(0.15).timeout
_save_shot(...)
```

等的是**真实事故状态**，不是拍脑袋的固定延时；3 s 兜底防止永远等下去。
**判定路径一行没改**：撞鸟 → `_trigger_accident` → BRO METER 的链路原样不动。

## 证据

两张图都是窗口化实跑（不是 headless 截帧），文件名带 `-b` 的是第二次独立运行：

| 验收点 | 读数 |
|---|---|
| 横幅拍到事故 | 两张都是 `咚！兔子被撞晕`（00:01.2、进度 2%） |
| 不是偶然 | 两次运行内容一致（md5 不同只来自水花/粒子帧间随机） |
| 事故进了记账 | 两张 BRO METER 都是 **1/3**，左上 `兔子 操控·眩晕` + `兔子晃动 89%` |
| 判定没被工具影响 | 事故是真实碰撞触发；截图工具只是“等它发生” |

## 回归

- 两圈 `fullrun-g13.log`：run1 272.9 s / run2 272.8 s、9770、S、55/55、0 事故、
  `STAGE3 PLAYTEST: PASS`，FINISH/总结行与 `fullrun-g12.log` 逐字相同。
- 21 场景批量：与 G14 共跑（两处改动都只在截图钩子里，正常跑不到），
  `reg-g14-*.log` 全部 exit=0，0 条失败行、0 条 SCRIPT ERROR。
- `best.json`：批量退出后 md5 `c322f9a20321c5b618f98db7e4120969`，内容仍是
  283.961389454381 / 3150 / 54 / 0。跑的过程中它会短暂出现测试成绩，退出后才算数。

## 已知限制

- 这是取证工具修复，**不改变玩家看到的事故反馈**；事故文案/晃动条本身没有重新评价。
- `docs/reports/STAGE-1.md`、`STAGE-2.md` 引用的 `stage1_accident.png`、
  `stage2_accident.png` 是历史截图，未重新生成，也没有被本轮当作证据。
