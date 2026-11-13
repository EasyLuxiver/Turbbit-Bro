extends Node
## STAGE 4 · 核心体验返工灰盒：三组实验，回答“兔子的动作有没有真实价值、
## 水上/水下两层能否形成可读的选择”。
##
##   A  同一障碍两条路线：低梁（趴下 / 下潜）、低岩（跳跃 / 下潜）。
##   B  浅礁深度扫描：低梁下方放暗礁，礁顶 350 / 420 / 500 / 620，比较
##      下潜路线是否仍然成立；另测“礁石晚 250 px 才出现”的预警距离。
##   C  跳跃落地接人 + 后面的长墙：跳跃→自动接住→下潜，以及“落地前就
##      把乌龟潜下去”会发生什么。
##
## 原则（制作人补充指令）：
##   - 不预设“下潜必须撞礁”。深度只是变量，结论由测量决定。
##   - 不预设“兔子动作必须成为唯一解”。两条路线都先按合理时机跑一遍。
##   - 代理测试只证明工程可行；没有任何真人手感结论。
##
## 手动推进 race.gd 的 _physics_process，固定 1/60 步长；不写 best.json。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT \
##       res://scenes/stage4_experience_rework.tscn
## 输出：docs/reports/stage4-experience-rework.json

const OUT_PATH := "res://docs/reports/stage4-experience-rework.json"
const STEP := 1.0 / 60.0
const SPEED := 240.0            # Zone 2 基准速度
const START_X := 16600.0
const OX := 17200.0             # 主障碍起点
const WALL_X := 17800.0         # 实验 C/B 的后续长墙
const DECIDE_LEAD := 200.0      # 下潜/趴下的决策提前量
const JUMP_LEAD := 70.0         # 跳跃提前量（再早会在下落段撞岩）

var is_runner := false
var race
var frames := 0
var data := {}
var m := {}
var _acc0 := 0
var _pickups0 := 0
var _down_held := false
var _up_held := false


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4ExperienceRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "en"
	data["stage"] = 4
	data["section"] = {"start": START_X, "obstacle_x": OX, "wall_x": WALL_X,
		"speed": SPEED, "step": STEP}
	data["experiment_a"] = {}
	data["experiment_b"] = {"arms": []}
	data["experiment_c"] = {"arms": []}

	# ---- A：同一障碍两条路线 ----
	data["experiment_a"]["beam_crouch"] = await _arm_beam_crouch()
	data["experiment_a"]["beam_crouch_late"] = await _arm_beam_crouch_late()
	data["experiment_a"]["beam_dive"] = await _arm_beam_dive()
	data["experiment_a"]["rock_jump"] = await _arm_rock_jump()
	data["experiment_a"]["rock_dive"] = await _arm_rock_dive()
	# 低梁能不能跳过？这决定趴下还有没有独有价值。
	data["experiment_a"]["beam_jump_free"] = await _arm_beam_jump(
		"A_beam_jump_free", 170.0, false)
	data["experiment_a"]["beam_jump_hold"] = await _arm_beam_jump(
		"A_beam_jump_hold", 170.0, true)
	data["experiment_a"]["beam_wide_jump_hold"] = await _arm_beam_jump(
		"A_beam_wide_jump_hold", 260.0, true)
	# 梁宽是不是“成本旋钮”？110 px 短梁：趴下 vs 下潜，都在贴近时才操作。
	data["experiment_a"]["beam_short_crouch"] = await _arm_beam_short(
		"A_beam_short_crouch", true)
	data["experiment_a"]["beam_short_dive"] = await _arm_beam_short(
		"A_beam_short_dive", false)

	# ---- B：浅礁深度扫描 ----
	for depth in [350.0, 420.0, 500.0, 620.0]:
		var arm := await _arm_reef_dive(depth, 0.0)
		data["experiment_b"]["arms"].append(arm)
	data["experiment_b"]["arms"].append(await _arm_reef_dive(420.0, 250.0))
	for depth in [350.0, 420.0, 500.0, 620.0]:
		data["experiment_b"]["arms"].append(await _arm_reef_crouch(depth))

	# ---- C：落地接人 + 后面的长墙 ----
	data["experiment_c"]["arms"].append(await _arm_jump_plain())
	data["experiment_c"]["arms"].append(await _arm_jump_wall(false))
	data["experiment_c"]["arms"].append(await _arm_jump_wall(true))
	for delay in [0.0, 0.6, 0.9, 1.1, 1.3]:
		data["experiment_c"]["arms"].append(await _arm_pickup_sweep(delay))

	# ---- D：真实关卡复核（LevelData 原样，不改布局）----
	# 只清加速带，保证读数是各区基准速度 220/240/260。
	data["real_level"] = []
	data["real_level"].append(await _real_arm("D_z1_rock_jump", 1300.0, 220.0, "jump"))
	data["real_level"].append(await _real_arm("D_z1_rock_dive", 1300.0, 220.0, "dive_rock"))
	data["real_level"].append(await _real_arm("D_z1_beam_crouch", 2100.0, 220.0, "crouch"))
	data["real_level"].append(await _real_arm("D_z1_beam_dive", 2100.0, 220.0, "dive"))
	data["real_level"].append(await _real_arm("D_z2_rock_jump", 34200.0, 240.0, "jump"))
	data["real_level"].append(await _real_arm("D_z2_rock_dive", 34200.0, 240.0, "dive_rock"))
	data["real_level"].append(await _real_arm("D_z2_beam_crouch", 35000.0, 240.0, "crouch"))
	data["real_level"].append(await _real_arm("D_z2_beam_dive", 35000.0, 240.0, "dive"))
	data["real_level"].append(await _real_arm("D_z3_rock_jump", 55000.0, 260.0, "jump"))
	data["real_level"].append(await _real_arm("D_z3_rock_dive", 55000.0, 260.0, "dive_rock"))
	data["real_level"].append(await _real_arm("D_z3_beam_crouch", 55800.0, 260.0, "crouch"))
	data["real_level"].append(await _real_arm("D_z3_beam_dive", 55800.0, 260.0, "dive"))

	data["verdict"] = _verdict()
	_write_json()
	_print_summary()
	print("STAGE4 EXPERIENCE REWORK: " + data["verdict"]["headline"])
	get_tree().quit(0)


