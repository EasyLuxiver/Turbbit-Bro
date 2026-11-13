extends Node
## TBB-SHIFT-CORE-02 海鸟重做的视觉证据：同一次俯冲的四个时刻。
## 只摆位、不注入按键；用来检查“预警 → 下潜 → 攻击 → 退出”四段画得读不读得懂。
## 运行（窗口化，必须）：
##   D:/Godot_v4.7-stable_win64_console.exe --path D:/GAMESTUDIO/TURBBIT \
##       res://scenes/stage4_bird_capture.tscn

const Tuning = preload("res://scripts/systems/tuning.gd")

var is_runner := false
var race


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4BirdCaptureRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "en"
	GameManager.start_race()
	await _wait_scene("race.tscn")
	await _frames(4)
	race = get_tree().current_scene
	race.test_disable_hazards = true
	race.test_no_finish = true
	race.set_physics_process(false)
	var group: Dictionary = race.hazard_groups[0]
	var gx: float = race._group_start(group)
	GameManager.set_control("rabbit")
	var phases := [
		[700.0, "bird-1-warning"],
		[380.0, "bird-2-dive"],
		[0.0, "bird-3-strike"],
		[-420.0, "bird-4-exit"],
	]
	for item in phases:
		var d: float = float(item[0])
		race.turtle.position = Vector2(gx - d, Tuning.NEUTRAL_DEPTH)
		race.turtle.speed = race.turtle.base_speed
		race.rabbit.position = race.turtle.get_mount_point()
		race.mount.mark_riding()
		race._update_camera()
		race.queue_redraw()
		await _frames(3)
		race._save_shot("%s.png" % String(item[1]))
	get_tree().quit(0)


func _wait_scene(suffix: String) -> void:
	for i in 240:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path.ends_with(suffix):
			return


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
