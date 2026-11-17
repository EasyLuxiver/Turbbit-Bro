extends Node
## FEEL-12 补充 B：CARROT GUARD / BRO CATCH 实际画面。
## 需要窗口化运行。

const LevelData = preload("res://scripts/systems/level_data.gd")
var is_runner := false


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
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	var race := get_tree().current_scene
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = false
	race.test_no_lessons = true
	race.test_no_overdrive = true
	var dir := ProjectSettings.globalize_path("res://docs/reports/longrun/feel12")
	DirAccess.make_dir_recursive_absolute(dir)
	# GUARD：TUBO 在低梁前展开胡萝卜盾。
	var g := LevelData.build_group({"group": "cap_beam", "zone": 1,
		"kind": "LOW_BEAM", "x": 2000.0, "w": 170.0})
	race.load_level([g], [])
	race.turtle.reset(Vector2(1930.0, race.surface_ref()))
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race._guard_t = 0.6
	race._guard_age = 0.03
	race._update_camera()
	race.queue_redraw()
	await _frames(3)
	_save(dir, "carrot-guard.png")
	# CATCH：BITT 主动冲向水里的 TUBO。
	race._guard_t = 0.0
	race.load_level([], [])
	race.turtle.reset(Vector2(1900.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.position = Vector2(2250.0, race.surface_ref() + 110.0)
	race.rabbit.state = "FALLING_WATER"
	race.mount.mark_rescue_active(5.0)
	GameManager.accident_state = "RABBIT_WATER"
	GameManager.current_control = "turtle"
	race._catch_active = true
	race._catch_t = 1.25
	race._catch_fx_t = 0.2
	race._update_camera()
	race.queue_redraw()
	await _frames(2)
	_save(dir, "bro-catch.png")
	get_tree().quit(0)


func _save(dir: String, name: String) -> void:
	get_viewport().get_texture().get_image().save_png(dir.path_join(name))
	print("CAPTURE ", name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