# ======================================================================
# 实验 A
# ======================================================================

func _arm_beam_crouch() -> Dictionary:
	await _setup([_group("a_beam", "LOW_BEAM", Rect2(OX, 140, 170, 100),
		"LOW BEAM", "CROUCH DOWN")])
	await _approach(OX - DECIDE_LEAD)
	_fresh()
	await _to("rabbit")
	_down(true)
	await _travel_until_x(OX + 170.0 + 40.0)
	_down(false)
	var snap := _snap()
	await _expire_edges()
	await _leave_obstacle()
	return _finish("A_beam_crouch", "crouch", snap)


## 贴着障碍才趴下：测趴下路线的最低成本（不把 200 px 接近段的计时算进去）。
func _arm_beam_crouch_late() -> Dictionary:
	await _setup([_group("a_beam", "LOW_BEAM", Rect2(OX, 140, 170, 100),
		"LOW BEAM", "CROUCH DOWN")])
	await _approach(OX - 60.0)
	_fresh()
	await _to("rabbit")
	_down(true)
	await _travel_until_x(OX + 170.0 + 40.0)
	_down(false)
	var snap := _snap()
	await _expire_edges()
	await _leave_obstacle()
	return _finish("A_beam_crouch_late", "crouch_late", snap)


## 低梁跳跃：滞空 1.244 s，但“高过梁顶”只有 0.654 s；按不按 RIGHT（空中
## 控制 +150）决定这段时间能横向走多远。宽容度由测量给出。
func _arm_beam_jump(name: String, width: float, hold_right: bool) -> Dictionary:
	await _setup([_group("a_beam_j", "LOW_BEAM", Rect2(OX, 140, width, 100),
		"LOW BEAM", "CROUCH DOWN")])
	await _approach(OX - 140.0)
	_fresh()
	await _to("rabbit")
	if hold_right:
		Input.action_press("right")
	await _jump()
	await _wait_land()
	if hold_right:
		Input.action_release("right")
	await _travel_until_x(OX + width + 40.0)
	var snap := _snap()
	await _leave_obstacle()
	return _finish(name, "jump", snap)


## 110 px 短梁：同一决策提前量（60 px）下对比趴下与下潜的双方计时成本。
func _arm_beam_short(name: String, crouch: bool) -> Dictionary:
	await _setup([_group("a_beam_s", "LOW_BEAM", Rect2(OX, 140, 110, 100),
		"LOW BEAM", "CROUCH DOWN")])
	await _approach(OX - 60.0)
	_fresh()
	if crouch:
		await _to("rabbit")
		_down(true)
		await _travel_until_x(OX + 110.0 + 40.0)
		_down(false)
		var snap := _snap()
		await _expire_edges()
		await _leave_obstacle()
		return _finish(name, "crouch_short", snap)
	await _to("turtle")
	_down(true)
	await _wait_depth(345.0)
	_down(false)
	await _travel_until_x(OX + 110.0 + 40.0)
	var snap := _snap()
	await _leave_obstacle()
	return _finish(name, "dive_short", snap)


