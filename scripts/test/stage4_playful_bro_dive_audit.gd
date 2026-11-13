extends Node
## TBB-SHIFT-PLAYFUL-04 §1：BRO DIVE 只读诊断。
##
## 只测量、不改玩法。固定 1/60 s 手动推进真实 race.gd，不依赖引擎帧率。
## 对正式关卡里每个 FLOATING_LOG（BRO DIVE 适用）记录：
##   - 判定区域（世界坐标）、组宽、区速、横穿时间、预警 lead；
##   - 起跳 lead × SHIFT/下潜 delay × 松↓ release 的成败矩阵；
##   - 第一次碰撞那一帧双方的真实坐标、谁先被撞、壳顶/兔子底与障碍的间隙；
##   - 单动作对照（什么都不做 / 只跳 / 只潜 / 下潜太晚 / 一直不松↓）；
##   - 失败归类：窗口过短 / 起跳过晚或过早 / 兔子轨迹进框 / 下潜太晚 /
##     松↓太早 / 没接住 / 其他。
##
## 只读：不写 best.json、不改正式场景、不改物理参数。
## 运行：
##   D:/Godot_v4.7-stable_win64_console.exe --headless --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage4_playful_bro_dive_audit.tscn
## 输出：docs/reports/longrun/playful04-bro-dive-audit.json

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/playful04-bro-dive-audit.json"
const STEP := 1.0 / 60.0
const LEADS := [120.0, 140.0, 160.0, 180.0, 200.0, 220.0]
const DELAYS := [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]
const RELEASES := [-40.0, 0.0, 40.0, 80.0, 120.0]
const REF_LEAD := 160.0
const REF_DELAY := 0.1
const REF_RELEASE := 40.0
const MAX_TICKS := 420

