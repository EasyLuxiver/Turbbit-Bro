# FEEL-17 音频任务清单（可直接派单）

> 当前项目**没有任何音频资源**。本清单全部为未开始；不得把占位音标为最终。
> 统一：WAV 48 kHz/16-bit 或 OGG；SFX 单声道优先，BGM 立体声；峰值 ≤ -1 dBFS；命名 `sfx_事件_vNN.wav` / `bgm_区域_vNN.ogg`；英文小写无空格。

## A. BGM（P1）

| ID | 文件 | 场景 | 情绪/节奏 | 循环 | 接入 |
|---|---|---|---|---|---|
| MUS-01 | `bgm_menu_v1.ogg` | 主菜单/设置 | 轻松海风，60–90 BPM | 是 | `menu.gd` |
| MUS-02 | `bgm_comic_v1.ogg` | 7 格开场 | 漫画悬疑转喜剧，可分段 | 否 | `opening_comic.gd` |
| MUS-03 | `bgm_tutorial_v1.ogg` | 4 步教学 | 鼓励、清楚、不抢提示 | 是 | `tutorial.gd` |
| MUS-04 | `bgm_z1_v1.ogg` | Z1 阳光海岸 | 明亮、学习，90–110 BPM | 是 | `race.gd` 进区切换 |
| MUS-05 | `bgm_z2_v1.ogg` | Z2 码头 | 机械、紧张，110–125 | 是 | `race.gd` |
| MUS-06 | `bgm_z3_v1.ogg` | Z3 肌肉混乱 | 高能、危险，125–140 | 是 | `race.gd` |
| MUS-07 | `bgm_finish_v1.ogg` | 终点 | 温暖收束，8–15 s | 否 | `result.gd` |
| MUS-08 | `bgm_fail_v1.ogg` | 氧气失败 | 低沉、短，4–8 s | 否/短循环 | `fail.gd` |

BGM 切换需 0.3–0.8 s 淡入淡出；Z 区切换不能切断 SHIFT/救援反馈。

## B. 核心机制 SFX（P0）

| ID | 文件 | 触发点 | 用途 | 备注 |
|---|---|---|---|---|
| SFX-01 | `sfx_shift_shock_v1.wav` | `GameManager.shift_shocked` | SHIFT 电击 | 与 `shift_fx.gd` 同帧 |
| SFX-02 | `sfx_jump_v1.wav` | `rabbit.launch` | TUBO 跳 | 短 |
| SFX-03 | `sfx_land_v1.wav` | `_apply_carry_result("pickup")` | 落壳 | 轻 |
| SFX-04 | `sfx_dive_v1.wav` / `sfx_surface_v1.wav` | 壳入水/出水 | 下潜/上浮 | 水声 |
| SFX-05 | `sfx_catch_start_v1.wav` | `_catch_active=true` | BITT 救援开始 | 三连第一段 |
| SFX-06 | `sfx_catch_ok_v1.wav` | `_rescue_catch` | 接住 | 第二段 |
| SFX-07 | `sfx_carry_v1.wav` | `_begin_carry("rescue")` | 抬回 | 第三段 |
| SFX-08 | `sfx_auto_return_v1.wav` | `_rescue_auto` | 自动回壳闪白 | 短促回响 |
| SFX-09 | `sfx_auto_fail_v1.wav` | `_rescue_auto_blocked` | 自动回壳失败 | 低 |
| SFX-10 | `sfx_oxygen_low_v1.wav` / `critical` / `out` | `_update_oxygen` phase 变化 | 氧气 | 心跳/断裂 |
| SFX-11 | `sfx_hit_rabbit_v1.wav` / `hit_turtle` | `_rabbit_contact` / `_turtle_contact` | 碰撞 | 木头/金属区分 |
| SFX-12 | `sfx_buoy_bump_v1.wav` | `_turtle_dynamic_bump` | BITT 撞浮标/木箱 | 木/金属 |
| SFX-13 | `sfx_mischief_pre_v1.wav` | `_maybe_start_mischief` | 前摇 | 电流蓄力 |
| SFX-14 | `sfx_mischief_shock_v1.wav` | `_apply_mischief_action` shock | BITT 电 TUBO | 漫画夸张 |
| SFX-15 | `sfx_mischief_tug_v1.wav` | `_apply_mischief_action` tug | TUBO 拽绳 | 绳/勒 |
| SFX-16 | `sfx_mischief_end_v1.wav` | `_end_mischief` | 结束/清零 | 收尾 |
| SFX-17 | `sfx_overdrive_pre_v1.wav` | `_start_overdrive` | OVERDRIVE 预兆 | 电流 |
| SFX-18 | `sfx_overdrive_spring_v1.wav` / `shell` | `_activate_overdrive` | 弹簧/旋壳 | 与角色动作 |
| SFX-19 | `sfx_showtime_v1.wav` | `start_showtime` | 表演开始 | 欢呼 |
| SFX-20 | `sfx_showtime_end_v1.wav` | `_end_showtime` | 表演收尾 | 短 |
| SFX-21 | `sfx_finish_v1.wav` | `finish_race` | 终点到达 | 与 BGM 转场 |
| SFX-22 | `sfx_fail_v1.wav` | `finish_failure` | 失败 | 水下闷响/静音 |

## C. UI/流程 SFX（P2）

| ID | 文件 | 触发 |
|---|---|---|
| UI-01 | `sfx_ui_confirm_v1.wav` | 菜单开始/设置/确认 |
| UI-02 | `sfx_ui_back_v1.wav` | 返回/取消 |
| UI-03 | `sfx_ui_quit_v1.wav` | 退出确认 |
| UI-04 | `sfx_comic_page_v1.wav` | 开场翻页 |
| UI-05 | `sfx_tutorial_ok_v1.wav` / `fail` | 教学步骤完成/失败 |

## D. 接入与验收

1. 新增 `AudioDirector`（或现有 autoload 内最小播放器池）只做播放，不新建第二套游戏状态。
2. 每个 SFX 必须由正式状态/信号触发；禁止测试专用音。
3. 同帧验证：截图/录屏 + 事件日志；至少检查 SHIFT、接住、MISCHIEF、氧气耗尽、失败、终点。
4. 音量：默认 BGM -18 LUFS 左右，SFX 不盖过语音/提示；提供 0–100 音量设置（如制作人批准）。
5. 未接入正式比赛的音频只标“候选”。

## E. OS 接入进度（本轮）

- 未新增/未播放任何音频；无资源可接。
- 接入点已在代码中可定位（见上表）；等音频文件后按表绑定。