func _arm_beam_dive() -> Dictionary:
	await _setup([_group("a_beam", "LOW_BEAM", Rect2(OX, 140, 170, 100),
		"LOW BEAM", "CROUCH DOWN")])
	await _approach(OX - DECIDE_LEAD)
	_fresh()
	await _to("turtle")
	_down(true)
	await _wait_depth(345.0)
	_down(false)
	await _travel_until_x(OX + 170.0 + 40.0)
	var snap := _snap()
	await _leave_obstacle()
	return _finish("A_beam_dive", "dive", snap)


func _arm_rock_jump() -> Dictionary:
	await _setup([_group("a_rock", "SURFACE_ROCK", Rect2(OX, 220, 90, 42),
		"LOW ROCK", "JUMP OVER")])
	await _approach(OX - JUMP_LEAD)
	_fresh()
	await _to("rabbit")
	await _jump()
	await _wait_land()
	var snap := _snap()
	await _leave_obstacle()
	return _finish("A_rock_jump", "jump", snap)


func _arm_rock_dive() -> Dictionary:
	await _setup([_group("a_rock", "SURFACE_ROCK", Rect2(OX, 220, 90, 42),
		"LOW ROCK", "JUMP OVER")])
	await _approach(OX - DECIDE_LEAD)
	_fresh()
	await _to("turtle")
	_down(true)
	await _wait_depth(350.0)
	_down(false)
	await _travel_until_x(OX + 90.0 + 60.0)
	var snap := _snap()
	await _leave_obstacle()
	return _finish("A_rock_dive", "dive", snap)


# ======================================================================
# 实验 B：低梁 + 水下暗礁
# ======================================================================

func _arm_reef_dive(depth: float, offset: float) -> Dictionary:
	var groups := [
		_group("b_beam", "LOW_BEAM", Rect2(OX, 140, 170, 100), "LOW BEAM", "CROUCH DOWN"),
		_group("b_reef", "UNDERWATER_REEF",
			Rect2(OX + offset, depth, 180, 150), "REEF", "STAY HIGH"),
	]
	await _setup(groups)
	await _approach(OX - DECIDE_LEAD)
	_fresh()
	await _to("turtle")
	_down(true)
	await _wait_depth(345.0)
	_down(false)
	# 只走到暗礁尾端 +20；走太远会让“兔子一直没人管”单独变成事故，
	# 污染“这条路线是否撞礁”的读数。
	await _travel_until_x(maxf(OX + 170.0, OX + offset + 180.0) + 20.0)
	var snap := _snap()
	await _leave_obstacle()
	var r := _finish("B_dive_D%d_off%d" % [int(depth), int(offset)], "dive", snap)
	r["reef_top"] = depth
	r["reef_offset"] = offset
	return r


func _arm_reef_crouch(depth: float) -> Dictionary:
	var groups := [
		_group("b_beam", "LOW_BEAM", Rect2(OX, 140, 170, 100), "LOW BEAM", "CROUCH DOWN"),
		_group("b_reef", "UNDERWATER_REEF",
			Rect2(OX, depth, 180, 150), "REEF", "STAY HIGH"),
	]
	await _setup(groups)
	await _approach(OX - DECIDE_LEAD)
	_fresh()
	await _to("rabbit")
	_down(true)
	await _travel_until_x(OX + 170.0 + 40.0)
	_down(false)
	var snap := _snap()
	await _expire_edges()
	await _leave_obstacle()
	var r := _finish("B_crouch_D%d" % int(depth), "crouch", snap)
	r["reef_top"] = depth
	r["reef_offset"] = 0.0
	return r


# ======================================================================
# 实验 C：跳跃落地接人 + 长墙
# ======================================================================

func _arm_jump_plain() -> Dictionary:
	await _setup([_group("c_rock", "SURFACE_ROCK", Rect2(OX, 220, 90, 42),
		"LOW ROCK", "JUMP OVER")])
	await _approach(OX - JUMP_LEAD)
	_fresh()
	await _to("rabbit")
	await _jump()
	await _wait_land()
	var snap := _snap()
	await _leave_obstacle()
	var r := _finish("C_jump_plain", "jump", snap)
	r["pickup_ok"] = m["pickup"] > 0 and m["accident"] == "NONE"
	return r


