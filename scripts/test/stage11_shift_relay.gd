extends Node
## FEEL-11 B5：SHIFT 电流接力判定矩阵（10 例）。
##
## 只验证“判定/奖励/不刷分”，不把自动化 PASS 当成趣味性通过。
## 输出：docs/reports/longrun/core-feel-11-shift-relay.json

const OUT := "res://docs/reports/longrun/core-feel-11-shift-relay.json"
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
	if race == null:
		_check("race", false, "no race")
		_finish()
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	GameManager.test_no_best = true
	_case_normal()
	_case_rabbit_jump_to_turtle_dive()
	_case_turtle_dive_to_rabbit_jump()
	_case_rapid_double()
	_case_outgoing_continues()
	_case_collision_cancels()
	_case_rescue_no_relay()
	_case_drift_shift()
	_case_perfect()
	_case_no_farm()
	_write()
	_finish()


func _reset() -> void:
	GameManager._reset_run()
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.current_control = "rabbit"
	GameManager.shift_lock_t = 0.0
	GameManager.has_shifted = false
	GameManager.test_no_best = true
	GameManager.accident_state = "NONE"
	race.test_disable_hazards = true
	race.test_no_finish = true
	race.world_end = 1.0e9
	race.hazard_cooldown = 0.0
	race.load_level([], [])
	race.turtle.reset(Vector2(800.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race._relay = {}
	race._relay_cd = 0.0
	race.relay_log.clear()
	Input.action_release("up")
	Input.action_release("down")


func _step(n: int) -> void:
	for i in n:
		race._physics_process(1.0 / FPS)


func _jump() -> void:
	race.rabbit.launch(race.turtle.get_mount_point(), race.turtle.speed)
	race.mount.mark_airborne()


func _last() -> Dictionary:
	return race.relay_log[race.relay_log.size() - 1] if not race.relay_log.is_empty() else {}


func _case_normal() -> void:
	_reset()
	var s0: int = GameManager.total_score
	var x0: float = race.turtle.position.x
	var sp0: float = race.turtle.speed
	GameManager.toggle_control()
	_step(90)
	var ok: bool = GameManager.current_control == "turtle" and race.relay_log.is_empty() \
		and GameManager.total_score == s0 and race.turtle.speed >= sp0 * 0.9 \
		and race.turtle.position.x > x0
	_check("1_normal_cruise", ok,
		"control=%s relays=%d score_delta=%d speed=%.0f dx=%.0f" % [
			GameManager.current_control, race.relay_log.size(),
			GameManager.total_score - s0, race.turtle.speed, race.turtle.position.x - x0])
	rows.append({"case": "normal", "ok": ok, "relays": race.relay_log.size()})


func _case_rabbit_jump_to_turtle_dive() -> void:
	_reset()
	_jump()
	_step(4)
	GameManager.toggle_control()
	Input.action_press("down")
	_step(20)
	Input.action_release("down")
	_step(100)
	var r := _last()
	_check("2_jump_to_dive_clever",
		not r.is_empty() and String(r.get("result", "")) == "clever"
			and int(r.get("score", 0)) == 50,
		"relay=%s" % str(r))
	rows.append({"case": "jump_to_dive", "relay": r})


func _case_turtle_dive_to_rabbit_jump() -> void:
	_reset()
	GameManager.current_control = "turtle"
	Input.action_press("down")
	_step(30)
	GameManager.toggle_control()
	Input.action_release("down")
	_jump()
	_step(110)
	var r := _last()
	_check("3_dive_to_jump_clever",
		not r.is_empty() and String(r.get("result", "")) == "clever",
		"relay=%s control=%s" % [str(r), GameManager.current_control])
	rows.append({"case": "dive_to_jump", "relay": r})


func _case_rapid_double() -> void:
	_reset()
	_jump()
	_step(4)
	GameManager.toggle_control()
	GameManager.toggle_control()  # 0.2 s 锁内，应被拒
	_step(100)
	var r := _last()
	_check("4_rapid_double_no_double",
		GameManager.current_control == "turtle" and race.relay_log.size() <= 1
			and (r.is_empty() or int(r.get("score", 0)) <= 50),
		"control=%s relays=%d last=%s" % [GameManager.current_control,
			race.relay_log.size(), str(r)])
	rows.append({"case": "rapid_double", "relays": race.relay_log.size(),
		"control": GameManager.current_control})


func _case_outgoing_continues() -> void:
	_reset()
	_jump()
	_step(3)
	var airborne_before: bool = race.rabbit.is_airborne()
	GameManager.toggle_control()
	Input.action_press("down")
	_step(8)
	var airborne_after: bool = race.rabbit.is_airborne()
	var turtle_dive: bool = race.turtle.diving or float(race.turtle.standby_dive_t) > 0.0
	Input.action_release("down")
	_check("5_outgoing_continues", airborne_before and airborne_after and turtle_dive,
		"rabbit_air %s->%s turtle_dive=%s standby=%.2f" % [
			str(airborne_before), str(airborne_after), str(turtle_dive),
			float(race.turtle.standby_dive_t)])
	rows.append({"case": "outgoing_continues", "rabbit_air": airborne_after,
		"turtle_dive": turtle_dive})


func _case_collision_cancels() -> void:
	_reset()
	_jump()
	_step(3)
	GameManager.toggle_control()
	Input.action_press("down")
	_step(6)
	var s0: int = GameManager.total_score
	GameManager.note_mistake("RABBIT_STUN", "rabbit")
	_step(100)
	Input.action_release("down")
	var r := _last()
	var relay_score := 0 if r.is_empty() else int(r.get("score", 0))
	_check("6_collision_cancels", relay_score == 0,
		"relay=%s score=+%d (obstacle score not counted)" % [str(r), relay_score])
	rows.append({"case": "collision", "relay": r})


func _case_rescue_no_relay() -> void:
	_reset()
	GameManager.accident_state = "RABBIT_WATER"
	race.mount.state = "RESCUE_FALLING"
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	_step(10)
	_check("7_rescue_no_relay",
		GameManager.current_control == "turtle" and race.relay_log.is_empty(),
		"control=%s relays=%d" % [GameManager.current_control,
			race.relay_log.size()])
	rows.append({"case": "rescue", "control": GameManager.current_control,
		"relays": race.relay_log.size()})


func _case_drift_shift() -> void:
	_reset()
	race.rabbit_brain.drift = 12.0
	race.rabbit.drift = 12.0
	var x0: float = race.rabbit.position.x
	GameManager.toggle_control()
	_step(30)
	_check("8_drift_shift_stable",
		GameManager.current_control == "turtle"
			and absf(race.rabbit.position.x - x0) < 260.0,
		"control=%s rabbit_dx=%.1f" % [GameManager.current_control,
			race.rabbit.position.x - x0])
	rows.append({"case": "drift", "control": GameManager.current_control})


func _case_perfect() -> void:
	_reset()
	_jump()
	_step(3)
	GameManager.toggle_control()
	Input.action_press("down")
	_step(8)
	GameManager.note_precise_pass("FLOATING_LOG")
	_step(30)
	Input.action_release("down")
	var r := _last()
	_check("9_perfect_relay",
		not r.is_empty() and String(r.get("result", "")) == "perfect"
			and int(r.get("score", 0)) == 100,
		"relay=%s" % str(r))
	rows.append({"case": "perfect", "relay": r})


func _case_no_farm() -> void:
	_reset()
	_jump()
	_step(3)
	GameManager.toggle_control()
	Input.action_press("down")
	_step(8)
	GameManager.note_precise_pass("FLOATING_LOG")
	_step(30)
	var n1: int = race.relay_log.size()
	var s1: int = GameManager.total_score
	# 冷却内再切一次：可以换人，但不该再给一次接力分。
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	Input.action_release("down")
	_step(20)
	Input.action_release("down")
	_check("10_no_farm",
		race.relay_log.size() == n1 and GameManager.total_score >= s1,
		"relays %d->%d score_delta=%d (only obstacle points after)" % [
			n1, race.relay_log.size(), GameManager.total_score - s1])
	rows.append({"case": "no_farm", "relays": n1, "after": race.relay_log.size()})


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var data := {"task": "TBB-CORE-FEEL-11 B5",
		"generated_at": Time.get_datetime_string_from_system(),
		"checks": checks, "rows": rows}
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()


func _finish() -> void:
	var failed := 0
	for c in checks:
		if not bool(c["ok"]):
			failed += 1
	print("FEEL-11 SHIFT RELAY: %d/%d pass" % [checks.size() - failed, checks.size()])
	print("FEEL-11 SHIFT RELAY RESULT: ", "PASS" if failed == 0 else "FAIL")
	GameManager.test_no_best = false
	get_tree().quit(0 if failed == 0 else 1)