var is_runner := false
var race: Node = null
var summary := {}


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "PlayfulBroDiveAuditRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "en"
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("BRO DIVE AUDIT: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = false
	race.test_no_finish = true
	# 正式装载（含本局食物抽取），先记录真实关卡里需要 BRO DIVE 的障碍。
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	var draws: Array = race.snack_draws.duplicate(true)
	var groups: Array = race.hazard_groups
	var log_groups := []
	for g in groups:
		if String(g["kind"]) == "FLOATING_LOG":
			log_groups.append(g)
	summary["load"] = {
		"seed": int(race.level_seed),
		"hazard_groups": groups.size(),
		"floating_logs": log_groups.size(),
		"log_names": _names(log_groups),
		"draws": draws,
	}
	summary["design_logs"] = _design_logs()
	summary["replaced_logs"] = _replaced_logs(draws, _names(log_groups))
	# 诊断期间关掉食物（不改关卡几何；抽取结果已经应用在 groups 上）。
	race.boost_lanes.clear()
	race._snack_cache = []
	race._snack_cache_sig = -1

	summary["static"] = []
	for g in groups:
		if String(g["kind"]) == "FLOATING_LOG" or String(g["kind"]) == "HIGH_WALL":
			summary["static"].append(_static_row(g))

	if log_groups.is_empty():
		push_error("BRO DIVE AUDIT: no FLOATING_LOG after load")
		_write()
		get_tree().quit(1)
		return

	# 取首 / 中 / 尾三组有代表性的浮木。
	var core := []
	core.append(log_groups[0])
	if log_groups.size() >= 3:
		core.append(log_groups[int(floor(log_groups.size() / 2.0))])
	if log_groups.size() >= 2:
		core.append(log_groups[log_groups.size() - 1])
	var seen := {}
	var picked := []
	for g in core:
		var n := String(g["group"])
		if seen.has(n):
			continue
		seen[n] = true
		picked.append(g)
	summary["core_groups"] = _names(picked)

	for g in picked:
		print("AUDIT group=%s x=%.0f" % [String(g["group"]), race._group_start(g)])
		if not summary.has("groups"):
			summary["groups"] = {}
		summary["groups"][String(g["group"])] = _audit_group(g)

	print("BRO DIVE AUDIT: DONE")
	_write()
	get_tree().quit(0)


func _names(arr: Array) -> Array:
	var out := []
	for g in arr:
		out.append(String(g["group"]))
	return out


func _design_logs() -> Array:
	var out := []
	for spec in LevelData.GROUPS:
		if String(spec["kind"]) == "FLOATING_LOG":
			out.append({"group": String(spec["group"]), "x": float(spec["x"]),
				"zone": int(spec["zone"])})
	return out


func _replaced_logs(draws: Array, live: Array) -> Array:
	var out := []
	for d in draws:
		if String(d["group"]) in live:
			continue
		for spec in LevelData.GROUPS:
			if String(spec["group"]) == String(d["group"]):
				if String(spec["kind"]) == "FLOATING_LOG":
					out.append({"group": String(d["group"]),
						"now": String(d["kind"])})
				break
	return out


func _static_row(g: Dictionary) -> Dictionary:
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	var zone: Dictionary = LevelData.zone_at(start)
	var v := float(zone["base_speed"])
	var rects := []
	for r in g["rects"]:
		var rect: Rect2 = r
		rects.append({
			"x": snappedf(rect.position.x, 0.1),
			"y": snappedf(rect.position.y, 0.1),
			"w": snappedf(rect.size.x, 0.1),
			"h": snappedf(rect.size.y, 0.1),
		})
	return {
		"group": String(g["group"]), "kind": String(g["kind"]),
		"zone": int(zone["id"]), "speed": v,
		"start_x": snappedf(start, 0.1), "end_x": snappedf(end, 0.1),
		"width": snappedf(end - start, 0.1),
		"cross_s": snappedf((end - start) / v, 0.01),
		"warn_lead_s": snappedf(1100.0 / v, 0.01),
		"rects": rects,
	}


func _audit_group(g: Dictionary) -> Dictionary:
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	var zone: Dictionary = LevelData.zone_at(start)
	var entry := {
		"start_x": snappedf(start, 0.1), "end_x": snappedf(end, 0.1),
		"zone": int(zone["id"]), "speed": float(zone["base_speed"]),
		"core": [], "controls": {},
	}

	for lead in LEADS:
		for delay in DELAYS:
			for release in RELEASES:
				entry["core"].append(_run_case(g, lead, delay, release))

	entry["lead_sweep"] = []
	for lead in range(80, 301, 20):
		entry["lead_sweep"].append(_run_case(g, float(lead), REF_DELAY, REF_RELEASE))
	entry["delay_sweep"] = []
	for i in range(0, 31):
		entry["delay_sweep"].append(_run_case(g, REF_LEAD,
			snappedf(0.02 * float(i), 0.02), REF_RELEASE))
	entry["release_sweep"] = []
	for release in range(-80, 181, 20):
		entry["release_sweep"].append(_run_case(g, REF_LEAD, REF_DELAY, float(release)))

	for mode in ["idle", "rabbit_only", "turtle_only", "late_dive", "never_release"]:
		entry["controls"][mode] = _run_case(g, REF_LEAD, REF_DELAY, REF_RELEASE, false, mode)

	var ref := _run_case(g, REF_LEAD, REF_DELAY, REF_RELEASE, true)
	entry["ref"] = ref
	entry["summary"] = _summarize(entry)
	_print_summary(g, entry, ref)
	return entry


## 一次完整尝试。
## mode: combo / idle / rabbit_only / turtle_only / late_dive / never_release
func _run_case(g: Dictionary, lead: float, delay: float, release: float,
		manual: bool = false, mode: String = "combo") -> Dictionary:
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	var zone: Dictionary = LevelData.zone_at(start)
	var do_jump := mode in ["combo", "rabbit_only", "late_dive", "never_release"]
	var do_shift := mode in ["combo", "turtle_only", "late_dive", "never_release"]
	if mode == "late_dive":
		delay = 0.6
	if mode == "never_release":
		release = 1.0e6

	_reset_trial(start - lead, zone)
	var st := {
		"t": 0, "apex_y": 9999.0,
		"hit": false, "hit_t": -1.0, "hit_role": "", "hit_tx": 0.0, "hit_ty": 0.0,
		"hit_rx": 0.0, "hit_ry": 0.0, "hit_mount": "",
		"water": false, "water_t": -1.0, "water_ty": 0.0,
		"landed": false, "landing_t": -1.0, "land_dx": 0.0, "land_dy": 0.0,
		"prev_dx": 0.0, "prev_dy": 0.0, "was_air": false,
		"rabbit_bottom_max": -9999.0, "shell_top_max": -9999.0,
		"dive_depth_max": 0.0, "release_past_clear": -9999.0,
		"trajectory": [],
	}

	# 1) 起跳
	if do_jump:
		Input.action_press("up")
		race._note_up_input()
		_tick()
		st["t"] = int(st["t"]) + 1
		Input.action_release("up")
		_after_tick(g, st, manual, start)
	else:
		_tick()
		st["t"] = int(st["t"]) + 1
		_after_tick(g, st, manual, start)
	var jumped: bool = st["was_air"]

	# 2) 等 delay 后 SHIFT + 按住 ↓
	var delay_ticks := int(round(delay / STEP))
	for i in delay_ticks:
		if race.turtle.position.x > end + 220.0:
			break
		_tick()
		st["t"] = int(st["t"]) + 1
		_after_tick(g, st, manual, start)
	if do_shift:
		GameManager.toggle_control()
	if do_shift:
		Input.action_press("down")
	var dived := do_shift

	# 3) 推进过障碍
	while int(st["t"]) < MAX_TICKS and race.turtle.position.x <= end + 220.0:
		var x: float = race.turtle.position.x
		if dived and x >= end + release:
			Input.action_release("down")
			dived = false
			st["release_past_clear"] = x - (end + 48.0)
		_tick()
		st["t"] = int(st["t"]) + 1
		_after_tick(g, st, manual, start)
		if not manual and bool(st["hit"]):
			break
	if dived:
		Input.action_release("down")

	var ended_x: float = race.turtle.position.x
	var riding: bool = race.mount.state == "RIDING"
	var act: Dictionary = race.group_actions.get(String(g["group"]), {})
	var precise := false
	if race.has_method("_precise_action"):
		precise = race._precise_action("FLOATING_LOG", act)
	var passed: bool = jumped and ended_x > end + 150.0 and not bool(st["hit"]) \
		and riding and bool(st["landed"])
	var fail := "pass"
	if not passed:
		if bool(st["water"]) and not bool(st["hit"]):
			fail = "rabbit_water_not_caught"
		elif bool(st["hit"]):
			var role := String(st["hit_role"])
			if role == "rabbit":
				fail = "rabbit_hit_arc"
			elif role == "turtle":
				fail = "turtle_hit_dive_late"
			else:
				fail = "hit_unknown_role"
		elif not jumped:
			fail = "no_jump"
		elif not riding:
			fail = "lost_shell"
		elif not bool(st["landed"]):
			fail = "never_landed"
		else:
			fail = "incomplete"
	var log_top := 1.0e9
	var log_bottom := -1.0e9
	for r in g["rects"]:
		var rect: Rect2 = r
		log_top = minf(log_top, rect.position.y)
		log_bottom = maxf(log_bottom, rect.end.y)
	return {
		"lead": lead, "delay": snappedf(delay, 0.02),
		"release": release if release < 1.0e5 else -999.0,
		"mode": mode,
		"pass": passed, "fail": fail,
		"jumped": jumped, "precise": precise,
		"apex_above": snappedf(Tuning.NEUTRAL_DEPTH - float(st["apex_y"]), 0.1)
			if float(st["apex_y"]) < 9000.0 else -999.0,
		"rabbit_bottom_max": snappedf(float(st["rabbit_bottom_max"]), 0.1)
			if float(st["rabbit_bottom_max"]) > -900.0 else -999.0,
		"log_top": snappedf(log_top, 0.1),
		"rabbit_clearance": snappedf(log_top - float(st["rabbit_bottom_max"]), 0.1)
			if float(st["rabbit_bottom_max"]) > -900.0 else -999.0,
		"shell_top_max": snappedf(float(st["shell_top_max"]), 0.1)
			if float(st["shell_top_max"]) > -900.0 else -999.0,
		"log_bottom": snappedf(log_bottom, 0.1),
		"turtle_clearance": snappedf(float(st["shell_top_max"]) - log_bottom, 0.1)
			if float(st["shell_top_max"]) > -900.0 else -999.0,
		"dive_depth_max": snappedf(float(st["dive_depth_max"]), 0.1),
		"release_past_clear": snappedf(float(st["release_past_clear"]), 0.1)
			if float(st["release_past_clear"]) > -9000.0 else -999.0,
		"hit": bool(st["hit"]),
		"hit_role": String(st["hit_role"]),
		"hit_t": snappedf(float(st["hit_t"]), 0.01),
		"hit_tx": snappedf(float(st["hit_tx"]), 0.1),
		"hit_ty": snappedf(float(st["hit_ty"]), 0.1),
		"hit_rx": snappedf(float(st["hit_rx"]), 0.1),
		"hit_ry": snappedf(float(st["hit_ry"]), 0.1),
		"hit_mount": String(st["hit_mount"]),
		"water": bool(st["water"]),
		"water_t": snappedf(float(st["water_t"]), 0.01),
		"water_ty": snappedf(float(st["water_ty"]), 0.1),
		"land_dx": snappedf(float(st["land_dx"]), 0.1),
		"land_dy": snappedf(float(st["land_dy"]), 0.1),
		"landing_t": snappedf(float(st["landing_t"]), 0.01),
		"actions": act,
		"trajectory": st["trajectory"] if manual else [],
	}


## 每 tick 之后的统一观测：碰撞归因、清空间隙、接人、落水。
func _after_tick(g: Dictionary, st: Dictionary, manual: bool, start: float) -> void:
	var key := String(g["group"])
	var x: float = race.turtle.position.x
	var rb: Vector2 = race.rabbit.position
	var rr_raw: Rect2 = race.rabbit.get_body_rect()
	var tr_raw: Rect2 = race.turtle.get_body_rect()
	var rr: Rect2 = race._inset(rr_raw, 3.0)
	var tr: Rect2 = race._inset(tr_raw, 3.0)
	st["apex_y"] = minf(float(st["apex_y"]), rb.y)
	st["dive_depth_max"] = maxf(float(st["dive_depth_max"]),
		race.turtle.position.y - Tuning.NEUTRAL_DEPTH)

	# 兔子/乌龟各自的 x 与障碍 x 真正重叠时，才谈“清空没清空”。
	# 注意：_check_hazards 只把身体内缩 3 px，障碍矩形保持原样——不要重复内缩。
	for r in g["rects"]:
		var rect: Rect2 = r
		if rr_raw.position.x <= rect.end.x and rr_raw.end.x >= rect.position.x:
			st["rabbit_bottom_max"] = maxf(float(st["rabbit_bottom_max"]),
				rr_raw.end.y)
		if tr_raw.position.x <= rect.end.x and tr_raw.end.x >= rect.position.x:
			st["shell_top_max"] = maxf(float(st["shell_top_max"]),
				tr_raw.position.y)
		if not bool(st["hit"]) and race.hit_groups.has(key):
			# 游戏已经记了这一次碰撞；用与 _check_hazards 相同的顺序归因（兔子先判）。
			if rr.intersects(rect):
				st["hit_role"] = "rabbit"
			elif tr.intersects(rect):
				st["hit_role"] = "turtle"
			else:
				st["hit_role"] = "unknown"
	if race.hit_groups.has(key) and not bool(st["hit"]):
		st["hit"] = true
		st["hit_t"] = float(st["t"]) * STEP
		st["hit_tx"] = x - start
		st["hit_ty"] = race.turtle.position.y
		st["hit_rx"] = rb.x - start
		st["hit_ry"] = rb.y
		st["hit_mount"] = race.mount.state
	if GameManager.accident_state == "RABBIT_WATER" and not bool(st["water"]):
		st["water"] = true
		st["water_t"] = float(st["t"]) * STEP
		st["water_ty"] = race.turtle.position.y
	if bool(st["was_air"]) and race.mount.state == "RIDING" and not bool(st["landed"]):
		st["landed"] = true
		st["landing_t"] = float(st["t"]) * STEP
		st["land_dx"] = float(st["prev_dx"])
		st["land_dy"] = float(st["prev_dy"])
	if race.mount.state == "AIRBORNE":
		st["was_air"] = true
		var mp: Vector2 = race.turtle.get_mount_point()
		st["prev_dx"] = rb.x - mp.x
		st["prev_dy"] = rb.y - mp.y
	if manual and int(st["t"]) % 2 == 0:
		var traj: Array = st["trajectory"]
		traj.append({
			"t": snappedf(float(st["t"]) * STEP, 0.01),
			"tx": snappedf(x - start, 0.1),
			"ty": snappedf(race.turtle.position.y, 0.1),
			"rx": snappedf(rb.x - start, 0.1),
			"r_top": snappedf(rr_raw.position.y, 0.1),
			"r_bottom": snappedf(rr_raw.end.y, 0.1),
			"shell_top": snappedf(tr_raw.position.y, 0.1),
			"mount": race.mount.state,
			"ctrl": GameManager.current_control,
		})


func _summarize(entry: Dictionary) -> Dictionary:
	var core: Array = entry["core"]
	var passed := 0
	var fails := {}
	var by_delay := {}
	var by_lead := {}
	var by_release := {}
	for r in core:
		var d := str(float(r["delay"]))
		var l := str(float(r["lead"]))
		var rel := str(float(r["release"]))
		if not by_delay.has(d):
			by_delay[d] = 0
		if not by_lead.has(l):
			by_lead[l] = 0
		if not by_release.has(rel):
			by_release[rel] = 0
		if bool(r["pass"]):
			passed += 1
			by_delay[d] += 1
			by_lead[l] += 1
			by_release[rel] += 1
		else:
			var f := String(r["fail"])
			fails[f] = int(fails.get(f, 0)) + 1
	return {
		"pass": passed, "total": core.size(),
		"pass_rate": snappedf(float(passed) / maxf(float(core.size()), 1.0), 0.01),
		"fails": fails,
		"pass_by_delay": by_delay,
		"pass_by_lead": by_lead,
		"pass_by_release": by_release,
		"lead_span": _pass_span(entry["lead_sweep"], "lead"),
		"delay_span": _pass_span(entry["delay_sweep"], "delay"),
		"release_span": _pass_span(entry["release_sweep"], "release"),
	}


func _pass_span(rows: Array, key: String) -> Dictionary:
	var first := -1.0e9
	var last := -1.0e9
	var count := 0
	for r in rows:
		if bool(r["pass"]):
			count += 1
			var v := float(r[key])
			if first < -1.0e8:
				first = v
			last = v
	return {"first": first, "last": last, "count": count, "n": rows.size()}


func _reset_trial(x: float, zone: Dictionary) -> void:
	_release_all()
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.oxygen_phase = "SAFE"
	GameManager.accident_count = 0
	GameManager.pickup_count = 0
	GameManager.showtime_active = false
	GameManager.clear_bro_meter()
	GameManager.current_control = "rabbit"
	GameManager.has_shifted = false
	GameManager.shift_count = 0
	GameManager.combo = 0
	race.showtime_active = false
	race.showtime_t = 0.0
	race.joint_show_t = 0.0
	race.finishing = false
	race.rescue_proto_mode = false
	race.hazard_cooldown = 0.0
	race.accident_flash = 0.0
	race._accident_t = 0.0
	race.turtle_repair = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.rabbit_stun = 0.0
	race.emergency_timer = 0.0
	race.combo = 0
	race.combo_max = 0
	# G20：hit_roles 必须和 hit_groups 一起清。只清 hit_groups 时，B2 起的“角色×组”记账还留着，同组第二例起整组免疫——后面那些重复用例其实在测一段不会撞的赛道。
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.input_buffer_log.clear()
	race.reset_brains()
	race.current_zone = zone
	race.world_end = 1.0e9
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.base_speed = float(zone["base_speed"])
	race.turtle.speed = float(zone["base_speed"])
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race._buf_action = ""
	race._buf_age = 0.0
	race._buf_shift_count = 0
	race._buf_event_msec = -9999
	race._up_was_pressed = false
	race._coyote_t = 0.0
	race._shift_jolt_t = 0.0
	race._camera_pulse_t = 0.0
	race._hitstop_t = 0.0
	race._shake_t = 0.0
	race.land_splash_t = -1.0
	race.action_fx_t = -1.0


func _tick() -> void:
	race._physics_process(STEP)


func _release_all() -> void:
	for a in ["up", "down", "shift", "left", "right"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)


func _print_summary(g: Dictionary, e: Dictionary, ref: Dictionary) -> void:
	var s: Dictionary = e["summary"]
	print("  %s pass=%d/%d rate=%.2f fails=%s" % [String(g["group"]),
		int(s["pass"]), int(s["total"]), float(s["pass_rate"]), str(s["fails"])])
	print("    lead=%s delay=%s release=%s" % [
		str(s["lead_span"]), str(s["delay_span"]), str(s["release_span"])])
	print("    ref pass=%s fail=%s rabbit_clear=%.1f turtle_clear=%.1f land_dx=%.1f land_dy=%.1f" % [
		str(ref["pass"]), String(ref["fail"]), float(ref["rabbit_clearance"]),
		float(ref["turtle_clearance"]), float(ref["land_dx"]), float(ref["land_dy"])])
	var controls: Dictionary = e["controls"]
	for m in controls:
		print("    %s -> %s role=%s" % [m, String(controls[m]["fail"]),
			String(controls[m]["hit_role"])])


func _write() -> void:
	var data := {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "BRO DIVE 只读诊断：固定 1/60 s 手动推进真实 race.gd；引擎内输入代理，不是真人试玩。",
		"constant": {
			"step": STEP, "leads": LEADS, "delays": DELAYS, "releases": RELEASES,
			"ref": [REF_LEAD, REF_DELAY, REF_RELEASE],
			"jump_velocity": -630.0, "dive_depth": Tuning.DIVE_DEPTH,
			"dive_sink": Tuning.DIVE_SINK_SPEED, "dive_rise": Tuning.DIVE_RISE_SPEED,
			"pickup_dx": Tuning.PICKUP_DX,
			"pickup_dy_rising": Tuning.PICKUP_DY_MIN_RISING,
			"pickup_dy": [Tuning.PICKUP_DY_MIN, Tuning.PICKUP_DY_MAX],
		},
		"summary": summary,
	}
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