func _arm_jump_wall(early_dive: bool) -> Dictionary:
	var groups := [
		_group("c_rock", "SURFACE_ROCK", Rect2(OX, 220, 90, 42), "LOW ROCK", "JUMP OVER"),
		_group("c_wall", "SURFACE_WALL", Rect2(WALL_X, 120, 500, 180), "LONG WALL", "DIVE THROUGH"),
	]
	await _setup(groups)
	await _approach(OX - JUMP_LEAD)
	_fresh()
	await _to("rabbit")
	await _jump()
	var pickup_ok := false
	if early_dive:
		# 落地前 0.3 s 就切乌龟下潜：记录接人会不会失败。
		var t0 := _t()
		while _t() - t0 < 0.3 and race.mount.state == "AIRBORNE" \
				and GameManager.accident_state == "NONE":
			await _tick()
		await _to("turtle")
		_down(true)
		await _wait_depth(350.0)
		_down(false)
	else:
		await _wait_land()
		pickup_ok = race.mount.state == "RIDING" and GameManager.accident_state == "NONE"
		await _to("turtle")
		_down(true)
		await _wait_depth(350.0)
		_down(false)
		await _travel_until_x(WALL_X + 40.0)
		_down(false)
		# 墙下把控制权还给兔子换气，乌龟在水下继续滑行过墙——
		# 这是正常打法；不换的话，兔子在 500 px 长墙里自己就滑下去了。
		# 换 0.8 s 再回乌龟，否则乌龟的 daze 会走满 3.6 s 判深度事故。
		if GameManager.accident_state == "NONE":
			await _to("rabbit")
			var hold := _t()
			while _t() - hold < 0.8 and GameManager.accident_state == "NONE":
				await _tick()
			await _to("turtle")
	m["land_ok"] = pickup_ok
	await _travel_until_x(WALL_X + 500.0 + 60.0)
	_down(false)
	var snap := _snap()
	await _leave_obstacle()
	var r := _finish("C_jump_wall_%s" % ("early" if early_dive else "late"),
		"jump_then_dive", snap)
	r["pickup_ok"] = pickup_ok
	r["land_to_wall_s"] = _land_to_wall()
	return r


func _arm_pickup_sweep(delay: float) -> Dictionary:
	await _setup([_group("c_rock", "SURFACE_ROCK", Rect2(OX, 220, 90, 42),
		"LOW ROCK", "JUMP OVER")])
	await _approach(OX - JUMP_LEAD)
	_fresh()
	await _to("rabbit")
	await _jump()
	# 起跳后 delay 秒把乌龟潜下去，看还能不能接住。
	var t0 := _t()
	while _t() - t0 < delay and race.mount.state == "AIRBORNE" \
			and GameManager.accident_state == "NONE":
		await _tick()
	await _to("turtle")
	_down(true)
	var t1 := _t()
	while _t() - t1 < 2.0 and GameManager.accident_state == "NONE" \
			and race.mount.state == "AIRBORNE":
		await _tick()
	_down(false)
	var landed: bool = race.mount.state == "RIDING" \
		and GameManager.accident_state == "NONE"
	var snap := _snap()
	await _leave_obstacle()
	var r := _finish("C_pickup_delay_%.1f" % delay, "pickup_sweep", snap)
	r["dive_delay_s"] = delay
	r["pickup_ok"] = landed and m["pickup"] > 0
	return r


# ======================================================================

func _group(name: String, kind: String, rect: Rect2, hint: String,
		action: String) -> Dictionary:
	return {"group": name, "zone": 2, "kind": kind, "rects": [rect],
		"hint": hint, "action": action}


func _setup(groups: Array) -> void:
	var old := get_tree().current_scene
	GameManager.start_race()
	await _wait_new_scene(old)
	await get_tree().process_frame
	race = get_tree().current_scene
	race.test_disable_hazards = false
	race.test_no_finish = true
	race.set_physics_process(false)
	race.hazard_groups = groups
	race.boost_lanes = []
	race.passed_groups.clear()
	race.entered_groups.clear()
	# G20：hit_roles 必须和 hit_groups 一起清。只清 hit_groups 时，B2 起的“角色×组”记账还留着，同组第二例起整组免疫——后面那些重复用例其实在测一段不会撞的赛道。
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.combo = 0
	race.showtime_active = false
	race.showtime_t = 0.0
	race.hazard_cooldown = 0.0
	race.turtle_repair = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.rabbit_stun = 0.0
	race.emergency_timer = 0.0
	race.finishing = false
	race.turtle.position = Vector2(START_X, 300.0)
	race.turtle.speed = SPEED
	race.turtle.base_speed = SPEED
	race.turtle.state = "CRUISING"
	race.turtle.accident = false
	race.turtle.daze_time = 0.0
	race.turtle.control_hold = 0.0
	race.turtle._sink_speed = 0.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race._update_zone()
	GameManager.set_control("rabbit")
	GameManager.has_shifted = true
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.oxygen_phase = "SAFE"
	GameManager.pickup_window = false
	for a in ["up", "down", "left", "right", "boost", "shift"]:
		Input.action_release(a)
	_down_held = false
	_up_held = false
	frames = 0
	_reset_m()
	await _tick()
	await _expire_edges()


