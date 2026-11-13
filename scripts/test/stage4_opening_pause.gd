extends Node
## 阶段 4 P2-7 验收（TBB-SHIFT-FEEL-03）：开场占位与暂停菜单。
##
## 真实 race.tscn + 真实时间（不开 time_scale）：
##   boot    —— 正式开局自动挂开场，状态仍是 RUNNING；
##   freeze  —— 开场期间比赛不推进（乌龟 x 不变，1.2 s 实测）；
##   skip    —— 任意键立即跳过，跳过比赛立刻恢复推进；
##   auto    —— 不按键 6 s 自动结束（5–8 s 窗口内）；
##   pause   —— Pause 显示 Take a breath, bro.，三个原生按钮齐全且可用；
##   restart —— 重新开始真的重载比赛；
##   menu    —— 返回主菜单真的回到 MENU。
##
## 全部是原生 Control / Label / Button 占位，不含任何新美术或音频素材。
##
## 运行：Godot_v4.7-stable_win64_console.exe --path TURBBIT \
##       res://scenes/stage4_opening_pause.tscn -- --force-opening
## 输出：docs/reports/longrun/phase-v-opening-pause.json

const OUT_PATH := "res://docs/reports/longrun/phase-v-opening-pause.json"
const BREATH := "Take a breath, bro."

var is_runner := false
var race
var rows: Array = []
var failures: Array[String] = []


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4OpeningPauseRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	await get_tree().process_frame
	await _run()


func _run() -> void:
	GameManager.start_race()
	await _frames(6)
	race = get_tree().current_scene
	if race == null or not race.has_method("on_opening_finished"):
		_check(false, "formal race scene loaded")
		_finish()
		return
	race.test_no_finish = true
	race.test_disable_hazards = true

	rows.append(await _case_boot())
	rows.append(await _case_freeze())
	rows.append(await _case_skip())
	rows.append(await _case_auto_end())
	rows.append(await _case_pause())
	rows.append(await _case_restart())
	rows.append(await _case_menu())

	_write_json()
	_finish()


# ---------------- 用例 ----------------

func _case_boot() -> Dictionary:
	var checks := {
		"opening_auto_hooked": race.opening_active and race.opening != null,
		"state_running": GameManager.state == GameManager.GameState.RUNNING,
		"duration_in_5_to_8": race.opening != null \
			and race.opening.OPENING_TIME >= 5.0 and race.opening.OPENING_TIME <= 8.0,
		"native_controls_only": _count_nodes(race.opening, "TextureRect") == 0,
		"title_visible": _contains_label(race.opening, Locale.t("menu.title")),
		"skip_hint_visible": _contains_label(race.opening, Locale.t("opening.skip")),
	}
	var data := {
		"opening_time": race.opening.OPENING_TIME if race.opening != null else -1.0,
		"scene": race.get_scene_file_path(),
	}
	return _row("boot", checks, data)


func _case_freeze() -> Dictionary:
	var x0: float = race.turtle.position.x
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(1.2).timeout
	var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
	var x1: float = race.turtle.position.x
	var checks := {
		"still_open": race.opening_active,
		"waited_at_least_1s": elapsed >= 1.0,
		"turtle_frozen": absf(x1 - x0) < 0.01,
		"no_input_buffered": race._buf_action == "",
	}
	return _row("freeze", checks, {
		"elapsed_s": snappedf(elapsed, 0.01),
		"x_before": snappedf(x0, 0.1), "x_after": snappedf(x1, 0.1),
	})


func _case_skip() -> Dictionary:
	var x0: float = race.turtle.position.x
	_send_key(KEY_SPACE)
	await _frames(3)
	var closed: bool = not race.opening_active
	var x_at_close: float = race.turtle.position.x
	await get_tree().create_timer(0.4).timeout
	var x_after: float = race.turtle.position.x
	var checks := {
		"one_key_closes": closed,
		"race_resumes": x_after > x_at_close + 1.0,
		"closes_in_under_0_5s": absf(x_at_close - x0) < 40.0,
	}
	return _row("skip", checks, {
		"x_before": snappedf(x0, 0.1), "x_at_close": snappedf(x_at_close, 0.1),
		"x_after": snappedf(x_after, 0.1),
	})


func _case_auto_end() -> Dictionary:
	race._start_opening()
	await _frames(2)
	var reopened: bool = race.opening_active
	var x0: float = race.turtle.position.x
	var t0 := Time.get_ticks_msec()
	# headless 可能不限帧率：按真实时钟等，不按帧数等（_process 的 delta 是实时）。
	await get_tree().create_timer(5.2).timeout
	var still_open_at_5_2: bool = race.opening_active
	var frozen_while_open: bool = absf(race.turtle.position.x - x0) < 0.01 if reopened else false
	while race.opening_active and Time.get_ticks_msec() - t0 < 8200:
		await get_tree().process_frame
	var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
	var checks := {
		"reopened": reopened,
		"frozen_while_open": frozen_while_open,
		"still_open_after_5_2s": still_open_at_5_2,
		"auto_closed": not race.opening_active,
		"closed_between_5_and_8s": elapsed >= 5.0 and elapsed <= 8.2,
	}
	return _row("auto", checks, {
		"elapsed_s": snappedf(elapsed, 0.01),
	})


