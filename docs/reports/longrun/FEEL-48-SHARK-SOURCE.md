# FEEL-48 · 鲨群三鲨同源收口

- 基线：FEEL-47
- 未导出、未打包、未覆盖 Web/EXE；`best.json` 已恢复基线。

## 1. 本次改动

### 胖/瘦攻击从可见鲨鱼发出

队形固定：

- leader：`bx + 230`
- fat：`bx + 60`
- thin：`bx - 110`

`_spawn_shark_follower` 的 `x0` 不再从“目标前 220 px”硬编码，而是从对应
队形成员当前 x 出发；然后 0.28 s 滑到攻击点。

绘制队形时，如果 fat/thin 正在攻击，就不再画它的静止剪影；由攻击体
承担这一条鲨鱼。预警线、目标圈和攻击体使用同一来源。

### Z3 入场

- 只在 Z3 绘制三鲨；
- 进入距离内给一次“鲨鱼群围上来了”；
- 保留 leader → fat → thin、0.95/0.95/1.05、0.70 安全间隔。

## 2. 验证

- `stage42_shark_fairness` PASS
- `stage32_shark_timing` PASS
- `stage21_shark_pack` exit 0
- `stage31_arena` PASS
- `stage3_playtest` PASS：261.1/261.1 s，55/55，5 accidents/lap，无普通障碍 contact，无卡死
- `best.json` MD5 `067DEB9A71A19C2F6F9F6DC41FEABF09`

## 3. 仍不是永久三 actor

当前仍是：

- `shark6` 一个真实障碍组；
- leader 走 `_ambush`；
- fat/thin 是 `_shark_attacks` 临时攻击体。

本轮已经让它们从对应可见鲨鱼位置出发、预警线同源、队形隐藏攻击者；
但 fat/thin 在窗口外仍不是三只持久碰撞 actor。

## 4. 自检结论

可读性比上一版好：不会从玩家背后凭空刷出，队形与攻击来源对得上。
仍保留 5 accidents/lap（自动驾驶不躲新排泄/鲨群），不是真人结论。

**STOP，等待制作人复看这版鲨群来源。**