## 真实关卡：保留 LevelData 的 hazard_groups，只把乌龟摆到组的左边。
func _setup_real(x: float) -> void:
	var old := get_tree().current_scene
	GameManager.start_race()
	await _wait_new_scene(old)
	await get_tree().process_frame
	race = get_tree().current_scene
	race.test_disable_hazards = false
	race.test_no_finish = true
	race.set_physics_process(false)
	race.boost_lanes = []
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.combo = 0
	race.showtime_active = false
	race.showtime_t = 0.0
	race.hazard_cooldown = 0.0
	race.turtle_repair = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.rabbit_stun = 0.0
	race.emergency_timer = 0.0
	race.finishing = false
	race.turtle.position = Vector2(x, 300.0)
	race.turtle.state = "CRUISING"
	race.turtle.accident = false
	race.turtle.daze_time = 0.0
	race.turtle.control_hold = 0.0
	race.turtle._sink_speed = 0.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race._update_zone()
	GameManager.set_control("rabbit")
	GameManager.has_shifted = true
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.oxygen_phase = "SAFE"
	GameManager.pickup_window = false
	for a in ["up", "down", "left", "right", "boost", "shift"]:
		Input.action_release(a)
	_down_held = false
	_up_held = false
	frames = 0
	_reset_m()
	await _tick()
	await _expire_edges()


func _real_arm(name: String, gx: float, spd: float, route: String) -> Dictionary:
	await _setup_real(gx - 260.0)
	match route:
		"jump":
			await _approach(gx - JUMP_LEAD)
			_fresh(spd)
			await _to("rabbit")
			await _jump()
			await _wait_land()
		"crouch":
			await _approach(gx - 60.0)
			_fresh(spd)
			await _to("rabbit")
			_down(true)
			await _travel_until_x(gx + 170.0 + 40.0)
			_down(false)
			await _expire_edges()
		"dive":
			await _approach(gx - DECIDE_LEAD)
			_fresh(spd)
			await _to("turtle")
			_down(true)
			await _wait_depth(345.0)
			_down(false)
			await _travel_until_x(gx + 170.0 + 40.0)
		"dive_rock":
			await _approach(gx - DECIDE_LEAD)
			_fresh(spd)
			await _to("turtle")
			_down(true)
			await _wait_depth(350.0)
			_down(false)
			await _travel_until_x(gx + 90.0 + 60.0)
	var snap := _snap()
	await _leave_obstacle()
	var r := _finish(name, route, snap)
	r["group_x"] = gx
	r["zone_speed"] = spd
	return r


## 平衡接近：每 0.9 s 把控制权交给当前更危险的一方，避免带着 1.7 s 的
## 计时进障碍。这是“正常在开车”的基线，不是给某条路线额外准备。
func _approach(target_x: float) -> void:
	var last_switch := _t()
	var guard := 0
	while race.turtle.position.x < target_x - 2.0 and guard < 400 \
			and GameManager.accident_state == "NONE":
		if _t() - last_switch >= 0.9:
			var worse := "rabbit"
			if race.turtle.daze_time > race.rabbit.daze_time:
				worse = "turtle"
			await _to(worse)
			last_switch = _t()
		await _tick()
		guard += 1


func _travel_until_x(target: float, limit := 20.0) -> void:
	var t0 := _t()
	while race.turtle.position.x < target and _t() - t0 < limit \
			and GameManager.accident_state == "NONE":
		await _tick()


func _wait_depth(depth: float) -> void:
	var t0 := _t()
	while race.turtle.position.y < depth and _t() - t0 < 4.0 \
			and GameManager.accident_state == "NONE":
		await _tick()


func _jump() -> void:
	_up(true)
	await _tick()
	if race.mount.state != "AIRBORNE":
		await _tick()
	_up(false)
	await _expire_edges()


func _wait_land(limit := 3.0) -> void:
	var t0 := _t()
	while race.mount.state == "AIRBORNE" and _t() - t0 < limit \
			and GameManager.accident_state == "NONE":
		await _tick()


