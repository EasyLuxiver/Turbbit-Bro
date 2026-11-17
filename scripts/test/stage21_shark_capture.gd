extends Node
## FEEL-21：shark6 鲨鱼群跟随攻击的实际画面。

const LevelData = preload("res://scripts/systems/level_data.gd")
const OUT := "res://docs/reports/longrun/feel21"
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
	race.test_disable_hazards = false
	var g := LevelData.build_group({"group": "shark6", "zone": 3, "kind": "SHARK",
		"x": 1100.0, "w": 70.0, "motion": {"name": "ambush_shark"}})
	race.load_level([g], [])
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race._ambush["shark6"] = {"phase": "LUNGE", "t": 0.0}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for i in 130:
		race._tick_shark_pack(1.0 / 60.0)
		if String(race._shark_pack["shark6"]["phase"]) == "FOLLOWER_1":
			break
	race._update_camera()
	race.queue_redraw()
	await _frames(3)
	await _save("shark-pack-follower1.png")
	for i in 40:
		race._tick_shark_pack(1.0 / 60.0)
		race._check_shark_attacks(1.0 / 60.0)
	race._update_camera()
	race.queue_redraw()
	await _frames(3)
	await _save("shark-pack-follower2.png")
	print("SHARK PACK CAPTURE: DONE")
	get_tree().quit(0)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var p := ProjectSettings.globalize_path(OUT).path_join(name)
	get_viewport().get_texture().get_image().save_png(p)
	print("CAPTURE ", p)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
