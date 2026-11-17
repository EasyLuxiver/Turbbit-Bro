extends Node
## FEEL-11 B4：60–90 秒 SHIFT 实验室。
##
## 直线巡航 → 兔子跳 → 乌龟潜 → 两种动作之间切换 → 组合障碍 → 救援/接管。
## 正式物理/输入/HUD；R 重置，J 演示一次兔子落水，F10 回制作人菜单。
## 不写正式 best.json。

const LevelData = preload("res://scripts/systems/level_data.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var race: Node
var _status: Label
var _log: Label
var _reloading := false


func _ready() -> void:
	GameManager.test_no_best = true
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.current_control = "rabbit"
	race = load("res://scenes/race.tscn").instantiate()
	add_child(race)
	await get_tree().process_frame
	await get_tree().process_frame
	race.opening_active = false
	race.test_no_finish = true
	race.test_no_coop_hint = true
	race.test_no_lessons = true
	race.test_disable_hazards = false
	race.world_end = 12000.0
	var specs := [
		{"group": "lab_rock1", "zone": 1, "kind": "SURFACE_ROCK", "x": 1300.0, "w": 120.0},
		{"group": "lab_gate1", "zone": 1, "kind": "DIVE_GATE", "x": 2100.0, "w": 180.0},
		{"group": "lab_log1", "zone": 1, "kind": "FLOATING_LOG", "x": 3100.0, "w": 32.0},
		{"group": "lab_beam1", "zone": 1, "kind": "LOW_BEAM", "x": 4100.0, "w": 170.0},
		{"group": "lab_shark1", "zone": 1, "kind": "SHARK", "x": 5000.0, "w": 70.0},
		{"group": "lab_log2", "zone": 1, "kind": "FLOATING_LOG", "x": 6300.0, "w": 32.0},
		{"group": "lab_gate2", "zone": 1, "kind": "DIVE_GATE", "x": 7400.0, "w": 180.0},
		{"group": "lab_wall1", "zone": 1, "kind": "HIGH_WALL", "x": 8500.0, "w": 30.0},
		{"group": "lab_log3", "zone": 1, "kind": "FLOATING_LOG", "x": 9800.0, "w": 32.0},
		{"group": "lab_shark2", "zone": 1, "kind": "SHARK", "x": 10900.0, "w": 70.0},
	]
	var groups := []
	for s in specs:
		groups.append(LevelData.build_group(s))
	race.load_level(groups, [])
	race.world_end = 12000.0
	race.turtle.reset(Vector2(400.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	_build_overlay()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()
	elif "--capture-relay" in OS.get_cmdline_user_args():
		_capture_relay.call_deferred()


func _process(_delta: float) -> void:
	if race == null or _status == null:
		return
	var r := {}
	if not race.relay_log.is_empty():
		r = race.relay_log[race.relay_log.size() - 1]
	_status.text = "控制 %s  ·  兔子 %s%s  ·  乌龟 %s y=%.0f" % [
		GameManager.current_control, String(race.rabbit.state),
		(" / 空中" if race.rabbit.is_airborne() else ""),
		String(race.turtle.state), float(race.turtle.position.y)]
	_log.text = "接力：%s   ·   分数 %d   ·   SHIFT 锁 %.2f s" % [
		("无" if r.is_empty() else "%s +%d" % [String(r.get("result", "")),
			int(r.get("score", 0))]), GameManager.total_score,
		float(GameManager.shift_lock_t)]


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(280, 18)
	panel.custom_minimum_size = Vector2(900, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(UiTheme.make_label("SHIFT 实验室  /  RELAY LAB", 24,
		UiTheme.GOLD))
	var body := UiTheme.make_label(
		"↑ 兔子跳  ↓ 兔子趴低  ·  SHIFT 换人  ·  乌龟 ↑ 跃起 / ↓ 下潜\n"
		+ "试试：兔子跳起来后 SHIFT 给乌龟下潜；乌龟潜着时 SHIFT 给兔子跳。\n"
		+ "R 重置   J 演示救援   O 演示电流过载   F10 内部菜单", 15,
		Color(0.85, 0.94, 1.0))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(body)
	_status = UiTheme.make_label("", 14, Color(0.55, 0.95, 0.9))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_status)
	_log = UiTheme.make_label("", 14, Color(1.0, 0.85, 0.4))
	_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_log)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_R:
			if not _reloading:
				_reloading = true
				get_tree().reload_current_scene.call_deferred()
			get_viewport().set_input_as_handled()
		KEY_F10:
			get_tree().change_scene_to_file("res://scenes/producer_menu.tscn")
			get_viewport().set_input_as_handled()
		KEY_J:
			# 手动演示“接管/救援”：不依赖自动驾驶。
			GameManager.accident_state = "NONE"
			race.hazard_cooldown = 0.0
			race._trigger_accident("RABBIT_WATER")
			get_viewport().set_input_as_handled()
		KEY_O:
			# 手动把当前角色推到电流过载；下一帧出现 0.3 s 预兆，按 SHIFT 触发 OVERDRIVE。
			var who: String = GameManager.current_control
			if who == "rabbit":
				race.rabbit_brain.drift = 12.0
				race.rabbit.drift = 12.0
			else:
				race.turtle_brain.drift = 12.0
				race.turtle.drift = 12.0
			GameManager.shift_lock_t = 0.0
			get_viewport().set_input_as_handled()


func _capture() -> void:
	await get_tree().create_timer(1.0).timeout
	var dir := ProjectSettings.globalize_path("res://docs/reports/longrun/feel11")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(
		dir.path_join("shift-lab.png"))
	print("CAPTURE shift lab")
	get_tree().quit(0)


func _capture_relay() -> void:
	await get_tree().create_timer(1.0).timeout
	var dir := ProjectSettings.globalize_path("res://docs/reports/longrun/feel11")
	DirAccess.make_dir_recursive_absolute(dir)
	race.rabbit.launch(race.turtle.get_mount_point(), race.turtle.speed)
	race.mount.mark_airborne()
	await get_tree().create_timer(0.10).timeout
	GameManager.toggle_control()
	Input.action_press("down")
	await get_tree().create_timer(0.06).timeout
	get_viewport().get_texture().get_image().save_png(
		dir.path_join("shift-shock.png"))
	await get_tree().create_timer(0.95).timeout
	get_viewport().get_texture().get_image().save_png(
		dir.path_join("shift-relay.png"))
	Input.action_release("down")
	print("CAPTURE shift relay")
	get_tree().quit(0)
