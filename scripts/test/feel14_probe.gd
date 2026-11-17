extends Node
## FEEL-14 制作人试玩快捷入口（不在玩家菜单里；只用于准备试玩）。
## 运行示例：
##   Godot --path . res://scenes/feel14_probe.tscn -- --z3
##   Godot --path . res://scenes/feel14_probe.tscn -- --catch-front
##   Godot --path . res://scenes/feel14_probe.tscn -- --catch-back
##   Godot --path . res://scenes/feel14_probe.tscn -- --guard
## 不改 55 组/角色能力/键位；只把当前 race 的状态摆到指定测试起点。

var is_runner := false
var race: Node
var _label: Label


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
	var args := OS.get_cmdline_user_args()
	GameManager.test_no_best = true
	GameManager.start_race()
	for i in 5:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("FEEL14: no race")
		get_tree().quit(1)
		return
	race.opening_active = false
	race.test_no_finish = true
	race.test_no_lessons = true
	var mode := "run"
	if args.has("--z3"):
		mode = "z3"
		_z3()
	elif args.has("--catch-front"):
		mode = "catch-front"
		_catch(320.0)
	elif args.has("--catch-back"):
		mode = "catch-back"
		_catch(-240.0)
	elif args.has("--guard"):
		mode = "guard"
		_guard()
	else:
		# 没带参数时仍走正式比赛起点；不把玩家锁在调试入口。
		race.turtle.reset(Vector2(400.0, race.surface_ref()))
		race.rabbit.attach(race.turtle.get_mount_point())
		race.mount.reset()
		race.mount.mark_riding()
		GameManager.current_control = "rabbit"
	_build_label(mode)
	race._update_camera()
	if args.has("--check"):
		await RenderingServer.frame_post_draw
		var dir := ProjectSettings.globalize_path("res://docs/reports/longrun/feel14")
		DirAccess.make_dir_recursive_absolute(dir)
		get_viewport().get_texture().get_image().save_png(
			dir.path_join("probe-%s.png" % mode))
		print("FEEL14 PROBE mode=%s turtle=%s rabbit=%s control=%s mount=%s" % [
			mode, str(race.turtle.position), str(race.rabbit.position),
			GameManager.current_control, String(race.mount.state)])
		print("FEEL14 PROBE: PASS")
		get_tree().quit(0)


func _z3() -> void:
	race.turtle.reset(Vector2(52000.0, race.surface_ref()))
	race.turtle.speed = 260.0
	race.turtle.base_speed = 260.0
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	GameManager.current_control = "rabbit"


func _catch(dx: float) -> void:
	race.test_no_overdrive = true
	race.test_disable_hazards = true
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.turtle.speed = 220.0
	race.turtle.base_speed = 220.0
	race.rabbit.reset()
	race.rabbit.position = Vector2(900.0 + dx, race.surface_ref() + 120.0)
	race.rabbit.state = "FALLING_WATER"
	race.mount.mark_rescue_active(5.0)
	GameManager.accident_state = "RABBIT_WATER"
	GameManager.current_control = "turtle"
	GameManager.shift_lock_t = 0.0
	race._catch_active = false
	race._catch_t = 0.0
	race.rescue_prev_pos = race.rabbit.position


func _guard() -> void:
	race.test_no_overdrive = true
	var beam := {"group": "feel14_guard_beam", "zone": 1,
		"kind": "LOW_BEAM", "x": 1500.0, "w": 170.0}
	var LevelData = preload("res://scripts/systems/level_data.gd")
	race.load_level([LevelData.build_group(beam)], [])
	race.turtle.reset(Vector2(950.0, race.surface_ref()))
	race.turtle.speed = 220.0
	race.turtle.base_speed = 220.0
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	GameManager.current_control = "rabbit"


func _build_label(mode: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(32, 150)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(1, 0.95, 0.65))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.text = _hint(mode)
	layer.add_child(_label)


func _hint(mode: String) -> String:
	match mode:
		"z3":
			return "FEEL-14 Z3 快速起点 · G43–G55 · 正式 55 组，不改数值"
		"catch-front":
			return "FEEL-14 救援练习（前方）· 按 SPACE 让 BITT 主动救援"
		"catch-back":
			return "FEEL-14 救援练习（后方）· 按 SPACE 让 BITT 主动救援"
		"guard":
			return "FEEL-14 护盾练习 · 低梁前按 SPACE 试 TUBO 胡萝卜护盾"
		_:
			return "FEEL-14 试玩入口 · 正式起点"
