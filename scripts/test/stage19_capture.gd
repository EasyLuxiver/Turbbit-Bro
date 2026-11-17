extends Node
## FEEL-19 视觉证据：满格 HUD/SPACE 键帽、海鸟预兆与投射物。

const LevelData = preload("res://scripts/systems/level_data.gd")
const OUT := "res://docs/reports/longrun/feel19"
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
	race.load_level([], [])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# P0 HUD：主控满格 + 救援 SPACE 提示。
	GameManager.current_control = "rabbit"
	GameManager.clear_bro_meter()
	for i in 3:
		GameManager.note_mistake("RABBIT_STUN", "rabbit")
	GameManager.prompt.emit(Locale.t("prompt.rescue_dive"))
	race.hud._process(0.016)
	race._update_camera()
	race.queue_redraw()
	await _frames(3)
	await _save("p0-full-meter-space.png")
	# 海鸟：bird3 排泄攻击的预兆/投射物。
	var g := LevelData.build_group({"group": "bird3", "zone": 1, "kind": "LOW_BIRD",
		"x": 1100.0, "w": 120.0})
	race.load_level([g], [])
	race.test_disable_hazards = false
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race._bird_states["bird3"]["target"] = "turtle"
	race._bird_states["bird3"]["phase"] = "WAIT"
	for i in 34:
		race._tick_bird_behaviors(1.0 / 60.0)
	race._update_camera()
	race.queue_redraw()
	await _frames(2)
	await _save("bird-poop-telegraph.png")
	# Advance to projectile action.
	for i in 24:
		race._tick_bird_behaviors(1.0 / 60.0)
		race._check_bird_attacks(1.0 / 60.0)
	race._update_camera()
	race.queue_redraw()
	await _frames(2)
	await _save("bird-poop-projectile.png")
	print("FEEL19 CAPTURE: DONE")
	get_tree().quit(0)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var p := ProjectSettings.globalize_path(OUT).path_join(name)
	get_viewport().get_texture().get_image().save_png(p)
	print("CAPTURE ", p)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
