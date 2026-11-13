extends Node
## STAGE 4 · 非对称冲浪板灰盒 A–F
##
## 制作人 2026-11-11 指令：兔子站在龟壳上冲浪；取消玩家用上/下直接控制乌龟深度；
## 乌龟受控时自动浮力回 NEUTRAL_DEPTH，失控才下沉，重新受控自动上浮。
## 本灰盒只回答“新机制在现有几何下能不能工作”，不预设任何结论：
##
##   A 受控自动回巡航（深水 / 水面两种起点，旧的“不动”作为改前对照）
##   B 失控下沉曲线 + 中途收回控制后自动上浮 + SHIFT 不清零
##   C 兔子站立 / 跳跃真实分离 / 落回龟壳
##   D 水下障碍：旧“按住下潜”路线 vs 新“让乌龟自己沉”路线的时序与可过宽度
##   E 接回容错：起跳时乌龟已下沉多少还能接住；过墙后多久收回控制不会重新撞墙
##   F BRO OLLIE：真弹跳与纯演出的可行性边界
##
## 每个臂固定 1/60 步长手动推进 race.tscn；不冲线、不写 best.json。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT \
##       res://scenes/stage4_surfboard.tscn
## 输出：docs/reports/stage4-surfboard.json / .log

const OUT_PATH := "res://docs/reports/stage4-surfboard.json"
const LOG_PATH := "res://docs/reports/stage4-surfboard.log"
const STEP := 1.0 / 60.0
const START_X := 2000.0
const OX := 2200.0

var is_runner := false
var race
var frames := 0
var t0 := 0.0
var m := {}
var data := {}
var log_lines: Array[String] = []
var _up_held := false
var _down_held := false


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4SurfboardRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "en"
	data = {
		"stage": 4,
		"step": STEP,
		"neutral": Tuning.NEUTRAL_DEPTH,
		"world_shift": Tuning.WORLD_Y_SHIFT,
		"runs": {},
	}
	# 改前 / 改后必须在同一次运行里出（QC 标准 4）：机器状态、时间缩放、
	# 场景版本都一样，两组数字才是可比的；跨轮次的旧基线会被数值改动带偏。
	Tuning.SURFBOARD_PHYSICS = false
	data["runs"]["old"] = await _suite(false)
	Tuning.SURFBOARD_PHYSICS = true
	data["runs"]["new"] = await _suite(true)

	data["verdict"] = _verdict()
	_write_files()
	print("STAGE4 SURFBOARD: " + data["verdict"]["headline"])
	get_tree().quit(0)


func _suite(new_physics: bool) -> Dictionary:
	var out := {}
	await _note("==== %s ====" % ("NEW (surfboard)" if new_physics else "OLD (manual up/down)"))
	out["a_auto_cruise"] = await _arm_a_auto_cruise()
	out["b_sink_rise"] = await _arm_b_sink_rise()
	out["c_jump"] = await _arm_c_jump()
	out["g_manual_depth"] = await _arm_g_manual_depth()
	if new_physics:
		out["d_wall_sink"] = await _arm_d_walls("sink")
		out["e_tolerance"] = await _arm_e_tolerance()
		out["f_bro_ollie"] = await _arm_f_bro_ollie()
		out["d_wall_zone"] = await _arm_wall_zone_sweep()
	else:
		out["d_wall_dive"] = await _arm_d_walls("dive")
	return out


# ======================================================================
# A 受控自动回巡航
# ======================================================================

