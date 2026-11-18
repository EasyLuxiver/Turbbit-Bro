extends Node
## PHASE-SLEEP：Q 弹碰撞截图探针（窗口模式）。

const LevelData = preload("res://scripts/systems/level_data.gd")

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
	var groups := [
		LevelData.build_group({"group": "gate_test", "zone": 1,
			"kind": "DIVE_GATE", "x": 2000.0, "w": 180.0}),
	]
	race.load_level(groups, [])
	race.turtle.position = Vector2(1950.0, race.surface_ref())
	race.rabbit.position = race.turtle.get_mount_point()
	race.camera.position = Vector2(1950.0, 330.0)
	race.camera.zoom = Vector2(1.8, 1.8)
	if race.hud != null:
		race.hud.visible = false
	race._bounce_cd = 0.0
	race._bonk_streak = 0
	race._turtle_contact("gate_test", "DIVE_GATE", true)
	var frames := [0.0, 0.10, 0.22, 0.40]
	var t := 0.0
	for f in frames:
		while t < f:
			race._tick_bonk_anim(1.0 / 60.0)
			t += 1.0 / 60.0
		race.queue_redraw()
		for i in 2:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = dir.path_join("qbounce_%02d.png" % int(f * 100.0))
		get_viewport().get_texture().get_image().save_png(path)
		print("CAPTURE ", path)
	print("QBOUNCE CAPTURE: DONE")
	get_tree().quit(0)
