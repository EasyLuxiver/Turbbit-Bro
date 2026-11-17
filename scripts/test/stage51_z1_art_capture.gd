extends Node
## PHASE-ART：Z1 室外码头背景 + 玩法水柱的截图探针（窗口模式）。

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
	for x in [400.0, 1800.0, 3600.0, 8000.0, 10200.0]:
		race.turtle.position = Vector2(x, race.surface_ref())
		race.rabbit.position = race.turtle.get_mount_point()
		race.camera.position = Vector2(x, 450.0)
		race._update_dock()
		race.queue_redraw()
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = dir.path_join("z1_art_%d.png" % int(x))
		get_viewport().get_texture().get_image().save_png(path)
		print("CAPTURE ", path)
	print("Z1 ART CAPTURE: DONE")
	get_tree().quit(0)