func _arm_a_auto_cruise() -> Dictionary:
	var res := {}

	# A1 深水受控：旧模型没有任何输入就停在原地；新模型应自动浮回巡航。
	var deep := _base_y() + 180.0
	await _setup([], [], START_X, deep)
	await _to("turtle")
	_begin("A1")
	var t_start := _t()
	var settled := -1.0
	while _t() - t_start < 6.0 and GameManager.accident_state == "NONE":
		await _tick()
		if absf(race.turtle.position.y - Tuning.NEUTRAL_DEPTH) <= 1.0 \
				and absf(m["vy_last"]) <= 2.0:
			settled = snappedf(_t() - t_start, 0.01)
			break
	res["from_deep"] = {
		"start_y": deep,
		"end_y": snappedf(race.turtle.position.y, 0.1),
		"settle_s": settled,
		"max_rise_speed": snappedf(m.get("vy_max", 0.0), 1.0),
		"accident": GameManager.accident_state,
	}

	# A2 水面受控：新模型应缓慢沉到巡航水深，而不是瞬移。
	await _setup([], [], START_X, _base_y())
	if Tuning.SURFBOARD_PHYSICS:
		race.turtle.position.y = 300.0
	await _to("turtle")
	_begin("A2")
	var t2 := _t()
	var sank_at := -1.0
	while _t() - t2 < 4.0 and GameManager.accident_state == "NONE":
		await _tick()
		if absf(race.turtle.position.y - Tuning.NEUTRAL_DEPTH) <= 1.0 \
				and absf(m["vy_last"]) <= 2.0:
			sank_at = snappedf(_t() - t2, 0.01)
			break
	res["from_surface"] = {
		"start_y": 300.0,
		"end_y": snappedf(race.turtle.position.y, 0.1),
		"settle_s": sank_at,
		"max_sink_speed": snappedf(m.get("vy_min_abs", 0.0), 1.0),
	}

	# A3 0.6 s 短交接：计时与位置在任何模型下都不该被切换抹掉。
	await _setup([], [], START_X, _base_y())
	await _to("rabbit")
	var t3 := _t()
	while _t() - t3 < 0.6:
		await _tick()
	var before := _snap()
	await _to("turtle")
	var after := _snap()
	res["short_handoff"] = {
		"y_before": before["turtle_y"], "y_after": after["turtle_y"],
		"daze_before": before["turtle_daze"], "daze_after": after["turtle_daze"],
	}
	return res


# ======================================================================
# B 失控下沉 / 收回控制自动上浮
# ======================================================================

func _arm_b_sink_rise() -> Dictionary:
	var res := {}
	await _setup([], [], START_X, _base_y())
	var start_y: float = race.turtle.position.y
	_begin("B1")
	var samples := {}
	var marks := [0.8, 1.6, 2.4, 3.2, 3.6]
	var mi := 0
	var acc_t := -1.0
	while _t() - t0 < 5.0:
		await _tick()
		var el := _t() - t0
		if mi < marks.size() and el >= marks[mi]:
			samples["t%.1f" % marks[mi]] = snappedf(race.turtle.position.y - start_y, 0.1)
			mi += 1
		if GameManager.accident_state != "NONE" and acc_t < 0.0:
			acc_t = snappedf(el, 0.01)
			break
	res["sink_curve"] = {
		"start_y": start_y,
		"deltas": samples,
		"accident": GameManager.accident_state,
		"accident_t": acc_t,
		"max_sink_speed": snappedf(m.get("vy_max", 0.0), 1.0),
	}

	# B2 下沉中途收回控制：新模型自动上浮；旧模型没有输入就停在深处。
	res["recover"] = []
	for hold in [1.5, 2.5]:
		await _setup([], [], START_X, _base_y())
		await _to("rabbit")
		var th := _t()
		while _t() - th < hold and GameManager.accident_state == "NONE":
			await _tick()
		var y_sw: float = race.turtle.position.y
		var daze_sw: float = race.turtle.daze_time
		await _to("turtle")
		_begin("B2_%.1f" % hold)
		var tr := _t()
		var rise_s := -1.0
		while _t() - tr < 6.0 and GameManager.accident_state == "NONE":
			await _tick()
			if absf(race.turtle.position.y - Tuning.NEUTRAL_DEPTH) <= 1.0 \
					and absf(m["vy_last"]) <= 2.0:
				rise_s = snappedf(_t() - tr, 0.01)
				break
		res["recover"].append({
			"hold_s": hold,
			"y_at_switch": snappedf(y_sw, 0.1),
			"daze_at_switch": snappedf(daze_sw, 0.001),
			"y_after_6s": snappedf(race.turtle.position.y, 0.1),
			"rise_s": rise_s,
			"daze_after": snappedf(race.turtle.daze_time, 0.01),
			"accident": GameManager.accident_state,
		})
	return res


