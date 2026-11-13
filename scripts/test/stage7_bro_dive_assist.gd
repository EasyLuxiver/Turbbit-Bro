extends Node
## TBB-CORE-FEEL-07 P0-A：BRO DIVE 辅助下潜的实测。
##
## 本轮改的规则（相对 REFINE-06 P2）：
##   旧：↑ 起跳 → 0.1 s 后 SHIFT + 按住 ↓ → 越过浮木右缘 40 px 手动松手 → 上浮接人。
##   新：↑ 起跳 → SHIFT（时间不要求精确）→ 自动下潜 → 越过浮木后自动上浮接人。
## 玩家输入仍然只有 ↑ 和 SHIFT；不按 ↓、不手动松手也必须完成。
##
## 本探针证明四件事：
##   1) 标准输入（↑ → 0.1 s → SHIFT，之后什么都不按）3 组 × 10 次全过、0 事故；
##   2) SHIFT 延迟 / 起跳提前量的通过区宽度达到人手级（不是单帧精度）；
##   3) 不按、只跳、只 SHIFT、SHIFT 太晚 都必须失败——不是靠关判定过关；
##   4) 碰撞体尺寸、浮木矩形、乌龟下潜深度都没被缩小/跳过。
##
## 输出：docs/reports/longrun/core-feel-07-brodive-assist.json
## 运行：godot --headless --path TURBBIT res://scenes/stage7_bro_dive_assist.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/core-feel-07-brodive-assist.json"
const GROUPS := ["log1", "log3", "log8"]
## 起跳时机按“秒”而不是像素给：三区速度不同（220/240/260），同一个 160 px
## 在 Z3 只等于 0.62 s。0.73 s 是旧标准在 Z1 的提前量，折算到各区 160/175/190 px。
const LEAD_S := 0.73
const DELAY := 0.10
const REPEATS := 10
const RATE_CASES := [30, 120]
## 早跳 + 晚 SHIFT 的人手场景：提前 0.95 s 起跳、SHIFT 延迟 0.5 s。
## 任务要求“SHIFT 不必卡点”，这一组就是它的直接证据。
const LATE_LEAD_S := 0.95
const LATE_DELAY := 0.50

const DELAY_SWEEP := [0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50,
	0.55, 0.60, 0.70, 0.80]
