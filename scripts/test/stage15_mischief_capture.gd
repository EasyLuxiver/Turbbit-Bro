extends Node
## FEEL-15：双向 MISCHIEF 与 SHIFT 中断的实际画面/GIF 帧。

const FPS := 60.0
const OUT := "res://docs/reports/longrun/feel15"
const FRAMES := "res://_attic/2026-11-14/feel15-mischief-frames"
var is_runner := false
var race: Node
var rows: Array = []


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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES))
	# 1) BITT 电 TUBO（玩家控 TUBO）
	_reset("rabbit")
	_fill("turtle")
	race._tick_mischief(1.0 / FPS)
	await _play(1.25, "shock", true)
	# 2) TUBO 拽 BITT（玩家控 BITT）
	_reset("turtle")
	_fill("rabbit")
	race._tick_mischief(1.0 / FPS)
	await _play(1.25, "tug", true)
	# 3) SHIFT 中断：前摇中切走，旧角色立即停止
	_reset("rabbit")
	_fill("turtle")
	race._tick_mischief(1.0 / FPS)
	GameManager.shift_lock_t = 0.0
	GameManager.toggle_control()
	race._tick_mischief(1.0 / FPS)
	await _play(2.4, "shift-cancel", false)
	var f := FileAccess.open(OUT + "/core-feel-15-mischief-capture.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"rows": rows}, "  "))
	f.close()
	print("MISCHIEF CAPTURE: PASS")
	get_tree().quit(0)


func _reset(control: String) -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.current_control = control
	GameManager.shift_lock_t = 0.0
	GameManager.accident_state = "NONE"
	GameManager.clear_bro_meter()
	race._mischief_role = ""
	race._mischief_phase = ""
	race._mischief_t = 0.0
	race._mischief_cd = 0.0
	race._mischief_last_control = control
	race._mischief_fx_kind = ""
	race._mischief_fx_t = 0.0
	race.mount.reset()
	race.mount.mark_riding()
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.turtle.speed = 220.0
	race._update_camera()
	race.queue_redraw()


func _fill(who: String) -> void:
	for i in 3:
		GameManager.note_mistake("TURTLE_WAVE" if who == "turtle" else "RABBIT_STUN", who)


func _play(seconds: float, tag: String, save_frames: bool) -> void:
	var n := int(seconds * FPS)
	var shot := ProjectSettings.globalize_path(OUT).path_join("mischief-%s.png" % tag)
	var shot_done := false
	for i in n:
		race._tick_mischief(1.0 / FPS)
		race._update_camera()
		race.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if save_frames and i % 2 == 0:
			var p := ProjectSettings.globalize_path(FRAMES).path_join(
				"%s_%03d.png" % [tag, int(i / 2)])
			get_viewport().get_texture().get_image().save_png(p)
		if not shot_done and (race._mischief_fx_t > 0.0 or (tag == "shift-cancel" and i >= n - 2)):
			get_viewport().get_texture().get_image().save_png(shot)
			shot_done = true
	if not shot_done:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
	rows.append({"tag": tag, "role": race._mischief_role,
		"phase": race._mischief_phase, "fx": race._mischief_fx_kind,
		"png": shot})
	print("CAPTURE ", tag, " role=", race._mischief_role,
		" phase=", race._mischief_phase, " fx=", race._mischief_fx_kind)
