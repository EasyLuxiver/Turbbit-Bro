extends Node
## 真实窗口彩排：进比赛、二连跳、自动接、切人、暂停、截图、FPS。

var is_runner := false
var race: Node
var failures: Array[String] = []
var dir := ""


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
	dir = ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	GameManager.test_no_best = true
	Locale.set_language("zh")
	GameManager.start_race()
	for i in 8:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.opening_active = false
	race.test_disable_hazards = true
	race.test_no_finish = true
	race.load_level([], [])
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.turtle.speed = 0.0
	race.turtle.base_speed = 0.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	GameManager.accident_state = "NONE"
	GameManager.current_control = "rabbit"
	await _shot("window_start")

	# 普通二连跳：不切乌龟，应该自动落壳。
	Input.action_press("up")
	for i in 2:
		await get_tree().process_frame
	Input.action_release("up")
	for i in 150:
		await get_tree().physics_frame
	_check("window_auto_catch", race.rabbit.state == "RIDING"
		and race.mount.state == "RIDING",
		"rabbit=%s mount=%s" % [race.rabbit.state, race.mount.state])
	await _shot("window_after_jump")

	# 第二次跳：空中切到乌龟，仍然要自动接。
	GameManager.current_control = "rabbit"
	GameManager.shift_lock_t = 0.0
	Input.action_press("up")
	for i in 2:
		await get_tree().process_frame
	Input.action_release("up")
	for i in 8:
		await get_tree().physics_frame
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	for i in 150:
		await get_tree().physics_frame
	_check("window_switch_midair_catch", race.rabbit.state == "RIDING"
		and race.mount.state == "RIDING",
		"rabbit=%s mount=%s control=%s" % [race.rabbit.state,
			race.mount.state, GameManager.current_control])
	await _shot("window_switch_midair")

	# 切乌龟，确认输入/控制切换正常。
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	for i in 4:
		await get_tree().process_frame
	_check("window_switch", GameManager.current_control == "rabbit",
		"control=%s" % GameManager.current_control)
	await _shot("window_turtle")

	# 暂停：菜单在最前、画面仍可见。
	GameManager.toggle_pause()
	for i in 4:
		await get_tree().process_frame
	var pause = race.get_node_or_null("PauseLayer/PauseMenu")
	_check("window_pause_visible", pause != null and pause.visible,
		"pause=%s" % str(pause != null and pause.visible))
	if pause != null:
		_check("window_pause_layer", pause.layer >= 100, "layer=%d" % pause.layer)
	await _shot("window_pause")
	GameManager.toggle_pause()
	for i in 3:
		await get_tree().process_frame
	_check("window_resume", GameManager.state == GameManager.GameState.RUNNING,
		"state=%s" % str(GameManager.state))

	for i in 30:
		await get_tree().process_frame
	print("WINDOW FPS ", Engine.get_frames_per_second())
	print("STAGE58 WINDOW: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("CAPTURE ", name)


func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		print("  ok   " + name + "  " + detail)
	else:
		failures.append(name)
		print("  FAIL " + name + "  " + detail)
