extends Node
## FEEL-15：氧气只属于 TUBO 水下；自动恢复；氧气耗尽独立失败。

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
	# 1) 正常骑乘：隐藏、回满。
	_riding()
	GameManager.oxygen = 3.0
	race._update_oxygen(1.0)
	_check("riding_hides_bubbles", not race.oxygen_bubbles_visible(),
		"visible=%s oxygen=%.2f" % [str(race.oxygen_bubbles_visible()),
			GameManager.oxygen])
	_check("riding_recovers_oxygen", GameManager.oxygen > 3.0,
		"oxygen=%.2f" % GameManager.oxygen)
	# 2) 水下：显示并消耗。
	_water()
	GameManager.oxygen = 8.0
	race._update_oxygen(1.0)
	_check("water_shows_bubbles", race.oxygen_bubbles_visible(),
		"visible=%s" % str(race.oxygen_bubbles_visible()))
	_check("water_drains_oxygen", GameManager.oxygen < 8.0,
		"oxygen=%.2f" % GameManager.oxygen)
	# 3) FEEL-22：超时自动回壳已取消；等 3.2 s 也不能自动接住。
	_water()
	var t := 0.0
	var auto_seen := false
	var guard := 0
	while guard < 220:
		race._tick_recovery(1.0 / FPS)
		t += 1.0 / FPS
		if String(race.rescue_last_result) == "auto":
			auto_seen = true
		guard += 1
	_check("no_timeout_auto_recovery", not auto_seen
		and String(race.mount.state) == "RESCUE_ACTIVE",
		"auto=%s mount=%s t=%.2f" % [str(auto_seen), String(race.mount.state), t])
	_check("rescue_bubbles_visible", race.oxygen_bubbles_visible(),
		"visible=%s" % str(race.oxygen_bubbles_visible()))
	# 4) 氧气耗尽：立即 FAILED，进入独立失败场景。
	_water()
	GameManager.oxygen = 0.01
	race._update_oxygen(0.1)
	_check("oxygen_zero_fails", GameManager.state == GameManager.GameState.FAILED
		and GameManager.failure_reason == "OXYGEN_OUT",
		"state=%s reason=%s" % [GameManager.state_name(), GameManager.failure_reason])
	_check("failure_does_not_use_result",
		GameManager.state != GameManager.GameState.RESULT,
		"state=%s" % GameManager.state_name())
	_write()
	get_tree().quit(0 if checks.all(func(c): return bool(c["ok"])) else 1)


func _riding() -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	race.mount.reset()
	race.mount.mark_riding()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.rabbit.state = "RIDING"


func _water() -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "RABBIT_WATER"
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.position = Vector2(1000.0, race.surface_ref() + 128.0)
	race.rabbit.state = "FALLING_WATER"
	race.mount.mark_rescue_active(3.2)
	race.rescue_last_result = ""
	race.rescue_last_reason = ""


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-15-oxygen.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks}, "  "))
	f.close()
