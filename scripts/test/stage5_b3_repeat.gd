extends Node
## TBB-EXPERIENCE-REBUILD-05 B3：BRO DIVE 三组代表障碍的标准时机重复验证。
##
## 标准时机（玩家视角只有三个动作）：
##   1) 浮木前 160 px 按 ↑ 起跳；
##   2) 0.1 s 后 SHIFT 切乌龟并按住 ↓；
##   3) 越过浮木右缘 40 px 时松开 ↓（乌龟上浮把兔子接回壳上）。
## 每组跑 5 次 60 Hz + 30/120 Hz 各 1 次，确认窗口不依赖单帧/毫秒。
## 另跑一次“一直按住不放”作对照：它也能落在壳上，但会擦水记一次事故——
## 说明“什么时候松手”是这条连招的真实技巧点，不是多余操作。
##
## 输出：docs/reports/longrun/rebuild05-b3-repeat.json
## 运行：godot --headless --path TURBBIT res://scenes/stage5_b3_repeat.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-b3-repeat.json"
const GROUPS := ["log1", "log3", "log8"] # Z1 / Z2 / Z3 各一
const LEAD := 160.0
const DELAY := 0.1
const RELEASE := 40.0
const REPEATS := 5
const RATES := [60, 60, 60, 60, 60, 30, 120]

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5B3RepeatRunner"
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
		push_error("B3 REPEAT: no race scene")
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
		"release_px_past_group_end": RELEASE,
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
	print("B3 REPEAT: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


func _repeat_group(g: Dictionary) -> Dictionary:
	var entry := {"runs": []}
	for rate in RATES:
		entry["runs"].append(_trial(g, float(rate), RELEASE))
	entry["hold_to_end"] = _trial(g, 60.0, 1.0e6)
	entry["pass_all"] = true
	var states := {}
	for r in entry["runs"]:
		if not bool(r["pass"]) or int(r["accidents"]) > 0:
			entry["pass_all"] = false
		states[String(r["state"])] = int(states.get(String(r["state"]), 0)) + 1
	entry["state_counts"] = states
	return entry


## 一次标准时机。rate = 手动推进的 tick 频率（1/rate 秒一步）。
## release = 乌龟越过障碍右缘多少 px 时松开 ↓（1e6 = 一直按住）。
func _trial(g: Dictionary, rate: float, release: float) -> Dictionary:
	var step := 1.0 / rate
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	var zone: Dictionary = LevelData.zone_at(start)
	var key := String(g["group"])
	_reset(start - LEAD, zone)

	# 1) 起跳
	Input.action_press("up")
	race._note_up_input()
	race._physics_process(step)
	Input.action_release("up")

	# 2) 0.1 s 后 SHIFT + 按住 ↓
	var waited := step
	while waited < DELAY:
		race._physics_process(step)
		waited += step
	GameManager.toggle_control()
	Input.action_press("down")

	# 3) 越过障碍右缘 release px 时松手，让乌龟上浮接人
	var t := waited
	var hit := false
	var wet := false
	var dived := true
	var rabbit_clear := -999.0
	var turtle_clear := -999.0
	var guard := 0
	while guard < int(rate * 6.0) and race.turtle.position.x <= end + 220.0:
		if dived and race.turtle.position.x >= end + release:
			Input.action_release("down")
			dived = false
		race._physics_process(step)
		guard += 1
		t += step
		if race.hit_groups.has(key):
			hit = true
			break
		if GameManager.accident_state == "RABBIT_WATER":
			wet = true
		for r in g["rects"]:
			var rect: Rect2 = r
			var rr: Rect2 = race.rabbit.get_body_rect()
			var tr: Rect2 = race.turtle.get_body_rect()
			if rr.position.x <= rect.end.x and rr.end.x >= rect.position.x:
				rabbit_clear = maxf(rabbit_clear, rect.position.y - rr.end.y)
			if tr.position.x <= rect.end.x and tr.end.x >= rect.position.x:
				turtle_clear = maxf(turtle_clear, tr.position.y - rect.end.y)
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
		"rate": rate, "release": release, "pass": passed, "state": state,
		"seconds": snappedf(t, 0.01),
		"end_x": snappedf(race.turtle.position.x, 0.1),
		"rabbit_clear": snappedf(rabbit_clear, 0.1),
		"turtle_clear": snappedf(turtle_clear, 0.1),
		"accidents": GameManager.accident_count,
	}


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
	for name in GROUPS:
		if not c.has(name):
			continue
		var e: Dictionary = c[name]
		_expect("%s: all %d standard runs pass without an accident (%s)" % [
			name, RATES.size(), str(e["state_counts"])], bool(e["pass_all"]))
		# 60 Hz 五连跑必须完全一致（确定性），不是碰运气。
		var first := ""
		var same := true
		for i in REPEATS:
			var r: Dictionary = e["runs"][i]
			var sig := "%s|%d|%.1f|%.1f" % [String(r["state"]), int(r["accidents"]),
				float(r["rabbit_clear"]), float(r["turtle_clear"])]
			if first == "":
				first = sig
			elif sig != first:
				same = false
		_expect("%s: 5x60Hz identical (%s)" % [name, first], same)
		# 30/120 Hz 不能翻转结论。
		var odd := []
		for i in range(REPEATS, RATES.size()):
			var r: Dictionary = e["runs"][i]
			odd.append("%.0fHz=%s" % [float(r["rate"]), String(r["state"])])
		_expect("%s: rate change keeps the result (%s)" % [name, str(odd)],
			not str(odd).contains("hit"))
		# 对照：按住不放也能落回壳上，但会擦水记一次事故 —— 这是设计事实，
		# 不是失败；只确认它没有变成“掉水里接不回来”。
		var hold: Dictionary = e["hold_to_end"]
		_expect("%s: hold-to-end still lands on shell (%s)" % [
			name, String(hold["state"])], bool(hold["pass"]))


func _expect(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)


func _write() -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f == null:
		push_error("B3 REPEAT: cannot write " + OUT_PATH)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
