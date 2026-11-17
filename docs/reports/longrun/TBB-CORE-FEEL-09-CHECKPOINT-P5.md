# FEEL-09 CHECKPOINT P5 — ComfyUI 美术验证（01:05）

## 1. 场景润色（一处）

- 原图：`art_test/polish/source_world.png`（从 `screenshots/core-feel-09_dock_crate_crest.png`
  裁掉 HUD，保留码头/水渠/吊箱/乌龟+兔子）。
- 生成：Anima aestheticV11 + outlined LoRA，img2img：
  - `polished_d030.png`（denoise 0.30，最终选用：构图与水下吊箱判定提示保留）
  - `polished_d042.png`（denoise 0.42，细节更多但改动更大）
- 对照：`compare_polish.png`
- 工作流：`polish/workflow_d030.json`、`workflow_d042.json`
- 结论：可以作为“画风润色方向”的参考，但**没有接进游戏**，原始场景与碰撞完全未改。

## 2. TUBO 拆件原型

- 完整参考：`art_test/tubo/source_ref.png`（Anima t2i，seed 20261115；另存 alt 20261114）
- 游戏内参考：`art_test/tubo/in_game_ref.png`
- 拆件：9 个透明 PNG（`parts/`）：
  - rear_far / rear_near / front_upper / front_tip / neck / carapace / rim /
    shoulder / head
- 组装参考：`assembly_rest.png`；pivot 图：`pivot_map.png`；
  总览：`parts_contact_sheet.png`
- pivot 坐标：`pivots.json`（源图坐标 + 局部坐标 + bbox + draw order）
- 遮挡顺序：rear_far → rear_near → neck → carapace → rim → front_upper →
  front_tip → shoulder → head
- 切件方法：手工多边形 + 4 px 扩边 + 边框白色洪泛透明；不是 AI 分割。
- 工作流：`tubo/workflow_t2i.json`

## 3. Godot 动画验证

- 场景：`scenes/tubo_cutout_test.tscn`
- 脚本：`scripts/test/tubo_cutout_test.gd`
- 左右对比：
  - A：前鳍单段（隐藏 front_tip），头/颈同相。
  - B：前鳍两段 + 颈部分层 + 鳍尖延迟。
- Idle / Cruise / Jump 各 3 s，循环；Jump 有 110 px 抬升。
- 预览：`art_test/tubo/tubo_cutout_preview.gif`（15 fps，9 s，约 4 MB）
- 状态图：`tubo_states.png`

## 4. v2 多件对照（P5 追加）

- `art_test/tubo_v2/tubo_v2_preview.gif` / `tubo_v2_states.png`：
  A v1 9 件单段 vs B v2 10 件**平涂**（anima-base-v1.0，无风格 LoRA）+
  颈→头层级 + 眨眼。
- `parts_v2/` + `pivots_v2.json` 可复现 B；`game_size_compare.png` 是两者
  缩到 100 px 的游戏尺寸对照。
- 结论：平涂 + 固定颈窝/肩窝后，B 在游戏尺寸下比 v1 干净；但前鳍仍是单段
  刚性件，Jump 是整体变换，**仍未达到正式资产精致度**。

## 诚实结论（待 Producer 判断）

- 流畅度：9 件 + 两段前鳍 + 肩部固定窝，Idle/Cruise 已能连续读；
  但前鳍中段仍能看到切缝，Jump 的形变只有整体抬升 + 后仰，不是逐帧动画。
- 精致度：**未达到正式资产**。2D 拆件能做到“活、可读”，但要达到“精致”，
  还需要：补画被遮挡区域、前鳍三段、头/颈两级骨骼、眼睑/眨眼、
  以及 2–3 套关键姿态的手工修型。
- 因此本轮给的是“表达力上限样片”，不是可替换正式 TUBO 的资产。
