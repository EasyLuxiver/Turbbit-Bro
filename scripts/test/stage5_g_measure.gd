extends Node
## REBUILD-05 G：近身余量测量（只量，不改玩法）。
##
## 目的：给“险过”这类反馈定阈值前，先知道正常解法实际留多少余量。
## 对每一组岩/鲨，按“起跳提前量”逐档扫，记录动作方身体与运动中的障碍
## 判定框之间的最小轴距（px），以及这一档是否撞上。
##
## 输出：docs/reports/longrun/rebuild05-g-margins.json
## 运行：godot --headless --path TURBBIT res://scenes/stage5_g_measure.tscn

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://docs/reports/longrun/rebuild05-g-margins.json"
const STEP := 1.0 / 60.0
const ROCK_LEADS := [20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0, 110.0, 120.0]
const SHARK_SHIFTS := [-60.0, -40.0, -20.0, 0.0, 20.0, 40.0, 60.0]

var is_runner := false
var race: Node = null
var out := {}


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5GMeasureRunner"
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
		push_error("G MEASURE: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()

	out["generated_at"] = Time.get_datetime_string_from_system()
	out["rocks"] = {}
	for name in ["rock1", "rock3", "rock4", "rock7", "rock9", "rock11", "rock12"]:
		out["rocks"][name] = _scan_rock(_group(name))
	out["sharks"] = {}
	for name in ["shark1", "shark3", "shark5", "shark6", "shark8", "shark9"]:
		out["sharks"][name] = _scan_shark(_group(name))

	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()

	for name in out["rocks"]:
		var rows: Array = out["rocks"][name]
		var clean: Array = []
		for r in rows:
			if not bool(r["hit"]):
				clean.append("%.0f→%.0f" % [float(r["lead"]), float(r["min_gap"])])
		print("ROCK %-6s clean %s" % [name, str(clean)])
	for name in out["sharks"]:
		var rows2: Array = out["sharks"][name]
		var clean2: Array = []
		for r in rows2:
			if not bool(r["hit"]):
				clean2.append("%.0f→%.0f" % [float(r["shift"]), float(r["min_gap"])])
		print("SHARK %-6s clean %s" % [name, str(clean2)])
	print("G MEASURE: DONE")
	get_tree().quit(0)


## 岩：按固定提前量起跳，记录兔子与岩框的最小轴距。
func _scan_rock(g: Dictionary) -> Array:
	var rows: Array = []
	if g.is_empty():
		return rows
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	for lead in ROCK_LEADS:
		_reset(start - float(lead), 0.0)
		GameManager.set_control("rabbit")
		Input.action_press("up")
		race._note_up_input()
		race._physics_process(STEP)
		Input.action_release("up")
		var min_gap := 1.0e9
		var hit := false
		var guard := 0
		while guard < 600 and race.turtle.position.x <= end + 220.0:
			race._physics_process(STEP)
			guard += 1
			min_gap = minf(min_gap, _rect_gap(race.rabbit.get_body_rect(),
				race.hazard_rect_live(g, 0)))
			if GameManager.accident_count > 0:
				hit = true
				break
		Input.action_release("up")
		Input.action_release("down")
		rows.append({"lead": lead, "min_gap": snappedf(min_gap, 0.1), "hit": hit})
	return rows


## 鲨：按“跃起提前量偏移”逐档跃，记录乌龟与鲨框的最小轴距。
func _scan_shark(g: Dictionary) -> Array:
	var rows: Array = []
	if g.is_empty():
		return rows
	var start: float = race._group_start(g)
	var end: float = race._group_end(g)
	var v: float = LevelData.zone_at(start)["base_speed"]
	var lead_std: float = 0.93 * v - 35.0
	for shift in SHARK_SHIFTS:
		var lead := lead_std + float(shift)
		_reset(start - lead, 0.0)
		# REBUILD-06 P3：伏击鲨每例都从“深水里等着”重新起跑，靠近即预警。
		race.reset_ambush_states("DOWN")
		GameManager.set_control("turtle")
		Input.action_press("up")
		race._note_up_input()
		race._physics_process(STEP)
		race._physics_process(STEP)
		Input.action_release("up")
		var min_gap := 1.0e9
		var hit := false
		var guard := 0
		while guard < 600 and race.turtle.position.x <= end + 260.0:
			race._physics_process(STEP)
			guard += 1
			min_gap = minf(min_gap, _rect_gap(race.turtle.get_body_rect(),
				race.hazard_rect_live(g, 0)))
			if GameManager.accident_count > 0:
				hit = true
				break
		Input.action_release("up")
		Input.action_release("down")
		rows.append({"shift": shift, "lead": snappedf(lead, 0.1),
			"min_gap": snappedf(min_gap, 0.1), "hit": hit})
	return rows


## 两个轴对齐矩形的最小轴距：只要有一个轴分离就是分离量。
func _rect_gap(a: Rect2, b: Rect2) -> float:
	var dx: float = maxf(maxf(b.position.x - a.end.x, a.position.x - b.end.x), 0.0)
	var dy: float = maxf(maxf(b.position.y - a.end.y, a.position.y - b.end.y), 0.0)
	return maxf(dx, dy)


func _reset(x: float, clock: float) -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.clear_bro_meter()
	GameManager.accident_count = 0
	GameManager.total_score = 0
	GameManager.score_log.clear()
	GameManager.rabbit_casualties = 0
	GameManager.turtle_failures = 0
	GameManager.rescue_success_count = 0
	GameManager.pickup_count = 0
	GameManager.showtime_active = false
	GameManager.current_control = "rabbit"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	race.showtime_active = false
	race.joint_show_t = 0.0
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.accident_flash = 0.0
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
	race.reset_brains()
	race.hazard_clock = clock
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
	race.carry_max_step = 0.0
	race.carry_kind = ""
	race.snack_boost_until_x = -1.0
	race.snack_boost_speed = 0.0
	race.snack_last_eaten = ""
	race.snack_gulp_t = 0.0
	race.snack_gulp_by_player = false
	Input.action_release("down")
	Input.action_release("up")


func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}
