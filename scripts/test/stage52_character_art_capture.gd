extends Node
## PHASE-ART：把制作人给的兔子/乌龟合照放进 Z1 场景里看比例与风格。

var is_runner := false
var race: Node
var pair: Sprite2D
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
	race.test_no_control_ring = true
	race.test_no_gameplay_draw = true
	# 只看新角色与背景；隐藏灰盒角色和 HUD。
	race.rabbit.visible = false
	race.turtle.visible = false
	if race.hud != null:
		race.hud.visible = false
	pair = Sprite2D.new()
	pair.texture = load("res://assets/art/characters_pair.png")
	pair.centered = false
	pair.scale = Vector2(0.8, 0.8)
	pair.z_index = 20
	race.add_child(pair)
	for x in [400.0, 1800.0]:
		race.camera.position = Vector2(x, 450.0)
		race.turtle.position = Vector2(x, race.surface_ref())
		# 以合照中心对准角色位置，脚底压在水线上。
		pair.position = Vector2(x - 250.0 * 0.8 * 0.5,
			race.surface_ref() - 300.0 * 0.8 + 10.0)
		race._update_dock()
		race.queue_redraw()
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = dir.path_join("char_pair_scene_%d.png" % int(x))
		get_viewport().get_texture().get_image().save_png(path)
		print("CAPTURE ", path)
	print("CHAR PAIR CAPTURE: DONE")
	get_tree().quit(0)
