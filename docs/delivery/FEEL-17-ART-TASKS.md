# FEEL-17 美术任务清单（可直接派单）

> 当前正式比赛仍是原生图形占位；本清单是缺口，不代表已完成。
> 统一：透明 PNG RGBA、不要预乘 alpha、2–4 px 安全边；同角色同画布比例；pivot 用 JSON；命名 `角色_部件_状态_vNN.png`。

## 状态图例

`未开始` / `候选` / `已接入` / `已验证`。本文件全部是 **未开始**，除了 `art_test/feel13` 的拆件技术样（候选，不接入）。

## A. 角色（P0）

| ID | 交付物 | 用途/状态 | 规格 | 接入位置 | 验收 |
|---|---|---|---|---|---|
| ART-01 | TUBO 头+脸、双耳、躯干、双臂、双腿、尾巴 | RIDING/CROUCH/JUMP/FALLING/WATER/SHOWTIME/SHOCK/TUG | 透明，同画布；pivot 表；100 px 下可读 | `race.gd` `_draw_rabbit` 替换为 Sprite/骨骼 | 9 状态截图；部件可独立旋转 |
| ART-02 | BITT 壳、头颈、四鳍、尾、表情 | CRUISE/DIVE/LEAP/RESCUE/CARRY/OVERDRIVE/TUG | 同上；壳/鳍 pivot | `_draw_turtle` | 6 状态截图；鳍可摆动 |
| ART-03 | 大表哥 idle/point/potion | 开场、教学、终点 | 透明；potion 独立 | `opening_comic.gd`/`tutorial.gd`/`result.gd` | 终点截图；解药在手中 |
| ART-04 | 角色受击/落水/救援表情层 | 事故反馈 | 透明叠层，可换色 | 角色状态绘制 | 与事故状态同帧 |

## B. 场景（P1）

| ID | 交付物 | 用途 | 规格 | 接入 |
|---|---|---|---|---|
| ART-05 | Z1 阳光海岸背景 | 正式比赛 Z1 | 可平铺/分层，1920 宽 | `race.gd` `_draw` / `zone2_layer` |
| ART-06 | Z2 室内木质码头 | Z2 | 分层前景/中景/背景 | `zone2_dock.gd` |
| ART-07 | Z3 外海肌肉混乱 | Z3 | 高对比，不抢障碍 | `race.gd` |
| ART-08 | 终点海岸舞台 | result | 明亮、木台、彩旗、cousin 位 | `result.gd` `_draw` |
| ART-09 | 失败深水画面 | fail | 深水、气泡、下沉 TUBO | `fail.gd` `_draw` |

## C. 障碍正式外观（P1）

每个障碍必须保持现有判定矩形和身份语义；只换画法。

| ID | 身份/类型 | 现有语义 | 规格 | 接入 |
|---|---|---|---|---|
| ART-10 | buoy 红白浮标 | SURFACE_ROCK 动态；TUBO 跳/BITT 接触减速 | 红白桶+锚绳+灯；透明/分层 | `_draw_buoy` |
| ART-11 | dock_crate 木质吊箱 | Z2 动态；TUBO 跳/BITT 接触 | 木箱+吊索+滑轮 | `_draw_dock_crate` |
| ART-12 | drift_crate 漂流货箱 | Z3 动态 | 木箱+浪花 | `_draw_drift_crate` |
| ART-13 | 浮木/高墙/闸门/低梁/海鸟/鲨鱼 | 现有 55 组 | 与判定框一致；不得改变轮廓 | 对应 `_draw_*` |
| ART-14 | 食物/加速带/终点线 | 环境提示 | 小、清楚、不与 HUD 抢 | `race.gd` |

## D. UI / 菜单 / 结算（P1）

| ID | 交付物 | 用途 | 规格 | 接入 |
|---|---|---|---|---|
| ART-15 | HUD 图标集 | 角色、氧气、BRO METER、COMBO、SHIFT | SVG/PNG，单色可 tint | `hud.gd` |
| ART-16 | 主菜单/设置/退出视觉 | 菜单 | 1920/1600 适配，三按钮 | `menu.gd` |
| ART-17 | 开场 7 格插画 | story | 每格 16:9/安全边；不依赖文字 | `opening_comic.gd` |
| ART-18 | 教学 4 步图示 | tutorial | 小图+文字位 | `tutorial.gd` |
| ART-19 | 结算/失败插画 | result/fail | 明亮/深水两套 | `result.gd`/`fail.gd` |

## E. 动画交付格式

- 2D 骨骼/拆件：PNG 序列或 Spine/DragonBones 导出；Godot 侧优先 `Skeleton2D` + `Bone2D` 或 `AnimationPlayer`。
- 每个 clip 必须写：名称、帧率、循环、事件帧（脚步/落地/电击）。
- 19 个状态映射见 `FEEL-16-ART-AUDIO-INTEGRATION.md`；不得只交“idle 一张图”。
- 验收：在 100 px 游戏尺寸、1920×1080、全屏三种情况下可读；与碰撞/救援/氧气反馈同帧。

## F. OS 接入职责

1. 新素材放入 `assets/char|env|ui`，不覆盖旧素材，保留版本号。
2. 先在独立 `art_preview` 场景验证 pivot/透明/遮挡，再替换正式 `race.gd` 绘制。
3. 每个替换必须跑两圈 55/55、救援矩阵、MISCHIEF、失败/结算、30/60/120、1920/全屏。
4. 未通过前标“候选”，不得标“已接入/已验证”。