# ======================================================================
# C 兔子站立 / 跳跃 / 落回
# ======================================================================

func _arm_c_jump() -> Dictionary:
	var res := {"arms": []}
	# C1 巡航水深上的普通跳跃。
	res["arms"].append(await _jump_arm("C1_neutral", 0.0, 0.0))
	# C2 乌龟刚开始下沉（0.9 s）时起跳。
	res["arms"].append(await _jump_arm("C2_sinking_0.9s", 0.9, 0.0))
	# C3 乌龟已下沉 40 px 时起跳：落回是否还成立。
	res["arms"].append(await _jump_arm("C3_sunk_40px", 0.0, 40.0))
	return res


func _jump_arm(name: String, wait_s: float, sunk: float) -> Dictionary:
	await _setup([], [], START_X, _base_y())
	await _to("rabbit")
	if wait_s > 0.0:
		var tw := _t()
		while _t() - tw < wait_s and GameManager.accident_state == "NONE":
			await _tick()
	if sunk > 0.0:
		race.turtle.position.y = Tuning.NEUTRAL_DEPTH + sunk
		race.turtle._vy = 0.0
	var y_at_jump: float = race.turtle.position.y
	_begin(name)
	await _jump()
	var sep_max := 0.0
	var air := 0.0
	var picked := false
	var water := false
	while race.mount.state == "AIRBORNE" and _t() - t0 < 4.0:
		await _tick()
		sep_max = maxf(sep_max, race.turtle.get_mount_point().y - race.rabbit.position.y)
		air = _t() - t0
		if GameManager.accident_state != "NONE":
			break
	if race.mount.state == "RIDING":
		picked = true
	if GameManager.accident_state == "RABBIT_WATER":
		water = true
	return {
		"name": name,
		"jumped_at_y": snappedf(y_at_jump, 0.1),
		"separation_max_px": snappedf(sep_max, 0.1),
		"air_s": snappedf(air, 0.01),
		"jump_locked": air <= 0.0,
		"picked_back": picked,
		"water": water,
		"turtle_y_after": snappedf(race.turtle.position.y, 0.1),
		"accident": GameManager.accident_state,
	}


# ======================================================================
# D 水下障碍：旧“按住下潜” vs 新“让乌龟自己沉”
# ======================================================================

func _arm_d_walls(route: String) -> Dictionary:
	var res := {"route": route, "arms": []}
	if route == "sink":
		# 新模型的关键参数是“提前多久把控制交给兔子”，按宽度扫提前量。
		for w in [100.0, 120.0, 140.0]:
			for lead in [180.0, 200.0, 220.0, 240.0]:
				res["arms"].append(await _wall_arm("sink", w, lead))
		# 对照：一直握着乌龟、什么也不做 → 以巡航水深撞墙。
		res["arms"].append(await _wall_arm("none", 160.0, 0.0))
		# 制作人设想的“先跳开兔子”：在墙前 160 px 起跳。
		res["arms"].append(await _wall_arm("jumpoff", 160.0, 160.0))
		return res
	# 旧模型：按住下潜，提前 200 px 决策。
	for w in [120.0, 160.0, 200.0, 240.0, 300.0, 500.0]:
		res["arms"].append(await _wall_arm(route, w, 200.0))
	return res


func _arm_wall_zone_sweep() -> Dictionary:
	# 合成墙放进真实区段坐标，让 zone 2/3 的 240/260 真正生效
	# （base_speed 每帧由 race._update_zone 写回，直接改 turtle.base_speed 无效）。
	var res := {"arms": []}
	for zx in [20000.0, 42000.0]:
		for w in [80.0, 100.0]:
			for lead in [180.0, 200.0, 220.0, 240.0]:
				res["arms"].append(await _wall_arm("sink", w, lead, zx))
	return res


