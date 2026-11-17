extends Node
## 阶段 4 菜单输入自检：全部走真实鼠标事件（InputEventMouseButton 打在按钮中心），
## 不用 emit_signal 走捷径。覆盖：主菜单三按钮、退出确认、设置页语言按钮、
## 暂停菜单三按钮、结算页两按钮，以及键盘焦点与 Enter/Space。
## 运行：Godot_v4.7-stable_win64_console.exe --headless --path TURBBIT res://scenes/stage4_menu_input.tscn

const SETTINGS_PATH := "user://settings.json"

var is_runner := false
var failures: Array[String] = []
var _settings_backup := {}
var _best_text := ""
var _orig_language := "zh"
var _scale := 1.0


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4MenuInputRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	_settings_backup = _backup(SETTINGS_PATH)
	_orig_language = Locale.language
	_best_text = _read(GameManager.BEST_PATH)
	Locale.language = "zh"
	# §六 720p 字号：项目视口 1600×900，窗口 1280×720 时 canvas_items 缩放 0.8。
	# 本探针窗口化运行，顺便量一次菜单/暂停/结算的最小实际字号。
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await _frames(2)
		_scale = float(DisplayServer.window_get_size().x) / 1600.0
		print("MENU-INPUT window=%s scale=%.3f" % [
			str(DisplayServer.window_get_size()), _scale])

	await _test_main_menu_mouse()
	await _test_quit_confirm_mouse()
	await _test_settings_mouse()
	await _test_pause_menu_mouse()
	await _test_result_mouse()
	await _test_keyboard_focus()

	_restore(SETTINGS_PATH, _settings_backup)
	Locale.language = _orig_language
	_check(_read(GameManager.BEST_PATH) == _best_text,
		"menu tests do not touch best.json")

	if failures.is_empty():
		print("STAGE4 MENU INPUT: PASS")
		get_tree().quit(0)
	else:
		print("STAGE4 MENU INPUT: FAIL")
		for item in failures:
			print("  - " + item)
		get_tree().quit(1)


# ---- 主菜单：三个按钮都在，点“开始游戏”真的进比赛。 ----

func _test_main_menu_mouse() -> void:
	# FEEL-11：正式流程首次启动会先进连环画；这个回归只测“开始→比赛”，
	# 所以把故事/教学标记置为已看。
	GameManager.story_seen = true
	GameManager.tutorial_done = true
	GameManager.state = GameManager.GameState.MENU
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	await _frames(6)
	var menu := get_tree().current_scene
	var buttons := _buttons(menu)
	await _shot("menu-zh")
	_check_min_font(menu, "main menu")
	_check(buttons.size() >= 3, "main menu exposes 3 native buttons (%d)" % buttons.size())
	_check(_has_text(buttons, "开始游戏"), "start button visible")
	_check(_has_text(buttons, "设置"), "settings button visible")
	_check(_has_text(buttons, "退出游戏"), "quit button visible")
	var start := _find_text(buttons, "开始游戏")
	_check(start != null and start.visible and start.size.x > 0.0,
		"start button has a real on-screen rect")
	# 窗口 1280×720、逻辑视口 1600×900 时，push_input 收的是窗口坐标，
	# 而 Control 的 global rect 是逻辑坐标——不乘缩放会点到别处。
	var hover := InputEventMouseMotion.new()
	hover.position = start.get_global_rect().get_center() * _scale
	hover.global_position = hover.position
	get_tree().root.push_input(hover)
	await _frames(2)
	# 注意：这个用例必须开真实窗口跑，--headless 下窗口是 0x0、视口 64x64，
	# 鼠标坐标会被重缩放，永远打不到按钮（2026-11-11 实测）。
	_check(start.is_hovered(), "mouse hover reaches the start button (hover style applies)")
	await _click(start)
	await _frames(6)
	_check(_scene_is("race.tscn"), "mouse click on START GAME enters the race")
	_check(GameManager.state == GameManager.GameState.RUNNING, "race state RUNNING")


# ---- 退出确认：默认焦点在取消，点取消不退出。 ----

