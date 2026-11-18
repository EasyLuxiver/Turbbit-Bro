extends Node2D
## 乌龟：自动巡航 / 加速 / 下潜 / 上浮 / 神游下沉。
## 失控按 GDD 5.6 分三段：失去动力（DAZED）→ 缓慢下沉（SINKING）→
## 接近危险深度（DEEP）→ 事故。位置与时间同时参与判断。

const Tuning = preload("res://scripts/systems/tuning.gd")
const SURFACE_Y := 300.0
const DEEP_Y := 760.0
const BASE_SPEED := 220.0
const BOOST_SPEED := 330.0
const VERTICAL_SPEED := 180.0
const BODY_SIZE := Vector2(96, 56)

var speed := BASE_SPEED
## 区域基础速度：由 race 按当前赛段写入，220 → 240 → 260。
var base_speed := BASE_SPEED
var state := "CRUISING"
var accident := false
var daze_time := 0.0
var control_hold := 0.0
var _sink_speed := 0.0
## 冲浪板模型的垂直速度（px/s，正=下沉）。受控时由浮力驱动，失控时由下沉驱动。
var _vy := 0.0
## 兔子滞空期间壳不沉：兔子只是跳起来了，不是不管乌龟。
var hold_depth := false
## 主动跃起（↑）：带动整组向上跳，躲水下攻击。一次性，落回巡航水深。
var leap_active := false
var leap_timer := 0.0
var leap_cooldown := 0.0
var leap_count := 0
## 主动下潜（↓）：按住下到巡航水深以下，松开/通过后自动上浮。
## 不是事故状态，也不累积失衡。
var diving := false
## FEEL-11 B2：被切出时把当前下潜再维持 0.55 s，让待命角色“做完这个动作”，
## 也构成“BITT 继续潜行、玩家接管 TUBO”的电流接力。
var standby_dive_t := 0.0
## FEEL-12：旋壳过载的表现计时（race 写入，画法读）。
var overdrive_spin_t := 0.0
## FEEL-12 补充 B：BRO CATCH 的目标水深；-1 表示不使用。
var catch_target_y := -1.0
## CORE-FEEL-07 P0-A：辅助下潜期间由 race 写入。只加快“主动下潜”的沉速，
## 深度上限、浮力上浮、碰撞体都不动；辅助结束当帧写回 false。
var dive_assist_active := false
## 被浪拍中后整组短暂没入水下：氧气消耗因此有真实来源。
var dunk_timer := 0.0
## REFINE-06 P5：浪击把壳掀成肚皮朝天。纯表现计时——位置、碰撞、判定都不动。
var flip_t := 0.0
## 掀翻后的冷却：贴着鲨鱼连续被拍时，整段“肚皮朝天”不会一直卡着播。
var flip_lock := 0.0
## BRO BRAIN：race 每帧写入的未受控神游量（秒）与状态名。
## 乌龟待命不再冻结成巡航贴图：会东张西望、上下晃、被食物勾走注意力。
var drift := 0.0
var drift_state := "CALM"
## 最近一个未吃食物的前方距离（race 写入）；< 0 表示没有。
var food_ahead := -1.0
## CORE-FEEL-08 P0-A：恶作剧时壳自己漂的目标深度偏移（px），由 race 每帧写入。
## 只是 want_y 的一个小偏移，不是下潜：玩家按 ↓ 时目标深度整段覆盖它。
var autodrift_px := 0.0
## 漏电命中后的短时“被电麻”，暂时不能下潜。
var zap_stun_t := 0.0
## 速度上限：兔子落水后 race 把乌龟压到 90（找人），其余时候是无穷大。
var speed_cap := 1.0e9
var _brain_t := 0.0


