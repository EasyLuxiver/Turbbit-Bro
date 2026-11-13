extends Node
## 阶段 4 完整流程：菜单 -> 比赛 -> 暂停/恢复 -> 终点 -> 结算 -> 重开 -> 菜单，
## 中英文各走一遍。冲线会调用 finalize_run()，所以测试前备份 best.json、
## 测试后原样写回，并断言内容一致——测试成绩不进真实纪录。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage4_flow.tscn

const SETTINGS_PATH := "user://settings.json"
const LevelDataScript = preload("res://scripts/systems/level_data.gd")
const WORLD_END := LevelDataScript.WORLD_END

var is_runner := false
var failures: Array[String] = []
var _settings_backup := {}
var _best_backup := {}


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4FlowRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	_settings_backup = _backup_file(SETTINGS_PATH)
	_best_backup = _backup_file(GameManager.BEST_PATH)
	Engine.time_scale = 4.0

	await _flow_zh()
	await _flow_en()

	_restore_file(GameManager.BEST_PATH, _best_backup)
	_restore_file(SETTINGS_PATH, _settings_backup)
	Locale.language = "zh"
	_check(_read_file(GameManager.BEST_PATH) == str(_best_backup.get("text", "")),
		"flow test restores best.json byte for byte")

	if failures.is_empty():
		print("STAGE4 FLOW: PASS")
		get_tree().quit(0)
	else:
		print("STAGE4 FLOW: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


func _flow_zh() -> void:
	Locale.set_language("zh")
	GameManager.go_to_menu()
	await _wait_scene("menu.tscn")
	await _frames(3)
	var menu := get_tree().current_scene
	_check(_joined(menu).contains("开始游戏"), "zh menu shows start button")

	await _press(KEY_ENTER)
	await _wait_scene("race.tscn")
	await _frames(4)
	var race := get_tree().current_scene
	_check(GameManager.state == GameManager.GameState.RUNNING, "zh ENTER starts race")
	_check(race.hud.time_label.text.contains(":") and race.hud.zone_label.text.contains("区域"), "zh race HUD")
	race.test_disable_hazards = true

	await _press(KEY_ESCAPE)
	await _frames(2)
	_check(GameManager.state == GameManager.GameState.PAUSED, "zh ESC pauses")
	await _press(KEY_ESCAPE)
	await _frames(2)
	_check(GameManager.state == GameManager.GameState.RUNNING, "zh ESC resumes")

	race.turtle.position = Vector2(WORLD_END + 4.0, 300.0)
	await _wait_scene("result.tscn", 240)
	await _frames(4)
	var result := get_tree().current_scene
	_check(_joined(result).contains("比赛完成"), "zh result title")
	check_numbers(result, "zh")

	await _press(KEY_R)
	await _wait_scene("race.tscn")
	await _frames(4)
	_check(get_tree().current_scene.scene_file_path.ends_with("race.tscn"), "zh R restarts")
	await _press(KEY_ESCAPE)
	await _frames(2)
	await _press(KEY_M)
	await _wait_scene("menu.tscn")
	await _frames(3)
	_check(get_tree().current_scene.scene_file_path.ends_with("menu.tscn"),
		"zh paused M returns to menu")


func _flow_en() -> void:
	Locale.set_language("en")
	await _frames(2)
	var menu := get_tree().current_scene
	_check(_joined(menu).contains("START GAME"), "en menu shows start button")

	await _press(KEY_ENTER)
	await _wait_scene("race.tscn")
	await _frames(4)
	var race := get_tree().current_scene
	_check(GameManager.state == GameManager.GameState.RUNNING, "en ENTER starts race")
	_check(race.hud.time_label.text.contains(":") and race.hud.zone_label.text.contains("ZONE"), "en race HUD")
	_check(not race.hud.control_label.text.contains("控制"), "en HUD has no leftover Chinese")
	race.test_disable_hazards = true

	race.turtle.position = Vector2(WORLD_END + 4.0, 300.0)
	await _wait_scene("result.tscn", 240)
	await _frames(4)
	var result := get_tree().current_scene
	_check(_joined(result).contains("RACE COMPLETE"), "en result title")
	check_numbers(result, "en")

	# 结算默认焦点在“再玩一次”；返回主菜单走 M 快捷键或点按钮。
	await _press(KEY_M)
	await _wait_scene("menu.tscn")
	await _frames(3)
	_check(get_tree().current_scene.scene_file_path.ends_with("menu.tscn"),
		"en result M returns to menu")


func check_numbers(result: Node, tag: String) -> void:
	var text := _joined(result)
	# §七-9：结算七项可读，固定数字总分不再出现。
	var keys: Array = ["比赛时间", "干净通过", "连招", "救援成功", "失误", "翻船次数"] \
		if tag == "zh" else ["RACE TIME", "CLEAN PASSES", "BRO COMBOS",
			"RESCUE SAVES", "MISTAKES", "CAPSIZES"]
	for key in keys:
		_check(text.contains(String(key)), "%s result shows %s" % [tag, key])
	var score_key := "总分" if tag == "zh" else "TOTAL SCORE"
	_check(not text.contains(score_key), "%s result hides total score" % tag)


func _wait_scene(marker: String, timeout_frames := 600) -> void:
	for i in timeout_frames:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path.ends_with(marker):
			return
	_check(false, "scene %s reached" % marker)


func _press(keycode: Key) -> void:
	_send_key(keycode, true)
	await get_tree().process_frame
	_send_key(keycode, false)
	await get_tree().process_frame


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _joined(root: Node) -> String:
	return "\n".join(PackedStringArray(_label_texts(root)))


func _label_texts(root: Node) -> Array[String]:
	var out: Array[String] = []
	if root is Label and (root as Label).text != "":
		out.append((root as Label).text)
	if root is Button and (root as Button).text != "":
		out.append((root as Button).text)
	for child in root.get_children():
		out.append_array(_label_texts(child))
	return out


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok  " + message)
	else:
		failures.append(message)
		print("  FAIL " + message)


func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _backup_file(path: String) -> Dictionary:
	return {"exists": FileAccess.file_exists(path), "text": _read_file(path)}


func _restore_file(path: String, info: Dictionary) -> void:
	if info.get("exists", false):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(info["text"])
			file.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
