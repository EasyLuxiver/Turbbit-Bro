extends Node
## TBB-EXPERIENCE-REBUILD-05 G9：壳下沉的截图证据。
##
## 只做视觉取证：先存一张“骑乘静止”的对照帧，再让兔子真实跳起、落回壳上，
## 在落壳后的第一帧存第二张（此时下沉量最接近峰值）。
##
## 运行（需要渲染，不能 --headless）：
##   godot --path TURBBIT res://scenes/stage5_g9_capture.tscn
## 输出：screenshots/rebuild05-g9-shell-dip_rest.png / rebuild05-g9-shell-dip.png

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const OUT_REST := "res://screenshots/rebuild05-g9-shell-dip_rest.png"
const OUT_DIP := "res://screenshots/rebuild05-g9-shell-dip.png"

var is_runner := false
var race: Node = null


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage5G9CaptureRunner"
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
		push_error("G9 CAPTURE: no race")
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
	for i in 6:
		await get_tree().physics_frame
	await _shot(OUT_REST, "rest")
	# 真实起跳（引擎内输入代理，不是 OS 级按键），然后等它落回壳上。
	Input.action_press("up")
	race._note_up_input()
	for i in 2:
		await get_tree().physics_frame
	Input.action_release("up")
	var jumped := false
	var guard := 0
	while guard < 240:
		await get_tree().physics_frame
		guard += 1
		if String(race.mount.state) == "AIRBORNE":
			jumped = true
		elif jumped and String(race.mount.state) == "RIDING":
			break
	if not jumped:
		push_error("G9 CAPTURE: jump never left the shell")
		get_tree().quit(1)
		return
	# 落壳后第一帧：下沉量接近峰值。
	print("G9 CAPTURE: dip=%.1f px at landing" % race.shell_dip_offset())
	await RenderingServer.frame_post_draw
	await _save(OUT_DIP)
	get_tree().quit(0)


func _shot(path: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	await _save(path, label)


func _save(path: String, label: String = "dip") -> void:
	var img := get_viewport().get_texture().get_image()
	var abs_path := ProjectSettings.globalize_path(path)
	var err: int = img.save_png(abs_path)
	print("G9 CAPTURE[%s]: saved %s err=%d" % [label, abs_path, err])
