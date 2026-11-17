extends Node
## FEEL-12 P0：BRO OVERDRIVE 判定与慢镜头矩阵。
## 输出：docs/reports/longrun/core-feel-12-overdrive.json

const OUT := "res://docs/reports/longrun/core-feel-12-overdrive.json"
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
	race.set_process(false)
	race.opening_active = false
	race.test_no_finish = true
	GameManager.test_no_best = true
	_case_normal_shift()
	_case_tubo()
	_case_bitt()
	_case_slowmo_inputs()
	_case_slowmo_shift()
	_case_collision()
	_case_consecutive()
	_case_rescue()
	_case_30_60_120()
	_write()
	_finish()


func _reset() -> void:
	GameManager._reset_run()
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.current_control = "rabbit"
	GameManager.shift_lock_t = 0.0
	GameManager.test_no_best = true
	GameManager.accident_state = "NONE"
	GameManager.role_mischief_pending = false
	race.test_disable_hazards = true
	race.test_no_finish = true
	race.world_end = 1.0e9
	race.load_level([], [])
	race.turtle.reset(Vector2(800.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race.rabbit_brain.drift = 0.0
	race.turtle_brain.drift = 0.0
	race._od_phase = ""
	race._od_role = ""
	race._od_cd = 0.0
	race._od_emphasis_t = 0.0
	race._od_flash = 0.0
	race._od_afterimages.clear()
	race._od_events.clear()
	race._relay = {}
	Engine.time_scale = 1.0


func _prime(who: String) -> void:
	GameManager.current_control = who
	if who == "rabbit":
		race.rabbit_brain.drift = 12.0
		race.rabbit.drift = 12.0
	else:
		race.turtle_brain.drift = 12.0
		race.turtle.drift = 12.0
	race._tick_overdrive(1.0 / FPS)


func _last_event() -> Dictionary:
	return race._od_events[race._od_events.size() - 1] if not race._od_events.is_empty() else {}


func _case_normal_shift() -> void:
	_reset()
	GameManager.toggle_control()
	_check("1_normal_shift_no_slow",
		GameManager.current_control == "turtle" and String(race._od_phase) == ""
			and is_equal_approx(Engine.time_scale, 1.0),
		"control=%s od=%s time=%s" % [GameManager.current_control,
			String(race._od_phase), str(Engine.time_scale)])
	rows.append({"case": "normal"})


func _case_tubo() -> void:
	_reset()
	_prime("rabbit")
	_check("2a_tubo_pre", String(race._od_phase) == "PRE"
		and String(race._od_role) == "rabbit",
		"od=%s role=%s" % [String(race._od_phase), String(race._od_role)])
	GameManager.toggle_control()
	var airborne: bool = race.rabbit.state in ["JUMPING", "FALLING"]
	_check("2b_tubo_shift_overdrive",
		GameManager.current_control == "turtle" and String(race._od_phase) == "ACTIVE"
			and airborne and is_equal_approx(Engine.time_scale, 1.0) \
			and float(race._od_emphasis_t) > 0.0,
		"control=%s od=%s rabbit=%s emphasis=%.2f" % [GameManager.current_control,
			String(race._od_phase), String(race.rabbit.state), float(race._od_emphasis_t)])
	rows.append({"case": "tubo", "event": _last_event(), "time": Engine.time_scale})
	# 补充 B：没有全局慢镜头；只有 0.70 s 的视觉强调，时间流速恒为 1。
	for i in 20:
		race._overdrive_tick_real(0.01)
	_check("2c_emphasis_holds", float(race._od_emphasis_t) > 0.0
		and is_equal_approx(Engine.time_scale, 1.0),
		"emphasis=%.2f time=%.2f" % [float(race._od_emphasis_t), Engine.time_scale])
	for i in 60:
		race._overdrive_tick_real(0.01)
	_check("2d_emphasis_ends", float(race._od_emphasis_t) <= 0.0
		and is_equal_approx(Engine.time_scale, 1.0),
		"emphasis=%.2f time=%.2f" % [float(race._od_emphasis_t), Engine.time_scale])


func _case_bitt() -> void:
	_reset()
	_prime("turtle")
	_check("3a_bitt_pre", String(race._od_phase) == "PRE"
		and String(race._od_role) == "turtle", "od=%s" % String(race._od_phase))
	GameManager.toggle_control()
	_check("3b_bitt_shift_overdrive",
		GameManager.current_control == "rabbit" and String(race._od_phase) == "ACTIVE"
			and race.turtle.speed > race.turtle.base_speed + 100.0,
		"control=%s turtle_speed=%.0f time=%s" % [GameManager.current_control,
			race.turtle.speed, str(Engine.time_scale)])
	rows.append({"case": "bitt", "event": _last_event(), "speed": race.turtle.speed})
	race._overdrive_tick_real(1.0)


func _case_slowmo_inputs() -> void:
	_reset()
	_prime("rabbit")
	GameManager.toggle_control()  # TUBO spring, control BITT
	# 慢镜头中 BITT ↓ 必须立即被听见。
	Input.action_press("down")
	race._physics_process(1.0 / FPS)
	var dive: bool = race.turtle.diving
	Input.action_release("down")
	# 慢镜头中 ↑ 交回兔子必须能起跳/触发输入缓存。
	GameManager.toggle_control()
	Input.action_press("up")
	race._physics_process(1.0 / FPS)
	Input.action_release("up")
	_check("4_slowmo_inputs", dive, "BITT diving in slow-mo=%s" % str(dive))
	rows.append({"case": "slow_inputs", "dive": dive})
	race._overdrive_tick_real(1.0)


func _case_slowmo_shift() -> void:
	_reset()
	_prime("rabbit")
	GameManager.toggle_control()
	var ev0: int = race._od_events.size()
	GameManager.toggle_control()  # 慢镜头中再换，不能重复触发同一事件奖励
	race._physics_process(1.0 / FPS)
	_check("5_slowmo_shift_no_repeat", race._od_events.size() == ev0,
		"events %d -> %d" % [ev0, race._od_events.size()])
	rows.append({"case": "slow_shift", "events": race._od_events.size()})
	race._overdrive_tick_real(1.0)


func _case_collision() -> void:
	_reset()
	_prime("rabbit")
	GameManager.toggle_control()
	var s0: int = GameManager.total_score
	GameManager.note_mistake("RABBIT_STUN", "rabbit")
	race._physics_process(1.0 / FPS)
	race._tick_shift_relay(0.1)
	var r := {}
	if not race.relay_log.is_empty():
		r = race.relay_log[race.relay_log.size() - 1]
	_check("6_collision_no_relay_reward",
		r.is_empty() or int(r.get("score", 0)) == 0,
		"relay=%s score_delta=%d" % [str(r), GameManager.total_score - s0])
	rows.append({"case": "collision", "relay": r})
	race._overdrive_tick_real(1.0)


func _case_consecutive() -> void:
	_reset()
	_prime("rabbit")
	GameManager.toggle_control()
	race._overdrive_tick_real(1.0)
	race._physics_process(1.0 / FPS)
	race._od_phase = ""
	race._od_role = ""
	race._od_cd = 0.0
	_prime("turtle")
	GameManager.toggle_control()
	_check("7_consecutive_different_roles", race._od_events.size() >= 2,
		"events=%d" % race._od_events.size())
	rows.append({"case": "consecutive", "events": race._od_events.size()})
	race._overdrive_tick_real(1.0)


func _case_rescue() -> void:
	_reset()
	GameManager.accident_state = "RABBIT_WATER"
	race.mount.state = "RESCUE_FALLING"
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	race._tick_overdrive(1.0 / FPS)
	_check("8_rescue_no_overdrive", String(race._od_phase) == ""
		and GameManager.current_control == "turtle",
		"od=%s control=%s" % [String(race._od_phase), GameManager.current_control])
	rows.append({"case": "rescue"})


func _case_30_60_120() -> void:
	for fps in [30, 60, 120]:
		_reset()
		race._start_emphasis()
		var t := 0.0
		var end_t := -1.0
		var step: float = 1.0 / float(fps)
		while t < 1.0:
			race._overdrive_tick_real(step)
			t += step
			if end_t < 0.0 and float(race._od_emphasis_t) <= 0.0:
				end_t = t
		_check("9_emphasis_%dHz" % fps,
			end_t > 0.68 and end_t < 0.80 and is_equal_approx(Engine.time_scale, 1.0),
			"end=%.2f time=%.2f" % [end_t, Engine.time_scale])
		rows.append({"case": "emphasis_%d" % fps, "end": end_t})

func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"task": "TBB-CORE-FEEL-12 P0",
		"generated_at": Time.get_datetime_string_from_system(),
		"checks": checks, "rows": rows}, "  "))
	f.close()


func _finish() -> void:
	Engine.time_scale = 1.0
	var failed := 0
	for c in checks:
		if not bool(c["ok"]):
			failed += 1
	print("FEEL-12 OVERDRIVE: %d/%d pass" % [checks.size() - failed, checks.size()])
	print("FEEL-12 OVERDRIVE RESULT: ", "PASS" if failed == 0 else "FAIL")
	get_tree().quit(0 if failed == 0 else 1)
