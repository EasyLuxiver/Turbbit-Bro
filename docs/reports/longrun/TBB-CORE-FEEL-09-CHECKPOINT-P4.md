# FEEL-09 CHECKPOINT P4 — 教学与 menu_input（00:20）

## 教学

- 开场只留：标题 / 副标题 / READY / `↑ 跳 ↓ 趴低` / 任意键跳过。
  不再同时出现三行长文；食物说明移出开场。
- HUD 新增按键图标行（SHIFT / ↑ / ↓），按当前提示文案高亮；提示超过
  40 字才在语义分隔处断成最多两行。
- SHIFT/浮木/高墙/Z2 新身份提示保持 5 s，保证从 1100 px 外触发后留到障碍前。
- 通用提示改成“为什么 + 按什么”：
  - 礁拱：只有乌龟潜得过去 → SHIFT + ↓ 按住下潜
  - 鲨鱼：从水下冲上来 → SHIFT + ↑ 乌龟跃起
  - 浮木：上下都挡 → ↑ 跳 → SHIFT → ↓ 潜
  - 高墙：翻不过去 → SHIFT + ↑ 跃起 → SHIFT → ↑ 蹬踏
- 暂停页常驻“操作说明”（SHIFT/↑/↓、五类障碍、浮木/高墙、食物），
  随时可重看；三个菜单按钮不变。
- 撞后补教沿用“一次”（G21 规格）。
- 食物提示拆成两行，规则与实际一致（乌龟加速 / 兔子下一跳更高 / 不吃不扣）。

## menu_input

- **窗口化运行：PASS**（全部鼠标 hover/click 用例通过）。
- headless 同环境对比：
  - 基线：27 ok / 16 fail
  - 本轮：28 ok / 15 fail
- 唯一差异：`pause min font` 从 17（FAIL）提到 18（PASS）；其余 15 条
  FAIL 与基线逐条相同，均为 headless 下鼠标 hover/click 不可用导致。
- 没有跳过测试、没有降低断言。

## 最终复核（07:30）

- `stage9_tutorial_timeline` 7/7 PASS：趴低 @x462、第一次 SHIFT @x2703、
  第一次连招 @x5321；Z2 吊网/鳗鱼/船闸文案都出现；提示 ≤2 行。
- `stage4_opening_pause` 通过“显式挂开场”改为 **PASS**；`stage5_f_lessons`、
  `stage5_g21_relesson`、`stage5_g10_lesson_order` 均 PASS。
- 1280×720 暂停/结算完整：`screenshots/core-feel-09-pause-1280.png`、
  `core-feel-09-result-1280.png`。

## 证据 / 截图

- `TURBBIT/screenshots/core-feel-09-opening.png`
- `TURBBIT/screenshots/core-feel-09-pause.png`
- `TURBBIT/screenshots/core-feel-09-lesson-gate1.png`
- `TURBBIT/screenshots/core-feel-09-hud-prompt.png`
- 全文：`D:\GAMESTUDIO\_menu_cur2.txt`、`D:\GAMESTUDIO\_menu_base.txt`

## 未完成

- 无（headless 的 opening/pause 旧失败已通过测试显式挂开场解决）。