func _wall_arm(route: String, width: float, lead: float, base_x: float = OX) -> Dictionary:
	# 用旧坐标描述墙体，load_level 会按模型整体下移，保持相对几何。
	var group := {
		"group": "g_wall", "zone": 1, "kind": "SURFACE_WALL",
		"rects": [Rect2(base_x, 120, width, 180)],
		"hint": "SINK GATE", "action": "TAKE THE RABBIT",
	}
	await _setup([group], [], base_x - 500.0, _base_y())
	await _approach(base_x - lead)
	_fresh()
	_begin("D_%s_w%d_lead%d" % [route, int(width), int(lead)])
	match route:
		"dive":
			await _to("turtle")
			_down(true)
			await _wait_depth(345.0)
			_down(false)
		"jumpoff":
			await _to("rabbit")
			await _jump()
			await _wait_land()
		"none":
			# 对照：一直握着乌龟、什么也不做。
			await _to("turtle")
		_:
			await _to("rabbit")
	var y_enter: float = race.turtle.position.y
	var daze_enter: float = race.turtle.daze_time
	# 只走到“乌龟整个离开墙”（左侧 x ≥ 墙尾 + 52），然后立刻收回控制：
	# 真实打法就是过墙即切回，不会让它在失控状态下多走。
	var at_wall := await _travel_mark(base_x + width + 52.0, base_x + 20.0)
	var hit := false
	if GameManager.accident_state != "NONE":
		hit = true
	var y_exit: float = race.turtle.position.y
	var daze_exit: float = race.turtle.daze_time
	var rehit := false
	if not hit:
		await _to("turtle")
		var tr := _t()
		while _t() - tr < 3.0 and race.turtle.position.x < base_x + width + 260.0 \
				and GameManager.accident_state == "NONE":
			await _tick()
		if GameManager.accident_state != "NONE":
			rehit = true
	return {
		"route": route,
		"width": width,
		"lead": lead,
		"base_x": base_x,
		"y_at_entry": snappedf(y_enter, 0.1),
		"daze_at_entry": snappedf(daze_enter, 0.001),
		"y_at_wall": at_wall.get("y", -1.0),
		"daze_at_wall": at_wall.get("daze", -1.0),
		"t_to_wall": at_wall.get("t", -1.0),
		"y_at_exit": snappedf(y_exit, 0.1),
		"daze_at_exit": snappedf(daze_exit, 0.001),
		"x_at_exit": snappedf(race.turtle.position.x, 0.1),
		"pass": not hit,
		"rehit_after_recontrol": rehit,
		"accident": GameManager.accident_state,
		"turtle_repair": race.turtle.accident,
	}


# ======================================================================
# E 接回容错
# ======================================================================

func _arm_e_tolerance() -> Dictionary:
	var res := {"pickup": [], "recontrol": []}
	# E1 起跳时乌龟已下沉 k px：落回还能不能接住。
	for k in [0.0, 30.0, 45.0, 60.0, 75.0, 90.0]:
		var arm := await _jump_arm("E1_sunk_%d" % int(k), 0.0, k)
		arm["sunk_at_jump"] = k
		res["pickup"].append(arm)
	# E2 过墙后延迟多久收回控制才不会重新撞墙。
	for dly in [0.0, 0.2, 0.4, 0.6, 1.0]:
		res["recontrol"].append(await _recontrol_arm(dly))
	return res