func _case_pause() -> Dictionary:
	GameManager.toggle_pause()
	await _frames(3)
	var menu = race.get_node_or_null("PauseLayer/PauseMenu")
	var labels := _labels(menu)
	var buttons := _buttons(menu)
	var checks := {
		"paused": GameManager.state == GameManager.GameState.PAUSED,
		"menu_visible": menu != null and menu.visible,
		"breath_text": BREATH in labels,
		"title_text": Locale.t("pause.title") in labels,
		"three_buttons": buttons.size() == 3,
		"buttons_labeled": buttons.size() == 3 \
			and buttons[0].text == Locale.t("pause.resume") \
			and buttons[1].text == Locale.t("pause.restart") \
			and buttons[2].text == Locale.t("pause.menu"),
		"native_controls_only": _count_nodes(menu, "TextureRect") == 0,
	}
	# 继续按钮真的能恢复。
	var resumed_ok := false
	if buttons.size() == 3:
		buttons[0].pressed.emit()
		await _frames(3)
		resumed_ok = GameManager.state == GameManager.GameState.RUNNING \
			and not menu.visible
	checks["resume_works"] = resumed_ok
	var row := _row("pause", checks, {
		"labels": labels, "buttons": _button_texts(buttons),
	})
	return row


func _case_restart() -> Dictionary:
	GameManager.toggle_pause()
	await _frames(3)
	var menu = race.get_node_or_null("PauseLayer/PauseMenu")
	var buttons := _buttons(menu)
	if buttons.size() != 3:
		return _row("restart", {"buttons_present": false}, {})
	var old_id: int = race.get_instance_id()
	buttons[1].pressed.emit()
	await _frames(8)
	race = get_tree().current_scene
	var checks := {
		"scene_reloaded": race != null and race.get_instance_id() != old_id,
		"is_race_scene": race != null \
			and race.get_scene_file_path().ends_with("race.tscn"),
		"state_running": GameManager.state == GameManager.GameState.RUNNING,
	}
	# 重开时 --force-opening 会再挂一次开场：用按键关掉，顺带再验一次跳过路径。
	if race != null and race.opening_active:
		_send_key(KEY_ENTER)
		await _frames(3)
	checks["opening_skip_again"] = race != null and not race.opening_active
	return _row("restart", checks, {
		"scene": race.get_scene_file_path() if race != null else "",
	})


func _case_menu() -> Dictionary:
	GameManager.toggle_pause()
	await _frames(3)
	var menu = race.get_node_or_null("PauseLayer/PauseMenu")
	var buttons := _buttons(menu)
	if buttons.size() != 3:
		return _row("menu", {"buttons_present": false}, {})
	buttons[2].pressed.emit()
	await _frames(8)
	var scene := get_tree().current_scene
	var checks := {
		"state_menu": GameManager.state == GameManager.GameState.MENU,
		"menu_scene_loaded": scene != null \
			and scene.get_scene_file_path().ends_with("menu.tscn"),
	}
	return _row("menu", checks, {
		"scene": scene.get_scene_file_path() if scene != null else "",
	})


# ---------------- 工具 ----------------

func _send_key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _labels(node) -> Array:
	var out: Array = []
	_collect(node, "Label", out, "text")
	return out


func _buttons(node) -> Array:
	var out: Array = []
	_collect(node, "Button", out, "self")
	return out


func _collect(node, cls: String, out: Array, field: String) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child.is_class(cls):
			out.append(child.text if field == "text" else child)
		_collect(child, cls, out, field)


func _button_texts(buttons: Array) -> Array:
	var out: Array = []
	for b in buttons:
		out.append(b.text)
	return out


func _contains_label(node, text: String) -> bool:
	return text in _labels(node)


func _count_nodes(node, cls: String) -> int:
	if node == null:
		return 0
	var n := 0
	for child in node.get_children():
		if child.is_class(cls):
			n += 1
		n += _count_nodes(child, cls)
	return n


func _row(name: String, checks: Dictionary, data: Dictionary) -> Dictionary:
	var ok := true
	for k in checks:
		if not bool(checks[k]):
			ok = false
			_check(false, "%s: %s" % [name, k])
	var row := {"case": name, "checks": checks, "pass": ok}
	for k in data:
		row[k] = data[k]
	print("OPENING/PAUSE %-8s pass=%s %s" % [name, str(ok), str(checks)])
	return row


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


func _write_json() -> void:
	var data := {
		"generated_at": Time.get_datetime_string_from_system(),
		"note": "P2-7 opening/pause: native Controls only, real time, real scene changes.",
		"opening_time_s": 6.0,
		"rows": rows,
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _finish() -> void:
	if failures.is_empty():
		print("STAGE4 OPENING/PAUSE: PASS")
	else:
		print("STAGE4 OPENING/PAUSE: FAIL")
		for item in failures:
			print("  - " + item)
	get_tree().quit(0 if failures.is_empty() else 1)
