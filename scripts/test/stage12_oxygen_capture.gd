extends Node
## FEEL-12 E：三颗氧气气泡的关键截图（满/中/低/耗尽）。
## 运行（窗口化）：Godot --path . res://scenes/stage12_oxygen_capture.tscn

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
	race.test_disable_hazards = true
	race.test_no_lessons = true
	race.turtle.position = Vector2(2000.0, race.surface_ref())
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race._update_camera()
	race._update_dock()
	var dir := ProjectSettings.globalize_path("res://docs/reports/longrun/feel12")
	DirAccess.make_dir_recursive_absolute(dir)
	var shots := [["oxygen-full", 8.0], ["oxygen-mid", 4.0],
		["oxygen-low", 1.2], ["oxygen-empty", 0.0]]
	for s in shots:
		GameManager.oxygen = float(s[1])
		race.queue_redraw()
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			dir.path_join(String(s[0]) + ".png"))
		print("CAPTURE ", s[0])
	get_tree().quit(0)
