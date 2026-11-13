extends Node2D
## 阶段 3：一条 66000 px 的完整赛道，分三个区域连续比赛。
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
const WORLD_END := LevelDataScript.WORLD_END
const HAZARD_WARN := 270.0
## 表演需要的空档：1.8 s 表演 + 1.0 s 结束宽限 + 换人/起跳提前量，按 260 px/s 取约 900 px。
const SHOWTIME_CLEAR := 900.0
## 下沉门没有手动潜深，换人的时机就是全部：预警牌放在换人的最佳位置
## （灰盒实测 180–220 px 可过，200 px 余量最大），而不是通用 270 px。
const GATE_WARN := 200.0
const FINISH_DELAY := 1.6

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
var hazard_cooldown := 0.0
## REBUILD-05 E2：动态障碍共用的运动时钟（游戏秒）。
## 探针把物理推进停下来时可以手动置位，用它扫完整周期；
## 画和判定都读同一个 hazard_offset()，不存在“画的在动、判的是静止”。
var hazard_clock := 0.0
## REBUILD-06 P3：水下伏击鲨的逐组状态（组名 -> {phase, t}）。
## 相位由“玩家靠近”驱动，不是全局计时器：玩家看得到它什么时候醒。
## 只有 LUNGE 与水面航道相交；DOWN/TELEGRAPH 时整条鱼在 528～720。
var _ambush: Dictionary = {}
var turtle_repair := 0.0
var turtle_grace := 0.0
var rabbit_grace := 0.0
var rabbit_stun := 0.0
var emergency_timer := 0.0
var test_disable_hazards := false
var test_no_finish := false
var show_hitboxes := false
## F3 调试层：障碍 ID/类型/预期动作、判定框、触发距离、危险深度线。
## 关闭后世界里的开发文字、辅助线和碰撞框全部消失。
var debug_mode := false
var combo := 0
var combo_max := 0
var passed_groups := {}
var entered_groups := {}
var hit_groups := {}
## REBUILD-05 B2：每组的“谁撞过”。{group_key: {"rabbit": true, "turtle": true}}
## hit_groups 仍然表示“这组已经出过事”，供通过/精准判定使用；
## hit_roles 让两个角色各记一次，不再因为兔子先命中就吞掉乌龟的碰撞。
var hit_roles := {}
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
var showtime_active := false
var showtime_t := 0.0
var showtime_prev_control := "rabbit"
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
			or "--capture-bird" in args or "--capture-motion" in args:
		GameManager.state = GameManager.GameState.RUNNING
	if "--capture-stage2" in args:
		_capture_after(1.0, "stage2_hud.png")
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
	if "--capture-coop" in args:
		_capture_coop(_arg_after(args, "--capture-coop", "coop"))