func _test_quit_confirm_mouse() -> void:
	GameManager.state = GameManager.GameState.MENU
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	await _frames(6)
	var menu := get_tree().current_scene
	var quit := _find_text(_buttons(menu), "退出游戏")
	await _click(quit)
	await _frames(4)
	_check_min_font(menu, "quit confirm")
	var buttons := _buttons(menu)
	var cancel := _find_text(buttons, "取消")
	var yes := _find_text(buttons, "退出")
	_check(cancel != null and yes != null, "quit confirmation offers cancel + confirm")
	var focus := menu.get_viewport().gui_get_focus_owner()
	_check(focus != null and focus is Button and (focus as Button).text.contains("取消"),
		"quit confirmation defaults focus to CANCEL")
	_check(GameManager.state == GameManager.GameState.MENU, "confirm does not change state")
	await _click(cancel)
	await _frames(4)
	_check(_find_text(_buttons(menu), "开始游戏") != null,
		"cancel closes the confirmation and returns to the menu")
	_check(GameManager.state == GameManager.GameState.MENU, "still in MENU after cancel")
	# 真正点“退出”：只有带 quit-smoke 参数时才做（进程应当当场结束）。
	if OS.get_cmdline_user_args().has("quit-smoke"):
		await _click(_find_text(_buttons(menu), "退出游戏"))
		await _frames(4)
		var confirm := _find_exact(_buttons(menu), "退出")
		_check(confirm != null, "quit smoke: confirmation has an exact QUIT button")
		print("QUIT SMOKE: clicking QUIT, process should exit with code 0")
		await _click(confirm)
		await _frames(3)
		_check(false, "quit smoke: still alive after confirming QUIT (no-op)")


# ---- 设置页：点语言按钮立即切换，点返回回主菜单。 ----

func _test_settings_mouse() -> void:
	var menu := get_tree().current_scene
	var settings := _find_text(_buttons(menu), "设置")
	await _click(settings)
	await _frames(4)
	_check_min_font(menu, "settings")
	_check(_find_text(_buttons(menu), "简体中文") != null
		or _find_text(_buttons(menu), "LANGUAGE") != null,
		"settings shows a language button")
	var lang := _find_text(_buttons(menu), "简体中文")
	var before := Locale.language
	await _click(lang)
	await _frames(4)
	_check(Locale.language != before, "mouse click on language button switches language")
	_check(_read(SETTINGS_PATH).contains(Locale.language),
		"language choice persisted after menu click")
	# 切回中文再返回，主菜单标题应跟着变。
	Locale.set_language("zh")
	await _frames(3)
	var back := _find_text(_buttons(menu), "返回")
	_check(back != null, "settings has a back button")
	await _click(back)
	await _frames(3)
	_check(_find_text(_buttons(menu), "开始游戏") != null, "back returns to main menu")


# ---- 暂停菜单：三个按钮都能点，且各自有可见结果。 ----

func _test_pause_menu_mouse() -> void:
	GameManager.start_race()
	await _frames(6)
	var race := get_tree().current_scene
	race.test_disable_hazards = true
	GameManager.toggle_pause()
	await _frames(4)
	var buttons := _buttons(race)
	await _shot("pause-zh")
	_check_min_font(race, "pause")
	_check(_find_text(buttons, "继续") != null, "pause menu shows CONTINUE")
	_check(_find_text(buttons, "重新开始") != null, "pause menu shows RESTART")
	_check(_find_text(buttons, "主菜单") != null, "pause menu shows MAIN MENU")
	await _click(_find_text(buttons, "继续"))
	await _frames(4)
	_check(GameManager.state == GameManager.GameState.RUNNING,
		"mouse click on CONTINUE resumes the race")
	# 重新开始：暂停后点重开，场景换了、时间归零、仍在跑。
	GameManager.toggle_pause()
	await _frames(4)
	await _click(_find_text(_buttons(race), "重新开始"))
	await _frames(6)
	var race2 := get_tree().current_scene
	_check(race2.scene_file_path.ends_with("race.tscn"), "restart reloads the race")
	_check(GameManager.state == GameManager.GameState.RUNNING and GameManager.race_time < 1.0,
		"restart resets the run")
	# 返回主菜单。
	race2.test_disable_hazards = true
	GameManager.toggle_pause()
	await _frames(4)
	await _click(_find_text(_buttons(race2), "主菜单"))
	await _frames(6)
	_check(_scene_is("menu.tscn"), "mouse click on MAIN MENU returns to the menu")
	_check(GameManager.state == GameManager.GameState.MENU, "state MENU after leaving")


# ---- 结算页：两个按钮都能点。 ----

func _test_result_mouse() -> void:
	GameManager.state = GameManager.GameState.RESULT
	GameManager.grade = "A"
	GameManager.total_score = 9000
	GameManager.finish_time = 250.0
	get_tree().change_scene_to_file("res://scenes/result.tscn")
	await _frames(6)
	var result := get_tree().current_scene
	await _shot("result-zh")
	_check_min_font(result, "result")
	var again := _find_text(_buttons(result), "再玩一次")
	var menu := _find_text(_buttons(result), "主菜单")
	_check(again != null and menu != null, "result shows PLAY AGAIN + MAIN MENU buttons")
	await _click(again)
	await _frames(6)
	_check(_scene_is("race.tscn"), "mouse click on PLAY AGAIN starts a race")
	GameManager.toggle_pause()
	await _frames(3)
	var race := get_tree().current_scene
	race.test_disable_hazards = true
	await _click(_find_text(_buttons(race), "主菜单"))
	await _frames(6)
	GameManager.state = GameManager.GameState.RESULT
	get_tree().change_scene_to_file("res://scenes/result.tscn")
	await _frames(6)
	result = get_tree().current_scene
	await _click(_find_text(_buttons(result), "主菜单"))
	await _frames(6)
	_check(_scene_is("menu.tscn"), "mouse click on MAIN MENU from result returns to menu")