func reset(start_pos: Vector2) -> void:
	position = start_pos
	speed = BASE_SPEED
	base_speed = BASE_SPEED
	state = "CRUISING"
	accident = false
	daze_time = 0.0
	control_hold = 0.0
	_sink_speed = 0.0
	_vy = 0.0
	leap_active = false
	leap_timer = 0.0
	leap_cooldown = 0.0
	leap_count = 0
	diving = false
	standby_dive_t = 0.0
	overdrive_spin_t = 0.0
	catch_target_y = -1.0
	dive_assist_active = false
	dunk_timer = 0.0
	flip_t = 0.0
	flip_lock = 0.0
	drift = 0.0
	drift_state = "CALM"
	food_ahead = -1.0
	autodrift_px = 0.0
	zap_stun_t = 0.0
	speed_cap = 1.0e9
	_brain_t = 0.0


func tick(delta: float, controlled: bool, boosting: bool, vertical: float,
		auto_cruise: bool, boost_target: float = BOOST_SPEED) -> void:
	# P5：掀翻只走表现计时；accident 的早退不影响它自然走完。
	if flip_t > 0.0:
		flip_t = maxf(flip_t - delta, 0.0)
	if flip_lock > 0.0:
		flip_lock = maxf(flip_lock - delta, 0.0)
	if accident:
		speed = move_toward(speed, 0.0, 480.0 * delta)
		position.x += speed * delta
		return

	if Tuning.SURFBOARD_PHYSICS:
		_tick_surfboard(delta, controlled, boosting, vertical, auto_cruise, boost_target)
		position.x += speed * delta
		return

	if controlled or auto_cruise:
		if auto_cruise:
			# 开局/事故宽限：完整重置，避免第一次 SHIFT 前和恢复期立刻下沉。
			daze_time = 0.0
			control_hold = 0.0
			_sink_speed = 0.0
		else:
			# 连续控制满 0.5 s 才开始恢复；已经下沉的深度和计时不因切换清零。
			control_hold += delta
			if control_hold >= Tuning.CONTROL_RECOVER_DELAY:
				daze_time = maxf(daze_time - Tuning.CONTROL_RECOVER_RATE * delta, 0.0)
		var target := boost_target if (controlled and boosting) else base_speed
		target = minf(target, speed_cap)
		var accel := 420.0 if target > speed else 300.0
		speed = move_toward(speed, target, accel * delta)

		var vy := vertical * VERTICAL_SPEED if controlled else 0.0
		if position.y <= SURFACE_Y and vy < 0.0:
			vy = 0.0
		position.y = clampf(position.y + vy * delta, SURFACE_Y, DEEP_Y)

		if controlled and position.y > SURFACE_Y + 2.0:
			state = "DIVING" if vy >= 0.0 else "SURFACING"
		elif controlled:
			state = "BOOSTING" if boosting else "CRUISING"
		else:
			state = "CRUISING"
		# 受控时保留 _sink_speed：再次失控会从当前下沉速度继续，而不是免费的归零。
	else:
		# FEEL-26：待命乌龟不再因为“离开控制时间”掉速/下沉。
		# 它保持巡航速度与巡航水深；救援时由 speed_cap 限制。
		control_hold = 0.0
		daze_time = 0.0
		_sink_speed = 0.0
		state = "CRUISING"
		var target := minf(base_speed, speed_cap)
		speed = move_toward(speed, target, 420.0 * delta)
		position.y = move_toward(position.y, Tuning.NEUTRAL_DEPTH, 180.0 * delta)

	position.x += speed * delta


