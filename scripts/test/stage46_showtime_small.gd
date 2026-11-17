extends Node
## PHASE-FIX：Showtime 是 <=0.7 s 的小奖励；不抢控制；清空惩罚条。

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
	race.load_level([], [])
	GameManager.current_control = "rabbit"
	GameManager.accident_state = "NONE"
	GameManager.complaint_role = "rabbit"
	GameManager.complaint_t = 3.0
	GameManager.bro_meter = 2
	var control_before := GameManager.current_control
	race.start_showtime()
	_check("showtime_starts", race.showtime_active, "active=%s" % str(race.showtime_active))
	_check("penalty_cleared", GameManager.complaint_role == ""
		and GameManager.complaint_t == 0.0 and GameManager.bro_meter == 0,
		"complaint=%s t=%.1f meter=%d" % [GameManager.complaint_role,
			GameManager.complaint_t, GameManager.bro_meter])
	var max_offset := 0.0
	var max_turtle := 0.0
	for i in 60:
		if not race.showtime_active:
			break
		race._tick_showtime(1.0 / 60.0)
		var base: float = race.turtle.get_mount_point().y
		max_offset = maxf(max_offset, absf(race.rabbit.position.y - base))
		max_turtle = maxf(max_turtle, absf(race._showtime_turtle_y))
	_check("showtime_short", not race.showtime_active
		and race.showtime_t <= Tuning.SHOWTIME_TIME + 0.03,
		"active=%s t=%.2f" % [str(race.showtime_active), race.showtime_t])
	_check("showtime_small_hop", max_offset <= 30.0,
		"max rabbit offset %.1f" % max_offset)
	_check("turtle_hop", max_turtle <= 24.0, "max turtle offset %.1f" % max_turtle)
	_check("control_kept", GameManager.current_control == control_before,
		"control=%s" % GameManager.current_control)
	print("STAGE46 SHOWTIME SMALL: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		print("  ok   " + name + "  " + detail)
	else:
		failures.append(name)
		print("  FAIL " + name + "  " + detail)
