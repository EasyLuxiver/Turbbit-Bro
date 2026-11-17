# FEEL-46 · 救援接回、氧气两黄、海鸟两段

- 基线：FEEL-45
- 未导出、未打包、未覆盖 Web/EXE；`best.json` MD5 未变。

## 1. 乌龟 SPACE 接兔子接不上来（A）

根因不是“没触发”，而是三个叠加：

1. `_tick_bro_catch` 只在玩家**不按 ↑/↓** 时才把乌龟纵向目标设到兔子；
   玩家按住 ↓（最常见）时 `catch_target_y = -1`，乌龟只追 x，不追 y。
2. 纵向目标原来是 `rabbit.y + 12`；但 `can_rescue_catch` 的接人框是
   `rabbit.y - mount.y ∈ [-95, 40]`，而 `mount.y = turtle.y - 58`。
   目标只比兔子深 12 px 时，仍然接不到。现在改为约 **+70 px**。
3. 接住后到 carry 完成之间，兔子仍在水下累计氧气；最后一口气会在
   抬升途中耗尽。

修复：

- SPACE 追索期间同时追 x/y，按住 ↓ 也不会关掉纵向追索；
- 接住后清掉 `_catch_active`，不再让空格追索和 carry 抢方向；
- 接住瞬间补氧；
- `carry_kind == "rescue"` 期间暂停水下氧气扣除；
- 救援 carry 期间 `↓` 不再把乌龟压回水下，carry 把壳抬回巡航、兔子放回壳。

`stage13_catch_matrix` 新增 **deep_down**（按住 ↓）：PASS；全部 12 个 case PASS。

## 2. 氧气两黄

改为按剩余气泡数统一颜色：

- 3 颗：全绿；
- 2 颗：两颗都黄；
- 1 颗：红。

`stage35 oxygen_bubble_discrete` 验证：
- 满氧：fill=1.0 绿；
- 2.5：第三颗 fill=0.5；
- 1.8：第一颗和第二颗都是黄色；
- 0.8：最后一颗红色。

## 3. 海鸟两段

保留两段，**不做水弹**：

1. **第一段：俯冲穿越**
   - 海鸟不再在最低点停住；
   - 穿过玩家后继续向左飞，到玩家左侧；
   - 然后在高空盘旋。
2. **第二段：排泄**
   - 只在盘旋后发生；
   - 目标只有兔子；
   - 抛物线 + 落点圈 + 尾迹；
   - 命中兔子后有可见溅射（扩散圈 + 棕色水滴）。

生产序列改为 `["dive"]` 或 `["dive","poop"]` / `["dive","dive","poop"]`；
不再有 poop 先于 dive 的序列，没有水弹。

`stage19_bird_behavior`：
- 三只鸟 phases、attack spawned 通过；
- `poop_hit_rabbit` PASS；
- `poop_splash` splashes=1 PASS；
- seed/相邻序列 PASS。

## 4. 回归

| 测试 | 结果 |
|---|---|
| `stage13_catch_matrix` | PASS，含 deep_down 按住 ↓ |
| `stage19_bird_behavior` | PASS |
| `stage3_playtest` | PASS：260.7/260.6 s，55/55，3 accidents/lap |
| `stage35_combo_audit` | PASS：氧气两黄、救援横向吸附、rock3 7/8+8/8 |
| `stage4_water_rescue` | exit 0 |
| `stage34_first60` | PASS（BRO DIVE） |
| `stage42_shark_fairness` | PASS 基线 |
| `best.json` | MD5 未变 |

## 5. 仍然需要注意

- 排泄的“溅射”目前是**可见效果**，不额外对乌龟造成第二笔伤害；
  如果制作人要“溅射伤害乌龟”，需要再明确。
- 海鸟第一段仍有原来的本体碰撞带；本次是飞行动线和第二段，不是重写第一段判定。
- 自动跑 3 accidents/lap，仍不代表真人手感。
- 没有音效/正式美术。

**STOP，等制作人确认救援接回与海鸟两段。**
