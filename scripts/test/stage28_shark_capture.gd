extends Node
## FEEL-28：正式 Z3 shark6 的三拍画面证据（实际关卡组，非合成组）。
const LevelData = preload("res://scripts/systems/level_data.gd")
const OUT := "res://docs/reports/longrun/feel28"
var is_runner := false
var race: Node

func _ready() -> void:
	if not is_runner:
		var r := Node.new(); r.set_script(get_script()); r.set("is_runner", true)
		get_tree().root.add_child.call_deferred(r); return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()

func _run() -> void:
	GameManager.test_no_best = true
	GameManager.start_race()
	for i in 5: await get_tree().process_frame
	race = get_tree().current_scene
	race.set_physics_process(false); race.opening_active = false; race.test_no_finish = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	var g: Dictionary = {}
	for h in race.hazard_groups:
		if String(h.get("group", "")) == "shark6": g = h; break
	if g.is_empty(): print("NO_SHARK6"); get_tree().quit(1); return
	race.turtle.reset(Vector2(LevelData.group_start(g) - 220.0, race.surface_ref()))
	race.rabbit.reset(); race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset(); race.mount.mark_riding()
	race._ambush["shark6"] = {"phase": "LUNGE", "t": 0.0}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for i in 90:
		race._tick_shark_pack(1.0 / 60.0)
		if String(race._shark_pack["shark6"]["phase"]) == "GAP1": break
	race._update_camera(); race.queue_redraw()
	await _frames(3)
	await _save("shark-z3-gap1.png")
	print("SHARK CAPTURE DONE phase=", String(race._shark_pack["shark6"]["phase"]))
	get_tree().quit(0)

func _save(n: String) -> void:
	await RenderingServer.frame_post_draw
	var p := ProjectSettings.globalize_path(OUT).path_join(n)
	get_viewport().get_texture().get_image().save_png(p)
	print("CAPTURE ", p)

func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame
