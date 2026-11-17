extends Node2D
## 阶段 3：一条约 66400 px 的完整赛道，分三个区域连续比赛。
## 氧气三档、分阶段失控、六类障碍、事故分级、Brotherhood 连击与 Showtime。
## 赛道数据在 level_data.gd；障碍判定全部走矩形，H 键可显示真实碰撞框。

const Tuning = preload("res://scripts/systems/tuning.gd")
const LevelDataScript = preload("res://scripts/systems/level_data.gd")
const TurtleScript = preload("res://scripts/actors/turtle_controller.gd")
const RabbitScript = preload("res://scripts/actors/rabbit_controller.gd")
const MountScript = preload("res://scripts/systems/mount_controller.gd")
const BroBrainScript = preload("res://scripts/systems/bro_brain.gd")
const HUDScript = preload("res://scripts/ui/hud.gd")
const PauseMenuScript = preload("res://scripts/ui/pause_menu.gd")
const ShiftFXScript = preload("res://scripts/ui/shift_fx.gd")
const OpeningScript = preload("res://scripts/ui/opening.gd")

const SURFACE_Y := 300.0
## PHASE-ART：Z1 用制作人提供的室外码头图；切掉平蓝水面，换成玩法水柱。
const Z1_DOCK_TEX = preload("res://assets/art/z1_dock_cutout.png")
const Z1_DOCK_REFLECT = preload("res://assets/art/z1_dock_reflection.png")
const Z1_ART_LEFT := -400.0
const Z1_ART_RIGHT := 1520.0
const Z1_ART_W := 1920.0
const Z1_ART_Y := -30.0
const Z1_ART_H := 1080.0
const USE_Z1_ART := true
const WORLD_END := LevelDataScript.WORLD_END
const HAZARD_WARN := 270.0
## 表演需要的空档：1.8 s 表演 + 1.0 s 结束宽限 + 换人/起跳提前量，按 260 px/s 取约 900 px。
const SHOWTIME_CLEAR := 900.0
## 下沉门没有手动潜深，换人的时机就是全部：预警牌放在换人的最佳位置
## （灰盒实测 180–220 px 可过，200 px 余量最大），而不是通用 270 px。
const GATE_WARN := 200.0
const FINISH_DELAY := 1.6
## PHASE-2：终点后的沙滩缓冲。镜头跟到世界终点后还要展示大表哥，
## 这段必须继续有背景，否则会露出默认黑色清屏。
const FINISH_BEACH_EXTRA := 2200.0

var hazard_groups: Array = []
var boost_lanes: Array = []
## 赛道终点：正式赛道 66000；原型段只有 8600。
var world_end := WORLD_END
var current_zone: Dictionary = LevelDataScript.ZONES[0]
var lesson_seen := {}
## REBUILD-05 G22：撞过的类型只补教一次。撞第二组时不再重新武装，
## 否则同一类型连着撞会一路复读同一句话（G21 记下的“无上限”问题）。
var lesson_retaught := {}
var snack_lesson_seen := false
var finishing := false
var finish_timer := 0.0
const BOOST_LANE_SPEED := 380.0

## ---- Phase O：TURTLE SNACK RUSH ----
## 食物遭遇表（每段旧加速带一个）。缓存由 boost_lanes 的条数失效，
## 旧测试 clear() 掉 boost_lanes 就等于关闭食物，几何审计不受影响。
var _snack_cache: Array = []
var _snack_cache_sig := -1
## 当前加速：只服务于吃下食物后的那一次遭遇，过障碍 + 尾巴后归零。
var snack_boost_until_x := -1.0
var snack_boost_speed := 0.0
## 吞食反馈：0.45 s 的夸张吞咽 + 速度线；snack_gulp_x 是吃下那一个的位置。
var snack_gulp_t := 0.0
var snack_gulp_x := 0.0
## PLAYFUL-04 §4：这一口是不是玩家亲手（操控乌龟）喂到的——只影响表现。
var snack_gulp_by_player := false
var snack_last_eaten := ""
## REBUILD-06 P4：谁吃到（turtle / rabbit）。控制谁就谁吃；控制兔子时乌龟
## 不再替玩家吃——想喂乌龟就得按 SHIFT 切回去。
var snack_last_by := ""
## 兔子阶段：吃到后 ×1.15 跳跃初速，窗口与乌龟 TURBO 同长（到该组末尾 + 180 px）。
var rabbit_boost_until_x := -1.0
## 争抢表现：0 = 附近没有未吃的食物；否则是食物的 x（两个角色都伸手）。
var snack_interest_x := -1.0

## ---- Phase P：随机障碍抽取 ----
## level_seed 为 0 时用固定默认种子（20261112），保证每次运行、每个自动测试
## 看到的是同一套抽取结果；复现/换一套抽法用命令行 `-- --seed N`，
## 或在测试里先 `race.level_seed = N` 再 load_level。种子会打印在日志里。
const DEFAULT_LEVEL_SEED := 20261112
var level_seed := 0
var snack_draws: Array = []

var turtle
var rabbit
var mount
var camera: Camera2D
var hud
## SHIFT 正式表现控制器（CanvasLayer 下的 Control，见 ui/shift_fx.gd）。
var shift_fx
## 受激动作与镜头脉冲：由 shift_shocked 触发，只影响画法，不影响判定。
var _shift_jolt_t := 0.0
var _shift_jolt_who := ""
## REFINE-06 P1：上一帧双方的神游阶段，用来只在“真的回到 CALM”时报一次。
var _last_drift_state := {"rabbit": "CALM", "turtle": "CALM"}
## FEEL-47：纯表现的三段压力状态（0..3），不参与判定/分数/控制。
## 0=正常，1=摇晃，2=乱蹦，3=快控制不住；食物/干净通过会回落。
var _visual_stress := {"rabbit": 0.0, "turtle": 0.0}
## FEEL-47 自检口径：视觉压力只走 _bump/_relieve + 头顶三格；不写 bro_meter、
## 不参与输入延迟、事故、氧气或分数。正赛教学文案由 quiet_lessons 关闭，
## 事件提示（好接/救援/事故）仍保留；headless 探针保留旧提示以测 UI。
## FEEL-25：被晾着的角色以可见情绪累积，不修改输入/位置。
var _ignore_t := {"rabbit": 0.0, "turtle": 0.0}
## CORE-FEEL-07 P1-D：上一帧的阶段序号，只在“升级”越过 6 s / 9 s 阈值时报警一次。
var _last_drift_rank := {"rabbit": 0, "turtle": 0}
var _camera_pulse_t := 0.0
const SHIFT_JOLT_TIME := 0.18
const CAMERA_PULSE_TIME := 0.11
const CAMERA_PULSE_PX := 2.0

## ---- TBB-SHIFT-FEEL-03 P2-7：开场占位 ----
## 6 s 可跳过；期间只冻结比赛推进，不接管输入以外的系统。
## 原生 Control 占位，不引入任何美术/音频素材。
var opening
var opening_active := false
## 开场期间把 HUD 整层藏起来：占位画面不显示还在计时的读数。
var _hud_layer: CanvasLayer

## ---- TBB-SHIFT-FEEL-03 P1-5：碰撞/动作反馈 ----
## 表现停顿（hitstop）只按住“画出来的位置”：物理位置、速度、碰撞框照常走。
## 读到的是“敲了一下”，不会给玩家多出/少掉反应时间——判定结果与改动前一致。
const HITSTOP_RABBIT := 0.05   # 40–60 ms
const HITSTOP_TURTLE := 0.09   # 乌龟更重
var _hitstop_t := 0.0
var _hitstop_dur := 0.0
var _hitstop_who := ""
var _hitstop_draw := Vector2.ZERO
## 供探针读取：每次停顿的时长与位置。
var hitstop_log: Array = []
## 普通碰撞 2–3 px，重大碰撞（浪击/落水）5–8 px；只叠加在相机位置，不移动判定。
const SHAKE_NORMAL_PX := 2.5
const SHAKE_MAJOR_PX := 6.5
const SHAKE_NORMAL_TIME := 0.18
const SHAKE_MAJOR_TIME := 0.26
var _shake_t := 0.0
var _shake_dur := 0.0
var _shake_amp := 0.0
var _shake_peak := 0.0
var shake_log: Array = []
## 落地水花：记在兔子真正落回壳上的世界点，而不是壳的当前位置。
var land_splash_pos := Vector2.ZERO
var land_splash_t := -1.0
const LAND_SPLASH_TIME := 0.4
## 主动动作成功：BRO DIVE（青）与 BRO OLLIE（金）用不同颜色/方向区分。
var action_fx_kind := ""
var action_fx_pos := Vector2.ZERO
var action_fx_t := -1.0
const ACTION_FX_TIME := 0.55
var action_fx_log: Array = []
## REBUILD-05 G4：连招成功时角色本体的一下小幅弹跳。
## 只作为 _draw_rabbit 的画法偏移，rabbit.position 不动，判定/碰撞/接应都不读它。
var celebrate_t := -1.0
var celebrate_kind := ""
const CELEBRATE_TIME := 0.34
const CELEBRATE_HOP_PX := 12.0
## REBUILD-05 G9：兔子落回壳上时壳的重量反应（制作人 2026-11-11 第 4 条）。
## 只在 `_draw_turtle` 里偏移画法；判定/接应/位置都不读它。
var shell_dip_t := -1.0
var shell_dip_amp := 0.0
## 探针读数用：本次下沉的最大像素。
var shell_dip_peak := 0.0
## REBUILD-05 G6：会动的障碍第一次进入这个距离时提醒一句，每区只提醒一次。
## 560 px 在 Z1 速度下约 2.5 s，提示（2.2 s）正好跟到障碍跟前。
const MOTION_HINT_RANGE := 560.0
var motion_lesson_zone := -1

## ---- TBB-SHIFT-FEEL-03 P1-6：Z3 复杂障碍的远距预警 ----
## 只对 Zone 3 前方最近的一组“两段操作”障碍（浮木/高墙）亮屏幕右缘图标：
## 1300 px ÷ 260 px/s = 5.0 s。障碍还没进画面时图标钉在右缘（不会提前露出来），
## 进画面后随世界坐标自然靠近。不读抽取池，只用当前这一组的真实类型。
const Z3_WARN_RANGE := 1300.0
const Z3_EDGE_X := 1080.0
## 图标画在天空层，离水面线（300）留出余量，不压操作带。
const Z3_ICON_Y := 150.0
var z3_warn_group := ""
var z3_warn_kind := ""
var z3_warn_dist := -1.0
var z3_warn_t := 0.0

## ---- TBB-SHIFT-FEEL-03 §3：输入宽容 ----
## 只缓存“上”（兔子跳 / 乌龟跃起）这一种瞬时动作。
## ↓ 是按住生效的持续输入，交接时只要还按着就自然生效，不需要缓存。
const INPUT_BUFFER_TIME := 0.12
const JUMP_COYOTE_TIME := 0.10
## 测试用：临时替换输入缓冲窗口（-1 = 用正式 INPUT_BUFFER_TIME）。
## 只给 A/B 探针证明“无缓冲 → 120 ms”的差别，正式流程从不改它。
var input_buffer_override := -1.0
var _buf_action := ""
var _buf_age := 0.0
## 按下时的 SHIFT 计数：允许“按完立刻换人”交付一次，连续快速换人不再追发。
var _buf_shift_count := 0
var _coyote_t := 0.0
## 上升沿检测：按住不放只算一次输入，落地时不会因为“还按着”自动连跳。
var _up_was_pressed := false
## 真实按键事件的记录时间：让“按下瞬间换了几次人”按事件顺序计算，
## 而不是按物理帧开始时的计数（同一帧连按 SHIFT 时两者不同）。
var _buf_event_msec := -9999
## 供测试读取：缓存被谁消费、跳了几次。
var input_buffer_log: Array = []
## ---- CORE-FEEL-08 P0-A：神游让角色“慢半拍” ----
## 按下沿先等 _buf_delay 再进缓存；↓ 的新按下先等 _down_delay 才算“听见”。
## 只延迟，不丢键、不反转、不锁死；按住不放的动作完全不受影响。
var _buf_delay := 0.0
var _down_delay := 0.0
var _down_was_pressed := false
var _drift_auton_t := 0.0
var _drift_impair_clock := 0.0
var _drift_lag_fb_t := {"rabbit": -99.0, "turtle": -99.0}
var _bitt_autocrouch_t := 0.0
var _bitt_autocrouch_left := 0.0
var _bitt_autocrouch_fb_t := -99.0
## FEEL-15：BRO MISCHIEF 状态机。只有“未受控 + 该角色惩罚条满”才启动。
## 单事件、单角色；SHIFT/救援/落水/Showtime 会立即取消，不会残留。
const MISCHIEF_TELEGRAPH := 0.65
const MISCHIEF_ACTION := 0.70
const MISCHIEF_END := 0.22
const MISCHIEF_CD := 3.0
## 抱怨窗口 7 s，但要让玩家先有“我把他留失控了”的 1.2 s，才允许动手。
const MISCHIEF_REACTION_DELAY := 1.2
var _mischief_role := ""
var _mischief_phase := ""
var _mischief_t := 0.0
var _mischief_cd := 0.0
## PHASE-FIX：乌龟撞上乌龟层障碍后弹回；连续 6 次直接失败。
var _bonk_streak := 0
var _bonk_level := 0
var _bounce_cd := 0.0
## PHASE-FIX：Showtime 小奖励的冷却与乌龟视觉腾空。
var _showtime_cd := 0.0
var _showtime_turtle_y := 0.0
var _showtime_turtle_spin := 0.0
const BONK_BACK := 140.0
const BONK_CD := 0.8
const BONK_FAIL_COUNT := 6
const BONK_KINDS := ["DIVE_GATE", "HIGH_WALL", "FLOATING_LOG", "SHARK"]
var _mischief_last_control := ""
var _mischief_fx_kind := ""
var _mischief_fx_t := 0.0
var _mischief_action_done := false
## PHASE-1：每个角色自己的动作序列，保证“电击”不会被拽绳完全淹没。
## 偶数次兔子捣乱必出电击；其余时候仍按上下潜/跃起情境选。
var _mischief_action_seq := {"rabbit": 0, "turtle": 0}
var mischief_log: Array = []
## 供探针读取：每次延迟/自主动作的记录（角色、类型、秒）。
var drift_impair_log: Array = []
var hazard_cooldown := 0.0
## REBUILD-05 E2：动态障碍共用的运动时钟（游戏秒）。
## 探针把物理推进停下来时可以手动置位，用它扫完整周期；
## 画和判定都读同一个 hazard_offset()，不存在“画的在动、判的是静止”。
var hazard_clock := 0.0
## REBUILD-06 P3：水下伏击鲨的逐组状态（组名 -> {phase, t}）。
## 相位由“玩家靠近”驱动，不是全局计时器：玩家看得到它什么时候醒。
## 只有 LUNGE 与水面航道相交；DOWN/TELEGRAPH 时整条鱼在 528～720。
var _ambush: Dictionary = {}
## FEEL-19 P1-A：海鸟行为状态。只让少数鸟拥有额外行为，避免全群同时变招。
var _bird_states: Dictionary = {}
var _bird_attacks: Array = []
var _bird_splashes: Array = []
## PHASE-FIX：落水后的便便停止旋转、下沉淡出。
var _poop_sinks: Array = []
## FEEL-21 P1-B：仅 shark6 单组鲨鱼群。
## FEEL-49：三只鲨鱼是持续存在的实体，平时在船底跟随，攻击时由同一只鱼
## 从深水上冲到攻击位置；不再“水里三只 + 另外凭空生成一个攻击体”。
var _shark_pack: Dictionary = {}
var _shark_pack_entry_seen := false
## 当前处于上冲/压顶/下潜窗口的那一只。最多一个，供旧测试和 HUD 读取。
var _shark_attacks: Array = []
## 三只持续实体：leader / fat / thin。每只自己带 rect、x、y、phase。
var _pack_actors: Array = []
## FEEL-31：三只鲨鱼的分工记录，供测试场/回归读取。
var _shark_pack_log: Array = []
## 看台：首次登场结束后沉到屏幕下方，观察但不参与判定。
var _shark_stands_t := 0.0
var _shark_stands_taunt_t := 0.0
## 测试场专用：只生成/清除 test_spawned 组，不影响正式关卡。
var _test_group_seq := 0
const BIRD_TELEGRAPH := 1.15
const BIRD_ACTION := 0.65
const BIRD_RECOVER := 0.55
## FEEL-32：小头目三段的时间轴（不是“攻击间隔”，是分别计时）。
const PACK_LEAD_WARN := 0.95
const PACK_WARN_FAT := 0.95
const PACK_WARN_THIN := 1.05
const PACK_SAFETY := 0.70
## FEEL-49：三只实体共用的攻击动作。上冲 0.12 s，压顶 0.55 s，下潜 0.45 s；
## 攻击体不再有独立寿命，生命周期完全由同一只鲨鱼的相位驱动。
const PACK_FOLLOW_TIME := 0.85
const PACK_ACTOR_RISE := 0.26
const PACK_ACTOR_HOLD := 0.60
const PACK_ACTOR_RETREAT := 0.55
const PACK_DEEP_TOP := 760.0
var turtle_repair := 0.0
var turtle_grace := 0.0
var rabbit_grace := 0.0
var rabbit_stun := 0.0
var emergency_timer := 0.0
var test_disable_hazards := false
var test_no_finish := false
## FEEL-31：测试场从菜单进入时没有命令行场景参数，race 会误播 6 s 开场卡片。
## 测试场在 add_child 前置 true，正式流程不受影响。
var test_no_opening := false
## P0-C 独立试玩段：这两个动词不是正式 55 组，HUD 的 BRO DIVE/OLLIE
## 协作时机条会给出相反指令，测试段里关掉。
var test_no_coop_hint := false
## FEEL-12：教学/实验室用覆盖层自己的提示时，关掉 55 组的旧教学，避免旧提示抢字。
var test_no_lessons := false
## FEEL-47：正式窗口里正赛不再持续讲教学/连招/食物文案；
## headless 探针保留完整提示，避免把测试界面和玩家界面混在一起。
var quiet_lessons := DisplayServer.get_name() != "headless"
## FEEL-33：教学是教学，不是惩罚局；教学期间关闭抱怨/捣乱。
var test_no_mischief := false
## 回归测试可关掉概率 Showtime，避免整关结果抖动。
var test_no_showtime := false
## 教学/回归关闭撞击弹回，避免把固定驾驶器的路线推回。
var test_no_bounce := false
## 角色美术试验截图可隐藏控制环。
var test_no_control_ring := false
## 路线审计/基础动作矩阵用：只测普通路线，不让自动电流过载改变动作。
var test_no_overdrive := false
## FEEL-19：需要纯基线审计时可关海鸟额外行为；正式比赛默认开。
var test_no_bird_behaviors := false
var show_hitboxes := false
## F3 调试层：障碍 ID/类型/预期动作、判定框、触发距离、危险深度线。
## 关闭后世界里的开发文字、辅助线和碰撞框全部消失。
var debug_mode := false
var combo := 0
var combo_max := 0
var passed_groups := {}
var entered_groups := {}
var hit_groups := {}
## FEEL-29：失败后的一次性浮木碎木状态。
var destroyed_groups := {}
## FEEL-25：正式赛首次教学只保留少量，避免 HUD 变成说明书。
var lesson_prompt_count := 0
var first_dive_hint_shown := false
## REBUILD-05 B2：每组的“谁撞过”。{group_key: {"rabbit": true, "turtle": true}}
## hit_groups 仍然表示“这组已经出过事”，供通过/精准判定使用；
## hit_roles 让两个角色各记一次，不再因为兔子先命中就吞掉乌龟的碰撞。
var hit_roles := {}
## FEEL-15：动态浮标/木箱对 BITT 的接触反馈（只减速，不记事故/不吞通过）。
var _dynamic_bump_cd := {}
## CORE-FEEL-07 P0-B：一次事故只罚一次。事故按“障碍事件”结算，不再让兔子和乌龟
## 各自往同一个障碍上记一笔（旧的 _turtle_contact 直连 note_mistake，一次没跳过去
## 的浮木会扣两次分，用户试玩时说的“联合判罚判定有问题”就是这个）。
## 事件字段：id / group / kind / t / roles / settled / penalty_role / rescue / settled_t。
## - 同一障碍、同一时间窗（ACCIDENT_JOINT_WINDOW）内的碰撞算同一个事件；
## - 事件里同时有 rabbit 和 turtle → 联合事故，仍然只罚一次；
## - 事件结算（settled）之后，同组再来的碰撞只补表现，不再记账；
## - 不同障碍是不同事件，各自独立结算。
## 2026-11-13 补：事件创建时记 rabbit_air（兔子当时是否已经在空中）。浮木壳撞把壳顶住后，
## 兔子这一跳注定没有壳可落；它随后落水是同一笔失败的下游后果，用这个字段认出来并进同一事件。
var accident_event_time := 0.0
var accident_events := {}
var accident_event_log: Array = []
var accident_event_seq := 0
## CORE-FEEL-07 P0-A：浮木组合的辅助下潜。玩家仍然自己起跳（↑）、自己 SHIFT，
## 但 SHIFT 之后不再要求“按住 ↓ 卡到右缘再松手”：下潜保持到壳整段越过浮木，
## 然后自动上浮接人。只省掉松手时机，不放宽碰撞体，也不替玩家按跳/SHIFT。
## OFF → ARMED（兔子起跳、前方有浮木）→ ACTIVE（SHIFT 到乌龟）→ SURFACING（越过浮木后）。
var dive_assist := "OFF"
var dive_assist_key := ""
var dive_assist_end := 0.0
var dive_assist_t := 0.0
## REBUILD-05 G19：A 类障碍（低梁/海鸟/岩檐）只压在兔子那一层。玩家在操控
## 乌龟时被撞，等于“没机会躲”——当局第一次发生时底栏说一句换人，之后不再重复。
var _wrong_role_hinted := false
## STAGE 4：通过某个障碍时“实际用了哪个动作”。只在障碍横穿带里采样，
## 避免提前很久的乱跳被算成精准动作。通过时据此给 150/250/300 或 100。
var group_actions := {}
## BRO METER 满格后的联合惩罚演出：固定在事故恢复完成后播。
var joint_show_t := 0.0
var _joint_turtle_y := 0.0
const JOINT_SHOW_TIME := 1.4
const ACT_BAND := 40.0

# ---- FEEL-10 P0-A：真实联合事故 + 单角色捣乱 ----
## 双人真实危险的进入时刻；只有两者在 0.6 s 内同时危险才触发联合。
var _rabbit_danger_since := -1.0
var _turtle_danger_since := -1.0
var _joint_episode_done := false
var _joint_done_t := 0.0
## 乌龟被实心障碍顶住的短暂标记（由 _resolve_turtle_solid 写入）。
var _turtle_blocked_t := 0.0
## 单角色捣乱/满值不服从：TELEGRAPH -> BURST，全部用模拟时间。
var _burst_who := ""
var _burst_phase := ""
var _burst_t := 0.0
var _burst_source := ""
var _burst_cd := 0.0
var _rabbit_refuse_t := 0.0
var _turtle_refuse_t := 0.0
## FEEL-10 P0-C：状态吊网的升降偏移（控制乌龟时被绞盘拉高）。
var _state_net_shift := 0.0
## FEEL-10 P0-D：Z1→Z2 的横向 alpha 渐变，只建一次。
var _zone2_fade_tex: GradientTexture2D = null

# ---- FEEL-11 B3：电流接力 ----
## 一次 SHIFT 后的观测窗口：切出角色是否完成手里的动作、切入角色是否接手
## 做了另一个动作、窗口内是否干净通过/完成组合。1.4 s 覆盖一次完整的
## 起跳→换人→下潜→过木，否则真实 BRO DIVE 永远够不到“完美”。
var _relay: Dictionary = {}
var _relay_cd := 0.0
var _relay_fx_t := 0.0
var _relay_fx_kind := ""
var _relay_fx_pos := Vector2.ZERO
## 供探针读取：每次判定结果（不参与玩法）。
var relay_log: Array = []
const RELAY_WINDOW := 1.40
const RELAY_COOLDOWN := 1.2
const RELAY_FX_TIME := 0.65

# ---- FEEL-12 P0：BRO OVERDRIVE ----
## 高阶段电流走火的预兆窗口。只有“当前受控角色”在预兆里被 SHIFT 换走，
## 才进入慢镜头；不按则角色自己完成过载动作，不罚重手。
var _od_role := ""
var _od_phase := ""          # PRE / ACTIVE
var _od_t := 0.0
var _od_cd := 0.0
var _od_emphasis_t := 0.0
var _od_flash := 0.0
var _od_afterimages: Array = []
var _od_real_t := 0.0
var _od_last_ms := 0
var _od_spring_t := 0.0
var _od_shell_t := 0.0
var _od_autonomous := false
var _od_events: Array = []
const OD_PRE := 0.30
const OD_ACTIVE := 0.55
const OD_CD := 2.5
const OD_SLOW_SCALE := 0.40
const OD_SLOW_REAL := 0.70
const OD_RESTORE_REAL := 0.10

# ---- FEEL-12 补充 B：TUBO CARROT GUARD / BITT BRO CATCH ----
var _space_was_pressed := false
var _guard_t := 0.0
var _guard_age := 0.0
var _guard_cd := 0.0
var _guard_flash_t := 0.0
var _guard_blocked: Dictionary = {}
var _catch_active := false
var _catch_t := 0.0
var _catch_fx_t := 0.0
var _catch_target := Vector2.ZERO
const GUARD_RAISE := 0.16
const GUARD_TIME := 0.60
const GUARD_CD := 0.85
const CATCH_TIME := 2.20
const CATCH_SPEED := 340.0
## FEEL-17：自动回壳只BITT在附近时兜底；太远/氧气不足时不再无条件成功。
const AUTO_RESCUE_RANGE := 850.0
## FEEL-22：自动回壳要留出回壳航程的氧气；只剩一口气时不要先播“自动救援”
## 再在同一段回壳里判失败。主动 SPACE 仍可在低氧时立即接住。
const AUTO_RESCUE_MIN_AIR := Tuning.RESCUE_RETURN_TIME + 0.15
const BURST_TELEGRAPH := 0.35
const BURST_TIME := 0.70
const BURST_COOLDOWN := 3.0
const JOINT_WINDOW := 0.6
const JOINT_RESET := 1.0
var showtime_active := false
var showtime_t := 0.0
var showtime_prev_control := "rabbit"
## 视觉朝向：救援/被推回时乌龟会向左移动；只改画，不改物理位置。
var _turtle_facing := 1.0
var _turtle_last_draw_x := -1.0e9
## BRO BRAIN：两个角色各自的“没人管就会走神”时钟。只累积/恢复，不判事故。
var rabbit_brain
var turtle_brain
## Phase F：主动救援原型。--rescue-proto 进入单场景循环，正常赛道不受影响。
var rescue_proto_mode := false
var rescue_proto_air_mode := false
var rescue_proto_reset_t := 0.0
## 供自动探针读取："" / "caught" / "missed"。
var rescue_last_result := ""
## 失败的实际原因（§6“失败必须记录实际原因”）：timeout / too_far_x /
## turtle_too_shallow / turtle_too_deep / passed_by / air_expired。
var rescue_last_reason := ""
## -1 = 已经报过“自动回壳不成立”，回到 RIDING 时清回 0。
var rescue_auto_blocked_t := 0.0
## 高优先级事件打断自动回壳后，本轮不再续命；等回到 RIDING/重新落水才清。
var rescue_auto_disabled := false
## 真实落水：兔子按自己的重力下落，穿过水线时在这里记下水花（世界坐标）。
var rescue_splash_pos := Vector2.ZERO
var rescue_splash_t := -1.0
## 上一帧的兔子位置：接人判定做线段扫掠，低帧率下不漏接。
var rescue_prev_pos := Vector2.ZERO
## PLAYFUL-04：接住之后的连续抬升。0 = 没在抬升；>0 是剩余时间。
var carry_from := Vector2.ZERO
var carry_t := 0.0
var carry_dur := 0.0
## "pickup" | "rescue"：抬升结束时该记哪一种成功。
var carry_kind := ""
var carry_real_catch := true
## 诊断：抬升期间的单帧最大位移（测试/探针读）。
var carry_max_step := 0.0
var _oxygen_phase := "SAFE"
## 障碍尾端的自动上浮闸：一旦在尾端窗口内触发，就锁到真正回到巡航水深为止。
## 只锁 260 px 的固定距离不够——从满潜深度带着下沉惯性上浮要将近 1 s，
## 窗口一过玩家还按着 ↓，壳又重新往下走，等于“自动上浮”没兑现。
var _debug_overlay: CanvasLayer
## 事故演出的闪白计时与演出时钟（0.15 s 一闪，短促不挡操作）。
var accident_flash := 0.0
var _accident_t := 0.0


func _ready() -> void:
	_od_last_ms = Time.get_ticks_msec()
	rabbit_brain = BroBrainScript.new("rabbit")
	turtle_brain = BroBrainScript.new("turtle")
	# --proto 进入“障碍空间原型段”：五类障碍各一组，用来验组合漂浮物。
	var args := OS.get_cmdline_user_args()
	# Phase P：`--seed N` 让随机障碍可复现；不写就用系统时间并在装载时打印。
	var seed_arg := _arg_after(args, "--seed", "")
	if seed_arg.is_valid_int():
		level_seed = int(seed_arg)
	if "--rescue-proto" in args or "--rescue-proto-air" in args:
		setup_rescue_proto()
	elif "--proto" in args:
		setup_proto()
	else:
		load_level(LevelDataScript.groups(), LevelDataScript.boost_lanes())
	current_zone = LevelDataScript.zone_by_id(1)
	GameManager.note_zone(1, current_zone["name"])

	turtle = TurtleScript.new()
	turtle.name = "Turtle"
	add_child(turtle)
	rabbit = RabbitScript.new()
	rabbit.name = "Rabbit"
	add_child(rabbit)
	mount = MountScript.new()
	mount.name = "MountController"
	add_child(mount)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()

	# SHIFT 电击表现：挂在正式 Race 上，订阅 GameManager 的唯一信号。
	# 放在 HUD 之前、同一 layer，保证闪光在 HUD 文字下面，不挡读数。
	var fx_layer := CanvasLayer.new()
	fx_layer.name = "ShiftFXLayer"
	fx_layer.layer = 1
	add_child(fx_layer)
	shift_fx = ShiftFXScript.new()
	shift_fx.name = "ShiftFX"
	shift_fx.race = self
	fx_layer.add_child(shift_fx)
	GameManager.shift_shocked.connect(shift_fx.on_shift_shocked)
	GameManager.shift_shocked.connect(_on_shift_take)

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	add_child(hud_layer)
	_hud_layer = hud_layer
	hud = HUDScript.new()
	hud.name = "HUD"
	hud_layer.add_child(hud)
	hud.race = self

	# 暂停菜单用原生控件：继续 / 重新开始 / 返回主菜单，鼠标和键盘都能操作。
	var pause_layer := CanvasLayer.new()
	pause_layer.name = "PauseLayer"
	add_child(pause_layer)
	var pause_menu := PauseMenuScript.new()
	pause_menu.name = "PauseMenu"
	pause_layer.add_child(pause_menu)

	_debug_overlay = get_node_or_null("DebugOverlay")
	if _debug_overlay != null:
		_debug_overlay.visible = false

	GameManager.current_control = "rabbit"
	GameManager.has_shifted = false
	# 冲浪板模型开局就停在巡航水深（壳体略低于水面），不要先在水线上再浮上来。
	turtle.reset(Vector2(LevelDataScript.RACE_START_X, surface_ref()))
	rabbit.reset()
	rabbit.attach(turtle.get_mount_point())
	mount.reset()
	reset_brains()
	_update_camera()
	queue_redraw()

	# PHASE-FIX：教学→正赛时从黑场淡入，不要硬切。
	if GameManager.race_fade_in:
		GameManager.race_fade_in = false
		var fade_layer := CanvasLayer.new()
		fade_layer.layer = 100
		add_child(fade_layer)
		var fade_rect := ColorRect.new()
		fade_rect.color = Color(0, 0, 0, 1)
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fade_layer.add_child(fade_rect)
		var tw := create_tween()
		tw.tween_property(fade_rect, "color:a", 0.0, 0.35)
		tw.tween_callback(func() -> void: fade_layer.queue_free())

	# P2-7：正式开局先播一段可跳过的开场占位。headless 测试与非开场截图
	# 默认不挂，避免改变既有测试与回归的行为。
	if _opening_wanted():
		_start_opening()

	# 窗口化真实按键测试：先让窗口稳定 1.5 s 再开始救援，避免 OS 按键
	# 在引擎还没准备好接收输入时被丢掉。只影响 --capture-rescue 运行。
	if "--capture-rescue" in args:
		await get_tree().create_timer(1.5).timeout

	if "--rescue-proto" in args:
		start_rescue_proto(false)
	elif "--rescue-proto-air" in args:
		start_rescue_proto(true)

	if "--capture-stage2" in args or "--capture-accident" in args \
			or "--capture-showtime" in args or "--capture-boost" in args \
			or "--capture-race" in args or "--capture-pause" in args \
			or "--capture-imbalance" in args or "--capture-fall" in args \
			or "--capture-flip" in args or "--capture-leap" in args \
			or "--capture-debug" in args or "--capture-standby" in args \
			or "--capture-proto" in args or "--capture-penalty" in args \
			or "--capture-shark" in args or "--capture-dive-block" in args \
			or "--capture-snack" in args or "--capture-z3-warning" in args \
			or "--capture-opening" in args or "--capture-collision" in args \
			or "--capture-shift" in args or "--capture-coop" in args \
			or "--capture-bird" in args or "--capture-motion" in args \
			or "--capture-identity" in args or "--capture-dock" in args \
			or "--capture-z2" in args or "--capture-lesson" in args \
			or "--capture-showtime-reward" in args:
		GameManager.state = GameManager.GameState.RUNNING
	if "--capture-stage2" in args:
		_capture_after(1.0, "stage2_hud.png")
	if "--capture-finish" in args:
		_capture_finish(_arg_after(args, "--capture-finish", "phase2_finish.png"))
	if "--capture-race" in args:
		_capture_after(1.0, _arg_after(args, "--capture-race", "stage4_race.png"))
	if "--capture-leap" in args:
		_capture_leap(_arg_after(args, "--capture-leap", "stage4_leap.png"))
	if "--capture-debug" in args:
		_capture_debug(_arg_after(args, "--capture-debug", "stage4_debug.png"))
	if "--capture-shark" in args:
		_capture_shark(_arg_after(args, "--capture-shark", "phase-h_shark.png"))
	if "--capture-dive-block" in args:
		_capture_dive_block(_arg_after(args, "--capture-dive-block", "rock"))
	if "--capture-proto" in args:
		_capture_proto(_arg_after(args, "--capture-proto", "proto"))
	if "--capture-penalty" in args:
		_capture_penalty(_arg_after(args, "--capture-penalty", "phase-g"))
	if "--capture-rescue" in args:
		_capture_rescue(_arg_after(args, "--capture-rescue", "rescue_proto.png"))
	if "--capture-standby" in args:
		_capture_standby(_arg_after(args, "--capture-standby", "stage4_standby.png"))
	if "--capture-pause" in args:
		_capture_pause(_arg_after(args, "--capture-pause", "stage4_pause.png"))
	if "--capture-accident" in args:
		_capture_accident()
	if "--capture-imbalance" in args:
		_capture_imbalance()
	if "--capture-fall" in args:
		_capture_fall(_arg_after(args, "--capture-fall", "stage4_fall.png"))
	if "--capture-flip" in args:
		_capture_flip(_arg_after(args, "--capture-flip", "stage4_flip.png"))
	if "--capture-showtime" in args:
		_capture_showtime()
	if "--capture-boost" in args:
		_capture_boost()
	if "--capture-snack" in args:
		_capture_snack()
	if "--capture-z3-warning" in args:
		_capture_z3_warning(_arg_after(args, "--capture-z3-warning",
			"phase-v-z3-warning.png"))
	if "--capture-opening" in args:
		_capture_opening(_arg_after(args, "--capture-opening",
			"phase-v-opening.png"))
	if "--capture-collision" in args:
		_capture_collision(_arg_after(args, "--capture-collision",
			"phase-v-collision.png"))
	if "--capture-shift" in args:
		_capture_shift(_arg_after(args, "--capture-shift",
			"phase-v-shift.png"))
	if "--capture-bird" in args:
		_capture_bird(_arg_after(args, "--capture-bird", "rebuild05-bird"))
	if "--capture-motion" in args:
		_capture_motion(_arg_after(args, "--capture-motion", "rebuild05-motion"))
	if "--capture-identity" in args:
		_capture_identity(_arg_after(args, "--capture-identity", "core-feel-08"))
	if "--capture-dock" in args:
		_capture_dock(_arg_after(args, "--capture-dock", "core-feel-08-dock"))
	if "--capture-z2" in args:
		_capture_z2(_arg_after(args, "--capture-z2", "core-feel-09-z2"))
	if "--capture-lesson" in args:
		_capture_lesson(_arg_after(args, "--capture-lesson", "core-feel-09-lesson"))
	if "--capture-showtime-reward" in args:
		_capture_showtime_reward(_arg_after(args, "--capture-showtime-reward",
			"core-feel-09-showtime-reward"))
	if "--capture-coop" in args:
		_capture_coop(_arg_after(args, "--capture-coop", "coop"))


## P2-7：开场只在正式运行出现。截图/测试默认关掉，只有 --capture-opening、
## --force-opening 显式要求时挂载，避免影响既有证据链。
func _opening_wanted() -> bool:
	if test_no_opening:
		return false
	var args := OS.get_cmdline_user_args()
	if "--capture-opening" in args or "--force-opening" in args:
		return true
	if "--no-opening" in args:
		return false
	# FEEL-11：正式流程的 7 格连环画由 opening_comic 场景负责；
	# race 里的旧 6 s 卡片只在 --force-opening 调试时使用。
	if GameManager.story_seen:
		return false
	if DisplayServer.get_name() == "headless":
		return false
	for a in args:
		var text := String(a)
		if text == "--no-opening" or text.begins_with("--capture-"):
			return false
	# 直接启动测试场景时（命令行里指定的场景不是 race.tscn）不播开场：
	# 那些场景自己操控物理和输入，6 s 冻结会打乱它们的时序。
	var scene_arg := ""
	for a in OS.get_cmdline_args():
		var t := String(a)
		if t.ends_with(".tscn") or t.ends_with(".scn"):
			scene_arg = t
	if scene_arg != "" and not (scene_arg.ends_with("scenes/race.tscn")
			or scene_arg.ends_with("scenes/menu.tscn")):
		return false
	return true


func _start_opening() -> void:
	if opening_active:
		return
	var layer := CanvasLayer.new()
	layer.name = "OpeningLayer"
	add_child(layer)
	opening = OpeningScript.new()
	opening.name = "Opening"
	opening.setup(self)
	layer.add_child(opening)
	opening_active = true
	if _hud_layer != null:
		_hud_layer.visible = false
	opening.tree_exiting.connect(_on_opening_exiting.bind(opening))


## 开场结束（跳过或用完 6 s）后，比赛从下一物理帧开始推进。
func on_opening_finished() -> void:
	opening_active = false
	opening = null
	if _hud_layer != null:
		_hud_layer.visible = true


## 兜底：开场被外部 free 掉时也要解除冻结，避免永久卡住。
func _on_opening_exiting(who) -> void:
	if who == opening:
		on_opening_finished()


## 装载赛道数据。冲浪板模型把整层障碍沿 y 下移同样的量：
## 只动深度，不动 x，所以组位置、连击、密度和旧审计完全一致。
## 动态障碍测试场：在乌龟前方生成一组障碍，复用正式关卡的 build_group、
## 运动、伏击/海鸟/鲨群初始化。只标记 test_spawned，清除时只删这些组。
func spawn_test_group(kind: String, ahead: float = 700.0) -> Dictionary:
	_test_group_seq += 1
	var gx: float = turtle.position.x + ahead
	var zone_info: Dictionary = LevelDataScript.zone_at(gx)
	var spec := {
		"group": "test_%04d_%s" % [_test_group_seq, kind],
		"zone": int(zone_info["id"]),
		"kind": kind,
		"x": gx,
	}
	if kind == "SHARK6":
		spec["kind"] = "SHARK"
		spec["group"] = "shark6"
		spec["identity"] = "shark_pack"
		spec["w"] = 70.0
		spec["motion"] = {"name": "ambush_shark"}
		# 同一时间只保留一个鲨群。
		for old in hazard_groups.duplicate():
			if String(old.get("group", "")) == "shark6":
				hazard_groups.erase(old)
	elif kind == "SHARK":
		spec["motion"] = {"name": "ambush_shark"}
	elif kind == "SURFACE_ROCK":
		spec["motion"] = {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6}
	elif kind == "FLOATING_LOG":
		spec["motion"] = {"name": "swell_log", "axis": "y", "amp": 22.0,
			"period": 5.0, "bias": -18.0}
	var g: Dictionary = LevelDataScript.build_group(spec)
	# 运行时坐标系：和 load_level 一样整体下移。
	if Tuning.SURFBOARD_PHYSICS:
		var rects := []
		for r in g["rects"]:
			var rect: Rect2 = r
			rects.append(Rect2(rect.position + Vector2(0.0, Tuning.WORLD_Y_SHIFT), rect.size))
		g["rects"] = rects
	g["test_spawned"] = true
	hazard_groups.append(g)
	_init_ambush()
	_init_bird_behaviors()
	_init_shark_pack()
	return g


func clear_test_groups() -> void:
	for g in hazard_groups.duplicate():
		if bool(g.get("test_spawned", false)):
			hazard_groups.erase(g)
	destroyed_groups.clear()
	hit_groups.clear()
	hit_roles.clear()
	passed_groups.clear()
	entered_groups.clear()
	group_actions.clear()
	_shark_attacks.clear()
	_bird_attacks.clear()
	_shark_pack.clear()
	_shark_stands_t = 0.0
	_shark_pack_entry_seen = false
	_init_ambush()
	_init_bird_behaviors()
	_init_shark_pack()


func load_level(groups: Array, lanes: Array) -> void:
	hazard_groups = groups
	_bonk_streak = 0
	_bonk_level = 0
	_bounce_cd = 0.0
	boost_lanes = lanes
	reset_brains()
	group_actions.clear()
	destroyed_groups.clear()
	lesson_prompt_count = 0
	first_dive_hint_shown = false
	carry_kind = ""
	carry_dur = 0.0
	carry_t = 0.0
	carry_max_step = 0.0
	# 换关/重开时食物全部复位：已吃的清空、加速归零。
	_snack_cache = []
	_snack_cache_sig = -1
	snack_boost_until_x = -1.0
	snack_boost_speed = 0.0
	snack_gulp_t = 0.0
	snack_gulp_by_player = false
	snack_last_eaten = ""
	snack_last_by = ""
	rabbit_boost_until_x = -1.0
	snack_interest_x = -1.0
	if rabbit != null:
		rabbit.jump_boost = 1.0
	snack_lesson_seen = false
	motion_lesson_zone = -1
	# REBUILD-05 G22：装载关卡时把动态障碍的运动时钟归零。
	# 正式赛局本来就从头开始（构造函数里是 0），这里只是让“每例重装一次关卡”的
	# 探针也从同一相位起跑；此前只有 snack_zones 自己归零，其余多行探针的相位
	# 会随前一例的物理步数漂移，同样的断言时红时绿。
	hazard_clock = 0.0
	# Phase P：本局的食物后障碍在装载时一次抽定（不随进食与否改变），
	# 同种子必然同结果；抽到什么都先打印出来，便于复现。
	if level_seed == 0:
		level_seed = DEFAULT_LEVEL_SEED
	snack_draws = LevelDataScript.plan_snack_draws(level_seed, _snack_list())
	LevelDataScript.apply_snack_draws(hazard_groups, snack_draws)
	# REBUILD-06 P3：伏击状态必须在“抽取”之后建——抽取可能把某组换成 SHARK
	# （默认种子确实把 gate3 抽成了鲨鱼），先建会漏掉这一组，它就会以基础框
	# 静止在水面，重新变成 P0 那种“把壳无限顶住”的钉子。
	_init_ambush()
	_init_bird_behaviors()
	_init_shark_pack()
	_log_snack_draws()
	if not Tuning.SURFBOARD_PHYSICS:
		return
	var dy: float = Tuning.WORLD_Y_SHIFT
	for i in hazard_groups.size():
		var group: Dictionary = hazard_groups[i]
		var rects := []
		for r in group["rects"]:
			var rect: Rect2 = r
			rects.append(Rect2(rect.position + Vector2(0.0, dy), rect.size))
		group["rects"] = rects
	for i in boost_lanes.size():
		var lane: Rect2 = boost_lanes[i]
		boost_lanes[i] = Rect2(lane.position + Vector2(0.0, dy), lane.size)


## 角色的“基准水面”：旧模型是 300，冲浪板模型是巡航水深。
func surface_ref() -> float:
	return Tuning.NEUTRAL_DEPTH if Tuning.SURFBOARD_PHYSICS else SURFACE_Y


## 神游清零只用于真正的“重新开始/换关/恢复点”，不是切换角色时的奖励。
func reset_brains() -> void:
	if rabbit_brain != null:
		rabbit_brain.reset()
	if turtle_brain != null:
		turtle_brain.reset()
	if rabbit != null:
		rabbit.drift = 0.0
		rabbit.drift_state = "CALM"
		rabbit.air_scale = 1.0
	if turtle != null:
		turtle.drift = 0.0
		turtle.drift_state = "CALM"
		turtle.food_ahead = -1.0
	_last_drift_state = {"rabbit": "CALM", "turtle": "CALM"}
	_visual_stress = {"rabbit": 0.0, "turtle": 0.0}
	_last_drift_rank = {"rabbit": 0, "turtle": 0}
	_buf_delay = 0.0
	_down_delay = 0.0
	_down_was_pressed = false
	_drift_auton_t = 0.0
	_drift_impair_clock = 0.0
	_drift_lag_fb_t = {"rabbit": -99.0, "turtle": -99.0}
	_bitt_autocrouch_t = 0.0
	_bitt_autocrouch_left = 0.0
	_bitt_autocrouch_fb_t = -99.0
	drift_impair_log.clear()
	_mischief_role = ""
	_mischief_phase = ""
	_mischief_t = 0.0
	_mischief_cd = 0.0
	_mischief_last_control = ""
	_mischief_fx_kind = ""
	_mischief_fx_t = 0.0
	_mischief_action_done = false
	_mischief_action_seq = {"rabbit": 0, "turtle": 0}
	mischief_log.clear()
	if GameManager != null:
		GameManager.mischief_lock_role = ""


## 独立原型段：只有五类障碍，没有加速带，终点提前到 8600。
## 可重复调用（自检/截图会先 _ready 再切过来），load_level 每次都重新装一份数据。
func setup_proto() -> void:
	hazard_groups = []
	boost_lanes = []
	load_level(LevelDataScript.proto_groups(), [])
	world_end = LevelDataScript.PROTO_END


## Phase F：主动救援单场景。没有障碍，只有“兔子在水里、乌龟去接”的一段。
func setup_rescue_proto() -> void:
	hazard_groups = []
	boost_lanes = []
	world_end = 999999.0
	test_no_finish = true


## 供 --rescue-proto 和自动探针调用：把场景重置到“兔子刚落水/刚被抛起”的瞬间。
func start_rescue_proto(air: bool = false) -> void:
	rescue_proto_mode = true
	rescue_proto_air_mode = air
	test_no_finish = true
	GameManager.state = GameManager.GameState.RUNNING
	_arm_rescue_proto(air)


func _arm_rescue_proto(air: bool = false) -> void:
	rescue_proto_reset_t = 0.0
	rescue_last_result = ""
	rescue_last_reason = ""
	rescue_splash_pos = Vector2.ZERO
	rescue_splash_t = -1.0
	rescue_prev_pos = Vector2.ZERO
	rescue_auto_blocked_t = 0.0
	rescue_auto_disabled = false
	reset_brains()
	Input.action_release("up")
	Input.action_release("down")
	Input.action_release("shift")
	GameManager.clear_bro_meter()
	GameManager.accident_state = "NONE"
	GameManager.current_control = "turtle"
	GameManager.has_shifted = true
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.pickup_window = false
	GameManager.accident_count = 0
	GameManager.total_score = 0
	GameManager.score_log.clear()
	hazard_cooldown = 0.0
	rabbit_grace = 0.0
	rabbit_stun = 0.0
	emergency_timer = 0.0
	turtle_repair = 0.0
	turtle_grace = 0.0
	joint_show_t = 0.0
	showtime_active = false
	GameManager.showtime_active = false
	hit_groups.clear()
	hit_roles.clear()
	accident_event_time = 0.0
	accident_events.clear()
	accident_event_log.clear()
	accident_event_seq = 0
	_clear_dive_assist()
	_wrong_role_hinted = false
	passed_groups.clear()
	entered_groups.clear()
	turtle.reset(Vector2(LevelDataScript.RACE_START_X, Tuning.NEUTRAL_DEPTH))
	turtle.speed = 220.0
	turtle.base_speed = 220.0
	rabbit.reset()
	# §6：原型也从真实离壳位置开始。兔子真的起跳、没人接，落点由这一跳决定；
	# 不再把兔子直接摆到乌龟前方 520 px / 深度 460。
	rabbit.launch(turtle.get_mount_point(), turtle.speed)
	mount.reset()
	mount.mark_airborne()
	_update_camera()
	_trigger_accident("RABBIT_AIR" if air else "RABBIT_WATER")
	queue_redraw()



func _process(_delta: float) -> void:
	# 慢镜头按真实时间计时：Engine.time_scale 会缩放 delta，不能用它数 0.7 s。
	var now := Time.get_ticks_msec()
	var real_dt := float(now - _od_last_ms) / 1000.0
	_od_last_ms = now
	_overdrive_tick_real(real_dt)


## FEEL-12 补充 B：不做全局慢镜头。这里只维护 0.7 s 的视觉强调/残影/闪光；
## Engine.time_scale 始终为 1，输入和物理都不被拖慢。
func _overdrive_tick_real(real_dt: float) -> void:
	if _od_emphasis_t > 0.0:
		_od_emphasis_t = maxf(_od_emphasis_t - real_dt, 0.0)
		_od_flash = maxf(_od_flash - real_dt * 3.5, 0.0)
	for i in range(_od_afterimages.size() - 1, -1, -1):
		_od_afterimages[i]["t"] = float(_od_afterimages[i]["t"]) - real_dt
		if float(_od_afterimages[i]["t"]) <= 0.0:
			_od_afterimages.remove_at(i)


func _start_emphasis() -> void:
	_od_emphasis_t = 0.70
	_od_flash = 0.25
	_od_afterimages.clear()
	_camera_pulse_t = CAMERA_PULSE_TIME
	_trigger_shake(false)


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		_up_was_pressed = Input.is_action_pressed("up")
		_update_camera()
		queue_redraw()
		return

	if opening_active:
		# P2-7：开场期间比赛不推进——不缓冲输入、不跑物理，只保持镜头和画面。
		_up_was_pressed = Input.is_action_pressed("up")
		_update_camera()
		queue_redraw()
		return

	_buffer_input(delta)
	# FEEL-09 P0-C：换手锁定按比赛物理时间推进（测试手动步进同样生效）。
	GameManager.tick_shift_lock(delta)
	# CORE-FEEL-07 P0-B：事故事件的时钟跟着真正推进的物理时间走，
	# 测试里手动步进也一致（暂停/开场/结算期间不动）。
	accident_event_time += delta


	# 终点演出：停止判定，让乌龟自己滑过线，短暂停留后进结算。
	if finishing:
		finish_timer -= delta
		turtle.tick(delta, false, false, 0.0, true, Tuning.BOOST_SPEED)
		rabbit.attach(turtle.get_mount_point())
		_update_camera()
		queue_redraw()
		if finish_timer <= 0.0:
			GameManager.finish_race()
		return

	_update_zone()
	turtle.base_speed = current_zone["base_speed"]
	hazard_clock += delta

	hazard_cooldown = maxf(hazard_cooldown - delta, 0.0)
	accident_flash = maxf(accident_flash - delta, 0.0)
	if GameManager.accident_state != "NONE":
		_accident_t += delta
		if rescue_splash_t >= 0.0:
			rescue_splash_t += delta
	else:
		_accident_t = 0.0
	turtle_grace = maxf(turtle_grace - delta, 0.0)
	rabbit_grace = maxf(rabbit_grace - delta, 0.0)
	_shift_jolt_t = maxf(_shift_jolt_t - delta, 0.0)
	_camera_pulse_t = maxf(_camera_pulse_t - delta, 0.0)
	_hitstop_t = maxf(_hitstop_t - delta, 0.0)
	_shake_t = maxf(_shake_t - delta, 0.0)
	if land_splash_t >= 0.0:
		land_splash_t += delta
		if land_splash_t > LAND_SPLASH_TIME:
			land_splash_t = -1.0
	if action_fx_t >= 0.0:
		action_fx_t += delta
		if action_fx_t > ACTION_FX_TIME:
			action_fx_t = -1.0
	if celebrate_t >= 0.0:
		celebrate_t += delta
		if celebrate_t > CELEBRATE_TIME:
			celebrate_t = -1.0
	if shell_dip_t >= 0.0:
		shell_dip_t += delta
		shell_dip_peak = maxf(shell_dip_peak, absf(shell_dip_offset()))
		if shell_dip_t > Tuning.SHELL_DIP_TIME:
			shell_dip_t = -1.0
	_tick_recovery(delta)

	# 救援原型：一次成功/失败演完，停 1.6–2.2 s 再自动重开同一段，方便反复试。
	if rescue_proto_mode and GameManager.accident_state == "NONE" \
			and mount.state == "RIDING":
		rescue_proto_reset_t = maxf(rescue_proto_reset_t - delta, 0.0)
		if rescue_proto_reset_t <= 0.0:
			_arm_rescue_proto(rescue_proto_air_mode)
			return

	# FEEL-10 P0-A：单角色捣乱与真实双人事故分开推进。
	_turtle_blocked_t = maxf(_turtle_blocked_t - delta, 0.0)
	_rabbit_refuse_t = maxf(_rabbit_refuse_t - delta, 0.0)
	_turtle_refuse_t = maxf(_turtle_refuse_t - delta, 0.0)
	_guard_t = maxf(_guard_t - delta, 0.0)
	_guard_age += delta
	_guard_cd = maxf(_guard_cd - delta, 0.0)
	_guard_flash_t = maxf(_guard_flash_t - delta, 0.0)
	_catch_fx_t = maxf(_catch_fx_t - delta, 0.0)
	# FEEL-10 P0-C：状态吊网——乌龟受控时绞盘把网拉高；切换后 0.5 s 到位。
	var net_target := -95.0 if GameManager.current_control == "turtle" else 0.0
	_state_net_shift = move_toward(_state_net_shift, net_target, 190.0 * delta)
	_tick_overdrive(delta)
	_update_true_joint(delta)
	if joint_show_t > 0.0:
		joint_show_t = maxf(joint_show_t - delta, 0.0)
		_hold_joint_pose()
		_update_display()
		_update_camera()
		queue_redraw()
		if joint_show_t <= 0.0:
			_end_joint_show()
		return

	var control: String = GameManager.current_control
	_tick_ignore(delta)
	GameManager.tick_waterlogged(delta)
	var rabbit_down: bool = GameManager.accident_state in [
		"RABBIT_SLIP", "RABBIT_WATER", "RABBIT_AIR", "OXYGEN_OUT"
	]
	var turtle_controlled: bool = control == "turtle" and not turtle.accident
	var rabbit_controlled: bool = control == "rabbit" and not rabbit_down \
		and rabbit_stun <= 0.0 and not showtime_active
	# Phase O：加速只来自“操控乌龟吃下能量海藻”，不是进带自动提速。
	# 吃下后是整组 TURBO：换兔子做动作时也继续，直到该遭遇的障碍通过 + 180 px。
	var boosting: bool = snack_boost_active()
	# FEEL-22：旧“神游”是离开控制时间驱动的第二套失控系统，已停用。
	# 失控只由 bro_meter_role 触发；这里不再 tick BroBrain、不再改漂移量。
	rabbit.drift = 0.0
	rabbit.drift_state = "CALM"
	turtle.drift = 0.0
	turtle.drift_state = "CALM"
	turtle.food_ahead = snack_ahead_distance()
	_tick_mischief(delta)
	_tick_visual_stress(delta)
	rabbit.mischief_pose = false
	# FEEL-22：切换后不继承旧的下潜尾/旧输入。下潜只来自玩家此刻按住的 ↓。
	rabbit.input_down = Input.is_action_pressed("down") and rabbit_controlled
	var vertical := 0.0
	if turtle_controlled and Input.is_action_pressed("down") \
			and not _catch_active and carry_kind != "rescue":
		vertical = 1.0
	if emergency_timer > 0.0:
		# 氧气耗尽：强制上浮，玩家暂时只能看着。
		vertical = -1.0
		boosting = false
	# 旧的辅助下潜、满值不服从、TUBO 自漂都不再参与垂直运动。
	turtle.autodrift_px = 0.0

	# 乌龟跃起：整组上抛，兔子被带动，不需要再按跳。
	# 只受控时触发；SHIFT 只交权，不提供免费动作。
	if turtle_controlled and Tuning.SURFBOARD_PHYSICS \
			and GameManager.accident_state in ["NONE", "RABBIT_AIR"] \
			and not showtime_active and _buffered_ready("up"):
		if turtle.start_leap():
			_consume_buffered("up", "turtle_leap")
			GameManager.feedback.emit(Locale.t("feedback.leap"), "pop")

	_update_snack(delta)

	# 旧的辅助下潜不参与正式物理；下潜只来自玩家当前按住的 ↓。
	turtle.dive_assist_active = false
	var assist_vertical := _tick_dive_assist(delta, turtle_controlled)
	if assist_vertical != 0:
		vertical = assist_vertical
	turtle.tick(delta, turtle_controlled, boosting, vertical,
		true, snack_boost_speed if boosting else Tuning.BOOST_SPEED)
	_tick_bro_catch(delta)

	# 可跳状态的宽限：壳刚沉下去/刚离开台面时还允许 100 ms 的补救跳。
	var jumpable_now: bool = rabbit_controlled and mount.state == "RIDING" \
		and not turtle.leap_active and turtle.is_at_surface()
	if jumpable_now:
		_coyote_t = JUMP_COYOTE_TIME
	else:
		_coyote_t = maxf(_coyote_t - delta, 0.0)

	# FEEL-17：氧气先于抬回/接人结算。耗尽那一帧优先失败，避免同一帧
	# 先完成自动回壳、再被氧气判失败造成不确定结果。
	_update_oxygen(delta)
	# FEEL-22：失败当帧立即停止其余模拟，避免同一帧再触发碰撞/攻击/连击，
	# 让失败画面背后的状态和失败原因保持一致。
	if GameManager.state != GameManager.GameState.RUNNING:
		queue_redraw()
		return
	if showtime_active:
		_tick_showtime(delta)
	else:
		_tick_rabbit(delta, rabbit_controlled, boosting)

	# REBUILD-05 B1：接应/硬直期间不再整段关掉判定（那等于接应无敌）。
	# 兔子在这种状态下不是自由操控角色，它的落水流程自己记账；
	# 乌龟仍然在巡航，真实障碍照常判（_check_hazards 内按角色分开挡）。
	# REBUILD-06 P3：伏击鲨的状态每帧先推进，再判、再顶住：
	# 这一帧画出来的位置就是这一帧用来判的位置。
	_update_ambush_sharks(delta)
	_bounce_cd = maxf(_bounce_cd - delta, 0.0)
	_showtime_cd = maxf(_showtime_cd - delta, 0.0)
	_tick_bird_behaviors(delta)
	_check_bird_attacks(delta)
	_tick_shark_pack(delta)
	_tick_shark_stands(delta)
	_check_shark_attacks(delta)
	if emergency_timer <= 0.0:
		_check_hazards()
		_resolve_turtle_solid()

	# Phase G：daze_time 不再单独触发事故。它只是姿态/短硬直，
	# 每一次有效失误都在发生当下记进 BRO METER，第三格才出联合事故。

	_update_combo()
	_tick_shift_relay(delta)
	_update_lessons()
	_update_snack_lesson()
	_update_z3_warning(delta)
	_update_display()
	_update_camera()
	_update_dock()

	if turtle.position.x >= world_end and not test_no_finish:
		_begin_finish()
		return
	queue_redraw()


func _update_zone() -> void:
	var zone := LevelDataScript.zone_at(turtle.position.x)
	if zone["id"] != current_zone["id"]:
		current_zone = zone
		GameManager.note_zone(zone["id"], zone["name"])
		GameManager.center_message.emit(
			Locale.t("center.zone", [zone["id"], Locale.zone_name(zone["id"])]),
			zone["grade_color"])
		GameManager.hint.emit(Locale.zone_lesson(zone["id"]))
		queue_redraw()


## 首次遇到某一类障碍时，底部中央只教一次“该按什么”，之后靠形状/高度/位置读。
## 不再在世界里挂黄色标签，也不在 HUD 顶部重复“障碍名 + 距离 + 动作”。
## REBUILD-05 G10：教学按“先来后到”。此前 1100 px 内所有没见过的类型会在同一帧
## 各发一次，后发的（更远的）盖掉先发的；首次 BRO DIVE 逼近 log1 时，底栏显示的是
## 1050 px 外鲨鱼的动作，和左上的「BRO DIVE 现在！」方向相反。现在只发最近的一组，
## 且最近的障碍没过完之前不发更远的新类型。
func _update_lessons() -> void:
	if quiet_lessons:
		return
	# FEEL-36：跳过教学后，第一次 BRO DIVE 也给一句动作提示；教学里 test_no_lessons 已关闭。
	if not test_no_lessons and not first_dive_hint_shown:
		for g in hazard_groups:
			if String(g.get("group", "")) != "log1":
				continue
			var d: float = _group_start(g) - turtle.position.x
			if d >= 200.0 and d <= 760.0 and GameManager.current_control == "rabbit":
				first_dive_hint_shown = true
				GameManager.hint.emit(Locale.t("hint.first_bro_dive"))
				break
	if test_no_lessons or lesson_prompt_count >= 4:
		return
	# 救援/事故期间不要再弹“下一组障碍”的首次教学，否则会把救援提示顶掉。
	if GameManager.accident_state != "NONE":
		return
	_update_motion_lesson()
	var frontier := 1.0e9
	for g in hazard_groups:
		var clear_d: float = LevelDataScript.group_end(g) \
			+ Tuning.LESSON_CLEAR_BEHIND - turtle.position.x
		if clear_d > 0.0 and clear_d < frontier:
			frontier = clear_d
	for g in hazard_groups:
		if _shark_arena_hides(g):
			continue
		var kind: String = g["kind"]
		var key := _lesson_key(g)
		if lesson_seen.has(key):
			continue
		# REBUILD-05 G21：已经撞过的这一组不再补教——补教是给“下一组”的。
		# 乌龟碰撞不产生事故状态（只记 TURTLE_WAVE），重新武装后同一帧就会
		# 走到这里；不挡的话玩家会在刚撞上的那一组原地听到同一句话。
		if hit_groups.has(String(g["group"])):
			continue
		var d: float = LevelDataScript.group_start(g) - turtle.position.x
		if d < 0.0 or d > Tuning.PROMPT_RANGE:
			continue
		# 前面还压着没过完的障碍时，不替更远的新类型发教学。
		if LevelDataScript.group_end(g) + Tuning.LESSON_CLEAR_BEHIND \
				- turtle.position.x > frontier:
			continue
		lesson_seen[key] = true
		GameManager.prompt.emit(_lesson_prompt(kind, String(g.get("identity", "")),
			bool(g.get("dual", false)), String(g.get("combo", ""))))
		return


## FEEL-37：5 组 2 s 级连招单独发一次“上一组→下一组”的提示。
## FEEL-40：Z1 的 gate1→rock2 与 Z2 的 rock6→gate4 也走同一条提示通道；
## 前者不压时间，后者留 2.93 s，让玩家练习“提前换人”。
const TIGHT_RELAY_COMBOS := [
	"gate6_log5", "log5_bird6", "log7_rock10", "shark9_bird8", "gate8_bird9",
]
const CHAIN_PROMPTS := {
	"gate1_rock2": "prompt.relay_gate1_rock2",
	"shark3_beam3": "prompt.relay_shark3_beam3",
	"rock4_gate3": "prompt.relay_rock4_gate3",
	"gate3_bird3": "prompt.relay_gate3_bird3",
	"rock6_gate4": "prompt.relay_rock6_gate4",
	"shark5_bird5": "prompt.relay_shark5_bird5",
	"gate6_log5": "prompt.relay_gate6_log5",
	"log5_bird6": "prompt.relay_log5_bird6",
	"log7_rock10": "prompt.relay_log7_rock10",
	"shark9_bird8": "prompt.relay_shark9_bird8",
	"gate8_bird9": "prompt.relay_gate8_bird9",
}
const CHAIN_FAIL_COMBOS := [
	"gate1_rock2", "shark3_beam3", "rock4_gate3", "gate3_bird3",
	"rock6_gate4", "shark5_bird5",
	"gate6_log5", "log5_bird6", "log7_rock10", "shark9_bird8", "gate8_bird9",
]


## FEEL-09 P0-A：Z2 换了身份的海鸥/鲨鱼/礁拱要单独教一次。
## 默认身份仍按 kind 记（一局一次）；Z2 的吊网/鳗鱼/船闸用
## “kind|identity” 作键，玩家在 Z1 学过海鸥也不会把吊网当成海鸥。
func _lesson_key(group: Dictionary) -> String:
	var kind := String(group["kind"])
	var identity := String(group.get("identity", ""))
	var fallback := String(LevelDataScript.IDENTITY_BY_KIND.get(kind, kind))
	var out := kind
	if identity == "" or identity == fallback:
		out = kind
	else:
		out = kind + "|" + identity
	# FEEL-37：双解要单独教一次。否则玩家在 beam1/bird1 已经学过单答案，
	# 到 beam4/bird6/rock6 时 lesson_seen 直接跳过，双解提示永远不显示。
	if bool(group.get("dual", false)):
		out += "|dual"
	# 紧连招也要单独教一次，不能因为“这个 kind 见过”就吞掉连招提示。
	if CHAIN_PROMPTS.has(String(group.get("combo", ""))):
		out += "|relay"
	return out


## REBUILD-05 G6：13 组动态障碍此前没有任何教学——第一组会动的岩上下起伏时，
## 玩家只会以为判定飘了。每区第一组会动的障碍进入 560 px 时底栏提一句；同区不再重复。
## 事故期间由 _update_lessons 的早退压住，不抢救援提示。
## CORE-FEEL-08 P1-C：文案按身份走——浮标讲锚绳、吊装箱讲吊钩、漂流货讲浪，
## 同一句“会动”不再套在三种来历不同的东西上。
const MOTION_HINT_BY_IDENTITY := {
	"buoy": "hint.motion_buoy",
	"dock_crate": "hint.motion_hoist",
	"drift_crate": "hint.motion_cargo",
	"canal_eel": "hint.motion_eel",
}

func _update_motion_lesson() -> void:
	if quiet_lessons:
		return
	for g in hazard_groups:
		var moved: Dictionary = g.get("motion", {})
		if moved.is_empty():
			continue
		var gs: float = LevelDataScript.group_start(g)
		var d: float = gs - turtle.position.x
		if d < 0.0 or d > MOTION_HINT_RANGE:
			continue
		var zid: int = int(LevelDataScript.zone_at(gs)["id"])
		if motion_lesson_zone == zid:
			continue
		motion_lesson_zone = zid
		var identity := String(g.get("identity", ""))
		GameManager.hint.emit(Locale.t(String(MOTION_HINT_BY_IDENTITY.get(identity, "hint.motion"))))
		return


## 首次教学文案按“当前控的是谁”取：已经控乌龟时再叫玩家按 SHIFT，
## 会把人送到兔子身上，正好错过这一组。兔子专属障碍提示先换回来，
## 乌龟专属障碍去掉多余的 SHIFT。
func _lesson_prompt(kind: String, identity: String = "", dual: bool = false,
		combo: String = "") -> String:
	var on_rabbit := GameManager.current_control == "rabbit"
	# FEEL-37/40：连招先讲“上一组之后马上做什么”，比只讲当前障碍更有用。
	if CHAIN_PROMPTS.has(combo):
		return Locale.t(String(CHAIN_PROMPTS[combo]))
	# FEEL-41：潮汐岩的兔子答案是“看浪谷跳”，风险是时机；乌龟答案仍是耗氧。
	if dual and kind == "SURFACE_ROCK" and identity == "buoy":
		return Locale.t("prompt.dual_tide_rock" if on_rabbit else "prompt.dual_tide_rock_on_turtle")
	# FEEL-36/37：双解障碍要把两条路都讲清楚，否则玩家不知道乌龟下潜也成立。
	if dual:
		match kind:
			"LOW_BEAM":
				return Locale.t("prompt.dual_beam" if on_rabbit else "prompt.dual_beam_on_turtle")
			"LOW_BIRD":
				return Locale.t("prompt.dual_bird" if on_rabbit else "prompt.dual_bird_on_turtle")
			"SURFACE_ROCK":
				return Locale.t("prompt.dual_rock" if on_rabbit else "prompt.dual_rock_on_turtle")
	# FEEL-09 P0-A：Z2 的吊网/鳗鱼/船闸有独立文案，说清“为什么这里要换人”。
	match identity:
		"cargo_net":
			return Locale.t("prompt.net" if on_rabbit else "prompt.net_from_turtle")
		"canal_eel":
			return Locale.t("prompt.eel" if on_rabbit else "prompt.eel_on_turtle")
		"sluice_gate":
			return Locale.t("prompt.sluice" if on_rabbit else "prompt.sluice_on_turtle")
	match kind:
		"SURFACE_ROCK":
			return Locale.t("prompt.jump" if on_rabbit else "prompt.jump_from_turtle")
		"LOW_BEAM", "LOW_BIRD":
			return Locale.t("prompt.crouch" if on_rabbit else "prompt.crouch_from_turtle")
		"SHARK":
			return Locale.t("prompt.leap" if on_rabbit else "prompt.leap_on_turtle")
		"DIVE_GATE":
			return Locale.t("prompt.dive" if on_rabbit else "prompt.dive_on_turtle")
		"FLOATING_LOG":
			return Locale.t("prompt.combo" if on_rabbit else "prompt.combo_from_turtle")
		"HIGH_WALL":
			return Locale.t("prompt.ollie" if on_rabbit else "prompt.ollie_on_turtle")
	return ""


func _update_snack_lesson() -> void:
	if quiet_lessons:
		return
	# 第一次看到食物时讲一次：判定只看乌龟的位置，谁在操控都能吃；
	# ↑/↓ 可以选择避开，不吃没有惩罚。只发提示，不改赛道布局，也不替玩家吃。
	if snack_lesson_seen:
		return
	var d := snack_ahead_distance()
	if d < 0.0:
		return
	snack_lesson_seen = true
	GameManager.hint.emit(Locale.t("hint.snack"))


## P1-6：Z3 复杂障碍（浮木/高墙）的屏幕右缘预警。
## 只取“前方最近的一组”，并且在 1300 px（Z3 基速 260 → 5.0 s）内才亮：
##   - 障碍还在画面外时图标钉在右缘，不提前露出它的世界位置；
##   - 只读这一组的真实 kind（抽取后的结果），不遍历/展示后面的障碍池。
func _update_z3_warning(delta: float) -> void:
	if int(current_zone["id"]) != 3 or GameManager.accident_state != "NONE":
		_clear_z3_warning()
		return
	var best: Dictionary = {}
	var best_d := 1.0e9
	for g in hazard_groups:
		var kind: String = String(g["kind"])
		if kind != "FLOATING_LOG" and kind != "HIGH_WALL":
			continue
		var key: String = String(g["group"])
		if bool(passed_groups.get(key, false)) or bool(hit_groups.get(key, false)):
			continue
		var start_x: float = LevelDataScript.group_start(g)
		var d: float = start_x - turtle.position.x
		if d < 0.0:
			continue
		if d > Z3_WARN_RANGE:
			break   # 数组按 x 排序，后面的只会更远
		if d < best_d:
			best_d = d
			best = g
	if best.is_empty():
		_clear_z3_warning()
		return
	var key2 := String(best["group"])
	if key2 != z3_warn_group:
		z3_warn_group = key2
		z3_warn_kind = String(best["kind"])
		z3_warn_t = 0.0
	z3_warn_dist = best_d
	z3_warn_t += delta


func _clear_z3_warning() -> void:
	z3_warn_group = ""
	z3_warn_kind = ""
	z3_warn_dist = -1.0
	z3_warn_t = 0.0


func z3_warn_active() -> bool:
	return z3_warn_group != ""


## 食物遭遇表：缓存 + 按 boost_lanes 条数失效（旧测试 clear() 即关闭食物）。
func _snack_list() -> Array:
	var sig := boost_lanes.size()
	if _snack_cache_sig != sig:
		_snack_cache = LevelDataScript.snack_encounters(boost_lanes)
		_snack_cache_sig = sig
	return _snack_cache


## Phase P：把种子和 9 条抽取结果打进日志；同一句 `LEVEL SEED n` 可原样复现。
func _log_snack_draws() -> void:
	print("LEVEL SEED %d" % level_seed)
	for d in snack_draws:
		var before := ""
		var gi := int(d["group_index"])
		if gi >= 0 and gi < LevelDataScript.GROUPS.size():
			before = String(LevelDataScript.GROUPS[gi]["kind"])
		print("SNACK DRAW #%d group=%s zone=%d kind=%s%s" % [
			int(d["index"]) + 1, String(d["group"]), int(d["zone"]), String(d["kind"]),
			" (fixed)" if bool(d.get("fixed", false)) else " (was %s)" % before])


## 最近一个未吃食物在前方的距离；没有则 -1。
func snack_ahead_distance() -> float:
	var best := -1.0
	var x: float = turtle.position.x
	for enc in _snack_list():
		if bool(enc.get("eaten", false)):
			continue
		var d := float(enc["x"]) - x
		if d < 0.0 or d > Tuning.PROMPT_RANGE:
			continue
		if best < 0.0 or d < best:
			best = d
	return best


func snack_boost_active() -> bool:
	return snack_boost_until_x > 0.0 and turtle.position.x < snack_boost_until_x


## P4：兔子的跳跃强化窗口（与乌龟 TURBO 互不覆盖，谁吃谁生效）。
func snack_rabbit_boost_active() -> bool:
	# FEEL-47：高跳保留到下一次兔子普通起跳，而不是按 x 过期。
	return rabbit.snack_jump_pending


## P4：谁会在这一刻吃到。控制谁就谁吃；控制者的身体得够得到食物（巡航深度、
## 不在跃起、兔子在壳上且没晕）。够不到就是错过——没有惩罚。
func _snack_eater() -> String:
	if GameManager.accident_state != "NONE":
		return ""
	if turtle.leap_active:
		return ""
	if absf(turtle.position.y - Tuning.NEUTRAL_DEPTH) > 40.0:
		return ""
	if GameManager.current_control == "rabbit":
		if mount.state == "RIDING" and not rabbit.is_airborne() \
				and rabbit.state != "STUNNED":
			return "rabbit"
		return ""
	return "turtle"


## CORE-FEEL-07 P1-C：给 HUD 用的“现在谁吃”。空字符串 = 这一刻够不到食物
## （跃起、不在巡航深度、兔子晕着或没骑在壳上），HUD 会明说“够不到”，
## 而不是让玩家以为按键没反应。
func snack_who_eats() -> String:
	return _snack_eater()


## 前方 range 内最近一个未吃食物的 x；没有则 -1。只用于争抢表现。
func _nearest_snack_ahead(range_px: float) -> float:
	var best := -1.0
	var x: float = turtle.position.x
	for enc in _snack_list():
		if bool(enc.get("eaten", false)):
			continue
		var d := float(enc["x"]) - x
		if d < 0.0 or d > range_px:
			continue
		if best < 0.0 or d < best:
			best = float(enc["x"])
	return best


## 每帧检查接触窗口。P4 起“谁吃”由当前操控决定：
## 控制乌龟 = 原有 TURBO + 冷静；控制兔子 = 兔子自己的跳跃强化。
## 两个人都在壳上时食物只有一个——SHIFT 决定给谁，不吃不扣任何东西。
func _update_snack(delta: float) -> void:
	snack_gulp_t = maxf(snack_gulp_t - delta, 0.0)
	if snack_boost_until_x > 0.0 and turtle.position.x >= snack_boost_until_x:
		snack_boost_until_x = -1.0
		snack_boost_speed = 0.0
	if rabbit_boost_until_x > 0.0 and turtle.position.x >= rabbit_boost_until_x:
		rabbit_boost_until_x = -1.0
		rabbit.jump_boost = 1.0
	snack_interest_x = _nearest_snack_ahead(Tuning.SNACK_INTEREST_PX)
	if GameManager.accident_state != "NONE":
		return
	var eater := _snack_eater()
	if eater == "":
		return
	for enc in _snack_list():
		if bool(enc.get("eaten", false)):
			continue
		if absf(turtle.position.x - float(enc["x"])) > LevelDataScript.SNACK_CONTACT_PX:
			continue
		_eat_snack(enc, eater)
		return


func _eat_snack(enc: Dictionary, by: String) -> void:
	enc["eaten"] = true
	snack_last_eaten = String(enc["obstacle_group"])
	snack_last_by = by
	snack_gulp_t = 0.45
	snack_gulp_x = float(enc["x"])
	var end_x := 0.0
	for g in hazard_groups:
		if String(g["group"]) == String(enc["obstacle_group"]):
			end_x = _group_end(g)
			break
	_relieve_visual_stress(by, 1.0)
	if by == "rabbit":
		# 兔子吃：自己的跳跃强化，乌龟不加速也不冷静——这正是“给谁吃”的取舍。
		rabbit_boost_until_x = end_x + Tuning.RABBIT_SNACK_TAIL
		rabbit.arm_snack_jump(Tuning.RABBIT_SNACK_JUMP_SCALE)
		snack_gulp_by_player = false
		GameManager.feedback.emit(Locale.t("feedback.snack_rabbit"), "pop")
		print("SNACK eaten by=rabbit x=%.0f obstacle=%s jump_boost=%.2f until=%.0f" % [
			float(enc["x"]), String(enc["obstacle_group"]),
			rabbit.jump_boost, rabbit_boost_until_x])
		return
	# 乌龟吃：原有 TURBO。食物是照顾乌龟的方式：饥饿/烦躁/神游明显恢复。
	if turtle_brain != null:
		turtle_brain.calm()
	snack_boost_speed = float(current_zone["base_speed"]) * LevelDataScript.SNACK_BOOST_SCALE
	snack_boost_until_x = end_x + LevelDataScript.SNACK_BOOST_TAIL
	var fed_by_player: bool = GameManager.current_control == "turtle"
	snack_gulp_by_player = fed_by_player
	if fed_by_player:
		GameManager.snack_switch_count += 1
		GameManager.add_score(Tuning.SNACK_SWITCH_BONUS, "snack_switch")
	GameManager.feedback.emit(Locale.t(
		"feedback.turbo_switch" if fed_by_player else "feedback.turbo"), "pop")
	print("SNACK eaten by=turtle x=%.0f obstacle=%s boost_until=%.0f speed=%.0f" % [
		float(enc["x"]), String(enc["obstacle_group"]),
		snack_boost_until_x, snack_boost_speed])


func _begin_finish() -> void:
	if finishing:
		return
	finishing = true
	finish_timer = FINISH_DELAY
	GameManager.finalize_run()
	GameManager.center_message.emit(
		Locale.t("center.finish", [
			GameManager.grade, Locale.grade_title(GameManager.grade)]),
		Color(1.0, 0.85, 0.25))
	queue_redraw()


## ---- TBB-SHIFT-FEEL-03 §3：输入缓存 ----
## 只缓存“上”的按下；每帧老化，超过 120 ms 自动清除。
## 交付规则：按下后最多允许一次 SHIFT 交接（同一动作不能追着连换几次人重复执行）。
func _buffer_input(delta: float) -> void:
	# CORE-FEEL-08 P0-A：还在“没听见”的延迟窗口里，这次按下不算过期——
	# 延迟结束后仍给它完整 120 ms 的缓存窗口，走神不是吃掉按键。
	if _buf_delay <= 0.0:
		_buf_age += delta
	if _buf_action != "" and _buf_age > _input_buffer_limit():
		_buf_action = ""
	# 用“按下沿”而不是 is_action_just_pressed：手动步进测试里同一引擎帧内
	# 连续调用 _physics_process 时 just_pressed 不会自己复位，会被反复记成新按下。
	var up_now: bool = Input.is_action_pressed("up")
	if up_now and not _up_was_pressed:
		# 真实按键已在 _unhandled_input 里按事件顺序记过（含当时的 shift_count），
		# 这里只补测试注入/没有事件的情况，避免覆盖掉更准确的记录。
		if Time.get_ticks_msec() - _buf_event_msec > 5:
			_note_up_input()
	_up_was_pressed = up_now
	var space_now := Input.is_action_pressed("pop")
	if space_now and not _space_was_pressed:
		_try_role_skill()
	_space_was_pressed = space_now


## 按键事件发生时立刻记录：此刻的 shift_count 就是“按下时已经换了几次人”。
func _note_up_input() -> void:
	# CORE-FEEL-08 P0-A：走神的角色先“没听见”，过 _buf_delay 才把这次按下
	# 送进缓存。不丢键：延迟结束后仍在缓冲窗口内；按住不放的第二次输入不再加。
	var who: String = GameManager.current_control
	var react := _drift_react_delay(who)
	if react > 0.0:
		_buf_delay = maxf(_buf_delay, react)
		# 只从“坐不住”起报：40–70 ms 的轻延迟报出来反而是噪音。
		if react >= 0.10:
			_note_drift_lag(who, "up")
	_buf_action = "up"
	_buf_age = 0.0
	_buf_shift_count = GameManager.shift_count
	_buf_event_msec = Time.get_ticks_msec()


func _buffered_ready(action: String) -> bool:
	if _buf_delay > 0.0:
		return false
	if _buf_action != action:
		return false
	if _buf_age > _input_buffer_limit():
		_buf_action = ""
		return false
	if GameManager.shift_count - _buf_shift_count > 1:
		# 连换两次以上还留着，就是“缓存追着人跑”；直接作废。
		_buf_action = ""
		return false
	return true


func _input_buffer_limit() -> float:
	return INPUT_BUFFER_TIME if input_buffer_override < 0.0 else input_buffer_override


func _consume_buffered(action: String, by: String) -> void:
	_buf_action = ""
	input_buffer_log.append({
		"action": action, "by": by, "age": _buf_age,
		"shifts": GameManager.shift_count - _buf_shift_count,
	})


## PLAYFUL-04 §1/§3：接住之后连续抬回壳上（不瞬移）。
## 距离很近时保持旧手感直接吸附；超过 CARRY_SNAP_DIST 才走抬升。
func _begin_carry(kind: String, mp: Vector2,
		max_time: float = Tuning.CARRY_MAX_TIME, real_catch: bool = true) -> void:
	var from: Vector2 = rabbit.position
	var dist: float = from.distance_to(mp)
	GameManager.pickup_window = false
	carry_real_catch = real_catch
	if dist <= Tuning.CARRY_SNAP_DIST:
		rabbit.attach(mp)
		mount.mark_riding()
		_apply_carry_result(kind, carry_real_catch)
		return
	carry_from = from
	carry_t = 0.0
	carry_dur = clampf(dist / Tuning.CARRY_SPEED,
		Tuning.CARRY_MIN_TIME, max_time)
	carry_kind = kind
	carry_max_step = 0.0
	mount.mark_carrying(carry_dur)


func _tick_carry(delta: float) -> void:
	carry_t += delta
	mount.carry_timer = maxf(mount.carry_timer - delta, 0.0)
	var k: float = clampf(carry_t / maxf(carry_dur, 0.001), 0.0, 1.0)
	var ease: float = k * k * (3.0 - 2.0 * k)
	# FEEL-30：救援 carry 时让壳同步浮回水面，避免兔子被抬到深水壳上再“卡一下”。
	if carry_kind == "rescue":
		turtle.position.y = move_toward(turtle.position.y, surface_ref(), 280.0 * delta)
	var target: Vector2 = turtle.get_mount_point()
	var next: Vector2 = carry_from.lerp(target, ease)
	# FEEL-29：兔子已经落在壳前面时，接应不再把它往左拽回壳心。
	# x 只允许向前/保持，等壳自己追上来；y 仍按原曲线落到壳上。
	next.x = maxf(next.x, rabbit.position.x)
	carry_max_step = maxf(carry_max_step, next.distance_to(rabbit.position))
	rabbit.position = next
	if k >= 1.0 and absf(rabbit.position.x - target.x) <= Tuning.CARRY_SNAP_DIST:
		if carry_kind == "rescue_return" and GameManager.oxygen <= 0.0:
			GameManager.finish_failure("OXYGEN_OUT")
			return
		var kind: String = carry_kind
		carry_kind = ""
		carry_dur = 0.0
		rabbit.attach(target)
		mount.mark_riding()
		_apply_carry_result(kind, carry_real_catch)


## 抬升结束才记成功：接住的瞬间先给表现，位置到了壳上才恢复骑乘状态。
## G5/G7：`real_catch` 只给真正的“接住”；普通跳跃落回壳上也走这条记账路径，
## 那一下是日常落壳——计数照旧 +1，但不弹庆祝、也不喊「好接！」（否则每次跳跃一次）。
func _apply_carry_result(kind: String, real_catch := true) -> void:
	if kind == "pickup":
		GameManager.pickup_count += 1
		_spawn_land_splash(rabbit.position)
		# G9：兔子压上壳的那一下，壳往下沉一点；真接住比日常落壳重。
		_shell_dip(Tuning.SHELL_DIP_CATCH if real_catch else Tuning.SHELL_DIP_ROUTINE)
		if real_catch:
			GameManager.pickup_success.emit()
			# G5：接住了也让兔子本体弹一下，和连招成功共用同一套画法偏移。
			_celebrate("pickup")
	elif kind == "rescue":
		rescue_auto_blocked_t = 0.0
		rescue_auto_disabled = false
		# G9：救回是最重的一拍——壳被按下去再弹回来。
		_shell_dip(Tuning.SHELL_DIP_RESCUE)
		GameManager.accident_state = "NONE"
		# B1：落水事故到这一帧就结束了。把落水时上的 3 s 冷却压回到
		# RESCUE_GRACE_TIME（1.2 s，和 rabbit_grace 同一档），
		# 既不会“接应成功了还要背一段看不见的惩罚冷却”，也不会一落地就无缝再挨一下。
		hazard_cooldown = minf(hazard_cooldown, Tuning.RESCUE_GRACE_TIME)
		GameManager.oxygen = maxf(GameManager.oxygen, Tuning.OXYGEN_RECOVERED)
		rabbit_grace = Tuning.RESCUE_GRACE_TIME
		GameManager.rescue_success_count += 1
		# REBUILD-05 D2：重聚本身是正向的一拍，不只是“事故结束”。
		# 奖励只加不减：不追接的玩家不会因此被多扣，救援失败仍走原来的账。
		GameManager.add_score(Tuning.RESCUE_SWITCH_BONUS, "rescue_switch")
		GameManager.feedback.emit(Locale.t("feedback.rescue_reunion"), "bro")
		# G5：救回比接人重一档，弹跳也放在重聚这一刻（落水被抓回时还在水里，不动）。
		_celebrate("rescue")
		if rabbit_brain != null:
			rabbit_brain.calm()
		if turtle_brain != null:
			turtle_brain.calm()
		GameManager.rescue_done.emit()
	elif kind == "rescue_return":
		_finish_rescue_return()


## 没接住时的恢复终点：短暂、可恢复，而且只在这里清事故状态。
func _finish_rescue_return() -> void:
	GameManager.complaint_role = ""
	GameManager.complaint_t = 0.0
	rescue_auto_blocked_t = 0.0
	rescue_auto_disabled = false
	GameManager.accident_state = "NONE"
	GameManager.oxygen = maxf(GameManager.oxygen, Tuning.OXYGEN_RECOVERED)
	rabbit_grace = Tuning.GRACE_TIME
	GameManager.rescue_done.emit()


func _near_bro_dive_log() -> bool:
	## FEEL-29：兔子在空中、且壳正接近一组浮木——这是 BRO DIVE 的接人场景。
	## 提前 320 px 就把兔子限速，避免“按住加速起跳”把壳甩开后再被拽回。
	var tx: float = turtle.position.x
	for g in hazard_groups:
		if String(g.get("kind", "")) != "FLOATING_LOG":
			continue
		if destroyed_groups.has(String(g.get("group", ""))):
			continue
		if tx >= _group_start(g) - 320.0 and tx <= _group_end(g) + 80.0:
			return true
	return false


func _tick_rabbit(delta: float, rabbit_controlled: bool, boosting: bool) -> void:
	# FEEL-29：BRO DIVE 接应时把兔子的空中水平速度收到壳速附近。
	# 玩家按住 →（加速）起跳再 SHIFT 下潜时，兔子原本会以 +150 px/s 甩开壳，
	# 接应只能从后面把兔子往回拉。浮木附近从起跳就限速，换人早晚都不会甩开。
	rabbit.air_speed_cap = INF
	if mount.state == "AIRBORNE" and not turtle.leap_active \
			and GameManager.accident_state == "NONE" and _near_bro_dive_log():
		rabbit.air_speed_cap = maxf(turtle.speed + 12.0, 0.0)
	# FEEL-10 P0-A/B：捣乱/满值不服从时，兔子短暂不听指挥；另一角色仍可操作。
	if _rabbit_refuse_t > 0.0:
		rabbit_controlled = false
	# BRO OLLIE：乌龟跃起期间，兔子仍可以主动蹬踏离壳（独立的一次弹跳）。
	# 这是高墙的唯一解法：乌龟的跃起只把壳送进窗口，壳上的兔子会撞墙楣，
	# 必须由玩家切到兔子补这一下，越过墙楣顶再落回壳上。
	if rabbit_controlled and mount.state == "RIDING" and turtle.leap_active \
			and _buffered_ready("up"):
		rabbit.launch(turtle.get_mount_point(), turtle.speed,
			Tuning.OLLIE_KICK_VELOCITY)
		_consume_buffered("up", "ollie")
		mount.mark_airborne()
		_arm_dive_assist()
	# 乌龟跃起期间兔子被整组带动：不抢跳、不趴低，只跟着壳走。
	# 组合漂浮物里兔子先跳、再 SHIFT 给乌龟下潜——跳跃不会被换人取消，
	# 因为 tick_air 不看控制权，只受重力。
	if rabbit_controlled and mount.state == "RIDING" and not turtle.leap_active \
			and turtle.is_at_surface() and _buffered_ready("up"):
		rabbit.launch(turtle.get_mount_point(), turtle.speed, 0.0, _log_jump_scale())
		_consume_buffered("up", "jump")
		_coyote_t = 0.0
		mount.mark_airborne()
		_arm_dive_assist()
	elif rabbit_controlled and mount.state == "RIDING" and not turtle.leap_active \
			and not turtle.is_at_surface() and _coyote_t > 0.0 \
			and _buffered_ready("up"):
		# 宽容跳：壳刚沉下去，但还在 100 ms 内——仍按“从壳上起跳”处理。
		# 初速/重力不变，只是把“已经不能站”这件事晚 100 ms 生效。
		rabbit.launch(turtle.get_mount_point(), turtle.speed, 0.0, _log_jump_scale())
		_consume_buffered("up", "coyote_jump")
		_coyote_t = 0.0
		mount.mark_airborne()
		_arm_dive_assist()

	if mount.state == "RIDING":
		if rabbit.state == "FALLING_WATER" or rabbit.state == "PASSED_OUT":
			# FEEL-45：状态不一致时也不能把已经落水的兔子按回壳上；
			# 只让位置继续按自己的速度走，不改写救援状态。
			rabbit.position += rabbit.velocity * delta
		elif rabbit_stun > 0.0:
			rabbit.tick_stun(delta, turtle.get_mount_point())
		elif turtle.leap_active:
			rabbit.tick_riding(delta, turtle.get_mount_point(), false, false, false)
		else:
			rabbit.tick_riding(delta, turtle.get_mount_point(), rabbit_controlled,
				boosting,
				not (GameManager.accident_state in ["RABBIT_SLIP", "RABBIT_WATER"]),
				rabbit_grace > 0.0)
	elif mount.state == "AIRBORNE":
		rabbit.tick_air(delta, rabbit_controlled)
	elif mount.state == "CARRYING":
		_tick_carry(delta)
	elif mount.state == "RESCUING":
		# 失败恢复也让兔子“被冲回来”，不要瞬移到壳上。
		# 目标是乌龟此刻的真实落点（不再是旧水线 SURFACE_Y+12，避免差 36 px 的吸附）。
		rabbit.position = rabbit.position.move_toward(
			turtle.get_mount_point(), 560.0 * delta)

	if mount.state == "AIRBORNE":
		# 跃起期间壳不收人：BRO OLLIE 的兔子正处在墙楣上方（离壳 60～120 px），
		# 半空收人会把兔子直接拽回壳上、拖进墙楣。落回必须等跃起结束、兔子下坠到位。
		var mp: Vector2 = turtle.get_mount_point()
		var dy: float = rabbit.position.y - mp.y
		var caught: bool = not turtle.leap_active \
			and mount.can_pickup(rabbit.position, rabbit.velocity.y, mp,
				turtle.is_at_surface(), turtle.is_rising())
		# REBUILD-05 G8：提示环是一个“落壳走廊”，比收人窗口早约 0.3 s 亮起。
		# 收人仍只看 caught（PICKUP_DY_MIN 当帧吸附），显示不看它——
		# 否则窗口同帧被消费，绿环永远只是一闪。条件与收人同源：
		# 正在下落、壳在水面或上浮、横向对准，只是纵向从 -150 起。
		GameManager.pickup_window = not turtle.leap_active \
			and rabbit.velocity.y >= 0.0 \
			and (turtle.is_at_surface() or turtle.is_rising()) \
			and absf(rabbit.position.x - mp.x) <= Tuning.PICKUP_DX \
			and dy >= Tuning.PICKUP_HINT_DY_MIN and dy <= Tuning.PICKUP_DY_MAX
		if caught:
			# 普通落壳：壳在水面，兔子从上方落进常规窗口（dy ≥ -60）。
			# 这一路保持旧手感的当帧吸附，和帧率无关；120 ms 内的 ↑ 也在这帧交付。
			if dy >= Tuning.PICKUP_DY_MIN:
				GameManager.pickup_window = false
				rabbit.attach(mp)
				mount.mark_riding()
				# 日常落壳：记账照旧，但不放 G5 的庆祝弹跳（那是“接住”的信号）。
				_apply_carry_result("pickup", false)
				if rabbit_controlled and not turtle.leap_active \
						and turtle.is_at_surface() and _buffered_ready("up"):
					rabbit.launch(turtle.get_mount_point(), turtle.speed, 0.0,
						_log_jump_scale())
					_consume_buffered("up", "buffered_jump")
					_coyote_t = 0.0
					mount.mark_airborne()
					_arm_dive_assist()
			else:
				# BRO DIVE 深接：壳还在下面、正往上浮。这一段要看得见抬升，
				# 而且抬升期间不接缓冲跳——那是另一个动作，不能叠进来。
				_begin_carry("pickup", mp, Tuning.CARRY_MAX_TIME, _near_bro_dive_log())
		elif rabbit.position.y > SURFACE_Y + 40.0 and rabbit.velocity.y > 0.0:
			# REBUILD-05 G3：同样是“兔子落水”，但如果是壳一直停在水下、
			# 兔子落壳时擦到水线（B3 实测的按住 ↓ 不放），只说“兔子落水”
			# 等于不告诉玩家做错了什么。这里补一句具体原因；判定与扣分不变。
			if turtle.diving:
				GameManager.hint.emit(Locale.t("hint.dive_deep"))
			# P0-B 补丁：壳刚被浮木顶住、兔子从那一跳直接落水时，这是同一笔失败
			# 的下游后果——物理后果（落水/救援）照常，但不再记第二格 BRO METER。
			var parent := _fall_consequence_event()
			if parent.is_empty():
				_trigger_accident("RABBIT_WATER")
			else:
				_note_fall_absorbed(parent)
				_trigger_accident("RABBIT_WATER", false)
	else:
		GameManager.pickup_window = false

	# Phase G：滑移到临界不再自动落水。兔子被撞的当下已经记了一格 BRO METER，
	# 不能再用同一串碰撞在几秒后追罚第二次。


func _tick_recovery(delta: float) -> void:
	# 兔子落水/还在往下掉：乌龟会明显慢下来找人。这是事故代价，不是接人辅助
	# （兔子位置仍然完全按物理走，玩家仍然必须自己下潜）。
	turtle.speed_cap = Tuning.RESCUE_SLOW_SPEED \
		if mount.state in ["RESCUE_FALLING", "RESCUE_ACTIVE"] else 1.0e9
	if mount.state == "RESCUE_AIR":
		# 方案 2 原型：兔子在空中下落；只有乌龟正在跃起时才有高度接住。
		rabbit.velocity.y = minf(rabbit.velocity.y
			+ Tuning.RESCUE_AIR_GRAVITY * delta, 900.0)
		rabbit.position.y += rabbit.velocity.y * delta
		var air_expired: bool = mount.tick_rescue_air(delta)
		var air_mp: Vector2 = turtle.get_mount_point()
		if mount.can_rescue_air_catch(rabbit.position, air_mp, turtle.leap_active):
			_rescue_catch(air_mp)
		elif turtle.position.x > rabbit.position.x + 280.0:
			_rescue_miss("passed_by")
		elif air_expired:
			_rescue_miss("air_expired")
		elif rabbit.position.y >= Tuning.RESCUE_AIR_WATER_Y:
			_rescue_miss("air_waterline")

	if mount.state == "RESCUE_FALLING":
		# §6 真实下落：世界坐标、方向、重力都保留；没人接就一直掉到水线。
		# 这一段不计时——水花出现之前，救援窗口还没开始。
		rabbit.velocity.y = minf(rabbit.velocity.y + Tuning.RESCUE_FALL_GRAVITY * delta,
			Tuning.RESCUE_FALL_MAX_VY)
		rabbit.position += rabbit.velocity * delta
		rescue_prev_pos = rabbit.position
		if rabbit.position.y >= Tuning.RESCUE_ENTRY_Y:
			# 穿水这一帧只走“下落 → 水花”，不再叠加一帧水中位移：
			# 否则同一帧会被积分两次（实测多走 7 px，看起来像一次小瞬移）。
			_splash_water()
	elif mount.state == "RESCUE_ACTIVE":
		# 兔子在水里：横向被水拖住、缓慢下沉。落点就是真实落点，乌龟要真的追上来。
		var mp: Vector2 = turtle.get_mount_point()
		var expired: bool = mount.tick_rescue_active(delta)
		var prev := rescue_prev_pos
		rabbit.velocity.x = move_toward(rabbit.velocity.x, 0.0,
			Tuning.RESCUE_WATER_DRAG * delta)
		rabbit.position.x += rabbit.velocity.x * delta
		rabbit.velocity.y = move_toward(rabbit.velocity.y, Tuning.RESCUE_RABBIT_SINK,
			Tuning.RESCUE_WATER_VY_DRAG * delta)
		rabbit.position.y = minf(rabbit.position.y + rabbit.velocity.y * delta, 760.0)
		# 轻微吸附只在真实靠近时生效（更外一圈），远处的兔子纹丝不动。
		rabbit.position += mount.rescue_suction_offset(rabbit.position, mp, delta)
		var caught: bool = mount.can_rescue_catch(rabbit.position, mp,
			rabbit.velocity, turtle.speed, prev)
		rescue_prev_pos = rabbit.position
		if caught:
			_rescue_catch(mp)
		elif expired:
			# FEEL-22：取消“超时自动回壳”这条竞争规则。
			# 救援只由合法接触或 SPACE 追近后的接触完成；氧耗尽走真实失败。
			if not _catch_active:
				_rescue_auto_blocked()
		elif turtle.position.x > rabbit.position.x + 280.0:
			_rescue_miss("passed_by")

	if mount.state == "RESCUING":
		if mount.tick_rescue(delta):
			# §3：追到壳边时剩下的距离也要连续走完，不能在这里一帧吸附。
			# 近距离直接吸附；还差得远就补一段抬升，运动轨迹始终可见。
			var mp: Vector2 = turtle.get_mount_point()
			if rabbit.position.distance_to(mp) <= Tuning.CARRY_SNAP_DIST:
				rabbit.attach(mp)
				mount.mark_riding()
				_finish_rescue_return()
			else:
				_begin_carry("rescue_return", mp, Tuning.RESCUE_RETURN_CARRY_MAX)

	if rabbit_stun > 0.0:
		rabbit_stun -= delta
		# 撞一下的减速要看得见：硬直期间把速度压在 140。
		turtle.speed = minf(turtle.speed, 140.0)
		if rabbit_stun <= 0.0:
			rabbit_stun = 0.0
			if GameManager.accident_state == "RABBIT_STUN":
				GameManager.accident_state = "NONE"
			rabbit.state = "RIDING"
			rabbit_grace = 1.0

	if emergency_timer > 0.0:
		emergency_timer -= delta
		# 冲浪板模型的“浮出水面”就是回到巡航水深，不用旧水线 300。
		var rescue_y := surface_ref()
		turtle.position.y = move_toward(turtle.position.y, rescue_y, 240.0 * delta)
		if emergency_timer <= 0.0 or turtle.position.y <= rescue_y + 1.0:
			emergency_timer = 0.0
			turtle.position.y = rescue_y
			turtle.daze_time = 0.0
			turtle.state = "CRUISING"
			turtle.speed = 180.0
			GameManager.oxygen = Tuning.OXYGEN_RECOVERED
			GameManager.accident_state = "NONE"
			rabbit.state = "RIDING"
			rabbit.slide = 0.0
			rabbit.daze_time = 0.0
			rabbit_grace = 1.0
			turtle_grace = 1.0
			GameManager.rescue_done.emit()

	if turtle.accident:
		turtle_repair -= delta
		if turtle_repair <= 0.0:
			turtle.accident = false
			turtle.position.y = surface_ref()
			turtle.speed = 180.0
			turtle.state = "CRUISING"
			turtle.daze_time = 0.0
			# 修好之后别再被残留的 dunk 拽回水下：复位必须包含它。
			turtle.dunk_timer = 0.0
			turtle_grace = Tuning.GRACE_TIME
			GameManager.accident_state = "NONE"
			GameManager.rescue_done.emit()


## 兔子穿过水线：水花记在真实落点（世界坐标），从这里开始算救援窗口。
func _splash_water() -> void:
	rescue_splash_pos = rabbit.position
	rescue_splash_t = 0.0
	rescue_prev_pos = rabbit.position
	# FEEL-15：氧气现在是“TUBO 在水里”的资源。入水从满格开始，
	# 正常骑乘时隐藏并回满。
	GameManager.note_fall()
	GameManager.oxygen = GameManager.oxygen_capacity()
	GameManager.oxygen_phase = "SAFE"
	rescue_auto_disabled = false
	rescue_auto_blocked_t = 0.0
	# 入水不是停住：保留下落速度的一大半，兔子先扎进去再被水拖住。
	rabbit.velocity.y *= Tuning.RESCUE_ENTRY_KEEP_VY
	mount.mark_rescue_active(Tuning.RESCUE_ACTIVE_TIME)


## 主动救援成功：兔子抓住壳，回到骑乘；这是一次玩家动作，不是计时器放回。
func _rescue_catch(mp: Vector2) -> void:
	GameManager.complaint_role = ""
	GameManager.complaint_t = 0.0
	rescue_last_result = "caught"
	rescue_last_reason = "caught"
	# FEEL-46：接住后不要再让“空格追索”继续抢方向；
	# 接下来由 carry 把乌龟抬回巡航、把兔子放回壳上。
	_catch_active = false
	_catch_t = 0.0
	turtle.catch_target_y = -1.0
	# 接住那一刻先补氧，避免兔子在 carry 抬升期间继续憋死。
	GameManager.oxygen = maxf(GameManager.oxygen, Tuning.OXYGEN_RECOVERED)
	rescue_auto_blocked_t = 0.0
	rescue_auto_disabled = false
	# PLAYFUL-04 §3：接住的瞬间先给表现，位置用 carry 连续抬回壳上——
	# 这里不再直接 attach，否则兔子会从水里一帧瞬移到壳上。
	GameManager.prompt.emit("")
	_spawn_land_splash(rabbit.position)
	accident_flash = maxf(accident_flash, Tuning.ACCIDENT_FLASH * 0.6)
	_trigger_shake(false)
	GameManager.feedback.emit(Locale.t("feedback.rescue_ok"), "pop")
	_begin_carry("rescue", mp)
	if rescue_proto_mode:
		print("RESCUE PROTO: caught mode=%s" % ("air" if rescue_proto_air_mode else "water"))
		_write_realinput_result("caught")
		rescue_proto_reset_t = 1.6


## 没接住：兔子被水流冲回壳上（有限恢复，不再触发第二次事故）。
## reason 记录实际原因（§6），供 HUD/探针/日志判断“为什么没接上”。
func _rescue_miss(reason: String = "timeout") -> void:
	rescue_last_result = "missed"
	rescue_last_reason = reason
	mount.mark_rescuing(Tuning.RESCUE_RETURN_TIME)
	GameManager.prompt.emit("")
	GameManager.feedback.emit(Locale.t("feedback.rescue_miss"), "hit")
	if rescue_proto_mode:
		print("RESCUE PROTO: missed reason=%s mode=%s" % [reason,
			"air" if rescue_proto_air_mode else "water"])
		_write_realinput_result("missed")
		rescue_proto_reset_t = 2.2


## 超时那一刻到底差在哪：这是“失败原因”，不是猜。
## FEEL-15：玩家没按 SPACE 时的自动恢复。比主动救援慢（3.2 s 等待 + 0.8 s 回壳），
## 有闪白/震动反馈，但不是普通失败，也不写最佳纪录。
## FEEL-17：自动回壳不成立时只报一次；保持 RESCUE_ACTIVE，玩家仍可按 SPACE，
## 或让氧气继续消耗到真正的失败。
func _rescue_auto_blocked() -> void:
	if rescue_auto_blocked_t > 0.0:
		return
	rescue_auto_blocked_t = 1.0
	GameManager.feedback.emit(Locale.t("feedback.rescue_auto_fail"), "hit")


## FEEL-17：打断自动回壳。保留“TUBO 在水里、mount 可被 SPACE 接”的状态。
func _cancel_auto_return() -> void:
	if mount.state != "RESCUING" and carry_kind != "rescue_return":
		return
	carry_kind = ""
	carry_t = 0.0
	carry_dur = 0.0
	rescue_auto_disabled = true
	rescue_auto_blocked_t = 0.0
	mount.mark_rescue_active(0.0)
	rabbit.state = "FALLING_WATER"
	GameManager.feedback.emit(Locale.t("feedback.rescue_auto_interrupt"), "hit")


func _rescue_auto() -> void:
	rescue_last_result = "auto"
	rescue_last_reason = "auto_timeout"
	mount.mark_rescuing(Tuning.RESCUE_RETURN_TIME)
	GameManager.prompt.emit("")
	accident_flash = maxf(accident_flash, Tuning.ACCIDENT_FLASH)
	_trigger_shake(false)
	GameManager.feedback.emit(Locale.t("feedback.rescue_auto"), "clean")
	if rescue_proto_mode:
		_write_realinput_result("auto")
		rescue_proto_reset_t = 1.6


func _rescue_miss_reason(mp: Vector2) -> String:
	var rp: Vector2 = rabbit.position
	var dx := absf(rp.x - mp.x)
	var dy := rp.y - mp.y
	if dx > Tuning.RESCUE_CATCH_DX:
		return "too_far_x"
	if dy > Tuning.RESCUE_CATCH_DY_MAX:
		return "turtle_too_shallow"
	if dy < Tuning.RESCUE_CATCH_DY_MIN:
		return "turtle_too_deep"
	return "timeout"


## 窗口化真实按键测试没有可读 stdout 时，用这个文件判定成功/失败。
## 只有带 --capture-rescue 的窗口化运行才写，自动探针不碰。
func _write_realinput_result(result: String) -> void:
	if not ("--capture-rescue" in OS.get_cmdline_user_args()):
		return
	var f := FileAccess.open(
		ProjectSettings.globalize_path("res://docs/reports/longrun/phase-f-realinput-last.txt"),
		FileAccess.WRITE)
	if f != null:
		f.store_string("%s %s %s %s\n" % [result, rescue_last_reason,
			"air" if rescue_proto_air_mode else "water",
			Time.get_datetime_string_from_system()])
		f.close()


## CORE-FEEL-07 P0-B：登记一次碰撞事实。同一障碍、时间窗内的第二次碰撞并进同一个
## 事件；超出窗口（或换了一个障碍）就是新事件。这里只记“谁碰了”，不记账。
func _register_collision(key: String, kind: String) -> Dictionary:
	var ev: Dictionary = accident_events.get(key, {})
	# hit_roles 被清空（重开/换关/测试换例）而事件还留着时，旧事件作废：
	# 否则“上一次已经结算过”会挡住下一次的全新碰撞。
	if not ev.is_empty() and not hit_roles.has(key):
		ev = {}
	if ev.is_empty() \
			or accident_event_time - float(ev["t"]) > Tuning.ACCIDENT_JOINT_WINDOW:
		accident_event_seq += 1
		ev = {
			"id": accident_event_seq,
			"group": key,
			"kind": kind,
			"t": accident_event_time,
			"roles": {},
			"settled": false,
			"penalty_role": "",
			"rescue": _rescue_context(),
			"settled_t": -1.0,
			# 兔子在这一次碰撞发生时是否已经在空中：决定“随后落水”算不算同一笔失败。
			"rabbit_air": rabbit.is_airborne(),
			"followups": [],
		}
		accident_events[key] = ev
		# 事件按引用进日志：后续补上的角色（兔子先落水、乌龟 0.3 s 后撞壳）
		# 会直接反映在记录里，不需要再次结算。
		accident_event_log.append(ev)
	return ev


## 把一个角色记进事件。已经结算过的事件，如果第二个角色也在窗口内撞上同一障碍，
## 记录升级为联合，但惩罚不重复：事故数/扣分保持一笔。
func _note_role(ev: Dictionary, role: String) -> void:
	ev["roles"][role] = true
	if bool(ev["settled"]) and ev["roles"].size() >= 2 \
			and String(ev["penalty_role"]) != "joint" \
			and accident_event_time - float(ev["settled_t"]) <= Tuning.ACCIDENT_JOINT_WINDOW:
		ev["penalty_role"] = "joint"


## 事件第一次真的记了账：把角色集折算成责任方（单侧 / joint），打上结算标志。
## 同一事件只结算一次；之后同组的碰撞只补表现，不再扣分。
func _settle_event(ev: Dictionary, fallback_role: String) -> void:
	if bool(ev["settled"]):
		return
	var roles: Dictionary = ev["roles"]
	var penalty := fallback_role
	if roles.size() >= 2:
		penalty = "joint"
	elif roles.size() == 1:
		penalty = String(roles.keys()[0])
	ev["settled"] = true
	ev["penalty_role"] = penalty
	ev["settled_t"] = accident_event_time


## P0-B 补丁（2026-11-13）：兔子落水不总是“新的一笔”。乌龟刚撞上浮木、壳被顶住时，
## 兔子这一跳已经没有壳可落——落水是同一次失败的下游后果，不该再扣一格。
## 认法要同时满足：最近一笔已结算事件是浮木、乌龟是当事角色、事件发生时兔子已经在空中、
## 且仍在同一时间窗内。任何一条不满足就返回空（照常独立记账）。
func _fall_consequence_event() -> Dictionary:
	for i in range(accident_event_log.size() - 1, -1, -1):
		var ev: Dictionary = accident_event_log[i]
		if not bool(ev["settled"]):
			return {}
		if String(ev["kind"]) != "FLOATING_LOG":
			return {}
		if not Dictionary(ev["roles"]).has("turtle"):
			return {}
		if not bool(ev.get("rabbit_air", false)):
			return {}
		if accident_event_time - float(ev["settled_t"]) > Tuning.ACCIDENT_JOINT_WINDOW:
			return {}
		return ev
	return {}


## 把“兔子随后落水”记进同一事件：扣分不重复，但记录里看得见这一笔从哪里来。
func _note_fall_absorbed(ev: Dictionary) -> void:
	var follows: Array = ev.get("followups", [])
	follows.append({
		"reason": "RABBIT_WATER",
		"role": "rabbit",
		"t": snappedf(accident_event_time, 0.01),
	})
	ev["followups"] = follows


## 事故发生在哪一段流程里：救援中（兔子落水/空中救援）还是普通行驶。
## 记进事件是为了核对“救援成功不算联合事故”“救援中的真实碰撞不被吞掉”。
func _rescue_context() -> String:
	if mount.state in ["RESCUING", "RESCUE_FALLING", "RESCUE_ACTIVE", "RESCUE_AIR"]:
		return String(mount.state)
	if GameManager.accident_state != "NONE":
		return String(GameManager.accident_state)
	return "NONE"


func _trigger_accident(reason: String, charge: bool = true) -> bool:
	if not _can_accident():
		return false
	if showtime_active:
		showtime_active = false
		GameManager.showtime_active = false
		rabbit.showtime_spin = 0.0
		rabbit.showtime_pose = false
	# FEEL-17：自动回壳是低优先级兜底。高优先级事故打断后不再续命，
	# 状态回到“兔子还在水里、玩家仍可 SPACE 接”，不会卡在半个抬升。
	if reason != "RABBIT_WATER" and (mount.state == "RESCUING" 			or carry_kind == "rescue_return"):
		_cancel_auto_return()
	hazard_cooldown = Tuning.TURTLE_COOLDOWN if reason == "TURTLE_REEF" \
		else Tuning.HAZARD_COOLDOWN
	accident_flash = Tuning.ACCIDENT_FLASH
	_accident_t = 0.0
	# 先取救援上下文，再写本次事故状态：否则 _rescue_context 读到的就是
	# 刚写进去的 reason，任何事故都会被误判成“救援中的二次事故”而不记账。
	var rescue_ctx := _rescue_context()
	GameManager.accident_state = reason
	# accident_count / 扣分 / BRO METER 都在 note_accident -> note_mistake 里，
	# 避免事故入口与海浪碰撞各记一套。
	# CORE-FEEL-07 P0-B：同一个障碍的第二笔只是同一个事件，不重复记账；
	# 落水/硬直等物理后果照常发生，玩家看到的反馈不会被吞。
	# FEEL-10 P0-A：救援流程本身不再记 BRO、不再触发联合；初始落水仍照常记账。
	if charge and rescue_ctx == "NONE":
		GameManager.note_accident(reason)
	elif charge:
		# 救援中的二次事故只播表现，不记账、不喂 BRO。
		charge = false
	combo = 0
	GameManager.combo = 0
	GameManager.accident.emit(reason)

	match reason:
		"RABBIT_SLIP":
			rabbit.state = "FALLING_WATER"
			rabbit.velocity = Vector2.ZERO
			mount.mark_rescuing(Tuning.RESCUE_TIME)
			GameManager.set_control("turtle")
		"RABBIT_WATER":
			# §6：不瞬移。兔子保持离壳瞬间的世界坐标、方向和速度继续下落，
			# 穿过水线时才在真实落点出水花、才开始救援计时。
			# 控制权不强制交回——如果刚才在兔子身上，SHIFT 本身就是救援的第一步。
			rabbit.state = "FALLING_WATER"
			rescue_prev_pos = rabbit.position
			if rabbit.position.y >= Tuning.RESCUE_ENTRY_Y:
				_splash_water()
			else:
				mount.mark_rescue_falling()
			GameManager.prompt.emit(Locale.t(
				"prompt.rescue_shift" if GameManager.current_control == "rabbit"
				else "prompt.rescue_dive"))
		"RABBIT_AIR":
			# 方案 2 原型：兔子被抛到空中；玩家可以 SHIFT 到乌龟，再按 ↑ 跃起接住。
			rabbit.state = "FALLING_WATER"
			rabbit.velocity = Vector2(0.0, 0.0)
			rabbit.position = Vector2(
				turtle.position.x + Tuning.RESCUE_AIR_AHEAD,
				Tuning.RESCUE_AIR_START_Y)
			mount.mark_rescue_air(Tuning.RESCUE_AIR_TIME)
			GameManager.prompt.emit(Locale.t(
				"prompt.rescue_leap_shift" if GameManager.current_control == "rabbit"
				else "prompt.rescue_leap"))
		"RABBIT_STUN":
			# 短硬直是碰撞后果，不是控制锁：不强制换人，玩家自己决定要不要换。
			rabbit.state = "STUNNED"
			rabbit_stun = Tuning.STUN_TIME
			turtle.speed *= 0.6
		"TURTLE_REEF":
			turtle.accident = true
			turtle_repair = Tuning.REPAIR_TIME
			turtle.state = "UNCONSCIOUS"
			GameManager.set_control("rabbit")
		"OXYGEN_OUT":
			rabbit.state = "PASSED_OUT"
			emergency_timer = Tuning.EMERGENCY_TIME
			GameManager.set_control("turtle")
	# FEEL-47：只喂视觉三段压力，不碰分数/判定/控制。
	if String(reason).begins_with("TURTLE"):
		_bump_visual_stress("turtle", 1.0)
	else:
		_bump_visual_stress("rabbit", 1.0)
	return true


## 现在能不能记一次新事故。碰撞前先问，避免“标脏了却没记账”的静默漏判。
## FEEL-15：动态实体撞到 BITT 的“接触反馈”。不写 BRO METER、不进入事故，
## 只减速 + 短暂停顿 + 一句说明；同一组 0.8 s 内不重复报。
func _turtle_dynamic_bump(key: String, group: Dictionary) -> void:
	var now := accident_event_time
	if now - float(_dynamic_bump_cd.get(key, -99.0)) < 0.8:
		return
	_dynamic_bump_cd[key] = now
	_trigger_hitstop("turtle")
	_trigger_shake(false)
	turtle.start_dunk()
	turtle.add_imbalance(0.05)
	turtle.speed *= 0.82
	GameManager.feedback.emit(Locale.t("feedback.buoy_hit"), "hit")
	GameManager.hint.emit(Locale.t("hint.buoy_hit"))


func _can_accident() -> bool:
	return hazard_cooldown <= 0.0 and GameManager.accident_state == "NONE"


func _rabbit_contact(kind: String = "", charge: bool = true) -> bool:
	# 已经被冷却/别的过程挡住时不要先播表现：既没记账又闪一下最误导。
	if not _can_accident():
		return false
	# REBUILD-05 G19：A 类障碍只判兔子。操控乌龟时撞上，玩家其实没有可用的躲法
	# （乌龟的 ↓ 是下潜，不是趴低），第一次给一句“换人”，当局只给一次。
	# 放在事故之前发：落水/失衡的反馈随后会覆盖它，但玩家先看到的是“该换人”。
	if kind in ["LOW_BEAM", "LOW_BIRD", "SURFACE_ROCK"] \
			and GameManager.current_control == "turtle" and not _wrong_role_hinted:
		_wrong_role_hinted = true
		GameManager.hint.emit(Locale.t("hint.take_rabbit"))
	# PLAYFUL-04：撞浮木是“跳跃弧线”问题，和低梁/岩檐的提示分开。
	if kind == "FLOATING_LOG":
		GameManager.feedback.emit(Locale.t("feedback.log_jump"), "hit")
		GameManager.hint.emit(Locale.t("hint.log_jump"))
	# P1-5：先给一次 50 ms 的表现停顿 + 2–3 px 震动；物理判定完全不动。
	_trigger_hitstop("rabbit")
	if mount.state == "AIRBORNE" or rabbit.is_airborne():
		_trigger_shake(true)   # 被撞落水是重大后果，给 5–8 px
		return _trigger_accident("RABBIT_WATER", charge)
	_trigger_shake(false)  # 撞一下但还没掉下去：只给普通震动
	# 撞一次不是立刻摔：加一段失衡，姿态马上变差，继续错才会到临界。
	rabbit.add_imbalance(Tuning.RABBIT_HIT_IMBALANCE)
	return _trigger_accident("RABBIT_STUN", charge)


## 浪击：乌龟失衡 + 整组短暂没入水下 + 明显减速。
## Phase G：它是一次“失误”，当场记 1 格 BRO METER；失衡只做短硬直，
## 不再有“攒到 9.5 再补一次翻肚皮”的第二套惩罚。
func _turtle_contact(_key: String, kind: String = "", charge: bool = true) -> void:
	# FEEL-17：自动回壳途中撞上真实障碍，属于高优先级中断；立即取消抬升，
	# 回到“兔子还在水里、可 SPACE 接”的状态，不让自动回壳续命。
	if mount.state == "RESCUING" or carry_kind == "rescue_return":
		_cancel_auto_return()
	# P1-5：乌龟更重——90 ms 停顿 + 5–8 px 震动；判定/减速数值保持原样。
	_trigger_hitstop("turtle")
	_trigger_shake(true)
	turtle.add_imbalance(Tuning.TURTLE_HIT_IMBALANCE)
	turtle.start_dunk()
	# P5：掀翻是“浪击”的可见后果，不是第二套惩罚：不另记事故/不清控制。
	turtle.start_flip()
	turtle.speed *= 0.6
	accident_flash = Tuning.ACCIDENT_FLASH
	# PLAYFUL-04 §1/§2：浮木撞壳的提示必须说“下潜太晚”，
	# 不能一律说“被浪拍到”——那会让玩家以为换个姿势就行。
	# CORE-FEEL-07C：鲨鱼/拱岩/高墙同样各说各的；玩家撞上什么，屏幕就点名什么。
	var fb := "feedback.wave_hit"
	var hn := "hint.wave_hit"
	match kind:
		"FLOATING_LOG":
			fb = "feedback.dive_late"
			hn = "hint.dive_late"
		"SHARK":
			fb = "feedback.shark_hit"
			hn = "hint.shark_hit"
		"DIVE_GATE":
			fb = "feedback.gate_hit"
			hn = "hint.gate_hit"
		"HIGH_WALL":
			fb = "feedback.wall_hit"
			hn = "hint.wall_hit"
		"SURFACE_ROCK":
			fb = "feedback.buoy_hit"
			hn = "hint.buoy_hit"
		"LOW_BIRD":
			fb = "feedback.bird_poop"
			hn = "hint.bird_poop"
	GameManager.feedback.emit(Locale.t(fb), "hit")
	GameManager.hint.emit(Locale.t(hn))
	# 记录仍然是一格 BRO METER（不新增惩罚系统）；原因标签按实际障碍区分。
	# CORE-FEEL-07 P0-B：同一障碍的同一件事只记一次。第二次命中仍然播
	# 停顿/震动/掀翻/减速，但不再扣分——表现不吞，账目不重复。
	if charge:
		GameManager.note_mistake(
			"TURTLE_DIVE_LATE" if kind == "FLOATING_LOG" else "TURTLE_WAVE",
			"turtle")
		_bump_visual_stress("turtle", 1.0)
	_apply_bounce(_key, kind)


func _apply_bounce(key: String, kind: String) -> void:
	if test_no_bounce:
		return
	if _bounce_cd > 0.0:
		return
	if not (kind in BONK_KINDS) or key.begins_with("pack_"):
		return
	var g := _group_by_name(key)
	if g.is_empty():
		return
	var idx := -1
	for i in hazard_groups.size():
		if String(hazard_groups[i].get("group", "")) == key:
			idx = i
			break
	if idx < 0:
		return
	# 后退 140 px；如果会退进上一组，就停在上一组末端 + 80。
	var floor_x := 40.0
	if idx > 0:
		floor_x = _group_end(hazard_groups[idx - 1]) + 80.0
	turtle.position.x = maxf(turtle.position.x - BONK_BACK, floor_x)
	turtle.speed = 0.0
	_bounce_cd = BONK_CD
	_bonk_streak += 1
	_bonk_level = mini(_bonk_streak, BONK_FAIL_COUNT)
	GameManager.feedback.emit(Locale.t("feedback.turtle_bonk",
		[_bonk_level, BONK_FAIL_COUNT]), "hit")
	if _bonk_streak == 2:
		var speaker := "rabbit" if GameManager.current_control == "turtle" else "turtle"
		GameManager.bro_say.emit(speaker, Locale.t("bro.bonk"))
	if _bonk_streak >= BONK_FAIL_COUNT:
		_bonk_fail()


func _bonk_fail() -> void:
	GameManager.finish_failure("BONK_OUT")


## 旧的“壳沉太深”暗流不再存在：乌龟待命也停在巡航水深。
## 保留这个查询给 HUD/旧测试调用，永远返回 false。
func undertow_active() -> bool:
	return false


func _check_hazards() -> void:
	if test_disable_hazards:
		return
	var t_rect := _inset(turtle.get_body_rect(), 3.0)
	var r_rect := _inset(rabbit.get_body_rect(), 3.0)
	# REBUILD-05 B2：两个角色各记各的。
	# - 兔子在落水/硬直/缺氧过程中不是自由操控角色，由落水流程自己记账；
	#   此时它的身体（还在空中飘）不应该再触发一次落水事故。
	# - 乌龟只要还在水里就参与判定——接应下潜途中撞到真障碍也算。
	var rabbit_can_hit: bool = GameManager.accident_state == "NONE"
	var turtle_can_hit: bool = not (GameManager.accident_state in ["TURTLE_REEF", "OXYGEN_OUT"])
	for g in hazard_groups:
		var group: Dictionary = g
		var key := String(group["group"])
		# 鲨群专场：三拍期间附近普通障碍不出现、不判。
		if _shark_arena_hides(group):
			continue
		# shark6 的碰撞由三只实体鲨鱼负责；旧组只保留位置锚点。
		if _pack_owns(key):
			continue
		if destroyed_groups.has(key):
			continue
		var kind := String(group["kind"])
		var roles: Dictionary = hit_roles.get(key, {})
		if roles.size() >= 2:
			continue
		for i in group["rects"].size():
			# REBUILD-05 E2：动态障碍按这一帧的位置判。
			var rect := hazard_rect_live(group, i)
			var rabbit_hit := false
			var turtle_hit := false
			match kind:
				"LOW_BEAM":
					# A 类：只占兔子站立的那一层。趴在壳上就过，龟壳不受影响。
					rabbit_hit = rabbit_can_hit and not roles.has("rabbit") \
						and rabbit.state != "CROUCHING" and r_rect.intersects(rect)
				"LOW_BIRD":
					# FEEL-49：只有鸟真正扎到攻击窗口时才判。
					# 鸟已经飞过/拉起（RECOVER/CIRCLE）时，固定判定带不再伤人。
					var bird_live := true
					if String(group.get("identity", "")) not in ["state_net", "cargo_net"]:
						var bp: Dictionary = bird_pose(group)
						bird_live = String(bp.get("phase", "")) == "DIVE" \
							and float(bp.get("d", 0.0)) > -18.0
					rabbit_hit = rabbit_can_hit and not roles.has("rabbit") \
						and bird_live and rabbit.state != "CROUCHING" \
						and r_rect.intersects(rect)
				"SURFACE_ROCK":
					# A 类（跳跃）：只压兔子；龟壳顶从岩石下沿让开 10 px。
					# 起跳上升帧允许越过岩檐；下落仍会撞上。
					rabbit_hit = rabbit_can_hit and not roles.has("rabbit") \
						and r_rect.intersects(rect) \
						and not (rabbit.state == "JUMPING" and rabbit.velocity.y < 0.0)
				"SHARK":
					# C 类：只判乌龟。跃起把整组带高，兔子跟着壳，不需要额外动作。
					turtle_hit = turtle_can_hit and not roles.has("turtle") \
						and t_rect.intersects(rect)
				"DIVE_GATE":
					# D 类：只判乌龟。下潜到位后整个壳（连同壳上的兔子）从下方过。
					turtle_hit = turtle_can_hit and not roles.has("turtle") \
						and t_rect.intersects(rect)
				"FLOATING_LOG":
					# B 类（组合）：上沿是兔子路线，下沿是乌龟路线，两条路径分别判。
					# 同一帧两边都撞也要各记一次，不能再 return 掉后者。
					# FEEL-44：BRO DIVE 已经完成“兔子跳 + 乌龟潜”时，兔子的骑乘体
					# 在深水下会与浮木水下段擦边；这不应把玩家卡在木前。
					# 只对“本次已跳过的兔子 + 当前乌龟正在下潜”放行兔子侧。
					var acts: Dictionary = group_actions.get(key, {})
					var bro_dive_tuck: bool = GameManager.current_control == "turtle" \
						and turtle.diving and (bool(acts.get("jumped", false))
							or (dive_assist != "OFF" and dive_assist_key == key))
					rabbit_hit = rabbit_can_hit and not roles.has("rabbit") \
						and r_rect.intersects(rect) and not bro_dive_tuck
					turtle_hit = turtle_can_hit and not roles.has("turtle") \
						and t_rect.intersects(rect)
				"HIGH_WALL":
					# E 类（BRO OLLIE）：墙楣只压骑乘兔，墙身压巡航壳。
					# 跃起只把壳送进窗口；壳上的兔子会撞墙楣，必须玩家补一次蹬踏。
					rabbit_hit = rabbit_can_hit and not roles.has("rabbit") \
						and r_rect.intersects(rect)
					turtle_hit = turtle_can_hit and not roles.has("turtle") \
						and t_rect.intersects(rect)
			# CORE-FEEL-07 P0-B：同一帧两边都撞也要先登记事实，再按“这一障碍的
			# 事件是否结算过”决定谁记账。旧实现里 _turtle_contact 无条件直连
			# note_mistake，兔子落水后再撞壳就是同一根浮木扣两次。
			# FEEL-15：红白浮标 / 木质吊箱 / 漂流货箱只做“真实接触反馈”，
			# 不升级成事故/扣格：TUBO 的跳跃路线仍是安全路线，BITT 被画到身上
			# 时减速、震动、报一句，不能“画着撞、判定当没发生”。
			if not group.get("motion", {}).is_empty() and turtle_can_hit 					and not roles.has("turtle") and t_rect.intersects(rect):
				_turtle_dynamic_bump(key, group)
			if not (rabbit_hit or turtle_hit):
				continue
			# 兔子被冷却/别的事故挡住、而乌龟这一帧没有真实碰撞：不登记事实，
			# 下一帧重新看（旧行为：被挡下的碰撞不算“已处理”）。
			if rabbit_hit and not turtle_hit and not _can_accident():
				continue
			var ev := _register_collision(key, kind)
			# 事件还没结算过才允许记账；兔子自己还有 _can_accident 的门槛。
			var charge: bool = not bool(ev["settled"])
			var charged := false
			var applied := false
			if rabbit_hit:
				_note_role(ev, "rabbit")
				if _rabbit_contact(kind, charge):
					# 真的记了账才标脏：冷却/事故期间被挡下的碰撞不算“已处理”，
					# 否则这组障碍会永远静默失效（B1 的一个来源）。
					charged = charge
					roles["rabbit"] = true
					applied = true
			if turtle_hit:
				_note_role(ev, "turtle")
				# 兔子已经为这个事件扣过分时，乌龟只补表现，不再记账。
				_turtle_contact(key, kind, charge and not charged)
				charged = charge
				roles["turtle"] = true
				applied = true
			if applied:
				if charged:
					_settle_event(ev, "rabbit" if rabbit_hit else "turtle")
				hit_roles[key] = roles
				hit_groups[key] = true
				# FEEL-37：紧连招撞了，除了“撞到哪种障碍”，再点名“断在哪一拍”。
				var chain := String(group.get("combo", ""))
				if chain in CHAIN_FAIL_COMBOS:
					GameManager.hint.emit(Locale.t("hint.relay_fail_" + chain))
				# 只有真正做成 BRO DIVE 尝试后才允许撞碎；乌龟单独擦到浮木
				# 是可恢复的碰撞，不能直接跳过整组。
				var both_failed: bool = roles.has("rabbit") and roles.has("turtle")
				if kind == "FLOATING_LOG" and both_failed:
					_destroy_floating_log(group, key)
				# REBUILD-05 G21：撞过就重新武装这一类型的首次教学。
				# 原来一局只教一次：第一组海鸟没躲过，后面 3 组同类型就再没人提醒，
				# 玩家已经知道“这里有问题”却不知道“该怎么办”。撞出真实失误
				# （applied = 真的记了账，冷却/事故中挡下的不算）后清掉标记，
				# 下一组同类型进入提示范围时会再说一遍；干净通过不清，
				# 所以“看懂了”的人不会被打扰，其他类型也不受影响。
				# G22：补教只给一次。撞第二组时不再重新武装——同一句话说第三遍
				# 不会让人更懂，只会盖住别的提示。
				# G22：补教只给一次。撞第二组时不再重新武装。
				if not lesson_retaught.has(_lesson_key(group)):
					lesson_retaught[_lesson_key(group)] = true
					lesson_seen.erase(_lesson_key(group))
				return


## REBUILD-06 P0：乌龟对实心障碍是“硬”的。
##
## 以前障碍只做判定、不做位置限制：撞上了会记一笔、会下沉、会减速，但壳继续沿
## 轨道从障碍中间穿过去。玩家看到的是“乌龟穿墙/穿圆木”，而且撞完不需要做任何
## 事——因为壳根本没被挡住。这里把穿透补成真实的顶住：只要壳的判定框（与
## _check_hazards 同一份 rects、同样 3 px 内缩）还压在障碍上，就把它推回障碍靠
## 近自己的那一侧。它只会把壳推出障碍，不会推着壳过关，也不会替玩家做下潜/跃起；
## 障碍仍然是“过不去”的，必须由玩家自己做对动作。
##
## 每帧在 turtle.tick() 之后、画之前跑，所以画出来的位置就是顶住后的位置；
## hitstop 冻结的也是这个位置。A 类只占兔子那一层，壳本来就不该被挡，跳过。
func _resolve_turtle_solid() -> void:
	if test_disable_hazards:
		return
	var tr := _inset(turtle.get_body_rect(), 3.0)
	var before_x: float = turtle.position.x
	var pushed := false
	for g in hazard_groups:
		var group: Dictionary = g
		if _pack_owns(String(group["group"])):
			continue
		if destroyed_groups.has(String(group["group"])):
			continue
		var kind := String(group["kind"])
		if kind in ["LOW_BEAM", "LOW_BIRD", "SURFACE_ROCK", "DIVE_GATE"]:
			continue
		for i in group["rects"].size():
			var rect := hazard_rect_live(group, i)
			if not tr.intersects(rect):
				continue
			# 只往“来的那一侧”（左边）推：推回、顶住可以是真实碰撞反馈，
			# 往前推过障碍就是替玩家过关——这里绝不那样做。
			# 壳已经完全越过障碍右沿时不再回拉，避免又出现一次瞬移；
			# 但此时它可能正从障碍底下浮上来，后半截还压在浮木下沿——
			# 于是沿 y 轴把它推回最近的那条水平边，不允许从背后穿上来。
			if turtle.position.x > rect.end.x:
				var up: float = rect.position.y - tr.end.y
				var down: float = rect.end.y - tr.position.y
				if absf(up) <= absf(down):
					turtle.position.y += up - 0.5
				else:
					turtle.position.y += down + 0.5
				tr = _inset(turtle.get_body_rect(), 3.0)
				pushed = true
				continue
			turtle.position.x = minf(turtle.position.x,
				rect.position.x - tr.size.x * 0.5)
			tr = _inset(turtle.get_body_rect(), 3.0)
			pushed = true
	# 壳被顶住时，坐在上面的兔子跟着一起退，不能自己留在墙里。
	if pushed:
		_turtle_blocked_t = 0.3
	var dx: float = turtle.position.x - before_x
	if dx != 0.0 and mount.state == "RIDING":
		rabbit.position.x += dx
		rescue_prev_pos.x += dx


func _update_oxygen(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	# FEEL-15：只有 TUBO 真正在水下（救援窗口）才消耗氧气。
	# 正常骑乘不显示气泡，也不再用“龟壳潜深”扣氧。
	# 氧气跟“兔子实际是否被水没过”走：骑壳潜水也算。
	# 接住后的救援抬升不再扣氧：兔子已经在回到壳上的路径里，
	# 不能因为 carry 的 0.3–0.8 s 把最后一口气耗光。
	var underwater: bool = _rabbit_underwater() and carry_kind != "rescue"
	if underwater:
		GameManager.oxygen = maxf(GameManager.oxygen
			- delta * Tuning.OXYGEN_DRAIN * GameManager.oxygen_drain_scale(), 0.0)
		if GameManager.oxygen <= 0.0:
			GameManager.finish_failure("OXYGEN_OUT")
			return
	else:
		GameManager.oxygen = minf(GameManager.oxygen
			+ delta * Tuning.OXYGEN_RECOVER, GameManager.oxygen_capacity())
	var phase := oxygen_phase()
	if phase != _oxygen_phase:
		if phase == "LOW":
			GameManager.hint.emit(Locale.t("hint.air_low"))
		elif phase == "CRITICAL":
			GameManager.hint.emit(Locale.t("hint.air_critical"))
		_oxygen_phase = phase
	GameManager.oxygen_phase = phase


func _rabbit_underwater() -> bool:
	if rabbit.position.y > surface_ref() + 20.0:
		return true
	return mount.state == "RESCUE_ACTIVE" 		or (mount.state == "RESCUING" and GameManager.accident_state == "RABBIT_WATER") 		or (mount.state == "CARRYING" and carry_kind == "rescue_return") 		or (GameManager.accident_state == "RABBIT_WATER" and rabbit.position.y > surface_ref() + 20.0)


func oxygen_bubbles_visible() -> bool:
	return _rabbit_underwater() or GameManager.accident_state == "OXYGEN_OUT"

func oxygen_phase() -> String:
	if GameManager.oxygen <= 0.01:
		return "EMPTY"
	if GameManager.oxygen <= Tuning.OXYGEN_CRITICAL:
		return "CRITICAL"
	if GameManager.oxygen <= Tuning.OXYGEN_LOW:
		return "LOW"
	return "SAFE"


func _update_combo() -> void:
	for g in hazard_groups:
		var group: Dictionary = g
		var key: String = group["group"]
		if passed_groups.has(key):
			continue
		var start_x := _group_start(group)
		var end_x := _group_end(group)
		# 必须先真正靠近/穿过障碍才具备“通过”资格。
		# 否则瞬移（测试、调试或未来任何跳转）会把身后的整段障碍误算成连击。
		if turtle.position.x >= start_x - 120.0 and turtle.position.x <= end_x + 120.0:
			entered_groups[key] = true
		# 精准动作只在横穿带里采样：起跳/下潜都要在障碍真正经过时仍然成立。
		if not passed_groups.has(key) \
				and turtle.position.x > start_x - ACT_BAND \
				and turtle.position.x < end_x + ACT_BAND:
			_sample_action(key)
		if turtle.position.x > end_x + 80.0 and entered_groups.get(key, false):
			passed_groups[key] = true
			if GameManager.accident_state != "NONE" or hit_groups.get(key, false):
				# 事故期间越过的障碍不补算连击，避免恢复后“隔空”加数。
				combo = 0
			else:
				# FEEL-24：取消“3 组自动积累 → SHOWTIME”的机械流程。
				combo = 0
				_bonk_streak = 0
				_bonk_level = 0
				var kind: String = String(group["kind"])
				var act: Dictionary = group_actions.get(key, {})
				var precise := _precise_action(kind, act)
				if precise:
					# 连招整段完成才给 250/300；精准单动作 150；其余干净通过 100。
					GameManager.note_precise_pass(kind)
					# PHASE-FIX：BRO DIVE/OLLIE/精准动作概率触发小 SHOWTIME；
					# 不用 0/3 计数器，一局最多 3 次。
					if not test_no_showtime and not showtime_active 							and _showtime_cd <= 0.0 							and GameManager.showtime_count < 3 							and randf() < Tuning.SHOWTIME_CHANCE:
						start_showtime()
					match kind:
						"FLOATING_LOG":
							GameManager.feedback.emit(Locale.t("feedback.bro_dive"), "bro")
							# P1-5：BRO DIVE 成功——青色下潜环，和跳跃/干净通过分开。
							_trigger_action_fx("dive", turtle.position)
						"HIGH_WALL":
							GameManager.feedback.emit(Locale.t("feedback.bro_ollie"), "bro")
							# P1-5：BRO OLLIE 成功（乌龟跃起 + 兔子蹬踏第二跳）——金色上冲环。
							_trigger_action_fx("ollie", turtle.position)
						_:
							GameManager.feedback.emit(Locale.t("feedback.clean"), "clean")
				else:
					GameManager.note_clean_pass()
					GameManager.feedback.emit(Locale.t("feedback.clean"), "clean")
				# FEEL-47：干净通过让视觉压力回落，但不动实际惩罚/分数。
				_relieve_visual_stress(GameManager.current_control, 0.25)


## 横穿带里每帧采样一次：这个障碍到底是靠哪个动作过的。
## 只看障碍真正经过的那一小段，提前很远的乱跳不算数。
func _sample_action(key: String) -> void:
	var a: Dictionary = group_actions.get(key, {})
	var rabbit_air: bool = rabbit.state == "JUMPING" or rabbit.state == "FALLING"
	if rabbit_air:
		a["jumped"] = true
	if rabbit.state == "CROUCHING":
		a["crouched"] = true
	if turtle.position.y > surface_ref() + 80.0:
		a["dived"] = true
	if turtle.leap_active:
		a["leaped"] = true
		# 壳在跃起、兔子却已经离壳：这才是 BRO OLLIE 的“二段蹬踏”。
		if rabbit_air or mount.state == "AIRBORNE":
			a["kicked"] = true
	group_actions[key] = a


func _precise_action(kind: String, a: Dictionary) -> bool:
	match kind:
		"SURFACE_ROCK":
			return bool(a.get("jumped", false))
		"LOW_BEAM", "LOW_BIRD":
			return bool(a.get("crouched", false))
		"SHARK":
			return bool(a.get("leaped", false))
		"DIVE_GATE":
			return bool(a.get("dived", false))
		"FLOATING_LOG":
			# 兔子跳 + 乌龟潜，两段都在障碍横穿带里成立才算 BRO DIVE。
			return bool(a.get("jumped", false)) and bool(a.get("dived", false))
		"HIGH_WALL":
			# 壳跃起 + 兔子蹬踏离壳，缺一段就只是撞墙。
			return bool(a.get("leaped", false)) and bool(a.get("kicked", false))
	return false


## FEEL-10 P0-A：单角色捣乱。满格只影响本次失误的角色；另一角色保持可操作。
## FEEL-12：高阶段电流走火。PRE 是 0.30 s 预兆；当前受控角色在预兆里被
## SHIFT 换走 → 慢镜头 + 原角色过载动作；不换则角色自己完成动作（无慢镜头、不重罚）。
## FEEL-12 补充 B：SPACE 按当前角色分派。
func _try_role_skill() -> void:
	if GameManager.accident_state != "NONE" and GameManager.accident_state not in ["RABBIT_WATER", "RABBIT_AIR"]:
		return
	if GameManager.current_control == "rabbit":
		# FEEL-15：TUBO 的 SPACE 胡萝卜护盾已从正式比赛移除。
		# SPACE 只属于 BITT 主动救援；这里不做任何动作。
		return
	elif GameManager.current_control == "turtle":
		if _can_bro_catch():
			_catch_active = true
			_catch_t = CATCH_TIME
			_catch_target = rabbit.position
			_catch_fx_t = 0.25
			GameManager.feedback.emit(Locale.t("feedback.catch_start"), "relay")


func _can_bro_catch() -> bool:
	if mount.state in ["RESCUING", "RESCUE_FALLING", "RESCUE_ACTIVE", "RESCUE_AIR"]:
		return true
	return rabbit.state == "FALLING_WATER"


func _guard_can_block(kind: String) -> bool:
	return _guard_t > 0.0 and kind in ["SURFACE_ROCK", "LOW_BEAM", "LOW_BIRD"]


func _guard_precise_bounce(precise: bool) -> void:
	_guard_flash_t = 0.30
	if not precise:
		GameManager.feedback.emit(Locale.t("feedback.guard_block"), "pop")
		return
	if rabbit.state in ["RIDING", "CROUCHING"]:
		rabbit.launch(turtle.get_mount_point(), turtle.speed, 0.0, 0.75)
		mount.mark_airborne()
	else:
		rabbit.velocity.y = minf(rabbit.velocity.y - 220.0, -520.0)
	rabbit.velocity.x += 120.0
	GameManager.add_score(50, "guard_precise")
	GameManager.feedback.emit(Locale.t("feedback.guard_precise"), "pop")


## BITT 主动接近 TUBO：真实移动，不是传送；玩家 ↑/↓ 仍可覆盖垂直自动。
func _tick_bro_catch(delta: float) -> void:
	if not _catch_active:
		return
	if mount.state == "RIDING" or rabbit.state == "RIDING" \
			or mount.state not in ["RESCUING", "RESCUE_FALLING", "RESCUE_ACTIVE", "RESCUE_AIR"]:
		_catch_active = false
		turtle.catch_target_y = -1.0
		return
	_catch_t -= delta
	if _catch_t <= 0.0:
		_catch_active = false
		turtle.catch_target_y = -1.0
		GameManager.feedback.emit(Locale.t("feedback.catch_fail"), "hit")
		return
	var target: Vector2 = rabbit.position + rabbit.velocity * 0.20
	var dx: float = target.x - turtle.position.x
	var step := clampf(dx, -CATCH_SPEED * delta, CATCH_SPEED * delta)
	turtle.position.x += step
	if step > 0.0:
		turtle.position.x = minf(turtle.position.x, target.x)
	elif step < 0.0:
		turtle.position.x = maxf(turtle.position.x, target.x)
	if absf(Input.get_axis("up", "down")) < 0.1:
		turtle.catch_target_y = clampf(target.y + 70.0, surface_ref(), 720.0)
	else:
		# FEEL-46：SPACE 主动救援必须以兔子为目标同时追 x/y。
		# 旧逻辑在玩家按住 ↓（最常见）时把垂直追索关掉，结果横向贴住了但
		# 高度差过大，can_rescue_catch 永远不成立，兔子随后憋死。
		turtle.catch_target_y = clampf(target.y + 70.0, surface_ref(), 720.0)
	_catch_fx_t = maxf(_catch_fx_t, 0.08)


func _tick_overdrive(delta: float) -> void:
	if test_no_overdrive:
		return
	_od_cd = maxf(_od_cd - delta, 0.0)
	_od_spring_t = maxf(_od_spring_t - delta, 0.0)
	_od_shell_t = maxf(_od_shell_t - delta, 0.0)
	# FEEL-22：事故/救援/表演/联合演出优先级高于过载。预兆或冲刺期间进入
	# 这些状态时取消，不把弹簧跳/旋壳带进别人的演出里。
	if _od_phase != "" and (GameManager.accident_state != "NONE"
			or showtime_active or joint_show_t > 0.0
			or _rescue_context() != "NONE"):
		_cancel_overdrive()
		return
	if _od_phase == "PRE":
		_od_t += delta
		if _od_t >= OD_PRE:
			_activate_overdrive(false)
		return
	if _od_phase == "ACTIVE":
		_od_t += delta
		var ap: Vector2 = rabbit.position if _od_role == "rabbit" else turtle.position
		_od_afterimages.append({"who": _od_role, "pos": ap, "t": 0.22})
		if _od_afterimages.size() > 10:
			_od_afterimages.pop_front()
		if _od_t >= OD_ACTIVE:
			_end_overdrive()
		return
	if _od_cd > 0.0 or GameManager.accident_state != "NONE" 			or showtime_active or joint_show_t > 0.0:
		return
	# FEEL-22：旧“神游到 MISCHIEF 自动触发 OVERDRIVE”的链已停用。
	# OVERDRIVE 只在现有明确入口显式启动（测试/演出），不再由时间驱动偷偷触发。
	return


func _start_overdrive(who: String) -> void:
	if _od_phase != "":
		return
	# 关键障碍前不起慢镜头预兆：先让玩家处理眼前的东西。
	var near := next_hazard_info()
	if not near.is_empty() and float(near.get("distance", 1e9)) <= 340.0:
		if GameManager.role_mischief_pending:
			GameManager.role_mischief_role = who
		return
	_od_role = who
	# 预兆本身就是“允许现在换走”的窗口：清掉 0.2 s 防连点锁，
	# 否则刚切到该角色就要等锁，慢镜头窗口只剩 0.1 s。
	GameManager.shift_lock_t = 0.0
	_od_phase = "PRE"
	_od_t = 0.0
	_od_autonomous = false
	_burst_who = who
	_burst_phase = "TELEGRAPH"
	_burst_t = 0.0
	_burst_cd = 0.0
	GameManager.feedback.emit(Locale.t(
		"feedback.od_ready_rabbit" if who == "rabbit"
		else "feedback.od_ready_turtle"), "hit")
	if who == "rabbit":
		rabbit.mischief_pose = true


func _activate_overdrive(shifted: bool) -> void:
	if _od_phase != "PRE" or _od_role == "":
		return
	var who := _od_role
	_od_phase = "ACTIVE"
	_od_t = 0.0
	_od_cd = OD_CD
	_od_autonomous = not shifted
	_burst_phase = "BURST"
	_burst_t = 0.0
	if shifted:
		_start_emphasis()
		var to_who: String = "turtle" if who == "rabbit" else "rabbit"
		# 这一次接力只从“实际完成的动作”里拿奖励；启动慢镜头本身不加分。
		_relay = {
			"from": who, "to": to_who, "action": "overdrive",
			"t": accident_event_time, "to_initial": _shift_action(to_who),
			"continued": true, "acted": false, "clean": false, "combo": false,
			"clean0": GameManager.clean_pass_count,
			"combo0": GameManager.combo_dive_count + GameManager.combo_ollie_count,
			"accidents0": GameManager.accident_count,
		}
	if who == "rabbit":
		_spring_overdrive()
		GameManager.feedback.emit(Locale.t("feedback.od_spring"), "pop")
	else:
		_shell_overdrive()
		GameManager.feedback.emit(Locale.t("feedback.od_shell"), "pop")
	_od_events.append({"who": who, "shifted": shifted,
		"t": snappedf(accident_event_time, 0.001)})


## TUBO：耳朵竖起、身体压缩，然后一次真正改变轨迹的弹簧跳。
func _spring_overdrive() -> void:
	_od_spring_t = OD_ACTIVE
	if rabbit.state in ["RIDING", "CROUCHING"]:
		rabbit.launch(turtle.get_mount_point(), turtle.speed, 0.0, 1.55)
		mount.mark_airborne()
	elif rabbit.state in ["JUMPING", "FALLING"]:
		rabbit.velocity.y = minf(rabbit.velocity.y - 260.0, -820.0)
	# 不写事故；只是轨迹更夸张，落点仍由物理决定。


## BITT：壳发光旋转，真正提速向前冲一段；不是自动下潜。
func _shell_overdrive() -> void:
	_od_shell_t = OD_ACTIVE
	turtle.diving = false
	turtle.standby_dive_t = 0.0
	turtle.speed = maxf(turtle.speed, turtle.base_speed + 160.0)
	turtle.overdrive_spin_t = OD_ACTIVE
	# 壳的旋转只改画法和速度，不改碰撞体/深度。


func _end_overdrive() -> void:
	_od_phase = ""
	_od_role = ""
	_od_autonomous = false
	_burst_who = ""
	_burst_phase = ""
	_burst_t = 0.0
	_burst_cd = OD_CD
	_od_cd = OD_CD
	rabbit.mischief_pose = false
	turtle.overdrive_spin_t = 0.0
	GameManager.feedback.emit(Locale.t("feedback.od_end"), "clean")


## FEEL-22：被更高优先级状态打断的过载。清干净，但不发“完成”反馈、
## 不补奖励，也不把冲刺动画留到事故/救援画面里。
func _cancel_overdrive() -> void:
	_od_phase = ""
	_od_role = ""
	_od_autonomous = false
	_od_t = 0.0
	_od_spring_t = 0.0
	_od_shell_t = 0.0
	_od_afterimages.clear()
	_burst_who = ""
	_burst_phase = ""
	_burst_t = 0.0
	_burst_cd = OD_CD
	_od_cd = OD_CD
	rabbit.mischief_pose = false
	turtle.overdrive_spin_t = 0.0


## 兼容旧测试/探针：旧名 _start_burst 现在就是启动电流走火预兆。
func _start_burst(who: String, _source: String) -> void:
	_start_overdrive(who)


func _end_burst() -> void:
	_end_overdrive()


func _rabbit_danger() -> bool:
	if rabbit.state in ["FALLING_WATER", "PASSED_OUT"]:
		return true
	return mount.state in ["RESCUING", "RESCUE_FALLING", "RESCUE_ACTIVE",
		"RESCUE_AIR"]


func _turtle_danger() -> bool:
	return turtle.accident or GameManager.oxygen <= 0.01 or _turtle_blocked_t > 0.0


## FEEL-10 P0-A：真正的联合事故——两人都在真实危险里，且进入时刻相差 ≤0.6 s。
func _update_true_joint(_delta: float) -> void:
	if joint_show_t > 0.0 or GameManager.accident_state == "BRO_BREAK":
		return
	var now := accident_event_time
	var rd := _rabbit_danger()
	var td := _turtle_danger()
	if rd and _rabbit_danger_since < 0.0:
		_rabbit_danger_since = now
	elif not rd:
		_rabbit_danger_since = -1.0
	if td and _turtle_danger_since < 0.0:
		_turtle_danger_since = now
	elif not td:
		_turtle_danger_since = -1.0
	if not rd and not td:
		if _joint_episode_done and now - _joint_done_t > JOINT_RESET:
			_joint_episode_done = false
		return
	if _joint_episode_done or _rabbit_danger_since < 0.0 or _turtle_danger_since < 0.0:
		return
	# 救援已经持续超过一个窗口：不让救援中的二次事故升级成全员冻结。
	if _rescue_context() != "NONE" \
			and now - _rabbit_danger_since > JOINT_WINDOW:
		return
	if absf(_rabbit_danger_since - _turtle_danger_since) <= JOINT_WINDOW:
		_joint_episode_done = true
		_joint_done_t = now
		GameManager.joint_accident_count += 1
		GameManager.add_score(-200, "joint")
		GameManager.clear_bro_meter()
		_start_joint_show()


func _start_joint_show() -> void:
	joint_show_t = JOINT_SHOW_TIME
	_joint_turtle_y = turtle.position.y
	GameManager.accident_state = "BRO_BREAK"
	hazard_cooldown = JOINT_SHOW_TIME + 1.2
	accident_flash = 0.8
	turtle.speed = 0.0
	GameManager.center_message.emit(Locale.t("center.bro_full"),
		Color(1.0, 0.35, 0.3))
	# 第三格的反馈就是联合惩罚本身；底部的旧碰撞提示/海浪建议会变成干扰
	# （玩家这时读到的会是“换回乌龟稳住”，和正在播的联合惩罚互相矛盾）。
	GameManager.prompt.emit("")
	GameManager.hint.emit("")


func _hold_joint_pose() -> void:
	# 原地抖动 + 闪白：够短，不抢玩家的判断时间，但看得出“这是第三格”。
	var t := JOINT_SHOW_TIME - joint_show_t
	turtle.position.y = _joint_turtle_y + absf(sin(t * 30.0)) * 4.0
	turtle.speed = 0.0
	rabbit.position = turtle.get_mount_point() + Vector2(0.0,
		absf(sin(t * 30.0 + 0.6)) * 6.0)


func _end_joint_show() -> void:
	joint_show_t = 0.0
	turtle.reset(Vector2(turtle.position.x, surface_ref()))
	turtle.speed = current_zone["base_speed"]
	rabbit.reset()
	rabbit.attach(turtle.get_mount_point())
	mount.reset()
	mount.mark_riding()
	GameManager.accident_state = "NONE"
	GameManager.clear_bro_meter()
	rabbit_grace = 1.5
	turtle_grace = 1.5
	# 联合惩罚结束不是“获救”：发 rescue_done 会让横幅错误显示“获救”。
	GameManager.center_message.emit(Locale.t("center.bro_recover"),
		Color(0.5, 1.0, 0.6))


## 表演 1.8 s 把控制权锁在乌龟，结束后还有 1 s 的恢复宽限（龟壳自动巡航、
## 下沉计时清零）。这段窗口里兔子的跳/趴做不了，下沉门也沉不下去——
## 连击刚好卡在障碍前触发表演，就变成“庆祝完直接撞”。
## 因此表演只在前面 900 px 没有兔子层障碍时开始；连击封顶在 3，
## 空档一到就会补上，不会丢奖励。
func _showtime_clear_ahead() -> bool:
	for g in hazard_groups:
		var group: Dictionary = g
		if not (group["kind"] in ["SURFACE_ROCK", "LOW_BEAM", "LOW_BIRD",
				"SHARK", "DIVE_GATE", "FLOATING_LOG"]):
			continue
		if turtle.position.x > _group_end(group) + 80.0:
			continue
		if _group_start(group) - turtle.position.x < SHOWTIME_CLEAR:
			return false
	return true


func _clear_penalty_state() -> void:
	GameManager.clear_bro_meter()
	GameManager.complaint_role = ""
	GameManager.complaint_t = 0.0
	GameManager.role_mischief_pending = false
	GameManager.role_mischief_role = ""
	GameManager.mischief_lock_role = ""
	_visual_stress = {"rabbit": 0.0, "turtle": 0.0}


func start_showtime() -> void:
	if showtime_active or GameManager.accident_state != "NONE":
		return
	if not _showtime_clear_ahead():
		return
	_clear_penalty_state()
	_showtime_cd = Tuning.SHOWTIME_CD
	showtime_active = true
	GameManager.showtime_active = true
	showtime_t = 0.0
	combo = 0
	GameManager.combo = 0
	showtime_prev_control = GameManager.current_control
	# 表演由兔子自动完成，但不抢玩家的控制权：奖励不应该打断正在做的判断。
	GameManager.center_message.emit(Locale.t("center.showtime"),
		Color(1.0, 0.85, 0.25))


func _tick_showtime(delta: float) -> void:
	showtime_t += delta
	var p := clampf(showtime_t / Tuning.SHOWTIME_TIME, 0.0, 1.0)
	var base: Vector2 = turtle.get_mount_point()
	var offset := 0.0
	var spin := 0.0
	# 小幅度：兔子小跳 + 一圈后空翻；乌龟一起小 ollie + 转一下。
	offset = -sin(p * PI) * 26.0
	spin = p * TAU
	rabbit.state = "SHOWTIME"
	rabbit.showtime_spin = spin
	rabbit.showtime_pose = p >= 0.7
	rabbit.position = base + Vector2(0.0, offset)
	_showtime_turtle_y = -sin(p * PI) * 22.0
	_showtime_turtle_spin = p * TAU
	if showtime_t >= Tuning.SHOWTIME_TIME:
		_end_showtime(true)


func _end_showtime(completed: bool) -> void:
	if not showtime_active:
		return
	showtime_active = false
	GameManager.showtime_active = false
	rabbit.showtime_spin = 0.0
	rabbit.showtime_pose = false
	_showtime_turtle_y = 0.0
	_showtime_turtle_spin = 0.0
	rabbit.attach(turtle.get_mount_point())
	mount.mark_riding()
	if completed:
		# Showtime 不再瞬间回满氧气，只给小幅回复；氧气不能被表演白送。
		var oxy_before := GameManager.oxygen
		GameManager.oxygen = minf(GameManager.oxygen + Tuning.SHOWTIME_OXYGEN,
			GameManager.oxygen_capacity())
		var oxy_gain := GameManager.oxygen - oxy_before
		GameManager.oxygen_phase = oxygen_phase()
		GameManager.showtime_count += 1
		GameManager.note_showtime()
		# FEEL-09 P0-D：完成奖励只在这里发一次。SHIFT 中断走 else 分支，
		# 不会经过这里，所以不存在“中断也发奖”。
		GameManager.add_score(100, "showtime")
		if oxy_gain < 0.05:
			GameManager.feedback.emit(
				Locale.t("feedback.showtime_reward_full"), "bro")
		else:
			GameManager.feedback.emit(
				Locale.t("feedback.showtime_reward", ["%.1f" % oxy_gain]), "bro")
		turtle_grace = 1.0
		rabbit_grace = 1.0
		GameManager.center_message.emit(Locale.t("center.showtime"),
			Color(1.0, 0.85, 0.25))
	else:
		# PHASE-FIX：Showtime 是小奖励，不因中途换人反扣一次滑落。
		rabbit_grace = 0.0


func showtime_left() -> float:
	return maxf(Tuning.SHOWTIME_TIME - showtime_t, 0.0)


## REBUILD-06 P3：水下伏击鲨。
##
## 四个相位：
##   DOWN      整条鱼在 528～720（任何可达深度都不碰），等待玩家进入唤醒距离；
##   TELEGRAPH 0.55 s，位置不变，只亮水面鳍/泡泡/“!”——这是“它要来了”的可读预告；
##   LUNGE     0.12 s 冲上水面，然后整条身体压住 288～480 共 1.4 s（只能跃起）；
##   RETREAT   0.55 s 退回深水，壳立刻失去支撑、自动放行（P0 的无限顶住就此结束）。
## 唤醒距离是“0.95 s 的航程”（见 shark_wake_px），所以三个区都是“壳碰到鱼
## 正好在预警后 0.95 s”，起跳窗口跨区一致；相位不用全局计时器。
func _is_ambush(group: Dictionary) -> bool:
	var motion: Dictionary = group.get("motion", {})
	return String(motion.get("name", "")) == "ambush_shark"


func _init_ambush() -> void:
	_ambush.clear()
	for g in hazard_groups:
		if _is_ambush(g):
			# 装载时统一在深水、且已经“醒着”：玩家一靠近立刻进入预警，
			# 不需要先等一段看不见的冷却（探针也从这个状态起跑）。
			_ambush[String(g["group"])] = {
				"phase": "DOWN", "t": Tuning.SHARK_REARM_TIME,
			}


## 探针用：把所有伏击鲨拨到指定相位重新起跑。只动测试状态，不改判定。
func reset_ambush_states(phase: String = "DOWN") -> void:
	for key in _ambush.keys():
		var t := Tuning.SHARK_REARM_TIME if phase == "DOWN" else 0.0
		_ambush[key] = {"phase": phase, "t": t}


## 唤醒距离按时间算：基础速度 × 0.95 s + 壳半宽。三个区都是“壳碰到鱼
## 正好在预警后 0.95 s”，所以起跳窗口跨区一致（见 tuning.gd 的几何推导）。
func shark_wake_px() -> float:
	var v: float = maxf(turtle.base_speed, 1.0)
	return v * Tuning.SHARK_WAKE_LEAD + Tuning.SHARK_SHELL_HALF


func _ambush_in_range(group: Dictionary) -> bool:
	var x: float = turtle.position.x
	var gs := _group_start(group)
	var ge := _group_end(group)
	return x >= gs - shark_wake_px() and x <= ge + 40.0


## 每物理帧推进一步；必须在 _check_hazards 之前调用，保证这一帧判的就是画的位置。
func _update_ambush_sharks(delta: float) -> void:
	if _ambush.is_empty():
		return
	for g in hazard_groups:
		if not _is_ambush(g):
			continue
		var key := String(g["group"])
		# FEEL-49：shark6 的相位由三只实体鲨群驱动，不再走单组 _ambush。
		# _ambush["shark6"] 只作为旧测试/调试的镜像，不参与移动。
		if key == "shark6":
			continue
		var st: Dictionary = _ambush.get(key, {"phase": "DOWN",
			"t": Tuning.SHARK_REARM_TIME})
		var phase := String(st["phase"])
		var old_phase := phase
		var t := float(st["t"]) + delta
		var is_pack := key == "shark6"
		# FEEL-32：小头目的第一段也必须给足 0.9 s 预警；普通鲨鱼保持原 0.55 s。
		var telegraph_time := PACK_LEAD_WARN if is_pack else Tuning.SHARK_TELEGRAPH_TIME
		match phase:
			"LUNGE":
				if t >= Tuning.SHARK_LUNGE_TIME:
					phase = "RETREAT"
					t = 0.0
			"RETREAT":
				if t >= Tuning.SHARK_RETREAT_TIME:
					phase = "DOWN"
					t = 0.0
			"DOWN":
				if t >= Tuning.SHARK_REARM_TIME and _ambush_in_range(g):
					phase = "TELEGRAPH"
					t = 0.0
			"TELEGRAPH":
				if t >= telegraph_time:
					phase = "LUNGE"
					t = 0.0
		_ambush[key] = {"phase": phase, "t": t}
		if is_pack and old_phase != phase:
			if phase == "TELEGRAPH":
				_shark_pack_log.append({"event": "warn", "who": "leader",
					"target": "turtle", "t": snappedf(hazard_clock, 0.01)})
				GameManager.feedback.emit(Locale.t("feedback.shark_boss_ready"), "hit")
			elif phase == "LUNGE":
				_shark_pack_log.append({"event": "attack", "who": "leader",
					"target": "turtle", "t": snappedf(hazard_clock, 0.01)})
			elif phase == "DOWN":
				_shark_pack_log.append({"event": "end", "who": "leader",
					"t": snappedf(hazard_clock, 0.01)})


## 当前相位对应的纵向位移。画、判定、顶住三处都只从这里取位移。
func _ambush_offset(key: String) -> float:
	var st: Dictionary = _ambush.get(key, {})
	if st.is_empty():
		return Tuning.SHARK_DOWN_OFFSET
	match String(st["phase"]):
		"LUNGE":
			var p := clampf(float(st["t"]) / Tuning.SHARK_RISE_TIME, 0.0, 1.0)
			return lerpf(Tuning.SHARK_DOWN_OFFSET, 0.0, p)
		"RETREAT":
			var p := clampf(float(st["t"]) / Tuning.SHARK_RETREAT_TIME, 0.0, 1.0)
			return lerpf(0.0, Tuning.SHARK_DOWN_OFFSET, p)
		_:
			return Tuning.SHARK_DOWN_OFFSET


## REBUILD-05 E2：动态障碍在“这一刻”的位移。
## motion = {} 时恒为零，静止障碍完全不受影响。
## 相位只看 hazard_clock（物理时间），不看玩家位置：这样同一个物体在
## 玩家眼里是“自己有节奏地动”，而不是“锁死在我的位置上的动画”。
func hazard_offset(group: Dictionary) -> Vector2:
	if String(group.get("identity", "")) == "state_net":
		return Vector2(0.0, _state_net_shift)
	var motion: Dictionary = group.get("motion", {})
	if motion.is_empty():
		return Vector2.ZERO
	if String(motion.get("name", "")) == "ambush_shark":
		return Vector2(0.0, _ambush_offset(String(group["group"])))
	var amp := float(motion.get("amp", 0.0))
	var bias := float(motion.get("bias", 0.0))
	var period := maxf(float(motion.get("period", 1.0)), 0.2)
	var phase := TAU * (hazard_clock / period + float(motion.get("phase", 0.0)))
	var v := bias + sin(phase) * amp
	if String(motion.get("axis", "y")) == "x":
		return Vector2(v, 0.0)
	return Vector2(0.0, v)


## 判定框只在这一处被“搬动”。_check_hazards、_draw_hazard、_draw_hitboxes 都走它。
func hazard_rect_live(group: Dictionary, index: int) -> Rect2:
	var rect: Rect2 = group["rects"][index]
	var offset := hazard_offset(group)
	if offset == Vector2.ZERO:
		return rect
	return Rect2(rect.position + offset, rect.size)


## 动态障碍的“节奏读数”：给探针和 HUD 用，0..1 表示离周期的哪一段。
func hazard_motion_state(group: Dictionary) -> Dictionary:
	var motion: Dictionary = group.get("motion", {})
	if motion.is_empty():
		return {}
	if String(motion.get("name", "")) == "ambush_shark":
		var key := String(group["group"])
		var st: Dictionary = _ambush.get(key, {})
		return {
			"name": "ambush_shark",
			"phase": String(st.get("phase", "DOWN")),
			"t": float(st.get("t", 0.0)),
			"offset": hazard_offset(group),
			"wake_px": shark_wake_px(),
			"axis": "y",
		}
	var period := maxf(float(motion.get("period", 1.0)), 0.2)
	var phase := TAU * (hazard_clock / period + float(motion.get("phase", 0.0)))
	return {
		"t": fmod(hazard_clock + float(motion.get("phase", 0.0)) * period, period),
		"period": period,
		"sin": sin(phase),
		"cos": cos(phase),
		"offset": hazard_offset(group),
		"amp": float(motion.get("amp", 0.0)),
		"bias": float(motion.get("bias", 0.0)),
		"axis": String(motion.get("axis", "y")),
	}


func _group_start(group: Dictionary) -> float:
	var start_x := 1.0e9
	for r in group["rects"]:
		var rect: Rect2 = r
		start_x = minf(start_x, rect.position.x)
	return start_x


func _group_end(group: Dictionary) -> float:
	var end_x := 0.0
	for r in group["rects"]:
		var rect: Rect2 = r
		end_x = maxf(end_x, rect.end.x)
	return end_x


func next_hazard_info() -> Dictionary:
	var best := {}
	var best_d := 1.0e9
	for g in hazard_groups:
		var group: Dictionary = g
		if _shark_arena_hides(group):
			continue
		var rect: Rect2 = group["rects"][0]
		var d: float = rect.position.x - turtle.position.x
		if d < -60.0:
			continue
		if d < best_d:
			best_d = d
			best = {
				"group": group["group"],
				"kind": group["kind"],
				"distance": maxf(d, 0.0),
				"end": _group_end(group),
				# 探针会注入只带判定框的合成组；缺 hint/action 时不能中断物理帧。
				"hint": String(group.get("hint", "")),
				"action": String(group.get("action", "")),
			}
	return best


## REBUILD-05 G2：BRO DIVE 的“该松手了”读数，给正式 HUD 用。
## B3 实测：一直按住 ↓ 会把壳停在水下 150 px，兔子落壳时擦水记一次事故，
## 而画面上只有水花差别。条件全部只读已发生的状态——兔子还在空中（没落壳）、
## 壳仍在主动下潜、壳已越过浮木右缘 40 px（B3 的标准松手点）。
## 不加惩罚、不改判定；松手后 turtle.diving 变 false，提示自然消失。
const DIVE_RELEASE_EDGE_PX := 40.0
const DIVE_RELEASE_SPAN_PX := 400.0

## CORE-FEEL-07 P0-A：辅助下潜的参数。
## 起跳时前方 900 px 内有浮木就把组合“上膛”；SHIFT 到乌龟后自动下潜。
## 自动上浮点沿用旧松手点（右缘 + 40 px），上浮保持 1.4 s（兔子滞空 1.2 s），
## 中途接住兔子就立刻把控制权还给玩家。
const DIVE_ASSIST_ARM_PX := 900.0
const DIVE_ASSIST_PASS_PX := DIVE_RELEASE_EDGE_PX
const DIVE_ASSIST_SURFACE_TIME := 1.4


## 兔子起跳那一刻调用：前方最近的障碍是浮木、且在 900 px 内，就上膛。
## 上膛不等于执行——不 SHIFT 就不会下潜，也不会替玩家起跳。
func _arm_dive_assist() -> void:
	if not Tuning.SURFBOARD_PHYSICS:
		return
	if dive_assist != "OFF":
		return
	var info: Dictionary = next_hazard_info()
	if String(info.get("kind", "")) != "FLOATING_LOG":
		return
	if float(info.get("distance", 1.0e9)) > DIVE_ASSIST_ARM_PX:
		return
	dive_assist = "ARMED"
	dive_assist_key = String(info["group"])
	dive_assist_end = float(info["end"])
	dive_assist_t = 0.0


## 前方最近的障碍是浮木时，起跳按“BRO DIVE 大跳”处理（更高、滞空更长）。
## 只影响起跳初速，碰撞弧线仍然是真实物理。
func _log_jump_scale() -> float:
	if not Tuning.SURFBOARD_PHYSICS:
		return 1.0
	var info: Dictionary = next_hazard_info()
	if String(info.get("kind", "")) != "FLOATING_LOG":
		return 1.0
	if float(info.get("distance", 1.0e9)) > DIVE_ASSIST_ARM_PX:
		return 1.0
	return Tuning.LOG_JUMP_HEIGHT_SCALE


## 每帧改写垂直轴：1 = 保持下潜，-1 = 自动上浮（不改水位，只松开下潜），0 = 交回玩家。
func _tick_dive_assist(delta: float, turtle_controlled: bool) -> int:
	match dive_assist:
		"ARMED":
			# 直接控制/测试代理也可能绕过 shift 信号；只要现在控乌龟就接管。
			if turtle_controlled:
				dive_assist = "ACTIVE"
				dive_assist_t = 0.0
				return 1
			# 玩家没换人：浮木整段过去就作废。
			if turtle.position.x > dive_assist_end + DIVE_ASSIST_PASS_PX:
				_clear_dive_assist()
			return 0
		"ACTIVE":
			# 壳中心越过浮木右缘 + 40 px 才开始上浮：比“画出来的位置”留了余量，
			# 与旧的手动松手点同一个读数，只是不再需要玩家卡这个点。
			if turtle.position.x >= dive_assist_end + DIVE_ASSIST_PASS_PX:
				dive_assist = "SURFACING"
				dive_assist_t = DIVE_ASSIST_SURFACE_TIME
				return 0
			return 1 if turtle_controlled else 0
		"SURFACING":
			dive_assist_t = maxf(dive_assist_t - delta, 0.0)
			# 接住兔子（或兔子落水进救援）就把控制权立刻交回，不额外锁 1.4 s。
			if dive_assist_t <= 0.0 or mount.state != "AIRBORNE":
				_clear_dive_assist()
				return 0
			return -1 if turtle_controlled else 0
	return 0


func _clear_dive_assist() -> void:
	dive_assist = "OFF"
	dive_assist_key = ""
	dive_assist_end = 0.0
	dive_assist_t = 0.0


func dive_assist_state() -> String:
	return dive_assist


func dive_release_ready() -> bool:
	# CORE-FEEL-07 P0-A：辅助下潜期间上浮是自动的，不再提示“松开 ↓”。
	if dive_assist != "OFF":
		return false
	if mount.state != "AIRBORNE":
		return false
	if not turtle.diving:
		return false
	if turtle.position.y <= surface_ref() + 60.0:
		return false
	for g in hazard_groups:
		var group: Dictionary = g
		if String(group["kind"]) != "FLOATING_LOG":
			continue
		var live: Rect2 = hazard_rect_live(group, 0)
		var d: float = turtle.position.x - live.end.x
		if d >= DIVE_RELEASE_EDGE_PX and d <= DIVE_RELEASE_EDGE_PX + DIVE_RELEASE_SPAN_PX:
			return true
	return false


func surface_y() -> float:
	# HUD 的“水下”提示跟着模型基准走：旧模型 300，冲浪板模型巡航水深。
	return surface_ref()


func zone_name() -> String:
	return current_zone["name"]


func zone_id() -> int:
	return current_zone["id"]


func progress() -> float:
	return clampf(turtle.position.x / world_end, 0.0, 1.0)


func total_groups() -> int:
	return hazard_groups.size()


func passed_count() -> int:
	return passed_groups.size()


## HUD 只用这两个数：当前的晃动强度。
## Phase G 后 daze_time 封顶在 DAZE_CAP，归一化必须也用它——
## 旧分母 9.5 会让条永远停在 38%，等于把“还有一套隐藏风险”画在屏幕上。
## 待命时 daze_time 冻结，所以待命不会让这两个数自己变大。
func rabbit_imbalance_pct() -> int:
	if rabbit == null:
		return 0
	return clampi(int(round(rabbit.daze_time / Tuning.DAZE_CAP * 100.0)), 0, 100)


func turtle_imbalance_pct() -> int:
	if turtle == null:
		return 0
	return clampi(int(round(turtle.daze_time / Tuning.DAZE_CAP * 100.0)), 0, 100)


func _inset(rect: Rect2, n: float) -> Rect2:
	return Rect2(rect.position + Vector2(n, n),
		rect.size - Vector2(n * 2.0, n * 2.0))


func _update_display() -> void:
	GameManager.turtle_state = turtle.state
	GameManager.rabbit_state = rabbit.state
	if turtle.state in ["RELAXED", "SINKING", "DEEP", "CRITICAL"]:
		GameManager.turtle_phase = turtle.phase_label()
	else:
		GameManager.turtle_phase = turtle.state
	if rabbit.state in ["RELAXED", "SLIDING", "EDGE", "CRITICAL"]:
		GameManager.rabbit_phase = rabbit.phase_label()
	else:
		GameManager.rabbit_phase = rabbit.state
	GameManager.turtle_speed = turtle.speed
	GameManager.slide_progress = rabbit.slide
	GameManager.mount_state = mount.state
	GameManager.combo = combo
	GameManager.combo_max = combo_max
	GameManager.showtime_active = showtime_active
	GameManager.oxygen_phase = oxygen_phase()


## 镜头固定前瞻 300 px，垂直中心压到 300：角色和前方障碍落在画面中段，
## 下面不再是一整屏空水。全程只有 x 跟随，换人不产生镜头跳动。
func _update_camera() -> void:
	if camera != null:
		var shake := Vector2.ZERO
		if _camera_pulse_t > 0.0:
			# SHIFT 的镜头脉冲：2 px、0.11 s，只抖画面，不改相机跟随目标。
			var k := _camera_pulse_t / CAMERA_PULSE_TIME
			shake = Vector2(sin(_camera_pulse_t * 140.0), -0.5) * CAMERA_PULSE_PX * k
		if _shake_t > 0.0 and _shake_dur > 0.0:
			# 碰撞震动：快速衰减的横抖为主，第一帧就是峰值 = 配置幅度。
			var k2 := _shake_t / _shake_dur
			var elapsed := _shake_dur - _shake_t
			var impact := Vector2(cos(elapsed * 118.0),
				sin(elapsed * 97.0) * 0.55) * _shake_amp * k2 * k2
			_shake_peak = maxf(_shake_peak, absf(impact.x))
			shake += impact
		camera.position = Vector2(turtle.position.x + 300.0, 300.0) + shake


## CORE-FEEL-08 P1-D：第二区域的分层背景只在这条路径上更新。
## 相机不在 Z2 时整组节点不可见、不重绘；进入后才逐层喂 x。
## 背景与碰撞完全无关：这里不读也不写任何判定状态。
func _update_dock() -> void:
	var dock := get_node_or_null("Zone2Dock")
	if dock == null or camera == null:
		return
	dock.update_cam(camera.position.x)


## 撞击表现停顿：只冻结画法位置，物理与控制照常。who 决定“谁更重”。
func _trigger_hitstop(who: String) -> void:
	_hitstop_dur = HITSTOP_TURTLE if who == "turtle" else HITSTOP_RABBIT
	_hitstop_t = _hitstop_dur
	_hitstop_who = who
	_hitstop_draw = turtle.position if who == "turtle" else rabbit.position
	hitstop_log.append({
		"who": who, "s": _hitstop_dur,
		"x": snappedf(_hitstop_draw.x, 1.0),
		"accident": GameManager.accident_state,
	})


## 镜头震动：major 给浪击/落水，普通碰撞给 normal。不改任何物理量。
func _trigger_shake(major: bool) -> void:
	_shake_dur = SHAKE_MAJOR_TIME if major else SHAKE_NORMAL_TIME
	_shake_t = _shake_dur
	_shake_amp = SHAKE_MAJOR_PX if major else SHAKE_NORMAL_PX
	_shake_peak = 0.0
	shake_log.append({
		"major": major, "amp": _shake_amp, "s": _shake_dur,
		"x": snappedf(turtle.position.x, 1.0),
	})


## 落地水花记在真实落点；0.4 s 内扩散消失。
func _spawn_land_splash(p: Vector2) -> void:
	land_splash_pos = p
	land_splash_t = 0.0


## 主动动作成功演出：dive（BRO DIVE）与 ollie（BRO OLLIE）分开。
func _trigger_action_fx(kind: String, p: Vector2) -> void:
	action_fx_kind = kind
	action_fx_pos = p
	action_fx_t = 0.0
	_celebrate(kind)
	action_fx_log.append({"kind": kind, "x": snappedf(p.x, 1.0)})


## G4/G5：角色本体的一下弹跳。只写画法计时器，重新成功会重新计时。
func _celebrate(kind: String) -> void:
	celebrate_kind = kind
	celebrate_t = 0.0


## G4：庆祝弹跳的画法偏移（零到峰值再回零）。只被 _draw_rabbit 使用。
func celebration_offset() -> Vector2:
	if celebrate_t < 0.0 or celebrate_t > CELEBRATE_TIME:
		return Vector2.ZERO
	var k: float = celebrate_t / CELEBRATE_TIME
	return Vector2(0.0, -sin(PI * k) * CELEBRATE_HOP_PX)


## G9：兔子落回壳上的重量反应。落壳当帧最大下沉，期间轻微回弹，0.26 s 归零。
## 只被 _draw_turtle 使用；turtle.position、判定框、接应距离都不读它。
func _shell_dip(amp: float) -> void:
	shell_dip_t = 0.0
	shell_dip_amp = amp
	shell_dip_peak = 0.0


## 下沉使壳向下（+y）。k=0 当帧最大，k=1 归零；中间一次小幅回弹（约 1/3 幅度）。
func shell_dip_offset() -> float:
	if shell_dip_t < 0.0 or shell_dip_t > Tuning.SHELL_DIP_TIME:
		return 0.0
	var k: float = clampf(shell_dip_t / Tuning.SHELL_DIP_TIME, 0.0, 1.0)
	return shell_dip_amp * (1.0 - k) * cos(k * PI * 1.5)


## REFINE-06 P1：换到正在神游的角色时，立刻告诉玩家“这一手正在起效”。
## 只是反馈，不给任何加速/清零——真正的恢复仍要连续受控 0.5 s（bro_brain.gd）。
func _on_shift_take(from: String, to: String) -> void:
	# FEEL-12：预兆窗口里把“当前受控角色”换走 → BRO OVERDRIVE。
	if _od_phase == "PRE" and from == _od_role:
		_activate_overdrive(true)
	elif _od_phase == "ACTIVE":
		# 慢镜头中允许正常换人，但同一事件不再判一次特殊奖励。
		pass
	else:
		# FEEL-11 B3：普通换手才进入接力观测。
		_start_relay(from, to)
	# FEEL-22：SHIFT 后旧角色的未完成输入不得交给新角色。
	# 清掉 ↑ 缓存和旧 ↓ 延迟；新角色只接受 SHIFT 之后的新输入。
	_buf_action = ""
	_buf_age = 0.0
	_buf_delay = 0.0
	_down_delay = 0.0
	# FEEL-47：如果这次是“浮木前兔子刚起跳 → SHIFT 乌龟”，保留辅助下潜并激活。
	# 以前这里无条件清掉，玩家只能靠手速把乌龟按到足够深，晚半拍就卡在木前。
	var armed_dive := dive_assist == "ARMED"
	dive_assist = "OFF"
	turtle.standby_dive_t = 0.0
	if to == "turtle" and armed_dive:
		dive_assist = "ACTIVE"
		dive_assist_t = 0.0
	# CORE-FEEL-07 P0-A：起跳之后 SHIFT 到乌龟，就是“该下潜了”。
	# FEEL-22 起这条自动接管已停用；下潜必须由玩家按 ↓。
	var brain = rabbit_brain if to == "rabbit" else turtle_brain
	if brain == null:
		return
	if String(brain.state_name()) == "CALM":
		return
	GameManager.feedback.emit(Locale.t("feedback.shift_take",
		[Locale.t("who." + to)]), "bro")


## 当前这个身体正在做的、值得接力的动作。空串 = 普通巡航，不值得判接力。
func _shift_action(who: String) -> String:
	if who == "rabbit":
		if rabbit.state in ["JUMPING", "FALLING"]:
			return "jump"
		if rabbit.state == "CROUCHING":
			return "crouch"
	else:
		if turtle.leap_active:
			return "leap"
		if turtle.diving or turtle.standby_dive_t > 0.0:
			return "dive"
	return ""


## SHIFT 当帧：如果切出的身体正在做一个动作，开一个观测窗口。
## 普通巡航换人不开窗口——不能只按 SHIFT 就拿奖励。
func _start_relay(from: String, to: String) -> void:
	if GameManager.accident_state != "NONE" \
			or mount.state in ["RESCUING", "RESCUE_FALLING", "RESCUE_ACTIVE",
				"RESCUE_AIR", "CARRYING"]:
		_relay = {}
		return
	if _relay_cd > 0.0:
		return
	var act := _shift_action(from)
	if act == "":
		return
	if not _relay.is_empty():
		_finalize_relay(false)
	_relay = {
		"from": from, "to": to, "action": act,
		"t": accident_event_time,
		"to_initial": _shift_action(to),
		"continued": false, "acted": false, "clean": false, "combo": false,
		"clean0": GameManager.clean_pass_count,
		"combo0": GameManager.combo_dive_count + GameManager.combo_ollie_count,
		"accidents0": GameManager.accident_count,
	}


## 每物理帧更新窗口：切出者是否做完动作、切入者是否接手做另一个动作、
## 窗口内是否干净通过/完成组合。任何事故都会取消奖励。
func _tick_shift_relay(delta: float) -> void:
	_relay_cd = maxf(_relay_cd - delta, 0.0)
	_relay_fx_t = maxf(_relay_fx_t - delta, 0.0)
	if _relay.is_empty():
		return
	var elapsed := accident_event_time - float(_relay["t"])
	var from := String(_relay["from"])
	var to := String(_relay["to"])
	var act := String(_relay["action"])
	if from == "rabbit":
		if act == "jump" and rabbit.state in ["JUMPING", "FALLING"]:
			_relay["continued"] = true
		elif act == "crouch" and rabbit.state == "CROUCHING":
			_relay["continued"] = true
	else:
		if act == "leap" and turtle.leap_active:
			_relay["continued"] = true
		elif act == "dive" and (turtle.diving or turtle.standby_dive_t > 0.0):
			_relay["continued"] = true
	var incoming := _shift_action(to)
	if incoming != "" and incoming != String(_relay["to_initial"]):
		_relay["acted"] = true
	if GameManager.clean_pass_count > int(_relay["clean0"]):
		_relay["clean"] = true
	var combo_now := GameManager.combo_dive_count + GameManager.combo_ollie_count
	if combo_now > int(_relay["combo0"]):
		_relay["combo"] = true
	if GameManager.accident_count > int(_relay["accidents0"]):
		_finalize_relay(false)
		return
	# 组合/干净通过一到就立刻结算，不必等满窗口；否则 0.85 s 后再判“巧妙”。
	if bool(_relay["continued"]) and bool(_relay["acted"]) \
			and (bool(_relay["clean"]) or bool(_relay["combo"])):
		_finalize_relay(true)
		return
	if elapsed >= RELAY_WINDOW:
		_finalize_relay(true)


## 结算一次接力：普通 = 无奖励；巧妙 = 两边都动 +50；完美 = 再加干净通过/组合 +100。
func _finalize_relay(allow: bool) -> void:
	if _relay.is_empty():
		return
	var r := _relay
	_relay = {}
	var elapsed := accident_event_time - float(r["t"])
	var result := "normal"
	if allow and bool(r["continued"]) and bool(r["acted"]) \
			and GameManager.accident_count == int(r["accidents0"]):
		if bool(r["clean"]) or bool(r["combo"]):
			result = "perfect"
		else:
			result = "clever"
	if result == "perfect":
		GameManager.add_score(100, "relay_perfect")
		GameManager.feedback.emit(Locale.t("feedback.relay_perfect"), "relay")
		_relay_fx_kind = "perfect"
		_relay_fx_pos = _relay_body_pos(String(r["to"]))
		_relay_fx_t = RELAY_FX_TIME
	elif result == "clever":
		GameManager.add_score(50, "relay_clever")
		GameManager.feedback.emit(Locale.t("feedback.relay_clever"), "relay")
		_relay_fx_kind = "clever"
		_relay_fx_pos = _relay_body_pos(String(r["to"]))
		_relay_fx_t = RELAY_FX_TIME
	_relay_cd = RELAY_COOLDOWN
	relay_log.append({
		"from": String(r["from"]), "to": String(r["to"]),
		"action": String(r["action"]), "continued": bool(r["continued"]),
		"acted": bool(r["acted"]), "clean": bool(r["clean"]),
		"combo": bool(r["combo"]), "result": result,
		"elapsed": snappedf(elapsed, 0.001),
		"score": 100 if result == "perfect" else (50 if result == "clever" else 0),
	})


func _relay_body_pos(who: String) -> Vector2:
	return rabbit.position if who == "rabbit" else turtle.position


## 接力成功的环：巧妙=青色，完美=金色；不冻结、不挡输入，只画 0.65 s。
func _draw_overdrive_fx() -> void:
	if _od_emphasis_t <= 0.0:
		return
	var k := _od_emphasis_t / 0.70
	if _od_flash > 0.0:
		draw_rect(Rect2(camera.position.x - 1400.0, -400.0, 2800.0, 1600.0),
			Color(0.65, 0.95, 1.0, 0.10 * _od_flash / 0.25))
	for g in _od_afterimages:
		var a := clampf(float(g["t"]) / 0.22, 0.0, 1.0)
		var p: Vector2 = g["pos"]
		var col := Color(0.45, 0.95, 1.0, 0.22 * a)
		if String(g["who"]) == "turtle":
			draw_circle(p, 34.0, col)
		else:
			draw_circle(p, 22.0, col)
		draw_arc(p, 40.0 + (1.0 - a) * 20.0, 0, TAU, 20, col, 2.0)


func _draw_relay_fx() -> void:
	if _relay_fx_t <= 0.0:
		return
	var k := _relay_fx_t / RELAY_FX_TIME
	var perfect := _relay_fx_kind == "perfect"
	var col := Color(1.0, 0.82, 0.28, 0.9 * k) if perfect \
		else Color(0.45, 0.95, 1.0, 0.85 * k)
	for i in 2:
		draw_arc(_relay_fx_pos, 28.0 + i * 10.0 + (1.0 - k) * 18.0,
			0.0, TAU, 36, col, 3.0 if i == 0 else 1.5)
	draw_string(ThemeDB.fallback_font,
		_relay_fx_pos + Vector2(-70.0, -54.0 - (1.0 - k) * 12.0),
		Locale.t("feedback.relay_perfect" if perfect else "feedback.relay_clever"),
		HORIZONTAL_ALIGNMENT_CENTER, 140, 16, col)


## 伙伴从任意神游阶段回到 CALM 的那一帧报一次“回过神了”。
## 快速连点换人不会触发：恢复要 0.5 s 站稳 + 2.0/s 回落，白嫖不到。
## CORE-FEEL-07 P1-D：越过 6 s（坐不住）/ 9 s（要惹麻烦）阈值时各报警一次，
## 并把这一刻真正生效的代价写进提示；只报升级，降级不刷屏。
func _tick_drift_feedback() -> void:
	for who in ["rabbit", "turtle"]:
		var state: String = rabbit_brain.state_name() if who == "rabbit" \
			else turtle_brain.state_name()
		if state == "CALM" and String(_last_drift_state[who]) != "CALM" \
				and GameManager.current_control == who:
			GameManager.feedback.emit(Locale.t("feedback.drift_back",
				[Locale.t("who." + who)]), "bro")
		var rank := _drift_rank(state)
		if rank > int(_last_drift_rank[who]) and rank >= 2:
			var key := "feedback.drift_warn_mischief" if rank >= 3 \
				else "feedback.drift_warn_restless"
			GameManager.feedback.emit(Locale.t(key, [
				Locale.t("who." + who), _drift_effect_text(who)]),
				"hit" if rank >= 3 else "pop")
		_last_drift_state[who] = state
		_last_drift_rank[who] = rank


## CORE-FEEL-08 P0-A：这一刻该角色按下动作要晚多久才“听见”。
## 只按神游量算，和是否刚换人无关；CALM 返回 0，延迟为 0 时不写记录。
## 分段线性，和四档严格对齐（每档的两端都写死，不靠一个总斜率）：
##   3–6 s：0.04 → 0.10    6–9 s：0.10 → 0.18    9–12 s：0.18 → 0.22/0.26
## CALM（< 3 s）为 0：低阶段不该有明显延迟，只有位置/晃动的轻干扰。
func _drift_react_delay(who: String) -> float:
	var d: float = rabbit.drift if who == "rabbit" else turtle.drift
	if d < Tuning.DRIFT_CALM_END:
		return 0.0
	if d < Tuning.DRIFT_DISTRACTED_END:
		var p := (d - Tuning.DRIFT_CALM_END) \
			/ (Tuning.DRIFT_DISTRACTED_END - Tuning.DRIFT_CALM_END)
		return lerpf(Tuning.DRIFT_REACT_MIN, 0.10, p)
	if d < Tuning.DRIFT_RESTLESS_END:
		var q := (d - Tuning.DRIFT_DISTRACTED_END) \
			/ (Tuning.DRIFT_RESTLESS_END - Tuning.DRIFT_DISTRACTED_END)
		return lerpf(0.10, 0.18, q)
	var r := clampf((d - Tuning.DRIFT_RESTLESS_END)
		/ (Tuning.DRIFT_CAP - Tuning.DRIFT_RESTLESS_END), 0.0, 1.0)
	var peak := Tuning.DRIFT_REACT_RABBIT_MAX if who == "rabbit" \
		else Tuning.DRIFT_REACT_TURTLE_MAX
	return lerpf(0.18, peak, r)


## 探针/报告读数：毫秒。
func drift_react_delay_ms(who: String) -> int:
	return int(round(_drift_react_delay(who) * 1000.0))


## 神游延迟生效时给一次可见反馈；同一角色 2.5 s 内只说一次，避免刷屏。
func _note_drift_lag(who: String, channel: String) -> void:
	if _drift_impair_clock - float(_drift_lag_fb_t.get(who, -99.0)) < 2.5:
		return
	_drift_lag_fb_t[who] = _drift_impair_clock
	var key := "feedback.drift_lag_rabbit" if who == "rabbit" \
		else "feedback.drift_lag_turtle"
	GameManager.feedback.emit(Locale.t(key), "hit")
	drift_impair_log.append({
		"who": who, "kind": "lag", "channel": channel,
		"delay_ms": drift_react_delay_ms(who), "t": _drift_impair_clock,
	})


## 这一刻真正被“听见”的 ↓。按下沿的延迟由 race 统一算，控制器只读结果。
func _gated_down() -> bool:
	return Input.is_action_pressed("down") and _down_delay <= 0.0


## CORE-FEEL-08 P0-A：每帧推进神游干扰时钟。
## 延迟只挂在“按下沿”：↑ 的按下先进缓存、到点才交付；↓ 的按下到点才算被听见。
## 按住不放的持续输入不叠加延迟——松开再按才重新等一次，所以不会出现“一直没反应”。
func _tick_drift_impair(delta: float) -> void:
	_drift_impair_clock += delta
	_drift_auton_t += delta
	_buf_delay = maxf(_buf_delay - delta, 0.0)
	_down_delay = maxf(_down_delay - delta, 0.0)
	var down_now: bool = Input.is_action_pressed("down")
	if down_now and not _down_was_pressed:
		var who: String = GameManager.current_control
		var react := _drift_react_delay(who)
		if react > 0.0:
			_down_delay = maxf(_down_delay, react)
			if react >= 0.10:
				_note_drift_lag(who, "down")
	_down_was_pressed = down_now


## FEEL-12 C：旧“自己趴一下”的恶作剧动作已移除；高阶段只做电流走火预兆，
## 不再让 TUBO 自动趴低。低阶段的小延迟仍由 _tick_drift_impair 负责。
func _tick_drift_autonomy(_delta: float) -> void:
	_bitt_autocrouch_left = 0.0
	_bitt_autocrouch_t = 0.0


## TUBO 的自主动作：恶作剧时壳围着巡航水深自己漂 ±14 px（慢，看得见）。
## 写的是目标深度偏移；玩家按 ↓（下潜目标）或氧气强制上浮时它被整段覆盖。
func _tubo_autodrift() -> float:
	var st := String(turtle_brain.state_name()) if turtle_brain != null else "CALM"
	if st == "MISCHIEF":
		return sin(_drift_auton_t * 1.1) * Tuning.TUBO_AUTODRIFT_PX
	if st == "RESTLESS":
		# 重度：壳开始有可见的自漂，但只有满值的一半。
		return sin(_drift_auton_t * 0.8) * (Tuning.TUBO_AUTODRIFT_PX * 0.5)
	return 0.0


## FEEL-15：BRO MISCHIEF。惩罚条满只对“未受控”的角色生效。
## 一个事件只有一个角色；SHIFT 当帧取消旧角色，新的未受控满格角色可以接管。
func _tick_mischief(delta: float) -> void:
	GameManager.tick_complaint(delta)
	_mischief_cd = maxf(_mischief_cd - delta, 0.0)
	_mischief_fx_t = maxf(_mischief_fx_t - delta, 0.0)
	if _mischief_last_control != GameManager.current_control:
		_mischief_last_control = GameManager.current_control
		if _mischief_role != "" and _mischief_role == GameManager.current_control:
			_end_mischief("shifted")
	if _mischief_role != "":
		# 救援/落水/Showtime 的优先级高于普通捣乱。
		if _mischief_role == GameManager.current_control 				or _rescue_context() != "NONE" or showtime_active:
			_end_mischief("priority")
			return
		_mischief_t += delta
		if _mischief_phase == "TELEGRAPH":
			if _mischief_t >= MISCHIEF_TELEGRAPH:
				_mischief_phase = "ACTION"
				_mischief_t = 0.0
				_mischief_action_done = false
		elif _mischief_phase == "ACTION":
			if not _mischief_action_done:
				_mischief_action_done = true
				_apply_mischief_action()
			if _mischief_t >= MISCHIEF_ACTION:
				_mischief_phase = "END"
				_mischief_t = 0.0
		elif _mischief_phase == "END":
			if _mischief_t >= MISCHIEF_END:
				_end_mischief("completed")
	else:
		_maybe_start_mischief()


func _tick_visual_stress(delta: float) -> void:
	# FEEL-49：不再按“每撞一次永久加一格”慢慢衰减。受击表现是短时的：
	# 一次撞击约 2 秒内消失；只有短时间内连续挨打才会叠到第二/第三段。
	for who in ["rabbit", "turtle"]:
		_visual_stress[who] = maxf(float(_visual_stress[who]) - delta * 0.45, 0.0)


func visual_stress(who: String) -> float:
	return float(_visual_stress.get(who, 0.0))


func _bump_visual_stress(who: String, amount: float = 1.0) -> void:
	if who not in ["rabbit", "turtle"]:
		return
	_visual_stress[who] = clampf(float(_visual_stress[who]) + amount, 0.0, 3.0)


func _relieve_visual_stress(who: String, amount: float = 0.6) -> void:
	if who not in ["rabbit", "turtle"]:
		return
	_visual_stress[who] = maxf(float(_visual_stress[who]) - amount, 0.0)


func _visual_stage(who: String) -> int:
	var v := visual_stress(who)
	if v >= 2.2:
		return 3
	if v >= 1.1:
		return 2
	if v > 0.1:
		return 1
	return 0


func _draw_visual_stress(pos: Vector2, who: String) -> void:
	var stage := _visual_stage(who)
	if stage <= 0:
		return
	# 不画三格“血条”，只画一次短促的受击符号：撞一下就是一下，
	# 连续挨打才让符号变大、变红。
	var col := Color(1.0, 0.82, 0.32, 0.95)
	if stage >= 3:
		col = Color(1.0, 0.28, 0.22, 0.98)
	elif stage == 2:
		col = Color(1.0, 0.56, 0.20, 0.96)
	var t := Time.get_ticks_msec() * 0.012
	var p := pos + Vector2(0, -84.0 + sin(t) * 3.0)
	draw_arc(p, 15.0 + stage * 3.0, -0.7, 0.7, 14, col, 3.0)
	draw_string(ThemeDB.fallback_font, p + Vector2(-6, 9),
		"!" if stage < 3 else "!!", HORIZONTAL_ALIGNMENT_LEFT, -1,
		22 + stage * 3, col)


func _mischief_clear_of_hazards() -> bool:
	var near := next_hazard_info()
	if near.is_empty():
		return true
	return float(near.get("distance", 1.0e9)) > 520.0


func _maybe_start_mischief() -> void:
	if test_no_mischief:
		return
	if _mischief_cd > 0.0 or showtime_active or _rescue_context() != "NONE":
		return
	# 不在障碍前启动捣乱，避免速度损失直接变成必然撞。520 px 在 Z3
	# 260 px/s 下约 2 s，足够从预兆里切回来。
	if not _mischief_clear_of_hazards():
		return
	# 一次失误只生成一次抱怨窗口；没有 3 格计数。
	var who := GameManager.complaint_role
	if who == "" or who == GameManager.current_control:
		return
	# 给玩家 1.2 s 的“我把谁留失控了”反应时间，再动手。
	if GameManager.complaint_t > 7.0 - MISCHIEF_REACTION_DELAY:
		return
	# 救援优先：兔子在水里时，先让玩家切 BITT 救援，不启动捣乱。
	if who == "rabbit" and (GameManager.accident_state in ["RABBIT_WATER", "RABBIT_AIR"] 			or rabbit.state in ["FALLING_WATER", "PASSED_OUT"]):
		return
	# PHASE-1：去掉 32% 随机抑制。情绪窗口 + 失控 + 安全区就是确定性触发；
	# 玩家看到预兆后仍可用 SHIFT 当帧取消。
	GameManager.complaint_role = ""
	GameManager.complaint_t = 0.0
	GameManager.mischief_lock_role = who
	_mischief_role = who
	_mischief_phase = "TELEGRAPH"
	_mischief_t = 0.0
	_mischief_action_done = false
	_mischief_fx_kind = ""
	_mischief_fx_t = 0.0
	GameManager.center_message.emit(Locale.t(
		"mischief.telegraph_turtle" if who == "turtle" else "mischief.telegraph_rabbit"),
		Color(1.0, 0.55, 0.25))
	GameManager.feedback.emit(Locale.t(
		"mischief.start_turtle" if who == "turtle" else "mischief.start_rabbit"), "hit")
	mischief_log.append({"event": "start", "who": who, "t": accident_event_time})


## 预兆阶段只读当前状态，不提前消耗随机/动作；用于把“拽绳/电击”写在脸上。
func _mischief_predicted_kind() -> String:
	if _mischief_role == "turtle":
		return "zap_landing" if rabbit.state in ["JUMPING", "FALLING"] else "shock"
	if _mischief_role == "rabbit":
		if turtle.diving or turtle.leap_active:
			return "rabbit_shock"
		return "rabbit_shock" if int(_mischief_action_seq.get("rabbit", 0)) % 2 == 0 else "tug"
	return ""


func _apply_mischief_action() -> void:
	_bump_visual_stress(_mischief_role, 0.8)
	var seq := int(_mischief_action_seq.get(_mischief_role, 0))
	_mischief_action_seq[_mischief_role] = seq + 1
	if _mischief_role == "turtle":
		# BITT 使坏：兔子在空中时把它打下来；否则电一下。
		if rabbit.state in ["JUMPING", "FALLING"]:
			_mischief_fx_kind = "zap_landing"
			_mischief_fx_t = 0.65
			rabbit.velocity.y = maxf(rabbit.velocity.y, 220.0)
			rabbit.velocity.x += 18.0
			GameManager.feedback.emit(Locale.t("mischief.zap_landing"), "hit")
		else:
			_mischief_fx_kind = "shock"
			_mischief_fx_t = 0.65
			# 真实后果：失衡更深、前冲更明显，不只是“头顶冒电”。
			rabbit.add_imbalance(0.18)
			rabbit.velocity.x += 32.0
			GameManager.feedback.emit(Locale.t("mischief.hit_rabbit"), "hit")
	else:
		# TUBO 使坏动作池：乌龟正在潜/跃时电它并打断动作；乌龟巡航时
		# 第一次也电击（让玩家真的看到“电对方”），之后在电击/拽绳之间交替。
		var do_shock: bool = turtle.diving or turtle.leap_active or seq % 2 == 0
		if do_shock:
			_mischief_fx_kind = "rabbit_shock"
			_mischief_fx_t = 0.65
			# PHASE-1：电击必须真的打断下潜/跃起，不能只加一点失衡。
			turtle.zap_stun_t = 0.35
			turtle.leap_active = false
			turtle.leap_timer = 0.0
			if turtle.position.y < Tuning.NEUTRAL_DEPTH:
				turtle.position.y = Tuning.NEUTRAL_DEPTH
			else:
				turtle.position.y = maxf(turtle.position.y - 22.0, SURFACE_Y)
			turtle.speed *= 0.80
			turtle.add_imbalance(0.16)
			turtle.start_flip()
			GameManager.feedback.emit(Locale.t("mischief.rabbit_shock"), "hit")
		else:
			_mischief_fx_kind = "tug"
			_mischief_fx_t = 0.65
			# PHASE-1：拽绳从“翻一下”改成真实的壳下沉 + 减速。
			turtle.tug_t = 0.65
			turtle.speed *= 0.85
			turtle.add_imbalance(0.10)
			turtle.start_flip()
			GameManager.feedback.emit(Locale.t("mischief.hit_turtle"), "hit")
	mischief_log.append({"event": "action", "who": _mischief_role,
		"kind": _mischief_fx_kind, "t": accident_event_time})


func _end_mischief(reason: String) -> void:
	if _mischief_role == "":
		return
	var old := _mischief_role
	GameManager.mischief_lock_role = ""
	_ignore_t[old] = 8.0
	_mischief_role = ""
	_mischief_phase = ""
	_mischief_t = 0.0
	_mischief_action_done = false
	_mischief_fx_kind = ""
	if reason == "shifted":
		# 换人中断后不要继续挂着“要捣乱了”的大字，避免看起来像仍在失控。
		# 救援/其他高优先级中断不清，保留救援提示。
		GameManager.center_message.emit("", Color(1, 1, 1))
	# SHIFT 中断必须允许“新未受控角色”当帧接管，不能被旧事件的冷却挡住。
	_mischief_cd = 0.0 if reason == "shifted" else MISCHIEF_CD
	mischief_log.append({"event": "end", "who": old, "reason": reason,
		"t": accident_event_time})
	if reason == "completed":
		GameManager.feedback.emit(Locale.t("mischief.end"), "clean")



func _draw_bird_target_warning(group: Dictionary, st: Dictionary) -> void:
	var rect: Rect2 = group["rects"][0]
	var bp: Vector2 = _bird_target_pos(st)
	var bc: Vector2 = Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - 16.0)
	draw_line(bc, bp + Vector2(0, -18), Color(1.0, 0.55, 0.25, 0.65), 2.0)
	draw_arc(bp + Vector2(0, -18), 22.0 + sin(Time.get_ticks_msec() * 0.01) * 3.0,
		0.0, TAU, 20, Color(1.0, 0.45, 0.25, 0.8), 3.0)
	draw_string(ThemeDB.fallback_font, bp + Vector2(-6, -96), "!",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.55, 0.25, 0.95))


func _tick_ignore(delta: float) -> void:
	if test_no_mischief:
		return
	if GameManager.accident_state != "NONE" or showtime_active:
		return
	for who in ["rabbit", "turtle"]:
		if who == GameManager.current_control:
			_ignore_t[who] = 0.0
		else:
			_ignore_t[who] = minf(float(_ignore_t[who]) + delta * 1.10, 20.0)
	# 12 s 还没被管：把可见抱怨交给 MISCHIEF 入口；之前只有表情/符号。
	if GameManager.complaint_role == "":
		for who in ["rabbit", "turtle"]:
			if who != GameManager.current_control and float(_ignore_t[who]) >= 12.0:
				GameManager.complaint_role = who
				GameManager.complaint_t = 2.6
				break


func _draw_ignore_mood(pos: Vector2, who: String) -> void:
	if who == GameManager.current_control:
		return
	var t: float = float(_ignore_t.get(who, 0.0))
	if t < 4.0:
		return
	var mark := "?" if t < 8.0 else ("!" if t < 12.0 else "!!")
	var col := Color(1.0, 0.82, 0.35, 0.95)
	if t >= 12.0:
		col = Color(1.0, 0.45, 0.30, 0.95)
	var bob := sin(Time.get_ticks_msec() * 0.006) * 2.0
	draw_circle(pos + Vector2(34, -92 + bob), 14.0, Color(0.05, 0.08, 0.10, 0.6))
	draw_string(ThemeDB.fallback_font, pos + Vector2(26, -85 + bob), mark,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)


func _draw_complaint() -> void:
	if GameManager.complaint_role == "" or _mischief_role != "":
		return
	if GameManager.complaint_role == GameManager.current_control:
		return
	var p: Vector2 = turtle.position if GameManager.complaint_role == "turtle" else rabbit.position
	var bob := sin(Time.get_ticks_msec() * 0.008) * 2.0
	draw_circle(p + Vector2(28, -86 + bob), 13.0, Color(0.05, 0.08, 0.10, 0.65))
	draw_string(ThemeDB.fallback_font, p + Vector2(22, -79 + bob), "…",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.82, 0.35, 0.95))


func _draw_mischief() -> void:
	if _mischief_role == "":
		return
	var active: bool = _mischief_phase == "TELEGRAPH" or _mischief_phase == "ACTION"
	if not active:
		return
	var culprit: Vector2 = turtle.position if _mischief_role == "turtle" else rabbit.position
	var other: Vector2 = rabbit.position if _mischief_role == "turtle" else turtle.position
	if _mischief_phase == "TELEGRAPH":
		# 预兆：先把“谁在使坏”画清楚，不等 ACTION 的 0.65 s。
		for i in 3:
			var a := culprit + Vector2(cos(float(i) * 2.1) * 28.0,
				-34.0 + sin(float(i) * 1.7) * 18.0)
			var b := other.lerp(culprit, 0.35 + 0.15 * float(i))
			draw_line(a, b, Color(1.0, 0.72, 0.2, 0.35), 2.0)
		draw_string(ThemeDB.fallback_font, culprit + Vector2(-8, -90), "!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.55, 0.15, 0.95))
		var tag := Locale.t("mischief.tag_tug" if _mischief_predicted_kind() == "tug"
			else "mischief.tag_zap")
		draw_string(ThemeDB.fallback_font, culprit + Vector2(-18, -112), tag,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.82, 0.35, 0.95))
		return
	if _mischief_fx_t <= 0.0:
		return
	var k := clampf(_mischief_fx_t / 0.65, 0.0, 1.0)
	match _mischief_fx_kind:
		"tug":
			var a: Vector2 = turtle.position + Vector2(0, -18)
			var b: Vector2 = rabbit.position + Vector2(0, -30)
			draw_line(a, b, Color(0.35, 0.22, 0.12, 0.9 * k), 4.0)
			draw_line(b, b + Vector2(0, 20), Color(0.35, 0.22, 0.12, 0.9 * k), 4.0)
			draw_circle(b, 10.0 * k, Color(0.85, 0.4, 0.2, 0.3 * k))
		_:
			# 三种电击：turtle→rabbit、rabbit→turtle、空中兔子被电下来。
			var z_from: Vector2 = culprit + Vector2(18, -18)
			var z_to: Vector2 = other + Vector2(0, -12)
			if _mischief_fx_kind == "rabbit_shock":
				z_from = rabbit.position + Vector2(-18, -18)
				z_to = turtle.position + Vector2(0, -12)
			_draw_zap(z_from, z_to,
				Color(1.0, 0.93, 0.30, 0.95 * k), 4.0, 9.0)
			draw_circle(z_from, 18.0 * k, Color(1.0, 0.9, 0.25, 0.18 * k))
			draw_circle(z_to, 26.0 * k, Color(1.0, 0.85, 0.2, 0.22 * k))
			# 谁被电，头顶显示“！”，不依赖颜色分辨。
			draw_string(ThemeDB.fallback_font, z_to + Vector2(-7, -48), "!",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.9, 0.35, 0.95))
			if _mischief_fx_kind == "zap_landing":
				draw_line(z_to, z_to + Vector2(0, 38.0 * k),
					Color(1.0, 0.75, 0.25, 0.9 * k), 3.0)
				draw_line(z_to + Vector2(0, 38.0 * k), z_to + Vector2(-8, 28.0 * k),
					Color(1.0, 0.75, 0.25, 0.9 * k), 3.0)
				draw_line(z_to + Vector2(0, 38.0 * k), z_to + Vector2(8, 28.0 * k),
					Color(1.0, 0.75, 0.25, 0.9 * k), 3.0)


## 电击折线：两端固定、中间抖动，灰盒里也看得出“电到了谁”。
func _draw_zap(a: Vector2, b: Vector2, col: Color, width: float, amp: float) -> void:
	var pts := PackedVector2Array()
	var perp := (b - a).orthogonal().normalized()
	var seg := 8
	for i in seg + 1:
		var f := float(i) / float(seg)
		var wig := sin(f * 17.0 + Time.get_ticks_msec() * 0.035) * amp * sin(PI * f)
		pts.append(a.lerp(b, f) + perp * wig)
	draw_polyline(pts, col, width, true)


func _drift_rank(state: String) -> int:
	match state:
		"DISTRACTED":
			return 1
		"RESTLESS":
			return 2
		"MISCHIEF":
			return 3
	return 0


## 与 HUD 同一组数字（都读控制器当前值），用于阈值报警的那一句话。
func _drift_effect_text(who: String) -> String:
	if who == "rabbit":
		return Locale.t("hud.drift_effect_rabbit", [
			int(round(rabbit.drift_air_scale() * 100.0)),
			int(round(rabbit.drift_offset_amp_px()))])
	return Locale.t("hud.drift_effect_turtle", [
		int(round(turtle.drift_speed_scale(false) * 100.0)),
		int(round(turtle.drift_bob_amp_px(false)))])


## SHIFT 表现回调：由 ui/shift_fx.gd 在收到 shift_shocked 的同一帧调用。
## 只写表现计时器；不读输入、不改控制权、不加冷却。
func on_shift_fx(to_who: String) -> void:
	_shift_jolt_t = SHIFT_JOLT_TIME
	_shift_jolt_who = to_who
	_camera_pulse_t = CAMERA_PULSE_TIME


## 新角色被“电一下”的轻微受激位移：3 px 竖跳 + 横向颤动，画在身体上，
## 不进物理位置，所以不会改变碰撞、落点或判定。
func _shift_jolt_offset(who: String) -> Vector2:
	if _shift_jolt_t <= 0.0 or _shift_jolt_who != who:
		return Vector2.ZERO
	var k := _shift_jolt_t / SHIFT_JOLT_TIME
	return Vector2(sin(_shift_jolt_t * 95.0) * 2.5 * k, -3.0 * k)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("up"):
		# 只记录，不消费：GameManager 仍需要收到 SHIFT，动作由当前角色在物理帧里取。
		_note_up_input()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F3:
			debug_mode = not debug_mode
			show_hitboxes = debug_mode
			if _debug_overlay != null:
				_debug_overlay.visible = debug_mode
			queue_redraw()
		elif event.physical_keycode == KEY_F1 and _debug_overlay != null:
			_debug_overlay.visible = not _debug_overlay.visible
		elif event.physical_keycode == KEY_H:
			show_hitboxes = not show_hitboxes
			queue_redraw()


func _draw() -> void:
	# PHASE-2：终点后至少留一屏沙滩，不能再让镜头滑进默认黑色清屏。
	var finish_extra := FINISH_BEACH_EXTRA
	var world_width := world_end + finish_extra
	var cam_x: float = camera.position.x if camera != null else turtle.position.x
	# 三个区域各画一段背景；区域边界和名字直接画在世界里。
	# CORE-FEEL-08 P1-D：第二区域改成室内木质码头，背景由 Zone2Dock 的六层节点负责
	# （z_index 都在本节点之下）。这里如果继续铺平色块，会把那些层整个盖住。
	for zone in LevelDataScript.ZONES:
		var x0: float = zone["start"] - 400.0
		var w: float = zone["end"] - zone["start"] + 400.0
		if int(zone["id"]) == 3:
			w += finish_extra
		# P0-D：Z1 的平色背景提前 400 px 让位给渐变带；否则它在 15000 的
		# 硬边会从渐变带底下露出来，接缝只是变淡而没有消失。
		if int(zone["id"]) == 1:
			w -= 400.0
		if int(zone["id"]) != 2:
			draw_rect(Rect2(x0, -200, w, 500), zone["sky"])
			draw_rect(Rect2(x0, SURFACE_Y, w, 700), zone["water"])
			draw_rect(Rect2(x0, 460, w, 440), zone["deep"])
			draw_rect(Rect2(x0, 820, w, 120), zone["seabed"])
			draw_line(Vector2(x0, SURFACE_Y), Vector2(x0 + w, SURFACE_Y),
				Color(0.7, 0.95, 1.0), 4.0)
		if zone["id"] > 1:
			draw_line(Vector2(zone["start"], -200), Vector2(zone["start"], 940),
				Color(1, 1, 1, 0.25), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(zone["start"] + 40, 80),
			Locale.t("world.zone_header", [zone["id"], Locale.zone_name(zone["id"])]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, zone["grade_color"])

	# FEEL-10 P0-D：Z1 平色背景在 15000 硬切，Z2 的六层从 15000 开始画，
	# 两段之间会留下一条竖直的“图层跳变”。这里用 800 px 的 Z1→透明渐变带
	# 把接缝化开：14600 还是完整 Z1，15400 完全交给码头，第一组障碍 15800 之前完成。
	_draw_zone2_blend()
	_draw_zone1_layers(cam_x)
	_draw_zone3_layers(cam_x)
	# PHASE-ART：只铺一次码头图，叠在原有海岸背景上；700–1400 px 淡出回海岸。
	if USE_Z1_ART:
		_draw_z1_water_base(cam_x)
		_draw_z1_reflection(cam_x)
		_draw_z1_art(cam_x)
		_draw_z1_water_fx(cam_x)
	if not test_no_finish:
		_draw_finish_beach()
	# 危险深度线只在 F3 调试层出现；正常界面没有红线。
	if debug_mode:
		draw_line(Vector2(-400, 740), Vector2(world_width, 740),
			Color(1.0, 0.3, 0.25, 0.5), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(turtle.position.x - 200, 726),
			Locale.t("world.danger_depth"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(1.0, 0.5, 0.45, 0.7))

	_draw_snacks()
	_draw_z3_warning()

	for g in hazard_groups:
		var group: Dictionary = g
		if _shark_arena_hides(group):
			continue
		for i in group["rects"].size():
			_draw_hazard(group, i)
		if not group.get("motion", {}).is_empty():
			_draw_motion_cue(group)
		if debug_mode and absf(LevelDataScript.group_start(group) - cam_x) <= 1700.0:
			_draw_debug_group(group)

	_draw_action_fx()
	_draw_relay_fx()
	_draw_overdrive_fx()
	_draw_turtle()
	# 吞食反馈画在乌龟之后：食物被“吸进嘴里”，不是糊在壳后面。
	if snack_gulp_t > 0.0:
		_draw_gulp_fx()
	_draw_rabbit()
	_draw_bird_attacks()
	_draw_shark_pack_fx()
	_draw_oxygen_bubbles()
	_draw_guard_and_catch()
	_draw_complaint()
	_draw_mischief()
	# P4：跳跃强化的箭头必须在兔子之后画，否则被兔子身体盖住。
	if snack_rabbit_boost_active():
		_draw_rabbit_boost_fx()
	_draw_land_splash()
	_draw_control_ring()
	if show_hitboxes or debug_mode:
		_draw_hitboxes()

	if accident_flash > 0.0:
		var a: float = 0.55 * (accident_flash / Tuning.ACCIDENT_FLASH)
		draw_rect(Rect2(cam_x - 1400.0, -400.0, 2800.0, 1600.0), Color(1, 1, 1, a))


## PHASE-3：Z1/Z3 的灰盒纵深。只画远景/中景/前景，不参与判定。
## 屏幕空间按 cam*parallax 平移，再取模重复；这样无论镜头走到哪里，
## 层都保持在可视区里，不会因为 base 固定在世界开头而飘走。
func _layer_screen_positions(cam_x: float, parallax: float, period: float,
		count: int, phase: float = 0.0) -> Array:
	var out := []
	var width: float = get_viewport_rect().size.x
	var total := period * maxf(float(count), 1.0)
	var shift := fmod(cam_x * parallax + phase, total)
	for i in count:
		var sx := fmod(float(i) * period - shift + total, total)
		# 取模后可能出现在屏幕右侧；只画屏内及少量预卷。
		if sx > -160.0 and sx < width + 160.0:
			out.append(cam_x + sx)
	return out


func _z1_art_alpha(cam_x: float) -> float:
	if not USE_Z1_ART:
		return 0.0
	if cam_x <= 700.0:
		return 1.0
	if cam_x >= 1400.0:
		return 0.0
	return clampf((1400.0 - cam_x) / 700.0, 0.0, 1.0)


func _draw_z1_water_base(cam_x: float) -> void:
	var alpha := _z1_art_alpha(cam_x)
	if alpha <= 0.0:
		return
	var vw: float = get_viewport_rect().size.x
	var l := maxf(Z1_ART_LEFT, cam_x - vw * 0.5)
	var r := minf(Z1_ART_RIGHT, cam_x + vw * 0.5)
	if r <= l:
		return
	for i in 12:
		var k := float(i) / 11.0
		var c := Color(0.24, 0.58, 0.69).lerp(Color(0.035, 0.12, 0.22), k)
		c.a = alpha
		draw_rect(Rect2(l, SURFACE_Y + k * 600.0, r - l, 56.0), c)
	draw_rect(Rect2(l, SURFACE_Y, r - l, 22.0),
		Color(0.36, 0.73, 0.80, 0.85 * alpha))


func _draw_z1_reflection(cam_x: float) -> void:
	var alpha := _z1_art_alpha(cam_x)
	if alpha <= 0.0:
		return
	var vw: float = get_viewport_rect().size.x
	var l := maxf(Z1_ART_LEFT, cam_x - vw * 0.5)
	var r := minf(Z1_ART_RIGHT, cam_x + vw * 0.5)
	if r <= l:
		return
	var src_x := l - Z1_ART_LEFT
	draw_texture_rect_region(Z1_DOCK_REFLECT,
		Rect2(l, SURFACE_Y, r - l, 130.0),
		Rect2(src_x, 0.0, r - l, 130.0),
		Color(0.82, 0.95, 1.0, 0.20 * alpha))


func _draw_z1_art(cam_x: float) -> void:
	var alpha := _z1_art_alpha(cam_x)
	if alpha <= 0.0:
		return
	var vw: float = get_viewport_rect().size.x
	var l := maxf(Z1_ART_LEFT, cam_x - vw * 0.5)
	var r := minf(Z1_ART_RIGHT, cam_x + vw * 0.5)
	if r <= l:
		return
	var src_x := l - Z1_ART_LEFT
	draw_texture_rect_region(Z1_DOCK_TEX,
		Rect2(l, Z1_ART_Y, r - l, Z1_ART_H),
		Rect2(src_x, 0.0, r - l, Z1_ART_H),
		Color(1, 1, 1, alpha))


func _draw_z1_water_fx(cam_x: float) -> void:
	var alpha := _z1_art_alpha(cam_x)
	if alpha <= 0.0:
		return
	var vw: float = get_viewport_rect().size.x
	var l := maxf(Z1_ART_LEFT, cam_x - vw * 0.5)
	var r := minf(Z1_ART_RIGHT, cam_x + vw * 0.5)
	if r <= l:
		return
	var t := Time.get_ticks_msec() * 0.001
	var width := r - l
	for layer in 2:
		var pts := PackedVector2Array()
		for i in 34:
			var x := l - 10.0 + float(i) * (width + 20.0) / 33.0
			var y := SURFACE_Y - 2.0 - layer * 5.0 				+ sin(x * 0.035 + t * (2.2 + layer) + layer * 1.7) * 3.5
			pts.append(Vector2(x, y))
		draw_polyline(pts, Color(0.88, 0.98, 1.0, (0.95 - layer * 0.35) * alpha),
			3.2 - layer, true)
	for j in 4:
		var cy := SURFACE_Y + 90.0 + j * 105.0
		var ca := PackedVector2Array()
		for i in 28:
			var x := l - 10.0 + float(i) * (width + 20.0) / 27.0
			var y := cy + sin(x * 0.022 + t * (1.1 + j * 0.27)) * 9.0
			ca.append(Vector2(x, y))
		draw_polyline(ca, Color(0.58, 0.90, 1.0, 0.13 * alpha), 2.2, true)
	for j in 3:
		var sx := l + fmod(float(j) * 430.0 + t * 10.0, maxf(width, 1.0))
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx, SURFACE_Y), Vector2(sx + 70.0, SURFACE_Y),
			Vector2(sx + 150.0, 760.0), Vector2(sx + 40.0, 760.0),
		]), Color(0.55, 0.88, 1.0, 0.045 * alpha))
	for i in 18:
		var bx := l + fmod(float(i) * 173.0 + t * 9.0, maxf(width, 1.0))
		var by := 850.0 - fmod(float(i) * 57.0 + t * (26.0 + i), 520.0)
		draw_circle(Vector2(bx, by), 1.8 + float(i % 3),
			Color(0.78, 0.95, 1.0, 0.26 * alpha))
	for i in 10:
		var sx := l + fmod(float(i) * 227.0 + t * 14.0, maxf(width, 1.0))
		draw_line(Vector2(sx, SURFACE_Y + 3.0),
			Vector2(sx + 20.0, SURFACE_Y + 3.0),
			Color(0.95, 1.0, 1.0, 0.38 * alpha), 2.0)


func _zone_layer_fade(cam_x: float, z: Dictionary) -> float:
	# PHASE-5：区域边界不再硬裁剪；前后各 600 px 把整层 alpha 淡到 0。
	var start := float(z["start"])
	var end := float(z["end"])
	var m := 600.0
	return clampf(minf((cam_x - (start - m)) / m, ((end + m) - cam_x) / m), 0.0, 1.0)


func _draw_zone1_layers(cam_x: float) -> void:
	var z: Dictionary = LevelDataScript.ZONES[0]
	var fade := _zone_layer_fade(cam_x, z)
	if fade <= 0.01:
		return
	# 远景云：p=0.18。
	var clouds := _layer_screen_positions(cam_x, 0.18, 820.0, 4, 0.0)
	for idx in clouds.size():
		var sx: float = clouds[idx]
		var cy := 72.0 + float(idx % 3) * 34.0
		draw_circle(Vector2(sx, cy), 28.0, Color(1, 1, 1, 0.11 * fade))
		draw_circle(Vector2(sx + 34, cy + 4), 22.0, Color(1, 1, 1, 0.09 * fade))
		draw_circle(Vector2(sx - 30, cy + 7), 18.0, Color(1, 1, 1, 0.08 * fade))
	# 远景岛：p=0.32。
	var islands := _layer_screen_positions(cam_x, 0.32, 1500.0, 4, 260.0)
	for idx in islands.size():
		var sx: float = islands[idx]
		var w := 110.0 + float(idx % 3) * 42.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx - w, SURFACE_Y), Vector2(sx - w * 0.6, SURFACE_Y - 34.0),
			Vector2(sx - w * 0.1, SURFACE_Y - 18.0), Vector2(sx + w * 0.5, SURFACE_Y - 42.0),
			Vector2(sx + w, SURFACE_Y),
		]), Color(0.24, 0.38, 0.42, 0.62 * fade))
	# 中景棕榈/木桩：p=0.62。
	var palms := _layer_screen_positions(cam_x, 0.62, 980.0, 4, 120.0)
	for idx in palms.size():
		var sx: float = palms[idx]
		var trunk := Color(0.22, 0.30, 0.23, 0.85 * fade)
		draw_line(Vector2(sx, SURFACE_Y + 14.0), Vector2(sx + 10.0, SURFACE_Y - 52.0), trunk, 5.0)
		for j in 3:
			var a := -PI * 0.5 + (float(j) - 1.0) * 0.85
			draw_line(Vector2(sx + 10.0, SURFACE_Y - 52.0),
				Vector2(sx + 10.0, SURFACE_Y - 52.0) + Vector2(cos(a), sin(a)) * 34.0,
				Color(0.20, 0.42, 0.28, 0.82 * fade), 4.0)
	# 近景浪：p=1.12。
	var waves := _layer_screen_positions(cam_x, 1.12, 360.0, 6, 0.0)
	for idx in waves.size():
		var sx: float = waves[idx]
		var wy := 664.0 + float(idx % 4) * 42.0
		draw_arc(Vector2(sx, wy), 26.0 + float(idx % 3) * 8.0,
			0.12, PI - 0.12, 10, Color(0.78, 0.96, 1.0, 0.18 * fade), 2.0)


func _draw_zone3_layers(cam_x: float) -> void:
	var z: Dictionary = LevelDataScript.ZONES[2]
	var fade := _zone_layer_fade(cam_x, z)
	if fade <= 0.01:
		return
	# 远景礁柱：p=0.25。
	var spires := _layer_screen_positions(cam_x, 0.25, 1450.0, 4, 180.0)
	for idx in spires.size():
		var sx: float = spires[idx]
		var h := 54.0 + float(idx % 4) * 32.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx - 52, SURFACE_Y), Vector2(sx - 22, SURFACE_Y - h),
			Vector2(sx + 12, SURFACE_Y - h - 26.0), Vector2(sx + 38, SURFACE_Y - h * 0.5),
			Vector2(sx + 58, SURFACE_Y),
		]), Color(0.34, 0.18, 0.11, 0.66 * fade))
	# 中景吊架/沉船骨架：p=0.55。
	var rigs := _layer_screen_positions(cam_x, 0.55, 1900.0, 3, 500.0)
	for idx in rigs.size():
		var sx: float = rigs[idx]
		var col := Color(0.22, 0.14, 0.10, 0.86 * fade)
		draw_line(Vector2(sx, SURFACE_Y + 40.0), Vector2(sx, SURFACE_Y - 90.0), col, 6.0)
		draw_line(Vector2(sx - 44.0, SURFACE_Y - 64.0), Vector2(sx + 44.0, SURFACE_Y - 64.0), col, 5.0)
		draw_line(Vector2(sx - 30.0, SURFACE_Y - 64.0), Vector2(sx - 30.0, SURFACE_Y - 24.0), col, 3.0)
		draw_circle(Vector2(sx, SURFACE_Y - 96.0), 7.0, Color(0.62, 0.28, 0.16, 0.9 * fade))
	# 近景浪：p=1.15。
	var waves := _layer_screen_positions(cam_x, 1.15, 430.0, 5, 0.0)
	for idx in waves.size():
		var sx: float = waves[idx]
		var wy := 628.0 + float(idx % 4) * 48.0
		draw_arc(Vector2(sx, wy), 30.0 + float(idx % 3) * 10.0,
			0.10, PI - 0.10, 12, Color(1.0, 0.74, 0.42, 0.18 * fade), 2.0)


## FEEL-10 P0-D：Z1→Z2 的横向渐变带。只画颜色，不改任何坐标或遮挡关系。
## 右端 alpha 归零，码头六层从下面透出来；入口因此是“化开”而不是“切一刀”。
func _draw_zone2_blend() -> void:
	var z1: Dictionary = LevelDataScript.ZONES[0]
	# PHASE-5 压缩后 Z1 平色在 9600 结束、Z2 从 10000 开始。
	var x0 := 9600.0
	var x1 := 10200.0
	var bands := [
		[-200.0, 300.0, z1["sky"]],
		[300.0, 460.0, z1["water"]],
		[460.0, 820.0, z1["deep"]],
		[820.0, 940.0, z1["seabed"]],
	]
	# 一张 256×1 的 alpha 渐变纹理横拉，避免竖条边缘被看成百叶窗。
	if _zone2_fade_tex == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		_zone2_fade_tex = GradientTexture2D.new()
		_zone2_fade_tex.gradient = grad
		_zone2_fade_tex.width = 256
		_zone2_fade_tex.height = 1
		_zone2_fade_tex.fill_from = Vector2(0, 0)
		_zone2_fade_tex.fill_to = Vector2(1, 0)
	for b in bands:
		var y0: float = b[0]
		var y1: float = b[1]
		var c: Color = b[2]
		draw_texture_rect(_zone2_fade_tex, Rect2(x0, y0, x1 - x0, y1 - y0),
			false, c)


## PHASE-2：终点不是黑屏。沙滩从水平线一直铺到屏幕底部，大表哥站在
## 终点门后等他们冲线；全部用灰盒几何，后续只换美术。
func _draw_finish_beach() -> void:
	var x0 := world_end
	var x1 := world_end + FINISH_BEACH_EXTRA
	var sand := Color(0.82, 0.69, 0.45)
	var sand_dark := Color(0.70, 0.56, 0.35)
	var wet := Color(0.62, 0.60, 0.44)
	# 沙地 + 湿沙 + 浪线
	draw_rect(Rect2(x0, SURFACE_Y, x1 - x0, 640.0), sand)
	draw_rect(Rect2(x0, SURFACE_Y, 190.0, 76.0), wet)
	draw_rect(Rect2(x0, SURFACE_Y + 76.0, x1 - x0, 6.0), sand_dark)
	for i in 7:
		var fx := x0 + 18.0 + i * 26.0
		draw_arc(Vector2(fx, SURFACE_Y + 4.0), 12.0 + i * 2.0,
			0.15, PI - 0.30, 10, Color(0.9, 0.98, 1.0, 0.55 - i * 0.05), 2.0)
	# 沙滩上的浅色纹理，避免一整块纯色
	for i in 14:
		var sx := x0 + 240.0 + i * 138.0
		var sy := SURFACE_Y + 42.0 + (i % 4) * 38.0
		draw_line(Vector2(sx, sy), Vector2(sx + 52.0, sy + 8.0),
			Color(0.92, 0.82, 0.58, 0.35), 2.0)
	# 终点门：两根木桩 + 横幅
	var post_col := Color(0.34, 0.25, 0.16)
	draw_rect(Rect2(x0 + 18.0, 116.0, 12.0, 184.0), post_col)
	draw_rect(Rect2(x0 + 356.0, 116.0, 12.0, 184.0), post_col)
	draw_rect(Rect2(x0 + 18.0, 116.0, 350.0, 54.0), Color(0.96, 0.82, 0.32))
	draw_rect(Rect2(x0 + 18.0, 116.0, 350.0, 54.0),
		Color(0.32, 0.23, 0.12), false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(x0 + 96.0, 154.0),
		Locale.t("world.finish"), HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
		Color(0.24, 0.16, 0.08))
	# 沙滩遮阳伞
	var ux := x0 + 760.0
	draw_line(Vector2(ux, 270.0), Vector2(ux, 330.0), Color(0.35, 0.25, 0.16), 6.0)
	var canopy := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		canopy.append(Vector2(ux + cos(a) * 74.0, 272.0 + sin(a) * 46.0))
	draw_colored_polygon(canopy, Color(0.94, 0.38, 0.30))
	draw_line(Vector2(ux - 74, 272), Vector2(ux + 74, 272),
		Color(0.72, 0.25, 0.20), 3.0)
	# 远处的沙丘剪影，压住“背景突然结束”的直线
	draw_colored_polygon(PackedVector2Array([
		Vector2(x0 + 980.0, SURFACE_Y), Vector2(x0 + 1160.0, SURFACE_Y - 34.0),
		Vector2(x0 + 1360.0, SURFACE_Y - 12.0), Vector2(x0 + 1520.0, SURFACE_Y),
	]), Color(0.72, 0.60, 0.40))
	# 大表哥：开场漫画同一轮廓。冲线时举手。
	var cousin_p := Vector2(x0 + 470.0, 174.0)
	draw_set_transform(cousin_p + Vector2(0, 126), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 48.0, Color(0.22, 0.18, 0.12, 0.30))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_cousin(cousin_p, 1.05, finishing)
	# 大表哥的提示/欢呼
	var cue := Locale.t("world.finish_cousin" if not finishing else "world.finish_cheer")
	# 气泡放在头顶、向左展开；镜头刚带到终点时也不会被右边缘切掉。
	var bubble := Rect2(cousin_p + Vector2(-128, -170), Vector2(250, 34))
	draw_rect(bubble, Color(0.05, 0.08, 0.10, 0.78))
	draw_string(ThemeDB.fallback_font, bubble.position + Vector2(10, 23), cue,
		HORIZONTAL_ALIGNMENT_LEFT, 230, 17, Color(1.0, 0.88, 0.48))
	# 沙滩旗
	for i in 3:
		var fx2 := x0 + 1040.0 + i * 240.0
		draw_line(Vector2(fx2, 300.0), Vector2(fx2, 214.0), post_col, 5.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(fx2 + 4, 218), Vector2(fx2 + 74, 238), Vector2(fx2 + 4, 258),
		]), Color(0.94, 0.42, 0.32) if i % 2 == 0 else Color(0.30, 0.70, 0.78))


## 与 opening_comic 的大表哥同一套灰盒轮廓；cheer=true 时抬手。
func _draw_cousin(p: Vector2, s: float, cheer: bool) -> void:
	var skin := Color(0.95, 0.72, 0.52)
	var shirt := Color(1.0, 0.38, 0.3)
	var line := Color(0.12, 0.08, 0.06)
	draw_circle(p + Vector2(0, 40) * s, 58 * s, shirt)
	draw_rect(Rect2(p + Vector2(-42, 48) * s, Vector2(84, 70) * s), shirt)
	draw_circle(p + Vector2(0, -30) * s, 38 * s, skin)
	draw_arc(p + Vector2(0, -36) * s, 26 * s, PI, TAU, 16, line, 4 * s)
	draw_line(p + Vector2(-28, -30) * s, p + Vector2(-8, -30) * s, line, 5 * s)
	draw_line(p + Vector2(8, -30) * s, p + Vector2(28, -30) * s, line, 5 * s)
	if cheer:
		draw_line(p + Vector2(-48, 20) * s, p + Vector2(-84, -42) * s, skin, 24 * s)
		draw_line(p + Vector2(48, 20) * s, p + Vector2(84, -42) * s, skin, 24 * s)
		draw_circle(p + Vector2(-88, -46) * s, 14 * s, skin)
		draw_circle(p + Vector2(88, -46) * s, 14 * s, skin)
	else:
		draw_line(p + Vector2(-48, 20) * s, p + Vector2(-78, -18) * s, skin, 24 * s)
		draw_line(p + Vector2(48, 20) * s, p + Vector2(78, -18) * s, skin, 24 * s)
		draw_circle(p + Vector2(-80, -20) * s, 14 * s, skin)
		draw_circle(p + Vector2(80, -20) * s, 14 * s, skin)
	draw_line(p + Vector2(0, -6) * s, p + Vector2(0, 14) * s, line, 3 * s)
	draw_circle(p + Vector2(0, 16) * s, 6 * s, Color(0.85, 0.85, 0.8))


## 主动垂直动作的灰盒演出：跃起是壳下破水 + 上抛水花；下潜是壳边气泡下压。
## 全部用原生绘制，不引入素材；动作必须“看得出来是主动做的”，不像事故。
func _draw_action_fx() -> void:
	if turtle.leap_active:
		var surf := Tuning.NEUTRAL_DEPTH
		var rise: float = surf - turtle.position.y
		var base := Vector2(turtle.position.x, surf + 10.0)
		# 破水圈：起跳时大、空中收小，读作“从水里弹出来”。
		var spread := 96.0 - 34.0 * clampf(rise / Tuning.LEAP_HEIGHT, 0.0, 1.0)
		for i in 3:
			var rr := spread - i * 16.0
			if rr <= 4.0:
				continue
			draw_arc(base, rr, PI * 0.05, PI * 0.95, 28,
				Color(0.8, 0.97, 1.0, 0.5 - i * 0.12), 5.0)
		for i in 5:
			var ang := PI * (0.2 + 0.6 * float(i) / 4.0)
			draw_circle(base + Vector2(cos(ang), -sin(ang)) * (spread + 10.0),
				5.0, Color(0.9, 1.0, 1.0, 0.5))
		# 向上冲的速度线，明确“整组被带高”。
		for i in 3:
			var y: float = turtle.position.y + 26.0 + i * 18.0
			draw_line(Vector2(turtle.position.x - 40.0, y),
				Vector2(turtle.position.x - 40.0, y + 26.0),
				Color(0.75, 1.0, 1.0, 0.45), 4.0)
	if turtle.diving:
		# 下潜：壳下两串气泡往上冒，方向和水流相反，读作“往下按”。
		for i in 6:
			var t := fmod(_accident_t * 0.9 + i * 0.17, 1.0)
			draw_circle(turtle.position + Vector2(-26.0 + i * 11.0, -30.0 - t * 60.0),
				4.0 - i * 0.35, Color(0.8, 0.95, 1.0, 0.45 * (1.0 - t)))
	if turtle.dunk_timer > 0.0:
		# 被浪打湿：一串气泡从壳边往上冒。
		for i in 5:
			var t := fmod(_accident_t * 0.8 + i * 0.2, 1.0)
			draw_circle(turtle.position + Vector2(-30.0 + i * 15.0, -40.0 - t * 70.0),
				4.0 - i * 0.4, Color(0.8, 0.95, 1.0, 0.5 * (1.0 - t)))
	if action_fx_t >= 0.0 and action_fx_t <= ACTION_FX_TIME:
		# P1-5 主动动作成功：BRO DIVE 青色向下 / BRO OLLIE 金色向上，一眼分得开。
		var kfx := action_fx_t / ACTION_FX_TIME
		var dive := action_fx_kind == "dive"
		var col := Color(0.55, 0.95, 1.0, 0.85 * (1.0 - kfx)) if dive \
			else Color(1.0, 0.85, 0.3, 0.9 * (1.0 - kfx))
		var center := action_fx_pos
		draw_arc(center, 34.0 + 62.0 * kfx, 0, TAU, 32, col, 4.0)
		var dir := 1.0 if dive else -1.0
		for i in 3:
			var yy := center.y + dir * (44.0 + i * 16.0 + 26.0 * kfx)
			draw_line(Vector2(center.x - 12.0, yy),
				Vector2(center.x, yy + dir * 9.0), col, 4.0)
			draw_line(Vector2(center.x + 12.0, yy),
				Vector2(center.x, yy + dir * 9.0), col, 4.0)
		draw_string(ThemeDB.fallback_font,
			center + Vector2(-60.0, -62.0 - 10.0 * kfx),
			Locale.t("combo.bro_dive" if dive else "combo.bro_ollie"),
			HORIZONTAL_ALIGNMENT_CENTER, 120, 16, col)


## P1-6：屏幕右缘的 Z3 预警图标。画在天空层（y≈150），不压水面的操作带；
## 障碍进画面前钉在右缘，进画面后随世界坐标自然靠近。图标 = 感叹号 + 剩余
## 时间环 + 动作箭头（浮木 ↑↓ / 高墙 ↑↑），只用原生绘制。
func _draw_z3_warning() -> void:
	if z3_warn_group == "" or z3_warn_dist < 0.0:
		return
	var edge: float = turtle.position.x + Z3_EDGE_X
	var obstacle_x: float = turtle.position.x + z3_warn_dist
	var wx: float = minf(obstacle_x - 50.0, edge)
	var k: float = clampf(z3_warn_dist / Z3_WARN_RANGE, 0.0, 1.0)
	var pulse := 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.006))
	var log_kind := z3_warn_kind == "FLOATING_LOG"
	var col := Color(0.55, 0.95, 1.0, pulse) if log_kind \
		else Color(1.0, 0.85, 0.3, pulse)
	var p := Vector2(wx, Z3_ICON_Y)
	# 底圈 + 剩余距离环（越近越满）。
	draw_arc(p, 22.0, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.3 * pulse), 2.0)
	draw_arc(p, 22.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - k), 24, col, 3.0)
	draw_string(ThemeDB.fallback_font, p + Vector2(-4, 7), "!",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
	# 动作箭头：浮木 = 跳 + 潜，高墙 = 跃起 + 蹬踏，方向相反。
	var glyph_y := p.y + 34.0
	if log_kind:
		draw_line(Vector2(p.x - 14, glyph_y + 8), Vector2(p.x - 6, glyph_y - 2), col, 3.0)
		draw_line(Vector2(p.x + 2, glyph_y + 8), Vector2(p.x + 10, glyph_y - 2), col, 3.0)
		draw_line(Vector2(p.x - 14, glyph_y + 20), Vector2(p.x - 6, glyph_y + 10), col, 3.0)
		draw_line(Vector2(p.x + 2, glyph_y + 20), Vector2(p.x + 10, glyph_y + 10), col, 3.0)
	else:
		for i in 2:
			var yy := glyph_y + i * 10.0
			draw_line(Vector2(p.x - 14, yy + 8), Vector2(p.x - 6, yy - 2), col, 3.0)
			draw_line(Vector2(p.x + 2, yy + 8), Vector2(p.x + 10, yy - 2), col, 3.0)
	# 障碍名：靠右对齐，往画面里侧展开，不压中心。
	draw_string(ThemeDB.fallback_font, Vector2(p.x - 200.0, p.y - 32.0),
		Locale.t("hazard.floating_log" if log_kind else "hazard.high_wall"),
		HORIZONTAL_ALIGNMENT_RIGHT, 196.0, 15, col)
	# 靠近方向：三个小箭头指向障碍（向右）。
	for i in 3:
		var ax := p.x - 40.0 - i * 12.0 + fmod(z3_warn_t * 40.0, 12.0)
		draw_line(Vector2(ax, p.y - 6), Vector2(ax + 6, p.y),
			Color(col.r, col.g, col.b, col.a * 0.6), 2.0)
		draw_line(Vector2(ax, p.y + 6), Vector2(ax + 6, p.y),
			Color(col.r, col.g, col.b, col.a * 0.6), 2.0)


## P1-5：落壳水花。记在兔子真实落点，0.4 s 内扩散消失；只画，不加分。
func _draw_land_splash() -> void:
	if land_splash_t < 0.0 or land_splash_t > LAND_SPLASH_TIME:
		return
	var k := land_splash_t / LAND_SPLASH_TIME
	var fade := 1.0 - k
	var p := land_splash_pos + Vector2(0, 8)
	draw_arc(p, 9.0 + 30.0 * k, PI, TAU, 20,
		Color(0.85, 0.97, 1.0, 0.7 * fade), 3.0)
	for i in 4:
		var a := PI + PI * float(i) / 3.0
		draw_circle(p + Vector2(cos(a), sin(a)) * (10.0 + 24.0 * k),
			2.6 * fade + 0.6, Color(0.9, 1.0, 1.0, 0.75 * fade))


## Phase O：能量海藻团。画在乌龟巡航深度（NEUTRAL_DEPTH），
## 因此“乌龟自然经过”和“兔子蹲在壳上”都看得见它；后方 450 px 就是本次遭遇的障碍。
func _draw_snacks() -> void:
	var cam_x: float = camera.position.x if camera != null else turtle.position.x
	for enc in _snack_list():
		var x := float(enc["x"])
		if absf(x - cam_x) > 1300.0:
			continue
		_draw_snack(x, bool(enc.get("eaten", false)))
	# P4：前方还有没吃的——两个人一起伸手，谁被操控谁的伸手更亮。
	if snack_interest_x >= 0.0 and GameManager.accident_state == "NONE":
		_draw_snack_contest(snack_interest_x)
	if snack_boost_active():
		_draw_turbo_fx()


## 争抢表现：两个角色各伸出一串朝食物移动的小点；没被操控的那个头顶冒 “!”。
## 这只是“看得见的选择”，判定仍然只看 _snack_eater()。
func _draw_snack_contest(x: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var food := Vector2(x, Tuning.NEUTRAL_DEPTH - 2.0 + sin(t * 3.0) * 6.0)
	var ctrl: String = GameManager.current_control
	# 够得着才伸手：跃起或不在巡航深度的角色不画，免得看起来“想吃却吃不到”是 bug。
	var turtle_wants: bool = not turtle.leap_active \
		and absf(turtle.position.y - Tuning.NEUTRAL_DEPTH) <= 40.0
	var rabbit_wants: bool = mount != null and mount.state == "RIDING" \
		and not rabbit.is_airborne() and rabbit.state != "STUNNED"
	if turtle_wants:
		_draw_reach(turtle.position + Vector2(26.0, 0.0), food, ctrl == "turtle", 0.0)
	if rabbit_wants:
		_draw_reach(rabbit.position + Vector2(0.0, -12.0), food,
			ctrl == "rabbit", 0.5)
	if rabbit_wants and ctrl != "rabbit":
		_draw_want_mark(rabbit.position + Vector2(-18.0, -52.0), t,
			rabbit.position + Vector2(-4.0, -18.0))
	if ctrl == "rabbit" and turtle_wants:
		_draw_want_mark(turtle.position + Vector2(-40.0, -52.0), t,
			turtle.position + Vector2(-24.0, -18.0))
	# CORE-FEEL-07 P1-C：把“现在谁吃”直接写在会吃的那一个头顶；
	# 够不到时（跃起/不在巡航/兔子晕着）不画，HUD 那边会说明原因。
	var eater := _snack_eater()
	if eater == "rabbit":
		_draw_eat_mark(rabbit.position + Vector2(26.0, -44.0), t)
	elif eater == "turtle":
		# 乌龟的头在右侧；标记放在头外侧，别被壳上的兔子挡住。
		_draw_eat_mark(turtle.position + Vector2(66.0, -32.0), t)


func _draw_reach(from: Vector2, to: Vector2, active: bool, phase: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var col := Color(1.0, 0.96, 0.6, 0.85) if active else Color(1.0, 0.6, 0.3, 0.55)
	for i in 3:
		var k := fmod(t * 1.7 + phase + float(i) / 3.0, 1.0)
		var p: Vector2 = from.lerp(to, 0.25 + 0.55 * k)
		draw_circle(p, 4.5 if active else 3.0, col)


func _draw_want_mark(at: Vector2, t: float, tail_to: Vector2) -> void:
	var bob := sin(t * 6.0) * 3.0
	var p := at + Vector2(0.0, bob)
	# 小尾巴指向“想吃的那个角色”，免得泡泡被看成是壳/乌龟的。
	var dir := (tail_to - p).normalized()
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		p + dir * 10.0 + side * 5.0,
		p + dir * 10.0 - side * 5.0,
		p + dir * 25.0]), Color(1.0, 0.9, 0.35, 0.9))
	draw_circle(p, 12.0, Color(1.0, 0.9, 0.35, 0.9))
	draw_string(ThemeDB.fallback_font, p + Vector2(-5.0, 7.0), "!",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.2, 0.14, 0.05, 1.0))


## CORE-FEEL-07 P1-C：“吃”标记。绿色圆底 + 角色名，直接告诉玩家这一口归谁。
func _draw_eat_mark(at: Vector2, t: float) -> void:
	var bob := sin(t * 5.0) * 2.0
	var p := at + Vector2(0.0, bob)
	draw_circle(p, 16.0, Color(0.15, 0.9, 0.55, 0.92))
	var txt := Locale.t("world.eat_now")
	var fs := 15
	var sz := ThemeDB.fallback_font.get_string_size(txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(ThemeDB.fallback_font, p + Vector2(-sz.x * 0.5, sz.y * 0.32),
		txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.04, 0.16, 0.09, 1.0))


## 兔子的跳跃强化：壳上一圈上浮的小箭头，和乌龟的三条速度线区分开。
func _draw_rabbit_boost_fx() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var base: Vector2 = rabbit.position + Vector2(0.0, -30.0)
	for i in 3:
		var k := fmod(t * 1.8 + float(i) / 3.0, 1.0)
		var y: float = base.y - k * 46.0
		var a := 0.45 + 0.55 * (1.0 - k)
		var c := Color(0.1, 0.85, 0.45, a)
		draw_line(Vector2(base.x - 14.0 + i * 14.0, y + 7.0),
			Vector2(base.x - 14.0 + i * 14.0, y), c, 4.0)
		draw_line(Vector2(base.x - 14.0 + i * 14.0, y),
			Vector2(base.x - 19.0 + i * 14.0, y + 5.0), c, 4.0)
		draw_line(Vector2(base.x - 14.0 + i * 14.0, y),
			Vector2(base.x - 9.0 + i * 14.0, y + 5.0), c, 4.0)


func _draw_snack(x: float, eaten: bool) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var y := Tuning.NEUTRAL_DEPTH - 2.0
	if eaten:
		# 吃掉的只留一圈散开的涟漪，不假装还有食物。
		draw_arc(Vector2(x, y), 28.0, 0.0, TAU, 24, Color(0.6, 1.0, 0.8, 0.22), 2.0)
		return
	var bob := sin(t * 3.0) * 6.0
	var cy := y + bob
	# 软光晕：远处也能在障碍轮廓前认出“这是食物”。
	draw_circle(Vector2(x, cy), 42.0, Color(0.3, 1.0, 0.6, 0.12))
	draw_arc(Vector2(x, cy), 36.0, 0.0, TAU, 30, Color(0.7, 1.0, 0.85, 0.65), 3.0)
	# 三片海藻叶 + 中心亮核，比加速带箭头更像“能咬的东西”。
	for i in 3:
		var a := -0.55 + i * 0.55 + sin(t * 2.0 + i) * 0.12
		var tip := Vector2(x + sin(a) * 36.0, cy - 30.0 - cos(a) * 12.0)
		draw_line(Vector2(x, cy + 8.0), tip, Color(0.22, 0.9, 0.5, 0.95), 8.0)
		draw_circle(tip, 7.0, Color(0.55, 1.0, 0.7, 0.95))
	draw_circle(Vector2(x, cy), 23.0, Color(0.14, 0.8, 0.42, 0.95))
	draw_circle(Vector2(x, cy - 4.0), 12.0, Color(0.75, 1.0, 0.85, 0.95))
	draw_string(ThemeDB.fallback_font, Vector2(x - 52, cy - 92),
		Locale.t("world.snack"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
		Color(0.7, 1.0, 0.85, 0.95))
	# CORE-FEEL-07 P1-C：食物自己就标出两种效果（兔子 ↑ 更高跳 / 乌龟 » 加速），
	# 当前操控的那一个更亮。玩家不吃也能先看懂“这一口会变成什么”。
	var font := ThemeDB.fallback_font
	var rabbit_lit: bool = GameManager.current_control == "rabbit"
	var turtle_lit: bool = GameManager.current_control == "turtle"
	draw_string(font, Vector2(x - 40.0, cy - 58.0), "↑",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
		Color(0.4, 1.0, 0.6, 0.98) if rabbit_lit else Color(0.4, 0.85, 0.55, 0.32))
	draw_string(font, Vector2(x + 14.0, cy - 58.0), "»",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
		Color(0.45, 0.95, 1.0, 0.98) if turtle_lit else Color(0.45, 0.8, 0.9, 0.32))


## 吞食反馈：食物从原位缩进吃到它的那张嘴前，再冒一串“咕咚”泡泡。
## P4：兔子吃到时从兔子嘴边冒，别把特效画到乌龟嘴上。
func _draw_gulp_fx() -> void:
	var k := 1.0 - snack_gulp_t / 0.45
	var from := Vector2(snack_gulp_x, Tuning.NEUTRAL_DEPTH - 2.0)
	var rabbit_ate := snack_last_by == "rabbit"
	var mouth: Vector2 = rabbit.position + Vector2(0.0, -8.0) if rabbit_ate \
		else turtle.position + Vector2(34.0, 2.0)
	var p: Vector2 = from.lerp(mouth, minf(k * 3.0, 1.0))
	var r := lerpf(20.0, 5.0, minf(k * 3.0, 1.0))
	draw_circle(p, r, Color(0.3, 1.0, 0.6, 0.9))
	draw_circle(p - Vector2(2.0, 3.0), r * 0.5, Color(0.75, 1.0, 0.85, 0.9))
	if k > 0.35:
		# 亲手喂到：气泡多一倍，外加一圈扩开的光环——不用加文字也看得出“这口更值”。
		var bubbles: int = 6 if snack_gulp_by_player else 3
		if rabbit_ate:
			bubbles = 3
		for i in bubbles:
			var q: Vector2 = mouth + Vector2(-6.0 + i * 12.0, -18.0 - (k - 0.35) * 46.0)
			draw_circle(q, 3.5 * (1.0 - k * 0.5), Color(0.7, 1.0, 0.85, 1.0 - k))
		if snack_gulp_by_player:
			draw_arc(mouth, 18.0 + (k - 0.35) * 120.0, 0.0, TAU, 28,
				Color(0.55, 1.0, 0.75, 0.55 * (1.0 - k) / 0.65), 3.0)


## 加速状态：壳后拖三条速度线，配合 HUD 的 TURBO 行。
func _draw_turbo_fx() -> void:
	var y: float = turtle.position.y
	for i in 3:
		var len := 46.0 + i * 16.0
		var a := 0.35 - i * 0.09
		draw_line(Vector2(turtle.position.x - 52.0 - i * 6.0, y - 10.0 + i * 10.0),
			Vector2(turtle.position.x - 52.0 - i * 6.0 - len, y - 10.0 + i * 10.0),
			Color(0.55, 1.0, 0.9, a), 4.0)


## F3 调试层：ID、类别、该谁动、预期动作、判定框、上下安全通道、触发距离。
## 正常游玩完全不出现；关掉 F3 后世界里的开发标注全部消失。
func _draw_debug_group(group: Dictionary) -> void:
	var start := _group_start(group)
	var first: Rect2 = group["rects"][0]
	var dist := int(round(start - turtle.position.x))
	for i in group["rects"].size():
		draw_rect(hazard_rect_live(group, i), Color(1.0, 0.85, 0.2, 0.85), false, 2.0)
	# 组合障碍：把“上安全区 / 下水道”直接画出来，判定框和可走空间一眼对上。
	if group["kind"] == "FLOATING_LOG":
		_draw_safe_channels(group)
	var speed: float = maxf(turtle.speed, 1.0)
	var role := LevelDataScript.role_for_kind(group["kind"])
	var eta := maxf(float(dist), 0.0) / speed
	var label := "#%s  %s  ID:%s  %s  ROLE:%s  ->  %s   d=%d px  t=%.1fs" % [
		group["group"], group["kind"], String(group.get("identity", "-")),
		_category_of(group["kind"]), role,
		Locale.hazard(group["action"]), dist, eta]
	draw_rect(Rect2(first.position.x, first.position.y - 34, 760, 24),
		Color(0.02, 0.05, 0.08, 0.82))
	draw_string(ThemeDB.fallback_font,
		Vector2(first.position.x + 6, first.position.y - 16),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.9, 0.5))
	var tx := start - Tuning.PROMPT_RANGE
	draw_line(Vector2(tx, 110), Vector2(tx, 520), Color(1.0, 0.8, 0.3, 0.35), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(tx + 4, 128),
		"TRIGGER %d" % int(Tuning.PROMPT_RANGE),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.8, 0.3, 0.7))


## 四类障碍的归类。A 类里再分“趴低”和“跳跃”，因为输入不同。
func _category_of(kind: String) -> String:
	match kind:
		"LOW_BIRD", "LOW_BEAM":
			return "A/RABBIT-CROUCH"
		"SURFACE_ROCK":
			return "A/RABBIT-JUMP"
		"FLOATING_LOG":
			return "B/COMBINED"
		"SHARK":
			return "C/TURTLE-LEAP"
		"DIVE_GATE":
			return "D/TURTLE-DIVE"
	return "?"


## 组合漂浮物的可走空间：上安全区（兔子跳）与下水道（乌龟潜）。
func _draw_safe_channels(group: Dictionary) -> void:
	var rect := hazard_rect_live(group, 0)
	var upper := Rect2(rect.position.x, rect.position.y - 260.0,
		rect.size.x, 260.0)
	draw_rect(upper, Color(0.3, 1.0, 0.5, 0.12))
	draw_rect(upper, Color(0.3, 1.0, 0.5, 0.45), false, 2.0)
	draw_string(ThemeDB.fallback_font,
		Vector2(rect.position.x + 4, rect.position.y - 246.0),
		Locale.t("world.safe_above"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 1.0, 0.6, 0.9))
	var lower := Rect2(rect.position.x, rect.end.y, rect.size.x,
		760.0 - rect.end.y)
	draw_rect(lower, Color(0.3, 0.8, 1.0, 0.12))
	draw_rect(lower, Color(0.3, 0.8, 1.0, 0.45), false, 2.0)
	draw_string(ThemeDB.fallback_font,
		Vector2(rect.position.x + 4, rect.end.y + 18.0),
		Locale.t("world.safe_below"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.9, 1.0, 0.9))


## 俯冲海鸟（2026-11-13 REBUILD-05 E1 重做）。
##
## 以前的画法在玩家还差 2 s 就俯冲完、停在固定高度，判定却是一整列
## 130～274 的墙——跳起来会撞到“看不见的鸟”。重做后**俯冲和玩家到达同拍**：
##
##   巡航 CRUISE    d > 900            高空绕圈，不构成威胁
##   前摇 TELEGRAPH  900 ≥ d > 240     仍在高空，翅膀收起 + “！” + 落点竖线
##   俯冲 DIVE       240 ≥ d > 0       从高空扎到攻击高度，整段穿过俯冲空域
##   攻击 STRIKE     0 ≥ d > -160      翅膀横扫，覆盖主判定带
##   恢复 RECOVER    -160 ≥ d > -520   拉起回高空
##
## 判定仍是 LevelData 里那两段矩形（主带 234～274 + 俯冲空域 130～234），
## 但这两段现在正好是鸟真正扫过的空间：俯冲穿空域、横扫占主带。
## `bird_pose()` 是画和判共用的唯一一份数，供探针逐帧比对。
## FEEL-49：单组鲨鱼群（shark6）改为三只持续实体。
## 三只鱼在船底跟随；轮到谁，谁就从深水上冲到攻击位置，压住/扫过目标，
## 再退回深水。攻击体就是这只鱼本身，不再另画一只、也不再从玩家身后刷出。
func _init_shark_pack() -> void:
	_shark_pack.clear()
	_shark_attacks.clear()
	_pack_actors.clear()
	_shark_pack_log.clear()
	_shark_stands_t = 0.0
	_shark_stands_taunt_t = 0.0
	_shark_pack_entry_seen = false
	if _shark_group("shark6").is_empty():
		return
	_shark_pack["shark6"] = {"phase": "CIRCLE", "t": 0.0,
		"announced": false, "lead_warned": false,
		"lead_warn_t": -1.0, "now_cued": false}
	# 队形：老大 bx+230，胖 bx+60，瘦 bx-110。
	# attack_top/size 与旧三拍判定几何一致；上冲时从 PACK_DEEP_TOP 升到这里。
	_pack_actors = [
		_make_pack_actor("leader", "turtle", 230.0, 288.0, Vector2(90, 192), false),
		_make_pack_actor("fat", "rabbit", 60.0, 246.0, Vector2(116, 92), true),
		_make_pack_actor("thin", "turtle", -110.0, 130.0, Vector2(90, 236), false),
	]


func _make_pack_actor(mode: String, target: String, offset: float,
		attack_top: float, size: Vector2, fat: bool) -> Dictionary:
	var x: float = turtle.position.x + offset if turtle != null else offset
	var deep_top: float = PACK_DEEP_TOP
	return {
		"mode": mode, "target": target, "offset": offset,
		"attack_top": attack_top, "size": size, "fat": fat,
		"phase": "SWIM", "t": 0.0,
		"x": x, "y": 620.0,
		"tx": x, "hit_logged": false, "end_logged": false,
		"rect": Rect2(x - size.x * 0.5, deep_top, size.x, size.y),
		"strike_rect": Rect2(x - size.x * 0.5, attack_top, size.x, size.y),
		"deep_rect": Rect2(x - size.x * 0.5, deep_top, size.x, size.y),
	}


func _pack_actor(mode: String) -> Dictionary:
	for a in _pack_actors:
		if String(a.get("mode", "")) == mode:
			return a
	return {}


func _pack_owns(key: String) -> bool:
	return key == "shark6" and not _pack_actors.is_empty()


func _shark_group(key: String) -> Dictionary:
	for g in hazard_groups:
		if String(g.get("group", "")) == key:
			return g
	return {}


func _shark_arena_active() -> bool:
	if _shark_pack.is_empty():
		return false
	var ph := String(_shark_pack.get("shark6", {}).get("phase", "DONE"))
	return ph != "CIRCLE" and ph != "DONE"


func _shark_arena_hides(group: Dictionary) -> bool:
	if not _shark_arena_active():
		return false
	if String(group.get("group", "")) == "shark6":
		return false
	var sg := _shark_group("shark6")
	if sg.is_empty():
		return false
	return absf(LevelDataScript.group_start(group)
		- LevelDataScript.group_start(sg)) <= 1500.0


func _tick_shark_pack(delta: float) -> void:
	if _shark_pack.is_empty():
		return
	var key := "shark6"
	var g := _shark_group(key)
	if g.is_empty():
		return
	# 测试场生成的 shark6 不在 Z3 也允许跑；正式关只认玩家实际所在的 Z3，
	# 不能因为 shark6 的组坐标在 Z3 就让鲨群提前从 Z2 窜出来。
	if not bool(g.get("test_spawned", false)) \
			and int(LevelDataScript.zone_at(turtle.position.x)["id"]) != 3:
		return
	var st: Dictionary = _shark_pack[key]
	var phase := String(st["phase"])
	if phase == "DONE":
		return
	if phase == "CIRCLE" and absf(turtle.position.x - _group_start(g)) < 1100.0 \
			and not _shark_pack_entry_seen:
		_shark_pack_entry_seen = true
		GameManager.feedback.emit(Locale.t("feedback.shark_pack"), "hit")
	# 救援/落水优先级高于鲨群；普通撞击硬直（RABBIT_STUN）不算救援。
	var interrupted: bool = mount.state in ["RESCUING", "RESCUE_FALLING",
			"RESCUE_ACTIVE", "RESCUE_AIR"] \
		or rabbit.state in ["FALLING_WATER", "PASSED_OUT"] \
		or GameManager.accident_state in ["RABBIT_WATER", "RABBIT_AIR",
			"TURTLE_REEF", "OXYGEN_OUT"]
	if interrupted:
		# 救援期间只清攻击，不把整组永久判 DONE；恢复后还能重新进入三拍。
		_pack_reset_actors()
		st["phase"] = "CIRCLE"
		st["t"] = 0.0
		st["announced"] = false
		st["lead_warned"] = false
		st["lead_warn_t"] = -1.0
		st["now_cued"] = false
		return
	# 玩家已经跑过整组时，仍在 CIRCLE 的鲨群放弃出场。
	if phase == "CIRCLE" and turtle.position.x > _group_end(g) + 340.0:
		st["phase"] = "DONE"
		st["t"] = 0.0
		return

	_update_pack_swimmers(delta)
	st["t"] = float(st["t"]) + delta
	# FEEL-43：老大预警后 0.35 s 给“现在——跃起”第二拍提示。
	if phase == "LEAD_LUNGE":
		var la := _pack_actor("leader")
		if String(la.get("phase", "")) == "WARN" and not bool(st.get("lead_warned", false)):
			st["lead_warned"] = true
			st["lead_warn_t"] = hazard_clock
		elif String(la.get("phase", "")) == "WARN" and not bool(st.get("now_cued", false)) \
				and hazard_clock - float(st.get("lead_warn_t", -1.0)) >= 0.35:
			st["now_cued"] = true
			GameManager.feedback.emit(Locale.t("feedback.shark_boss_now"), "pop")
	match phase:
		"CIRCLE":
			if _shark_pack_entry_seen and float(st["t"]) >= PACK_FOLLOW_TIME:
				st["phase"] = "LEAD_LUNGE"
				st["t"] = 0.0
				_pack_begin_warn("leader", PACK_LEAD_WARN)
		"LEAD_LUNGE":
			var la: Dictionary = _pack_actor("leader")
			_advance_pack_actor(la, delta)
			if String(la.get("phase", "")) == "SWIM":
				st["phase"] = "SAFE1"
				st["t"] = 0.0
		"SAFE1":
			if float(st["t"]) >= PACK_SAFETY:
				st["phase"] = "GAP1"
				st["t"] = 0.0
				st["target"] = "rabbit"
				_pack_begin_warn("fat", PACK_WARN_FAT)
		"GAP1":
			var fa: Dictionary = _pack_actor("fat")
			_advance_pack_actor(fa, delta)
			if String(fa.get("phase", "")) in ["RISE", "HOLD", "RETREAT"]:
				st["phase"] = "FAT_LUNGE"
				st["t"] = 0.0
		"FAT_LUNGE":
			var fa: Dictionary = _pack_actor("fat")
			_advance_pack_actor(fa, delta)
			if String(fa.get("phase", "")) == "SWIM":
				st["phase"] = "SAFE2"
				st["t"] = 0.0
		"SAFE2":
			if float(st["t"]) >= PACK_SAFETY:
				st["phase"] = "GAP2"
				st["t"] = 0.0
				st["target"] = "turtle"
				_pack_begin_warn("thin", PACK_WARN_THIN)
		"GAP2":
			var ta: Dictionary = _pack_actor("thin")
			_advance_pack_actor(ta, delta)
			if String(ta.get("phase", "")) in ["RISE", "HOLD", "RETREAT"]:
				st["phase"] = "THIN_LUNGE"
				st["t"] = 0.0
		"THIN_LUNGE":
			var ta: Dictionary = _pack_actor("thin")
			_advance_pack_actor(ta, delta)
			if String(ta.get("phase", "")) == "SWIM":
				st["phase"] = "RETREAT"
				st["t"] = 0.0
		"RETREAT":
			if float(st["t"]) >= 0.60:
				st["phase"] = "DONE"
				st["t"] = 0.0
				_shark_attacks.clear()
				# 打完不是消失：鲨群沉到屏幕下方的看台，继续看兄弟俩跑。
				show_shark_stands(12.0)


## 三只鱼平时都在船底跟随；只有轮到的那只离开队形上冲。
func _update_pack_swimmers(delta: float) -> void:
	for a in _pack_actors:
		if String(a.get("phase", "")) != "SWIM":
			continue
		var want_x: float = turtle.position.x + float(a["offset"])
		a["x"] = lerpf(float(a.get("x", want_x)), want_x,
			clampf(delta * 8.0, 0.0, 1.0))
		a["y"] = 620.0 + sin(Time.get_ticks_msec() * 0.004 +
			float(a["offset"]) * 0.013) * 5.0
		var size: Vector2 = a["size"]
		a["rect"] = Rect2(float(a["x"]) - size.x * 0.5, PACK_DEEP_TOP, size.x, size.y)
		a["deep_rect"] = a["rect"]


func _pack_target_x(a: Dictionary) -> float:
	if String(a.get("target", "")) == "rabbit":
		return rabbit.position.x
	return turtle.position.x


func _pack_begin_warn(mode: String, duration: float) -> void:
	var a := _pack_actor(mode)
	if a.is_empty():
		return
	a["phase"] = "WARN"
	a["t"] = 0.0
	a["warn"] = duration
	a["x0"] = float(a.get("x", 0.0))
	a["tx"] = _pack_target_x(a)
	a["hit_logged"] = false
	a["end_logged"] = false
	if mode == "leader":
		_ambush["shark6"] = {"phase": "TELEGRAPH", "t": 0.0}
	_shark_pack_log.append({"event": "warn", "who": mode,
		"target": String(a["target"]), "t": snappedf(hazard_clock, 0.01)})
	match mode:
		"leader":
			GameManager.feedback.emit(Locale.t("feedback.shark_boss_ready"), "hit")
			GameManager.bro_say.emit("rabbit", Locale.t("bro.leap"))
		"fat":
			GameManager.feedback.emit(Locale.t("feedback.shark_fat"), "hit")
			GameManager.bro_say.emit("turtle", Locale.t("bro.crouch"))
		"thin":
			GameManager.feedback.emit(Locale.t("feedback.shark_thin"), "hit")
			GameManager.bro_say.emit("rabbit", Locale.t("bro.down"))


## 同一只鲨鱼走完 WARN → RISE → HOLD → RETREAT → SWIM。
## 上冲、压顶、下潜的 rect 就是 _check_shark_attacks 判的那个 rect。
func _advance_pack_actor(a: Dictionary, delta: float) -> void:
	if a.is_empty():
		return
	var phase := String(a.get("phase", "SWIM"))
	var t := float(a.get("t", 0.0)) + delta
	a["t"] = t
	var size: Vector2 = a["size"]
	match phase:
		"WARN":
			var wp := clampf(t / maxf(float(a.get("warn", 1.0)), 0.01), 0.0, 1.0)
			a["x"] = lerpf(float(a.get("x0", a["x"])), float(a["tx"]), wp)
			a["rect"] = Rect2(float(a["x"]) - size.x * 0.5,
				PACK_DEEP_TOP, size.x, size.y)
			if t >= float(a.get("warn", 1.0)):
				_begin_pack_attack(a)
		"RISE":
			if t >= PACK_ACTOR_RISE:
				a["phase"] = "HOLD"
				a["t"] = 0.0
				a["rect"] = Rect2(float(a["tx"]) - size.x * 0.5,
					float(a["attack_top"]), size.x, size.y)
			else:
				var p := smoothstep(0.0, 1.0, t / PACK_ACTOR_RISE)
				var y := lerpf(PACK_DEEP_TOP, float(a["attack_top"]), p)
				# 过冲 12 px 再回落，读作“整条鱼冲出水”。
				if p > 0.78:
					y -= sin((p - 0.78) / 0.22 * PI) * 12.0
				a["rect"] = Rect2(float(a["tx"]) - size.x * 0.5,
					y, size.x, size.y)
			a["x"] = float(a["tx"])
			a["y"] = (a["rect"] as Rect2).get_center().y
		"HOLD":
			a["rect"] = Rect2(float(a["tx"]) - size.x * 0.5,
				float(a["attack_top"]), size.x, size.y)
			a["x"] = float(a["tx"])
			a["y"] = (a["rect"] as Rect2).get_center().y
			if t >= PACK_ACTOR_HOLD:
				a["phase"] = "RETREAT"
				a["t"] = 0.0
		"RETREAT":
			var p := clampf(t / PACK_ACTOR_RETREAT, 0.0, 1.0)
			a["rect"] = Rect2(float(a["tx"]) - size.x * 0.5,
				lerpf(float(a["attack_top"]), PACK_DEEP_TOP, p),
				size.x, size.y)
			a["x"] = float(a["tx"])
			a["y"] = (a["rect"] as Rect2).get_center().y
			if p >= 1.0:
				a["phase"] = "SWIM"
				a["t"] = 0.0
				_end_pack_attack(a)


func _begin_pack_attack(a: Dictionary) -> void:
	if a.is_empty():
		return
	a["t"] = 0.0
	a["phase"] = "RISE"
	a["hit_logged"] = false
	a["tx"] = _pack_target_x(a)
	a["strike_rect"] = Rect2(float(a["tx"]) - (a["size"] as Vector2).x * 0.5,
		float(a["attack_top"]), (a["size"] as Vector2).x, (a["size"] as Vector2).y)
	if not _shark_attacks.has(a):
		_shark_attacks.append(a)
	if String(a["mode"]) == "leader":
		_ambush["shark6"] = {"phase": "LUNGE", "t": 0.0}
	_shark_pack_log.append({"event": "attack", "who": String(a["mode"]),
		"target": String(a["target"]), "x": snappedf(float(a["tx"]), 0.1),
		"t": snappedf(hazard_clock, 0.01)})


func _end_pack_attack(a: Dictionary) -> void:
	if a.is_empty():
		return
	for i in range(_shark_attacks.size() - 1, -1, -1):
		if String(_shark_attacks[i].get("mode", "")) == String(a["mode"]):
			_shark_attacks.remove_at(i)
	if not bool(a.get("end_logged", false)):
		a["end_logged"] = true
		_shark_pack_log.append({"event": "end", "who": String(a["mode"]),
			"target": String(a["target"]), "t": snappedf(hazard_clock, 0.01)})
	if String(a["mode"]) == "leader":
		_ambush["shark6"] = {"phase": "DOWN", "t": 0.0}


func _pack_reset_actors() -> void:
	_shark_attacks.clear()
	for a in _pack_actors:
		a["phase"] = "SWIM"
		a["t"] = 0.0
		a["x"] = turtle.position.x + float(a["offset"])
		a["y"] = 620.0
		var size: Vector2 = a["size"]
		a["rect"] = Rect2(float(a["x"]) - size.x * 0.5, PACK_DEEP_TOP, size.x, size.y)
		a["hit_logged"] = false
		a["end_logged"] = false


## 攻击判定只读三只实体自己的 rect。rect 在 _advance_pack_actor 里随
## 上冲/压顶/下潜一起移动，所以画到哪就判到哪，不存在第二套攻击体。
func _check_shark_attacks(_delta: float) -> void:
	if test_disable_hazards or _shark_attacks.is_empty():
		return
	if _rescue_context() != "NONE" or rabbit.state in ["FALLING_WATER", "PASSED_OUT"]:
		_shark_attacks.clear()
		return
	for i in range(_shark_attacks.size() - 1, -1, -1):
		var a: Dictionary = _shark_attacks[i]
		# 上冲本身不是攻击帧：鱼从深水穿上来时，玩家可能正在下潜/跃起。
		# 只有鱼到达最终攻击位置（HOLD）时才用它的身体判伤，避免“从下面
		# 穿过去也算撞上”，也让下潜/跃起的旧答案继续成立。
		if String(a.get("phase", "HOLD")) != "HOLD":
			continue
		var target := String(a.get("target", ""))
		var rect: Rect2 = a["rect"]
		var hit := false
		if target == "turtle" and GameManager.accident_state == "NONE" \
				and _inset(turtle.get_body_rect(), 3.0).intersects(rect):
			_turtle_contact("pack_" + String(a.get("mode", "")), "SHARK", true)
			hit = true
		elif target == "rabbit" and GameManager.accident_state == "NONE" \
				and _inset(rabbit.get_body_rect(), 3.0).intersects(rect):
			# 胖鲨压站立/跳跃兔；趴低从肚子下过。
			if String(a.get("mode", "")) != "fat" or rabbit.state != "CROUCHING":
				hit = _rabbit_contact("SHARK", true)
		if hit:
			_shark_pack_log.append({"event": "hit", "who": String(a.get("mode", "")),
				"target": target, "x": snappedf(float(a.get("x", 0.0)), 0.1),
				"t": snappedf(hazard_clock, 0.01)})
			a["hit_logged"] = true
			_end_pack_attack(a)


func _pack_attack_active(mode: String) -> bool:
	for a in _shark_attacks:
		if String(a.get("mode", "")) == mode:
			return true
	return false


func _draw_shark_pack_fx() -> void:
	if _shark_stands_t > 0.0:
		_draw_shark_stands()
	if _shark_pack.is_empty():
		return
	var g := _shark_group("shark6")
	if g.is_empty():
		return
	if not bool(g.get("test_spawned", false)) \
			and int(LevelDataScript.zone_at(turtle.position.x)["id"]) != 3:
		return
	var st: Dictionary = _shark_pack.get("shark6", {})
	var phase_name := String(st.get("phase", "DONE"))
	if phase_name == "DONE":
		return
	# FEEL-45：开局 shark6 还在几万像素外时不要画“三只鱼跟着玩家”。
	var pack_x := _group_start(g)
	if phase_name == "CIRCLE" and absf(turtle.position.x - pack_x) > 1600.0:
		return
	for a in _pack_actors:
		var mode := String(a.get("mode", ""))
		var aphase := String(a.get("phase", "SWIM"))
		var scale := 1.02 if mode == "leader" else (0.78 if mode == "fat" else 0.72)
		if aphase in ["SWIM", "WARN"]:
			var p := Vector2(float(a["x"]), float(a["y"]))
			_draw_pack_shark(p, scale, bool(a.get("fat", false)))
			if aphase == "WARN":
				# 同一只鱼在水下抬头：水面背鳍 + 目标圈 + 上冲气泡。
				var target: Vector2 = rabbit.position if String(a["target"]) == "rabbit" \
					else turtle.position
				draw_colored_polygon(PackedVector2Array([
					Vector2(p.x - 24, SURFACE_Y + 4),
					Vector2(p.x + 2, SURFACE_Y - 28),
					Vector2(p.x + 28, SURFACE_Y + 4),
				]), Color(0.3, 0.38, 0.46, 0.92))
				for i in 4:
					var bt := fmod(float(a["t"]) * 2.1 + i * 0.25, 1.0)
					draw_circle(Vector2(p.x - 20 + i * 13,
						SURFACE_Y + 34.0 - bt * 54.0), 3.2,
						Color(0.85, 0.96, 1.0, 0.65 * (1.0 - bt)))
				draw_line(Vector2(p.x, SURFACE_Y), target + Vector2(0, -18),
					Color(1.0, 0.5, 0.25, 0.38), 3.0)
				_draw_lock_reticle(target, Color(1.0, 0.5, 0.25),
					false, String(a["target"]))
				draw_string(ThemeDB.fallback_font, target + Vector2(-8, -96), "!",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 28,
					Color(1.0, 0.55, 0.25, 0.95))
		else:
			var rect: Rect2 = a["rect"]
			if mode == "thin":
				# 瘦鲨压顶：整条纵向危险区就是它上冲后的身体。
				draw_rect(rect, Color(0.45, 0.80, 0.95, 0.10), true)
				for i in 4:
					var lx := rect.position.x + rect.size.x * (0.2 + 0.2 * i)
					draw_line(Vector2(lx, rect.position.y), Vector2(lx - 12.0, rect.end.y),
						Color(0.55, 0.88, 1.0, 0.35), 2.0)
			# 上冲水线：从深水直接连到鱼尾，读作“它自己冲上来的”。
			draw_line(Vector2(rect.get_center().x, rect.end.y),
				Vector2(rect.get_center().x, PACK_DEEP_TOP),
				Color(0.65, 0.88, 1.0, 0.20), 3.0)
			for i in 3:
				var bt := fmod(Time.get_ticks_msec() * 0.0018 + i * 0.31, 1.0)
				draw_circle(Vector2(rect.get_center().x + 18.0 + i * 8.0,
					rect.end.y + 10.0 + bt * 80.0), 3.0,
					Color(0.85, 0.96, 1.0, 0.45 * (1.0 - bt)))
			_draw_pack_shark_rising(rect, bool(a.get("fat", false)))
			draw_rect(rect, Color(1.0, 0.5, 0.25, 0.16), false, 2.0)
	_draw_pack_lock()


func _draw_lock_reticle(target: Vector2, col: Color, locked: bool,
		who: String) -> void:
	var r := 34.0
	if locked:
		r = 31.0 + sin(Time.get_ticks_msec() * 0.014) * 1.5
	draw_arc(target, r, 0.0, TAU, 36, Color(col.r, col.g, col.b, 0.92), 2.5)
	for d in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		draw_line(target + d * (r + 7.0), target + d * 12.0, col, 3.0)
	draw_circle(target, 3.0, col)
	draw_string(ThemeDB.fallback_font, target + Vector2(-18, r + 22),
		Locale.t("who." + who), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)


func _draw_pack_lock() -> void:
	for a in _pack_actors:
		var ap := String(a.get("phase", ""))
		if ap not in ["RISE", "HOLD"]:
			continue
		var who := String(a.get("target", "turtle"))
		var target: Vector2 = rabbit.position if who == "rabbit" else turtle.position
		_draw_lock_reticle(target, Color(1.0, 0.32, 0.2), ap == "HOLD", who)


## 竖向上冲形态：复用普通伏击鲨的身体读法，头朝上、尾在深水。
func _draw_pack_shark_rising(rect: Rect2, fat: bool) -> void:
	var sx := rect.get_center().x
	var top := rect.position.y
	var bot := rect.end.y
	var body_col := Color(0.42, 0.5, 0.58) if not fat else Color(0.46, 0.52, 0.56)
	var fin_col := Color(0.36, 0.44, 0.52)
	var half := rect.size.x * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(sx - half * 0.25, bot - 40), Vector2(sx - half * 0.62, bot - 2),
		Vector2(sx, bot - 20), Vector2(sx + half * 0.62, bot - 2),
		Vector2(sx + half * 0.25, bot - 40),
	]), fin_col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(sx - half * 0.86, top + 4), Vector2(sx + half * 0.86, top + 4),
		Vector2(sx + half * 0.66, top + minf(96.0, rect.size.y * 0.5)),
		Vector2(sx + half * 0.28, bot - 46),
		Vector2(sx - half * 0.28, bot - 46),
		Vector2(sx - half * 0.66, top + minf(96.0, rect.size.y * 0.5)),
	]), body_col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(sx - half * 0.62, top + minf(96.0, rect.size.y * 0.5)),
		Vector2(sx - half * 1.35, top + minf(142.0, rect.size.y * 0.7)),
		Vector2(sx - half * 0.52, top + minf(148.0, rect.size.y * 0.75)),
	]), fin_col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(sx + half * 0.56, top + minf(120.0, rect.size.y * 0.6)),
		Vector2(sx + half * 1.25, top + minf(150.0, rect.size.y * 0.75)),
		Vector2(sx + half * 0.45, top + minf(154.0, rect.size.y * 0.8)),
	]), fin_col)
	draw_rect(Rect2(sx - half * 0.72, top + 16, half * 1.44, 10),
		Color(0.9, 0.9, 0.88))
	for i in 6:
		var tx := sx - half * 0.68 + i * (half * 1.36 / 5.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(tx, top + 26), Vector2(tx + 4, top + 33),
			Vector2(tx + 8, top + 26),
		]), Color(0.95, 0.95, 0.92))
	draw_circle(Vector2(sx - half * 0.45, top + 6), 4.0, Color(0.08, 0.08, 0.1))
	draw_circle(Vector2(sx + half * 0.5, top + 6), 4.0, Color(0.08, 0.08, 0.1))
	for i in 4:
		draw_circle(Vector2(sx + half * 0.7 + i * 6.0, top - 16.0 - i * 10.0), 3.0,
			Color(0.85, 0.95, 1.0, 0.5))


func show_shark_stands(seconds: float = 12.0) -> void:
	_shark_stands_t = maxf(_shark_stands_t, seconds)
	_shark_stands_taunt_t = 0.0


func _tick_shark_stands(delta: float) -> void:
	if _shark_stands_t <= 0.0:
		return
	_shark_stands_t = maxf(_shark_stands_t - delta, 0.0)
	_shark_stands_taunt_t = maxf(_shark_stands_taunt_t - delta, 0.0)
	if _shark_stands_taunt_t <= 0.0:
		_shark_stands_taunt_t = 2.6


## 看台只是画面：没有判定、没有攻击、不改控制。
func _draw_shark_stands() -> void:
	var x: float = turtle.position.x
	var bob := sin(Time.get_ticks_msec() * 0.003) * 3.0
	_draw_pack_shark(Vector2(x + 250.0, 636.0 + bob), 0.85)
	_draw_pack_shark(Vector2(x + 80.0, 640.0 - bob), 0.62)
	_draw_pack_shark(Vector2(x - 110.0, 638.0 + bob), 0.70, true)
	# 挑衅/争吵气泡：纯表现，隔几秒换一个。
	var mark := "?" if int(Time.get_ticks_msec() / 1300) % 2 == 0 else "!"
	draw_circle(Vector2(x + 80.0, 584.0), 15.0, Color(0.05, 0.08, 0.10, 0.65))
	draw_string(ThemeDB.fallback_font, Vector2(x + 72.0, 592.0), mark,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.82, 0.35, 0.95))


func _draw_pack_shark(p: Vector2, s: float, fat: bool = false) -> void:
	# 侧视鲨鱼，不是“虾米”：尖吻在右、尾鳍在左、背鳍/胸鳍/鳃裂都画出来。
	var h := 30.0 if fat else 22.0
	var body_col := Color(0.34, 0.43, 0.50, 0.96)
	var belly_col := Color(0.62, 0.69, 0.72, 0.96)
	var fin_col := Color(0.27, 0.35, 0.42, 0.96)
	# 尾鳍
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-58, -2) * s, p + Vector2(-92, -26) * s,
		p + Vector2(-78, 0) * s, p + Vector2(-92, 24) * s,
	]), fin_col)
	# 身体：右端尖吻，背腹呈流线
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(70, 0) * s, p + Vector2(34, -h * 0.62) * s,
		p + Vector2(-20, -h * 0.58) * s, p + Vector2(-58, -2) * s,
		p + Vector2(-28, h * 0.58) * s, p + Vector2(30, h * 0.52) * s,
	]), body_col)
	# 白肚皮
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(56, 2) * s, p + Vector2(26, h * 0.48) * s,
		p + Vector2(-30, h * 0.52) * s, p + Vector2(-52, 2) * s,
	]), belly_col)
	# 背鳍
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(2, -h * 0.58) * s, p + Vector2(18, -h * 1.55) * s,
		p + Vector2(28, -h * 0.5) * s,
	]), fin_col)
	# 胸鳍
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(12, h * 0.38) * s, p + Vector2(2, h * 1.18) * s,
		p + Vector2(38, h * 0.30) * s,
	]), fin_col)
	# 眼 + 鳃裂 + 嘴线
	draw_circle(p + Vector2(45, -5) * s, 4.2 * s, Color(0.95, 0.96, 0.9))
	draw_circle(p + Vector2(46, -5) * s, 1.8 * s, Color(0.05, 0.07, 0.09))
	for i in 3:
		draw_line(p + Vector2(24 + i * 6, -h * 0.35) * s,
			p + Vector2(21 + i * 6, h * 0.28) * s,
			Color(0.20, 0.28, 0.34, 0.55), 1.2 * s)
	draw_line(p + Vector2(52, h * 0.12) * s, p + Vector2(67, h * 0.05) * s,
		Color(0.12, 0.16, 0.18, 0.8), 1.5 * s)
	if fat:
		draw_circle(p + Vector2(-4, h * 0.18) * s, 12.0 * s,
			Color(0.38, 0.46, 0.52, 0.95))


## FEEL-20 P0：行为选择改为“遭遇级”而不是固定实例名。
## 每个海鸟遭遇从合法序列中选一个；同一种子可复现；相邻遭遇不重复同一序列。
func _init_bird_behaviors() -> void:
	# FEEL-23：恢复特殊鸟攻击；海鸟本体/投射物共用同一套绘制与判定入口。
	# 第一只鸟仍是普通俯冲，之后最多 3 个特殊遭遇，避免全群变招。
	_bird_states.clear()
	_bird_attacks.clear()
	_bird_splashes.clear()
	_poop_sinks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level_seed) ^ 0x51A7
	# FEEL-46：海鸟先俯冲穿越到玩家左侧，再盘旋做第二段排泄；
	# 不再有“排泄先于俯冲”的队列，也不再考虑水弹。
	var pool := [
		["dive"], ["dive", "poop"], ["dive", "dive", "poop"],
	]
	var last_sig := ""
	var special_count := 0
	var first_bird := true
	for i in hazard_groups.size():
		var g: Dictionary = hazard_groups[i]
		if String(g.get("kind", "")) != "LOW_BIRD":
			continue
		var key := String(g["group"])
		if first_bird:
			first_bird = false
			_bird_states[key] = {"queue": ["dive"], "idx": 0, "mode": "dive",
				"phase": "WAIT", "t": 0.0, "target": "rabbit"}
			continue
		var seq: Array
		if special_count >= 3:
			seq = ["dive"]
		else:
			var tries := 0
			while true:
				seq = (pool[rng.randi_range(0, pool.size() - 1)] as Array).duplicate()
				var sig := "/".join(PackedStringArray(seq))
				if sig == last_sig and tries < 8:
					tries += 1
					continue
				if special_count < 3 and seq.size() == 1 and tries < 8:
					tries += 1
					continue
				break
			var final_sig := "/".join(PackedStringArray(seq))
			if final_sig == last_sig and final_sig != "dive":
				seq = ["dive"]
				final_sig = "dive"
			if seq.size() > 1 or String(seq[0]) != "dive":
				special_count += 1
			last_sig = final_sig
		_bird_states[key] = {"queue": seq, "idx": 0, "mode": String(seq[0]),
			"phase": "WAIT", "t": 0.0, "target": "rabbit"}


func _bird_group_offscreen(g: Dictionary) -> bool:
	if camera == null or g.is_empty():
		return false
	var band: Rect2 = g["rects"][0]
	var view_w: float = get_viewport_rect().size.x
	return band.position.x < camera.position.x - view_w * 0.55


func _clear_bird_attacks_for(key: String) -> void:
	for i in range(_bird_attacks.size() - 1, -1, -1):
		if String(_bird_attacks[i].get("group", "")) == key:
			_bird_attacks.remove_at(i)


func _tick_bird_behaviors(delta: float) -> void:
	if test_no_bird_behaviors:
		_bird_attacks.clear()
		return
	for g in hazard_groups:
		if String(g.get("kind", "")) != "LOW_BIRD":
			continue
		var key := String(g["group"])
		if not _bird_states.has(key):
			continue
		var st: Dictionary = _bird_states[key]
		var queue: Array = st["queue"]
		# 纯俯冲的遭遇不跑额外状态；仍使用原 bird_pose 和原碰撞带。
		if queue.size() == 1 and String(queue[0]) == "dive":
			continue
		var phase := String(st["phase"])
		var band: Rect2 = g["rects"][0]
		var d: float = band.position.x - turtle.position.x
		# 鸟组已经被镜头甩到身后：整组收工，别让投射物在屏幕外继续打。
		if _bird_group_offscreen(g):
			_clear_bird_attacks_for(key)
			st["phase"] = "DONE"
			continue
		st["t"] = float(st["t"]) + delta
		if phase == "WAIT":
			if d < 820.0 and d > -260.0:
				st["phase"] = "TELEGRAPH"
				st["t"] = 0.0
				# FEEL-30：攻击路线不锁定某个角色；报点只用于画预警。
				st["target"] = "any"
		elif phase == "TELEGRAPH":
			if float(st["t"]) >= BIRD_TELEGRAPH:
				st["phase"] = "ACTION"
				st["t"] = 0.0
				_spawn_bird_attack(g, st)
		elif phase == "ACTION":
			if float(st["t"]) >= BIRD_ACTION:
				st["phase"] = "RECOVER"
				st["t"] = 0.0
		elif phase == "RECOVER":
			if float(st["t"]) >= BIRD_RECOVER:
				var idx := int(st["idx"])
				if idx + 1 < queue.size():
					st["idx"] = idx + 1
					st["mode"] = String(queue[idx + 1])
					st["phase"] = "NEXT"
					st["t"] = 0.0
				else:
					st["phase"] = "DONE"
		elif phase == "NEXT":
			if float(st["t"]) >= 0.45:
				st["phase"] = "TELEGRAPH"
				st["t"] = 0.0


func _bird_target_pos(st: Dictionary) -> Vector2:
	if String(st["target"]) == "turtle":
		return turtle.position
	if String(st["target"]) == "any":
		return (rabbit.position + turtle.position) * 0.5
	return rabbit.position


func _spawn_bird_attack(g: Dictionary, st: Dictionary) -> void:
	# FEEL-29：同一时间只允许一个动态威胁；鲨群正在攻击时不叠加海鸟。
	if not _shark_attacks.is_empty():
		return
	# PHASE-FIX：鸟已经飞出屏幕，不再从画面外发射。
	if _bird_group_offscreen(g):
		return
	var band: Rect2 = g["rects"][0]
	var mode := String(st["mode"])
	if mode == "dive":
		return
	if mode == "poop":
		# FEEL-47：排泄不能再“锁定发射瞬间的兔子位置”。
		# 飞行约 1.25 s，必须按玩家前进速度做 lead；落点是一个区域，
		# 不直接命中也会在落点留下溅射，而不是飞到终点凭空消失。
		var flight := 1.25
		var lead_speed: float = maxf(turtle.speed, rabbit.velocity.x)
		# PHASE-FIX：便便最终打到水面，不再瞄兔子身体。
		var target := Vector2(rabbit.position.x + lead_speed * flight * 0.92
			+ randf_range(-18.0, 18.0), SURFACE_Y + 10.0)
		# FEEL-47：远程排泄不要叠在 BRO DIVE 的接人/下潜准备上。
		# 远程攻击只发生在没有紧邻地面障碍的开阔段，避免和 BRO DIVE/低梁叠拍。
		for lg in hazard_groups:
			if String(lg.get("kind", "")) == "LOW_BIRD":
				continue
			if absf(target.x - _group_start(lg)) < 700.0:
				return
		_bird_attacks.append({
			"type": "poop", "group": String(g["group"]),
			"p0": Vector2(band.position.x - 180.0, band.position.y - 150.0),
			"p1": target,
			"t": 0.0, "life": flight, "target": "rabbit",
			"splash_radius": 30.0,
		})
		GameManager.feedback.emit(Locale.t("feedback.bird_attack"), "hit")


func _circle_hits_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	# 圆形落点与角色身体框的最近点相交，而不是“角色中心在圈里”。
	# 这样兔子已经跑出圈、只剩尾巴擦边时不会继续按中心距离误判。
	var nearest := Vector2(
		clampf(center.x, rect.position.x, rect.end.x),
		clampf(center.y, rect.position.y, rect.end.y))
	return nearest.distance_to(center) <= radius


func _bird_attack_rect(a: Dictionary) -> Rect2:
	if String(a["type"]) == "poop":
		var k: float = clampf(float(a["t"]) / float(a["life"]), 0.0, 1.0)
		var p: Vector2 = (a["p0"] as Vector2).lerp(a["p1"] as Vector2, k)
		p.y += sin(k * PI) * 70.0
		return Rect2(p - Vector2(12, 12), Vector2(24, 24))
	return Rect2(float(a["x"]), float(a["y"]) - 20.0, 120.0, 44.0)


func _check_bird_attacks(delta: float) -> void:
	if test_disable_hazards or test_no_bird_behaviors:
		return
	for i in range(_bird_splashes.size() - 1, -1, -1):
		_bird_splashes[i]["t"] = float(_bird_splashes[i]["t"]) + delta
		if float(_bird_splashes[i]["t"]) >= float(_bird_splashes[i]["life"]):
			_bird_splashes.remove_at(i)
	for i in range(_poop_sinks.size() - 1, -1, -1):
		_poop_sinks[i]["t"] = float(_poop_sinks[i]["t"]) + delta
		if float(_poop_sinks[i]["t"]) >= float(_poop_sinks[i]["life"]):
			_poop_sinks.remove_at(i)
	# FEEL-22：救援优先。TUBO 落水/被接住期间，空中的鸟攻击不再判、也不留残影，
	# 避免恢复后凭空吃一下。
	if _rescue_context() != "NONE" or rabbit.state in ["FALLING_WATER", "PASSED_OUT"]:
		_bird_attacks.clear()
		return
	var r_rect := _inset(rabbit.get_body_rect(), 3.0)
	var t_rect := _inset(turtle.get_body_rect(), 3.0)
	for i in range(_bird_attacks.size() - 1, -1, -1):
		var a: Dictionary = _bird_attacks[i]
		var ga := _group_by_name(String(a.get("group", "")))
		if not ga.is_empty() and _bird_group_offscreen(ga):
			_bird_attacks.remove_at(i)
			continue
		a["t"] = float(a["t"]) + delta
		if String(a["type"]) == "body":
			a["x"] = float(a["x"]) + float(a["vx"]) * delta
		if float(a["t"]) >= float(a["life"]) - 0.001:
			# FEEL-47：排泄落地必定留下溅射；即使没有直接命中兔子，
			# 溅射圈仍然存在，不再是“飞到终点就消失”。
			if String(a["type"]) == "poop":
				var land: Vector2 = a["p1"]
				var radius: float = float(a.get("splash_radius", 44.0))
				_bird_splashes.append({"p": land, "t": 0.0, "life": 0.55})
				_poop_sinks.append({"p": land, "t": 0.0, "life": 0.6})
				if GameManager.accident_state == "NONE" \
						and _circle_hits_rect(land, radius,
							_inset(rabbit.get_body_rect(), 3.0)):
					if _mischief_role == "turtle" and _mischief_phase == "ACTION" 							and _mischief_fx_kind == "shock" 							and GameManager.current_control == "rabbit":
						GameManager.feedback.emit(Locale.t("mischief.arc_block"), "clean")
					else:
						_rabbit_contact("LOW_BIRD", true)
			_bird_attacks.remove_at(i)
			continue
		# 排泄只在落水时判；飞行中不再直接砸人。
		if String(a["type"]) == "poop":
			continue
		var rect := _bird_attack_rect(a)
		var target := String(a["target"])
		var hit := false
		if target in ["turtle", "any"] and GameManager.accident_state == "NONE" 				and t_rect.intersects(rect):
			# 失控 BITT 的电弧只在电击 ACTION 的短窗口内抵消远程投射物。
			if String(a["type"]) == "poop" and _mischief_role == "turtle" 					and _mischief_phase == "ACTION" and _mischief_fx_kind == "shock" 					and GameManager.current_control == "rabbit":
				GameManager.feedback.emit(Locale.t("mischief.arc_block"), "clean")
				_bird_attacks.remove_at(i)
				continue
			_turtle_contact("bird_" + String(a["group"]), "LOW_BIRD", true)
			hit = true
		elif target in ["rabbit", "any"] and GameManager.accident_state == "NONE" 				and r_rect.intersects(rect):
			if String(a["type"]) == "poop" and _mischief_role == "turtle" 					and _mischief_phase == "ACTION" and _mischief_fx_kind == "shock":
				GameManager.feedback.emit(Locale.t("mischief.arc_block"), "clean")
				_bird_attacks.remove_at(i)
				continue
			hit = _rabbit_contact("LOW_BIRD", true)
		if hit:
			if String(a["type"]) == "poop":
				# 排泄命中：在兔子位置留下一圈可见溅射，不额外写第二套惩罚。
				_bird_splashes.append({"p": rect.get_center(), "t": 0.0, "life": 0.55})
			_bird_attacks.remove_at(i)


func _draw_bird_attacks() -> void:
	for a in _bird_attacks:
		var rect := _bird_attack_rect(a)
		if String(a["type"]) == "poop":
			var p := rect.get_center()
			var target: Vector2 = a["p1"]
			var k: float = clampf(float(a["t"]) / maxf(float(a["life"]), 0.01), 0.0, 1.0)
			# 落点区域先出现，读作“东西要砸到这里”；半径就是实际溅射半径。
			var sr: float = float(a.get("splash_radius", 44.0))
			draw_circle(target, sr * 0.58, Color(0.12, 0.08, 0.04, 0.16))
			draw_arc(target, sr, 0.0, TAU, 28, Color(1.0, 0.35, 0.2, 0.6), 2.0)
			draw_line(target + Vector2(0, -38), target + Vector2(0, -12),
				Color(1.0, 0.45, 0.25, 0.45), 2.0)
			# 尾迹：从 p0 到 p1 的路径上留三团逐渐变小的棕色。
			var p0: Vector2 = a.get("p0", p)
			for i in 3:
				var q: Vector2 = p0.lerp(p, 0.35 + 0.2 * i + k * 0.15)
				draw_circle(q, (6.0 - i) * 0.8, Color(0.32, 0.20, 0.10, 0.25))
			# 旋转的螺旋/卷曲（懒羊羊发型那种卷），落水后停转下沉。
			var spin: float = float(a["t"]) * 16.0
			_draw_poop_coil(p, spin, 1.0)
	# 落水后的便便：停止旋转、下沉、淡出。
	for s in _poop_sinks:
		var k := clampf(float(s["t"]) / maxf(float(s["life"]), 0.01), 0.0, 1.0)
		var p: Vector2 = s["p"] + Vector2(0, 26.0 * k)
		_draw_poop_coil(p, 1.2, 1.0 - k, 1.0 - 0.25 * k)
		draw_arc(s["p"], 10.0 + 14.0 * k, 0.0, TAU, 20,
			Color(0.78, 0.70, 0.52, 0.45 * (1.0 - k)), 2.0)
	# 排泄命中溅射：棕色水滴 + 扩大的落点圈，读作“砸开了”。
	for s in _bird_splashes:
		var p: Vector2 = s["p"]
		var k := clampf(float(s["t"]) / maxf(float(s["life"]), 0.01), 0.0, 1.0)
		var r := 18.0 + 34.0 * k
		draw_arc(p, r, 0.0, TAU, 24,
			Color(0.72, 0.64, 0.48, 0.65 * (1.0 - k)), 3.0)
		for i in 6:
			var ang := TAU * float(i) / 6.0 + 0.4
			var q := p + Vector2(cos(ang), sin(ang)) * (12.0 + r * 0.45)
			draw_circle(q, 4.5 * (1.0 - k) + 1.0,
				Color(0.42, 0.28, 0.14, 0.8 * (1.0 - k)))
		draw_circle(p, 8.0 * (1.0 - k), Color(0.9, 0.82, 0.6, 0.45 * (1.0 - k)))


func _draw_poop_coil(p: Vector2, spin: float, alpha: float,
		scale: float = 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 26:
		var ang := spin + float(i) * 0.52
		var rr := (2.0 + float(i) * 0.42) * scale
		pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
	draw_polyline(pts, Color(0.34, 0.20, 0.09, 0.98 * alpha), 5.0 * scale, true)
	draw_circle(p, 3.5 * scale, Color(0.22, 0.13, 0.06, 0.95 * alpha))


func bird_pose(group: Dictionary, now_t: float = -1.0) -> Dictionary:
	var band: Rect2 = group["rects"][0]
	var strike_y := band.position.y + band.size.y * 0.55
	var high_y := strike_y - 240.0
	var d: float = band.position.x - turtle.position.x
	var t: float = now_t if now_t >= 0.0 else Time.get_ticks_msec() * 0.001
	var y := high_y
	var tilt := 0.0
	var phase := "CRUISE"
	var p := 0.0
	if d > 900.0:
		y = high_y + sin(t * 2.2) * 5.0
	elif d > 240.0:
		# 前摇：留在高空看着你，翅膀半收，给足判断时间（Z1 基速下 ~2.7 s）。
		p = clampf((900.0 - d) / 660.0, 0.0, 1.0)
		y = high_y + sin(t * 2.2) * 5.0
		phase = "TELEGRAPH"
	elif d > 0.0:
		# 俯冲：和玩家跨过这一列是同一段时间，所以没有“提前扎完”的空窗。
		p = clampf((240.0 - d) / 240.0, 0.0, 1.0)
		y = lerpf(high_y, strike_y, smoothstep(0.0, 1.0, p))
		tilt = -0.42 * sin(PI * p)
		phase = "DIVE"
	elif d > -520.0:
		# 第一段俯冲穿过后不停在最低点：继续向左前方拉起，再进入盘旋。
		var q := clampf((-d) / 520.0, 0.0, 1.0)
		y = lerpf(strike_y, high_y, smoothstep(0.0, 1.0, q))
		tilt = 0.34 * sin(PI * q)
		phase = "RECOVER"
	else:
		y = high_y + sin(t * 2.2) * 5.0
		phase = "CIRCLE"
	# 翅膀张开的程度：俯冲末段到攻击段完全展开，横着盖住主判定带。
	var flare := 0.0
	if phase == "DIVE":
		flare = smoothstep(0.55, 1.0, p)
	elif phase == "RECOVER":
		flare = 1.0 - clampf((-d) / 200.0, 0.0, 1.0)
	# 横向翼展：攻击段张开到盖住整条判定带（±2 px 内），这样“在带里被撞”
	# 一定伴随着看得见的翅膀，而不是一条比鸟宽的隐形带。
	return {
		"band": band, "d": d, "phase": phase, "y": y, "tilt": tilt,
		"strike_y": strike_y, "high_y": high_y, "flare": flare,
		"wing_top": lerpf(y - 20.0, band.position.y + 2.0, flare),
		"wing_bottom": lerpf(y + 16.0, band.end.y - 2.0, flare),
		"span_x": lerpf(34.0, band.size.x * 0.5 + 2.0, flare),
		"body_top": y - 14.0, "body_bottom": y + 10.0,
	}


func _draw_bird(group: Dictionary) -> void:
	var pose := bird_pose(group)
	var band: Rect2 = pose["band"]
	var d0: float = pose["d"]
	# 俯冲穿越后继续飞到玩家左侧，再盘旋；画法偏移，不改 group 判定。
	var fly_left := clampf(-d0, 0.0, 520.0) * 0.82
	var cx := band.position.x + band.size.x * 0.5 - fly_left
	var y: float = pose["y"]
	var strike_y: float = pose["strike_y"]
	var high_y: float = pose["high_y"]
	var d: float = pose["d"]
	var phase: String = pose["phase"]
	var flare: float = pose["flare"]
	var t := Time.get_ticks_msec() * 0.001
	if phase == "CIRCLE":
		# 盘旋：在玩家左侧高空绕小圈，第二段排泄从这里发出。
		cx += sin(t * 2.2) * 42.0
		y += cos(t * 2.2) * 10.0

	# 攻击轨迹：从右上方俯冲到壳顶，再向左上方拉起。淡线是方向与落点提示。
	if d > -520.0 and d < 1100.0:
		var path := PackedVector2Array()
		for i in 15:
			var q := float(i) / 14.0
			path.append(Vector2(cx + lerpf(300.0, -300.0, q),
				lerpf(high_y, strike_y + 6.0, sin(PI * q))))
		draw_polyline(path, Color(1.0, 1.0, 1.0, 0.13), 2.0)
	# 前摇：高位亮“！”，落点竖线一直拉到攻击带——站位与时机都从这里读。
	if phase == "TELEGRAPH":
		draw_string(ThemeDB.fallback_font, Vector2(cx + 38.0, y - 26.0), "!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.55, 0.3, 0.85))
		draw_line(Vector2(cx, y + 40.0), Vector2(cx, strike_y - 18.0),
			Color(1.0, 0.55, 0.3, 0.22), 2.0)
	if phase == "STRIKE":
		draw_arc(Vector2(cx, strike_y), 46.0, 0.15, PI - 0.15, 20,
			Color(1.0, 0.5, 0.32, 0.35), 3.0)

	var flap := sin(t * 6.0) * 12.0
	draw_set_transform(Vector2(cx, y), float(pose["tilt"]), Vector2.ONE)
	# 横扫：展开的两片翼膜从身体铺到判定带的上下沿与左右两端，
	# 覆盖范围就是 bird_pose() 的 wing_top/wing_bottom/span_x。
	# 巡航/前摇时翅膀扇动只影响高空姿态，不会碰到趴低层。
	var flutter: float = (1.0 - flare) * (8.0 + flap * 0.5)
	var up_tip: float = pose["wing_top"] - y - flutter
	var dn_tip: float = pose["wing_bottom"] - y + flutter
	var span: float = pose["span_x"]
	if flare > 0.15:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-span, up_tip), Vector2(span, up_tip), Vector2(2, -8),
		]), Color(0.88, 0.86, 0.8, 0.42))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-span, dn_tip), Vector2(span, dn_tip), Vector2(2, 6),
		]), Color(0.84, 0.82, 0.78, 0.42))
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, -8), Vector2(26, up_tip), Vector2(-16, -10),
	]), Color(0.82, 0.8, 0.76, 0.92))
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, 6), Vector2(26, dn_tip), Vector2(-16, 8),
	]), Color(0.78, 0.76, 0.72, 0.92))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-34, -6), Vector2(-4, -14), Vector2(34, -2),
		Vector2(30, 10), Vector2(-6, 8), Vector2(-34, 4),
	]), Color(0.92, 0.9, 0.84))
	draw_circle(Vector2(-30, -4), 11.0, Color(0.95, 0.93, 0.86))
	draw_circle(Vector2(-33, -7), 2.5, Color(0.12, 0.12, 0.16))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-40, -2), Vector2(-52, 2), Vector2(-40, 5),
	]), Color(1.0, 0.72, 0.28))
	# 尾迹朝后（向右）：鸟朝玩家飞来。
	for i in 3:
		var ty := -8.0 + i * 8.0
		draw_line(Vector2(40.0 + i * 6.0, ty), Vector2(58.0 + i * 6.0, ty),
			Color(1.0, 1.0, 1.0, 0.35), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## FEEL-10 P0-C：状态吊网。控制乌龟时绞盘把网拉高，兔子的站立层让开；
## 控制兔子时网停在原高度，必须趴低/下潜。判定框由 hazard_offset 同步搬动。
func _draw_state_net(group: Dictionary) -> void:
	var rect := hazard_rect_live(group, 0)
	var cx := rect.position.x + rect.size.x * 0.5
	var top := rect.position.y
	var bottom := rect.end.y
	var t := Time.get_ticks_msec() * 0.001
	# 屋顶绞盘与吊索：网被拉高时吊索变短，画面能读出“为什么这里能过”。
	var anchor := Vector2(cx, 26.0)
	draw_circle(anchor, 12.0, Color(0.3, 0.23, 0.15))
	draw_circle(anchor, 4.0, Color(0.12, 0.1, 0.08))
	for side in [-1.0, 1.0]:
		draw_line(anchor, Vector2(cx + side * rect.size.x * 0.42, top),
			Color(0.32, 0.26, 0.18), 3.0)
	# 网体 + 网眼 + 货箱。网眼必须真的透出后面的天/水，否则读成一块木板；
	# 只有“能看见网后面”才读得出它是被吊起来的网，而不是墙。
	var body := Rect2(rect.position.x, top, rect.size.x, bottom - top)
	draw_rect(body, Color(0.55, 0.5, 0.34, 0.28))
	draw_rect(body, Color(0.9, 0.8, 0.55, 0.9), false, 2.5)
	for i in 4:
		var yy := lerpf(top, bottom, float(i + 1) / 5.0)
		draw_line(Vector2(rect.position.x, yy), Vector2(rect.end.x, yy),
			Color(0.9, 0.8, 0.55, 0.55), 1.5)
	for i in 7:
		var fx := rect.position.x + i * rect.size.x / 6.0
		draw_line(Vector2(fx, top), Vector2(fx + 8.0, bottom),
			Color(0.9, 0.8, 0.55, 0.4), 1.5)
	# 斜向网绳：两族 45° 线，只在网体内部画，不越界。
	var drop := bottom - top
	for i in 8:
		var xa := rect.position.x + rect.size.x * float(i) / 7.0
		var ex := minf(xa + drop * 0.55, rect.end.x)
		var ey := top + (ex - xa)
		draw_line(Vector2(xa, top), Vector2(ex, ey),
			Color(0.9, 0.8, 0.55, 0.3), 1.0)
		var sx := maxf(xa - drop * 0.55, rect.position.x)
		var sy := top + (xa - sx)
		draw_line(Vector2(xa, top), Vector2(sx, sy),
			Color(0.9, 0.8, 0.55, 0.3), 1.0)
	var ch := maxf((bottom - top) * 0.45, 18.0)
	var cw := minf(rect.size.x * 1.1, 52.0)
	draw_rect(Rect2(cx - cw * 0.5, bottom - ch, cw, ch),
		Color(0.58, 0.4, 0.22, 0.95))
	draw_rect(Rect2(cx - cw * 0.5, bottom - ch, cw, ch),
		Color(0.34, 0.23, 0.13), false, 2.0)
	# 状态提示：网被绞盘拉起时，向上箭头 + 闪动；玩家能看出“换乌龟=网升起”。
	if _state_net_shift < -10.0:
		for i in 3:
			var q := fmod(t * 1.4 + i * 0.3, 1.0)
			draw_line(Vector2(cx - 18.0 + i * 18.0, bottom - 18.0 - q * 28.0),
				Vector2(cx - 18.0 + i * 18.0, bottom - 34.0 - q * 28.0),
				Color(0.55, 1.0, 0.9, 0.75 * (1.0 - q)), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(cx + rect.size.x * 0.5 + 8.0, top + 20.0),
			Locale.t("world.winch_up"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color(0.55, 1.0, 0.9, 0.95))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(cx + rect.size.x * 0.5 + 8.0, top + 20.0),
			Locale.t("world.net_low"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color(1.0, 0.78, 0.35, 0.95))
## 复用 bird_pose() 的节拍（900 px 外收在屋顶 → 240 px 内放下 → 网底压住
## 兔子层 → 拉回），所以判定框、俯冲空域、时机全都不变；变的只有画法。
## 运动来源画在屋顶绞盘上：两根吊索把网从梁下放下来。
func _draw_cargo_net(group: Dictionary) -> void:
	var pose := bird_pose(group)
	var band: Rect2 = pose["band"]
	var cx := band.position.x + band.size.x * 0.5
	var phase: String = pose["phase"]
	var flare: float = pose["flare"]
	var span: float = pose["span_x"]
	var top_y: float = pose["wing_top"]
	var bottom_y: float = pose["wing_bottom"]
	var t := Time.get_ticks_msec() * 0.001
	var sway := sin(t * 1.6) * (3.0 + flare * 3.0)
	cx += sway

	# 屋顶绞盘（画出“为什么它上下动”）。
	var anchor := Vector2(cx, 26.0)
	draw_circle(anchor, 12.0, Color(0.3, 0.23, 0.15))
	draw_circle(anchor, 4.5, Color(0.13, 0.11, 0.08))
	for i in 4:
		var a := i * PI * 0.5 + t * 0.8
		draw_line(anchor, anchor + Vector2(cos(a), sin(a)) * 10.0,
			Color(0.5, 0.4, 0.27), 2.0)
	# 两根吊索：上端在绞盘，下端在网杆两端。
	var bar_l := Vector2(cx - span * 0.86, top_y)
	var bar_r := Vector2(cx + span * 0.86, top_y)
	draw_line(anchor, bar_l, Color(0.33, 0.27, 0.19), 3.0)
	draw_line(anchor, bar_r, Color(0.33, 0.27, 0.19), 3.0)
	draw_line(bar_l, bar_r, Color(0.28, 0.22, 0.15), 5.0)
	# 网体：上沿是网杆，下沿就是判定带底沿——看得见的边就是撞得到的边。
	var net_pts := PackedVector2Array([
		bar_l, bar_r, Vector2(cx + span * 0.9, bottom_y),
		Vector2(cx + span * 0.4, bottom_y - 4.0),
		Vector2(cx, bottom_y),
		Vector2(cx - span * 0.4, bottom_y - 4.0),
		Vector2(cx - span * 0.9, bottom_y),
	])
	draw_colored_polygon(net_pts, Color(0.56, 0.5, 0.32, 0.92))
	# 网眼：斜线交叉，读作“渔网/货网”，不是一块板。
	var rows := 4 if flare < 0.5 else 5
	for i in rows:
		var q := float(i + 1) / float(rows + 1)
		var yy := lerpf(top_y, bottom_y, q)
		var half := lerpf(span * 0.86, span * 0.9, q)
		draw_line(Vector2(cx - half, yy), Vector2(cx + half, yy),
			Color(0.36, 0.31, 0.2, 0.7), 1.5)
	for i in 6:
		var fx := cx - span * 0.8 + i * span * 0.32
		draw_line(Vector2(fx, top_y), Vector2(fx + 10.0, bottom_y),
			Color(0.36, 0.31, 0.2, 0.55), 1.5)
	# 网底浮子：网真的在“垂着”，不是漂浮的矩形。
	for i in 5:
		draw_circle(Vector2(cx - span * 0.72 + i * span * 0.36, bottom_y + 1.0),
			3.6, Color(0.95, 0.62, 0.28, 0.95))
	# 前摇：网要放下来之前先亮“！”，落点竖线拉到攻击带。
	# 网收在屋顶时 top_y 几乎是负的，警告不能画在网顶——画在梁下可见处。
	if phase == "TELEGRAPH":
		draw_string(ThemeDB.fallback_font, Vector2(cx + span + 12.0, 96.0), "!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.55, 0.3, 0.95))
		draw_line(Vector2(cx, 70.0), Vector2(cx, pose["strike_y"] - 18.0),
			Color(1.0, 0.55, 0.3, 0.25), 2.0)
		draw_circle(anchor, 14.0 + sin(t * 9.0) * 2.0,
			Color(1.0, 0.55, 0.3, 0.35))
	if phase == "STRIKE":
		draw_arc(Vector2(cx, pose["strike_y"]), 46.0, 0.15, PI - 0.15, 20,
			Color(1.0, 0.5, 0.32, 0.35), 3.0)
	# 网里装的是货：一块小木箱，读作“货网”而不是一条布。
	var cw := minf(span * 1.2, 54.0)
	var ch := maxf((bottom_y - top_y) * 0.5, 18.0)
	var crate := Rect2(cx - cw * 0.5, bottom_y - ch, cw, ch)
	draw_rect(crate, Color(0.58, 0.4, 0.22, 0.95))
	draw_rect(crate, Color(0.34, 0.23, 0.13, 0.9), false, 2.0)
	draw_line(Vector2(crate.position.x + 4.0, crate.position.y + 4.0),
		Vector2(crate.end.x - 4.0, crate.end.y - 4.0),
		Color(0.42, 0.28, 0.14, 0.8), 2.0)
	# 网脚扬起的灰尘/木屑：读作“网底扫过这一带”。
	if flare > 0.6:
		for i in 3:
			var q := fmod(t * 0.9 + i * 0.33, 1.0)
			draw_circle(Vector2(cx - 30.0 + i * 30.0, bottom_y + q * 16.0), 2.5,
				Color(0.85, 0.72, 0.45, 0.5 * (1.0 - q)))


## REBUILD-05 E2：动态障碍的“行程线”。
## 目的不是装饰，是让玩家在 1100 px 外就能读出两件事：
##   1. 它会在哪一段范围里来回动（静止位置 + 两端）
##   2. 它现在走到哪了（游标点）
## 灰盒规则：全部是 Primitive（line/circle），可整段替换。
func _draw_motion_cue(group: Dictionary) -> void:
	if _pack_owns(String(group.get("group", ""))):
		return
	var motion: Dictionary = group.get("motion", {})
	if motion.is_empty():
		return
	var base: Rect2 = group["rects"][0]
	var amp := float(motion.get("amp", 0.0))
	var offset := hazard_offset(group)
	var faint := Color(1.0, 1.0, 1.0, 0.16)
	var hot := Color(1.0, 0.86, 0.42, 0.8)
	if _is_ambush(group):
		# 伏击鲨的行程是竖直线：水面位置 ↔ 深水位置，游标就是它此刻的框顶。
		var ax := base.position.x + base.size.x * 0.5
		var down_y: float = base.position.y + Tuning.SHARK_DOWN_OFFSET
		draw_line(Vector2(ax, base.position.y), Vector2(ax, down_y), faint, 2.0)
		for end_y in [base.position.y, down_y]:
			draw_line(Vector2(ax - 9.0, end_y), Vector2(ax + 9.0, end_y), faint, 2.0)
		draw_circle(Vector2(ax - 26.0, base.position.y + offset.y), 5.0, hot)
		return
	if String(motion.get("axis", "y")) == "x":
		var y := base.position.y + base.size.y * 0.5
		draw_line(Vector2(base.position.x - amp, y),
			Vector2(base.end.x + amp, y), faint, 2.0)
		for end_x in [base.position.x - amp, base.end.x + amp]:
			draw_line(Vector2(end_x, y - 9.0), Vector2(end_x, y + 9.0), faint, 2.0)
		draw_circle(Vector2(base.position.x + offset.x, y - 26.0), 5.0, hot)
	else:
		var x := base.position.x + base.size.x * 0.5
		draw_line(Vector2(x, base.position.y - amp),
			Vector2(x, base.end.y + amp), faint, 2.0)
		for end_y in [base.position.y - amp, base.end.y + amp]:
			draw_line(Vector2(x - 9.0, end_y), Vector2(x + 9.0, end_y), faint, 2.0)
		draw_circle(Vector2(x - 26.0, base.position.y + offset.y), 5.0, hot)


## CORE-FEEL-08 P1-C：SURFACE_ROCK 位的四种身份。
## 关卡数据和判定都没变（同一组矩形、同一组计时），变的只是“画出来是什么”，
## 以及底栏那句运动提示。这样玩家看到的是“浮标在浪里起落”“货箱挂在吊钩上晃”，
## 而不是“石头凭空上下飘”。
func _draw_rock_identity(rect: Rect2, identity: String, submerged: bool) -> void:
	match identity:
		"buoy":
			_draw_buoy(rect, submerged)
		"dock_crate":
			_draw_dock_crate(rect, submerged)
		"drift_crate":
			_draw_drift_crate(rect, submerged)
		"mooring_pontoon":
			_draw_mooring_pontoon(rect, submerged)
		_:
			_draw_plain_rock(rect, submerged)


func _draw_plain_rock(rect: Rect2, submerged: bool) -> void:
	var a := 0.45 if submerged else 1.0
	draw_rect(rect, Color(0.31, 0.3, 0.29, a))
	draw_circle(rect.position + Vector2(rect.size.x * 0.3, rect.size.y * 0.5),
		28.0, Color(0.38, 0.36, 0.34, a))
	draw_circle(rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.45),
		24.0, Color(0.35, 0.33, 0.31, a))
	if submerged:
		return
	draw_line(Vector2(rect.position.x, rect.end.y),
		Vector2(rect.end.x, rect.end.y), Color(0.13, 0.12, 0.11), 6.0)
	for i in 4:
		var fx := rect.position.x + 18.0 + i * 34.0
		draw_circle(Vector2(fx, rect.end.y + 4.0), 5.0,
			Color(0.7, 0.95, 1.0, 0.7))


## 浮起来的东西要有“浪”：水线本身是平的，所以浮标/货箱被顶到浪峰时
## 底下必须画一鼓浪，否则看起来像悬在空中。浪只是画，不参与判定。
func _draw_swell_hump(base: Rect2, tint: Color) -> void:
	var cx := base.position.x + base.size.x * 0.5
	var rise := clampf(SURFACE_Y - base.end.y, 0.0, 80.0)
	if rise <= 4.0:
		# 浪谷里：不画浪，只画一道水线，读作“它半沉在水里”。
		draw_line(Vector2(base.position.x - 8.0, SURFACE_Y),
			Vector2(base.end.x + 8.0, SURFACE_Y), Color(0.85, 0.97, 1.0, 0.55), 3.0)
		return
	var half := base.size.x * 0.5 + 46.0
	var pts := PackedVector2Array([
		Vector2(cx - half, SURFACE_Y + 26.0),
		Vector2(cx - half * 0.62, SURFACE_Y - rise * 0.55),
		Vector2(cx, SURFACE_Y - rise - 4.0),
		Vector2(cx + half * 0.62, SURFACE_Y - rise * 0.55),
		Vector2(cx + half, SURFACE_Y + 26.0),
	])
	draw_colored_polygon(pts, tint)


## Z1 系泊浮标：红白桶身 + 顶灯，锚绳垂到深水。
## 绳子的可见长度正好覆盖反下潜段——玩家不会觉得那段空域是凭空来的。
func _draw_buoy(rect: Rect2, submerged: bool) -> void:
	var cx := rect.position.x + rect.size.x * 0.5
	draw_line(Vector2(cx, rect.position.y + rect.size.y * 0.55),
		Vector2(cx, 780.0), Color(0.33, 0.28, 0.21, 0.45 if submerged else 0.85),
		3.0 if submerged else 4.0)
	if submerged:
		# 水下的绳结配重：读作“绳子从这里过”，不是第二块石头。
		draw_circle(Vector2(cx, rect.end.y - 12.0), 8.0,
			Color(0.3, 0.26, 0.2, 0.5))
		return
	_draw_swell_hump(rect, Color(0.42, 0.72, 0.86, 0.5))
	draw_rect(rect, Color(0.82, 0.26, 0.22))
	draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * 0.44,
		rect.size.x, rect.size.y * 0.28), Color(0.94, 0.91, 0.85))
	draw_line(Vector2(rect.position.x + 3.0, rect.end.y),
		Vector2(rect.end.x - 3.0, rect.end.y), Color(0.46, 0.12, 0.1), 4.0)
	# 顶上的小桅杆和灯：让它在浪里有明确的“上面”。
	draw_line(Vector2(cx, rect.position.y), Vector2(cx, rect.position.y - 34.0),
		Color(0.3, 0.26, 0.2), 3.0)
	draw_circle(Vector2(cx, rect.position.y - 40.0), 5.0, Color(1.0, 0.86, 0.36))
	for i in 3:
		draw_circle(Vector2(rect.position.x + rect.size.x * (0.2 + 0.3 * i),
			rect.end.y + 3.0), 4.5, Color(0.75, 0.95, 1.0, 0.65))


## Z2 吊装货箱：吊索收在滑轮上、再通到上方，箱体随吊臂上下。
## “为什么会上下动”就写在吊索上——这是最能解释运动的画法。
func _draw_dock_crate(rect: Rect2, submerged: bool) -> void:
	var cx := rect.position.x + rect.size.x * 0.5
	if submerged:
		draw_rect(Rect2(rect.position.x + 8.0, rect.position.y + 4.0,
			rect.size.x - 16.0, rect.size.y - 8.0), Color(0.34, 0.23, 0.13, 0.4))
		draw_line(Vector2(cx, rect.position.y - 46.0), Vector2(cx, rect.position.y + 4.0),
			Color(0.3, 0.26, 0.2, 0.4), 3.0)
		return
	var pivot := Vector2(cx, rect.position.y - 92.0)
	draw_line(Vector2(cx, pivot.y), Vector2(cx, 18.0), Color(0.28, 0.24, 0.18), 4.0)
	draw_line(Vector2(rect.position.x + 12.0, rect.position.y), pivot,
		Color(0.28, 0.24, 0.18), 3.0)
	draw_line(Vector2(rect.end.x - 12.0, rect.position.y), pivot,
		Color(0.28, 0.24, 0.18), 3.0)
	draw_circle(pivot, 9.0, Color(0.42, 0.35, 0.24))
	draw_circle(pivot, 4.0, Color(0.16, 0.14, 0.11))
	draw_rect(rect, Color(0.66, 0.45, 0.24))
	draw_rect(rect, Color(0.38, 0.25, 0.13), false, 4.0)
	for i in 3:
		var px := rect.position.x + rect.size.x * (0.25 + 0.25 * i)
		draw_line(Vector2(px, rect.position.y + 4.0), Vector2(px, rect.end.y - 4.0),
			Color(0.48, 0.32, 0.17, 0.8), 2.0)
	draw_circle(Vector2(cx, rect.position.y - 4.0), 5.0, Color(0.2, 0.2, 0.22))


## Z3 漂流货箱：从码头冲出去的箱子，半沉半浮，浪花拍在箱侧。
func _draw_drift_crate(rect: Rect2, submerged: bool) -> void:
	var a := 0.4 if submerged else 1.0
	draw_rect(Rect2(rect.position.x + 8.0, rect.position.y + 2.0,
		rect.size.x - 16.0, rect.size.y - 4.0), Color(0.58, 0.4, 0.22, a))
	for k in [0.18, 0.7]:
		draw_rect(Rect2(rect.position.x + rect.size.x * k, rect.position.y + 2.0,
			10.0, rect.size.y - 4.0), Color(0.42, 0.28, 0.14, a))
	if submerged:
		return
	_draw_swell_hump(rect, Color(0.42, 0.72, 0.86, 0.45))
	for i in 4:
		var fx := rect.position.x + 10.0 + i * (rect.size.x - 20.0) / 3.0
		draw_circle(Vector2(fx, rect.end.y + 3.0), 4.5, Color(0.75, 0.95, 1.0, 0.7))
	draw_circle(Vector2(rect.position.x - 9.0, rect.position.y + 14.0), 6.0,
		Color(0.8, 0.97, 1.0, 0.45))
	draw_circle(Vector2(rect.end.x + 7.0, rect.position.y + 22.0), 5.0,
		Color(0.8, 0.97, 1.0, 0.4))


## FEEL-09 P0-A：Z2 的静止礁石改成系泊浮台。
## 判定仍是同一个矩形（跳过去；水下那段是反下潜段），画成码头浮台后
## 水下那段有锚链可看，不再是一块“凭空出现的礁石”。
func _draw_mooring_pontoon(rect: Rect2, submerged: bool) -> void:
	var cx := rect.position.x + rect.size.x * 0.5
	if submerged:
		# 反下潜段：浮台底下的锚链与配重，半透明，画在深水里。
		draw_line(Vector2(cx, SURFACE_Y), Vector2(cx, rect.end.y - 10.0),
			Color(0.3, 0.28, 0.22, 0.5), 3.0)
		for i in 3:
			var yy := lerpf(SURFACE_Y, rect.end.y - 10.0, float(i) / 3.0)
			draw_circle(Vector2(cx, yy), 4.5, Color(0.4, 0.36, 0.28, 0.45))
		draw_rect(Rect2(cx - 18.0, rect.end.y - 22.0, 36.0, 20.0),
			Color(0.34, 0.3, 0.24, 0.45))
		return
	# 浮台主体：木板 + 侧沿，上面钉着系缆桩。
	draw_rect(rect, Color(0.62, 0.44, 0.25))
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 8.0),
		Color(0.45, 0.31, 0.17))
	for i in 5:
		var px := rect.position.x + 8.0 + i * (rect.size.x - 16.0) / 4.0
		draw_line(Vector2(px, rect.position.y + 8.0), Vector2(px, rect.end.y - 4.0),
			Color(0.42, 0.29, 0.16, 0.8), 2.0)
	draw_line(Vector2(rect.position.x + 3.0, rect.end.y),
		Vector2(rect.end.x - 3.0, rect.end.y), Color(0.3, 0.21, 0.12), 5.0)
	# 浮筒：水面下两排木桶，读作“它浮着”。
	for i in 3:
		var bx := rect.position.x + rect.size.x * (0.2 + 0.3 * i)
		draw_circle(Vector2(bx, rect.end.y + 16.0), 13.0, Color(0.5, 0.34, 0.18, 0.9))
		draw_line(Vector2(bx - 10.0, rect.end.y + 16.0),
			Vector2(bx + 10.0, rect.end.y + 16.0), Color(0.3, 0.2, 0.11), 2.0)
	# 系缆桩 + 绳：这是“系泊”两个字的可见来源。
	var post := Vector2(rect.end.x - 14.0, rect.position.y - 16.0)
	draw_rect(Rect2(post.x - 5.0, post.y, 10.0, 20.0), Color(0.26, 0.2, 0.14))
	draw_circle(Vector2(post.x, post.y), 7.0, Color(0.32, 0.25, 0.17))
	draw_line(post + Vector2(0.0, 2.0), Vector2(rect.end.x + 60.0, rect.position.y + 34.0),
		Color(0.72, 0.62, 0.42, 0.9), 3.0)
	# 水面拍在浮台边上的白沫。
	for i in 4:
		draw_circle(Vector2(rect.position.x + 10.0 + i * (rect.size.x - 20.0) / 3.0,
			SURFACE_Y - 4.0), 4.0, Color(0.82, 0.97, 1.0, 0.5))


## FEEL-09 P0-A：室内水渠鳗鱼。
## 行为与礁鲨共用 ambush_shark 状态机：盘在水渠底 → 靠近时预警 → 窜上水面
## → 退回深水。判定框仍是整条纵向矩形，所以“下潜躲不开、必须乌龟跃起”
## 这条规则不变；画法改成细长带鳍的鳗鱼 + 电火花预警。
func _draw_canal_eel(group: Dictionary, rect: Rect2) -> void:
	var sx := rect.position.x + rect.size.x * 0.5
	var top := rect.position.y
	var bot := rect.end.y
	var t := Time.get_ticks_msec() * 0.001
	var body := Color(0.2, 0.36, 0.27)
	var belly := Color(0.34, 0.52, 0.36)
	var fin := Color(0.16, 0.3, 0.24)
	var st := hazard_motion_state(group)
	var phase := String(st.get("phase", "DOWN"))
	var st_t := float(st.get("t", 0.0))
	# 身体：从判定框底一路扭到框顶，宽度略窄于鲨鱼，但占满纵向——
	# 玩家看到的“鱼身在这里”就是“下潜也躲不开”的那条带。
	var pts := PackedVector2Array()
	for i in 13:
		var q := float(i) / 12.0
		pts.append(Vector2(sx + sin(q * 6.0 + t * 2.4) * 9.0,
			lerpf(bot - 4.0, top + 38.0, q)))
	draw_polyline(pts, body, 20.0)
	draw_polyline(pts, belly, 11.0)
	draw_polyline(pts, Color(0.55, 0.78, 0.5, 0.8), 3.0)
	# 背鳍/侧鳍：沿身体的锯齿，和海鸥/鲨鱼都不同。
	for i in range(1, 12, 2):
		var q := float(i) / 12.0
		var p := Vector2(sx + sin(q * 6.0 + t * 2.4) * 9.0,
			lerpf(bot - 4.0, top + 38.0, q))
		var side := 1.0 if i % 4 == 1 else -1.0
		draw_colored_polygon(PackedVector2Array([
			p, p + Vector2(side * 16.0, -10.0), p + Vector2(0.0, 10.0),
		]), fin)
	# 尾鳍（深端）。
	draw_colored_polygon(PackedVector2Array([
		Vector2(sx - 8.0, bot - 8.0), Vector2(sx - 26.0, bot + 6.0),
		Vector2(sx, bot - 22.0), Vector2(sx + 26.0, bot + 6.0),
		Vector2(sx + 8.0, bot - 8.0),
	]), fin)
	# 头：框顶就是头顶，嘴朝上（伏击方向）。
	var hy := top + 22.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(sx - 16.0, hy + 20.0), Vector2(sx - 11.0, hy - 4.0),
		Vector2(sx, hy - 12.0), Vector2(sx + 11.0, hy - 4.0),
		Vector2(sx + 16.0, hy + 20.0),
	]), body)
	draw_circle(Vector2(sx - 8.0, hy + 2.0), 3.0, Color(1.0, 0.86, 0.35))
	draw_circle(Vector2(sx + 8.0, hy + 2.0), 3.0, Color(1.0, 0.86, 0.35))
	# 张嘴：只有冲到水面（LUNGE）才露牙；下方状态嘴是闭的。
	if phase == "LUNGE":
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx - 10.0, hy - 10.0), Vector2(sx + 10.0, hy - 10.0),
			Vector2(sx, hy + 4.0),
		]), Color(0.55, 0.1, 0.12))
		for i in 4:
			draw_colored_polygon(PackedVector2Array([
				Vector2(sx - 8.0 + i * 5.0, hy - 10.0),
				Vector2(sx - 6.0 + i * 5.0, hy - 3.0),
				Vector2(sx - 4.0 + i * 5.0, hy - 10.0),
			]), Color(0.95, 0.95, 0.9))
	# 电火花预警：鳗鱼不靠鳍，靠“水里有电”提前告诉你。
	if phase == "TELEGRAPH":
		for i in 3:
			var y0 := SURFACE_Y - 6.0 + i * 10.0
			var arc := PackedVector2Array()
			for k in 6:
				var q := float(k) / 5.0
				arc.append(Vector2(sx - 26.0 + q * 52.0,
					y0 + sin(q * 14.0 + st_t * 20.0) * 5.0))
			draw_polyline(arc, Color(1.0, 0.9, 0.35, 0.85), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(sx + 32.0, SURFACE_Y - 34.0), "!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.75, 0.2, 0.95))
	# 深水状态：缓慢上浮的泡泡，读作“它盘在这里”。
	if phase == "DOWN" or phase == "RETREAT":
		for i in 3:
			var bt := fmod(st_t * 1.1 + i * 0.33, 1.0)
			draw_circle(Vector2(sx + 8.0 + i * 9.0,
				rect.position.y - 12.0 - bt * 60.0), 3.0,
				Color(0.8, 0.94, 1.0, 0.4 * (1.0 - bt)))


## FEEL-09 P0-A：室内船闸。木质闸板从上方码头结构吊下来，底部留出下潜通道；
## 两侧导轨、铁箍、绞盘都画出来，回答“为什么这里必须往下钻”。
func _draw_sluice_gate(rect: Rect2) -> void:
	var cx := rect.position.x + rect.size.x * 0.5
	# 吊链：从上方结构到闸板顶，证明闸板不是浮空的。
	for sx_off in [-rect.size.x * 0.32, rect.size.x * 0.32]:
		var x: float = cx + float(sx_off)
		draw_line(Vector2(x, 20.0), Vector2(x, rect.position.y + 6.0),
			Color(0.3, 0.26, 0.2, 0.9), 3.0)
		for i in 6:
			var yy := lerpf(20.0, rect.position.y + 6.0, float(i) / 6.0)
			draw_circle(Vector2(x, yy), 2.4, Color(0.45, 0.4, 0.3, 0.8))
	# 闸板：竖木板 + 两道铁箍 + 斜撑。
	draw_rect(rect, Color(0.44, 0.31, 0.18))
	for i in 5:
		var px := rect.position.x + 6.0 + i * (rect.size.x - 12.0) / 4.0
		draw_line(Vector2(px, rect.position.y + 4.0), Vector2(px, rect.end.y - 4.0),
			Color(0.34, 0.23, 0.13, 0.9), 2.0)
	for band_y in [rect.position.y + 44.0, rect.end.y - 52.0]:
		draw_line(Vector2(rect.position.x + 2.0, band_y),
			Vector2(rect.end.x - 2.0, band_y), Color(0.24, 0.24, 0.26), 6.0)
		for i in 4:
			draw_circle(Vector2(rect.position.x + 14.0 + i * (rect.size.x - 28.0) / 3.0,
				band_y), 2.2, Color(0.62, 0.62, 0.66))
	draw_line(rect.position + Vector2(10.0, 10.0),
		rect.position + Vector2(rect.size.x - 10.0, rect.size.y - 10.0),
		Color(0.36, 0.25, 0.14, 0.8), 4.0)
	# 顶部绞盘：闸板靠它升降。
	var wheel := Vector2(cx, rect.position.y - 12.0)
	draw_circle(wheel, 13.0, Color(0.3, 0.26, 0.2))
	draw_circle(wheel, 4.0, Color(0.14, 0.12, 0.1))
	for i in 4:
		var a := i * PI * 0.5
		draw_line(wheel, wheel + Vector2(cos(a), sin(a)) * 11.0,
			Color(0.5, 0.42, 0.3), 2.0)
	# 底沿：明确的安全线 + 水流从门下穿过。
	draw_line(Vector2(rect.position.x - 10.0, rect.end.y),
		Vector2(rect.end.x + 10.0, rect.end.y), Color(0.13, 0.11, 0.1), 9.0)
	draw_line(Vector2(rect.position.x - 10.0, rect.end.y + 4.0),
		Vector2(rect.end.x + 10.0, rect.end.y + 4.0), Color(0.55, 0.92, 0.98, 0.7), 3.0)
	for i in 5:
		var fx := rect.position.x + 14.0 + i * (rect.size.x - 28.0) / 4.0
		draw_line(Vector2(fx, rect.end.y + 10.0), Vector2(fx - 8.0, rect.end.y + 26.0),
			Color(0.6, 0.94, 1.0, 0.4), 2.0)
	# 水线：闸板一半在水上、一半在水下。
	if SURFACE_Y > rect.position.y and SURFACE_Y < rect.end.y:
		draw_line(Vector2(rect.position.x, SURFACE_Y),
			Vector2(rect.end.x, SURFACE_Y), Color(0.62, 0.95, 1.0, 0.8), 3.0)
		for i in 4:
			var wx := rect.position.x + 10.0 + i * (rect.size.x - 20.0) / 3.0
			draw_circle(Vector2(wx, SURFACE_Y + 4.0), 3.0, Color(0.85, 0.98, 1.0, 0.6))


## FEEL-29：BRO DIVE 失败后只摧毁当前这一组浮木，不重置、不直接放行。
func _destroy_floating_log(group: Dictionary, key: String) -> void:
	if destroyed_groups.has(key):
		return
	destroyed_groups[key] = true
	hit_groups[key] = true
	passed_groups[key] = true
	combo = 0
	GameManager.combo = 0
	_trigger_shake(true)
	GameManager.feedback.emit(Locale.t("feedback.log_smash"), "hit")


func _draw_broken_log(group: Dictionary) -> void:
	var rect := hazard_rect_live(group, 0)
	var y := surface_ref() + 6.0
	draw_rect(Rect2(rect.position.x - 34.0, y, rect.size.x * 0.38, 18.0),
		Color(0.36, 0.24, 0.14))
	draw_rect(Rect2(rect.end.x - rect.size.x * 0.30, y + 4.0,
		rect.size.x * 0.30, 16.0), Color(0.30, 0.20, 0.12))
	for i in 3:
		draw_circle(Vector2(rect.position.x + rect.size.x * (0.2 + i * 0.3), y + 30.0 + i * 8.0),
			4.0 - i, Color(0.65, 0.9, 1.0, 0.45))


func _draw_hazard(group: Dictionary, index: int) -> void:
	var kind: String = group["kind"]
	# shark6 由 _draw_shark_pack_fx 的同一只实体鱼绘制。
	if _pack_owns(String(group["group"])):
		return
	if destroyed_groups.has(String(group["group"])):
		if index == 0:
			_draw_broken_log(group)
		return
	# REBUILD-05 E2：画的就是判的那一个矩形（同一个 hazard_rect_live）。
	var rect := hazard_rect_live(group, index)
	if kind == "LOW_BIRD":
		# 海鸟是唯一一个“按距离改变姿态”的障碍：只画一次，用 rect[0] 主带定位。
		if index == 0:
			# FEEL-09 P0-A：Z2 是室内码头，同一套俯冲节拍改成屋顶吊网
			# （绞盘放网→网底压下来→收回），判定框与俯冲空域完全不变。
			var id := String(group.get("identity", ""))
			if id == "state_net":
				_draw_state_net(group)
			elif id == "cargo_net":
				_draw_cargo_net(group)
			else:
				# FEEL-23：特殊攻击的 ACTION 由攻击体本身绘制，避免同屏两只鸟。
				var bst: Dictionary = _bird_states.get(String(group["group"]), {})
				if bst.is_empty() or String(bst.get("mode", "dive")) == "dive" 						or String(bst.get("phase", "")) != "ACTION":
					_draw_bird(group)
				if not bst.is_empty() and String(bst.get("phase", "")) == "TELEGRAPH" 						and String(bst.get("mode", "dive")) != "dive":
					var bp: Vector2 = _bird_target_pos(bst)
					var bc: Vector2 = Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - 16.0)
					draw_line(bc, bp + Vector2(0, -18), Color(1.0, 0.55, 0.25, 0.65), 2.0)
					draw_arc(bp + Vector2(0, -18), 22.0 + sin(Time.get_ticks_msec() * 0.01) * 3.0,
						0.0, TAU, 20, Color(1.0, 0.45, 0.25, 0.8), 3.0)
					draw_string(ThemeDB.fallback_font, bp + Vector2(-6, -96), "!",
						HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.55, 0.25, 0.95))
		return
	match kind:
		"SURFACE_ROCK":
			# CORE-FEEL-08 P1-C：岩位按身份画——浮标 / 吊装货箱 / 漂流货箱。
			# 判定框仍是 hazard_rect_live 那一个矩形；index>0 是反下潜段，
			# 画成同一件东西的水下部分，玩家能看出“这块空域为什么不能钻”。
			_draw_rock_identity(rect, String(group.get("identity", "sea_rock")), index > 0)
		"LOW_BEAM":
			# 码头低梁：两根立柱扎到海底，横梁从上面压下来。
			# 不是“凭空悬在海面上的杆”——支撑关系必须看得见。
			var post_l := rect.position.x + 10.0
			var post_r := rect.end.x - 10.0
			draw_rect(Rect2(post_l - 7, rect.end.y, 14, 820.0 - rect.end.y),
				Color(0.34, 0.28, 0.2))
			draw_rect(Rect2(post_r - 7, rect.end.y, 14, 820.0 - rect.end.y),
				Color(0.34, 0.28, 0.2))
			draw_rect(rect, Color(0.42, 0.33, 0.22))
			draw_rect(Rect2(rect.position.x, rect.end.y - 12, rect.size.x, 12),
				Color(0.24, 0.18, 0.12))
			# 木头纹理，读作“码头木板”而不是海草。
			for i in 5:
				var by := rect.position.y + 18.0 + i * 16.0
				draw_line(Vector2(rect.position.x + 6, by), Vector2(rect.end.x - 6, by),
					Color(0.33, 0.25, 0.16, 0.7), 2.0)
		"LOW_BIRD":
			# 由 _draw_bird 单独画（要按距离播下潜轨迹），这里不会走到。
			pass
		"SHARK":
			# FEEL-09 P0-A：Z2 的鲨鱼改成水渠鳗鱼——同样的水下伏击节拍、
			# 同样占满整条判定框（下潜躲不开），但它是室内水渠里该有的东西。
			if String(group.get("identity", "")) == "canal_eel":
				_draw_canal_eel(group, rect)
				return
			# 鲨鱼整条从深水冲上来：判定框就是从头到尾的整条身体，
			# 画法必须占满 rect 的纵向——“下潜也躲不开”才看得懂。
			var sx := rect.position.x + rect.size.x * 0.5
			var top := rect.position.y
			var bot := rect.end.y
			var body_col := Color(0.42, 0.5, 0.58)
			var fin_col := Color(0.36, 0.44, 0.52)
			# 尾鳍（深端）
			draw_colored_polygon(PackedVector2Array([
				Vector2(sx - 12, bot - 40), Vector2(sx - 30, bot - 2),
				Vector2(sx, bot - 20), Vector2(sx + 30, bot - 2),
				Vector2(sx + 12, bot - 40),
			]), fin_col)
			# 身体：头宽、腰收、尾窄。
			# Phase H：头的上沿从 top+34 提到 top+4，贴住判定框上沿。
			# 旧画法让眼睛/嘴浮在框外的 34 px 空白带里，玩家会以为“身体还差一截”，
			# 读不准安全余量；现在框的上沿就是鱼头顶，画的和判的是同一条线。
			draw_colored_polygon(PackedVector2Array([
				Vector2(sx - 30, top + 4), Vector2(sx + 32, top + 4),
				Vector2(sx + 22, top + 96), Vector2(sx + 10, bot - 46),
				Vector2(sx - 10, bot - 46), Vector2(sx - 22, top + 96),
			]), body_col)
			# 背鳍 + 胸鳍
			draw_colored_polygon(PackedVector2Array([
				Vector2(sx - 22, top + 96), Vector2(sx - 52, top + 142),
				Vector2(sx - 18, top + 148),
			]), fin_col)
			draw_colored_polygon(PackedVector2Array([
				Vector2(sx + 20, top + 120), Vector2(sx + 46, top + 150),
				Vector2(sx + 16, top + 154),
			]), fin_col)
			# 嘴和牙：读作“张嘴冲上来”
			draw_rect(Rect2(sx - 26, top + 16, 52, 10), Color(0.9, 0.9, 0.88))
			for i in 6:
				var tx := sx - 24.0 + i * 9.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(tx, top + 26), Vector2(tx + 4, top + 33),
					Vector2(tx + 8, top + 26),
				]), Color(0.95, 0.95, 0.92))
			draw_circle(Vector2(sx - 16, top + 6), 4.0, Color(0.08, 0.08, 0.1))
			draw_circle(Vector2(sx + 18, top + 6), 4.0, Color(0.08, 0.08, 0.1))
			# 上冲气泡
			for i in 4:
				var bx := sx + 26.0 + i * 6.0
				draw_circle(Vector2(bx, top - 16.0 - i * 10.0), 3.0,
					Color(0.85, 0.95, 1.0, 0.5))
			# REBUILD-06 P3：伏击鲨的三个可读状态。
			#   DOWN：深水里露着整条鱼 + 缓慢上浮的泡泡（“它在这里等”）；
			#   TELEGRAPH：水面鳍 + 上浮泡泡 + “!” 三处同时亮（≥2 种信号），
			#              鱼身仍在深水，不碰任何可达深度；
			#   LUNGE：水面上的鱼张嘴上冲（身体就是判定框）。
			if _is_ambush(group):
				var st := hazard_motion_state(group)
				var phase := String(st.get("phase", "DOWN"))
				var st_t := float(st.get("t", 0.0))
				if phase == "TELEGRAPH":
					var wob := sin(st_t * 18.0) * 4.0
					draw_colored_polygon(PackedVector2Array([
						Vector2(sx - 26 + wob, SURFACE_Y + 4),
						Vector2(sx + 2 + wob, SURFACE_Y - 30),
						Vector2(sx + 30 + wob, SURFACE_Y + 4),
					]), Color(0.3, 0.38, 0.46, 0.92))
					for i in 4:
						var bt := fmod(st_t * 2.2 + i * 0.25, 1.0)
						draw_circle(Vector2(sx - 21 + i * 14,
							SURFACE_Y + 44.0 - bt * 44.0), 3.5,
							Color(0.85, 0.96, 1.0, 0.7 * (1.0 - bt)))
					draw_string(ThemeDB.fallback_font, Vector2(sx + 32.0, SURFACE_Y - 34.0),
						"!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
						Color(1.0, 0.55, 0.2, 0.95))
				elif phase == "DOWN" or phase == "RETREAT":
					for i in 3:
						var bt := fmod(st_t * 1.1 + i * 0.33, 1.0)
						draw_circle(Vector2(sx + 8 + i * 9,
							rect.position.y - 12.0 - bt * 60.0), 3.0,
							Color(0.8, 0.94, 1.0, 0.4 * (1.0 - bt)))
		"DIVE_GATE":
			# FEEL-09 P0-A：Z2 的礁拱改成木质船闸——闸板从上方的码头结构吊下来，
			# 底部留出下潜通道；气泡方向不变，仍然是“往下走”。
			if String(group.get("identity", "")) == "sluice_gate":
				_draw_sluice_gate(rect)
				pass
			else:
				# 水下拱岩：从水面上方横压下来，底沿要画清楚，下面留出安全通道。
				draw_rect(rect, Color(0.3, 0.29, 0.3, 0.95))
				draw_circle(rect.position + Vector2(rect.size.x * 0.25, 20.0), 34.0,
					Color(0.36, 0.34, 0.35))
				draw_circle(rect.position + Vector2(rect.size.x * 0.7, 34.0), 30.0,
					Color(0.33, 0.32, 0.33))
				draw_line(Vector2(rect.position.x, rect.end.y),
					Vector2(rect.end.x, rect.end.y), Color(0.14, 0.13, 0.16), 8.0)
				# 底沿的海草：暗示“这里要往下钻”。
				for i in 6:
					var gx := rect.position.x + 10.0 + i * (rect.size.x - 20.0) / 5.0
					draw_line(Vector2(gx, rect.end.y), Vector2(gx + sin(i * 2.1) * 10.0,
						rect.end.y + 34.0), Color(0.18, 0.4, 0.26), 5.0)
			# 下方通道：两列向上气泡，方向就是“往下走”。
			for i in 5:
				var t := fmod(Time.get_ticks_msec() * 0.0006 + i * 0.2, 1.0)
				draw_circle(Vector2(rect.position.x + 30.0 + i * 30.0,
					rect.end.y + 96.0 - t * 70.0), 3.5,
					Color(0.8, 0.95, 1.0, 0.4 * (1.0 - t)))
		"FLOATING_LOG":
			# 巨型浮木：水上一段木头，水下那段用更深的颜色 + 亮描边单独标出来。
			# 组合障碍必须能看出“上面挡兔子、下面挡乌龟”。
			var lx := rect.position.x
			var lw := rect.size.x
			# REBUILD-05 E2 涨落浮木：局部浪涌线跟着浮木上下，读作“这片水在变”。
			# 浪高 → 下水道更浅、上沿更高；浪低 → 相反。两条路都在，选哪条要读浪。
			if not group.get("motion", {}).is_empty():
				# 冲浪板模型的水线是 surface_ref()（=334），不是旧常量 300；
				# 用 300 画浪线/水下段会整体高出真实水面 34 px。
				var swell_y := surface_ref() + hazard_offset(group).y
				var swell := PackedVector2Array()
				for i in 17:
					var px := lx - 150.0 + i * (lw + 300.0) / 16.0
					swell.append(Vector2(px,
						swell_y + sin(px * 0.045 + hazard_clock * 2.4) * 5.0))
				draw_polyline(swell, Color(0.75, 0.96, 1.0, 0.55), 3.0)
				draw_line(Vector2(lx, swell_y), Vector2(lx + lw, swell_y),
					Color(0.75, 0.96, 1.0, 0.5), 2.0)
				# FEEL-10 P0-C：强水流段画出方向与相位，玩家据此选“跳上面”还是“潜下面”。
				if String(group["motion"].get("name", "")) == "current_log":
					var dir := signf(hazard_offset(group).y)
					for i in 4:
						var ay := swell_y + 34.0 + i * 18.0
						var ax := lx + 10.0 + fmod(hazard_clock * 55.0 + i * 40.0,
							maxf(lw + 90.0, 40.0))
						draw_line(Vector2(ax, ay), Vector2(ax + 22.0 * dir, ay),
							Color(0.55, 0.95, 1.0, 0.55), 3.0)
						draw_line(Vector2(ax + 22.0 * dir, ay),
							Vector2(ax + 14.0 * dir, ay - 5.0),
							Color(0.55, 0.95, 1.0, 0.55), 3.0)
					draw_string(ThemeDB.fallback_font, Vector2(lx + lw + 6.0, swell_y - 10.0),
						Locale.t("world.current"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
						Color(0.55, 0.95, 1.0, 0.8))
					# 读得出的“这一拍该走哪条”：上沿压到跳跃顶点 → 只能潜；
					# 下沿伸进下潜壳层 → 只能跳。字和箭头都画在同一根浮木旁边。
					var jump_blocked := rect.position.y < 114.0
					var dive_blocked := rect.end.y > 456.0
					var bx := lx + lw + 14.0
					if jump_blocked and not dive_blocked:
						for i in 3:
							var ay := rect.end.y + 26.0 + i * 16.0
							draw_line(Vector2(bx, ay), Vector2(bx, ay + 10.0),
								Color(0.55, 1.0, 0.95, 0.9), 4.0)
							draw_line(Vector2(bx - 7.0, ay + 4.0),
								Vector2(bx, ay + 10.0),
								Color(0.55, 1.0, 0.95, 0.9), 4.0)
							draw_line(Vector2(bx + 7.0, ay + 4.0),
								Vector2(bx, ay + 10.0),
								Color(0.55, 1.0, 0.95, 0.9), 4.0)
						draw_string(ThemeDB.fallback_font,
							Vector2(bx + 14.0, rect.end.y + 58.0), Locale.t("world.dive_here"),
							HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
							Color(0.55, 1.0, 0.95))
					elif dive_blocked and not jump_blocked:
						for i in 3:
							var ay := rect.position.y - 56.0 + i * 16.0
							draw_line(Vector2(bx, ay + 10.0), Vector2(bx, ay),
								Color(1.0, 0.88, 0.45, 0.95), 4.0)
							draw_line(Vector2(bx - 7.0, ay + 6.0),
								Vector2(bx, ay),
								Color(1.0, 0.88, 0.45, 0.95), 4.0)
							draw_line(Vector2(bx + 7.0, ay + 6.0),
								Vector2(bx, ay),
								Color(1.0, 0.88, 0.45, 0.95), 4.0)
						draw_string(ThemeDB.fallback_font,
							Vector2(bx + 14.0, rect.position.y - 30.0), Locale.t("world.jump_here"),
							HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
							Color(1.0, 0.88, 0.45))
					elif jump_blocked and dive_blocked:
						draw_string(ThemeDB.fallback_font,
							Vector2(bx + 12.0, rect.position.y + 20.0), Locale.t("world.blocked"),
							HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.35, 0.3))
			var water_y := surface_ref()
			var log_above := Rect2(lx, rect.position.y,
				lw, maxf(water_y - rect.position.y, 0.0))
			var log_under := Rect2(lx, maxf(water_y, rect.position.y),
				lw, rect.end.y - maxf(water_y, rect.position.y))
			draw_rect(log_above, Color(0.5, 0.36, 0.2))
			draw_rect(Rect2(lx, rect.position.y, lw, 10), Color(0.34, 0.24, 0.13))
			for i in 4:
				draw_line(Vector2(lx + 8.0, rect.position.y + 22.0 + i * 18.0),
					Vector2(lx + lw - 8.0, rect.position.y + 22.0 + i * 18.0),
					Color(0.36, 0.25, 0.14, 0.8), 2.0)
			draw_rect(log_under, Color(0.2, 0.26, 0.26, 0.92))
			draw_rect(log_under, Color(0.55, 0.9, 0.95, 0.85), false, 3.0)
			draw_line(Vector2(lx, rect.end.y), Vector2(lx + lw, rect.end.y),
				Color(0.65, 0.95, 1.0, 0.9), 4.0)
			# 水下段的附着物：一眼能看出它不是浅色背景。
			for i in 5:
				var wx := lx + 12.0 + i * (lw - 24.0) / 4.0
				draw_circle(Vector2(wx, rect.end.y - 12.0), 4.0,
					Color(0.35, 0.55, 0.5, 0.9))
			for i in 3:
				var t := fmod(Time.get_ticks_msec() * 0.0007 + i * 0.3, 1.0)
				draw_circle(Vector2(lx + 26.0 + i * 38.0, rect.end.y + 40.0 - t * 34.0),
					3.0, Color(0.8, 0.95, 1.0, 0.4 * (1.0 - t)))
		"HIGH_WALL":
			# 高墙：墙楣与墙身是两段石头，中间窗口只放得下跃起到顶的壳。
			# 判定框就是这两块石头的形状，画的和判的是同一份 rect。
			draw_rect(rect, Color(0.38, 0.39, 0.42))
			draw_rect(rect, Color(0.12, 0.13, 0.15), false, 3.0)
			var rows := 2 if rect.size.y < 40.0 else 7
			for i in rows:
				var by := rect.position.y + rect.size.y * float(i + 1) / float(rows + 1)
				draw_line(Vector2(rect.position.x + 3.0, by),
					Vector2(rect.end.x - 3.0, by),
					Color(0.24, 0.25, 0.28, 0.95), 2.0)
				var bx := rect.position.x + (8.0 if i % 2 == 0 else rect.size.x * 0.55)
				draw_line(Vector2(bx, by - rect.size.y / float(rows + 1)),
					Vector2(bx, by), Color(0.24, 0.25, 0.28, 0.95), 2.0)
			# 灰色石块 + 墙齿，和棕色浮木彻底区分；它是“跃墙”，不是“下潜”。
			if rect.size.y < 40.0:
				for i in 3:
					var cx := rect.position.x + 4.0 + i * (rect.size.x - 8.0) / 2.0
					draw_rect(Rect2(cx, rect.position.y - 8.0, rect.size.x * 0.22, 8.0),
						Color(0.38, 0.39, 0.42))
			# FEEL-47：墙身要有水下基座，不能看起来悬空；基座只是画法，
			# 判定仍是原来的两段 rect。
			if rect.size.y > 40.0:
				draw_rect(Rect2(rect.position.x - 10.0, rect.end.y - 4.0,
					rect.size.x + 20.0, 760.0 - rect.end.y + 4.0),
					Color(0.22, 0.24, 0.26, 0.95))
				for i in 5:
					var by2 := rect.end.y + 12.0 + i * 24.0
					draw_line(Vector2(rect.position.x - 10.0, by2),
						Vector2(rect.end.x + 10.0, by2),
						Color(0.16, 0.17, 0.19, 0.8), 2.0)



func _turtle_phase_text() -> String:
	if turtle.accident:
		return Locale.state_name("UNCONSCIOUS")
	# CORE-FEEL-07C：掀翻的前 0.9 s 画面是肚皮朝天，状态字必须跟着翻，
	# 不能还在说“被浪压进水里”。
	if turtle.flip_t > 0.0:
		return Locale.state_name("BELLY_UP")
	if turtle.dunk_timer > 0.0:
		return Locale.state_name("DUNKED")
	match turtle.phase_name():
		"RELAXED":
			return Locale.state_name("UNSTEADY")
		"SINKING":
			return Locale.state_name("WOBBLING")
		"DEEP":
			return Locale.state_name("FLIP_RISK")
		_:
			return Locale.state_name("CRITICAL")


## 失衡姿态是主要预警，不是只靠头顶进度条：
## 兔子按阶段后仰、原地左右晃（早期只晃、不平移）；乌龟按阶段侧倾、慢慢摇，
## 越到临界倾得越多。两个函数同时被 _draw 和自检读，保证“说的”和“画的”一致。
func rabbit_lean() -> float:
	if mount.state != "RIDING" or showtime_active:
		return 0.0
	if rabbit.state in ["JUMPING", "FALLING", "CROUCHING", "FALLING_WATER",
			"STUNNED", "PASSED_OUT", "SHOWTIME"]:
		return 0.0
	if rabbit.daze_time <= 0.1:
		return 0.0
	match rabbit.phase_name():
		"RELAXED":
			return 0.04
		"SLIDING":
			return 0.10
		"EDGE":
			return 0.26
		"CRITICAL":
			return 0.42
	return 0.0


func rabbit_wobble_px() -> float:
	if rabbit.daze_time <= 0.1:
		return 0.0
	match rabbit.phase_name():
		"RELAXED":
			return 1.5
		"SLIDING":
			return 2.5
		"EDGE":
			return 5.0
		"CRITICAL":
			return 8.0
	return 0.0


func turtle_tilt() -> float:
	if turtle.accident:
		return 0.0
	if turtle.daze_time <= 0.1:
		return 0.0
	match turtle.phase_name():
		"RELAXED":
			return 0.02
		"SINKING":
			return 0.05
		"DEEP":
			return 0.12
		"CRITICAL":
			return 0.22
	return 0.0


func _update_turtle_facing(x: float) -> void:
	if _turtle_last_draw_x < -1.0e8:
		_turtle_last_draw_x = x
		return
	var dx := x - _turtle_last_draw_x
	if absf(dx) > 0.35:
		_turtle_facing = signf(dx)
	_turtle_last_draw_x = x


func _draw_turtle() -> void:
	# 受激动作只偏移画法；撞击框/落点仍用 turtle.position。
	var pos: Vector2 = turtle.position + _shift_jolt_offset("turtle")
	# P1-5：撞击的 90 ms 里把“画出来的壳”按在撞击点，物理照常走。
	if _hitstop_t > 0.0 and _hitstop_who == "turtle":
		pos = _hitstop_draw + _shift_jolt_offset("turtle")
	# FEEL-47：三段压力只改画法。
	var vtstress := visual_stress("turtle")
	if vtstress > 0.0:
		var tts := Time.get_ticks_msec() * 0.001
		pos += Vector2(sin(tts * (3.8 + vtstress)) * vtstress * 1.4,
			-absf(sin(tts * (5.6 + vtstress))) * vtstress * 1.2)
	# 救援/被顶回时乌龟会向左移动；朝向跟着位移翻转，不再“倒着退”。
	_update_turtle_facing(pos.x)
	# G9：兔子落回壳上/被接住时整只壳往下沉再回弹；只是画法偏移。
	pos.y += shell_dip_offset() + _showtime_turtle_y
	if turtle.speed > 250.0:
		for i in 3:
			var y := pos.y - 24.0 + i * 22.0
			draw_line(Vector2(pos.x - 90.0 - i * 18.0, y),
				Vector2(pos.x - 50.0 - i * 18.0, y),
				Color(0.75, 1.0, 1.0, 0.55), 4.0)
	# 壳画成 92x56 的椭圆，和 96x56 的碰撞体对齐，避免“看着撞了却没判”。
	# 失控时整只侧倾 + 缓慢左右摇：前两段只有一点倾斜，看得到“不太稳”，
	# 临界时倾到 0.22 rad 并来回摇，读到“要翻了”。
	var tilt: float = turtle_tilt() + _showtime_turtle_spin 		+ sin(Time.get_ticks_msec() * 0.005) * vtstress * 0.035
	if tilt > 0.0:
		tilt += sin(Time.get_ticks_msec() * 0.0024) * tilt * 0.5
	if turtle.accident:
		# 翻肚皮后来回晃两下（幅度随翻完程度增大）：喜剧感靠“晃”，不靠拉长演出。
		tilt += sin(_accident_t * 7.0) * 0.14
	# FEEL-12 BITT 旋壳过载：壳外两圈反向电流弧 + 水花，速度和碰撞体不变。
	if _od_shell_t > 0.0 or turtle.overdrive_spin_t > 0.0:
		var tt := Time.get_ticks_msec() * 0.012
		for ar in 2:
			var a0 := tt * (1.0 if ar == 0 else -1.0)
			draw_arc(pos, 54.0 + ar * 8.0, a0, a0 + PI * 1.35, 24,
				Color(0.55, 1.0, 1.0, 0.75), 4.0)
		for i in 5:
			var aa := tt + i * TAU / 5.0
			draw_circle(pos + Vector2(cos(aa), sin(aa)) * 62.0, 3.0,
				Color(0.7, 1.0, 1.0, 0.8))
	var shell := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		shell.append(pos + Vector2(cos(a) * 46.0, sin(a) * 28.0).rotated(tilt))
	draw_colored_polygon(shell, Color(0.25, 0.6, 0.3))
	# BRO BRAIN：待命神游时头会左右张望 / 盯着食物；只动头，不动壳的判定。
	var look: Vector2 = turtle.drift_look_px(GameManager.current_control == "turtle")
	var head_base := pos + Vector2(40.0 * _turtle_facing, -6).rotated(tilt) + look
	# 尾鳍/尾尖在头的反方向，让“掉头”不只靠眼睛判断。
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-46.0 * _turtle_facing, -8).rotated(tilt),
		pos + Vector2(-64.0 * _turtle_facing, 2).rotated(tilt),
		pos + Vector2(-44.0 * _turtle_facing, 10).rotated(tilt),
	]), Color(0.20, 0.48, 0.26))
	draw_circle(pos + Vector2(0, -6).rotated(tilt), 27.0, Color(0.55, 0.8, 0.35))
	draw_circle(head_base, 14.0, Color(0.4, 0.7, 0.3))
	draw_circle(head_base + Vector2(4.0 * _turtle_facing, -4), 3.0, Color(0.05, 0.1, 0.08))
	_draw_bonk_face(head_base, tilt)
	if turtle.accident:
		# 翻肚皮：浅色肚皮盖住壳面，四肢朝天，头被压在下面。
		# 0.6 s 内从侧翻过渡到全翻，先“出事”再定格，不做瞬切。
		var flip := clampf(_accident_t / 0.6, 0.0, 1.0)
		draw_colored_polygon(shell, Color(0.93, 0.88, 0.72).lerp(
			Color(0.25, 0.6, 0.3), 1.0 - flip))
		for i in 4:
			var lx := -30.0 + i * 20.0
			var ly := -20.0 - 12.0 * flip
			draw_circle(pos + Vector2(lx, ly), 7.0, Color(0.4, 0.7, 0.3))
		draw_circle(pos + Vector2(42, 6), 11.0, Color(0.4, 0.7, 0.3))
		draw_line(pos + Vector2(-14, -16), pos + Vector2(-2, -4),
			Color(1, 0.2, 0.2), 4.0)
		draw_line(pos + Vector2(-2, -16), pos + Vector2(-14, -4),
			Color(1, 0.2, 0.2), 4.0)
	if turtle.flip_t > 0.0 and not turtle.accident:
		# P5：浪击掀翻。0.18 s 翻过去、肚皮朝天乱蹬、最后 0.25 s 自己翻回来。
		# 全是画法：位置/碰撞/判定不变，所以翻着也照样被障碍顶住，不会穿过去。
		var fk: float = 1.0 - turtle.flip_t / Tuning.FLIP_TIME
		var flip_in: float = clampf(fk / 0.18, 0.0, 1.0)
		var flip_out: float = clampf((fk - 0.72) / 0.28, 0.0, 1.0)
		var up: float = flip_in * (1.0 - flip_out)
		if up > 0.0:
			var belly := PackedVector2Array()
			for i in 28:
				var ba := TAU * float(i) / 28.0
				belly.append(pos + Vector2(cos(ba) * 46.0,
					sin(ba) * 28.0).rotated(tilt))
			draw_colored_polygon(belly, Color(0.25, 0.6, 0.3).lerp(
				Color(0.93, 0.88, 0.72), up))
		# 四肢朝天乱蹬：四条腿相位不同，像在挣扎，不是整齐划一。
		var fsec := Time.get_ticks_msec() / 1000.0
		for i in 4:
			var flx := -30.0 + i * 20.0
			var kick := sin(fsec * 17.0 + float(i) * 1.9) * 7.0 * up
			var root := pos + Vector2(flx, 6.0).rotated(tilt)
			var tip := root + Vector2(kick * 0.4, -20.0 - 10.0 * up - kick)
			draw_line(root, tip, Color(0.4, 0.7, 0.3), 7.0)
			draw_circle(tip, 3.5, Color(0.5, 0.78, 0.36))
		# 头被压在壳底下，只剩一点露出来。
		if up > 0.05:
			draw_circle(pos + Vector2(34.0 * up, 14.0 * up), 12.0 * up,
				Color(0.42, 0.7, 0.3, 0.9))
	# 只有真有失衡/事故/被浪打湿时才冒状态字；待命不再显示 Zzz（不是在睡觉）。
	if turtle.accident or turtle.daze_time > 0.1 or turtle.dunk_timer > 0.0:
		var color := Color(0.9, 0.9, 1.0)
		match turtle.phase_name():
			"SINKING":
				color = Color(1.0, 0.82, 0.3)
			"DEEP":
				color = Color(1.0, 0.6, 0.25)
			"CRITICAL":
				var pulse := 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.006))
				color = Color(1.0, 0.35, 0.3, pulse)
		draw_string(ThemeDB.fallback_font, pos + Vector2(38, -58),
			_turtle_phase_text(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)
	# BRO BRAIN：没在事故/失衡里时，用一个小符号标出“它在想别的”。
	# REFINE-06 P1：符号旁必须有角色图形（龟壳），否则两个“?”分不出谁是谁。
	if not turtle.accident and turtle.daze_time <= 0.1 and turtle.dunk_timer <= 0.0 \
			and turtle.drift >= Tuning.DRIFT_CALM_END:
		_draw_drift_mark(pos + Vector2(0, -96), "turtle",
			drift_mark_text("turtle"), _drift_color_for(turtle.drift_state),
			24 + _drift_level_for(turtle.drift_state) * 3)
	# CORE-FEEL-07 P1-D：满值不只是条变红——乌龟自己开始划水，四肢一直在动，
	# 读得出“它已经没在配合了”。只画手脚，不改变位置/碰撞。
	var paddle := turtle_paddle_strength()
	if paddle > 0.0:
		var psec := Time.get_ticks_msec() * 0.008
		for i in 2:
			var side := -1.0 if i == 0 else 1.0
			var root := pos + Vector2(side * 34.0, 16.0).rotated(tilt)
			var tip := root + Vector2(side * (10.0 + 4.0 * paddle),
				10.0 + 6.0 * sin(psec + float(i) * 2.4) * paddle)
			draw_line(root, tip, Color(0.4, 0.7, 0.3), 6.0)
			draw_circle(tip, 3.5, Color(0.5, 0.78, 0.36))
	_draw_visual_stress(pos, "turtle")


func _draw_bonk_face(head: Vector2, tilt: float) -> void:
	if _bonk_level <= 0:
		return
	var lv := _bonk_level
	var col := Color(1.0, 0.42, 0.25, 0.95)
	var e1 := head + Vector2(-5, -6).rotated(tilt)
	var e2 := head + Vector2(6, -6).rotated(tilt)
	if lv >= 2:
		for e in [e1, e2]:
			draw_line(e + Vector2(-3, -3), e + Vector2(3, 3), col, 2.0)
			draw_line(e + Vector2(3, -3), e + Vector2(-3, 3), col, 2.0)
	else:
		draw_circle(e1, 2.0, Color(0.05, 0.1, 0.08))
		draw_circle(e2, 2.0, Color(0.05, 0.1, 0.08))
	var mouth := head + Vector2(0, 5).rotated(tilt)
	var pts := PackedVector2Array()
	for i in 5:
		pts.append(mouth + Vector2(-6.0 + i * 3.0, sin(float(i) * 1.8) * 1.5))
	draw_polyline(pts, col, 1.8)
	if lv >= 3:
		draw_circle(head + Vector2(12, -12), 2.5, Color(0.6, 0.9, 1.0, 0.9))
	if lv >= 4:
		var fs := 16 + lv * 2
		draw_string(ThemeDB.fallback_font, head + Vector2(-fs * 0.5, -30),
			"囧", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## FEEL-12 E：三颗氧气气泡跟随 TUBO 头顶；归一化比例，不改氧气数值。
func oxygen_bubble_count() -> int:
	var r := GameManager.oxygen / Tuning.OXYGEN_MAX
	var c := 3 if r > 0.66 else (2 if r > 0.33 else (1 if r > 0.01 else 0))
	# 气短时少一颗气泡，给玩家可见的压力线索。
	if c > 0 and GameManager.waterlogged >= 1:
		c -= 1
	if c > 0 and GameManager.waterlogged >= 3:
		c -= 1
	return maxi(c, 0)


func _draw_oxygen_bubbles() -> void:
	if not oxygen_bubbles_visible():
		return
	var r: float = clampf(GameManager.oxygen / Tuning.OXYGEN_MAX, 0.0, 1.0)
	if r <= 0.01:
		return
	# 三颗气泡是“剩余量”而不是同一个色条：满氧三颗绿；第三颗先淡出；
	# 只剩两颗时中间变黄；只剩最后一颗时变红。
	var remaining := r * 3.0
	var center: Vector2 = rabbit.position + Vector2(0.0, -62.0)
	var t := Time.get_ticks_msec() * 0.006
	for i in 3:
		var state: Dictionary = oxygen_bubble_state(i, remaining)
		var fill: float = float(state["fill"])
		if fill <= 0.02:
			continue
		var col: Color = state["color"]
		col.a = 0.22 + 0.72 * fill
		var p := center + Vector2(float(i - 1) * 17.0, -absf(float(i - 1)) * 3.0)
		var pulse := 0.88 + 0.12 * absf(sin(t * 2.2 + float(i)))
		draw_circle(p, 7.0, Color(col.r, col.g, col.b, col.a * pulse))
		draw_circle(p - Vector2(2.0, 2.0), 2.2,
			Color(1, 1, 1, 0.55 * col.a * pulse))
		draw_arc(p, 8.5, 0, TAU, 14,
			Color(col.r, col.g, col.b, 0.45 * col.a), 1.2)


## 纯逻辑：剩余量 0..3 时每个气泡的填充和颜色。便于审计“不是整体换色”。
func oxygen_bubble_state(index: int, remaining: float) -> Dictionary:
	var fill := clampf(remaining - float(index), 0.0, 1.0)
	var col := Color(0.55, 0.95, 0.55)
	if remaining <= 1.05:
		col = Color(1.0, 0.35, 0.28)
	elif remaining <= 2.05:
		col = Color(1.0, 0.86, 0.30)
	return {"fill": fill, "color": col}


func _draw_guard_and_catch() -> void:
	if _catch_fx_t > 0.0 and _catch_active:
		var a: Vector2 = turtle.position
		var b: Vector2 = rabbit.position
		for i in 4:
			var f := fmod(i * 0.25 + Time.get_ticks_msec() * 0.001, 1.0)
			draw_circle(a.lerp(b, f), 3.0, Color(0.55, 1.0, 1.0, 0.7))
		draw_line(a, b, Color(0.45, 0.95, 1.0, 0.25), 2.0)


func _draw_rabbit() -> void:
	# 同上：受激动作是画法偏移，不改变兔子真实位置。
	var pos: Vector2 = rabbit.position + _shift_jolt_offset("rabbit") \
		+ celebration_offset()
	# P1-5：兔子被撞的 50 ms 里画在撞击点；读作“撞住了”，不影响落水/救援判定。
	if _hitstop_t > 0.0 and _hitstop_who == "rabbit":
		pos = _hitstop_draw + _shift_jolt_offset("rabbit")
	# FEEL-47：三段压力只改画法，不改物理位置/判定。
	var vstress := visual_stress("rabbit")
	if vstress > 0.0:
		var ts := Time.get_ticks_msec() * 0.001
		pos += Vector2(sin(ts * (5.0 + vstress)) * vstress * 1.5,
			-absf(sin(ts * (7.0 + vstress))) * vstress * 1.6)
	var crouching: bool = rabbit.state == "CROUCHING"
	var radius := 15.0 if crouching else 22.0
	# 失衡预警：原地晃（不给位移），越往后晃得越大、身体越往后仰。
	var lean: float = rabbit_lean()
	var sway: float = sin(Time.get_ticks_msec() * 0.009) * rabbit_wobble_px()
	var body_pos := pos + Vector2(sway, 0.0)
	if lean > 0.01 and not crouching and rabbit.state in ["RIDING", "RELAXED",
			"SLIDING", "EDGE", "CRITICAL"]:
		draw_set_transform(body_pos, -lean, Vector2.ONE)
		draw_circle(Vector2.ZERO, radius, Color(0.95, 0.95, 0.95))
		draw_rect(Rect2(Vector2(-14, -radius - 40), Vector2(9, 40)),
			Color(0.95, 0.95, 0.95))
		draw_rect(Rect2(Vector2(5, -radius - 40), Vector2(9, 40)),
			Color(0.95, 0.95, 0.95))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		pos = body_pos
	else:
		draw_circle(body_pos, radius, Color(0.95, 0.95, 0.95))
		pos = body_pos
	if rabbit.state == "FALLING_WATER":
		# 落水翻滚：耳朵绕着脑袋转，配 X 眼和水花圈，一秒内看懂“兔子栽水里了”。
		var ang := _accident_t * 9.0
		for i in 2:
			var side := -1.0 if i == 0 else 1.0
			var base := pos + Vector2(side * 9.0, 0)
			draw_line(base, base + Vector2(cos(ang + side), sin(ang + side)) * 40.0,
				Color(0.95, 0.95, 0.95), 8.0)
		draw_line(pos + Vector2(-9, -7), pos + Vector2(-1, 1), Color(0.25, 0.3, 0.35), 3.0)
		draw_line(pos + Vector2(-1, -7), pos + Vector2(-9, 1), Color(0.25, 0.3, 0.35), 3.0)
		draw_line(pos + Vector2(1, -7), pos + Vector2(9, 1), Color(0.25, 0.3, 0.35), 3.0)
		draw_line(pos + Vector2(9, -7), pos + Vector2(1, 1), Color(0.25, 0.3, 0.35), 3.0)
	elif crouching:
		# 趴下时耳朵折平，视觉上不再顶到横梁。
		draw_rect(Rect2(pos + Vector2(-16, -radius - 4), Vector2(14, 6)),
			Color(0.9, 0.9, 0.9))
		draw_rect(Rect2(pos + Vector2(2, -radius - 4), Vector2(14, 6)),
			Color(0.9, 0.9, 0.9))
	elif lean <= 0.01 and rabbit_ears_droop() > 0.0:
		# CORE-FEEL-07 P1-D：满值神游时耳朵垂下来（姿态本身说明它没在听）。
		var droop := rabbit_ears_droop()
		var tt := Time.get_ticks_msec() * 0.003
		for side in [-1.0, 1.0]:
			var ear_base := pos + Vector2(side * 9.0, -radius + 2.0)
			var ang: float = float(side) * (droop + sin(tt + float(side)) * 0.06)
			var direction := Vector2(sin(ang), -cos(ang))
			draw_line(ear_base, ear_base + direction * 36.0,
				Color(0.95, 0.95, 0.95), 8.0)
			draw_circle(ear_base + direction * 36.0, 4.0, Color(0.95, 0.95, 0.95))
	elif lean <= 0.01:
		# 站姿且没失衡：竖直耳朵。失衡时上面已经按倾斜姿态画过了。
		draw_rect(Rect2(pos + Vector2(-14, -radius - 40), Vector2(9, 40)),
			Color(0.95, 0.95, 0.95))
		draw_rect(Rect2(pos + Vector2(5, -radius - 40), Vector2(9, 40)),
			Color(0.95, 0.95, 0.95))

	if rabbit.mischief_pose:
		# P0-3 错误姿势：身体已经抬到梁下缘，头顶红色弧 + “!”说明这一下会刮到。
		# 只是画法与真实位置抬高；切回兔子（受控）这一帧就消失。
		draw_arc(pos + Vector2(0, -radius - 52), 11.0, PI * 1.15, PI * 1.85, 12,
			Color(1.0, 0.35, 0.25, 0.95), 3.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(14, -radius - 46), "!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.45, 0.3))

	if rabbit.state == "SHOWTIME":
		var dir := Vector2(cos(rabbit.showtime_spin), sin(rabbit.showtime_spin))
		draw_line(pos, pos + dir * 34.0, Color(1.0, 0.8, 0.2), 5.0)
		if rabbit.showtime_pose:
			draw_line(pos + Vector2(-12, -6), pos + Vector2(-26, -34),
				Color(0.95, 0.95, 0.95), 5.0)
			draw_line(pos + Vector2(12, -6), pos + Vector2(26, -34),
				Color(0.95, 0.95, 0.95), 5.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-48, -58), Locale.t("world.showtime_pop"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.25))

	# FEEL-12 TUBO 弹簧过载：耳朵拉长、脚下电火花；轨迹已由 launch 改变。
	if _od_spring_t > 0.0:
		var tt := Time.get_ticks_msec() * 0.02
		for side in [-1.0, 1.0]:
			var base := pos + Vector2(side * 9.0, -radius)
			draw_line(base, base + Vector2(side * 3.0, -62.0),
				Color(0.95, 0.95, 0.95), 7.0)
			draw_line(base + Vector2(side * 3.0, -62.0),
				base + Vector2(side * 8.0, -74.0 + sin(tt + side) * 4.0),
				Color(0.55, 0.95, 1.0, 0.9), 3.0)
		for i in 3:
			var aa := tt + i * 2.1
			draw_circle(pos + Vector2(cos(aa) * 30.0, sin(aa) * 16.0 - 18.0),
				2.5, Color(0.55, 0.95, 1.0, 0.7))
	# 世界里的“抓地%”条删掉：只保留姿态，失衡数值由 HUD 在真的有风险时显示。
	# 站立/待命时画两只小爪扣住壳，读作“抓紧”，不是发呆。
	if rabbit.state == "RIDING" and mount.state == "RIDING" and not turtle.leap_active:
		draw_circle(pos + Vector2(-11, radius + 2), 4.0, Color(0.9, 0.9, 0.9))
		draw_circle(pos + Vector2(11, radius + 2), 4.0, Color(0.9, 0.9, 0.9))
	# BRO BRAIN：待命神游的姿势。只画在真正站/坐在壳上的时候；
	# 跳跃、趴低、硬直期间不做额外表演，避免和玩家动作抢读。
	if mount.state == "RIDING" and not turtle.leap_active and not crouching \
			and rabbit.state in ["RIDING", "RELAXED", "SLIDING", "EDGE", "CRITICAL"]:
		_draw_rabbit_drift(pos)
	if rabbit.state == "STUNNED":
		for i in 3:
			var a := TAU * i / 3.0 + 0.5
			draw_circle(pos + Vector2(cos(a), sin(a)) * 34.0, 4.0,
				Color(1.0, 0.9, 0.3))
	if rabbit.state == "PASSED_OUT":
		draw_line(pos + Vector2(-10, -10), pos + Vector2(-2, -2), Color(0.3, 0.3, 0.3), 3.0)
		draw_line(pos + Vector2(-2, -10), pos + Vector2(-10, -2), Color(0.3, 0.3, 0.3), 3.0)
		draw_line(pos + Vector2(2, -10), pos + Vector2(10, -2), Color(0.3, 0.3, 0.3), 3.0)
		draw_line(pos + Vector2(10, -10), pos + Vector2(2, -2), Color(0.3, 0.3, 0.3), 3.0)

	# 一次性水花：记在兔子真正穿水的那个世界点（§6），0.6 s 内扩散消失。
	# 和下面跟着兔子走的救生圈分开画，玩家能看出“它是在那里掉下去的”。
	if rescue_splash_t >= 0.0 and rescue_splash_t <= 0.6:
		var k: float = rescue_splash_t / 0.6
		draw_arc(rescue_splash_pos + Vector2(0, 10), 10.0 + 70.0 * k, 0, TAU, 28,
			Color(0.8, 0.97, 1.0, 0.7 * (1.0 - k)), 3.0)
		for i in 6:
			var sa := TAU * float(i) / 6.0
			draw_circle(rescue_splash_pos + Vector2(cos(sa), sin(sa) * 0.6)
				* (6.0 + 46.0 * k), 3.2 * (1.0 - k) + 0.8,
				Color(0.9, 1.0, 1.0, 0.8 * (1.0 - k)))

	if mount.state in ["RESCUING", "RESCUE_ACTIVE"] \
			and GameManager.accident_state in ["RABBIT_SLIP", "RABBIT_WATER"]:
		# 水花圈 + 溅点：事故是“落水”不是“消失”，玩家能看见兔子还在水里。
		for i in 3:
			var rr := 16.0 + fmod(_accident_t * 70.0 + i * 24.0, 66.0)
			var alpha := clampf(1.0 - rr / 92.0, 0.0, 0.55)
			draw_arc(pos + Vector2(0, 18), rr, 0, TAU, 32,
				Color(0.75, 0.95, 1.0, alpha), 3.0)
		for i in 4:
			var ang2 := TAU * float(i) / 4.0 + _accident_t * 2.0
			draw_circle(pos + Vector2(cos(ang2), sin(ang2))
				* (24.0 + 22.0 * _accident_t), 3.0, Color(0.9, 1.0, 1.0, 0.5))

	if GameManager.pickup_window:
		# G8：环是“落壳走廊”（下落中对准壳），从 -150 px 就亮。
		# FEEL-47：不再在这里写“接住了”；普通跳跃落壳不是“好接”，
		# 真正接住的奖励只走 pickup_success / banner。
		var hint_pos: Vector2 = turtle.get_mount_point()
		draw_arc(hint_pos, 82.0, 0, TAU, 48, Color(0.4, 1.0, 0.6), 4.0)
	_draw_visual_stress(pos, "rabbit")


## 神游姿态：只用项目现有的原生画法，不引入任何美术素材。
## DISTRACTED 摆姿势秀肌肉；RESTLESS 脚步错乱；MISCHIEF 已经挂到壳边抓稳。
func _draw_rabbit_drift(pos: Vector2) -> void:
	var state: String = rabbit.drift_state
	if state == "CALM":
		return
	var t := Time.get_ticks_msec() * 0.001
	var white := Color(0.95, 0.95, 0.95)
	if state == "DISTRACTED":
		for side in [-1.0, 1.0]:
			draw_line(pos + Vector2(side * 10.0, -6.0),
				pos + Vector2(side * 24.0, -20.0), white, 5.0)
			draw_line(pos + Vector2(side * 24.0, -20.0),
				pos + Vector2(side * 18.0, -34.0), white, 5.0)
		draw_circle(pos + Vector2(0, 2), 7.0 + 2.0 * absf(sin(t * 4.0)),
			Color(0.98, 0.98, 0.98, 0.85))
	elif state == "RESTLESS":
		var lift := maxf(sin(t * 7.0), 0.0)
		draw_circle(pos + Vector2(-10, 24), 4.5, white)
		draw_circle(pos + Vector2(10, 24 - lift * 6.0), 4.5, white)
		draw_line(pos + Vector2(-26, -30), pos + Vector2(-22, -16),
			Color(0.6, 0.9, 1.0), 3.0)
	else:
		# MISCHIEF：身体已经向外探，两只手抓着壳边；汗滴说明“快站不住了”。
		for side in [-1.0, 1.0]:
			draw_line(pos + Vector2(side * 10.0, 2.0),
				pos + Vector2(-26.0, 30.0), white, 5.0)
		draw_circle(pos + Vector2(-30, 30), 3.5, white)
		draw_line(pos + Vector2(-24, -26), pos + Vector2(-30, -38),
			Color(0.6, 0.9, 1.0), 3.0)
	# 阶段符号统一画在角色图形旁边：图形说明“是谁”，符号说明“到哪一步”。
	_draw_drift_mark(pos + Vector2(16, -46), "rabbit",
		drift_mark_text("rabbit"), _drift_color_for(state),
		20 + _drift_level_for(state) * 2)


## CORE-FEEL-07 P1-D：满值（drift 到达 DRIFT_CAP）时符号升为 "!!"，
## 和还没满的 "!" 分开；读数来自角色每帧同步的 drift/drift_state。
func drift_mark_text(who: String) -> String:
	var state: String = rabbit.drift_state if who == "rabbit" else turtle.drift_state
	var drift: float = rabbit.drift if who == "rabbit" else turtle.drift
	if state == "MISCHIEF" and drift >= Tuning.DRIFT_CAP - 0.05:
		return "!!"
	return _drift_mark_for(state)


## 兔子满值姿态：耳朵从竖直一路垂到接近水平。返回的是“偏离竖直”的角度
## （rad），画法和自检都读它，保证 HUD 说的“满值”和画出来的动作是同一件事。
func rabbit_ears_droop() -> float:
	if rabbit.drift_state != "MISCHIEF" or mount.state != "RIDING" \
			or turtle.leap_active:
		return 0.0
	if not (rabbit.state in ["RIDING", "RELAXED", "SLIDING", "EDGE", "CRITICAL"]):
		return 0.0
	var p := clampf((float(rabbit.drift) - Tuning.DRIFT_RESTLESS_END) / 3.0, 0.0, 1.0)
	return 0.7 + 0.45 * p


## 乌龟满值姿态：壳下两只鳍脚不停划水（0 = 不画）。同样只动画法，
## 位置、碰撞与判定仍用 turtle.position。
func turtle_paddle_strength() -> float:
	if turtle.drift_state != "MISCHIEF" or turtle.accident:
		return 0.0
	var p := clampf((float(turtle.drift) - Tuning.DRIFT_RESTLESS_END) / 3.0, 0.0, 1.0)
	return 0.45 + 0.55 * p


## REFINE-06 P1：神游标记 = 角色图形 + 阶段符号。
## 兔子用“头 + 两只长耳朵”，乌龟用“壳 + 头”；符号仍分 ? / !? / !。
## 只画形状，不引入素材；最高一级符号更大、颜色更红。
func _draw_drift_mark(at: Vector2, who: String, mark: String, color: Color,
		font_size: int) -> void:
	var bob := sin(Time.get_ticks_msec() * 0.004 + (1.7 if who == "turtle" else 0.0)) * 1.5
	var base := at + Vector2(0, bob)
	# 深色“想法泡”底：白色图形直接画在浅色天空/水面和背景装饰上几乎看不见
	# （REFINE-06 P1 截图实测：白圈要放大 10 倍才分得清，还和背景鱼糊在一起）。
	var bubble := base + Vector2(6, 2)
	var br := 19.0 if who == "turtle" else 16.0
	draw_circle(bubble, br, Color(0.05, 0.10, 0.14, 0.55))
	draw_arc(bubble, br, 0, TAU, 24, Color(color.r, color.g, color.b, 0.85), 1.5)
	var c := Color(0.95, 0.98, 1.0, 1.0)
	if who == "rabbit":
		draw_circle(base + Vector2(0, 4), 4.0, c)
		draw_line(base + Vector2(-2.5, 0), base + Vector2(-3.6, -8.0), c, 2.0)
		draw_line(base + Vector2(2.5, 0), base + Vector2(3.6, -8.0), c, 2.0)
	else:
		draw_arc(base + Vector2(0, 4), 4.5, 0, TAU, 16, c, 1.8)
		draw_circle(base + Vector2(6.0, 4), 2.2, c)
	draw_string(ThemeDB.fallback_font, base + Vector2(10, 1), mark,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _drift_mark_for(state: String) -> String:
	match state:
		"RESTLESS":
			return "!?"
		"MISCHIEF":
			return "!"
	return "?"


func _drift_color_for(state: String) -> Color:
	match state:
		"RESTLESS":
			return Color(1.0, 0.72, 0.28)
		"MISCHIEF":
			return Color(1.0, 0.45, 0.30)
	return Color(1.0, 0.90, 0.50)


func _drift_level_for(state: String) -> int:
	match state:
		"DISTRACTED":
			return 1
		"RESTLESS":
			return 2
		"MISCHIEF":
			return 3
	return 0


func _draw_control_ring() -> void:
	if test_no_control_ring:
		return
	var color := Color(1.0, 0.9, 0.25, 0.9)
	if GameManager.current_control == "turtle":
		draw_arc(turtle.position, 62.0, 0, TAU, 48, color, 5.0)
	else:
		draw_arc(rabbit.position, 36.0, 0, TAU, 36, color, 4.0)


func _draw_hitboxes() -> void:
	for g in hazard_groups:
		var group: Dictionary = g
		for i in group["rects"].size():
			draw_rect(hazard_rect_live(group, i), Color(1.0, 0.2, 0.2, 0.8), false, 2.0)
	draw_rect(turtle.get_body_rect(), Color(0.2, 1.0, 1.0, 0.9), false, 2.0)
	draw_rect(rabbit.get_body_rect(), Color(0.2, 1.0, 0.5, 0.9), false, 2.0)


## PHASE-2：终点沙滩/大表哥截图。只为视觉自检，不写 best。
func _capture_finish(file_name: String) -> void:
	opening_active = false
	finishing = false
	test_no_finish = false
	turtle.reset(Vector2(world_end - 100.0, surface_ref()))
	rabbit.reset()
	rabbit.attach(turtle.get_mount_point())
	mount.reset()
	mount.mark_riding()
	_update_zone()
	_update_camera()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_shot(file_name)
	get_tree().quit(0)


func _capture_after(seconds: float, file_name: String) -> void:
	await get_tree().create_timer(seconds).timeout
	_save_shot(file_name)
	get_tree().quit(0)


## 窗口化真人键位测试用：不注入任何按键，只在两个时刻截屏。
## 1.95 s 是接住窗口内，4.05 s 是未接住后的有限恢复。
func _capture_rescue(file_name: String) -> void:
	var args := OS.get_cmdline_user_args()
	if "--rescue-demo-catch" in args:
		# 窗口化 + 引擎内输入代理：不是 OS 级真实按键（本机 SendInput 被系统拒绝）。
		await get_tree().create_timer(1.0).timeout
		Input.action_press("down")
		await get_tree().create_timer(0.9).timeout
		_save_shot(file_name)
		Input.action_release("down")
		await get_tree().create_timer(0.4).timeout
		get_tree().quit(0)
		return
	if "--rescue-demo-miss" in args:
		await get_tree().create_timer(3.4).timeout
		_save_shot(file_name)
		await get_tree().create_timer(0.7).timeout
		_save_shot(file_name.get_basename() + "_late.png")
		get_tree().quit(0)
		return
	await get_tree().create_timer(1.95).timeout
	_save_shot(file_name)
	await get_tree().create_timer(2.10).timeout
	_save_shot(file_name.get_basename() + "_late.png")
	get_tree().quit(0)


func _capture_pause(file_name: String) -> void:
	await get_tree().create_timer(0.6).timeout
	GameManager.toggle_pause()
	await get_tree().create_timer(0.3).timeout
	_save_shot(file_name)
	get_tree().quit(0)


func _arg_after(args: PackedStringArray, flag: String, fallback: String) -> String:
	var i := args.find(flag)
	if i >= 0 and i + 1 < args.size() and not args[i + 1].begins_with("--"):
		return args[i + 1]
	return fallback


func _capture_showtime() -> void:
	await get_tree().create_timer(0.4).timeout
	# REBUILD-05 G11：x=5100 是 rock2（会下沉的礁）的正中间。旧写法传送过去 0.2 s 内
	# 就撞上，`start_showtime()` 因为事故被拒，截出来是「咚！兔子被撞晕」而不是 SHOWTIME。
	# 截图工具先关判定，再挪到 rock2 组尾（5240）之后的空档，拍到的才是表演本身。
	test_disable_hazards = true
	turtle.position = Vector2(5300.0, surface_ref())
	turtle.speed = 220.0
	await get_tree().create_timer(0.2).timeout
	start_showtime()
	await get_tree().create_timer(0.45).timeout
	_save_shot(_arg_after(OS.get_cmdline_user_args(), "--capture-showtime", "stage2_showtime.png"))
	get_tree().quit(0)


func _capture_boost() -> void:
	await get_tree().create_timer(0.3).timeout
	turtle.position = Vector2(2700.0, surface_ref())
	turtle.speed = 380.0
	await get_tree().create_timer(0.4).timeout
	# REBUILD-05 G14：原来写死 "stage2_boost.png"，不认命令行文件名——跑一次取证
	# 就把 Phase 2 的历史证据覆盖了（2026-11-13 实际发生过一次，已从 .ctex 恢复）。
	# 和其他 capture 钩子一样接受 `-- --capture-boost <文件名>`。
	_save_shot(_arg_after(OS.get_cmdline_user_args(), "--capture-boost", "stage2_boost.png"))
	get_tree().quit(0)


## Phase O 截图：食物 + 后方障碍，以及吞下后的 TURBO。
## 只用于窗口化证据；脚本自动驱动，不是真人试玩。
func _capture_snack() -> void:
	await get_tree().create_timer(0.3).timeout
	var encs := _snack_list()
	if encs.is_empty():
		get_tree().quit(1)
		return
	# `--snack-index N` 拍第 N+1 个食物遭遇（0 是第一个固定遭遇）。
	var idx := int(_arg_after(OS.get_cmdline_user_args(), "--snack-index", "0"))
	idx = clampi(idx, 0, encs.size() - 1)
	var enc: Dictionary = encs[idx]
	# 截图名前缀可传，吞食/加速两张跟着同一前缀，避免覆盖别的阶段的图。
	var shot := _arg_after(OS.get_cmdline_user_args(), "--capture-snack", "stage4_snack.png")
	var shot_base := shot.get_basename()
	GameManager.current_control = "turtle"
	GameManager.has_shifted = true
	turtle.position = Vector2(float(enc["x"]) - 320.0, Tuning.NEUTRAL_DEPTH)
	turtle.speed = float(current_zone["base_speed"])
	await get_tree().create_timer(0.35).timeout
	_save_shot(shot)
	# 等真正吃下（而不是猜时间），拍吞食那一瞬。
	for i in 60:
		await get_tree().create_timer(0.05).timeout
		if snack_last_eaten != "":
			break
	await get_tree().create_timer(0.16).timeout
	_save_shot(shot_base + "_gulp.png")
	await get_tree().create_timer(0.8).timeout
	_save_shot(shot_base + "_turbo.png")
	get_tree().quit(0)


func _capture_accident() -> void:
	await get_tree().create_timer(0.4).timeout
	# REBUILD-05 G13：bird1 在 P1-4 挪到 1560 之后，旧的“传送到 1290 再等 0.4 s”
	# 只够走 88 px，根本到不了鸟——截出来是“鸟在飞、没有事故横幅”，文件名却写着
	# accident。改成传送到鸟前 160 px，然后等真的发生一次事故再拍（最多 3 s）。
	turtle.position = Vector2(1400.0, surface_ref())
	turtle.speed = 220.0
	var frames := 0
	while GameManager.accident_state == "NONE" and frames < 180:
		await get_tree().physics_frame
		frames += 1
	await get_tree().create_timer(0.15).timeout
	_save_shot(_arg_after(OS.get_cmdline_user_args(), "--capture-accident", "stage2_accident.png"))
	get_tree().quit(0)


## P0-1 证据：正式赛车道上做一次真实 SHIFT，抓电击表现（电弧/闪光/HUD 换人）的那几帧。
func _capture_shift(file_name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	GameManager.set_control("rabbit")
	await get_tree().create_timer(0.2).timeout
	GameManager.toggle_control()
	await get_tree().create_timer(0.05).timeout
	_save_shot(file_name)
	get_tree().quit(0)


## P1-5 证据：在正式赛道第一块低岩上撞一次，抓碰撞后的后果画面
## （事故闪白 / HUD 事故与提示），不是脚本假造的暂停帧。
func _capture_collision(file_name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	test_disable_hazards = false
	GameManager.set_control("rabbit")
	var rock := {}
	for g in hazard_groups:
		if String(g["kind"]) == "SURFACE_ROCK":
			rock = g
			break
	var rock_x: float = _group_start(rock) if not rock.is_empty() else 2500.0
	turtle.position = Vector2(rock_x - 55.0, surface_ref())
	rabbit.position = turtle.get_mount_point()
	rabbit_grace = 0.0
	var guard := 0
	while hit_groups.is_empty() and guard < 180:
		await get_tree().process_frame
		guard += 1
	await get_tree().create_timer(0.06).timeout
	_save_shot(file_name)
	get_tree().quit(0)


## 乌龟跃起：停在鲨鱼前，受控触发一次，0.5 s 时在上升段。
func _capture_leap(file_name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	test_disable_hazards = true
	GameManager.set_control("turtle")
	turtle.position = Vector2(6150.0, surface_ref())
	await get_tree().create_timer(0.15).timeout
	turtle.start_leap()
	await get_tree().create_timer(0.5).timeout
	_save_shot(file_name)
	get_tree().quit(0)


## 原型段截图：五类障碍各一张 + 组合漂浮物的完整序列 + F3 判定框。
## 不关判定，跑不通就会在截图里看到事故——这是证据，不是摆拍。
func _capture_proto(prefix: String) -> void:
	await get_tree().create_timer(0.4).timeout
	GameManager.state = GameManager.GameState.RUNNING
	var shots := [
		["bird", Vector2(1180.0, surface_ref())],
		["rock", Vector2(2380.0, surface_ref())],
		["beam", Vector2(3580.0, surface_ref())],
		["gate", Vector2(4780.0, surface_ref())],
		["shark", Vector2(5980.0, surface_ref())],
		["log", Vector2(7260.0, surface_ref())],
	]
	for s in shots:
		turtle.position = s[1]
		turtle.speed = 0.0
		await get_tree().create_timer(0.3).timeout
		_save_shot("%s_%s.png" % [prefix, s[0]])
	# 同一位置再拍一张 F3：每类障碍的兔子/乌龟判定框与上下安全通道。
	debug_mode = true
	show_hitboxes = true
	for s in shots:
		turtle.position = s[1]
		turtle.speed = 0.0
		await get_tree().create_timer(0.3).timeout
		_save_shot("%s_debug_%s.png" % [prefix, s[0]])
	debug_mode = false
	show_hitboxes = false
	# 组合漂浮物的完整序列：先跳、再换乌龟、再下潜、最后接回。
	test_disable_hazards = true
	turtle.speed = 220.0
	GameManager.set_control("rabbit")
	turtle.position = Vector2(7400.0, surface_ref())
	await get_tree().create_timer(0.1).timeout
	Input.action_press("up")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("up")
	await get_tree().create_timer(0.45).timeout
	_save_shot("%s_combo_1_jump.png" % prefix)
	GameManager.set_control("turtle")
	Input.action_press("down")
	await get_tree().create_timer(0.8).timeout
	_save_shot("%s_combo_2_dive.png" % prefix)
	await get_tree().create_timer(0.9).timeout
	_save_shot("%s_combo_3_land.png" % prefix)
	Input.action_release("down")
	# F3：判定框 + 上下安全通道。
	debug_mode = true
	show_hitboxes = true
	turtle.position = Vector2(7260.0, surface_ref())
	await get_tree().create_timer(0.5).timeout
	_save_shot("%s_debug.png" % prefix)
	get_tree().quit(0)


## F3 调试层：障碍 ID/类型/动作、判定框、触发距离、危险深度线一次看全。
func _capture_debug(file_name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	test_disable_hazards = true
	debug_mode = true
	show_hitboxes = true
	turtle.position = Vector2(1050.0, surface_ref())
	await get_tree().create_timer(0.2).timeout
	_save_shot(file_name)
	get_tree().quit(0)


## Phase H：鲨鱼判定框与画法对齐取证。把乌龟放在第一条鲨鱼前 300 px，
## 打开 show_hitboxes：红框上沿必须贴着鱼头顶，不再有 30 px 空白。
func _capture_shark(file_name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	test_disable_hazards = true
	debug_mode = true
	show_hitboxes = true
	turtle.position = Vector2(6900.0, surface_ref())
	await get_tree().create_timer(0.2).timeout
	_save_shot(file_name)
	get_tree().quit(0)


## M 门槛① 的可读性证据：岩/梁的水下反下潜段必须看得见。
## 窗口化运行 + 引擎内输入代理（不是 OS 级真实按键）：控制乌龟、按住下潜，
## 在兔子撞上水下那段的瞬间截屏。rock1 2400 / beam1 3700。
func _capture_dive_block(which: String) -> void:
	await get_tree().create_timer(0.4).timeout
	var x0 := 2400.0 if which == "rock" else 3700.0
	GameManager.set_control("turtle")
	turtle.position = Vector2(x0 - 300.0, surface_ref())
	Input.action_press("down")
	await get_tree().create_timer(1.7).timeout
	_save_shot("phase-m_%s_block.png" % which)
	Input.action_release("down")
	get_tree().quit(0)


## 待命稳定性截图：控制乌龟，兔子待命，壳应停在巡航水深、兔子不滑。
## P1-6 取证：把乌龟放到 Z3 第一条浮木（log5=44110）前 1220 px。
## 此时预警已亮、但浮木还在画面外——图标应该钉在右缘，不压主画面。
func _capture_z3_warning(file_name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	test_disable_hazards = true
	GameManager.set_control("turtle")
	turtle.position = Vector2(42890.0, surface_ref())
	rabbit.position = turtle.get_mount_point()
	await get_tree().create_timer(0.6).timeout
	_save_shot(file_name)
	get_tree().quit(0)


## REBUILD-05 C2 取证：同一块浮木的三个时机（准备 / 现在 / 已错过）。
## 只钉 x、不推进物理，保证三张图只有提示状态不同。
func _capture_coop(prefix: String) -> void:
	await get_tree().create_timer(0.4).timeout
	test_disable_hazards = true
	var g: Dictionary = {}
	for it in hazard_groups:
		if String(it["group"]) == "log1":
			g = it
			break
	if g.is_empty():
		get_tree().quit(1)
		return
	GameManager.set_control("rabbit")
	var start_x: float = LevelDataScript.group_start(g)
	for step in [["prepare", 500.0], ["now", 200.0], ["missed", 60.0]]:
		turtle.position = Vector2(start_x - float(step[1]), surface_ref())
		rabbit.position = turtle.get_mount_point()
		# 每帧重钉一次：截图取的是上一帧画好的 HUD。
		for i in 12:
			turtle.position.x = start_x - float(step[1])
			rabbit.position = turtle.get_mount_point()
			await get_tree().process_frame
		_save_shot("rebuild05-coop_%s_%s.png" % [prefix, step[0]])
	get_tree().quit(0)


## REBUILD-05 E1 证据：海鸟四段姿态各一张（前摇 / 俯冲 / 攻击 / 拉起）。
## 用正式场景、正式绘制路径，只把乌龟钉在指定距离上；不改判定、不注入按键。
func _capture_bird(prefix: String) -> void:
	await get_tree().create_timer(0.4).timeout
	test_disable_hazards = true
	var g: Dictionary = {}
	for it in hazard_groups:
		if String(it["group"]) == "bird1":
			g = it
			break
	if g.is_empty():
		get_tree().quit(1)
		return
	GameManager.set_control("rabbit")
	var start_x: float = _group_start(g)
	for step in [["telegraph", 620.0], ["dive", 120.0],
			["strike", -60.0], ["recover", -320.0]]:
		var d := float(step[1])
		for i in 14:
			turtle.position = Vector2(start_x - d, surface_ref())
			rabbit.position = turtle.get_mount_point()
			await get_tree().process_frame
		_save_shot("%s_%s.png" % [prefix, step[0]])
	get_tree().quit(0)


## REBUILD-05 E2 证据：三种动态障碍各抓关键相位。
## 运动时钟每一帧重钉，截图取到的就是指定相位下的“画和判定同源”的矩形。
## CORE-FEEL-08 P1-C 证据：三种身份各抓高低两个相位 + 静止礁石对照。
## 走的是正式赛道同一条绘制路径（_draw_hazard），不是另搭的预览场景。
func _capture_identity(prefix: String) -> void:
	await get_tree().create_timer(0.4).timeout
	test_disable_hazards = true
	GameManager.set_control("rabbit")
	var shots := [
		["rock1", 0.0, "sea_rock_static"],
		["rock3", 2.7, "buoy_crest"],
		["rock3", 0.9, "buoy_trough"],
		["rock4", 2.7, "dock_crate_crest"],
		["rock4", 0.9, "dock_crate_trough"],
		["rock8", 2.7, "drift_crate_crest"],
		["rock8", 0.9, "drift_crate_trough"],
	]
	for shot in shots:
		var g: Dictionary = {}
		for it in hazard_groups:
			if String(it["group"]) == String(shot[0]):
				g = it
				break
		if g.is_empty():
			continue
		var start_x: float = _group_start(g)
		var pin_x: float = start_x - 210.0
		for i in 14:
			hazard_clock = float(shot[1])
			turtle.position = Vector2(pin_x, surface_ref())
			rabbit.position = turtle.get_mount_point()
			await get_tree().process_frame
		_save_shot("%s_%s.png" % [prefix, shot[2]])
	get_tree().quit(0)


## FEEL-09 P0-A 取证：Z2 三个新身份的五个关键时刻 + 浮台。
## 只钉位置和时钟，不改判定；画的就是正式绘制路径。
func _capture_z2(prefix: String) -> void:
	await get_tree().create_timer(0.4).timeout
	test_disable_hazards = true
	GameManager.set_control("rabbit")
	# 吊网按距离分四段：巡航 / 前摇 / 放下 / 收回。
	var net_shots := [[1000.0, "net_cruise"], [500.0, "net_telegraph"],
		[120.0, "net_dive"], [-80.0, "net_strike"], [-300.0, "net_recover"]]
	# 注意：9 个“食物锚点”组会按种子重抽 kind（plan_snack_draws），
	# 所以不能按组名假设 gate3 一定是 DIVE_GATE。按 Z2 实际出现的种类找。
	var net_group := _first_with_identity("cargo_net", 2)
	if not net_group.is_empty():
		var band: Rect2 = net_group["rects"][0]
		for shot in net_shots:
			var pin_x: float = band.position.x - float(shot[0])
			for i in 45:
				turtle.position = Vector2(pin_x, surface_ref())
				rabbit.position = turtle.get_mount_point()
				await get_tree().process_frame
			await _capture_still("%s_%s.png" % [prefix, shot[1]])
	# 鳗鱼两个状态：预警（带电）与窜起。按相位等，不按固定时长。
	var eel := _first_with_identity("canal_eel", 2)
	if not eel.is_empty():
		var pin_e: float = _group_start(eel) - 170.0
		for i in 240:
			turtle.position = Vector2(pin_e, surface_ref())
			rabbit.position = turtle.get_mount_point()
			if String(hazard_motion_state(eel).get("phase", "")) == "TELEGRAPH":
				break
			await get_tree().process_frame
		await _capture_still("%s_eel_telegraph.png" % prefix)
		for i in 240:
			turtle.position = Vector2(pin_e, surface_ref())
			rabbit.position = turtle.get_mount_point()
			if String(hazard_motion_state(eel).get("phase", "")) == "LUNGE":
				break
			await get_tree().process_frame
		# LUNGE 的上升只占 SHARK_RISE_TIME=0.12 s，相位一变就截图会截到还在深水。
		for i in 18:
			turtle.position = Vector2(pin_e, surface_ref())
			rabbit.position = turtle.get_mount_point()
			await get_tree().process_frame
		await _capture_still("%s_eel_lunge.png" % prefix)
	# 船闸与系泊浮台：按身份找实际出现的组。
	for pair in [["sluice_gate", "sluice_gate"], ["mooring_pontoon", "mooring_pontoon"]]:
		var g := _first_with_identity(String(pair[0]), 2)
		if g.is_empty():
			print("CAPZ2 no %s in Z2 this seed" % pair[0])
			continue
		var pin_x: float = _group_start(g) - 230.0
		for i in 60:
			hazard_clock = 0.0
			turtle.position = Vector2(pin_x, surface_ref())
			rabbit.position = turtle.get_mount_point()
			await get_tree().process_frame
		await _capture_still("%s_%s.png" % [prefix, pair[1]])
	get_tree().quit(0)


## FEEL-09 P1-A 取证：第一次“必须 SHIFT”的提示 + 键帽高亮。
func _capture_lesson(prefix: String) -> void:
	await get_tree().create_timer(0.4).timeout
	test_disable_hazards = true
	GameManager.set_control("rabbit")
	for i in 60:
		turtle.position = Vector2(3400.0, surface_ref())
		rabbit.position = turtle.get_mount_point()
		await get_tree().process_frame
	await _capture_still(prefix + ".png")
	get_tree().quit(0)


## FEEL-09 P0-D 取证：Showtime 完成后 HUD 的 +100 / 氧气奖励一行。
func _capture_showtime_reward(prefix: String) -> void:
	await get_tree().create_timer(0.4).timeout
	test_disable_hazards = true
	GameManager.set_control("rabbit")
	GameManager.oxygen = 4.0
	start_showtime()
	# 表演结束前把氧气压低，截图才能看到“实际 +1.5”而不是“氧气已满”。
	await get_tree().create_timer(1.65).timeout
	GameManager.oxygen = 0.5
	await get_tree().create_timer(0.55).timeout
	await _capture_still(prefix + ".png")
	get_tree().quit(0)


func _first_with_identity(identity: String, zone_id: int) -> Dictionary:
	for g in hazard_groups:
		if String(g.get("identity", "")) != identity:
			continue
		if zone_id > 0 \
				and int(LevelDataScript.zone_at(_group_start(g))["id"]) != zone_id:
			continue
		return g
	return {}


## 截图前强制画一帧：窗口失焦时 process_frame 仍会触发，但画面不一定重绘，
## 直接 get_image() 会拿到上一处钉点的旧帧（本次实测差一整组）。
func _capture_still(file_name: String) -> void:
	# 先让窗口真正出一帧：失焦时 process_frame 仍会跑，但绘制可能被跳过。
	await get_tree().create_timer(0.35).timeout
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	_save_shot(file_name)


func _first_in_zone(kind: String, zone_id: int) -> Dictionary:
	for g in hazard_groups:
		if String(g["kind"]) != kind:
			continue
		if int(LevelDataScript.zone_at(_group_start(g))["id"]) == zone_id:
			return g
	return {}


func _group_by_name(name: String) -> Dictionary:
	for g in hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


## CORE-FEEL-08 P1-D 证据：第二区域进场 / 中段 / 出场的分层画面，
## 以及同一位置前后推进 240 px 的滚动对照（检查视差与接缝）。
func _capture_dock(prefix: String) -> void:
	await get_tree().create_timer(0.4).timeout
	test_disable_hazards = true
	GameManager.set_control("rabbit")
	var pins := [
		[14700.0, "entry"],
		[15200.0, "inside"],
		[22000.0, "mid"],
		[30800.0, "far"],
		[38600.0, "exit"],
		[22000.0 + 240.0, "mid_plus240"],
	]
	for pin in pins:
		for i in 14:
			turtle.position = Vector2(float(pin[0]), surface_ref())
			rabbit.position = turtle.get_mount_point()
			await get_tree().process_frame
		_save_shot("%s_%s.png" % [prefix, pin[1]])
	get_tree().quit(0)


func _capture_motion(prefix: String) -> void:
	await get_tree().create_timer(0.4).timeout
	test_disable_hazards = true
	GameManager.set_control("rabbit")
	var shots := [
		["rock3", 2.7, "tide_rock_dip"],
		["rock3", 0.9, "tide_rock_crest"],
		["shark5", 0.6, "patrol_shark_charge"],
		# bias −18：时钟 3.75 是浪涌最高（−40，浮木上浮），1.25 是最低（+4）。
		["log6", 3.75, "swell_log_high"],
		["log6", 1.25, "swell_log_low"],
	]
	for shot in shots:
		var g: Dictionary = {}
		for it in hazard_groups:
			if String(it["group"]) == String(shot[0]):
				g = it
				break
		if g.is_empty():
			continue
		var start_x: float = _group_start(g)
		var pin_x: float = start_x - 210.0
		for i in 14:
			hazard_clock = float(shot[1])
			turtle.position = Vector2(pin_x, surface_ref())
			rabbit.position = turtle.get_mount_point()
			await get_tree().process_frame
		_save_shot("%s_%s.png" % [prefix, shot[2]])
	get_tree().quit(0)


func _capture_opening(file_name: String) -> void:
	await get_tree().create_timer(0.8).timeout
	_save_shot(file_name)
	get_tree().quit(0)


func _capture_standby(file_name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	test_disable_hazards = true
	GameManager.set_control("turtle")
	turtle.position = Vector2(5200.0, surface_ref())
	await get_tree().create_timer(2.0).timeout
	_save_shot(file_name)
	get_tree().quit(0)


## 失衡姿态证据（Phase G 后）：daze 封顶 3.6，只做短硬直/姿态，不定罪。
## 旧五段的 EDGE / CRITICAL（6.0 / 8.4）已不可达，对应旧截图已移入 _attic。
func _capture_imbalance() -> void:
	await get_tree().create_timer(0.35).timeout
	test_disable_hazards = true
	GameManager.has_shifted = true
	turtle.position = Vector2(4700.0, surface_ref())
	var poses := [["relaxed", 1.0], ["sliding", 2.5], ["capped", Tuning.DAZE_CAP]]
	for p in poses:
		# 每帧重新钉住：viewport 截图取的是上一帧画好的 HUD，
		# 只设一次会拍到上一档的数（capped 会被拍成 26%）。
		for i in 20:
			rabbit.daze_time = p[1]
			turtle.daze_time = p[1]
			await get_tree().process_frame
		_save_shot("stage4_poseg_%s.png" % p[0])
	get_tree().quit(0)


## Phase G 证据：一次乌龟浪击、一次兔子碰撞、第三格联合事故、演出后复位。
## 用现有的碰撞入口重放，HUD 和姿态都走真实主流程；不注入 OS 按键。
func _capture_penalty(prefix: String) -> void:
	await get_tree().create_timer(0.35).timeout
	test_disable_hazards = true
	GameManager.total_score = 1000
	turtle.position = Vector2(4700.0, surface_ref())
	turtle.speed = 0.0
	await get_tree().create_timer(0.2).timeout
	_turtle_contact("demo_wave")
	await get_tree().create_timer(0.25).timeout
	print("PENALTY DEMO 1 wave score=%d meter=%d state=%s" % [
		GameManager.total_score, GameManager.bro_meter, GameManager.accident_state])
	_save_shot("%s_hit_turtle.png" % prefix)
	# 等 dunk 结束、底部提示自然过期，再让兔子撞一下：
	# 两种事故表现要在同一组图里可比，且互不串提示。
	await get_tree().create_timer(3.0).timeout
	_rabbit_contact()
	await get_tree().create_timer(0.15).timeout
	print("PENALTY DEMO 2 rabbit score=%d meter=%d state=%s log=%s" % [
		GameManager.total_score, GameManager.bro_meter, GameManager.accident_state,
		str(GameManager.score_log.slice(-4))])
	_save_shot("%s_hit_rabbit.png" % prefix)
	await get_tree().create_timer(Tuning.STUN_TIME + 0.35).timeout
	_turtle_contact("demo_wave_2")
	# 联合演出 1.4 s；0.9 s 时闪白已退，画面能看清“3/3 + 联合惩罚”。
	await get_tree().create_timer(0.9).timeout
	print("PENALTY DEMO 3 full score=%d meter=%d state=%s pending=%s" % [
		GameManager.total_score, GameManager.bro_meter, GameManager.accident_state,
		GameManager.bro_joint_pending])
	_save_shot("%s_meter_full.png" % prefix)
	await get_tree().create_timer(1.2).timeout
	_save_shot("%s_recovered.png" % prefix)
	get_tree().quit(0)


## 兔子落水演出：耳朵打转 + X 眼 + 水花圈，0.5 s 时定格。
func _capture_fall(file_name: String) -> void:
	await get_tree().create_timer(0.35).timeout
	hazard_cooldown = 0.0
	_trigger_accident("RABBIT_WATER")
	await get_tree().create_timer(0.5).timeout
	_save_shot(file_name)
	get_tree().quit(0)


## 乌龟翻肚皮演出：0.6 s 从侧翻过渡到全翻，0.8 s 时定格（四肢朝天、X 眼）。
func _capture_flip(file_name: String) -> void:
	await get_tree().create_timer(0.35).timeout
	hazard_cooldown = 0.0
	_trigger_accident("TURTLE_REEF")
	await get_tree().create_timer(0.8).timeout
	_save_shot(file_name)
	get_tree().quit(0)


func _save_shot(file_name: String) -> void:
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	var image := get_viewport().get_texture().get_image()
	var path := dir.path_join(file_name)
	image.save_png(path)
	print("CAPTURE ", path)
