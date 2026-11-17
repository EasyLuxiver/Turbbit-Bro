extends Node2D
## 兔子：骑乘 / 跳跃 / 空中移动 / 下落 / 趴下 / 神游滑落 / 落水 / Showtime。
## 失控按 GDD 5.6 分三段：提示（RELAXED）→ 开始滑落（SLIDING）→ 边缘（EDGE）→ 事故。

const Tuning = preload("res://scripts/systems/tuning.gd")
## STAGE 4 追加指令：最高点 180–200 px、滞空 1.1–1.2 s。
## g=1050、v=-630 -> 1.20 s、~189 px（离散实测 183 px）；水平 264 px@220 / 312 px@260。
## 兔子最高只到 y≈62，不再撞进顶部 HUD；组合漂浮木的地形同步收窄（见 level_data）。
const GRAVITY := 1050.0
const JUMP_VELOCITY := -630.0
const AIR_ACCEL := 600.0
const AIR_MAX := 150.0
const CROUCH_DROP := 20.0
const RIDE_BODY := Vector2(32, 48)
const CROUCH_BODY := Vector2(32, 24)

var state := "RIDING"
var velocity := Vector2.ZERO
## FEEL-29：BRO DIVE 接应期间由 race 写入的水平速度上限。
## 兔子在空中的 → 键是 150 px/s 的空中加速，玩家按住加速跳时会把壳甩在身后，
## 接应只能把兔子往回拽。潜水接人时把上限压到壳的当前速度附近，让落点留在接人窗口里。
var air_speed_cap := INF
var slide := 0.0
var air_base := 0.0
## P4：兔子自己吃到海藻后的跳跃初速倍率；窗口结束由 race 复位为 1.0。
var jump_boost := 1.0
## FEEL-47：兔子吃到海藻后，高跳保留到下一次普通起跳才消耗。
var snack_jump_pending := false
var daze_time := 0.0
var control_hold := 0.0
var showtime_spin := 0.0
var showtime_pose := false
## BRO BRAIN：race 每帧写入的未受控神游量（秒）与状态名。
## 兔子待命时不再冻结成海报：越久没人管，越往壳边挪、越晃、空中越难修正。
var drift := 0.0
var drift_state := "CALM"
## 起跳瞬间锁定的空中操控系数：神游越深，落点越难改。
var air_scale := 1.0
## P0-3：MISCHIEF 且在低梁/海鸟前——站直探头（身体抬高，进入碰撞矩形）。
## 由 race 每帧按“未受控 + MISCHIEF + 前方 170 px 有低障碍”写入；切回即取消。
var mischief_pose := false
## CORE-FEEL-08 P0-A：race 每帧写入“这一刻真正被听见的 ↓”，
## 神游造成的反应延迟在 race 里统一算，控制器不再直接读原始输入。
var input_down := false
## FEEL-11 B2：被切出时把“趴低”再维持 0.35 s，让动作有尾，不是一切换就站起。
var standby_crouch_t := 0.0
var _brain_t := 0.0


func reset() -> void:
	state = "RIDING"
	velocity = Vector2.ZERO
	slide = 0.0
	daze_time = 0.0
	control_hold = 0.0
	showtime_spin = 0.0
	showtime_pose = false
	drift = 0.0
	drift_state = "CALM"
	air_scale = 1.0
	mischief_pose = false
	snack_jump_pending = false
	input_down = false
	air_speed_cap = INF
	standby_crouch_t = 0.0
	_brain_t = 0.0


func tick_riding(delta: float, mount_point: Vector2, controlled: bool,
		_boosting: bool, can_act: bool, grace: bool = false) -> void:
	_brain_t += delta
	if grace and not controlled:
		# 事故恢复后的宽限：先稳住，不立刻滑落。
		daze_time = 0.0
		control_hold = 0.0
		state = "RIDING"
		slide = maxf(slide - 0.55 * delta, 0.0)
		position = mount_point
		return

	if controlled and can_act:
		# 主动控制：连续站稳 0.5 s 后才开始爬回龟壳；切换本身不重置失衡进度。
		# 滑移位置由 daze_time 决定，只有实际控制时间能把它收回来（GDD 6.3）。
		control_hold += delta
		if control_hold >= Tuning.CONTROL_RECOVER_DELAY:
			daze_time = maxf(daze_time - Tuning.CONTROL_RECOVER_RATE * delta, 0.0)
		slide = slide_for_time(daze_time)
		state = "CROUCHING" if input_down else "RIDING"
		if input_down:
			standby_crouch_t = 0.35
		else:
			standby_crouch_t = 0.0
	elif controlled:
		# 受控但暂时不能行动（硬直等）：冻结，不再自动恶化。
		# 失衡只来自事件（碰撞/错误着陆/特殊动作失败），不来自时间。
		control_hold = 0.0
		state = phase_name() if daze_time > 0.01 else "RIDING"
		slide = slide_for_time(daze_time)
	else:
		# 待命：抓紧龟壳，稳定。不累积、不滑落、不清零。
		# 这是本指令最硬的一条：未被选中永远不会让兔子变糟。
		# CORE-FEEL-08 P0-A：待命时 input_down 只可能是“自己趴下”（恶作剧），
		# 不是玩家输入——让它照样看得见，但不改变任何累积/恢复规则。
		control_hold = 0.0
		if standby_crouch_t > 0.0 and not input_down:
			standby_crouch_t = maxf(standby_crouch_t - delta, 0.0)
		if input_down or standby_crouch_t > 0.0:
			state = "CROUCHING"
		else:
			state = phase_name() if daze_time > 0.01 else "RIDING"
		slide = slide_for_time(daze_time)

	position = mount_point + Vector2(-slide * Tuning.SLIDE_PIXELS, 0.0)
	if state == "CROUCHING":
		position.y += CROUCH_DROP
	elif mischief_pose and not controlled:
		# 错误姿势：站起来探头。位置抬高直接进 get_body_rect：
		# 低梁余量 12 px，抬 18 px 后判定框会擦到梁（3 px），但不落水。
		position.y -= Tuning.MISCHIEF_POSE_LIFT


