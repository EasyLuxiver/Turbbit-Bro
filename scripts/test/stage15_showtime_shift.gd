extends Node
## FEEL-15：SHOWTIME 期间 SHIFT 只换控制权，不取消表演。

const FPS := 60.0
var is_runner := false
var race: Node
var checks: Array = []


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
	race.turtle.reset(Vector2(800.0, race.surface_ref()))
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	GameManager.current_control = "rabbit"
	GameManager.shift_lock_t = 0.0
	GameManager.accident_state = "NONE"
	race.start_showtime()
	_check("showtime starts", race.showtime_active and GameManager.showtime_active,
		"active=%s" % str(race.showtime_active))
	# 多次 SHIFT：不能结束表演，控制对象必须切换，另一角色仍可操作。
	for i in 4:
		GameManager.shift_lock_t = 0.0
		GameManager.toggle_control()
		race._tick_showtime(1.0 / FPS)
	_check("showtime survives shifts", race.showtime_active,
		"active=%s control=%s" % [str(race.showtime_active), GameManager.current_control])
	_check("rabbit still performing", race.rabbit.state == "SHOWTIME"
		and absf(race.rabbit.showtime_spin) > 0.01,
		"state=%s spin=%.2f" % [race.rabbit.state, race.rabbit.showtime_spin])
	# 另一角色：当前控制如果是 BITT，turtle_controlled 应成立（表演不锁 turtle）。
	var turtle_ok: bool = GameManager.current_control != "turtle" \
		or (race.turtle != null and not race.turtle.accident)
	# 再切一次到 BITT，确认表演期间另一角色能被玩家接住。
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	race._tick_showtime(1.0 / FPS)
	var bitt_ok: bool = GameManager.current_control == "turtle" and not race.turtle.accident
	_check("bitt_controllable_during_showtime", bitt_ok and race.showtime_active,
		"control=%s active=%s" % [GameManager.current_control,
			str(race.showtime_active)])
	_check("other role remains controllable", turtle_ok,
		"control=%s turtle_accident=%s" % [GameManager.current_control,
			str(race.turtle.accident)])
	# 表演完整结束。
	var guard := 0
	while race.showtime_active and guard < 300:
		race._tick_showtime(1.0 / FPS)
		guard += 1
	_check("showtime completes", not race.showtime_active and guard < 300,
		"ended after %d frames" % guard)
	_check("riding restored", race.rabbit.state == "RIDING"
		and race.mount.state == "RIDING",
		"rabbit=%s mount=%s control=%s" % [race.rabbit.state,
			race.mount.state, GameManager.current_control])
	# 控制权没有被表演抢回。
	_check("control stays where player left it",
		GameManager.current_control in ["rabbit", "turtle"],
		"control=%s" % GameManager.current_control)
	# 高优先级事故仍可中断表演。
	race.start_showtime()
	GameManager.accident_state = "NONE"
	race.hazard_cooldown = 0.0
	race._trigger_accident("RABBIT_STUN")
	_check("accident_interrupts_showtime", not race.showtime_active,
		"active=%s accident=%s" % [str(race.showtime_active),
			GameManager.accident_state])
	_write()
	get_tree().quit(0 if checks.all(func(c): return bool(c["ok"])) else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-15-showtime.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks}, "  "))
	f.close()
