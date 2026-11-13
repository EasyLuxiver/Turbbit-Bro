extends Node
## TBB-EXPERIENCE-REFINE-06 P6：Z1 35–50 s 窗口的视觉取证（只截图，不改判定）。
##
## 换位后的实际赛道：
##   rock3 8400 → beam2 9600 → wall1 10860 → gate2 12000 → bird2 13300 → beam1 14550
## 三张：
##   1) z1-run-up     rock3/beam2 两连兔子之后的路段；
##   2) z1-wall1      原 10860 的低鸟位置现在是高墙（跃起+蹬踏，BOTH）；
##   3) z1-bird2      原 13300 的高墙位置现在是低鸟。
##
## 运行（需要渲染，不能 --headless）：
##   godot --path TURBBIT res://scenes/stage4_p6_layout_capture.tscn
## 输出：screenshots/refine06-p6-z1-*.png

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const STEP := 1.0 / 60.0
const SHOTS := {
	"run_up": "res://screenshots/refine06-p6-z1-run-up.png",
	"wall1": "res://screenshots/refine06-p6-z1-wall1.png",
	"bird2": "res://screenshots/refine06-p6-z1-bird2.png",
}

var is_runner := false
var race: Node = null


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4P6LayoutCaptureRunner"
		runner.set_script(get_script())
		runner.set("is_runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run()


func _run() -> void:
	Locale.language = "zh"
	GameManager.start_race()
	for i in 4:
		await get_tree().process_frame
	race = get_tree().current_scene
	if race == null:
		push_error("P6 CAPTURE: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())

	# 1) rock3(8400)/beam2(9600) 之后、wall1 之前的路段。
	_place(8700.0, "turtle")
	await _advance_to(9150.0)
	await _shot("run_up", "x=%.0f wall1=%.0f" % [race.turtle.position.x, _group_x("wall1")])

	# 2) wall1：10520 处，前方 340 px 就是 10860 的高墙。
	_place(10300.0, "turtle")
	await _advance_to(10520.0)
	await _shot("wall1", "x=%.0f wall1=%.0f" % [race.turtle.position.x, _group_x("wall1")])

	# 3) bird2：13200 处，前方 100 px 是 13300 的低鸟。
	_place(12900.0, "turtle")
	await _advance_to(13200.0)
	await _shot("bird2", "x=%.0f bird2=%.0f" % [race.turtle.position.x, _group_x("bird2")])

	print("P6 CAPTURE: done")
	get_tree().quit(0)


func _group_x(name: String) -> float:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return LevelData.group_start(g)
	return -1.0


func _place(x: float, control: String) -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.oxygen = Tuning.OXYGEN_MAX
	GameManager.showtime_active = false
	GameManager.current_control = control
	race.showtime_active = false
	race.finishing = false
	race.hazard_cooldown = 0.0
	race.turtle_repair = 0.0
	race.rabbit_stun = 0.0
	var zone: Dictionary = LevelData.zone_at(x)
	race.current_zone = zone
	var speed: float = float(zone["base_speed"])
	race.turtle.reset(Vector2(x, Tuning.NEUTRAL_DEPTH))
	race.turtle.speed = speed
	race.turtle.base_speed = speed
	race.turtle.speed_cap = 1.0e9
	race.turtle.daze_time = 0.0
	race.turtle.drift = 0.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	# 少了这一行，兔子被当成离壳，下一帧就记 RABBIT_AIR，乌龟事故停车。
	race.rabbit.state = "RIDING"


func _advance_to(target_x: float) -> void:
	var guard := 0
	while race.turtle.position.x < target_x and guard < 600:
		race._physics_process(STEP)
		await get_tree().process_frame
		guard += 1
	print("ADV to %.0f: x=%.1f guard=%d state=%s acc=%s tut_acc=%s speed=%.1f opening=%s finishing=%s" % [
		target_x, race.turtle.position.x, guard, str(GameManager.state),
		String(GameManager.accident_state), str(race.turtle.accident),
		race.turtle.speed, str(race.opening_active), str(race.finishing)])
	# 让镜头跟到位再截。
	for i in 6:
		await get_tree().process_frame


func _shot(tag: String, note: String) -> void:
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(String(SHOTS[tag]))
	var err: int = img.save_png(path)
	print("SHOT %-8s %s -> %s (err=%d)" % [tag, note, String(SHOTS[tag]), err])
