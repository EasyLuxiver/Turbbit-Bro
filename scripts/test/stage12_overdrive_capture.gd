extends Node
## FEEL-12：BRO OVERDRIVE 视觉证据（无全局慢镜头，仅电击/残影/夸张动作）。
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
	race.set_process(false)
	race.opening_active = false
	race.test_disable_hazards = true
	race.test_no_lessons = true
	var dir := ProjectSettings.globalize_path("res://docs/reports/longrun/feel12")
	DirAccess.make_dir_recursive_absolute(dir)
	# TUBO spring
	race.turtle.reset(Vector2(2000.0, race.surface_ref()))
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset(); race.mount.mark_riding()
	race._update_camera()
	GameManager.current_control = "rabbit"
	race.rabbit_brain.drift = 12.0
	race.rabbit.drift = 12.0
	race._od_phase = ""; race._od_cd = 0.0
	race._tick_overdrive(1.0 / 60.0)
	GameManager.toggle_control()  # -> BITT, triggers overdrive
	race._physics_process(1.0 / 60.0)
	race.queue_redraw()
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("overdrive-tubo.png"))
	# BITT shell
	race.turtle.reset(Vector2(2000.0, race.surface_ref()))
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset(); race.mount.mark_riding()
	race._update_camera()
	GameManager.current_control = "turtle"
	race.turtle_brain.drift = 12.0
	race.turtle.drift = 12.0
	race._od_phase = ""; race._od_cd = 0.0; race._od_emphasis_t = 0.0
	race._tick_overdrive(1.0 / 60.0)
	GameManager.toggle_control()  # -> TUBO
	race._physics_process(1.0 / 60.0)
	race.queue_redraw()
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("overdrive-bitt.png"))
	print("CAPTURE overdrive")
	get_tree().quit(0)