func _recontrol_arm(delay: float) -> Dictionary:
	_note("-- E2_recontrol_%.1f" % delay)
	var width := 120.0
	var group := {
		"group": "g_wall", "zone": 1, "kind": "SURFACE_WALL",
		"rects": [Rect2(OX, 120, width, 180)],
		"hint": "SINK GATE", "action": "TAKE THE RABBIT",
	}
	await _setup([group], [], OX - 500.0, _base_y())
	await _approach(OX - 200.0)
	_fresh()
	await _to("rabbit")
	# 走过整面墙（乌龟左缘越过墙尾），然后按 delay 决定多久收手。
	await _travel_until_x(OX + width + 52.0)
	if GameManager.accident_state != "NONE":
		return {"delay": delay, "pass": false, "accident": GameManager.accident_state}
	var y_clear: float = race.turtle.position.y
	var daze_clear: float = race.turtle.daze_time
	var tw := _t()
	while _t() - tw < delay and GameManager.accident_state == "NONE":
		await _tick()
	await _to("turtle")
	var tr := _t()
	var rehit := false
	while _t() - tr < 3.0 and race.turtle.position.x < OX + width + 400.0:
		await _tick()
		if GameManager.accident_state != "NONE":
			rehit = true
			break
	return {
		"delay": delay,
		"pass": not rehit,
		"rehit": rehit,
		"y_at_clear": snappedf(y_clear, 0.1),
		"daze_at_clear": snappedf(daze_clear, 0.001),
		"y_at_recontrol": snappedf(race.turtle.position.y, 0.1),
		"accident": GameManager.accident_state,
	}


# ======================================================================
# F BRO OLLIE
# ======================================================================

func _arm_f_bro_ollie() -> Dictionary:
	var res := {}
	# F1 真弹跳：给乌龟一个向上冲量，看自动浮力多久把它拉回来、
	#    以及弹起后是不是反而更容易撞墙（墙需要“更深”，不是“更高”）。
	await _setup([], [], START_X, _base_y())
	await _to("turtle")
	race.turtle._vy = -260.0
	_begin("F1")
	var top: float = race.turtle.position.y
	var back_s := -1.0
	var tf := _t()
	while _t() - tf < 4.0:
		await _tick()
		top = minf(top, race.turtle.position.y)
		if absf(race.turtle.position.y - Tuning.NEUTRAL_DEPTH) <= 1.0 \
				and absf(m["vy_last"]) <= 2.0:
			back_s = snappedf(_t() - tf, 0.01)
			break
	res["real_pop"] = {
		"rise_px": snappedf(Tuning.NEUTRAL_DEPTH - top, 0.1),
		"return_s": back_s,
	}
	# F2 纯演出弹跳：只把绘制用的机位抬高，不动机位判定。
	#    接人用的是 turtle.get_mount_point()，所以演出偏移会直接改变接人几何。
	await _setup([], [], START_X, _base_y())
	await _to("rabbit")
	_begin("F2")
	await _jump()
	var dy_ride: float = race.turtle.get_mount_point().y - race.rabbit.position.y
	res["visual_pop"] = {
		"mount_offset_if_pop_24px": 24.0,
		"pickup_dy_without_pop": snappedf(dy_ride, 0.1),
		"pickup_dy_with_pop": snappedf(dy_ride - 24.0, 0.1),
		"dy_limit": [Tuning.PICKUP_DY_MIN, Tuning.PICKUP_DY_MAX],
	}
	return res


# ======================================================================
# 公共：场景 / 步进 / 输入
# ======================================================================

func _base_y() -> float:
	return Tuning.NEUTRAL_DEPTH if Tuning.SURFBOARD_PHYSICS else 300.0


## 只加载一次 race.tscn：每个臂原地重置。三角色都是普通节点，
## 重置所有计时/位置后等同于新开一局，但省掉 40 多次场景重载。
func _ensure_race() -> void:
	if race != null and is_instance_valid(race):
		return
	var old := get_tree().current_scene
	GameManager.start_race()
	await _wait_new_scene(old)
	await get_tree().process_frame
	race = get_tree().current_scene
	race.set_physics_process(false)


