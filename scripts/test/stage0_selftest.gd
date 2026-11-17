extends Node
## 阶段 0 自检。以独立场景运行，不影响主流程。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage0_selftest.tscn

const Tuning = preload("res://scripts/systems/tuning.gd")
const LevelDataScript = preload("res://scripts/systems/level_data.gd")

var is_runner := false
var failures: Array[String] = []
var _best_existed := false
var _best_text := ""


func _ready() -> void:
	if not is_runner:
		# 自检节点必须挂在 root 上，否则 change_scene 会把它一起 free 掉。
		var runner := Node.new()
		runner.name = "Stage0Runner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	# 自检会瞬移到终点，finalize_run 会把它当成个人纪录写进 best.json。
	# 跑测试不能污染玩家纪录，先备份、结束时原样还回去。
	_backup_best()
	for action in ["shift", "boost", "up", "down", "pause", "restart", "confirm"]:
		_check(InputMap.has_action(action), "action exists: " + action)

	GameManager.start_race()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(get_tree().current_scene.scene_file_path.ends_with("race.tscn"),
		"Enter -> race scene loaded")
	print("  scene  -> ", get_tree().current_scene.scene_file_path)
	_check(GameManager.state == GameManager.GameState.RUNNING, "state RUNNING after start")
	_check(GameManager.current_control == "rabbit", "initial control is rabbit")
	# 场景加载会吃掉几帧；这里判断的是“重置”而不是精确的零。
	_check(GameManager.race_time < 0.5, "race time reset on start")
	_check(is_equal_approx(GameManager.oxygen, Tuning.OXYGEN_MAX), "oxygen reset on start")
	var overlay := get_tree().current_scene.get_node_or_null("DebugOverlay")
	_check(overlay != null, "debug overlay exists in race scene")
	if overlay != null:
		var text: String = overlay.label.text
		print("  overlay -> ", text.replace("\n", " | "))
		_check(text.contains("control:") and text.contains("oxygen:")
			and text.contains("speed:") and text.contains("time:")
			and text.contains("accidents:"), "debug overlay shows state fields")

	var t0 := GameManager.race_time
	await get_tree().create_timer(0.25).timeout
	_check(GameManager.race_time > t0, "race time advances while running")

	_send_key(KEY_SHIFT, true)
	await get_tree().process_frame
	_send_key(KEY_SHIFT, false)
	_check(GameManager.current_control == "turtle", "Shift event swaps control to turtle")
	await get_tree().process_frame
	if overlay != null:
		_check(overlay.label.text.contains("TURTLE"),
			"debug overlay follows control change")

	# FEEL-09 P0-C：0.20 s 内第二次 SHIFT 会被锁定挡住；等锁定过了再按。
	await get_tree().create_timer(0.25).timeout
	_send_key(KEY_SHIFT, true)
	await get_tree().process_frame
	_send_key(KEY_SHIFT, false)
	_check(GameManager.current_control == "rabbit", "Shift event swaps control back to rabbit")
	# 阶段 4：下潜是主动动作。切到乌龟，按住 ↓ 越过 334+80 的氧气线。
	await get_tree().create_timer(0.25).timeout
	_send_key(KEY_SHIFT, true)
	await get_tree().process_frame
	_send_key(KEY_SHIFT, false)
	_send_key(KEY_DOWN, true)
	await get_tree().create_timer(1.4).timeout
	_check(GameManager.current_control == "turtle"
		and GameManager.oxygen < Tuning.OXYGEN_MAX - 0.1,
		"oxygen drops when the turtle dives below the air line")
	_send_key(KEY_DOWN, false)
	await get_tree().process_frame

	GameManager.start_race()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(GameManager.race_time < 0.2, "restart resets time")
	_check(is_equal_approx(GameManager.oxygen, Tuning.OXYGEN_MAX), "restart resets oxygen")
	_check(GameManager.current_control == "rabbit", "restart resets control")

	_send_key(KEY_ESCAPE, true)
	await get_tree().process_frame
	_send_key(KEY_ESCAPE, false)
	_check(GameManager.state == GameManager.GameState.PAUSED, "Esc pauses")
	_send_key(KEY_M, true)
	await get_tree().process_frame
	_send_key(KEY_M, false)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(get_tree().current_scene.scene_file_path.ends_with("menu.tscn"),
		"M from pause -> menu scene")
	print("  scene  -> ", get_tree().current_scene.scene_file_path)

	GameManager.start_race()
	await get_tree().process_frame
	await get_tree().process_frame
	var race := get_tree().current_scene
	race.turtle.position.x = LevelDataScript.WORLD_END + 1.0
	# 阶段 3 起终点有 1.6 秒的 FINISH 演出，之后才切结算。
	var wait_start := Time.get_ticks_msec()
	while not get_tree().current_scene.scene_file_path.ends_with("result.tscn") \
			and Time.get_ticks_msec() - wait_start < 5000:
		await get_tree().physics_frame
	_check(get_tree().current_scene.scene_file_path.ends_with("result.tscn"),
		"finish -> result scene")
	print("  scene  -> ", get_tree().current_scene.scene_file_path)

	GameManager.go_to_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(get_tree().current_scene.scene_file_path.ends_with("menu.tscn"),
		"result -> menu scene")
	print("  scene  -> ", get_tree().current_scene.scene_file_path)

	_restore_best()
	if failures.is_empty():
		print("STAGE0 SELFTEST: PASS")
		get_tree().quit(0)
	else:
		print("STAGE0 SELFTEST: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


func _backup_best() -> void:
	_best_existed = FileAccess.file_exists(GameManager.BEST_PATH)
	if _best_existed:
		_best_text = FileAccess.get_file_as_string(GameManager.BEST_PATH)


func _restore_best() -> void:
	if _best_existed:
		var file := FileAccess.open(GameManager.BEST_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(_best_text)
			file.close()
	elif FileAccess.file_exists(GameManager.BEST_PATH):
		DirAccess.remove_absolute(GameManager.best_path_absolute())


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok  " + message)
	else:
		failures.append(message)
		print("  FAIL " + message)
