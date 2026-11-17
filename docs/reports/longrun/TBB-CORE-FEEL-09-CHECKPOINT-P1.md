# FEEL-09 CHECKPOINT P1 — Z2 室内码头身份对齐（00:00）

## 完成

- `LevelData.IDENTITY_BY_KIND_ZONE`：Z2 覆盖
  - LOW_BIRD → `cargo_net`（屋顶绞盘吊网）
  - SHARK → `canal_eel`（水渠鳗鱼）
  - DIVE_GATE → `sluice_gate`（木质船闸）
  - SURFACE_ROCK → `mooring_pontoon`（系泊浮台，备用）
- 画法：`race.gd` 新增 `_draw_cargo_net` / `_draw_canal_eel` / `_draw_sluice_gate` /
  `_draw_mooring_pontoon`；Z1/Z3 原画法不动。
- 教学：新增 `prompt.net/eel/sluice` 中英文案；课键按 `kind|identity`，
  Z2 新身份各教一次；撞后补教一次（沿用 G21 规格）。
- 区域名：`CORAL CHAOS / 珊瑚乱流` → `DOCK CHAOS / 码头乱流`。
- 运行时探针：`stage9_runtime_identity.gd`（加载真实 race）。
  - 55/55 组、Z2 19 组、点名 8/8 身份在码头集合、Z2 无珊瑚身份：6/6 PASS。
  - 最终复核：种子 20261112 / 12345 / 777 / 2026 / 1–10 共 13 个全部 PASS。
- 证据：`docs/reports/longrun/core-feel-09-p0a-runtime-identities.json`
- 截图（`TURBBIT/screenshots/`）：
  - `core-feel-09-z2_net_cruise/telegraph/dive/strike/recover.png`
  - `core-feel-09-z2_eel_telegraph/lunge.png`
  - `core-feel-09-z2_sluice_gate.png`

## 重要发现

9 个“食物锚点”组会按种子重抽 kind（`plan_snack_draws`）。因此
bird3/4/5、shark3/5、gate3/4/5 在默认种子下不一定还是海鸥/鲨鱼/礁拱
（例如 gate3 实际是 SHARK）。验收按“位置 + 运行时身份”判：8 个位置
8/8 都是码头身份，而不是按组名硬套旧 kind。

## 未完成 / 需注意

- `mooring_pontoon` 在默认种子没有出现（rock6 被重抽为 DIVE_GATE）。
  它只是静态岩落到 Z2 时的兜底身份，本轮没有实拍。
- `capture_z2` 依赖运行时身份查找；换种子也能截到对应身份。