## 神游带来的持续偏移：3 s 之后从 0 连续长到 22 px，再叠加 1.5–7 px 的左右晃。
## 偏移直接写进 position，所以也进 get_body_rect——碰撞风险是真实的，不是只画出来。
func drift_offset_px() -> float:
	var d := clampf(drift, 0.0, Tuning.DRIFT_CAP)
	if d <= Tuning.DRIFT_CALM_END:
		return 0.0
	var p := clampf((d - Tuning.DRIFT_CALM_END)
		/ (Tuning.DRIFT_CAP - Tuning.DRIFT_CALM_END), 0.0, 1.0)
	return Tuning.DRIFT_MAX_OFFSET * p + drift_sway_px()


## P1-D：身体最多能偏出壳心多少 px（含左右摆）。HUD 用它写“具体后果”，
## 实际偏移仍由 drift_offset_px 逐帧算，两者共用 Tuning 里的上限。
func drift_offset_amp_px() -> float:
	var d := clampf(drift, 0.0, Tuning.DRIFT_CAP)
	if d <= Tuning.DRIFT_CALM_END:
		return 0.0
	var p := clampf((d - Tuning.DRIFT_CALM_END)
		/ (Tuning.DRIFT_CAP - Tuning.DRIFT_CALM_END), 0.0, 1.0)
	var sway := 0.0
	if drift >= Tuning.DRIFT_DISTRACTED_END:
		var q := clampf((drift - Tuning.DRIFT_DISTRACTED_END)
			/ (Tuning.DRIFT_CAP - Tuning.DRIFT_DISTRACTED_END), 0.0, 1.0)
		sway = 1.5 + 5.5 * q
	return Tuning.DRIFT_MAX_OFFSET * p + sway


func drift_sway_px() -> float:
	if drift < Tuning.DRIFT_DISTRACTED_END:
		return 0.0
	var p := clampf((drift - Tuning.DRIFT_DISTRACTED_END)
		/ (Tuning.DRIFT_CAP - Tuning.DRIFT_DISTRACTED_END), 0.0, 1.0)
	return sin(_brain_t * 5.2) * (1.5 + 5.5 * p)


## RESTLESS 起脚步错乱：小幅上下弹跳，站姿也会因此更容易擦到低层障碍。
func drift_bob_px() -> float:
	if drift < Tuning.DRIFT_RESTLESS_END:
		return 0.0
	var p := clampf((drift - Tuning.DRIFT_RESTLESS_END)
		/ (Tuning.DRIFT_CAP - Tuning.DRIFT_RESTLESS_END), 0.0, 1.0)
	return sin(_brain_t * 7.0) * (1.0 + 2.0 * p)


## 起跳时锁定的空中修正能力：DISTRACTED 以后线性下降，MISCHIEF 最低 0.55。
func drift_air_scale() -> float:
	var d := clampf(drift, 0.0, Tuning.DRIFT_CAP)
	if d <= Tuning.DRIFT_DISTRACTED_END:
		return 1.0
	if d <= Tuning.DRIFT_RESTLESS_END:
		return lerpf(1.0, 0.75,
			(d - Tuning.DRIFT_DISTRACTED_END) / 3.0)
	return lerpf(0.75, 0.55,
		clampf((d - Tuning.DRIFT_RESTLESS_END) / 3.0, 0.0, 1.0))


func phase_name() -> String:
	if daze_time < Tuning.RELAX_TIME:
		return "RELAXED"
	if daze_time < Tuning.SLIP_EDGE_TIME:
		return "SLIDING"
	if daze_time < Tuning.SLIP_CRITICAL_TIME:
		return "EDGE"
	return "CRITICAL"


func phase_label() -> String:
	match phase_name():
		"RELAXED":
			return "RELAXED"
		"SLIDING":
			return "SLIPPING"
		"EDGE":
			return "ABOUT TO FALL"
		_:
			return "CRITICAL"


