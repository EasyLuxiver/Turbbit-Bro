# FEEL-16 美术 / 音频整合清单

> 当前正式比赛仍是 Godot 原生绘制；`art_test/feel13` 只是独立拆件技术样，**没有接入正式比赛**。
> 本清单是给美术/音频成员的可执行接口，不代表这些素材已完成。

## 1. 现有资源状态

- 角色：`race.gd` 原生形状绘制（TUBO 兔子、BITT 乌龟）；`art_test/feel13` 有 17 张 AI 拆件透明 PNG + pivots，但未进正式场景。
- 场景：程序化色块/几何背景；无外部场景贴图。
- UI：原生 Control/Label/Panel；无图标包、无字体文件。
- 音频：**没有任何音频资源**；无 BGM、无 SFX。

## 2. 角色素材需求

### TUBO

| 部件 | 文件命名 | 尺寸/要求 | 用途 |
|---|---|---|---|
| 头（含脸） | `char/tubo/head.png` | 建议 256×256 内，透明 | RIDING/CROUCH/JUMP/FALLING/SHOWTIME |
| 双耳 | `char/tubo/ear_l.png` / `ear_r.png` | 同头，透明，pivot 在耳根 | 待机摆动、跳跃拉伸、过载 |
| 躯干 | `char/tubo/torso.png` | 透明，pivot 在髋 | 所有状态 |
| 双臂 | `arm_l.png` / `arm_r.png` | 透明，pivot 肩 | 跳跃、抓壳、SHOWTIME、MISCHIEF |
| 双腿 | `leg_l.png` / `leg_r.png` | 透明，pivot 髋 | 站立/跳跃/落地 |
| 尾巴 | `tail.png` | 透明，pivot 根部 | 待机、落地 |
| 表情层（可选） | `face_idle.png` / `face_hit.png` / `face_water.png` | 透明叠层 | 当前原生表情替代 |

### BITT

| 部件 | 文件命名 | 尺寸/要求 | 用途 |
|---|---|---|---|
| 壳 | `char/bitt/shell.png` | 透明，pivot 壳中心 | CRUISING/DIVING/LEAPING/OVERDRIVE |
| 头/颈 | `head.png` / `neck.png` | 透明，pivot 颈根 | 待命/下潜/救援 |
| 四鳍 | `flipper_front/back/far/rear.png` | 透明，pivot 鳍根 | 巡航、跃起、救援、MISCHIEF 拽绳 |
| 尾 | `tail.png` | 透明 | 巡航 |
| 表情层 | `face_idle/hit/water.png` | 透明叠层 | 情绪反馈 |

### 大表哥

| 文件 | 用途 | 要求 |
|---|---|---|
| `char/cousin/idle.png` | 开场/教学/终点 | 透明，热情/肌肉/笨拙姿态 |
| `char/cousin/potion.png` | 终点解药 | 透明，独立瓶/手可分离 |
| `char/cousin/point.png` | 教学提示 | 透明，指向姿势 |

### 统一要求

- 透明 PNG（RGBA），不要预乘 alpha；留 2–4 px 安全边。
- 同一角色所有部件同一画布比例；pivot 用 JSON 记录：`{part: {file, pivot_px, z, scale}}`。
- 描线粗细/配色必须来自同一色板；不要每张图自动描边。
- 命名：`角色_部件_状态_vNN.png`；不要用空格/中文路径。
- 正式导入前检查：尺寸、透明边缘、pivot、遮挡顺序、缩放后在 100 px 游戏尺寸仍可读。

## 3. 动画状态映射

每个动画必须对应下列实际游戏状态；缺一个就不算接入。