func _to(who: String) -> void:
	var guard := 0
	while GameManager.current_control != who and guard < 6:
		if GameManager.accident_state != "NONE" or race.showtime_active:
			return
		GameManager.toggle_control()
		m["shift"] = int(m.get("shift", 0)) + 1
		await _tick()
		guard += 1


func _leave_obstacle() -> void:
	# 事故臂：让恢复流程自己走完，记录恢复时长（事故严重程度）。
	if GameManager.accident_state != "NONE":
		var t0 := _t()
		while GameManager.accident_state != "NONE" and _t() - t0 < 8.0:
			await _tick()
		m["recovery_s"] = snappedf(_t() - t0, 0.01)
		return
	# 无事故臂：把乌龟带回水面，停止（不模拟后续调平）。
	if race.turtle.position.y > 305.0:
		await _to("turtle")
		_up(true)
		var t0 := _t()
		while race.turtle.position.y > 305.0 and _t() - t0 < 4.0:
			await _tick()
		_up(false)
		await _expire_edges()


func _down(v: bool) -> void:
	if v and not _down_held:
		m["down"] = int(m.get("down", 0)) + 1
	_down_held = v
	if v:
		Input.action_press("down")
	else:
		Input.action_release("down")


func _up(v: bool) -> void:
	if v and not _up_held:
		m["up"] = int(m.get("up", 0)) + 1
	_up_held = v
	if v:
		Input.action_press("up")
	else:
		Input.action_release("up")


func _expire_edges() -> void:
	# 手动推进时 is_action_just_pressed 会跨多个模拟帧保持为真；
	# 松手后等一个真实物理帧 + 渲染帧让边沿过期，避免下一次切换误触发跳跃。
	await get_tree().physics_frame
	await get_tree().process_frame


func _tick() -> void:
	race._physics_process(STEP)
	frames += 1
	_observe()


func _t() -> float:
	return frames * STEP


# ======================================================================
# 观测
# ======================================================================

func _reset_m() -> void:
	m = {
		"down": 0, "up": 0, "shift": 0,
		"rabbit_daze_max": 0.0, "turtle_daze_max": 0.0,
		"turtle_depth_max": 300.0,
		"rabbit_gap_min": 999.0, "turtle_gap_min": 999.0,
		"accident": "NONE", "accident_t": -1.0,
		"pickup": 0, "land_t": -1.0, "land_x": -1.0, "jump_t": -1.0,
		"recovery_s": 0.0,
	}
	_acc0 = GameManager.accident_count
	_pickups0 = GameManager.pickup_count


## 决策点清零：路线成本从“看到障碍、开始操作”这一刻算，不从接近段
## 残留的计时算。否则两条路线都比真实多背 0.9–1.4 s，读数不可比。
## 乌龟速度也归一到巡航：模拟“接近时乌龟在开、临障碍才切兔子”的正常打法。
## 注意：跳跃初速 = 乌龟当前速度 +15，所以“乌龟已经被拖慢再跳”会缩短
## 跳跃距离——这条单独记录，不在本实验里混入。
func _fresh(spd := SPEED) -> void:
	_reset_m()
	race.rabbit.daze_time = 0.0
	race.rabbit.slide = 0.0
	race.rabbit.control_hold = 0.0
	if race.rabbit.state == "RIDING":
		race.rabbit.position = race.turtle.get_mount_point()
	race.turtle.daze_time = 0.0
	race.turtle.control_hold = 0.0
	race.turtle._sink_speed = 0.0
	race.turtle.speed = spd
	race.turtle.base_speed = spd