## 冲浪板模型：没有手动上下、没有速度档位。
## 永远自动巡航；受控时进加速带自动提速。待命保持巡航水深，不下沉。
## 失衡只由事件（浪击/撞击/特殊动作失败）累积，受控稳定操控时回落。
func _tick_surfboard(delta: float, controlled: bool, boosting: bool,
		vertical: float, _auto_cruise: bool, boost_target: float) -> void:
	_brain_t += delta
	leap_cooldown = maxf(leap_cooldown - delta, 0.0)
	if dunk_timer > 0.0:
		dunk_timer = maxf(dunk_timer - delta, 0.0)
	zap_stun_t = maxf(zap_stun_t - delta, 0.0)

	# 速度：自动巡航。旧 BroBrain 掉速已停用，速度只受 TURBO/碰撞/救援状态影响。
	var target := base_speed
	if boosting:
		target = boost_target
	target = minf(target, speed_cap)
	var accel := 420.0 if target > speed else 300.0
	speed = move_toward(speed, target, accel * delta)

	# 失衡：受控稳定操控 0.5 s 后按 2.5/s 收回；待命冻结（不涨也不掉）。
	if controlled:
		control_hold += delta
		if control_hold >= Tuning.CONTROL_RECOVER_DELAY:
			daze_time = maxf(daze_time - Tuning.CONTROL_RECOVER_RATE * delta, 0.0)
	else:
		control_hold = 0.0

	# 主动跃起：整组上抛，兔子被带动，不需要重复跳。结束后回巡航水深。
	if leap_active:
		leap_timer += delta
		var p := clampf(leap_timer / Tuning.LEAP_TIME, 0.0, 1.0)
		position.y = Tuning.NEUTRAL_DEPTH - sin(PI * p) * Tuning.LEAP_HEIGHT
		_vy = -cos(PI * p) * PI * Tuning.LEAP_HEIGHT / Tuning.LEAP_TIME
		speed = base_speed
		diving = false
		state = "LEAPING"
		if p >= 1.0:
			leap_active = false
			leap_timer = 0.0
			position.y = Tuning.NEUTRAL_DEPTH
			_vy = 0.0
			state = "CRUISING"
		return

	# 目标深度：默认巡航；按住 ↓ 时下潜；被撞后短暂强制更深。
	# BRO BRAIN：待命/未恢复时围绕巡航水深上下晃（不是持续下沉），
	# 受控后幅度保留一半并随 recovery 收小——SHIFT 到手不等于立刻稳。
	# CORE-FEEL-08 P0-A：autodrift_px 是“壳自己漂”的目标深度偏移（恶作剧时由 race 写入）。
	var want_y := Tuning.NEUTRAL_DEPTH + autodrift_px
	var catch_mode := catch_target_y >= 0.0 and absf(vertical) < 0.1
	# BRO CATCH 的目标深度：只在玩家没有按 ↑/↓ 时接管垂直，仍然走浮力/加速度。
	if catch_mode:
		want_y = catch_target_y
	# FEEL-22：切走后不再执行玩家之前按下的下潜尾动作。
	# 下潜只由“当前受控 + 此刻按住 ↓”成立；切走当帧就结束。
	standby_dive_t = 0.0
	diving = controlled and vertical > 0.0 and dunk_timer <= 0.0 and zap_stun_t <= 0.0
	if diving:
		want_y = Tuning.NEUTRAL_DEPTH + Tuning.DIVE_DEPTH
	if dunk_timer > 0.0:
		want_y = Tuning.NEUTRAL_DEPTH + Tuning.DUNK_DEPTH
	if vertical < 0.0:
		# 紧急上浮（氧气耗尽）：强制目标改成水面，但仍然按加速度移动。
		want_y = SURFACE_Y
	var sink_speed := Tuning.DIVE_SINK_SPEED if (diving or catch_mode) else Tuning.BUOY_SINK_SPEED
	# 主动下潜用更硬的增益：目标深度不变，只是更快吃掉最后几十像素。
	# 松开/上浮仍用 BUOY_GAIN，接人时的上浮速度没有变化。
	var gain := Tuning.DIVE_GAIN if (diving or catch_mode) else Tuning.BUOY_GAIN
	var dive_accel := Tuning.DIVE_ACCEL
	# CORE-FEEL-07 P0-A：辅助下潜时更快沉下去（真实位移，深度上限与碰撞都不变）。
	if diving and dive_assist_active:
		sink_speed = Tuning.DIVE_ASSIST_SINK_SPEED
		gain = Tuning.DIVE_ASSIST_GAIN
		dive_accel = Tuning.DIVE_ASSIST_ACCEL
	var vy_target := clampf((want_y - position.y) * gain,
		-Tuning.DIVE_RISE_SPEED, sink_speed)
	_vy = move_toward(_vy, vy_target, dive_accel * delta)
	position.y = clampf(position.y + _vy * delta, SURFACE_Y, DEEP_Y)

	if dunk_timer > 0.0:
		state = "DUNKED"
	elif daze_time > 0.01:
		state = "RECOVERING" if controlled else phase_name()
	elif absf(Tuning.NEUTRAL_DEPTH - position.y) < 2.0:
		state = "BOOSTING" if boosting else "CRUISING"
	elif _vy < 0.0:
		state = "SURFACING"
	else:
		state = "DIVING"