## 五段滑落曲线：0 → 0.35（1.5～4.5）→ 0.7（4.5～7.5）→ 1.0（7.5～9.5）。
## 前半段几乎看不出来，中段开始明显，临界时整只兔子挂在壳边。
func slide_for_time(t: float) -> float:
	if t <= Tuning.RELAX_TIME:
		return 0.0
	if t <= Tuning.SLIP_EDGE_TIME:
		var p := (t - Tuning.RELAX_TIME) / (Tuning.SLIP_EDGE_TIME - Tuning.RELAX_TIME)
		return 0.35 * p
	if t <= Tuning.SLIP_CRITICAL_TIME:
		var q := (t - Tuning.SLIP_EDGE_TIME) \
			/ (Tuning.SLIP_CRITICAL_TIME - Tuning.SLIP_EDGE_TIME)
		return 0.35 + 0.35 * q
	var r := clampf((t - Tuning.SLIP_CRITICAL_TIME)
		/ (Tuning.SLIP_FALL_TIME - Tuning.SLIP_CRITICAL_TIME), 0.0, 1.0)
	return 0.7 + 0.3 * r


func is_falling() -> bool:
	return daze_time >= Tuning.SLIP_FALL_TIME


func tick_stun(_delta: float, mount_point: Vector2) -> void:
	# 硬直是碰撞的即时后果，不是免费的复位：失衡保留，姿态继续挂在壳边。
	# 硬直期间不累积也不恢复，结束后由“是否受控”决定回落还是继续恶化。
	state = "STUNNED"
	slide = slide_for_time(daze_time)
	position = mount_point + Vector2(-slide * Tuning.SLIDE_PIXELS, 0.0)


func force_slip() -> void:
	# Showtime 被中断：跳过提示期，直接从“开始滑落”读秒。
	daze_time = Tuning.RELAX_TIME
	state = "SLIDING"
	slide = 0.0


## 事件驱动的失衡。碰撞、错误着陆、特殊动作失败走这里，
## 待命时间不走这里——所以没被选中的兔子永远不会自己变糟。
func add_imbalance(amount: float) -> void:
	if amount <= 0.0:
		return
	# 只做短硬直/姿态：封顶在 DAZE_CAP，永远到不了落水线。
	daze_time = minf(daze_time + amount, Tuning.DAZE_CAP)
	slide = slide_for_time(daze_time)
	state = phase_name()


## kick_velocity 留给 BRO OLLIE：乌龟跃起时兔子从壳上蹬踏，用自己的初速离壳。
## 默认仍是普通跳；水平速度跟随乌龟，所以蹬踏后不会甩开壳太远。
## REBUILD-06 P4：普通跳的初速乘 jump_boost（兔子自己吃到海藻时 1.15），
## BRO OLLIE 的显式初速不受影响。
func arm_snack_jump(scale: float) -> void:
	jump_boost = scale
	snack_jump_pending = true


func launch(mount_point: Vector2, turtle_speed: float,
		kick_velocity: float = 0.0, height_scale: float = 1.0) -> void:
	state = "JUMPING"
	var normal_launch := is_zero_approx(kick_velocity)
	var boost := jump_boost
	if normal_launch and snack_jump_pending:
		snack_jump_pending = false
		jump_boost = 1.0
	# 从“实际站着的位置”起跳，而不是瞬间回到壳心：神游越深，起跳点越偏。
	air_scale = 1.0
	position = mount_point
	air_base = turtle_speed
	if is_zero_approx(kick_velocity):
		kick_velocity = JUMP_VELOCITY * boost * height_scale
	velocity = Vector2(turtle_speed + 15.0, kick_velocity)
	air_speed_cap = INF


func tick_air(delta: float, controlled: bool) -> void:
	if controlled:
		var dir := Input.get_axis("left", "right")
		var maxv := AIR_MAX * air_scale
		var target := air_base + dir * maxv
		if air_speed_cap < INF:
			target = minf(target, air_speed_cap)
		velocity.x = move_toward(velocity.x, target, AIR_ACCEL * air_scale * delta)
	# FEEL-29：换到乌龟后兔子不再受控，但已经在空中的水平速度仍要收回到上限，
	# 否则按住 → 起跳再 SHIFT，兔子会一直领先壳 150 px/s。
	if air_speed_cap < INF and velocity.x > air_speed_cap:
		velocity.x = move_toward(velocity.x, air_speed_cap,
			AIR_ACCEL * air_scale * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, 950.0)
	position += velocity * delta
	state = "JUMPING" if velocity.y < 0.0 else "FALLING"


func attach(mount_point: Vector2) -> void:
	state = "RIDING"
	slide = 0.0
	daze_time = 0.0
	control_hold = 0.0
	velocity = Vector2.ZERO
	showtime_spin = 0.0
	showtime_pose = false
	position = mount_point
	air_speed_cap = INF


func is_airborne() -> bool:
	return state == "JUMPING" or state == "FALLING"


func get_body_rect() -> Rect2:
	var size := CROUCH_BODY if state == "CROUCHING" else RIDE_BODY
	return Rect2(position - size * 0.5, size)
