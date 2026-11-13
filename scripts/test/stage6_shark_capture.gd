extends Node
## TBB-EXPERIENCE-REFINE-06 P3：伏击鲨三个可读状态的截图取证。
##
## 只做视觉取证，不改判定：把乌龟停在 shark5 前方、让鲨鱼走完
## 潜伏 → 预警 → 上冲 三段，各抓一帧；同时把这一帧的 live 矩形打印出来，
## 截图里的位置要和数字对得上。
##
## 运行（需要渲染，不能 --headless）：
##   godot --path TURBBIT res://scenes/stage6_shark_capture.tscn
## 输出：screenshots/refine06-p3-shark-down.png / -telegraph.png / -lunge.png

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const GROUP := "shark5"
const STEP := 1.0 / 60.0
const SHOTS := {
	"down": "res://screenshots/refine06-p3-shark-down.png",
	"telegraph": "res://screenshots/refine06-p3-shark-telegraph.png",
	"lunge": "res://screenshots/refine06-p3-shark-lunge.png",
}

var is_runner := false
var race: Node = null


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage6SharkCaptureRunner"
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
		push_error("P3 CAPTURE: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	race.boost_lanes.clear()
	var g := _group(GROUP)
	var start: float = race._group_start(g)
	var x0: float = start - 170.0
	var y0: float = Tuning.NEUTRAL_DEPTH
	race.turtle.reset(Vector2(x0, y0))
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race.reset_ambush_states("DOWN")

	# 潜伏：把状态拨到“刚归位”，只走两帧让画面同步；还没到重装时间，不会醒。
	race._ambush[GROUP] = {"phase": "DOWN", "t": 0.0}
	_step(2.0 * STEP, x0, y0)
	await _shot("down", g)

	# 预警：水面鳍 + 泡泡 + “!”；鱼身仍在深水。
	race._ambush[GROUP] = {"phase": "DOWN", "t": Tuning.SHARK_REARM_TIME}
	var guard := 0
	while _phase(g) != "TELEGRAPH" and guard < 120:
		_step(STEP, x0, y0)
		guard += 1
	_step(0.30, x0, y0)
	await _shot("telegraph", g)

	# 上冲：鱼身到水面，判定框就是画出来的那一个。
	guard = 0
	while _phase(g) != "LUNGE" and guard < 120:
		_step(STEP, x0, y0)
		guard += 1
	_step(0.30, x0, y0)
	await _shot("lunge", g)

	get_tree().quit(0)


func _step(seconds: float, x0: float, y0: float) -> void:
	var guard := 0
	while guard < int(seconds / STEP):
		race.turtle.speed = 0.0
		race._physics_process(STEP)
		race.turtle.position = Vector2(x0, y0)
		guard += 1


func _phase(g: Dictionary) -> String:
	return String(race.hazard_motion_state(g).get("phase", ""))


func _shot(tag: String, g: Dictionary) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var live: Rect2 = race.hazard_rect_live(g, 0)
	var st: Dictionary = race.hazard_motion_state(g)
	print("P3 CAPTURE %s: phase=%s t=%.2f live=(%.1f,%.1f %.0fx%.0f)" % [
		tag, String(st["phase"]), float(st["t"]),
		live.position.x, live.position.y, live.size.x, live.size.y])
	var img := get_viewport().get_texture().get_image()
	var err: int = img.save_png(ProjectSettings.globalize_path(String(SHOTS[tag])))
	print("P3 CAPTURE %s: saved err=%d" % [tag, err])


func _group(name: String) -> Dictionary:
	for g in race.hazard_groups:
		if String(g["group"]) == name:
			return g
	return {}