## P2-7：开场只在正式运行出现。截图/测试默认关掉，只有 --capture-opening、
## --force-opening 显式要求时挂载，避免影响既有证据链。
func _opening_wanted() -> bool:
	var args := OS.get_cmdline_user_args()
	if "--capture-opening" in args or "--force-opening" in args:
		return true
	if "--no-opening" in args:
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
func load_level(groups: Array, lanes: Array) -> void:
	hazard_groups = groups
	boost_lanes = lanes
	reset_brains()
	group_actions.clear()
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
	_last_drift_rank = {"rabbit": 0, "turtle": 0}


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

	# BRO METER 第三格：事故恢复完成后播联合惩罚，然后复位、清空、短暂保护。
	if joint_show_t > 0.0:
		joint_show_t = maxf(joint_show_t - delta, 0.0)
		_hold_joint_pose()
		_update_display()
		_update_camera()
		queue_redraw()
		if joint_show_t <= 0.0:
			_end_joint_show()
		return
	if GameManager.bro_joint_pending and GameManager.accident_state == "NONE" \
			and emergency_timer <= 0.0:
		_start_joint_show()
		return

	var control: String = GameManager.current_control
	var rabbit_down: bool = GameManager.accident_state in [
		"RABBIT_SLIP", "RABBIT_WATER", "RABBIT_AIR", "OXYGEN_OUT"
	]
	var turtle_controlled: bool = control == "turtle" and not turtle.accident
	var rabbit_controlled: bool = control == "rabbit" and not rabbit_down \
		and rabbit_stun <= 0.0 and not showtime_active
	# Phase O：加速只来自“操控乌龟吃下能量海藻”，不是进带自动提速。
	# 吃下后是整组 TURBO：换兔子做动作时也继续，直到该遭遇的障碍通过 + 180 px。
	var boosting: bool = snack_boost_active()
	# BRO BRAIN：事故演出/Showtime 期间冻结神游，不从演出里额外收惩罚。
	var attentive: bool = GameManager.accident_state == "NONE" and not showtime_active
	rabbit_brain.tick(delta, rabbit_controlled, attentive)
	turtle_brain.tick(delta, turtle_controlled, attentive)
	rabbit.drift = rabbit_brain.drift
	rabbit.drift_state = rabbit_brain.state_name()
	turtle.drift = turtle_brain.drift
	turtle.drift_state = turtle_brain.state_name()
	turtle.food_ahead = snack_ahead_distance()
	_tick_drift_feedback()
	# P0-3：兔子在 MISCHIEF 时，靠近低梁/海鸟会站直探头（错误姿势）。
	# 只读下一个障碍的类型/距离；不触发事故、不写 BRO METER。切回兔子即取消。
	var near_info: Dictionary = next_hazard_info()
	var near_kind: String = String(near_info.get("kind", ""))
	var near_dist: float = float(near_info.get("distance", 1.0e9))
	rabbit.mischief_pose = not rabbit_controlled \
		and rabbit_brain.state_name() == "MISCHIEF" \
		and near_kind in ["LOW_BEAM", "LOW_BIRD"] \
		and near_dist <= Tuning.MISCHIEF_POSE_NEAR
	# 垂直轴只属于乌龟：↑ 跃起、↓ 下潜。↑ 同时是兔子的跳跃键，
	# 但同一时刻只有一个角色受控，所以不会互相抢输入。
	var vertical := 0.0
	if turtle_controlled:
		if Tuning.SURFBOARD_PHYSICS:
			# 下潜只在玩家按住 ↓ 时成立；松开就按浮力上浮。
			# 不再有“尾端自动上浮”：接人时机是玩家的操作（BRO DIVE 的要求）。
			if Input.is_action_pressed("down"):
				vertical = 1.0
		else:
			vertical = Input.get_axis("up", "down")
	if emergency_timer > 0.0:
		# 氧气耗尽：强制上浮，玩家暂时只能看着。
		vertical = -1.0
		boosting = false

	# CORE-FEEL-07 P0-A：辅助下潜只改写“按不按下潜”，不改速度、不挪位置。
	# 1 = 保持下潜；-1 = 自动上浮（按浮力回到巡航水深，不是氧气强制上浮）。
	var dive_assist_axis := _tick_dive_assist(delta, turtle_controlled)
	if emergency_timer <= 0.0:
		if dive_assist_axis > 0:
			vertical = 1.0
		elif dive_assist_axis < 0:
			vertical = 0.0

	# 乌龟跃起：整组上抛，兔子被带动，不需要再按跳。
	# 只受控时触发；SHIFT 只交权，不提供免费动作。
	if turtle_controlled and Tuning.SURFBOARD_PHYSICS \
			and GameManager.accident_state in ["NONE", "RABBIT_AIR"] \
			and not showtime_active and _buffered_ready("up"):
		if turtle.start_leap():
			_consume_buffered("up", "turtle_leap")
			GameManager.feedback.emit(Locale.t("feedback.leap"), "pop")

	_update_snack(delta)

	# 待命不恶化、也不替玩家清失衡：auto_cruise 只保留给旧模型兼容。
	turtle.dive_assist_active = dive_assist == "ACTIVE"
	turtle.tick(delta, turtle_controlled, boosting, vertical,
		true, snack_boost_speed if boosting else Tuning.BOOST_SPEED)

	# 可跳状态的宽限：壳刚沉下去/刚离开台面时还允许 100 ms 的补救跳。
	var jumpable_now: bool = rabbit_controlled and mount.state == "RIDING" \
		and not turtle.leap_active and turtle.is_at_surface()
	if jumpable_now:
		_coyote_t = JUMP_COYOTE_TIME
	else:
		_coyote_t = maxf(_coyote_t - delta, 0.0)

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
	if emergency_timer <= 0.0:
		_check_hazards()
		_resolve_turtle_solid()

	# Phase G：daze_time 不再单独触发事故。它只是姿态/短硬直，
	# 每一次有效失误都在发生当下记进 BRO METER，第三格才出联合事故。

	_update_oxygen(delta)
	_update_combo()
	_update_lessons()
	_update_snack_lesson()
	_update_z3_warning(delta)
	_update_display()
	_update_camera()

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
		var kind: String = g["kind"]
		if lesson_seen.has(kind):
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
		lesson_seen[kind] = true
		GameManager.prompt.emit(_lesson_prompt(kind))
		return


