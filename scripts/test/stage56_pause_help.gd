extends Node
## PHASE-TEXT：暂停帮助分页。实际打开暂停菜单，逐页点击检查。

var is_runner := false
var race: Node
var pause: Node
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
	race.test_no_mischief = true
	GameManager.toggle_pause()
	for i in 4:
		await get_tree().process_frame
	pause = race.get_node_or_null("PauseLayer/PauseMenu")
	_check("pause_visible", pause != null and pause.visible,
		"pause=%s" % str(pause != null and pause.visible))
	if pause == null:
		_finish()
		return
	_check("page_one", pause._help_page_label.text == "1/7",
		pause._help_page_label.text)
	_check("page_one_text", pause._help_body.text == Locale.t("pause.help_page_1"),
		pause._help_body.text)
	_check("prev_disabled_first", pause._help_prev.disabled,
		str(pause._help_prev.disabled))
	_check("next_enabled_first", not pause._help_next.disabled,
		str(pause._help_next.disabled))
	await _shot("pause_help_1")
	for i in 6:
		pause._help_next.pressed.emit()
		await get_tree().process_frame
	_check("last_page", pause._help_page_label.text == "7/7",
		pause._help_page_label.text)
	_check("last_page_text", pause._help_body.text == Locale.t("pause.help_page_7"),
		pause._help_body.text)
	_check("next_disabled_last", pause._help_next.disabled,
		str(pause._help_next.disabled))
	_check("prev_enabled_last", not pause._help_prev.disabled,
		str(pause._help_prev.disabled))
	await _shot("pause_help_7")
	# 后退两页，确认页码和内容同步。
	pause._help_prev.pressed.emit()
	pause._help_prev.pressed.emit()
	await get_tree().process_frame
	_check("back_two", pause._help_page_label.text == "5/7"
		and pause._help_body.text == Locale.t("pause.help_page_5"),
		"%s %s" % [pause._help_page_label.text, pause._help_body.text])
	# 语言切换：分页保留，中英文一一对应。
	Locale.set_language("en")
	for i in 4:
		await get_tree().process_frame
	pause = race.get_node("PauseLayer/PauseMenu")
	_check("en_page_kept", pause._help_page_label.text == "5/7",
		pause._help_page_label.text)
	_check("en_text", pause._help_body.text == Locale.t("pause.help_page_5")
		and pause._help_body.text.contains("SEAWEED"),
		pause._help_body.text)
	await _shot("pause_help_5_en")
	Locale.set_language("zh")
	for i in 4:
		await get_tree().process_frame
	# 关闭暂停并恢复比赛。
	GameManager.toggle_pause()
	await get_tree().process_frame
	_check("resume_running", GameManager.state == GameManager.GameState.RUNNING
		and not race.get_node("PauseLayer/PauseMenu").visible,
		str(GameManager.state))
	_finish()


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


func _finish() -> void:
	print("STAGE56 PAUSE HELP: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)
