# FEEL-43 · Leader 可读性提示

- 基线：FEEL-42
- 范围：只改 leader 的提示文字/时机，不改鲨群攻击时序
- 未导出、未打包、未覆盖 Web/EXE；`best.json` MD5
  `067DEB9A71A19C2F6F9F6DC41FEABF09` 未变。

## 1. 改了什么

FEEL-42 发现：

- 预警后立即起跳、或 +0.20 s 起跳，都会太早而中招；
- +0.35 s 起跳才安全；
- 原有 HUD 只在预警时给“老大来了”类文字，玩家要靠猜“什么时候跳”。

FEEL-43 增加两段现有 feedback 通道提示：

1. leader 进入 `TELEGRAPH`：
   `老大要冲了——SHIFT 乌龟，准备跃起`
2. 预警后约 0.35 s：
   `现在——跃起！`

没有改：

- `PACK_LEAD_WARN=0.95`
- `PACK_WARN_FAT=0.95`
- `PACK_WARN_THIN=1.05`
- `PACK_SAFETY=0.70`
- leader/fat/thin 的攻击目标、hitbox、spawn 位置。

## 2. 真实输入验证

`stage42_shark_fairness` PASS 11/11：

- `leader_ready_cue` 捕获到：
  - `老大要冲了——SHIFT 乌龟，准备跃起`
  - `现在——跃起！`
- 正确操作 3/3 无命中；
- leader 0 / 0.20 s 早跳仍命中；
- leader 0.35 s 安全；
- wrong/late 5/5 命中。

原始数据：`docs/reports/longrun/feel42-shark-fairness.json`。

## 3. 回归

- `stage32_shark_timing` PASS：10/10 + Z3 时间轴，顺序/预警/安全间隔未变。
- `stage3_playtest` PASS：
  - 260.9 / 260.8 s
  - 55/55
  - 两圈 `leader/fat/thin` 三拍
  - 4 accidents/lap（来源不变：Z1 1、fat 1、thin 1、介入 1）
- `best.json` 未改。
- QA 指南已更新：[PRODUCER_QA_GUIDE.md](../PRODUCER_QA_GUIDE.md)。

## 4. 诚实限制

- 这只解决“什么时候按”的提示，不解决“玩家是否理解”；仍需真人验证。
- 自动跑仍 4 accidents/lap，因为自动代理不会按提示躲避；不能据此判断游戏不公平。
- 没有改鲨群难度，也没有降低攻击判定。
- Z1/Z2 的其余决策密度、双解氧气结构仍未改变。

## 5. 自评

- 可读性：比 FEEL-42 好一档；
- 公平性：未削弱，提示与正确时机对齐；
- 综合仍 **8.4/10**；这轮是修正一个具体可读性缺口，不是新增内容。

**STOP，等待真人确认“现在——跃起”是否足够清楚。**