| 动画 | 游戏状态/触发 | 当前代码位置 |
|---|---|---|
| `tubo_idle` | `rabbit.state=RIDING`，无输入 | `_tick_rabbit` |
| `tubo_crouch` | `CROUCHING` / ↓ | `_tick_rabbit` |
| `tubo_jump` | `JUMPING`，↑ | `rabbit.launch` |
| `tubo_fall` | `FALLING`，空中下落 | `rabbit.tick_air` |
| `tubo_land` | 回到 `RIDING` 的落地帧 | `_apply_carry_result("pickup")` |
| `tubo_water` | `FALLING_WATER` / `RESCUE_ACTIVE` | `_trigger_accident("RABBIT_WATER")` |
| `tubo_showtime` | `SHOWTIME` | `_tick_showtime` |
| `tubo_shock` | MISCHIEF 电击 | `_apply_mischief_action` |
| `tubo_tug` | MISCHIEF 拽绳 | `_apply_mischief_action` |
| `bitt_cruise` | `CRUISING` | `turtle.tick` |
| `bitt_dive` | 按住 ↓ + 壳下沉 | `turtle._tick_surfboard` |
| `bitt_leap` | ↑ 跃起 | `turtle.start_leap` |
| `bitt_land` | 跃起结束/落回 | `_tick_recovery` |
| `bitt_rescue` | `_catch_active` / `RESCUING` | `_tick_bro_catch` |
| `bitt_carry` | `CARRYING` | `_tick_carry` |
| `bitt_overdrive` | `_od_phase=ACTIVE` 且角色 turtle | `_shell_overdrive` |
| `tubo_overdrive` | `_od_phase=ACTIVE` 且角色 rabbit | `_spring_overdrive` |
| `bitt_tug` | MISCHIEF 被 TUBO 拽 | `_apply_mischief_action` |
| `cousin_idle/point` | 开场/教学/终点 | `opening_comic.gd` / `tutorial.gd` / `result.gd` |

## 4. 音效事件（SFX）

| 事件 | 触发点 | 建议 |
|---|---|---|
| 菜单确认/返回 | `menu.gd` 按钮 | 短、轻 |
| 开场翻页 | `opening_comic.gd` 面板切换 | 纸张/电流 |
| 教学步骤完成/失败 | `tutorial._set_step` / `_show_fail` | 上扬/下降 |
| SHIFT 电击 | `GameManager.shift_shocked` | 短电流，必须与 `shift_fx.gd` 同帧 |
| 跳跃/落地 | `rabbit.launch` / 落壳 | 起跳/轻落 |
| 下潜/上浮 | 壳入水/出水 | 水声 |
| 护盾（已移除） | 不接 | — |
| BITT 救援开始/接住/抬回 | `_catch_active` / `_rescue_catch` / `_apply_carry_result("rescue")` | 三段可辨 |
| 自动恢复闪白 | `_rescue_auto` | 短促回响 |
| 氧气低/临界/耗尽 | `_update_oxygen` phase 变化 | 心跳/气泡/断裂 |
| 碰撞 | `_rabbit_contact` / `_turtle_contact` / `_turtle_dynamic_bump` | 木头/金属/水 |
| MISCHIEF 前摇/电击/拽绳/结束 | `_maybe_start_mischief` / `_apply_mischief_action` / `_end_mischief` | 漫画夸张 |
| OVERDRIVE 预兆/动作/结束 | `_start_overdrive` / `_activate_overdrive` / `_end_overdrive` | 电流/弹簧/壳旋转 |
| SHOWTIME | `start_showtime` / `_end_showtime` | 欢呼/收尾 |
| 终点到达 | `finish_race` | 音乐转场 |
| 失败 | `finish_failure` | 水下闷响/静默 |

## 5. 音乐（BGM）

| 场景 | 情绪 | 需求 |
|---|---|---|
| 主菜单 | 轻松、海风 | 可循环，淡入淡出 |
| 开场连环画 | 漫画、悬疑转喜剧 | 7 格可分段或整段 |
| 教学 | 鼓励、清楚 | 不抢提示音 |
| Z1 阳光海岸 | 明亮、学习 | 中速 |
| Z2 码头 | 紧张、机械 | 节奏加快 |
| Z3 肌肉混乱 | 高能、危险 | 最强，但不盖碰撞/氧气 |
| SHOWTIME/OVERDRIVE | 短促高光 | 可与 BGM 叠加或 duck |
| 终点 | 温暖、解药 | 收束 |
| 失败 | 低沉、短 | 不循环或短循环 |

## 6. 导入与验收

- 音频：WAV 48 kHz / 16-bit 或 OGG Vorbis；SFX 单声道优先，BGM 立体声；峰值 ≤ -1 dBFS。
- 命名：`sfx_事件_vNN.wav`、`bgm_区域_vNN.ogg`；不要中文/空格。
- 每个接入必须：
  1. 在正式场景/正式状态触发；
  2. 有实际运行截图或录屏；
  3. 与画面事件同帧或 ≤1 帧偏差；
  4. 不新增音频总线/系统，先用现有 AudioStreamPlayer 节点。
- 未接入正式比赛的素材只能标“候选”，不能标“完成”。