## 神游造成的小幅上下晃：围绕巡航水深振荡，幅度 3–18 px，周期 1.6–0.9 s。
## 受控时只保留 55% 幅度：控制权到手后壳还要晃一小会儿，潜深/接人因此有准备成本。
func drift_bob_px(controlled: bool) -> float:
	var d := clampf(drift, 0.0, Tuning.DRIFT_CAP)
	if d <= Tuning.DRIFT_CALM_END:
		return 0.0
	var p := clampf((d - Tuning.DRIFT_CALM_END)
		/ (Tuning.DRIFT_RESTLESS_END - Tuning.DRIFT_CALM_END), 0.0, 1.0)
	var period := 1.6 - 0.7 * p
	return sin(_brain_t * TAU / period) * drift_bob_amp_px(controlled)


## P1-D：壳上下晃的幅度（px）。HUD 用它把“具体后果”写成数字；画法仍用
## drift_bob_px 的瞬时值，两者共用同一段幅度公式，说的和画的一致。
func drift_bob_amp_px(controlled: bool) -> float:
	var d := clampf(drift, 0.0, Tuning.DRIFT_CAP)
	if d <= Tuning.DRIFT_CALM_END:
		return 0.0
	var p := clampf((d - Tuning.DRIFT_CALM_END)
		/ (Tuning.DRIFT_RESTLESS_END - Tuning.DRIFT_CALM_END), 0.0, 1.0)
	var amp := 3.0 + 15.0 * p
	return amp * (0.55 if controlled else 1.0)


## 无人控制时的巡航掉速：3 s 起 1.00→0.96，6 s 起 0.96→0.90，9 s+ 保持 0.90。
## 受控只保留一半掉速，随 drift 恢复回到 1.00；TURBO 加速不受影响。
func drift_speed_scale(controlled: bool) -> float:
	var d := clampf(drift, 0.0, Tuning.DRIFT_CAP)
	var scale := 1.0
	if d > Tuning.DRIFT_CALM_END and d <= Tuning.DRIFT_DISTRACTED_END:
		scale = lerpf(1.0, 0.96,
			(d - Tuning.DRIFT_CALM_END) / 3.0)
	elif d > Tuning.DRIFT_DISTRACTED_END and d <= Tuning.DRIFT_RESTLESS_END:
		scale = lerpf(0.96, 0.90,
			(d - Tuning.DRIFT_DISTRACTED_END) / 3.0)
	elif d > Tuning.DRIFT_RESTLESS_END:
		scale = 0.90
	if controlled:
		scale = lerpf(1.0, scale, 0.5)
	return scale


## 头往哪看：分心时左右张望，坐不住时晃得更明显，恶作剧时盯着前方的食物。
## 只影响画法，不改变碰撞；真正的影响在速度与上下晃里。
func drift_look_px(controlled: bool) -> Vector2:
	if drift < Tuning.DRIFT_CALM_END:
		return Vector2.ZERO
	var s := 0.6 if controlled else 1.0
	match drift_state:
		"DISTRACTED":
			return Vector2(sin(_brain_t * 1.8) * 6.0,
				cos(_brain_t * 1.4) * 2.0) * s
		"RESTLESS":
			return Vector2(sin(_brain_t * 2.6) * 8.0,
				cos(_brain_t * 2.1) * 4.0) * s
		_:
			if food_ahead >= 0.0:
				return Vector2(7.0, 7.0) * s
			return Vector2(sin(_brain_t * 3.2) * 9.0, 3.0) * s