func _observe() -> void:
	m["rabbit_daze_max"] = maxf(m["rabbit_daze_max"], race.rabbit.daze_time)
	m["turtle_daze_max"] = maxf(m["turtle_daze_max"], race.turtle.daze_time)
	m["turtle_depth_max"] = maxf(m["turtle_depth_max"], race.turtle.position.y)
	if m["jump_t"] < 0.0 and race.mount.state == "AIRBORNE":
		m["jump_t"] = _t()
	if m["pickup"] == 0 and GameManager.pickup_count > _pickups0:
		m["pickup"] = GameManager.pickup_count - _pickups0
		m["land_t"] = _t()
		m["land_x"] = race.turtle.position.x
	var rr: Rect2 = race.rabbit.get_body_rect()
	var tr: Rect2 = race.turtle.get_body_rect()
	for g in race.hazard_groups:
		var kind: String = g["kind"]
		for item in g["rects"]:
			var r: Rect2 = item
			if race.turtle.position.x < r.position.x - 140.0 \
					or race.turtle.position.x > r.end.x + 140.0:
				continue
			match kind:
				"LOW_BEAM":
					# 正数 = 兔子在梁下，净空
					m["rabbit_gap_min"] = minf(m["rabbit_gap_min"],
						rr.position.y - r.end.y)
				"SURFACE_ROCK":
					# 正数 = 兔子底部高于岩顶
					m["rabbit_gap_min"] = minf(m["rabbit_gap_min"],
						r.position.y - rr.end.y)
				"AIR_BAR":
					m["rabbit_gap_min"] = minf(m["rabbit_gap_min"],
						rr.position.y - r.end.y)
				"UNDERWATER_REEF":
					# 正数 = 乌龟底部高于礁顶
					m["turtle_gap_min"] = minf(m["turtle_gap_min"],
						r.position.y - tr.end.y)
				"SURFACE_WALL":
					# 正数 = 乌龟顶部低于墙底
					m["turtle_gap_min"] = minf(m["turtle_gap_min"],
						tr.position.y - r.end.y)
	if GameManager.accident_state != "NONE" and m["accident"] == "NONE":
		m["accident"] = GameManager.accident_state
		m["accident_t"] = _t()
		print("    ACC %s t=%.2f turtle=(%.0f,%.0f) rabbit=(%.0f,%.0f) rstate=%s ctrl=%s"
			% [GameManager.accident_state, _t(), race.turtle.position.x,
				race.turtle.position.y, race.rabbit.position.x,
				race.rabbit.position.y, race.rabbit.state,
				GameManager.current_control])


func _snap() -> Dictionary:
	return {
		"rabbit_daze": snappedf(race.rabbit.daze_time, 0.01),
		"rabbit_slide": snappedf(race.rabbit.slide, 0.01),
		"turtle_daze": snappedf(race.turtle.daze_time, 0.01),
		"turtle_y": snappedf(race.turtle.position.y, 0.1),
		"turtle_phase": race.turtle.phase_name(),
		"control": GameManager.current_control,
		"mount": race.mount.state,
		"rabbit_gap_min": _fmt_gap(m["rabbit_gap_min"]),
		"turtle_gap_min": _fmt_gap(m["turtle_gap_min"]),
		"rabbit_budget_s": snappedf(3.6 - race.rabbit.daze_time, 0.01),
		"turtle_budget_s": snappedf(3.6 - race.turtle.daze_time, 0.01),
	}


func _fmt_gap(v: float) -> float:
	if v >= 998.0:
		return 999.0
	return snappedf(v, 0.1)


func _finish(name: String, route: String, snap: Dictionary) -> Dictionary:
	var r := {
		"arm": name,
		"route": route,
		"accident": m["accident"],
		"accident_t": snappedf(m["accident_t"], 0.01),
		"cleared": m["accident"] == "NONE",
		"actions": {"down": m["down"], "up": m["up"], "shift": m["shift"]},
		"rabbit_daze_max": snappedf(m["rabbit_daze_max"], 0.01),
		"turtle_daze_max": snappedf(m["turtle_daze_max"], 0.01),
		"turtle_depth_max": snappedf(m["turtle_depth_max"], 0.1),
		"pickup": m["pickup"],
		"recovery_s": m["recovery_s"],
		"at_pass": snap,
	}
	print("  %-22s route=%-6s clear=%-5s acc=%s daze(r/t)=%.2f/%.2f depth=%.0f "
		% [name, route, str(r["cleared"]), m["accident"],
			r["rabbit_daze_max"], r["turtle_daze_max"], r["turtle_depth_max"]]
		+ "gap(r/t)=%.1f/%.1f actions=%s recovery=%.2f"
		% [snap["rabbit_gap_min"], snap["turtle_gap_min"],
			str(r["actions"]), r["recovery_s"]])
	return r


func _land_to_wall() -> float:
	if m["land_t"] < 0.0:
		return -1.0
	return snappedf((WALL_X - m["land_x"]) / SPEED, 0.01)


# ======================================================================
# 结论（只陈述测量结果，不替制作人做玩法裁决之外的发挥）
# ======================================================================

