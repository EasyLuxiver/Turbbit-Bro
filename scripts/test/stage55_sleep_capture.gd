extends Node
## PHASE-SLEEP：走神预兆/漏电截图（窗口模式）。

var is_runner := false
var race: Node
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
	GameManager.start_race()
	for i in 8:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.hazard_groups = []
	race.test_no_mischief = false
	GameManager.current_control = "rabbit"
	race.turtle.position = Vector2(400.0, race.surface_ref())
	race.rabbit.position = race.turtle.get_mount_point()
	race.camera.position = Vector2(400.0, 450.0)
	race._sleep = {"rabbit": 0.0, "turtle": 100.0}
	race._sleep_event_role = ""
	race._sleep_phase = ""
	race._sleep_cd = 0.0
	race._tick_sleep(0.01)
	race.queue_redraw()
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("sleep_telegraph.png"))
	print("CAPTURE sleep_telegraph")
	race._tick_sleep(0.66)
	race.queue_redraw()
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("sleep_zap.png"))
	print("CAPTURE sleep_zap")
	print("SLEEP CAPTURE: DONE")
	get_tree().quit(0)
