extends Node
## TBB-EXPERIENCE-REFINE-06 P4：食物争夺与两种吃法的截图取证。
##
## 只做视觉取证，不改判定：把食物放到镜头里，抓四帧——
##   1) interest：320 px 内有食物，两个角色都伸手、没被操控的那个头顶冒 “!”；
##   2) rabbit-gulp：兔子吃下，gulp 特效从兔子嘴边冒；
##   3) rabbit-boost：吃下后兔子身上有上浮箭头（跳跃强化在生效）；
##   4) turtle-gulp：乌龟吃下，同样的 gulp 从乌龟嘴边冒。
##
## 运行（需要渲染，不能 --headless）：
##   godot --path TURBBIT res://scenes/stage4_snack_contest_capture.tscn
## 输出：screenshots/refine06-p4-snack-*.png

const LevelData = preload("res://scripts/systems/level_data.gd")
const Tuning = preload("res://scripts/systems/tuning.gd")

const STEP := 1.0 / 60.0
const SHOTS := {
	"interest": "res://screenshots/refine06-p4-snack-interest.png",
	"interest_rabbit": "res://screenshots/refine06-p4-snack-interest-rabbit.png",
	"rabbit_gulp": "res://screenshots/refine06-p4-snack-rabbit-gulp.png",
	"rabbit_boost": "res://screenshots/refine06-p4-snack-rabbit-boost.png",
	"turtle_gulp": "res://screenshots/refine06-p4-snack-turtle-gulp.png",
}

var is_runner := false
var race: Node = null


func _ready() -> void:
	if not is_runner:
		var runner := Node.new()
		runner.name = "Stage4SnackContestCaptureRunner"
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
		push_error("P4 CAPTURE: no race")
		get_tree().quit(1)
		return
	race.set_physics_process(false)
	race.opening_active = false
	race.test_no_finish = true
	race.test_disable_hazards = true
	race.load_level(LevelData.groups(), LevelData.boost_lanes())
	# 不清 boost_lanes：食物就是从它们生成的，清了就没有食物可拍。
	var enc := _first_snack()
	if enc.is_empty():
		push_error("P4 CAPTURE: no snack")
		get_tree().quit(1)
		return
	var sx := float(enc["x"])

	# 1) 争抢：食物在右前方 300 px，控乌龟；兔子伸手 + “!”。
	_place(sx - 300.0, "turtle")
	_step(0.30)
	await _shot("interest", "interest=%.0f" % race.snack_interest_x)

	# 1b) 同一位置改控兔子：乌龟的伸手标记 + “!” 指向乌龟。
	_place(sx - 300.0, "rabbit")
	_step(0.30)
	await _shot("interest_rabbit", "interest=%.0f" % race.snack_interest_x)

	# 2/3) 兔子吃：把食物重置，控兔子，停在食物上吃下。
	_reset_snack(enc)
	_place(sx, "rabbit")
	race._update_snack(STEP)
	_step(0.16)
	await _shot("rabbit_gulp", "by=%s jump=%.2f" % [
		race.snack_last_by, race.rabbit.jump_boost])
	await _shot("rabbit_boost", "boost_active=%s" % str(race.snack_rabbit_boost_active()))

	# 4) 乌龟吃：同一份食物重置，控乌龟。
	_reset_snack(enc)
	_place(sx, "turtle")
	race._update_snack(STEP)
	_step(0.16)
	await _shot("turtle_gulp", "by=%s turbo=%s" % [
		race.snack_last_by, str(race.snack_boost_active())])

	get_tree().quit(0)


func _first_snack() -> Dictionary:
	var list: Array = race._snack_list()
	return list[0] if not list.is_empty() else {}


func _reset_snack(enc: Dictionary) -> void:
	enc["eaten"] = false
	race.snack_boost_until_x = -1.0
	race.snack_boost_speed = 0.0
	race.rabbit_boost_until_x = -1.0
	race.rabbit.jump_boost = 1.0
	race.snack_last_by = ""
	race.snack_last_eaten = ""
	race.snack_gulp_t = 0.0
	race.snack_gulp_by_player = false


func _place(x: float, control: String) -> void:
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.accident_state = "NONE"
	GameManager.current_control = control
	var y: float = Tuning.NEUTRAL_DEPTH
	race.turtle.reset(Vector2(x, y))
	race.turtle.base_speed = 220.0
	race.turtle.speed = 0.0
	race.rabbit.reset()
	race.rabbit.attach(race.turtle.get_mount_point())
	race.mount.reset()
	race.mount.mark_riding()
	race.turtle_brain.drift = 0.0


## 冻结走位但让 _physics_process 走完（它负责 queue_redraw 与动画时钟）。
func _step(seconds: float) -> void:
	var guard := 0
	var x: float = race.turtle.position.x
	while guard < int(seconds / STEP):
		race.turtle.speed = 0.0
		race._physics_process(STEP)
		race.turtle.position = Vector2(x, Tuning.NEUTRAL_DEPTH)
		guard += 1


func _shot(tag: String, note: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err: int = img.save_png(ProjectSettings.globalize_path(String(SHOTS[tag])))
	print("P4 CAPTURE %s: %s gulp_t=%.2f saved err=%d" % [
		tag, note, race.snack_gulp_t, err])
