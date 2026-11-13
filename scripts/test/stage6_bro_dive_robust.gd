extends Node
## TBB-EXPERIENCE-REFINE-06 P2：BRO DIVE 障碍鲁棒性（3 组代表障碍 × 10 次）。
##
## 标准时机（与 REBUILD05-B3 相同，玩家视角三个动作）：
##   1) 浮木前 160 px 按 ↑ 起跳；
##   2) 0.1 s 后 SHIFT 切乌龟并按住 ↓；
##   3) 越过浮木右缘 40 px 时松开 ↓（乌龟上浮把兔子接回壳上）。
##
## 本探针在 B3 的基础上加三件事：
##   - 每组 10 次 60 Hz 重复，逐例记录余量（不是只记最好的一次）；
##   - 余量按“真正的两侧净空”算：兔子 = 木顶 − 兔身底（逐帧取最小），
##     乌龟 = 龟身顶 − 木底（逐帧取最小），而不是 maxf 取最高点；
##   - 30/120 Hz 对照与三类操作偏差对照（跳太晚 / SHIFT 太晚 / 跳太早），
##     记录失败角色与原因，证明失败来自操作而不是判定。
##
## 输出：docs/reports/longrun/refine06-p2-brodive.json
## 运行：godot --headless --path TURBBIT res://scenes/stage6_bro_dive_robust.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/refine06-p2-brodive.json"
const GROUPS := ["log1", "log3", "log8"] # Z1 / Z2 / Z3 各一
const LEAD := 160.0
const DELAY := 0.1
const RELEASE := 40.0
const REPEATS := 10
const RATE_CASES := [30, 120]
const MIN_CLEAR := 20.0
const RATE_CLEAR_TOL := 10.0

## 操作偏差对照：预期失败或“安全但不是连招”，只记录不预设。
const CONTROLS := [
	{"name": "late_jump", "lead": 40.0, "delay": DELAY},
	{"name": "late_shift", "lead": LEAD, "delay": 0.6},
	{"name": "early_jump", "lead": 400.0, "delay": DELAY},
]
## 三条轴的单轴安全窗口（其余两轴保持标准值），用来量“不是单帧精度”：
## 起跳提前量、SHIFT 延迟、松手位置各扫一遍，找包含标准值的那段连续通过区。
const LEAD_SWEEP := [120.0, 128.0, 136.0, 144.0, 152.0, 160.0, 168.0, 176.0,
	184.0, 192.0, 200.0]