# ---- 键盘：焦点可见、方向键移动、Enter 触发。 ----

func _test_keyboard_focus() -> void:
	GameManager.story_seen = true
	GameManager.tutorial_done = true
	GameManager.state = GameManager.GameState.MENU
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	await _frames(6)
	var menu := get_tree().current_scene
	var focus: Control = menu.get_viewport().gui_get_focus_owner()
	_check(focus is Button, "a button holds keyboard focus on entry")
	var first_text: String = (focus as Button).text if focus is Button else ""
	focus.set("ui_accept_disabled", false)
	await _press(KEY_DOWN)
	await _frames(2)
	var moved: Control = menu.get_viewport().gui_get_focus_owner()
	_check(moved is Button and (moved as Button) != focus,
		"DOWN moves focus to another button")
	await _press(KEY_UP)
	await _frames(2)
	_check(menu.get_viewport().gui_get_focus_owner() == focus,
		"UP returns focus (%s)" % first_text)
	# Space 也能确认：焦点在“开始游戏”时按下应进比赛。
	await _press(KEY_SPACE)
	await _frames(6)
	_check(_scene_is("race.tscn"), "SPACE activates the focused button")
	_check(_scene_is("race.tscn"), "race scene is live after keyboard start")
	# Enter 也映射到 ui_accept：回主菜单再确认一次。
	GameManager.state = GameManager.GameState.MENU
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	await _frames(6)
	await _press(KEY_ENTER)
	await _frames(6)
	_check(_scene_is("race.tscn"), "ENTER activates the focused button")


# ---- 工具 ----

func _buttons(root: Node) -> Array[Button]:
	var out: Array[Button] = []
	for node in root.find_children("*", "Button", true, false):
		var b := node as Button
		if b.visible:
			out.append(b)
	return out


func _find_text(buttons: Array[Button], needle: String) -> Button:
	for b in buttons:
		if b.text.contains(needle):
			return b
	return null


func _has_text(buttons: Array[Button], needle: String) -> bool:
	return _find_text(buttons, needle) != null


func _find_exact(buttons: Array[Button], text: String) -> Button:
	for b in buttons:
		if b.text == text:
			return b
	return null


func _click(button: Button) -> void:
	if button == null:
		_check(false, "click target missing")
		return
	var c: Vector2 = button.get_global_rect().get_center() * _scale
	print("    click '%s' at %s (viewport %s)" % [button.text, c,
		get_viewport().get_visible_rect().size])
	var move := InputEventMouseMotion.new()
	move.position = c
	move.global_position = c
	get_tree().root.push_input(move)
	await get_tree().process_frame
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = c
		e.global_position = c
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		get_tree().root.push_input(e)
		await get_tree().process_frame


func _press(keycode: Key) -> void:
	_send_key(keycode, true)
	await get_tree().process_frame
	_send_key(keycode, false)
	await get_tree().process_frame


func _send_key(keycode: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.physical_keycode = keycode
	e.pressed = pressed
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## 窗口化截图：报告里的“菜单 / 暂停 / 结算”证据。
func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(
		"res://docs/reports/logs/phase-t/ui-%s.png" % name))


func _visible_labels(root: Node) -> Array:
	var out := []
	if (root is Label or root is Button) and root.is_visible_in_tree():
		out.append(root)
	for child in root.get_children():
		out.append_array(_visible_labels(child))
	return out


## §六：1280×720 下最小实际字号不得低于 14.4 px（设计 18 px × 0.8）。
func _check_min_font(root: Node, tag: String) -> void:
	var min_design := 9999.0
	var min_text := ""
	for c in _visible_labels(root):
		var text := String(c.text).strip_edges()
		if text == "":
			continue
		var fs := float(c.get_theme_font_size("font_size"))
		if fs < min_design:
			min_design = fs
			min_text = text.substr(0, 28)
	var actual := snappedf(min_design * _scale, 0.1)
	_check(min_design >= 18.0 and actual >= 14.4,
		"%s min font %.0f design = %.1f actual (%s)" % [
			tag, min_design, actual, min_text])


func _scene_is(name: String) -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.ends_with(name)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok  " + message)
	else:
		failures.append(message)
		print("  FAIL " + message)


func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _backup(path: String) -> Dictionary:
	return {"exists": FileAccess.file_exists(path), "text": _read(path)}


func _restore(path: String, info: Dictionary) -> void:
	if info.get("exists", false):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(info["text"])
			file.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