## 主动跃起：整组上抛，躲水下攻击。一次性，不是档位；冷却很短，防止连按叠跳。
func can_leap() -> bool:
	# FEEL-25：水下不能直接起跳；必须先浮回巡航水面。
	if position.y > Tuning.NEUTRAL_DEPTH + 20.0:
		return false
	return not accident and not leap_active and leap_cooldown <= 0.0


func start_leap() -> bool:
	if not can_leap():
		return false
	leap_active = true
	leap_timer = 0.0
	leap_cooldown = Tuning.LEAP_TIME + Tuning.LEAP_COOLDOWN
	leap_count += 1
	dunk_timer = 0.0
	return true


func start_dunk() -> void:
	dunk_timer = Tuning.DUNK_TIME


## P5：被浪掀翻。只置表现计时；事故记账仍由 race 的 _turtle_contact 负责一次。
## 已经翻着的时候再被拍一下不重新计时：贴着鲨鱼连拍不会让“肚皮朝天”整段卡住。
func start_flip() -> void:
	if accident or flip_t > 0.0 or flip_lock > 0.0:
		return
	flip_t = Tuning.FLIP_TIME
	# 掀翻 0.9 s + 0.6 s 立回来的缓冲：连续被拍时不会整段卡在肚皮朝天上。
	flip_lock = Tuning.FLIP_TIME + 0.6


## 事件驱动的失衡。浪击、撞击、特殊动作失败走这里，待命时间不走这里。
## Phase G：只做短硬直/姿态，封顶在 DAZE_CAP；持续风险由 BRO METER 记。
func add_imbalance(amount: float) -> void:
	if amount <= 0.0:
		return
	daze_time = minf(daze_time + amount, Tuning.DAZE_CAP)
	state = phase_name()


func phase_name() -> String:
	if daze_time < Tuning.RELAX_TIME:
		return "RELAXED"
	if daze_time < Tuning.SINK_EDGE_TIME:
		return "SINKING"
	if daze_time < Tuning.SINK_CRITICAL_TIME:
		return "DEEP"
	return "CRITICAL"


func phase_label() -> String:
	match phase_name():
		"RELAXED":
			return "NO POWER"
		"SINKING":
			return "SINKING"
		"DEEP":
			return "TOO DEEP"
		_:
			return "CRITICAL"


func is_in_danger() -> bool:
	return daze_time >= Tuning.SINK_DANGER_TIME


func is_at_surface() -> bool:
	if Tuning.SURFBOARD_PHYSICS:
		# 被浪打湿没入水下时接不住兔子；巡航/跃浪高度都接得住。
		# 120 = 浮出带（BRO DIVE 里壳还在上浮时也算“在水面”）。
		return position.y <= Tuning.NEUTRAL_DEPTH + Tuning.PICKUP_SURFACE_MARGIN
	return position.y <= SURFACE_Y + 40.0


## 壳是否正在上浮：接人窗口据此放宽（见 mount_controller.can_pickup）。
## CORE-FEEL-07 P1-E：神游的上下晃（3–18 px）也会让 _vy 周期性地小于 0，
## 但那是巡航中的振荡，不是“壳还在水下、正在浮上来”的 BRO DIVE 段。
## 不排除的话，普通岩跳在下落时会被提前 115 px 接住，抬升路径正好横穿岩檐。
## 只有壳确实低于巡航水深（超过最大晃幅 18 px + 6 px 余量）才算上浮。
func is_rising() -> bool:
	return _vy < -1.0 and position.y > Tuning.NEUTRAL_DEPTH + 24.0


func get_mount_point() -> Vector2:
	return position + Vector2(0, -58)


func get_body_rect() -> Rect2:
	return Rect2(position - BODY_SIZE * 0.5, BODY_SIZE)