const DELAY_SWEEP := [0.02, 0.04, 0.06, 0.08, 0.10, 0.12, 0.14, 0.16, 0.18, 0.20]
const RELEASE_SWEEP := [0.0, 8.0, 16.0, 24.0, 32.0, 40.0, 48.0, 56.0, 64.0, 80.0, 96.0]

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage6BroDiveRobustRunner"
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
		push_error("P2 BRO DIVE: no race scene")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = false
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["standard"] = {
		"lead_px": LEAD, "shift_delay_s": DELAY,
		"release_px_past_group_end": RELEASE, "repeats": REPEATS,
	}
	out["cases"] = {}
	for name in GROUPS:
		var g := _group(name)
		if g.is_empty():
			failures.append("%s: group not found" % name)
			continue
		out["cases"][name] = _repeat_group(g)
	_evaluate()
	_write()
	print("P2 BRO DIVE: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


func _repeat_group(g: Dictionary) -> Dictionary:
	var entry := {
		"zone": int(LevelData.zone_at(race._group_start(g))["id"]),
		"start_x": snappedf(race._group_start(g), 0.1),
		"end_x": snappedf(race._group_end(g), 0.1),
		"runs": [], "rate_cases": [], "controls": {},
	}
	for i in REPEATS:
		entry["runs"].append(_trial(g, 60.0, LEAD, DELAY, RELEASE))
	for rate in RATE_CASES:
		entry["rate_cases"].append(_trial(g, float(rate), LEAD, DELAY, RELEASE))
	entry["window"] = {"lead": [], "delay": [], "release": []}
	for v in LEAD_SWEEP:
		entry["window"]["lead"].append(_trial(g, 60.0, float(v), DELAY, RELEASE))
	for v in DELAY_SWEEP:
		entry["window"]["delay"].append(_trial(g, 60.0, LEAD, float(v), RELEASE))
	for v in RELEASE_SWEEP:
		entry["window"]["release"].append(_trial(g, 60.0, LEAD, DELAY, float(v)))
	for c in CONTROLS:
		entry["controls"][String(c["name"])] = _trial(g, 60.0,
			float(c["lead"]), float(c["delay"]), RELEASE)
	entry["pass_all"] = true
	for r in entry["runs"]:
		if not bool(r["pass"]) or int(r["accidents"]) > 0:
			entry["pass_all"] = false
	return entry


## 一次完整尝试。rate = 手动推进的 tick 频率（1/rate 秒一步）。
## release = 乌龟越过障碍右缘多少 px 时松开 ↓（1e6 = 一直按住）。
func _trial(g: Dictionary, rate: float, lead: float, delay: float,
		release: float) -> Dictionary:
	var step := 1.0 / rate
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	var zone: Dictionary = LevelData.zone_at(start)
	var key := String(g["group"])
	_reset(start - lead, zone)

	# 1) 起跳
	Input.action_press("up")
	race._note_up_input()
	race._physics_process(step)
	Input.action_release("up")

	# 2) delay 秒后 SHIFT + 按住 ↓
	var waited := step
	while waited < delay:
		race._physics_process(step)
		waited += step
	GameManager.toggle_control()
	Input.action_press("down")

	# 3) 越过障碍右缘 release px 时松手，让乌龟上浮接人
	var t := waited
	var hit := false
	var wet := false
	var dived := true
	var hit_role := ""
	var rabbit_clear := 9999.0
	var turtle_clear := 9999.0
	var guard := 0
	while guard < int(rate * 6.0) and race.turtle.position.x <= end + 220.0:
		if dived and race.turtle.position.x >= end + release:
			Input.action_release("down")
			dived = false
		race._physics_process(step)
		guard += 1
		t += step
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
	Input.action_release("down")

	var riding: bool = race.mount.state == "RIDING"
	var passed: bool = not hit and riding and race.turtle.position.x > end + 150.0
	# wet = 兔子擦到水面但被接住了，这是 BRO DIVE 的正常姿势，不算失败。
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
		"release": release if release < 1.0e5 else -999.0,
		"pass": passed, "state": state,
		"hit_role": hit_role,
		"seconds": snappedf(t, 0.01),
		"end_x": snappedf(race.turtle.position.x, 0.1),
		"rabbit_clear": snappedf(rabbit_clear, 0.1) if rabbit_clear < 9000.0 else -999.0,
		"turtle_clear": snappedf(turtle_clear, 0.1) if turtle_clear < 9000.0 else -999.0,
		"accidents": GameManager.accident_count,
	}


## 撞上那一帧，是兔子还是乌龟的身体压在木上。
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


