extends Node
## FEEL-15：浮标/木箱的 TUBO 跳跃路线与 BITT 碰撞反馈截图。

const LevelData = preload("res://scripts/systems/level_data.gd")
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
	race.test_disable_hazards = false
	var buoy := LevelData.build_group({"group": "cap_buoy", "zone": 1,
		"kind": "SURFACE_ROCK", "x": 1200.0, "w": 120.0, "identity": "buoy",
		"motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6}})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# TUBO 路线：站上壳跳起，画面同时有浮标与 TUBO。
	race.load_level([buoy], [])
	race.hazard_clock = 0.9
	race.turtle.reset(Vector2(1100.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.position = race.turtle.get_mount_point() + Vector2(0, -90)
	race.rabbit.state = "JUMPING"
	race.rabbit.velocity = Vector2(0, -80)
	race.mount.mark_airborne()
	race._update_camera()
	race.queue_redraw()
	await _frames(3)
	await _save("buoy-tubo-jump.png")
	# BITT 错误路线：浪峰压到壳，真实碰撞反馈。
	race.hazard_clock = 0.9
	race.turtle.reset(Vector2(1200.0, race.surface_ref()))
	race.turtle.speed = 240.0
	race.rabbit.reset()
	race.rabbit.state = "JUMPING"
	race.rabbit.velocity = Vector2(0, -120)
	race.rabbit.position = race.turtle.get_mount_point() + Vector2(0, -300)
	race.mount.mark_riding()
	race.hit_roles.clear()
	race.hit_groups.clear()
	GameManager.accident_state = "NONE"
	race.hazard_cooldown = 0.0
	race._check_hazards()
	race._update_camera()
	race.queue_redraw()
	await _frames(3)
	await _save("buoy-bitt-hit.png")
	print("BUOY CAPTURE: PASS")
	get_tree().quit(0)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var p := ProjectSettings.globalize_path(OUT).path_join(name)
	get_viewport().get_texture().get_image().save_png(p)
	print("CAPTURE ", p)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
