extends Node
## FEEL-13 P1-B：1920×1080 / 全屏下的氧气三气泡检查。
## 运行（窗口化，必须带分辨率）：
##   Godot_v4.7-stable_win64_console.exe --path . --resolution 1920x1080 \
##       res://scenes/stage13_oxygen_1920.tscn
## 输出：docs/reports/longrun/feel13/oxygen-1920-*.png + core-feel-15-oxygen-1920.json

var is_runner := false
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
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	var race := get_tree().current_scene
	if race == null:
		push_error("OXYGEN13: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = true
	race.test_no_lessons = true
	race.turtle.position = Vector2(2000.0, race.surface_ref())
	race.rabbit.reset()
	race.rabbit.position = Vector2(2100.0, race.surface_ref() + 128.0)
	race.rabbit.state = "FALLING_WATER"
	race.mount.reset()
	race.mount.mark_rescue_active(3.2)
	GameManager.accident_state = "RABBIT_WATER"
	race._update_camera()
	race._update_dock()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var win: Vector2i = DisplayServer.window_get_size()
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	var dir := ProjectSettings.globalize_path("res://docs/reports/longrun/feel15")
	DirAccess.make_dir_recursive_absolute(dir)
	var shots := [["full", 8.0, 3], ["mid", 4.0, 2], ["low", 1.2, 1], ["empty", 0.0, 0]]
	var ok := win.x >= 1900 and win.y >= 1060
	for s in shots:
		GameManager.oxygen = float(s[1])
		race.queue_redraw()
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var center: Vector2 = race.rabbit.position + Vector2(0.0, -62.0)
		var screen_pos: Vector2 = get_viewport().get_canvas_transform() * center
		var inside := Rect2(Vector2.ZERO, vp).has_point(screen_pos)
		var count: int = race.oxygen_bubble_count()
		var good := count == int(s[2]) and inside
		ok = ok and good
		var path := dir.path_join("oxygen-1920-%s%s.png" % [
			String(s[0]), "-fullscreen" if fullscreen else ""])
		get_viewport().get_texture().get_image().save_png(path)
		rows.append({"state": String(s[0]), "oxygen": float(s[1]),
			"bubbles": count, "expect": int(s[2]), "screen_center": [screen_pos.x, screen_pos.y],
			"inside_viewport": inside, "ok": good, "png": path})
		print("OXY13 %-5s oxygen=%.1f bubbles=%d expect=%d screen=(%.0f,%.0f) inside=%s logical=%.0fx%.0f window=%dx%d fullscreen=%s" % [
			String(s[0]), float(s[1]), count, int(s[2]), screen_pos.x, screen_pos.y,
			str(inside), vp.x, vp.y, win.x, win.y, str(fullscreen)])
	var payload := {"logical_viewport": [vp.x, vp.y], "window_size": [win.x, win.y],
		"fullscreen": fullscreen, "min_window_ok": win.x >= 1900 and win.y >= 1060,
		"rows": rows, "ok": ok}
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-15-oxygen-1920.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
	print("OXYGEN 1920: " + ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