func _setup(groups: Array, lanes: Array, x: float, y: float) -> void:
	await _ensure_race()
	race.test_disable_hazards = false
	race.test_no_finish = true
	race.load_level(groups, lanes)
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
	race.turtle.position = Vector2(x, y)
	race.turtle.speed = 220.0
	race.turtle.base_speed = 220.0
	race.turtle.state = "CRUISING"
	race.turtle.accident = false
	race.turtle.daze_time = 0.0
	race.turtle.control_hold = 0.0
	race.turtle._sink_speed = 0.0
	race.turtle._vy = 0.0
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
	_up_held = false
	_down_held = false
	frames = 0
	m = {"vy_max": 0.0, "vy_min_abs": 0.0, "vy_last": 0.0}
	await _tick()
	await _expire_edges()


func _fresh() -> void:
	race.turtle.daze_time = 0.0
	race.turtle.control_hold = 0.0
	race.turtle._sink_speed = 0.0
	race.rabbit.daze_time = 0.0
	race.rabbit.slide = 0.0
	race.rabbit.state = "RIDING"
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.mark_riding()
	race.hazard_cooldown = 0.0
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.turtle_grace = 0.0
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.accident_state = "NONE"


func _approach(target_x: float) -> void:
	var last_switch := _t()
	var guard := 0
	while race.turtle.position.x < target_x - 2.0 and guard < 900 \
			and GameManager.accident_state == "NONE":
		if _t() - last_switch >= 0.9:
			var worse := "rabbit"
			if race.turtle.daze_time > race.rabbit.daze_time:
				worse = "turtle"
			await _to(worse)
			last_switch = _t()
		await _tick()
		guard += 1


## 走到 target，并在第一次越过 mark 时记下深度/计时（用来区分“换人点”和“入墙点”）。
func _travel_mark(target: float, mark: float, limit := 14.0) -> Dictionary:
	var rec := {}
	var ts := _t()
	while race.turtle.position.x < target and _t() - ts < limit \
			and GameManager.accident_state == "NONE":
		if rec.is_empty() and race.turtle.position.x >= mark:
			rec = {
				"y": snappedf(race.turtle.position.y, 0.1),
				"daze": snappedf(race.turtle.daze_time, 0.001),
				"t": snappedf(_t() - ts, 0.01),
			}
		await _tick()
	return rec


func _travel_until_x(target: float, limit := 14.0) -> void:
	var ts := _t()
	while race.turtle.position.x < target and _t() - ts < limit \
			and GameManager.accident_state == "NONE":
		await _tick()


func _wait_depth(depth: float) -> void:
	var ts := _t()
	while race.turtle.position.y < depth and _t() - ts < 4.0 \
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
	var ts := _t()
	while race.mount.state == "AIRBORNE" and _t() - ts < limit \
			and GameManager.accident_state == "NONE":
		await _tick()


func _to(who: String) -> void:
	var guard := 0
	while GameManager.current_control != who and guard < 6:
		if GameManager.accident_state != "NONE" or race.showtime_active:
			return
		GameManager.toggle_control()
		await _tick()
		guard += 1


func _down(v: bool) -> void:
	_down_held = v
	if v:
		Input.action_press("down")
	else:
		Input.action_release("down")


func _up(v: bool) -> void:
	_up_held = v
	if v:
		Input.action_press("up")
	else:
		Input.action_release("up")


func _expire_edges() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame


func _begin(name: String) -> void:
	_note("-- " + name)
	t0 = _t()
	m["vy_max"] = 0.0
	m["vy_min_abs"] = 0.0
	m["vy_last"] = 0.0


func _tick() -> void:
	var y0: float = race.turtle.position.y
	race._physics_process(STEP)
	frames += 1
	var vy: float = (race.turtle.position.y - y0) / STEP
	m["vy_last"] = vy
	if vy > 0.0:
		m["vy_max"] = maxf(m["vy_max"], vy)
	else:
		m["vy_min_abs"] = maxf(m["vy_min_abs"], -vy)


func _t() -> float:
	return frames * STEP


