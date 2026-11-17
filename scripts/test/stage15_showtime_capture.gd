extends Node
## FEEL-15：SHOWTIME 中 SHIFT 后表演继续的实际截图。

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
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.load_level([], [])
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	GameManager.current_control = "rabbit"
	GameManager.shift_lock_t = 0.0
	race.start_showtime()
	# 表演中 SHIFT 到 BITT：TUBO 继续转，BITT 可操作。
	GameManager.toggle_control()
	for i in 24:
		race._tick_showtime(1.0 / 60.0)
		race._update_camera()
		race.queue_redraw()
		await get_tree().process_frame
	await _save("showtime-shift-bitt.png")
	# 再 SHIFT 回 TUBO，表演仍继续，直到结束。
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	var guard := 0
	while race.showtime_active and guard < 300:
		race._tick_showtime(1.0 / 60.0)
		guard += 1
	race._update_camera()
	race.queue_redraw()
	await _frames(3)
	await _save("showtime-complete.png")
	print("SHOWTIME CAPTURE: PASS control=", GameManager.current_control,
		" active=", race.showtime_active)
	get_tree().quit(0)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var p := ProjectSettings.globalize_path(OUT).path_join(name)
	get_viewport().get_texture().get_image().save_png(p)
	print("CAPTURE ", p)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
