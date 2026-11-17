extends Node
## FEEL-10 P0-C 视觉证据：两个新动词各两个状态。
## 运行（窗口化，必须）：
##   D:/Godot_v4.7-stable_win64_console.exe --path D:/GAMESTUDIO/TURBBIT \
##       --resolution 1280x720 res://scenes/p0c_capture.tscn

const OUT_DIR := "res://docs/reports/longrun/feel10-p0c"

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
	Locale.set_language("zh")
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUT_DIR))
	await _shot_current("current-high-dive", 4.0)
	await _shot_current("current-low-jump", 0.5)
	await _shot_net("net-low-crouch", false)
	await _shot_net("net-high-turtle", true)
	get_tree().quit(0)


func _spawn(path: String) -> Node:
	var seg: Node = load(path).instantiate()
	add_child(seg)
	for i in 4:
		await get_tree().process_frame
	var race: Node = seg.race
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	return seg


func _pose(race: Node, x: float) -> void:
	race.turtle.position = Vector2(x, race.surface_ref())
	race.turtle.speed = 0.0
	race.rabbit.input_down = false
	race.rabbit.tick_riding(0.016, race.turtle.get_mount_point(), false,
		false, true)
	race.mount.reset()
	race.mount.mark_riding()
	race._update_camera()
	for i in 3:
		await get_tree().process_frame


func _save(race: Node, name: String) -> void:
	race.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ", path)


func _shot_current(name: String, clock: float) -> void:
	var seg: Node = await _spawn("res://scenes/p0c_current_test.tscn")
	var race: Node = seg.race
	var g: Dictionary = race.hazard_groups[0]
	race.hazard_clock = clock
	var gx: float = race._group_start(g)
	await _pose(race, gx - 250.0)
	await _save(race, name)
	seg.queue_free()
	await get_tree().process_frame


func _shot_net(name: String, raised: bool) -> void:
	var seg: Node = await _spawn("res://scenes/p0c_net_test.tscn")
	var race: Node = seg.race
	var g: Dictionary = race.hazard_groups[0]
	var gx: float = race._group_start(g)
	GameManager.current_control = "turtle" if raised else "rabbit"
	race._state_net_shift = -95.0 if raised else 0.0
	await _pose(race, gx - 250.0)
	await _save(race, name)
	seg.queue_free()
	await get_tree().process_frame