## REBUILD-05 G6：13 组动态障碍此前没有任何教学——第一组会动的岩上下起伏时，
## 玩家只会以为判定飘了。每区第一组会动的障碍进入 560 px 时底栏提一句；同区不再重复。
## 事故期间由 _update_lessons 的早退压住，不抢救援提示。
func _update_motion_lesson() -> void:
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
		GameManager.hint.emit(Locale.t("hint.motion"))
		return


## 首次教学文案按“当前控的是谁”取：已经控乌龟时再叫玩家按 SHIFT，
## 会把人送到兔子身上，正好错过这一组。兔子专属障碍提示先换回来，
## 乌龟专属障碍去掉多余的 SHIFT。
func _lesson_prompt(kind: String) -> String:
	var on_rabbit := GameManager.current_control == "rabbit"
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
	return rabbit_boost_until_x > 0.0 and turtle.position.x < rabbit_boost_until_x


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
	if by == "rabbit":
		# 兔子吃：自己的跳跃强化，乌龟不加速也不冷静——这正是“给谁吃”的取舍。
		rabbit_boost_until_x = end_x + Tuning.RABBIT_SNACK_TAIL
		rabbit.jump_boost = Tuning.RABBIT_SNACK_JUMP_SCALE
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


## 按键事件发生时立刻记录：此刻的 shift_count 就是“按下时已经换了几次人”。
func _note_up_input() -> void:
	_buf_action = "up"
	_buf_age = 0.0
	_buf_shift_count = GameManager.shift_count
	_buf_event_msec = Time.get_ticks_msec()


func _buffered_ready(action: String) -> bool:
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
		max_time: float = Tuning.CARRY_MAX_TIME) -> void:
	var from: Vector2 = rabbit.position
	var dist: float = from.distance_to(mp)
	GameManager.pickup_window = false
	if dist <= Tuning.CARRY_SNAP_DIST:
		rabbit.attach(mp)
		mount.mark_riding()
		_apply_carry_result(kind)
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
	var target: Vector2 = turtle.get_mount_point()
	var next: Vector2 = carry_from.lerp(target, ease)
	carry_max_step = maxf(carry_max_step, next.distance_to(rabbit.position))
	rabbit.position = next
	if k >= 1.0:
		var kind: String = carry_kind
		carry_kind = ""
		carry_dur = 0.0
		rabbit.attach(target)
		mount.mark_riding()
		_apply_carry_result(kind)


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
	GameManager.accident_state = "NONE"
	GameManager.oxygen = maxf(GameManager.oxygen, Tuning.OXYGEN_RECOVERED)
	rabbit_grace = Tuning.GRACE_TIME
	GameManager.rescue_done.emit()


func _tick_rabbit(delta: float, rabbit_controlled: bool, boosting: bool) -> void:
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
		if rabbit_stun > 0.0:
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
				_begin_carry("pickup", mp)
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
			_rescue_miss(_rescue_miss_reason(mp))
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
	# 入水不是停住：保留下落速度的一大半，兔子先扎进去再被水拖住。
	rabbit.velocity.y *= Tuning.RESCUE_ENTRY_KEEP_VY
	mount.mark_rescue_active(Tuning.RESCUE_ACTIVE_TIME)


