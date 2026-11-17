extends Node
## FEEL-13 P0-A：BITT 主动救援真实链路逐帧取证（接近 → 接住 → 抬回壳上 → 恢复骑乘）。
## 运行（窗口化，建议 1280x720；GIF 会缩到 640 宽）：
##   Godot --path . --resolution 1280x720 res://scenes/stage13_catch_gif.tscn
## 帧写到 _attic/2026-11-14/feel13-catch-frames/，不留在工作树。

const FPS := 60.0
const OUT_FRAMES := "res://_attic/2026-11-14/feel13-catch-frames"

var is_runner := false
var race: Node
var frames: Array = []


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
	race = get_tree().current_scene
	race.set_physics_process(false)
	race.opening_active = false
	race.test_disable_hazards = true
	race.test_no_lessons = true
	race.test_no_finish = true
	GameManager.test_no_best = true
	race.load_level([], [])
	race.world_end = 1.0e9
	race.turtle.reset(Vector2(900.0, race.surface_ref()))
	race.rabbit.reset()
	race.rabbit.position = Vector2(1220.0, race.surface_ref() + 120.0)
	race.rabbit.state = "FALLING_WATER"
	race.mount.mark_rescue_active(5.0)
	GameManager.accident_state = "RABBIT_WATER"
	GameManager.current_control = "turtle"
	GameManager.shift_lock_t = 0.0
	race._catch_active = false
	race._catch_t = 0.0
	Input.action_release("pop")
	race._physics_process(1.0 / FPS)
	Input.action_press("pop")
	race._physics_process(1.0 / FPS)
	Input.action_release("pop")
	var dir := ProjectSettings.globalize_path(OUT_FRAMES)
	DirAccess.make_dir_recursive_absolute(dir)
	# 清掉上一次的帧（只清这个专用目录）。
	for old in DirAccess.get_files_at(dir):
		if old.begins_with("frame_") and old.ends_with(".png"):
			DirAccess.remove_absolute(dir.path_join(old))
	var caught_at := -1
	var riding_at := -1
	for i in 260:
		race._physics_process(1.0 / FPS)
		race._update_camera()
		race.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if i % 2 == 0:
			var path := dir.path_join("frame_%03d.png" % int(i / 2))
			get_viewport().get_texture().get_image().save_png(path)
			frames.append({
				"step": i, "png": path,
				"mount": String(race.mount.state),
				"result": String(race.rescue_last_result),
				"turtle": [race.turtle.position.x, race.turtle.position.y],
				"rabbit": [race.rabbit.position.x, race.rabbit.position.y],
				"catch_active": bool(race._catch_active),
				"catch_t": float(race._catch_t),
			})
		if caught_at < 0 and String(race.rescue_last_result) == "caught":
			caught_at = i
		if caught_at >= 0 and String(race.mount.state) == "RIDING":
			riding_at = i
			# 恢复骑乘后再多拍 12 帧，确认控制/HUD 回来。
			if i - caught_at >= 60:
				break
		if caught_at < 0 and String(race.rescue_last_result) == "missed":
			break
	var meta := {
		"frames": frames.size(), "caught_at_step": caught_at,
		"riding_at_step": riding_at,
		"final_mount": String(race.mount.state),
		"final_result": String(race.rescue_last_result),
		"final_control": GameManager.current_control,
		"final_accident": GameManager.accident_state,
		"start_turtle_x": 900.0, "start_rabbit_x": 1220.0,
		"no_teleport_check": _no_teleport(frames),
	}
	var f := FileAccess.open("res://docs/reports/longrun/core-feel-13-catch-gif.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "  "))
	f.close()
	print("CATCH GIF frames=%d caught_at=%d riding_at=%d final=%s/%s control=%s no_teleport=%s" % [
		frames.size(), caught_at, riding_at, String(race.mount.state),
		String(race.rescue_last_result), GameManager.current_control,
		str(meta["no_teleport_check"])])
	get_tree().quit(0 if caught_at >= 0 and riding_at >= 0 and bool(meta["no_teleport_check"]) else 1)


## 任何一帧位移超过 80 px 都算瞬移；接住/抬升必须是连续轨迹。
func _no_teleport(list: Array) -> bool:
	for i in range(1, list.size()):
		var a: Array = list[i - 1]["rabbit"]
		var b: Array = list[i]["rabbit"]
		if Vector2(a[0], a[1]).distance_to(Vector2(b[0], b[1])) > 80.0:
			return false
	return true
