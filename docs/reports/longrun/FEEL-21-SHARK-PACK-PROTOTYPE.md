# FEEL-21 鲨鱼群单组试接入与水下遭遇验证

- 日期：2026-11-15
- 阶段：`STAGE=4`
- 模式：CONTROLLED_WRITE
- **未导出测试包/候选包/EXE，未执行 Godot Export，未复制 EXE。**
- 结论：只把 **shark6** 一组接入最小鲨鱼群；领头沿用现有 `_ambush`，两条跟随只在各自窗口形成单个攻击体。其他鲨鱼组保持原样。

## 1. 选组与位置

选择 **`shark6`**（Z3，`x=40245`，w=70，`ambush_shark`）。

为什么选它：

- 不是食物锚点（Z3 锚点是 shark8/beam8/shark9/gate8），不会改变食物抽签。
- 前一拍是 `beam6`（x=39200，TUBO），后一拍是 `rock8`（x=41425，TUBO）；这里有足够的水下空间放两条跟随的队形，不必新增组或扩赛道。
- 仍然只要求 BITT 跃起处理领头；跟随攻击是为了制造水下连续压力，不是新增解法。

前后窗口：

| 组 | x | 玩法 |
|---|---|---|
| gate5 | 37630 | BITT 下潜 |
| beam6 | 39200 | TUBO 趴低 |
| **shark6** | **40245** | **BITT 跃起 → 跟随 1/2** |
| rock8 | 41425 | TUBO 跳（动态漂箱） |

## 2. 修改前 / 修改后

### 修改前

- `shark6` 只有一条 `_ambush` 鲨：TELEGRAPH → LUNGE → RETREAT → DOWN，单身体矩形。
- 其他鲨鱼组相同；视觉上只有一条鱼，没有队形/错峰。

### 修改后（只 shark6）

新增 `_shark_pack["shark6"]` 状态：

```
CIRCLE
  → LEAD_LUNGE（跟随领头进入 LUNGE，不另造身体）
  → GAP 0.45 s（跟随预警）
  → FOLLOWER_1（攻击体 A，target=BITT）
  → FOLLOWER_2（攻击体 B，target=TUBO，若 TUBO 还骑着）
  → RETREAT 0.60 s
  → DONE
```

- **领头**仍由 `_ambush` 负责 TELEGRAPH/LUNGE/RETREAT 和主碰撞矩形；没有复制三份领头。
- **两条跟随**：
  - 只在 `FOLLOWER_1/2` 的 0.52 s 生存期内有 `Rect2(x-35,288,70,176)` 或 `Rect2(x-35,228,70,86)` 判定；
  - 窗口外只画队形/剪影，没有碰撞；
  - 同一时间最多 1 个攻击体（`_shark_attacks` 只在空时 spawn）；
  - 跟随 1 先 0.45 s 预警，跟随 2 在跟随 1 后 ≥0.55 s；不会同时攻击。
- 跟随 1 目标为 BITT；跟随 2 在 TUBO 仍骑乘时目标 TUBO，否则仍 BITT。目标在 spawn 时锁定，SHIFT 后不换目标。
- 领头与跟随的动作不同：领头用原身体矩形+原 `_draw`；跟随是低位/水面剪影，不复制同一身体。
- 玩家仍用现有 ↑/↓/SHIFT/SPACE 处理；没有新增按键或资源条。

## 3. 正式赛道接入

- `load_level()` → `_init_shark_pack()`：只对 group==`shark6` 建状态。
- `_physics_process()` → `_tick_shark_pack(delta)` → `_check_shark_attacks(delta)`；在正式 race 中每帧调用。
- `_draw_shark_pack_fx()`：画两条队形剪影和当前攻击体；无独立场景/脚本。
- 其他 7 组鲨鱼（shark1/shark3/shark5/shark8/shark9 + 食物抽签变出的鲨鱼）没有 pack 状态，保持原单鲨鱼行为。

## 4. 救援优先级 / 状态清理

- `_tick_shark_pack` 开头检查 `_rescue_context() != "NONE"` 或 `rabbit.state` 为 `FALLING_WATER/PASSED_OUT`：
  - 立即 `phase=DONE`；
  - `_shark_attacks.clear()`；
  - 不生成跟随攻击、不保留幽灵矩形。
- `_check_shark_attacks` 同样在救援/落水时清空，不产生第二次惩罚。
- `SPACE` 主动救援/自动回壳/氧气失败路径未改；鲨鱼攻击不阻断救援。
- 玩家越过组尾 +340 px 时收队，清空攻击体。
- 攻击体 `life` 结束自动移除；命中即移除。
- 鲨鱼攻击不修改 MISCHIEF、OVERDRIVE、SHOWTIME 状态。

## 5. 专项测试

`stage21_shark_pack` **9/9**：

- 领头 LUNGE → GAP → FOLLOWER_1；
- 任意时刻 `_shark_attacks.size() <= 1`；
- 跟随 1 命中 BITT（flip 1.5，速度 132）；
- 跟随 2 在 TUBO 骑乘时目标 TUBO，且错峰生成；
- SHIFT 后目标仍锁定在生成时的角色；
- TUBO 落水时 pack 立即 DONE、攻击清空；
- 30/60/120 Hz 的跟随首击在 1.72–1.77 s（同一量级）。

实际画面：

- `docs/reports/longrun/feel21/shark-pack-follower1.png`
- `docs/reports/longrun/feel21/shark-pack-follower2.png`

（跟随鲨鱼/攻击体仍是原生剪影，不是最终美术。）

## 6. 全量回归

- 两圈正式跑圈：**55/55、0 失败、每圈 1 次事故**（鸟/鲨鱼攻击未被自动驾驶适配，不能作为真人难度结论）。
- 全量 55 组 solution audit：四个 shard（0–13/14–27/28–41/42–54）全部 **AUDIT no_solution=[]**，覆盖 55 组；shark6 单组也单独通过。
- 鸟行为 17/17；P0 HUD/SPACE 6/6；MISCHIEF 13/13；救援 11/11；氧气/失败 9/9；OVERDRIVE 15/15；HUD 41 checks；30/60/120 PASS。
- `best.json` 未读写，保持原样；交付时复核 MD5。

## 7. 未完成 / 风险

- 只有 shark6 一组；其他鲨鱼保持原样。
- 跟随鲨鱼是原生剪影，需正式美术。
- 自动驾驶未适配跟随攻击，每圈 1 次事故；真人预兆/窗口仍需试玩。
- 跟随 2 目标 TUBO 是从“TUBO 仍骑乘”条件选出的，若 TUBO 在水里则回到 BITT；这避免救援中额外惩罚，但需要真人确认读得懂。
- 全量 audit 若因 shark6 出现 no_solution，立即回退本组，不扩展到其他鲨鱼。
- 本批不处理 G39–G41、G31–G35、温泉、水草、Boss。

## 8. 停止

- 未导出、未打包、未复制 EXE。
- 本批只接入 shark6 一组，完成后停止，等待制作人审核。
- **不宣布内容冻结，不宣布游戏完成。**