const LEAD_SWEEP := [80.0, 100.0, 120.0, 140.0, 160.0, 180.0, 200.0, 220.0,
	240.0, 260.0, 280.0, 320.0, 360.0, 400.0]

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage7BroDiveAssistRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "zh"
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("CORE-FEEL-07 P0-A: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["standard"] = {"lead_s": LEAD_S, "shift_delay_s": DELAY, "repeats": REPEATS,
		"player_inputs": ["up", "shift"], "down_pressed": false, "manual_release": false}
	out["geometry"] = _geometry()
	out["cases"] = {}
	for name in GROUPS:
		var g := _group(name)
		if g.is_empty():
			failures.append("%s: group not found" % name)
			continue
		out["cases"][name] = _repeat_group(g)
	out["controls"] = _controls()
	out["non_log"] = _non_log_control()
	_evaluate()
	_write()
	print("CORE-FEEL-07 P0-A: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _geometry() -> Dictionary:
	var g := _group("log1")
	var rect: Rect2 = g["rects"][0]
	return {
		"log_rect": [snappedf(rect.position.x, 0.1), snappedf(rect.position.y, 0.1),
			snappedf(rect.size.x, 0.1), snappedf(rect.size.y, 0.1)],
		"turtle_body": [snappedf(race.turtle.get_body_rect().size.x, 0.1),
			snappedf(race.turtle.get_body_rect().size.y, 0.1)],
		"rabbit_body": [snappedf(race.rabbit.get_body_rect().size.x, 0.1),
			snappedf(race.rabbit.get_body_rect().size.y, 0.1)],
		"neutral_depth": Tuning.NEUTRAL_DEPTH,
		"dive_depth": Tuning.DIVE_DEPTH,
		"assist_arm_px": race.DIVE_ASSIST_ARM_PX,
		"assist_pass_px": race.DIVE_ASSIST_PASS_PX,
		"assist_surface_time": race.DIVE_ASSIST_SURFACE_TIME,
	}


func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


func _repeat_group(g: Dictionary) -> Dictionary:
	var zone_speed := float(LevelData.zone_at(race._group_start(g))["base_speed"])
	var lead_px := LEAD_S * zone_speed
	var late_px := LATE_LEAD_S * zone_speed
	var entry := {
		"zone": int(LevelData.zone_at(race._group_start(g))["id"]),
		"zone_speed": zone_speed,
		"standard_lead_px": snappedf(lead_px, 0.1),
		"late_lead_px": snappedf(late_px, 0.1),
		"start_x": snappedf(race._group_start(g), 0.1),
		"end_x": snappedf(race._group_end(g), 0.1),
		"runs": [], "rate_cases": [], "early_late": [],
		"window": {"lead": [], "delay": []},
	}
	for i in REPEATS:
		entry["runs"].append(_trial(g, 60.0, lead_px, DELAY, true))
	for rate in RATE_CASES:
		entry["rate_cases"].append(_trial(g, float(rate), lead_px, DELAY, true))
	for i in REPEATS:
		entry["early_late"].append(_trial(g, 60.0, late_px, LATE_DELAY, true))
	for v in LEAD_SWEEP:
		entry["window"]["lead"].append(_trial(g, 60.0, float(v), DELAY, true))
	for v in DELAY_SWEEP:
		entry["window"]["delay"].append(_trial(g, 60.0, lead_px, float(v), true))
	var pass_all := true
	for r in entry["runs"]:
		if not bool(r["pass"]) or int(r["accidents"]) > 0:
			pass_all = false
	entry["pass_all"] = pass_all
	return entry


## 一次完整尝试 = 一个真人只按两个键。
## shift=false 用于对照（不换人就永远不下潜）。
## 全程不按 ↓、不松手动作；release 轴不再存在。
func _trial(g: Dictionary, rate: float, lead: float, delay: float,
		do_shift: bool) -> Dictionary:
	var step := 1.0 / rate
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	var zone: Dictionary = LevelData.zone_at(start)
	var key := String(g["group"])
	_reset(start - lead, zone)

	# 1) ↑ 起跳（唯一的跳跃输入）
	Input.action_press("up")
	race._note_up_input()
	race._physics_process(step)
	Input.action_release("up")
	var armed: String = race.dive_assist_state()

	# 2) delay 秒后 SHIFT。之后什么都不按。
	var waited := step
	while waited < delay:
		race._physics_process(step)
		waited += step
	var shifted := false
	var active := ""
	if do_shift:
		GameManager.toggle_control()
		shifted = true
		active = race.dive_assist_state()

	var t := waited
	var hit := false
	var wet := false
	var hit_role := ""
	var rabbit_clear := 9999.0
	var turtle_clear := 9999.0
	var surfacing_seen := false
	var min_depth := 0.0
	var guard := 0
	while guard < int(rate * 8.0) and race.turtle.position.x <= end + 260.0:
		race._physics_process(step)
		guard += 1
		t += step
		if race.dive_assist_state() == "SURFACING":
			surfacing_seen = true
		if race.hit_groups.has(key) and not hit:
			hit = true
			hit_role = _overlap_role(g)
		if GameManager.accident_state == "RABBIT_WATER":
			wet = true
		# 逐帧净空：只统计 x 真正压在木上的帧。
		var rr: Rect2 = race.rabbit.get_body_rect()
		var tr: Rect2 = race.turtle.get_body_rect()
		for r in g["rects"]:
			var rect: Rect2 = r
			if rr.position.x <= rect.end.x and rr.end.x >= rect.position.x:
				rabbit_clear = minf(rabbit_clear, rect.position.y - rr.end.y)
			if tr.position.x <= rect.end.x and tr.end.x >= rect.position.x:
				turtle_clear = minf(turtle_clear, tr.position.y - rect.end.y)
				min_depth = maxf(min_depth, tr.position.y - rect.position.y)

	var riding: bool = race.mount.state == "RIDING"
	# 事故数也算失败：落水后被救援接回不算“通关”，否则会掩盖一次真的失败。
	var passed: bool = not hit and riding and GameManager.accident_count == 0 \
		and race.turtle.position.x > end + 200.0
	var state := "pass"
	if hit:
		state = "hit"
	elif not riding:
		state = "not_caught"
	elif wet:
		state = "pass_wet"
	elif not passed:
		state = "short"
	return {
		"rate": rate, "lead": lead, "delay": snappedf(delay, 0.01),
		"shift": do_shift,
		"assist_armed": armed, "assist_active": active,
		"assist_surfaced": surfacing_seen, "assist_end": race.dive_assist_state(),
		"pass": passed, "state": state, "hit_role": hit_role,
		"seconds": snappedf(t, 0.01),
		"end_x": snappedf(race.turtle.position.x, 0.1),
		"rabbit_clear": snappedf(rabbit_clear, 0.1) if rabbit_clear < 9000.0 else -999.0,
		"turtle_clear": snappedf(turtle_clear, 0.1) if turtle_clear < 9000.0 else -999.0,
		"layers_below_log": snappedf(min_depth, 0.1),
		"accidents": GameManager.accident_count,
		"score": GameManager.total_score,
	}


## 四类失败对照：所有不用两个键的组合都必须撞（或掉进水里），不能“自动完成”。
func _controls() -> Dictionary:
	var g := _group("log1")
	var end: float = race._group_end(g)
	var start: float = race._group_start(g)
	var zone: Dictionary = LevelData.zone_at(start)
	var lead_px := LEAD_S * float(zone["base_speed"])
	var res := {}

	# A) 完全不动：乌龟巡航水深直接撞浮木。
	_reset(start - lead_px, zone)
	var r := _passive_run(end, 1.0 / 60.0, "none")
	res["no_input"] = r

	# B) 只跳不 SHIFT：兔子起跳，乌龟还在水面 → 撞木。
	_reset(start - lead_px, zone)
	Input.action_press("up")
	race._note_up_input()
	race._physics_process(1.0 / 60.0)
	Input.action_release("up")
	var armed: String = race.dive_assist_state()
	r = _passive_run(end, 1.0 / 60.0, "jump_only")
	r["assist_armed"] = armed
	res["jump_only"] = r

	# C) 只 SHIFT 不跳：切到乌龟也拿不到下潜（没有起跳就不上膛）。
	_reset(start - lead_px, zone)
	GameManager.toggle_control()
	var armed_c: String = race.dive_assist_state()
	race._physics_process(1.0 / 60.0)
	r = _passive_run(end, 1.0 / 60.0, "shift_only")
	r["assist_armed"] = armed_c
	res["shift_only"] = r

	# D) SHIFT 太晚（1.0 s）：几何上已经来不及下潜。
	res["late_shift"] = _trial(g, 60.0, lead_px, 1.0, true)

	# E) 先 SHIFT 再按 ↑：这是乌龟跃起，不是兔子起跳，必须撞。
	_reset(start - lead_px, zone)
	GameManager.toggle_control()
	race._physics_process(1.0 / 60.0)
	Input.action_press("up")
	race._note_up_input()
	race._physics_process(1.0 / 60.0)
	Input.action_release("up")
	r = _passive_run(end, 1.0 / 60.0, "leap_into_log")
	r["assist_armed"] = race.dive_assist_state()
	res["shift_then_jump"] = r
	return res


## 只推进、不输入：给对照组用。返回与 _trial 同形的结果。
func _passive_run(end: float, step: float, tag: String) -> Dictionary:
	var hit := false
	var hit_role := ""
	var t := 0.0
	var guard := 0
	while guard < int((1.0 / step) * 6.0) and race.turtle.position.x <= end + 220.0:
		race._physics_process(step)
		guard += 1
		t += step
		if race.hit_groups.has("log1") and not hit:
			hit = true
			hit_role = _overlap_role(_group("log1"))
	var riding: bool = race.mount.state == "RIDING"
	var passed: bool = not hit and riding and GameManager.accident_count == 0 \
		and race.turtle.position.x > end + 200.0
	return {
		"tag": tag, "pass": passed, "state": "pass" if passed else "hit",
		"hit_role": hit_role, "seconds": snappedf(t, 0.01),
		"end_x": snappedf(race.turtle.position.x, 0.1),
		"accidents": GameManager.accident_count,
		"score": GameManager.total_score,
		"assist_end": race.dive_assist_state(),
	}


## 非浮木障碍不应上膛：在低梁前起跳，dive_assist 必须保持 OFF。
func _non_log_control() -> Dictionary:
	var g := _group("beam1")
	if g.is_empty():
		return {"error": "beam1 not found"}
	var start: float = race._group_start(g)
	var zone: Dictionary = LevelData.zone_at(start)
	_reset(start - LEAD_S * float(zone["base_speed"]), zone)
	Input.action_press("up")
	race._note_up_input()
	race._physics_process(1.0 / 60.0)
	Input.action_release("up")
	return {"group": "beam1", "kind": String(g["kind"]),
		"assist_after_jump": race.dive_assist_state()}


func _overlap_role(g: Dictionary) -> String:
	var rr: Rect2 = race.rabbit.get_body_rect()
	var tr: Rect2 = race.turtle.get_body_rect()
	for r in g["rects"]:
		var rect: Rect2 = r
		if rr.position.x <= rect.end.x and rr.end.x >= rect.position.x \
				and rr.position.y <= rect.end.y and rr.end.y >= rect.position.y:
			return "rabbit"
		if tr.position.x <= rect.end.x and tr.end.x >= rect.position.x \
				and tr.position.y <= rect.end.y and tr.end.y >= rect.position.y:
			return "turtle"
	return "unknown"


func _reset(x: float, zone: Dictionary) -> void:
	Input.action_release("up")
	Input.action_release("down")
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.oxygen_phase = "SAFE"
	GameManager.accident_count = 0
	GameManager.pickup_count = 0
	GameManager.total_score = 0
	GameManager.score_log.clear()
	GameManager.showtime_active = false
	GameManager.clear_bro_meter()
	GameManager.current_control = "rabbit"
	GameManager.has_shifted = false
	GameManager.combo = 0
	race.showtime_active = false
	race.showtime_t = 0.0
	race.joint_show_t = 0.0
	race.finishing = false
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
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.input_buffer_log.clear()
	race._clear_dive_assist()
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
	race.rabbit.state = "RIDING"
	race._buf_action = ""
	race._buf_age = 0.0


func _evaluate() -> void:
	_geometry_checks()
	var c: Dictionary = out["cases"]
	for name in GROUPS:
		if not c.has(name):
			continue
		var e: Dictionary = c[name]
		var runs: Array = e["runs"]
		var pass_n := 0
		var accident_n := 0
		var min_rabbit := 9999.0
		var min_turtle := 9999.0
		var surfaced := 0
		for r in runs:
			if bool(r["pass"]):
				pass_n += 1
			accident_n += int(r["accidents"])
			min_rabbit = minf(min_rabbit, float(r["rabbit_clear"]))
			min_turtle = minf(min_turtle, float(r["turtle_clear"]))
			if bool(r["assist_surfaced"]):
				surfaced += 1
		_expect("%s: %d/%d two-key runs pass, accidents=%d" % [name, pass_n, REPEATS, accident_n],
			pass_n == REPEATS and accident_n == 0)
		_expect("%s: rabbit clearance min %.1f px > 0" % [name, min_rabbit], min_rabbit > 0.0)
		_expect("%s: turtle stays under the log (min clearance %.1f px)" % [name, min_turtle],
			min_turtle > 0.0)
		_expect("%s: auto-surface observed in %d/%d runs" % [name, surfaced, REPEATS],
			surfaced == REPEATS)
		var win: Dictionary = e["window"]
		var std_lead := float(e["standard_lead_px"])
		var sp_lead := _span_around(win["lead"], "lead", std_lead)
		var sp_delay := _pass_span(win["delay"], "delay", DELAY)
		print("P0-A window %s: lead %.0f..%.0f (%.0f px, standard %.0f), shift delay %.2f..%.2f (%.2f s)" % [
			name, float(sp_lead["lo"]), float(sp_lead["hi"]), float(sp_lead["width"]),
			std_lead, float(sp_delay["lo"]), float(sp_delay["hi"]), float(sp_delay["width"])])
		_expect("%s: jump lead window >= 40 px and contains the standard %.0f px (got %.0f..%.0f)" % [
			name, std_lead, float(sp_lead["lo"]), float(sp_lead["hi"])],
			float(sp_lead["width"]) >= 40.0 and std_lead >= float(sp_lead["lo"])
			and std_lead <= float(sp_lead["hi"]))
		_expect("%s: shift window >= 0.25 s (got %.2f s)" % [name, float(sp_delay["width"])],
			float(sp_delay["width"]) >= 0.25)
		# 早跳 0.95 s + SHIFT 延迟 0.5 s：人手不卡点的直接证据。
		var late_n := 0
		var late_acc := 0
		for r in e["early_late"]:
			if bool(r["pass"]):
				late_n += 1
			late_acc += int(r["accidents"])
		_expect("%s: jump %.0f px early + SHIFT after 0.5 s: %d/%d pass, accidents=%d" % [
			name, float(e["late_lead_px"]), late_n, REPEATS, late_acc],
			late_n == REPEATS and late_acc == 0)
		# 30/120 Hz 对照
		for r in e["rate_cases"]:
			_expect("%s @%d Hz: pass, 0 accidents" % [name, int(r["rate"])],
				bool(r["pass"]) and int(r["accidents"]) == 0)
	# 对照组：所有不完整的输入都必须失败。
	var ctrl: Dictionary = out["controls"]
	for tag in ["no_input", "jump_only", "shift_only", "late_shift", "shift_then_jump"]:
		var r: Dictionary = ctrl[tag]
		_expect("control %s must fail (got %s, hit=%s)" % [tag, String(r["state"]),
			String(r["hit_role"])], not bool(r["pass"]))
	_expect("control late_shift must not hit the rabbit (turtle-only failure)",
		String(ctrl["late_shift"]["hit_role"]) != "rabbit")
	var nl: Dictionary = out["non_log"]
	_expect("beam1 jump does not arm dive assist (got %s)" %
		String(nl.get("assist_after_jump", "?")), nl.get("assist_after_jump", "?") == "OFF")


func _geometry_checks() -> void:
	var geo: Dictionary = out["geometry"]
	_expect("log rect unchanged (32 x 218)", is_equal_approx(float(geo["log_rect"][2]), 32.0)
		and is_equal_approx(float(geo["log_rect"][3]), 218.0))
	_expect("turtle body not shrunk (%.0f x %.0f)" % [float(geo["turtle_body"][0]),
		float(geo["turtle_body"][1])], float(geo["turtle_body"][0]) >= 90.0
		and float(geo["turtle_body"][1]) >= 50.0)
	_expect("rabbit body not shrunk (%.0f x %.0f)" % [float(geo["rabbit_body"][0]),
		float(geo["rabbit_body"][1])], float(geo["rabbit_body"][0]) > 0.0
		and float(geo["rabbit_body"][1]) > 0.0)


## 标准值不一定正好落在扫描点上（按秒折算的 175 px 等）：先取最近的扫描点，
## 再按那个点求连续通过区。返回的 lo..hi 仍然覆盖标准值本身才算通过。
func _span_around(rows: Array, axis: String, standard: float) -> Dictionary:
	var nearest := standard
	var best_d := 1.0e9
	for r in rows:
		var v := float(r[axis])
		if absf(v - standard) < best_d:
			best_d = absf(v - standard)
			nearest = v
	return _pass_span(rows, axis, nearest)


## 连续通过区的宽度：从标准值出发向两侧找，遇到第一个失败就停。
func _pass_span(rows: Array, axis: String, standard: float) -> Dictionary:
	var by_value := {}
	for r in rows:
		by_value[float(r[axis])] = bool(r["pass"]) and int(r["accidents"]) == 0
	var vals := by_value.keys()
	vals.sort()
	var idx := -1
	for i in vals.size():
		if is_equal_approx(float(vals[i]), standard):
			idx = i
			break
	if idx < 0 or not bool(by_value[standard]):
		return {"lo": standard, "hi": standard, "width": 0.0}
	var lo := standard
	var hi := standard
	# 从标准值向上/向下各走一步，相邻通过才扩展。
	for i in range(idx, vals.size()):
		if bool(by_value[vals[i]]):
			hi = float(vals[i])
		else:
			break
	for i in range(idx, -1, -1):
		if bool(by_value[vals[i]]):
			lo = float(vals[i])
		else:
			break
	return {"lo": lo, "hi": hi, "width": hi - lo}


func _expect(msg: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + msg)
	if not ok:
		failures.append(msg)


func _write() -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		failures.append("cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
