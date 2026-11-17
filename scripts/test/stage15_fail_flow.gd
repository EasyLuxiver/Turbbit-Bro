extends Node
## FEEL-15：氧气耗尽实际切换 fail.tscn，R 重开，不进入普通结算。

var is_runner := false
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
	var race := get_tree().current_scene
	race.set_physics_process(false)
	race.test_disable_hazards = true
	race.load_level([], [])
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "RABBIT_WATER"
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.position = Vector2(1000.0, race.surface_ref() + 128.0)
	race.rabbit.state = "FALLING_WATER"
	race.mount.mark_rescue_active(3.2)
	GameManager.oxygen = 0.01
	race._update_oxygen(0.1)
	_check("state_failed", GameManager.state == GameManager.GameState.FAILED,
		GameManager.state_name())
	for i in 12:
		await get_tree().process_frame
	_check("fail_scene", get_tree().current_scene != null
		and get_tree().current_scene.scene_file_path.ends_with("fail.tscn"),
		str(get_tree().current_scene.scene_file_path if get_tree().current_scene else ""))
	GameManager.start_race()
	for i in 8:
		await get_tree().process_frame
	_check("retry_race", get_tree().current_scene != null
		and get_tree().current_scene.scene_file_path.ends_with("race.tscn")
		and GameManager.state == GameManager.GameState.RUNNING,
		"%s %s" % [str(get_tree().current_scene.scene_file_path if get_tree().current_scene else ""),
			GameManager.state_name()])
	_write()
	get_tree().quit(0 if checks.all(func(c): return bool(c["ok"])) else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	print(("ok    " if ok else "FAIL  ") + name + "  " + detail)


func _write() -> void:
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-15-fail-flow.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks}, "  "))
	f.close()
