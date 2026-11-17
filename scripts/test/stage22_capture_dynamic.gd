extends Node
## FEEL-22：三种动态障碍的实机视觉证据。

const LevelData = preload("res://scripts/systems/level_data.gd")
const OUT := "res://docs/reports/longrun/feel22"
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for spec in [
		{"identity": "dock_crate", "motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6, "phase": 0.18}, "file": "dynamic-dock-crate.png"},
		{"identity": "drift_crate", "motion": {"name": "tide_rock", "axis": "y", "amp": 52.0, "period": 3.6, "phase": 0.31}, "file": "dynamic-drift-crate.png"},
	]:
		var g := LevelData.build_group({"group": "cap_" + String(spec["identity"]),
			"zone": 2, "kind": "SURFACE_ROCK", "x": 900.0, "w": 120.0,
			"identity": spec["identity"], "motion": spec["motion"]})
		race.load_level([g], [])
		race.turtle.reset(Vector2(700.0, race.surface_ref()))
		race.rabbit.reset()
		race.rabbit.attach(race.turtle.get_mount_point())
		race.mount.reset()
		race.mount.mark_riding()
		race.hazard_clock = 0.9
		race._update_camera()
		race.queue_redraw()
		await _frames(3)
		await _save(String(spec["file"]))
	print("DYNAMIC CAPTURE DONE")
	get_tree().quit(0)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var p := ProjectSettings.globalize_path(OUT).path_join(name)
	get_viewport().get_texture().get_image().save_png(p)
	print("CAPTURE ", p)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