## 主动救援成功：兔子抓住壳，回到骑乘；这是一次玩家动作，不是计时器放回。
func _rescue_catch(mp: Vector2) -> void:
	rescue_last_result = "caught"
	rescue_last_reason = "caught"
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
	hazard_cooldown = Tuning.TURTLE_COOLDOWN if reason == "TURTLE_REEF" \
		else Tuning.HAZARD_COOLDOWN
	accident_flash = Tuning.ACCIDENT_FLASH
	_accident_t = 0.0
	GameManager.accident_state = reason
	# accident_count / 扣分 / BRO METER 都在 note_accident -> note_mistake 里，
	# 避免事故入口与海浪碰撞各记一套。
	# CORE-FEEL-07 P0-B：同一个障碍的第二笔只是同一个事件，不重复记账；
	# 落水/硬直等物理后果照常发生，玩家看到的反馈不会被吞。
	if charge:
		GameManager.note_accident(reason)
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
	return true


## 现在能不能记一次新事故。碰撞前先问，避免“标脏了却没记账”的静默漏判。
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
	GameManager.feedback.emit(Locale.t(fb), "hit")
	GameManager.hint.emit(Locale.t(hn))
	# 记录仍然是一格 BRO METER（不新增惩罚系统）；原因标签按实际障碍区分。
	# CORE-FEEL-07 P0-B：同一障碍的同一件事只记一次。第二次命中仍然播
	# 停顿/震动/掀翻/减速，但不再扣分——表现不吞，账目不重复。
	if charge:
		GameManager.note_mistake(
			"TURTLE_DIVE_LATE" if kind == "FLOATING_LOG" else "TURTLE_WAVE")


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
				"LOW_BEAM", "LOW_BIRD":
					# A 类：只占兔子站立的那一层。趴在壳上就过，龟壳不受影响。
					rabbit_hit = rabbit_can_hit and not roles.has("rabbit") \
						and rabbit.state != "CROUCHING" and r_rect.intersects(rect)
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
					rabbit_hit = rabbit_can_hit and not roles.has("rabbit") \
						and r_rect.intersects(rect)
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
				# REBUILD-05 G21：撞过就重新武装这一类型的首次教学。
				# 原来一局只教一次：第一组海鸟没躲过，后面 3 组同类型就再没人提醒，
				# 玩家已经知道“这里有问题”却不知道“该怎么办”。撞出真实失误
				# （applied = 真的记了账，冷却/事故中挡下的不算）后清掉标记，
				# 下一组同类型进入提示范围时会再说一遍；干净通过不清，
				# 所以“看懂了”的人不会被打扰，其他类型也不受影响。
				# G22：补教只给一次。撞第二组时不再重新武装——同一句话说第三遍
				# 不会让人更懂，只会盖住别的提示。
				if not lesson_retaught.has(kind):
					lesson_retaught[kind] = true
					lesson_seen.erase(kind)
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
	for g in hazard_groups:
		var group: Dictionary = g
		var kind := String(group["kind"])
		if kind in ["LOW_BEAM", "LOW_BIRD", "SURFACE_ROCK"]:
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
				continue
			turtle.position.x = minf(turtle.position.x,
				rect.position.x - tr.size.x * 0.5)
			tr = _inset(turtle.get_body_rect(), 3.0)
	# 壳被顶住时，坐在上面的兔子跟着一起退，不能自己留在墙里。
	var dx: float = turtle.position.x - before_x
	if dx != 0.0 and mount.state == "RIDING":
		rabbit.position.x += dx
		rescue_prev_pos.x += dx


