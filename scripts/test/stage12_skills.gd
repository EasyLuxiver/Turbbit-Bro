extends Node
## FEEL-12 补充 B：TUBO CARROT GUARD / BITT BRO CATCH 矩阵。
## 输出：docs/reports/longrun/core-feel-12-skills.json

const OUT := "res://docs/reports/longrun/core-feel-12-skills.json"
const LevelData = preload("res://scripts/systems/level_data.gd")
const FPS := 60.0

var is_runner := false
var race: Node = null
var checks: Array = []
var rows: Array = []


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
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	GameManager.test_no_best = true
	_case_guard_precise()
	_case_guard_normal()
	_case_guard_not_universal()
	_case_guard_safe_switch()
	_case_catch_forward()
	_case_catch_backward()
	_case_catch_safe()
	_case_catch_success()
	_write()
	_finish()


func _reset() -> void:
	GameManager._reset_run()
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.current_control = "rabbit"
	GameManager.shift_lock_t = 0.0
	GameManager.accident_state = "NONE"
	race.test_disable_hazards = false
	race.test_no_lessons = true
	race.world_end = 1.0e9
	race.load_level([], [])
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race._guard_t = 0.0
	race._guard_cd = 0.0
	race._guard_age = 0.0
	race._guard_blocked.clear()
	race._catch_active = false
	race._catch_t = 0.0
	Input.action_release("pop")
	Input.action_release("up")
	Input.action_release("down")


func _press_space() -> void:
	# 先让物理帧看到一次“松开”，否则 _space_was_pressed 仍是上一例的 true，按键沿被吃掉。
	Input.action_release("pop")
	race._physics_process(1.0 / FPS)
	Input.action_press("pop")
	race._physics_process(1.0 / FPS)
	Input.action_release("pop")


func _load_beam() -> void:
	var g := LevelData.build_group({"group": "skill_beam", "zone": 1,
		"kind": "LOW_BEAM", "x": 1000.0, "w": 170.0})
	race.load_level([g], [])
	race.turtle.reset(Vector2(1000.0, race.surface_ref()))
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()


func _case_guard_precise() -> void:
	_reset()
	_load_beam()
	var s0: int = GameManager.total_score
	var a0: int = GameManager.accident_count
	_press_space()
	_check("1_guard_removed", float(race._guard_t) <= 0.0
		and not race._guard_can_block("LOW_BEAM") and GameManager.total_score == s0,
		"guard=%.2f can_block=%s score +%d" % [
			float(race._guard_t), str(race._guard_can_block("LOW_BEAM")),
			GameManager.total_score - s0])
	rows.append({"case": "guard_removed"})


func _case_guard_normal() -> void:
	_reset()
	_load_beam()
	_press_space()
	_check("2_guard_no_window", float(race._guard_t) <= 0.0,
		"guard=%.2f" % float(race._guard_t))
	rows.append({"case": "guard_no_window"})


func _case_guard_not_universal() -> void:
	_reset()
	_press_space()
	_check("3_guard_no_reward",
		not race._guard_can_block("SURFACE_ROCK")
			and not race._guard_can_block("FLOATING_LOG")
			and not race._guard_can_block("SHARK"),
		"guard cannot block any class")
	rows.append({"case": "guard_no_reward"})


func _case_guard_safe_switch() -> void:
	_reset()
	_press_space()
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	race._physics_process(1.0 / FPS)
	_check("4_no_guard_shift", GameManager.current_control == "turtle"
		and float(race._guard_t) <= 0.0,
		"guard=%.2f control=%s" % [float(race._guard_t),
			GameManager.current_control])
	rows.append({"case": "no_guard_shift"})


func _make_rescue(offset_x: float) -> void:
	_reset()
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race.rabbit.position = Vector2(900.0 + offset_x, race.surface_ref() - 28.0)
	race.mount.mark_rescuing(3.0)
	race.rabbit.state = "FALLING_WATER"
	GameManager.accident_state = "RABBIT_WATER"
	GameManager.current_control = "turtle"
	race._catch_active = false


func _case_catch_forward() -> void:
	_make_rescue(280.0)
	_press_space()
	_check("5_catch_forward_starts", bool(race._catch_active),
		"active=%s" % str(race._catch_active))
	var x0: float = race.turtle.position.x
	for i in 20:
		race._physics_process(1.0 / FPS)
	_check("5b_catch_moves_forward", race.turtle.position.x > x0 + 40.0,
		"turtle x %.0f -> %.0f" % [x0, race.turtle.position.x])
	rows.append({"case": "catch_forward", "dx": race.turtle.position.x - x0})


func _case_catch_backward() -> void:
	_make_rescue(-280.0)
	_press_space()
	var x0: float = race.turtle.position.x
	var min_x := x0
	for i in 30:
		race._physics_process(1.0 / FPS)
		min_x = minf(min_x, race.turtle.position.x)
	_check("6_catch_moves_backward", min_x < x0 - 40.0,
		"turtle min x %.0f -> %.0f (final %.0f)" % [x0, min_x,
			race.turtle.position.x])
	rows.append({"case": "catch_backward", "dx": race.turtle.position.x - x0})


func _case_catch_safe() -> void:
	_reset()
	_press_space()
	_check("7_safe_tubo_no_catch", not bool(race._catch_active),
		"active=%s" % str(race._catch_active))
	rows.append({"case": "catch_safe"})


func _case_catch_success() -> void:
	_reset()
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.position = Vector2(1220.0, race.surface_ref() + 120.0)
	race.rabbit.state = "FALLING_WATER"
	race.mount.mark_rescue_active(5.0)
	GameManager.accident_state = "RABBIT_WATER"
	GameManager.current_control = "turtle"
	_press_space()
	for i in 150:
		race._physics_process(1.0 / FPS)
		if String(race.rescue_last_result) == "caught" or race.mount.state == "CARRYING" or race.mount.state == "RIDING":
			break
	_check("8_catch_success", String(race.rescue_last_result) == "caught"
		or race.mount.state in ["CARRYING", "RIDING"],
		"result=%s mount=%s turtle=%s rabbit=%s active=%s target_y=%.0f dist=%.0f" % [String(race.rescue_last_result), String(race.mount.state), str(race.turtle.position), str(race.rabbit.position), str(race._catch_active), float(race.turtle.catch_target_y), race.turtle.position.distance_to(race.rabbit.position)])
	rows.append({"case": "catch_success", "result": String(race.rescue_last_result),
		"mount": String(race.mount.state)})


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"task": "TBB-CORE-FEEL-12 skills",
		"generated_at": Time.get_datetime_string_from_system(),
		"checks": checks, "rows": rows}, "  "))
	f.close()


func _finish() -> void:
	Engine.time_scale = 1.0
	var failed := 0
	for c in checks:
		if not bool(c["ok"]):
			failed += 1
	print("FEEL-12 SKILLS: %d/%d pass" % [checks.size() - failed, checks.size()])
	print("FEEL-12 SKILLS RESULT: ", "PASS" if failed == 0 else "FAIL")
	get_tree().quit(0 if failed == 0 else 1)
