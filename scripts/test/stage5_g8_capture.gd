extends Node
## TBB-EXPERIENCE-REBUILD-05 G8：接人提示环的截图证据。
##
## 只做视觉取证：把兔子摆进落壳走廊（壳上方 100 px、正在下落），
## 让 _draw 画出绿色环，抓一帧存盘。判定/收人都不动。
##
## 运行（需要渲染，不能 --headless）：
##   godot --path TURBBIT res://scenes/stage5_g8_capture.tscn
## 输出：screenshots/rebuild05-g8-corridor.png

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_PATH := "res://screenshots/rebuild05-g8-corridor.png"

var is_runner := false
var race: Node = null


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5G8CaptureRunner"
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
	if race == null:
		push_error("G8 CAPTURE: no race")
		get_tree().quit(1)
		return
	race.opening_active = false
	race.test_disable_hazards = true
	race.test_no_finish = true
	var zone: Dictionary = LevelData.zone_at(400.0)
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	race.current_zone = zone
	race.turtle.reset(Vector2(420.0, Tuning.NEUTRAL_DEPTH))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	# 摆进走廊：壳上方 100 px（走廊是 -150 起），正在下落。
	var mp: Vector2 = race.turtle.get_mount_point()
	race.rabbit.position = mp + Vector2(0.0, -100.0)
	race.rabbit.velocity = Vector2(0.0, 120.0)
	race.mount.mark_airborne()
	for i in 3:
		await get_tree().physics_frame
	print("G8 CAPTURE: pickup_window=%s dy=%.1f" % [
		str(GameManager.pickup_window),
		race.rabbit.position.y - race.turtle.get_mount_point().y])
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_PATH)
	var err: int = img.save_png(path)
	print("G8 CAPTURE: saved %s err=%d" % [path, err])
	get_tree().quit(0 if err == OK else 1)