func _update_oxygen(delta: float) -> void:
	if emergency_timer > 0.0 or GameManager.accident_state != "NONE":
		return
	if mount.state != "RIDING":
		return
	var air_line := SURFACE_Y + 20.0
	if Tuning.SURFBOARD_PHYSICS:
		air_line = Tuning.NEUTRAL_DEPTH + Tuning.OXYGEN_DEPTH_MARGIN
	if turtle.position.y > air_line:
		GameManager.oxygen = maxf(GameManager.oxygen - delta * Tuning.OXYGEN_DRAIN, 0.0)
		if GameManager.oxygen <= 0.0:
			_trigger_accident("OXYGEN_OUT")
	else:
		GameManager.oxygen = minf(
			GameManager.oxygen + delta * Tuning.OXYGEN_RECOVER, Tuning.OXYGEN_MAX)
	var phase := oxygen_phase()
	if phase != _oxygen_phase:
		if phase == "LOW":
			GameManager.hint.emit(Locale.t("hint.air_low"))
		elif phase == "CRITICAL":
			GameManager.hint.emit(Locale.t("hint.air_critical"))
		_oxygen_phase = phase
	GameManager.oxygen_phase = phase


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
				combo = mini(combo + 1, Tuning.SHOWTIME_COMBO)
				combo_max = maxi(combo_max, combo)
				var kind: String = String(group["kind"])
				var act: Dictionary = group_actions.get(key, {})
				var precise := _precise_action(kind, act)
				if precise:
					# 连招整段完成才给 250/300；精准单动作 150；其余干净通过 100。
					GameManager.note_precise_pass(kind)
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
				# §七-9：连招里程碑放在同一帧最后——否则会被“干净通过”当场盖掉。
				if combo >= Tuning.SHOWTIME_COMBO:
					GameManager.feedback.emit(Locale.t("feedback.bro_combo"), "bro")
	GameManager.combo = combo
	GameManager.combo_max = combo_max
	if combo >= Tuning.SHOWTIME_COMBO and not showtime_active \
			and GameManager.accident_state == "NONE" and mount.state == "RIDING" \
			and _showtime_clear_ahead():
		start_showtime()


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


func start_showtime() -> void:
	if showtime_active or GameManager.accident_state != "NONE":
		return
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
	if p < 0.31:
		var q := p / 0.31
		offset = -sin(q * PI) * 90.0
		spin = q * TAU * 2.0
	elif p < 0.64:
		offset = -absf(sin((p - 0.31) * 30.0)) * 6.0
		spin = TAU * 2.0
	else:
		offset = -4.0
		spin = TAU * 2.0
	rabbit.state = "SHOWTIME"
	rabbit.showtime_spin = spin
	rabbit.showtime_pose = p >= 0.64
	rabbit.position = base + Vector2(0.0, offset)
	if showtime_t >= Tuning.SHOWTIME_TIME:
		_end_showtime(true)


