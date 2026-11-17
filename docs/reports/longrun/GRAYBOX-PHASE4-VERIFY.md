# 灰盒 Phase 4 · 全量验证与测试债收口

- 基线：Phase 3（09471b4）
- 本轮未加新玩法；只收口验证、区域数据与旧测试。
- 未导出、未打包、未部署；`best.json` 未修改。

## 1. 区域数据修正

`stage3_selftest` 发现 `beam6` 在 `x=37953`，却被标为 `zone=3`（Z3 从39000开始），
属于“区域外障碍”。

处理：

- `beam6` 的 zone 改为 **2**（它实际位于 Z2 15000..39000）；
- 保留它作为 Z3 前的最后一拍，不移动关卡；
- Z2/Z3 分组变为 **12 / 20 / 23**；
- 重跑 `stage3_selftest`：`every group lies inside its declared zone` PASS。

没有改 Z3 起点，避免提前提速导致自动驾驶在 rock8 前落水。

## 2. 旧测试债

`stage3_selftest` 原本失败在：

- 旧三格 BRO METER；
- 主菜单旧 BEST 文案；
- 主菜单开始直接进 race（现在先走开场漫画）；
- 结算页旧指标（BRO COMBOS / RESCUE SAVES / CAPSIZES）。

已更新为当前机制：

- 失误 → 事故 + 7 秒抱怨窗口；
- 结算检查 RACE TIME / CLEAN PASSES / MISTAKES / BRO DIVE；
- 菜单开始走 `GameManager.start_race()`；
- 菜单只验证能加载，不再断言已移除的 BEST 行。

`stage3_selftest` 现在 **PASS**。

## 3. 全量回归

| 测试 | 结果 |
|---|---|
| `stage3_selftest` | PASS |
| `stage3_playtest` | PASS：run1 260.9s / run2 260.8s，55/55，5 accidents，max_stuck=0，grade B |
| `stage35_combo_audit` | PASS：10组双解 ×2 路线 |
| `stage32_shark_timing` | PASS |
| `stage21_shark_pack` | PASS |
| `stage42_shark_fairness` | PASS |
| `stage19_bird_behavior` | PASS |
| `stage13_catch_matrix` | PASS |
| `stage34_first60` | PASS |
| `stage34_tutorial_relay` | PASS |
| `stage31_arena` | PASS |
| `stage15_mischief` | PASS |
| `stage15_fail_flow` | PASS |
| `stage4_bilingual` | PASS |

## 4. 交付状态

- `best.json` MD5：`067DEB9A71A19C2F6F9F6DC41FEABF09`
- 未导出 EXE、未打包、未覆盖 Web、未部署
- 工作树提交后清空

## 5. 仍未完成

- 没有真人完整试玩；自动代理只能证明可运行/可计分，不证明有趣。
- Z1 仍约 60 秒；40 秒目标需要重排 Z2/Z3 全赛道。
- Z3 约 6 秒空档未压。
- 美术、音频仍未接入；Web 构建未在本轮重新导出。