func _evaluate() -> void:
	var c: Dictionary = out["cases"]
	var control_hits := 0
	var control_safe := 0
	for name in GROUPS:
		if not c.has(name):
			continue
		var e: Dictionary = c[name]
		var runs: Array = e["runs"]
		var pass_n := 0
		var accident_n := 0
		var min_rabbit := 9999.0
		var min_turtle := 9999.0
		var sigs := {}
		for r in runs:
			if bool(r["pass"]):
				pass_n += 1
			accident_n += int(r["accidents"])
			min_rabbit = minf(min_rabbit, float(r["rabbit_clear"]))
			min_turtle = minf(min_turtle, float(r["turtle_clear"]))
			sigs[signature(r)] = true
		_expect("%s: %d/%d standard runs pass, accidents=%d" % [
			name, pass_n, REPEATS, accident_n],
			pass_n == REPEATS and accident_n == 0)
		_expect("%s: rabbit clearance min %.1f px >= %.0f px" % [
			name, min_rabbit, MIN_CLEAR], min_rabbit >= MIN_CLEAR)
		# 乌龟从木底下方过，净空只要求“真的在下方”；具体多薄如实记录。
		_expect("%s: turtle stays below the log (min clearance %.1f px)" % [
			name, min_turtle], min_turtle > 0.0)
		# 三条轴的单轴安全窗口：宽度够不够“人手级”，不是单帧精度。
		var win: Dictionary = e["window"]
		var sp_lead := _pass_span(win["lead"], "lead", LEAD)
		var sp_delay := _pass_span(win["delay"], "delay", DELAY)
		var sp_release := _pass_span(win["release"], "release", RELEASE)
		print("P2 window %s: lead %.0f..%.0f (%.0f px), delay %.2f..%.2f (%.2f s), release %.0f..%.0f (%.0f px)" % [
			name, float(sp_lead["lo"]), float(sp_lead["hi"]), float(sp_lead["width"]),
			float(sp_delay["lo"]), float(sp_delay["hi"]), float(sp_delay["width"]),
			float(sp_release["lo"]), float(sp_release["hi"]), float(sp_release["width"])])
		_expect("%s: lead window >= 24 px around 160 (got %.0f..%.0f)" % [
			name, float(sp_lead["lo"]), float(sp_lead["hi"])],
			float(sp_lead["width"]) >= 24.0)
		_expect("%s: delay window >= 0.06 s around 0.10 (got %.2f..%.2f)" % [
			name, float(sp_delay["lo"]), float(sp_delay["hi"])],
			float(sp_delay["width"]) >= 0.06)
		_expect("%s: release window >= 24 px around 40 (got %.0f..%.0f)" % [
			name, float(sp_release["lo"]), float(sp_release["hi"])],
			float(sp_release["width"]) >= 24.0)
		_expect("%s: %d runs identical (%s)" % [name, REPEATS, str(sigs.keys())],
			sigs.size() == 1)
		# 30/120 Hz：结论不翻转，余量与 60 Hz 的差可解释。
		var base_rabbit := float(runs[0]["rabbit_clear"])
		for r in e["rate_cases"]:
			var dr: float = absf(float(r["rabbit_clear"]) - base_rabbit)
			_expect("%s: %.0fHz state=%s rabbit_clear=%.1f (delta %.1f px)" % [
				name, float(r["rate"]), String(r["state"]),
				float(r["rabbit_clear"]), dr],
				bool(r["pass"]) and dr <= RATE_CLEAR_TOL)
		# 操作偏差对照：记录它是失败还是“安全但不是连招”。
		var ctl: Dictionary = e["controls"]
		for cname in ctl:
			var r: Dictionary = ctl[cname]
			if bool(r["pass"]):
				control_safe += 1
			else:
				control_hits += 1
			print("P2 control %s/%s: state=%s hit_role=%s rabbit=%.1f turtle=%.1f" % [
				name, String(cname), String(r["state"]), String(r["hit_role"]),
				float(r["rabbit_clear"]), float(r["turtle_clear"])])
	# 至少两类偏差必须真的失败，且失败角色可解释。
	_expect("at least 2 control deviations fail (%d failed, %d safely passed)" % [
		control_hits, control_safe], control_hits >= 2)


## 在一条扫描里找“包含参考值的那段连续通过区”。
func _pass_span(trials: Array, axis: String, ref: float) -> Dictionary:
	var idx := -1
	for i in range(trials.size()):
		if absf(float(trials[i][axis]) - ref) < 0.001:
			idx = i
			break
	if idx < 0 or not bool(trials[idx]["pass"]):
		return {"lo": ref, "hi": ref, "width": 0.0}
	var lo := idx
	var hi := idx
	while lo > 0 and bool(trials[lo - 1]["pass"]):
		lo -= 1
	while hi < trials.size() - 1 and bool(trials[hi + 1]["pass"]):
		hi += 1
	return {
		"lo": float(trials[lo][axis]), "hi": float(trials[hi][axis]),
		"width": float(trials[hi][axis]) - float(trials[lo][axis]),
	}


func signature(r: Dictionary) -> String:
	return "%s|%d|%.1f|%.1f" % [String(r["state"]), int(r["accidents"]),
		float(r["rabbit_clear"]), float(r["turtle_clear"])]


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _write() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f == null:
		push_error("P2 BRO DIVE: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