func _end_showtime(completed: bool) -> void:
	if not showtime_active:
		return
	showtime_active = false
	GameManager.showtime_active = false
	rabbit.showtime_spin = 0.0
	rabbit.showtime_pose = false
	rabbit.attach(turtle.get_mount_point())
	mount.mark_riding()
	if completed:
		# Showtime 不再瞬间回满氧气，只给小幅回复；氧气不能被表演白送。
		GameManager.oxygen = minf(GameManager.oxygen + Tuning.SHOWTIME_OXYGEN,
			Tuning.OXYGEN_MAX)
		GameManager.oxygen_phase = oxygen_phase()
		GameManager.showtime_count += 1
		GameManager.note_showtime()
		turtle_grace = 1.0
		rabbit_grace = 1.0
		GameManager.center_message.emit(Locale.t("center.brotherhood"),
			Color(1.0, 0.85, 0.25))
	else:
		# 中断：跳过提示期，兔子直接从滑落读秒；控制权不抢。
		rabbit.force_slip()
		rabbit_grace = 0.0
		GameManager.center_message.emit(Locale.t("center.shows_over"),
			Color(0.8, 0.85, 0.9))


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
		var st: Dictionary = _ambush.get(key, {"phase": "DOWN",
			"t": Tuning.SHARK_REARM_TIME})
		var phase := String(st["phase"])
		var t := float(st["t"]) + delta
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
				if t >= Tuning.SHARK_TELEGRAPH_TIME:
					phase = "LUNGE"
					t = 0.0
		_ambush[key] = {"phase": phase, "t": t}


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
func _on_shift_take(_from: String, to: String) -> void:
	# CORE-FEEL-07 P0-A：起跳之后 SHIFT 到乌龟，就是“该下潜了”。
	# 这里只接住“已经上膛”的组合；没起跳就 SHIFT 不会凭空下潜。
	if to == "turtle" and dive_assist == "ARMED" and mount.state == "AIRBORNE" \
			and turtle.position.x < dive_assist_end + DIVE_ASSIST_PASS_PX:
		dive_assist = "ACTIVE"
		dive_assist_t = 0.0
	var brain = rabbit_brain if to == "rabbit" else turtle_brain
	if brain == null:
		return
	if String(brain.state_name()) == "CALM":
		return
	GameManager.feedback.emit(Locale.t("feedback.shift_take",
		[Locale.t("who." + to)]), "bro")


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
	if event.is_action_pressed("shift") and showtime_active:
		_end_showtime(false)
		get_viewport().set_input_as_handled()
		return
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
	var world_width := world_end + 900.0
	# 三个区域各画一段背景；区域边界和名字直接画在世界里。
	for zone in LevelDataScript.ZONES:
		var x0: float = zone["start"] - 400.0
		var w: float = zone["end"] - zone["start"] + 400.0
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

	# 危险深度线只在 F3 调试层出现；正常界面没有红线。
	if debug_mode:
		draw_line(Vector2(-400, 740), Vector2(world_width, 740),
			Color(1.0, 0.3, 0.25, 0.5), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(turtle.position.x - 200, 726),
			Locale.t("world.danger_depth"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(1.0, 0.5, 0.45, 0.7))

	_draw_snacks()
	_draw_z3_warning()
	draw_rect(Rect2(world_end, 120, 16, 700), Color(1.0, 0.85, 0.2))
	draw_string(ThemeDB.fallback_font, Vector2(world_end - 50, 100),
		Locale.t("world.finish"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.85, 0.2))

	var cam_x: float = camera.position.x if camera != null else turtle.position.x
	for g in hazard_groups:
		var group: Dictionary = g
		for i in group["rects"].size():
			_draw_hazard(group, i)
		if not group.get("motion", {}).is_empty():
			_draw_motion_cue(group)
		if debug_mode and absf(LevelDataScript.group_start(group) - cam_x) <= 1700.0:
			_draw_debug_group(group)

	_draw_action_fx()
	_draw_turtle()
	# 吞食反馈画在乌龟之后：食物被“吸进嘴里”，不是糊在壳后面。
	if snack_gulp_t > 0.0:
		_draw_gulp_fx()
	_draw_rabbit()
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
			"BRO DIVE" if dive else "BRO OLLIE",
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
	var label := "#%s  %s  %s  ROLE:%s  ->  %s   d=%d px  t=%.1fs" % [
		group["group"], group["kind"], _category_of(group["kind"]), role,
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
		"SAFE ABOVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 1.0, 0.6, 0.9))
	var lower := Rect2(rect.position.x, rect.end.y, rect.size.x,
		760.0 - rect.end.y)
	draw_rect(lower, Color(0.3, 0.8, 1.0, 0.12))
	draw_rect(lower, Color(0.3, 0.8, 1.0, 0.45), false, 2.0)
	draw_string(ThemeDB.fallback_font,
		Vector2(rect.position.x + 4, rect.end.y + 18.0),
		"SAFE BELOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.9, 1.0, 0.9))


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
	elif d > -160.0:
		y = strike_y + sin(t * 7.0) * 3.0
		p = 1.0
		phase = "STRIKE"
	elif d > -520.0:
		var q := clampf((-160.0 - d) / 360.0, 0.0, 1.0)
		y = lerpf(strike_y, high_y, smoothstep(0.0, 1.0, q))
		tilt = 0.34 * sin(PI * q)
		phase = "RECOVER"
	else:
		y = high_y + sin(t * 2.2) * 5.0
	# 翅膀张开的程度：俯冲末段到攻击段完全展开，横着盖住主判定带。
	var flare := 0.0
	if phase == "DIVE":
		flare = smoothstep(0.55, 1.0, p)
	elif phase == "STRIKE":
		flare = 1.0
	elif phase == "RECOVER":
		flare = 1.0 - clampf((-160.0 - d) / 200.0, 0.0, 1.0)
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
	var cx := band.position.x + band.size.x * 0.5
	var y: float = pose["y"]
	var strike_y: float = pose["strike_y"]
	var high_y: float = pose["high_y"]
	var d: float = pose["d"]
	var phase: String = pose["phase"]
	var flare: float = pose["flare"]
	var t := Time.get_ticks_msec() * 0.001

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


## REBUILD-05 E2：动态障碍的“行程线”。
## 目的不是装饰，是让玩家在 1100 px 外就能读出两件事：
##   1. 它会在哪一段范围里来回动（静止位置 + 两端）
##   2. 它现在走到哪了（游标点）
## 灰盒规则：全部是 Primitive（line/circle），可整段替换。
func _draw_motion_cue(group: Dictionary) -> void:
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


func _draw_hazard(group: Dictionary, index: int) -> void:
	var kind: String = group["kind"]
	# REBUILD-05 E2：画的就是判的那一个矩形（同一个 hazard_rect_live）。
	var rect := hazard_rect_live(group, index)
	if kind == "LOW_BIRD":
		# 海鸟是唯一一个“按距离改变姿态”的障碍：只画一次，用 rect[0] 主带定位。
		if index == 0:
			_draw_bird(group)
		return
	match kind:
		"SURFACE_ROCK":
			draw_rect(rect, Color(0.31, 0.3, 0.29))
			draw_circle(rect.position + Vector2(rect.size.x * 0.3, rect.size.y * 0.5),
				28.0, Color(0.38, 0.36, 0.34))
			draw_circle(rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.45),
				24.0, Color(0.35, 0.33, 0.31))
			draw_line(Vector2(rect.position.x, rect.end.y),
				Vector2(rect.end.x, rect.end.y), Color(0.13, 0.12, 0.11), 6.0)
			for i in 4:
				var fx := rect.position.x + 18.0 + i * 34.0
				draw_circle(Vector2(fx, rect.end.y + 4.0), 5.0,
					Color(0.7, 0.95, 1.0, 0.7))
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
				var swell_y := SURFACE_Y + hazard_offset(group).y
				var swell := PackedVector2Array()
				for i in 17:
					var px := lx - 150.0 + i * (lw + 300.0) / 16.0
					swell.append(Vector2(px,
						swell_y + sin(px * 0.045 + hazard_clock * 2.4) * 5.0))
				draw_polyline(swell, Color(0.75, 0.96, 1.0, 0.55), 3.0)
				draw_line(Vector2(lx, swell_y), Vector2(lx + lw, swell_y),
					Color(0.75, 0.96, 1.0, 0.5), 2.0)
			var log_above := Rect2(lx, rect.position.y,
				lw, maxf(SURFACE_Y - rect.position.y, 0.0))
			var log_under := Rect2(lx, maxf(SURFACE_Y, rect.position.y),
				lw, rect.end.y - maxf(SURFACE_Y, rect.position.y))
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
			draw_rect(rect, Color(0.44, 0.4, 0.36))
			draw_rect(rect, Color(0.18, 0.16, 0.14), false, 3.0)
			var rows := 2 if rect.size.y < 40.0 else 6
			for i in rows:
				var by := rect.position.y + rect.size.y * float(i + 1) / float(rows + 1)
				draw_line(Vector2(rect.position.x + 3.0, by),
					Vector2(rect.end.x - 3.0, by),
					Color(0.3, 0.27, 0.24, 0.85), 2.0)



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


func _draw_turtle() -> void:
	# 受激动作只偏移画法；撞击框/落点仍用 turtle.position。
	var pos: Vector2 = turtle.position + _shift_jolt_offset("turtle")
	# P1-5：撞击的 90 ms 里把“画出来的壳”按在撞击点，物理照常走。
	if _hitstop_t > 0.0 and _hitstop_who == "turtle":
		pos = _hitstop_draw + _shift_jolt_offset("turtle")
	# G9：兔子落回壳上/被接住时整只壳往下沉再回弹；只是画法偏移。
	pos.y += shell_dip_offset()
	if turtle.speed > 250.0:
		for i in 3:
			var y := pos.y - 24.0 + i * 22.0
			draw_line(Vector2(pos.x - 90.0 - i * 18.0, y),
				Vector2(pos.x - 50.0 - i * 18.0, y),
				Color(0.75, 1.0, 1.0, 0.55), 4.0)
	# 壳画成 92x56 的椭圆，和 96x56 的碰撞体对齐，避免“看着撞了却没判”。
	# 失控时整只侧倾 + 缓慢左右摇：前两段只有一点倾斜，看得到“不太稳”，
	# 临界时倾到 0.22 rad 并来回摇，读到“要翻了”。
	var tilt: float = turtle_tilt()
	if tilt > 0.0:
		tilt += sin(Time.get_ticks_msec() * 0.0024) * tilt * 0.5
	if turtle.accident:
		# 翻肚皮后来回晃两下（幅度随翻完程度增大）：喜剧感靠“晃”，不靠拉长演出。
		tilt += sin(_accident_t * 7.0) * 0.14
	var shell := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		shell.append(pos + Vector2(cos(a) * 46.0, sin(a) * 28.0).rotated(tilt))
	draw_colored_polygon(shell, Color(0.25, 0.6, 0.3))
	# BRO BRAIN：待命神游时头会左右张望 / 盯着食物；只动头，不动壳的判定。
	var look: Vector2 = turtle.drift_look_px(GameManager.current_control == "turtle")
	var head_base := pos + Vector2(40, -6).rotated(tilt) + look
	draw_circle(pos + Vector2(0, -6).rotated(tilt), 27.0, Color(0.55, 0.8, 0.35))
	draw_circle(head_base, 14.0, Color(0.4, 0.7, 0.3))
	draw_circle(head_base + Vector2(4, -4), 3.0, Color(0.05, 0.1, 0.08))
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
		_draw_drift_mark(pos + Vector2(46, -80), "turtle",
			drift_mark_text("turtle"), _drift_color_for(turtle.drift_state),
			20 + _drift_level_for(turtle.drift_state) * 2)
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


func _draw_rabbit() -> void:
	# 同上：受激动作是画法偏移，不改变兔子真实位置。
	var pos: Vector2 = rabbit.position + _shift_jolt_offset("rabbit") \
		+ celebration_offset()
	# P1-5：兔子被撞的 50 ms 里画在撞击点；读作“撞住了”，不影响落水/救援判定。
	if _hitstop_t > 0.0 and _hitstop_who == "rabbit":
		pos = _hitstop_draw + _shift_jolt_offset("rabbit")
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
		draw_string(ThemeDB.fallback_font, pos + Vector2(-48, -58), "720!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.25))

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
		# G8：环是“落壳走廊”（下落中对准壳），从 -150 px 就亮；
		# 文字仍是“接住了”，只在真正进吸附区（-60）时出现，不提前报喜。
		var hint_pos: Vector2 = turtle.get_mount_point()
		draw_arc(hint_pos, 82.0, 0, TAU, 48, Color(0.4, 1.0, 0.6), 4.0)
		if rabbit.position.y - hint_pos.y >= Tuning.PICKUP_DY_MIN:
			draw_string(ThemeDB.fallback_font,
				hint_pos + Vector2(-42, -96), Locale.t("hint.pickup"),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.4, 1.0, 0.6))


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
	draw_circle(bubble, 16.0, Color(0.05, 0.10, 0.14, 0.55))
	draw_arc(bubble, 16.0, 0, TAU, 24, Color(color.r, color.g, color.b, 0.85), 1.5)
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