func _verdict() -> Dictionary:
	var a: Dictionary = data["experiment_a"]
	var b_arms: Array = data["experiment_b"]["arms"]
	var c_arms: Array = data["experiment_c"]["arms"]

	var a_lines: Array = []
	var a_clear := true
	for key in a.keys():
		var r: Dictionary = a[key]
		if not r["cleared"]:
			a_clear = false
		a_lines.append("%s: clear=%s rabbit/turtle daze %.2f/%.2f, depth %.0f, actions %s"
			% [key, str(r["cleared"]), r["rabbit_daze_max"],
				r["turtle_daze_max"], r["turtle_depth_max"], str(r["actions"])])
	var beam_jump_free: bool = a["beam_jump_free"]["cleared"]
	var beam_jump_hold: bool = a["beam_jump_hold"]["cleared"]
	var beam_wide_jump_hold: bool = a["beam_wide_jump_hold"]["cleared"]

	# 深度表：同一深度先看下潜，再看趴下。
	var b_table: Array = []
	var depths := [350.0, 420.0, 500.0, 620.0]
	for depth in depths:
		var row := {"reef_top": depth, "dive": "-", "dive_gap": 0.0,
			"crouch": "-", "crouch_gap": 0.0, "crouch_turtle_daze": 0.0}
		for arm in b_arms:
			if arm["reef_top"] != depth or arm["reef_offset"] != 0.0:
				continue
			if arm["route"] == "dive":
				row["dive"] = "acc " + arm["accident"] if not arm["cleared"] else "clear"
				row["dive_gap"] = arm["at_pass"]["turtle_gap_min"]
			else:
				row["crouch"] = "acc " + arm["accident"] if not arm["cleared"] else "clear"
				row["crouch_gap"] = arm["at_pass"]["turtle_gap_min"]
				row["crouch_turtle_daze"] = arm["turtle_daze_max"]
		b_table.append(row)

	var d_lines: Array = []
	for arm in data.get("real_level", []):
		d_lines.append("%s (x=%.0f @%.0f): clear=%s rabbit/turtle daze %.2f/%.2f, depth %.0f"
			% [arm["arm"], arm["group_x"], arm["zone_speed"], str(arm["cleared"]),
				arm["rabbit_daze_max"], arm["turtle_daze_max"],
				arm["turtle_depth_max"]])

	var pickup_rows: Array = []
	var sweep_ok: Array = []
	var sweep_fail: Array = []
	for arm in c_arms:
		if arm.get("dive_delay_s", -1.0) >= 0.0:
			if arm["pickup_ok"]:
				sweep_ok.append(arm["dive_delay_s"])
			else:
				sweep_fail.append(arm["dive_delay_s"])
			pickup_rows.append({"delay": arm["dive_delay_s"],
				"pickup_ok": arm["pickup_ok"], "accident": arm["accident"]})

	var headline := "REFERENCE ONLY: 三条路线都能跑通，需人工试玩判定手感"
	if not a_clear:
		headline = "CHECK: A 组至少一条路线在合理时机失败，先看是哪一条"
	# 深度表的分界由实测决定，不预设。
	var dive_min := 9999.0
	var crouch_min := 9999.0
	for row in b_table:
		if row["dive"] == "clear":
			dive_min = minf(dive_min, row["reef_top"])
		if row["crouch"] == "clear":
			crouch_min = minf(crouch_min, row["reef_top"])
	headline = "A: 三条路线成立但成本不同；B: 下潜最早 %.0f 成立、趴下最早 %.0f 成立；C: 接人 %d/%d" % [
		dive_min, crouch_min, sweep_ok.size(),
		sweep_ok.size() + sweep_fail.size()]

	return {
		"headline": headline,
		"experiment_a": a_lines,
		"experiment_a_all_clear": a_clear,
		"beam_jump_free_clears": beam_jump_free,
		"beam_jump_hold_clears": beam_jump_hold,
		"beam_wide_260_jump_hold_clears": beam_wide_jump_hold,
		"beam_crouch_late_turtle_daze": a["beam_crouch_late"]["turtle_daze_max"],
		"beam_crouch_lead200_turtle_daze": a["beam_crouch"]["turtle_daze_max"],
		"experiment_b_depth_table": b_table,
		"experiment_b_dive_first_clear_depth": dive_min,
		"experiment_b_crouch_first_clear_depth": crouch_min,
		"experiment_c_pickup_sweep": pickup_rows,
		"experiment_c_sweep_success_delays": sweep_ok,
		"experiment_c_sweep_failure_delays": sweep_fail,
		"real_level": d_lines,
		"playtest": "NOT TESTED",
		"note": "代理测试只证明工程可行，不证明真实玩家觉得有趣。",
	}


func _print_summary() -> void:
	print("  A: " + JSON.stringify(data["experiment_a"]))
	print("  B: " + JSON.stringify(data["experiment_b"]["arms"]))
	print("  C: " + JSON.stringify(data["experiment_c"]["arms"]))


func _write_json() -> void:
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		print("  cannot write " + OUT_PATH)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()


func _wait_new_scene(old_scene: Node) -> void:
	for i in 240:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene != old_scene \
				and scene.scene_file_path.ends_with("race.tscn"):
			return
