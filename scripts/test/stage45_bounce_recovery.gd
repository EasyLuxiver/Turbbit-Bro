extends Node
## PHASE-FIX：乌龟撞上乌龟层障碍后被弹回；同组重复撞击不重复扣分；
## 连续 6 次直接失败（BONK_OUT）。

const LevelData = preload("res://scripts/systems/level_data.gd")

var is_runner := false
var race: Node
var failures: Array[String] = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	GameManager.test_no_best = true
	GameManager.start_race()
	for i in 5:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	var groups := [
		LevelData.build_group({"group": "gate_test", "zone": 1,
			"kind": "DIVE_GATE", "x": 2000.0, "w": 180.0}),
		LevelData.build_group({"group": "beam_test", "zone": 1,
			"kind": "LOW_BEAM", "x": 3000.0, "w": 170.0}),
	]
	race.load_level(groups, [])
	race.turtle.position = Vector2(1950.0, race.surface_ref())
	race.turtle.speed = 220.0
	race._bounce_cd = 0.0
	race._bonk_streak = 0
	race._bonk_level = 0
	var x0: float = race.turtle.position.x
	race._turtle_contact("gate_test", "DIVE_GATE", true)
	_check("bounce_moves_back", race.turtle.position.x <= x0 - 139.0,
		"x %.0f -> %.0f" % [x0, race.turtle.position.x])
	_check("bounce_stops_speed", race.turtle.speed <= 0.01,
		"speed=%.2f" % race.turtle.speed)
	_check("first_hit_counts", GameManager.accident_count == 1,
		"accidents=%d" % GameManager.accident_count)
	_check("bonk_level_one", race._bonk_level == 1,
		"level=%d" % race._bonk_level)
	# 同一组第二次：只弹回，不再扣分/记事故。
	race._bounce_cd = 0.0
	var accidents := GameManager.accident_count
	race._turtle_contact("gate_test", "DIVE_GATE", false)
	_check("second_bounce_no_double", GameManager.accident_count == accidents,
		"accidents=%d" % GameManager.accident_count)
	_check("bonk_level_two", race._bonk_level == 2,
		"level=%d" % race._bonk_level)
	# 兔子层障碍不弹回。
	var bx: float = race.turtle.position.x
	race._bounce_cd = 0.0
	race._turtle_contact("beam_test", "LOW_BEAM", false)
	_check("rabbit_layer_no_bounce", is_equal_approx(race.turtle.position.x, bx),
		"x %.0f -> %.0f" % [bx, race.turtle.position.x])
	# 连续第 6 次 -> BONK_OUT。
	race._bonk_streak = 5
	race._bounce_cd = 0.0
	race._turtle_contact("gate_test", "DIVE_GATE", false)
	_check("sixth_hit_fails", GameManager.failure_reason == "BONK_OUT"
		and GameManager.state == GameManager.GameState.FAILED,
		"reason=%s state=%s" % [GameManager.failure_reason,
			str(GameManager.state)])
	print("STAGE45 BOUNCE: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		print("  ok   " + name + "  " + detail)
	else:
		failures.append(name)
		print("  FAIL " + name + "  " + detail)
