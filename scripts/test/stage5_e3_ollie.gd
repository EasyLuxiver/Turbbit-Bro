extends Node
## TBB-EXPERIENCE-REBUILD-05 E3：BRO OLLIE 蹬踏点的窗口探针。
##
## 问题：全回归里 wall1 的兔子落水（RABBIT_WATER），而 wall2/wall3 通过。
## 怀疑不是关卡而是“蹬踏点刚好压在跃起结束的那一帧上”——量一下窗口到底多宽。
##
## 做法：同一个高墙，固定“起跳点 = 墙前 0.8 × 速度”（BRO OLLIE 的既定摆法），
## 只变“兔子蹬踏点距墙多远”（40…160 px，5 px 粒度），每档跑到落壳或落水。
## 输出：哪些蹬踏点能把兔子送回壳上、对应的落点 x、以及跃起结束的 x。
##
## 输出：docs/reports/longrun/rebuild05-e3-ollie.json
## 运行：godot --headless --path TURBBIT res://scenes/stage5_e3_ollie.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-e3-ollie.json"
const STEP := 1.0 / 60.0
const WALL := "wall1"
const OFFSETS := [40.0, 45.0, 50.0, 55.0, 60.0, 65.0, 70.0, 75.0, 80.0, 85.0,
	90.0, 95.0, 100.0, 110.0, 120.0, 140.0, 160.0]

var is_runner := false
var race: Node = null
var out := {}
var failures: Array = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5E3OllieRunner"
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
		push_error("E3 OLLIE: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()

	var g := _group(WALL)
	if g.is_empty():
		push_error("E3 OLLIE: no wall")
		get_tree().quit(1)
		return
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	var spd := float(LevelData.zone_at(start)["base_speed"])
	var lead := spd * 0.8

	out["wall"] = WALL
	out["wall_start"] = start
	out["wall_end"] = end
	out["speed"] = spd
	out["lead"] = lead
	out["leap_end_x_expected"] = snappedf(start - lead + Tuning.LEAP_TIME * spd, 0.1)
	out["trials"] = []
	for off in OFFSETS:
		out["trials"].append(_trial(g, start, end, spd, lead, float(off)))
	_evaluate()
	_write()
	print("E3 OLLIE: " + ("PASS" if failures.is_empty() else "FAIL"))
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## 一次：墙前 lead 起跳 → 墙前 off 蹬踏 → 等落壳/落水。
func _trial(g: Dictionary, start: float, end: float, spd: float, lead: float,
		off: float) -> Dictionary:
	_reset(start - lead - 40.0)
	var leap_x := -1.0
	var leap_end_x := -1.0
	var kick_x := -1.0
	var kick_y := -1.0
	var landed_x := -1.0
	var guard := 0
	while guard < 600 and race.turtle.position.x < start - lead:
		race._physics_process(STEP)
		guard += 1
	GameManager.current_control = "turtle"
	Input.action_press("up")
	race._note_up_input()
	race._physics_process(STEP)
	Input.action_release("up")
	race._physics_process(STEP)
	leap_x = race.turtle.position.x
	guard = 0
	while guard < 600 and race.turtle.position.x < start - off \
			and GameManager.accident_state == "NONE":
		race._physics_process(STEP)
		guard += 1
	kick_x = race.turtle.position.x
	kick_y = race.rabbit.position.y
	GameManager.current_control = "rabbit"
	Input.action_press("up")
	race._note_up_input()
	race._physics_process(STEP)
	Input.action_release("up")
	race._physics_process(STEP)
	guard = 0
	while guard < 600 and GameManager.accident_state == "NONE":
		race._physics_process(STEP)
		guard += 1
		if not race.turtle.leap_active and leap_end_x < 0.0:
			leap_end_x = race.turtle.position.x
		if race.mount.state == "RIDING" and race.turtle.position.x >= end + 120.0:
			landed_x = race.turtle.position.x
			break
	if landed_x < 0.0:
		landed_x = race.turtle.position.x
	var landed: bool = GameManager.accident_state == "NONE" \
		and String(race.mount.state) == "RIDING"
	return {
		"offset": off,
		"leap_x": snappedf(leap_x, 0.1),
		"kick_x": snappedf(kick_x, 0.1),
		"kick_y": snappedf(kick_y, 0.1),
		"leap_end_x": snappedf(leap_end_x, 0.1),
		"end_x": snappedf(landed_x, 0.1),
		"landed": landed,
		"accident": GameManager.accident_state,
		"mount": String(race.mount.state),
	}


func _evaluate() -> void:
	var landed_offsets := []
	for t in out["trials"]:
		if bool(t["landed"]):
			landed_offsets.append(float(t["offset"]))
	_expect("at least one kick offset lands the rabbit back on the shell (%s)"
		% str(landed_offsets), not landed_offsets.is_empty())
	if not landed_offsets.is_empty():
		var lo := 1.0e9
		var hi := -1.0e9
		for v in landed_offsets:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		_expect("the landing window is at least 30 px wide (%.0f…%.0f px)"
			% [lo, hi], hi - lo >= 30.0)
		out["landed_window_px"] = [lo, hi]


func _expect(what: String, ok: bool) -> void:
	print(("  ok  " if ok else "  FAIL  ") + what)
	if not ok:
		failures.append(what)


func _reset(x: float) -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.clear_bro_meter()
	GameManager.accident_count = 0
	GameManager.showtime_active = false
	GameManager.current_control = "turtle"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.has_shifted = true
	GameManager.pickup_window = false
	race.showtime_active = false
	race.joint_show_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.rabbit_stun = 0.0
	race.turtle_grace = 0.0
	race.rabbit_grace = 0.0
	race.emergency_timer = 0.0
	race.turtle_repair = 0.0
	race.hit_groups.clear()
	race.hit_roles.clear()
	race.passed_groups.clear()
	race.entered_groups.clear()
	race.group_actions.clear()
	race.current_zone = LevelData.zone_at(x)
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.base_speed = float(LevelData.zone_at(x)["base_speed"])
	race.turtle.speed = race.turtle.base_speed
	race.turtle.speed_cap = 1.0e9
	race.turtle.daze_time = 0.0
	race.turtle.drift = 0.0
	race.turtle.dunk_timer = 0.0
	race.rabbit.reset()
	race.mount.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.mark_riding()
	race.rabbit.state = "RIDING"
	race.rescue_last_result = ""
	race.rescue_last_reason = ""
	Input.action_release("up")
	Input.action_release("down")


func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}


func _write() -> void:
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
	print("WROTE " + OUT_PATH)
