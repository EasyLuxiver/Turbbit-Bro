# FEEL-44 · 角色反馈、氧气、鲨群与 BRO DIVE 卡脚

- 基线：FEEL-43
- 范围：表现/反馈 + BRO DIVE 卡脚的最小机制修复
- 未导出、未打包、未覆盖 Web/EXE；`best.json` MD5
  `067DEB9A71A19C2F6F9F6DC41FEABF09` 未变。

## 1. 氧气三气泡

旧画法：三颗气泡整体换色，满氧→黄→红一起变，读不出“还剩几口气”。

现在：

- 满氧：三颗绿；
- 第三颗随剩余量**淡出**；
- 剩两颗：中间变黄；
- 只剩一颗：最后一颗变红。

纯逻辑审计在 `stage35`：
`full fill=1.0 / 2.5 third fill=.5 / 1.8 middle yellow / 0.8 last red`。

## 2. MISCHIEF 画面

旧画法只有 `!` 和一行字，实际动作几乎看不到。

现在：

- TELEGRAPH 阶段画 culprit 到另一角色的虚线/预兆；
- ACTION 阶段画**抖动电击折线** + 两端电环 + 被电者头顶 `!`；
- 乌龟电兔子、兔子电乌龟、空中兔子被电，分别走不同端点；
- 持续时间从 0.35 s 提到 0.65 s。

截图：`_attic/2026-11-14/feel15-mischief-frames/shock_014.png`
（中心文字“乌龟电了兔子一下”，黄色电击线可见）。

## 3. 乌龟朝向

新增 `_turtle_facing` / `_update_turtle_facing`：

- 乌龟向左移动（救援、被顶回）时，头和眼睛转向左；
- 向右巡航时转回右；
- 尾巴/尾鳍画在头的反方向；
- 只改画法，不改位置、碰撞、控制。

`stage35` 审计：`left=-1.0 right=1.0`。

## 4. 鲨群小弟

### 不再闪现

Fat/Thin 原来直接在玩家面前生成。现在：

- 先出现在玩家后方约 220 px；
- 在 0.28 s 内滑到攻击点；
- 绘制和判定共用同一个移动矩形；
- 预警/命中时序不变。

### 鲨鱼轮廓

`_draw_pack_shark` 重画：

- 尖吻在右、尾鳍在左；
- 背鳍、胸鳍、白肚皮、鳃裂、嘴线；
- 胖鲨有更大的腹部；
- 看台和跟随机队使用同一套鲨鱼轮廓，不再像虾米。

`stage42` 真实输入测试仍 10/10，`stage32` 时序 PASS。

## 5. 兔子落水后的独立性

- `rescue_suction_offset` 只保留横向吸附，返回的纵向分量固定为 0；
- 兔子落水后自己的下沉/漂浮不再被乌龟的上浮/下潜拖着走；
- 要接住仍必须把乌龟潜到兔子附近；`stage35`
  `rescue_suction_horizontal_only` 通过；
- `stage4_water_rescue` 的 water 捕获仍为 caught（0.38–1.73 s 窗口）。

## 6. 高墙 / 浮木视觉与 BRO DIVE

- 高墙：灰色石块 + 墙齿 + 砌缝 + 靠近时“跃墙/OLLIE”字；
- 浮木：棕色木段 + 水下亮边；
- 乌龟下潜过不了高墙是设计（墙身封住深潜），正确解法是 BRO OLLIE；
- 高墙不再和浮木看起来像同一种棕色木块。

### 6.1 BRO DIVE 卡脚

新增最小机制修复：

- 仅当 `kind == FLOATING_LOG`、当前控乌龟、乌龟在下潜、且 `group_actions` 已记录兔子跳过时，
  放行兔子侧的擦边碰撞；
- 兔子只跳/只潜仍失败；
- 不改变浮木主碰撞、乌龟碰撞、通过/连击判定。

`stage34_first60` PASS：

- rabbit_only = false；
- turtle_only = false；
- bro_dive = true。

## 7. 回归

| 测试 | 结果 |
|---|---|
| `stage34_first60` | PASS：BRO DIVE 通过，单角色仍失败 |
| `stage3_playtest` | PASS：260.9/260.8 s，55/55，4 accidents/lap，无普通障碍 contact |
| `stage42_shark_fairness` | PASS：10/10，三拍/延迟/错误角色 |
| `stage32_shark_timing` | PASS |
| `stage21_shark_pack` / `stage31_arena` | exit 0 / PASS |
| `stage15_dynamic_buoy` | exit 0 |
| `stage35_combo_audit` | PASS：双解、rock3 7/8+8/8、氧气离散、乌龟朝向 |
| `stage4_collision_feedback` | PASS |
| `stage4_water_rescue` | exit 0：water 捕获仍为 caught |
| `best.json` | MD5 未变 |

## 8. 仍然存在的问题

- 自动跑仍是 **4 accidents/lap**，因为测试代理不会按三拍提示躲避；这是测试代理限制，
  不等于真人不可躲。
- 高墙的“跃墙/OLLIE”字是灰盒提示；没有正式美术和音效。
- 氧气只做了逻辑审计，没有截取 4 个氧量档位的连续视频。
- 鲨群小弟现在是滑入，不是完整“从身后追上游动”的动画。
- BRO DIVE 放行的是“已跳 + 正在下潜”的兔子擦边，不是重写整个接人机制。
- 没有真人试玩；最终手感仍需 Producer 确认。

## 9. 自评

- 视觉可读性：比 FEEL-43 好一档；
- 机制：只做 BRO DIVE 擦边放行，没有改鲨群/高墙/氧气规则；
- 综合仍 **8.5/10**，不是 9：没有真人手感、没有音画、Z1/Z2 决策密度仍有限。

**STOP，等待制作人复看这版视觉与卡脚修复。**