func _snap() -> Dictionary:
	return {
		"turtle_y": snappedf(race.turtle.position.y, 0.1),
		"turtle_x": snappedf(race.turtle.position.x, 0.1),
		"turtle_daze": snappedf(race.turtle.daze_time, 0.001),
		"rabbit_daze": snappedf(race.rabbit.daze_time, 0.001),
		"accident": GameManager.accident_state,
		"mount": race.mount.state,
		"control": GameManager.current_control,
	}


# ======================================================================
# G 旧手动上下入口：乌龟受控时按住 up / down 各 1 s，
# 新模型深度不应改变（旧模型 down 会下潜）。
# ======================================================================

func _arm_g_manual_depth() -> Dictionary:
	var res := {}
	for dir in ["down", "up"]:
		await _setup([], [], START_X, _base_y())
		await _to("turtle")
		var ts := _t()
		while _t() - ts < 1.0 and GameManager.accident_state == "NONE":
			await _tick()
		var y0: float = race.turtle.position.y
		if dir == "down":
			_down(true)
		else:
			_up(true)
		ts = _t()
		while _t() - ts < 1.0 and GameManager.accident_state == "NONE":
			await _tick()
		if dir == "down":
			_down(false)
		else:
			_up(false)
		await _expire_edges()
		res[dir] = {
			"y0": snappedf(y0, 0.1),
			"y1": snappedf(race.turtle.position.y, 0.1),
			"dy": snappedf(race.turtle.position.y - y0, 0.1),
			"mount": race.mount.state,
			"control": GameManager.current_control,
		}
		await _note("G  hold %-4s 1 s  y %.1f -> %.1f  (dy %+.1f)" % [
			dir, y0, race.turtle.position.y, race.turtle.position.y - y0])
	return res


# ======================================================================
# 输出
# ======================================================================

func _verdict() -> Dictionary:
	var has_old: bool = data["runs"].has("old")
	var old_y: Dictionary = data["runs"]["old"] if has_old else {}
	var new_y: Dictionary = data["runs"]["new"]
	var walls: Array = new_y["d_wall_sink"]["arms"]
	var widths := {}
	for arm in walls:
		if arm["route"] == "sink":
			var key := "%d" % int(arm["width"])
			if arm["pass"]:
				widths[key] = true
			elif widths.get(key, false):
				pass
			else:
				widths[key] = false
	var max_ok := 0.0
	for w in [100, 120, 140, 160, 200, 240, 300, 500]:
		if widths.get("%d" % w, false):
			max_ok = float(w)
	return {
		"headline": "auto-cruise=%s, sink-accident=%.2fs, max wall passable via sink=%d px" % [
			str(new_y["a_auto_cruise"]["from_deep"]["settle_s"]),
			float(new_y["b_sink_rise"]["sink_curve"]["accident_t"]),
			int(max_ok)],
		"a_old_settle": old_y["a_auto_cruise"]["from_deep"]["settle_s"] if has_old else -1.0,
		"a_new_settle": new_y["a_auto_cruise"]["from_deep"]["settle_s"],
		"b_old_rise": old_y["b_sink_rise"]["recover"][0]["rise_s"] if has_old else -1.0,
		"b_new_rise": new_y["b_sink_rise"]["recover"][0]["rise_s"],
		"c_new_pickup": new_y["c_jump"]["arms"][0]["picked_back"],
		"d_sink_pass": widths,
		"g_manual_old": old_y.get("g_manual_depth", {}),
		"g_manual_new": new_y.get("g_manual_depth", {}),
		"playtest": "NOT TESTED",
	}


func _note(s: String) -> void:
	log_lines.append(s)
	print(s)
	# 立刻落盘：跑挂时也能看到卡在哪个臂。
	var l := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if l != null:
		l.store_string("\n".join(log_lines) + "\n")
		l.close()


func _write_files() -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
	var l := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if l != null:
		l.store_string("\n".join(log_lines) + "\n")
		l.close()


func _wait_new_scene(old_scene: Node) -> void:
	for i in 240:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene != old_scene \
				and scene.scene_file_path.ends_with("race.tscn"):
			return
