extends Node
## FEEL-15：正常骑乘隐藏 / 水下显示氧气气泡的实际截图。

const OUT := "res://docs/reports/longrun/feel15"
var is_runner := false
var race: Node


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
	GameManager.test_no_best = true
	GameManager.start_race()
	for i in 5:
		await get_tree().process_frame
	race = get_tree().current_scene
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = true
	race.test_no_finish = true
	race.load_level([], [])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# 正常骑乘：隐藏
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	race.turtle.reset(Vector2(2000.0, race.surface_ref()))
	race.mount.reset()
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.mark_riding()
	GameManager.accident_state = "NONE"
	GameManager.oxygen = 8.0
	print("DBG riding visible=", race.oxygen_bubbles_visible(),
		" mount=", race.mount.state, " rabbit=", race.rabbit.state,
		" accident=", GameManager.accident_state)
	race._update_camera()
	race.queue_redraw()
	await _frames(3)
	await _save("oxygen-riding-hidden.png")
	# 水下：显示
	GameManager.accident_state = "RABBIT_WATER"
	race.rabbit.reset()
	race.rabbit.position = Vector2(2100.0, race.surface_ref() + 128.0)
	race.rabbit.state = "FALLING_WATER"
	race.mount.mark_rescue_active(3.2)
	GameManager.oxygen = 6.0
	race._update_camera()
	race.queue_redraw()
	await _frames(3)
	await _save("oxygen-underwater-visible.png")
	print("OXYGEN CAPTURE: PASS")
	get_tree().quit(0)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var p := ProjectSettings.globalize_path(OUT).path_join(name)
	get_viewport().get_texture().get_image().save_png(p)
	print("CAPTURE ", p)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
